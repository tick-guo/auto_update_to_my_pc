#!/bin/bash
cd "$(dirname $0)" || exit 1
bashdir="$(pwd)"

upload_dir="$bashdir/download_store/"
keyfile="$bashdir/sync-passwd"

prepare_cmd(){
    echo "系统版本"
    cat /etc/os-release
    echo "准备阶段"
    echo cur_dir=$(pwd)
    # 机密
    echo "$RSYNC_KEY" > $keyfile
    chmod 600 $keyfile
    #
    echo "列举文件"
    ls -l
    #
    echo "设置时区"
    date
    export TZ='Asia/Shanghai'
    date
    #
    echo env_yml=$env_yml
    #
    type jq
    if [ $? -ne 0 ];then
        yum install -y epel-release
        yum install -y jq
    fi
    #echo "测试ping ipv4"
    #ping -4 -c 2 www.baidu.com
    echo net.ipv6.conf.all.disable_ipv6 = 0 | sudo tee -a /etc/sysctl.conf
    echo net.ipv6.conf.default.disable_ipv6 = 0 | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo "测试ping ipv6"
    ip r
    ping6 -c 2 www.baidu.com
}

#https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository

update_file_use_rsync(){
    echo "推送ALI $upload_dir"
    cd "$upload_dir" || echo cd failed
    # 把就日志拉下来
    rsync -vz -rlptD -P   rsync1@$env_ip::rsync-data/update_date.log /tmp/update_date.log.ali  --password-file="$keyfile"
    echo "时间:$(date +%F_%T)" > "update_date.log"
    echo "统计数据大小:$(du -sh .)" >> "update_date.log"
    find . -type f -printf '%s\t%p\n' >> "update_date.log"
    cat "/tmp/update_date.log.ali" >> update_date.log
    #
    rsync -vz -rlptD -P ./  rsync1@$env_ip::rsync-data --password-file="$keyfile"
    echo ret=$?

}

# rsync through ssh
update_file_tool_ssh(){
    echo "推送PC $upload_dir"
    cd $bashdir
    pckey="$bashdir/pc-key"
    echo "$PC_KEY" > "$bashdir/pc-key"
    #sudo apt install dos2unix -y
    #dos2unix "$bashdir/pc-key"
    chmod 600 "$bashdir/pc-key"
    #
    cd "$upload_dir" || echo cd failed
    #test
    ssh -o StrictHostKeyChecking=no -i $pckey $PC_USER@$PC_IP  'cd'
    # 把就日志拉下来
    rsync -e "ssh -o StrictHostKeyChecking=no -i $pckey " -vz -rlptD -P $PC_USER@$PC_IP:/cygdrive/e/githubsync/datapc/update_date.log ./update_date.log.old
    echo "$(date +%F_%T)" > "update_date.log"
    cat update_date.log.old >> update_date.log
    rm -rf update_date.log.old
    #
    rsync -e "ssh -o StrictHostKeyChecking=no -i $pckey " -vz -rlptD -P ./  $PC_USER@$PC_IP:/cygdrive/e/githubsync/datapc/
    echo ret=$?
    #
    ssh  -i $pckey $PC_USER@$PC_IP  ' icacls  E:\githubsync\datapc /reset /t  > nul '
    cd "$bashdir" || echo cd failed

}


# windows rsync daemon
update_file_rsync_to_pc(){
    ip=$PC_IP
    echo "推送PC $upload_dir"
    cd "$upload_dir" || echo cd failed
    echo "统计数据大小:$(du -sh .)"

    # 把就日志拉下来
    rsync -vzrP   rsync1@$ip::rsync-data/update_date.log "/tmp/update_date.log"  --password-file="$keyfile"
    echo "时间:$(date +%F_%T)" > "update_date.log"
    echo "统计数据大小:$(du -sh .)" >> "update_date.log"
    find . -type f -printf '%s\t%p\n' >> "update_date.log"
    cat "/tmp/update_date.log" >> update_date.log
    #
    rsync -vzrP ./  rsync1@$ip::rsync-data --password-file="$keyfile"
    echo ret=$?
}

# 检测文件是否已经存在，已经存在，就不重复下载了
# return 1 存在， 0 不存在
check_file_is_exist(){
    local name="$1"
    if [[ "$name" == "" ]];then
        return 0
    fi
    echo "check: $name"
    cat "$bashdir/f2.list" | grep  "^$name$"
    if [[ $? == 0 ]];then
        echo "检测到文件存在: $name"
        return 1
    fi
    echo "检测到文件不存在: $name"
    return 0
}


# 通用github下载模板
# bitwarden 文件名不包含版本号，增加 add_tag 标记，来追加版本号
soft_json_config='
[
{"soft_dir_name": "trzsz","soft_repo": "trzsz/trzsz-go","soft_filter": "win.*x86"},
{"soft_dir_name": "legado","soft_repo": "gedoor/legado","soft_filter": ""},
{"soft_dir_name": "notepadpp","soft_repo": "notepad-plus-plus/notepad-plus-plus","soft_filter": "x64.exe"},
{"soft_dir_name": "moonlight","soft_repo": "moonlight-stream/moonlight-qt","soft_filter": "Portable.*x64"},
{"soft_dir_name": "ImageGlass","soft_repo": "d2phap/ImageGlass","soft_filter": "x64.*msi"},
{"soft_dir_name": "bitwarden","soft_repo": "bitwarden/android","soft_filter": "bitwarden.apk", "add_tag": true },
{}
]
'

