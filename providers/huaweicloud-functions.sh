#!/bin/bash

# 定义 AXIOM 路径
AXIOM_PATH="$HOME/.axiom"

###################################################################
# 创建实例
# 这是最重要的提供者函数，用于初始化和批量创建实例
# 参数:
#   $1 - name: 实例名称
#   $2 - image_id: 镜像ID
#   $3 - size_slug: 实例规格
#   $4 - region: 区域
#   $5 - boot_script: 启动脚本
#
create_instance() {
    name="$1"
    image_id="$2"
    size_slug="$3"
    region="$4"
    boot_script="$5"
    sshkey="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.sshkey')"
    security_group_id="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.security_group_id')"

    huaweicloud ecs run-instances \
        --image-id "$image_id" \
        --instance-type "$size_slug" \
        --name "$name" \
        --region "$region" \
        --security-group-id "$security_group_id" \
        --vpc-id "$HUAWEICLOUD_VPC_ID" \
        --subnet-id "$HUAWEICLOUD_SUBNET_ID" \
        --key-name "$sshkey" \
        --user-data "$boot_script" 2>&1 >> /dev/null

    sleep 260
}

###################################################################
# 删除实例
# 如果第二个参数设置为 "true"，则不会提示确认
# 用于 axiom-rm 命令
# 参数:
#   $1 - name: 实例名称
#   $force - 是否强制删除（可选）
#
delete_instance() {
    name="$1"
    id="$(instance_id "$name")"

    if [ "$force" != "true" ]; then
        read -p "确定要删除实例 '$name' 吗？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "实例删除已取消。"
            return 1
        fi
    fi

    huaweicloud ecs delete-instances --instance-ids "$id" 2>&1 >> /dev/null
}

###################################################################
# 实例相关函数
# 这些函数被文件中的许多其他函数使用
#
instances() {
    huaweicloud ecs list-servers
}

# 获取实例的IP地址
# 参数:
#   $1 - name: 实例名称
# 返回: 实例的公网IP地址
# 用于: axiom-ls axiom-init
instance_ip() {
    name="$1"
    instances | jq -r ".servers[] | select(.name==\"$name\") | .addresses[].\"floating-ip\".addr"
}

# 获取实例列表
# 返回: 所有实例的名称列表
# 用于: axiom-select axiom-ls
instance_list() {
    instances | jq -r '.servers[].name'
}

# 格式化显示实例信息
# 显示: 实例名称、IP地址、区域、类型、状态和价格
# 用于: axiom-ls
instance_pretty() {
    type="$(jq -r .default_size "$AXIOM_PATH/axiom.json")"    
    header="实例名称,公网IP,内网IP,区域,类型,状态,月费用"
    fields=".servers[] | [.name, (.addresses[].\"floating-ip\".addr), .addresses[].\"fixed-ip\".addr, .availability_zone, .flavor.name, .status] | @csv"
    data=$(instances | jq -r "$fields" | sort -k1)
    numInstances=$(echo "$data" | grep -v '^$' | wc -l)

    if [[ $numInstances -gt 0 ]]; then
        cost=$(huaweicloud bss query-price --product-infos "[{\"id\":\"$type\",\"type\":\"vm\"}]" | jq -r '.official_website_price')
        data=$(echo "$data" | sed "s/$/,\"$cost\" /")
        totalCost=$(echo "$cost * $numInstances * 730" | bc)
    fi
    footer="_,_,_,实例总数,$numInstances,总费用,\$$totalCost"
    (echo "$header" && echo "$data" && echo "$footer") | sed 's/"//g' | column -t -s,
}

