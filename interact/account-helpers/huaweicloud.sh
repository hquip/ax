#!/bin/bash

AXIOM_PATH="$HOME/.axiom"
source "$AXIOM_PATH/interact/includes/vars.sh"

token=""
region=""
provider=""
size=""

BASEOS="$(uname)"
case $BASEOS in
'Linux')
    BASEOS='Linux'
    ;;
'FreeBSD')
    BASEOS='FreeBSD'
    alias ls='ls -G'
    ;;
'WindowsNT')
    BASEOS='Windows'
    ;;
'Darwin')
    BASEOS='Mac'
    ;;
'SunOS')
    BASEOS='Solaris'
    ;;
'AIX') ;;
*) ;;
esac

# 检查华为云 CLI 是否安装
installed_version=$(hcloud --version 2>/dev/null | cut -d ' ' -f 3)

# 检查安装的版本是否匹配推荐版本
if [[ "$(printf '%s\n' "$installed_version" "$HcloudCliVersion" | sort -V | head -n 1)" != "$HcloudCliVersion" ]]; then
    echo -e "${Yellow}华为云 CLI 未安装或版本低于 ~/.axiom/interact/includes/vars.sh 中推荐的版本${Color_Off}"

    # 根据操作系统类型处理安装
    if [[ $BASEOS == "Mac" ]]; then
        echo -e "${BGreen}在 macOS 上安装/更新华为云 CLI...${Color_Off}"
        brew install huaweicloud-cli

    elif [[ $BASEOS == "Linux" ]]; then
        if uname -a | grep -qi "Microsoft"; then
            OS="UbuntuWSL"
        else
            OS=$(lsb_release -i 2>/dev/null | awk '{ print $3 }')
            if ! command -v lsb_release &> /dev/null; then
                OS="unknown-Linux"
                BASEOS="Linux"
            fi
        fi

        # 根据具体的 Linux 发行版安装华为云 CLI
        if [[ $OS == "Ubuntu" ]] || [[ $OS == "Debian" ]] || [[ $OS == "Linuxmint" ]] || [[ $OS == "Parrot" ]] || [[ $OS == "Kali" ]] || [[ $OS == "unknown-Linux" ]] || [[ $OS == "UbuntuWSL" ]]; then
            echo -e "${BGreen}在 $OS 上安装/更新华为云 CLI...${Color_Off}"
            curl -fsSL https://cli-repo.huaweicloud.com/cli/install.sh | bash
        elif [[ $OS == "Fedora" ]]; then
            echo -e "${BGreen}在 Fedora 上安装/更新华为云 CLI...${Color_Off}"
            curl -fsSL https://cli-repo.huaweicloud.com/cli/install.sh | bash
        else
            echo -e "${BRed}不支持的 Linux 发行版: $OS${Color_Off}"
        fi
    fi

    echo "华为云 CLI 已更新到版本 $HcloudCliVersion。"
else
    echo "华为云 CLI 已经是推荐版本 $HcloudCliVersion 或更高版本。"
fi