update_github_soft(){
    local soft_dir_name
    local soft_repo
    local soft_filter

    soft_count=$(echo $soft_json_config | jq 'length')
    for i in $(seq 0 $soft_count)
    do
        soft_dir_name=$(echo $soft_json_config | jq -r ".[$i].soft_dir_name")
        soft_repo=$(echo $soft_json_config | jq -r ".[$i].soft_repo")
        soft_filter=$(echo $soft_json_config | jq -r ".[$i].soft_filter")
        add_tag=$(echo $soft_json_config | jq -r ".[$i].add_tag")
        echo $i: ${soft_dir_name}, ${soft_repo}, ${soft_filter}
        if [[ "$soft_dir_name" == "null" ]];then
            echo "null skip"
            continue
        else
            echo "do it ... ... "
        fi

        echo "开始下载，只打印需要下载的，忽略的不会显示日志"
        cd "$bashdir"
        the_dir="$upload_dir/${soft_dir_name}"
        mkdir -p "$the_dir"

        curl -s https://api.github.com/repos/${soft_repo}/releases?per_page=1 > 1.log
        len=$(jq '.[0].assets' 1.log | jq 'length')
        for i in $(seq 0 $len)
        do
            # 索引是最大长度减 1
            if [ "$i" == "$len" ];then
                break
            fi
            #echo "index=$i"
            browser_download_url=$(jq -r '.[0].assets['$i'].browser_download_url' 1.log)
            name=$(jq -r '.[0].assets['$i'].name' 1.log)
            #
            if [[ "${add_tag}" == "true" ]];then
                tag_tmp=$(jq -r '.[0].name' 1.log)
                to_name=${name}_${tag_tmp}.apk
            else
                to_name=$name
            fi

            #echo "$name => $browser_download_url"
            choice=$(echo "$to_name"  | grep "${soft_filter}" )
            if [ "$choice" == "" ];then
                #echo skip $name
                continue
            fi
            if [[ "$name" == "" || "$browser_download_url" == "" ]];then
                echo "value is none"
                continue
            fi

            echo "符合下载命名：$name"
            check_file_is_exist "${soft_dir_name}/$to_name" && curl -L $browser_download_url -o $the_dir/$to_name

        done
        echo "结束本轮下载"

    done

}


run_zerotier_docker(){
    mkdir -p $bashdir/zerotier
    cd $bashdir/zerotier
    #

    ls -la
    #
    mkdir data
    echo > .env
    echo NETWORK_ID=$NETWORK_ID > .env
    echo ZEROTIER_API_SECRET=$ZEROTIER_API_SECRET > .env
    echo ZEROTIER_IDENTITY_PUBLIC=$ZEROTIER_IDENTITY_PUBLIC > .env
    echo ZEROTIER_IDENTITY_SECRET=$ZEROTIER_IDENTITY_SECRET > .env

    docker-compose up -d
    docker images
    #sleep 5
    docker-compose logs zerotier
    #docker inspect zerotier

    #echo 容器内部
    #docker exec zerotier ip addr
    #docker exec zerotier ping -c 2 8.8.8.8
    #docker exec zerotier ping -c 2 www.baidu.com
    #docker exec zerotier ping -c 2 tb4.fun60.fun
    #docker exec zerotier curl -v tb4.fun60.fun:22
    echo 容器外部
    ip addr
    #ping -c 2 8.8.8.8
    #ping -c 2 www.baidu.com
    #ping -c 2 tb4.fun60.fun
    #curl -v tb4.fun60.fun:22


}

end_clean_file(){
    rm -rf $keyfile
}

do_action-cache(){
    cd "$bashdir"
    mkdir action-cache
    cd "action-cache"
    # 设置到环境变量
    PATH=$(pwd):$PATH
    if [ ! -f docker-compose ];then
        echo download docker-compose
        curl -L "https://github.com/docker/compose/releases/download/v2.32.1/docker-compose-$(uname -s)-$(uname -m)" -o  docker-compose
        chmod 755  docker-compose
    else
        echo docker-compose is cached
    fi

}

check_zerotier_connection(){
    # test internet
    ip=$PC_IP
    local cnt=0
    while true;
    do
        rsync   --list-only --contimeout=1 rsync1@$ip::rsync-data /tmp/ --password-file="$keyfile"
        if [ $? -eq 0 ];then
            echo "连接成功"
            break
        else
            echo zerotier is not ok, wait ...
            sleep 1
        fi
        echo test cnt=$((cnt++))
        if [[ "$cnt" -gt "60" ]];then
            echo "连接超时"
            return 2
        fi
    done
}

get_exist_file_list(){
    cd "$bashdir"
    ip=$PC_IP
    rsync  -r --list-only    rsync1@$ip::rsync-data /tmp/ --password-file="$keyfile" | tee f1.list
    cat f1.list  | cut -c47- | tee f2.list
}

do_main(){
    echo "准备命令环境"
    prepare_cmd
    do_action-cache
    echo "先运行docker以便异步准备网络"
    run_zerotier_docker
    # 失败不反馈到 github，否则会发邮件，挺烦的
    check_zerotier_connection || return 0
    get_exist_file_list
    #
    echo "下载文件"
    echo "通用下载模板"
    update_github_soft
    #
    echo "列举文件"
    find "$upload_dir"
    #
    echo "发送文件到云服务器"
    #update_file_tool
    update_file_use_rsync
    # 通过ssh通道发送，不再使用
    #update_file_tool_ssh
    echo "发送文件到PC"
    update_file_rsync_to_pc
    #
    end_clean_file
}

do_main
echo "----eof----"