###################################################################
# 动态生成 axiom 的 SSH 配置
# 可以选择使用私有IP或公网IP生成配置
# 也可以选择锁定配置，只使用缓存的配置文件 ~/.axiom/.sshconfig
# 用于: axiom-exec axiom-fleet axiom-ssh
#
generate_sshconfig() {
    accounts=$(ls -l "$AXIOM_PATH/accounts/" | grep "json" | grep -v 'total ' | awk '{ print $9 }' | sed 's/\.json//g')
    current=$(readlink -f "$AXIOM_PATH/axiom.json" | rev | cut -d / -f 1 | rev | cut -d . -f 1)> /dev/null 2>&1
    sshnew="$AXIOM_PATH/.sshconfig.new$RANDOM"
    droplets="$(instances)"
    echo -n "" > $sshnew
    echo -e "\tServerAliveInterval 60\n" >> $sshnew
    sshkey="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.sshkey')"
    echo -e "IdentityFile $HOME/.ssh/$sshkey" >> $sshnew
    generate_sshconfig="$(cat "$AXIOM_PATH/axiom.json" | jq -r '.generate_sshconfig')"

    if [[ "$generate_sshconfig" == "private" ]]; then
        echo -e "Warning your SSH config generation toggle is set to 'Private' for account : $(echo $current)."
        for name in $(instance_list)
        do
            ip=$(instance_ip "$name")
            status=$(instances | jq -r ".servers[] | select(.name==\"$name\") | .status")
            if [[ "$status" == "ACTIVE" ]]; then
                echo -e "Host $name\n\tHostName $ip\n\tUser op\n\tPort 2266\n" >> $sshnew
            fi
        done
    else
        for name in $(instance_list)
        do
            ip=$(instance_ip "$name")
            status=$(instances | jq -r ".servers[] | select(.name==\"$name\") | .status")
            if [[ "$status" == "ACTIVE" ]]; then
                echo -e "Host $name\n\tHostName $ip\n\tUser op\n\tPort 2266\n" >> $sshnew
            fi
        done
    fi
    mv $sshnew $AXIOM_PATH/.sshconfig
}

