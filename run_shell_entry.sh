#!/bin/bash
cd "$(dirname $0)" || exit 1
workdir="$(pwd)"

source ./secret.env

#env_remote_dir="/e:/githubsync/"
env_remote_dir="/root/githubsync/"
env_local_dir="$workdir/download_store/"

prepare_cmd(){
    echo "设置时区"
    date
    export TZ='Asia/Shanghai'
    date

    echo env_yml=$env_yml

    type jq
    if [ $? -ne 0 ];then
        yum install -y epel-release
        yum install -y jq
    fi
    echo "测试ping ipv6"
    ping -6 -c 2 www.baidu.com
}

#https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository

update_file_use_rsync(){
    echo "推送 $env_local_dir"
    cd "$env_local_dir" || echo cd failed
    chmod 600 id_rsa
    # 把就日志拉下来
    rsync -vz -rlptD -P   rsync1@$env_ip::rsync-data/update_date.log ./update_date.log.old  --password-file="$workdir/id_rsa"
    echo "$(date +%F_%T)" > "update_date.log"
    cat update_date.log.old >> update_date.log
    rm -rf update_date.log.old
    #
    ls -lhR > updatefilelist.log
    rsync -vz -rlptD -P ./  rsync1@$env_ip::rsync-data --password-file="$workdir/id_rsa" | tee -a "$env_local_dir/updatefilelist.log"
    echo ret=$?
    # 再把日志单独推送一次
    rsync -vz -rlptD -P ./updatefilelist.log  rsync1@$env_ip::rsync-data --password-file="$workdir/id_rsa"
    cd "$workdir" || echo cd failed
}

update_file_tool(){
    echo "push $env_local_dir"
    chmod 600 id_rsa
    echo $(date) > "$env_local_dir/date.log"
    ssh -i id_rsa -o StrictHostKeyChecking=no "$env_user@$env_ip" "pwd"
    scp -i id_rsa  -P "$env_port" -r  "$env_local_dir" "$env_user@$env_ip:$env_remote_dir"
}

update_legado(){
    legado="$env_local_dir/legado"
    mkdir -p "$legado"

    curl -s https://api.github.com/repos/gedoor/legado/releases?per_page=1 > 1.log
    len=$(jq '.[0].assets' 1.log | jq 'length')
    for i in $(seq 0 $len)
    do
        # 索引是最大长度减 1
        if [ "$i" == "$len" ];then
            break
        fi
        echo "index=$i"
        browser_download_url=$(jq -r '.[0].assets['$i'].browser_download_url' 1.log)
        name=$(jq -r '.[0].assets['$i'].name' 1.log)
        echo "$name => $browser_download_url"
        if [ "$name" == "" -o "$browser_download_url" == "" ];then
            echo "value is none"
            continue
        fi

        curl -L $browser_download_url -o $legado/$name

    done



}

do_main(){
    echo "prepare cmd"
    prepare_cmd
    echo "download local files"
    update_legado
    echo "list files"
    find "$env_local_dir"
    echo "send all file"
    #update_file_tool
    update_file_use_rsync
}

do_main
echo "----eof----"
