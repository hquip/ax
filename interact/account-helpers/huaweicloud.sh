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
            # 尝试多个安装源
            install_success=false
            
            # 尝试官方源
            if curl -fsSL https://obs.cn-north-4.myhuaweicloud.com/hcloud/cli/latest/hcloud.sh | bash; then
                install_success=true
            fi
            
            # 如果官方源失败，尝试备用源
            if [ "$install_success" = false ]; then
                if curl -fsSL https://mirrors.huaweicloud.com/cli/latest/hcloud.sh | bash; then
                    install_success=true
                fi
            fi
            
            # 如果所有源都失败
            if [ "$install_success" = false ]; then
                echo -e "${BRed}华为云 CLI 安装失败。请检查网络连接或手动安装。${Color_Off}"
                echo -e "${Yellow}手动安装说明：https://support.huaweicloud.com/intl/zh-cn/cli/index.html${Color_Off}"
                exit 1
            fi
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
    while true; do
        echo -e "${BGreen}请访问华为云控制台获取访问密钥: https://console.huaweicloud.com/iam/?locale=zh-cn#/mine/accessKey${Color_Off}"
        echo -e "${Yellow}注意: 每个IAM用户最多可以创建2个有效的访问密钥(AK/SK)${Color_Off}"
        
        # 列出现有的华为云配置
        existing_configs=$(ls -1 "$AXIOM_PATH/accounts/" | grep "huaweicloud.*\.json" | grep -v "\.example" | sed 's/\.json//')
        if [ ! -z "$existing_configs" ]; then
            echo -e "${BGreen}当前已配置的华为云账号:${Color_Off}"
            echo "$existing_configs"
        fi

        # 获取配置文件名称
        echo -e -n "${BWhite}请输入配置文件名称（例如: huaweicloud1, huaweicloud-prod 等，必须全小写且不含特殊字符）\n>> ${Color_Off}"
        read title
        while [[ "$title" == "" ]]; do
            echo -e "${BRed}配置文件名称不能为空${Color_Off}"
            echo -e -n "${BWhite}请输入配置文件名称: \n>> ${Color_Off}"
            read title
        done

        # 检查文件是否已存在
        if [[ -f "$AXIOM_PATH/accounts/$title.json" ]]; then
            echo -e -n "${Yellow}配置文件 '$title' 已存在，是否覆盖？(y/N) ${Color_Off}"
            read ans
            if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
                echo -e "${BRed}操作已取消${Color_Off}"
                continue
            fi
        fi

        # 获取账号配置信息
        echo -e -n "${Green}请输入访问密钥 ID (AK): \n>> ${Color_Off}"
        read ACCESS_KEY
        
        echo -e -n "${Green}请输入访问密钥密码 (SK): \n>> ${Color_Off}"
        read -s SECRET_KEY
        echo
        
        while [[ "$SECRET_KEY" == "" ]]; do
            echo -e "${BRed}请提供华为云访问密钥密码，您的输入为空。${Color_Off}"
            echo -e -n "${Green}请输入访问密钥密码 (SK): \n>> ${Color_Off}"
            read -s SECRET_KEY
            echo
        done
        
        echo -e -n "${Green}请输入项目 ID: \n>> ${Color_Off}"
        read PROJECT_ID
        
        echo -e -n "${Green}请输入区域 (默认: cn-north-4): \n>> ${Color_Off}"
        read REGION
        REGION=${REGION:-cn-north-4}

        # 验证凭证
        echo -e "${BGreen}正在验证凭证...${Color_Off}"
        export HUAWEICLOUD_ACCESS_KEY="$ACCESS_KEY"
        export HUAWEICLOUD_SECRET_KEY="$SECRET_KEY"
        export HUAWEICLOUD_REGION="$REGION"
        export HUAWEICLOUD_PROJECT_ID="$PROJECT_ID"

        if ! hcloud ecs list-flavors &>/dev/null; then
            echo -e "${BRed}凭证验证失败，请检查输入的信息${Color_Off}"
            continue
        fi

        # 创建配置文件
        data="{
            \"provider\": \"huaweicloud\",
            \"access_key\": \"$ACCESS_KEY\",
            \"secret_key\": \"$SECRET_KEY\",
            \"project_id\": \"$PROJECT_ID\",
            \"region\": \"$REGION\",
            \"default_size\": \"s6.small.1\"
        }"

        echo -e "${BGreen}配置信息如下: ${Color_Off}"
        echo "$data" | jq '.secret_key = "*****"'
        
        echo -e -n "${BWhite}是否保存此配置？(Y/n) ${Color_Off}"
        read ans
        if [[ "$ans" == "n" || "$ans" == "N" ]]; then
            echo -e "${BRed}配置未保存${Color_Off}"
            continue
        fi

        echo "$data" | jq '.' > "$AXIOM_PATH/accounts/$title.json"
        echo -e "${BGreen}配置已保存到 $title.json${Color_Off}"
        
        # 询问是否继续添加新账号
        echo -e -n "${BWhite}是否继续添加新的华为云账号？(y/N) ${Color_Off}"
        read continue_add
        if [[ "$continue_add" != "y" && "$continue_add" != "Y" ]]; then
            break
        fi
    done
}

huaweicloudsetup 