###################################################################
# 查询实例
# 接受任意数量的参数，每个参数可以是实例名或通配符，如 'omnom*'
# 返回基于查询的已排序实例列表
# 示例: query_instances 'john*' marin39
# 返回: john01 john02 john03 john04 nmarin39
# 用于: axiom-ls axiom-select axiom-fleet axiom-rm axiom-power
#
query_instances() {
    droplets="$(instances)"
    selected=""

    for var in "$@"; do
        if [[ "$var" == "\\*" ]]; then
            var="*"
        fi

        if [[ "$var" == *"*"* ]]; then
            var=$(echo "$var" | sed 's/*/.*/g')
            matches=$(echo "$droplets" | jq -r '.servers[].name' | grep -E "^${var}$")
        else
            matches=$(echo "$droplets" | jq -r '.servers[].name' | grep -w -E "^${var}$")
        fi

        if [[ -n "$matches" ]]; then
            selected="$selected $matches"
        fi
    done

    if [[ -z "$selected" ]]; then
        return 1
    fi

    selected=$(echo "$selected" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    echo -n "${selected}" | xargs
}

###################################################################
# 获取镜像ID
# 用于: axiom-fleet axiom-init
# 参数:
#   $1 - query: 镜像名称查询
# 返回: 匹配的镜像ID
#
get_image_id() {
    query="$1"
    images=$(huaweicloud ims list-images --owner self)
    name=$(echo $images | jq -r '.images[].name' | grep -wx "$query" | tail -n 1)
    id=$(echo $images | jq -r ".images[] | select(.name==\"$name\") | .id")
    echo $id
}

###################################################################
# 管理快照
# 用于: axiom-images
#
# 获取快照的JSON数据
snapshots() {
    huaweicloud ims list-images --owner self
}

# 获取快照列表
# 用于: axiom-images
get_snapshots() {
    header="镜像名称,创建时间,镜像ID,大小(GB)"
    footer="_,_,_,_"
    fields=".images[] | [.name, .created_at, .id, .size] | @csv"
    data=$(snapshots)
    (echo "$header" && echo "$data" | jq -r "$fields" | sort -k1 && echo "$footer") | sed 's/"//g' | column -t -s,
}

# 删除指定名称的快照
# 用于: axiom-images
# 参数:
#   $1 - name: 快照名称
delete_snapshot() {
    name="$1"
    image_id=$(get_image_id "$name")
    huaweicloud ims delete-image --image-id "$image_id"
}

# 创建快照
# 用于: axiom-images
# 参数:
#   $1 - instance: 实例��称
#   $2 - snapshot_name: 快照名称
create_snapshot() {
    instance="$1"
    snapshot_name="$2"
    huaweicloud ims create-image --instance-id "$(instance_id $instance)" --name "$snapshot_name"
}

###################################################################
# 获取区域信息
# 用于: axiom-regions
list_regions() {
    huaweicloud iam list-regions | jq -r '.regions[].id'
}

# 获取区域列表
# 用于: axiom-regions
regions() {
    list_regions
}

###################################################################
# 管理实例电源状态
# 用于: axiom-power
#
# 启动实例
# 参数:
#   $1 - instance_name: 实例名称
poweron() {
    instance_name="$1"
    id=$(instance_id "$instance_name")
    huaweicloud ecs start-instances --instance-ids "$id"
}

# 关闭实例
# 参数:
#   $1 - instance_name: 实例名称
poweroff() {
    instance_name="$1"
    id=$(instance_id "$instance_name")
    huaweicloud ecs stop-instances --instance-ids "$id"
}

# 重启实例
# 参数:
#   $1 - instance_name: 实例名称
reboot() {
    instance_name="$1"
    id=$(instance_id "$instance_name")
    huaweicloud ecs reboot-instances --instance-ids "$id"
}

# 获取实例ID
# 用于: axiom-power axiom-images
# 参数:
#   $1 - name: 实例名称
# 返回: 实例ID
instance_id() {
    name="$1"
    instances | jq -r ".servers[] | select(.name==\"$name\") | .id"
}

###################################################################
# 列出可用的实例规格
# 用于: ax sizes
sizes_list() {
    (
        echo -e "InstanceType\tMemory\tVCPUS\tCost"
        huaweicloud ecs list-flavors | \
        jq -r '.flavors[] | [.name, .ram, .vcpus, ""] | @tsv'
    ) | column -t
}

###################################################################
# 实验性v2功能
# 同时删除多个实例，如果第二个参数设置为 "true"，则不会提示确认
# 用于: axiom-rm --multi
# 参数:
#   $1 - names: 实例名称列表
#   $2 - force: 是否强制删除
delete_instances() {
    names="$1"
    force="$2"
    instance_ids=()
    instance_names=()

    # 将名称转换为数组
    name_array=($names)

    # 获取所有实例信息并按名称过滤
    all_instances=$(huaweicloud ecs list-servers --query "servers[*].[id, name]" --output text)

    # 遍历输出并按提供的名称过滤
    while read -r instance_id instance_name; do
        for name in "${name_array[@]}"; do
            if [[ "$instance_name" == "$name" ]]; then
                instance_ids+=("$instance_id")
                instance_names+=("$instance_name")
            fi
        done
    done <<< "$all_instances"

    # 强制删除：不提示直接删除所有实例
    if [ "$force" == "true" ]; then
        echo -e "${Red}正在删除: ${instance_names[@]}...${Color_Off}"
        huaweicloud ecs delete-servers --server-ids "${instance_ids[@]}" --delete-volume true >/dev/null 2>&1

    # 如果不是强制删除，则逐个提示确认
    else
        # 收集用户确认要删除的实例
        confirmed_instance_ids=()
        confirmed_instance_names=()

        for i in "${!instance_ids[@]}"; do
            instance_id="${instance_ids[$i]}"
            instance_name="${instance_names[$i]}"

            echo -e -n "确定要删除实例 '$instance_name' (ID: $instance_id) 吗？(y/N) - 默认否: "
            read ans
            if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
                confirmed_instance_ids+=("$instance_id")
                confirmed_instance_names+=("$instance_name")
            else
                echo "已取消删除实例 '$instance_name' (ID: $instance_id)。"
            fi
        done

        # 批量删除确认的实例
        if [ ${#confirmed_instance_ids[@]} -gt 0 ]; then
            echo -e "${Red}正在删除: ${confirmed_instance_names[@]}...${Color_Off}"
            huaweicloud ecs delete-servers --server-ids "${confirmed_instance_ids[@]}" --delete-volume true >/dev/null 2>&1
        fi
    fi
} 