function huaweicloudsetup() {
    echo -e "${BGreen}请访问华为云控制台获取访问密钥: https://console.huaweicloud.com/iam/?locale=zh-cn#/mine/accessKey${Color_Off}"
    
    echo -e -n "${Green}请输入您的华为云访问密钥 ID (必填): \n>> ${Color_Off}"
    read ACCESS_KEY
    while [[ "$ACCESS_KEY" == "" ]]; do
        echo -e "${BRed}请提供华为云访问密钥 ID，您的输入为空。${Color_Off}"
        echo -e -n "${Green}请输入您的访问密钥 ID (必填): \n>> ${Color_Off}"
        read ACCESS_KEY
    done

    echo -e -n "${Green}请输入您的华为云访问密钥密码 (必填): \n>> ${Color_Off}"
    read SECRET_KEY
    while [[ "$SECRET_KEY" == "" ]]; do
        echo -e "${BRed}请提供华为云访问密钥密码，您的输入为空。${Color_Off}"
        echo -e -n "${Green}请输入您的访问密钥密码 (必填): \n>> ${Color_Off}"
        read SECRET_KEY
    done

    echo -e -n "${Green}请输入您的华为云项目 ID (必填): \n>> ${Color_Off}"
    read PROJECT_ID
    while [[ "$PROJECT_ID" == "" ]]; do
        echo -e "${BRed}请提供华为云项目 ID，您的输入为空。${Color_Off}"
        echo -e -n "${Green}请输入您的项目 ID (必填): \n>> ${Color_Off}"
        read PROJECT_ID
    done

    # 配置华为云 CLI
    hcloud configure set ak "$ACCESS_KEY"
    hcloud configure set sk "$SECRET_KEY"
    hcloud configure set project "$PROJECT_ID"
    hcloud configure set output json

    # 列出可用区域
    echo -e "${BGreen}正在列出可用区域...${Color_Off}"
    hcloud ecs list-availability-zones

    default_region="cn-north-4"
    echo -e -n "${Green}请输入您的默认区域（您可以稍后使用 axiom-region select \$region 更改）：默认为 '$default_region'，按回车确认 \n>> ${Color_Off}"
    read region
    if [[ "$region" == "" ]]; then
        echo -e "${Blue}已选择默认选项 '$default_region'${Color_Off}"
        region="$default_region"
    fi

    echo -e -n "${Green}请输入您的默认实例规格（您可以稍后使用 axiom-sizes select \$size 更改）：默认为 's6.small.1'，按回车确认 \n>> ${Color_Off}"
    read size
    if [[ "$size" == "" ]]; then
        echo -e "${Blue}已选择默认选项 's6.small.1'${Color_Off}"
        size="s6.small.1"
    fi

    hcloud configure set region "$region"

    # 打印可用的安全组
    echo -e "${BGreen}正在打印可用的安全组:${Color_Off}"
    hcloud vpc list-security-groups

    # 提示用户输入安全组名称
    echo -e -n "${Green}请输入上面列出的安全组 ID，或按回车创建一个随机名称的新安全组 \n>> ${Color_Off}"
    read SECURITY_GROUP

    # 如果未提供安全组名称，则创建一个新的
    if [[ "$SECURITY_GROUP" == "" ]]; then
        axiom_sg_random="axiom-$(date +%m-%d_%H-%M-%S-%1N)"
        SECURITY_GROUP=$axiom_sg_random
        echo -e "${BGreen}正在创建 Axiom 安全组: ${Color_Off}"
        sg=$(hcloud vpc create-security-group --name "$SECURITY_GROUP" --description "Axiom SG")
        group_id=$(echo "$sg" | jq -r '.security_group.id')
        echo -e "${BGreen}已创建安全组: $group_id ${Color_Off}"
    else
        # 使用现有的安全组
        echo -e "${BGreen}使用安全组: $SECURITY_GROUP ${Color_Off}"
        group_id="$SECURITY_GROUP"
    fi

    # 添加安全组规则
    echo -e "${BGreen}正在添加安全组规则...${Color_Off}"
    hcloud vpc create-security-group-rule \
        --security-group-id "$group_id" \
        --direction ingress \
        --protocol tcp \
        --port-range-min 2266 \
        --port-range-max 2266 \
        --remote-ip-prefix "0.0.0.0/0"

    data="$(echo "{\"access_key\":\"$ACCESS_KEY\",\"secret_key\":\"$SECRET_KEY\",\"project_id\":\"$PROJECT_ID\",\"security_group_id\":\"$group_id\",\"region\":\"$region\",\"provider\":\"huaweicloud\",\"default_size\":\"$size\"}")"

    echo -e "${BGreen}配置文件设置如下: ${Color_Off}"
    echo $data | jq '.secret_key = "*************************************"'
    echo -e "${BWhite}按回车保存到新配置文件，输入 'r' 重新开始。${Color_Off}"
    read ans

    if [[ "$ans" == "r" ]]; then
        $0
        exit
    fi

    echo -e -n "${BWhite}请输入您的配置文件名称（例如 'huaweicloud'，必须全小写且不含特殊字符）\n>> ${Color_Off}"
    read title

    if [[ "$title" == "" ]]; then
        title="huaweicloud"
        echo -e "${BGreen}已命名配置文件为 'huaweicloud'${Color_Off}"
    fi

    echo $data | jq > "$AXIOM_PATH/accounts/$title.json"
    echo -e "${BGreen}已成功保存配置文件 '$title'！${Color_Off}"
    $AXIOM_PATH/interact/axiom-account $title
}

huaweicloudsetup 