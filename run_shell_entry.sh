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
    echo "测试ping ipv6"
    ping -6 -c 2 www.baidu.com
}

#https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository

update_file_use_rsync(){
    echo "推送ALI $upload_dir"
    cd "$upload_dir" || echo cd failed
    # 把就日志拉下来
    rsync -vz -rlptD -P   rsync1@$env_ip::rsync-data/update_date.log ./update_date.log.old  --password-file="$keyfile"
    echo "$(date +%F_%T)" > "update_date.log"
    cat update_date.log.old >> update_date.log
    rm -rf update_date.log.old
    #
    ls -lhR > updatefilelist.log
    rsync -vz -rlptD -P ./  rsync1@$env_ip::rsync-data --password-file="$keyfile" | tee -a "$upload_dir/updatefilelist.log"
    echo ret=$?
    # 再把日志单独推送一次
    rsync -vz -rlptD -P ./updatefilelist.log  rsync1@$env_ip::rsync-data --password-file="$keyfile"
    cd "$bashdir" || echo cd failed
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
    ls -lhR > updatefilelist.log
    rsync -e "ssh -o StrictHostKeyChecking=no -i $pckey " -vz -rlptD -P ./  $PC_USER@$PC_IP:/cygdrive/e/githubsync/datapc/ | tee -a "$upload_dir/updatefilelist.log"
    echo ret=$?
    # 再把日志单独推送一次
    rsync -e "ssh -o StrictHostKeyChecking=no -i $pckey " -vz -rlptD -P ./updatefilelist.log  $PC_USER@$PC_IP:/cygdrive/e/githubsync/datapc/
    ssh  -i $pckey $PC_USER@$PC_IP  ' icacls  E:\githubsync\datapc /reset /t  > nul '
    cd "$bashdir" || echo cd failed

}


# windows rsync daemon
update_file_rsync_to_pc(){
    ip=$PC_IP
    echo "推送PC $upload_dir"
    cd "$upload_dir" || echo cd failed
    # test internet
    cnt=0
    while true;
    do
        rsync   --list-only    rsync1@$ip::rsync-data    /tmp/ --password-file="$keyfile"
        if [ $? -eq 0 ];then
            echo connect is ok
            break
        else
            echo zerotier is not ok, wait ...
            sleep 1
        fi
        echo test cnt=$((cnt++))
        if [ "$cnt" -gt "10" ];then
            echo connection is timeout
            return 1
        fi
    done

    # 把就日志拉下来
    rsync -vz -rlptD -P   rsync1@$ip::rsync-data/update_date.log ./update_date.log.old  --password-file="$keyfile"
    echo "$(date +%F_%T)" > "update_date.log"
    cat update_date.log.old >> update_date.log
    rm -rf update_date.log.old
    #
    ls -lhR > updatefilelist.log
    rsync -vz -rlptD -P ./  rsync1@$ip::rsync-data --password-file="$keyfile" | tee -a "$upload_dir/updatefilelist.log"
    echo ret=$?
    # 再把日志单独推送一次
    rsync -vz -rlptD -P ./updatefilelist.log  rsync1@$ip::rsync-data --password-file="$keyfile"
    cd "$bashdir" || echo cd failed
}

update_legado(){
    cd "$bashdir"
    legado="$upload_dir/legado"
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

update_notepadpp(){
    cd "$bashdir"
    the_dir="$upload_dir/notepadpp"
    mkdir -p "$the_dir"

    curl -s https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases?per_page=1 > 1.log
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
        choice=$(echo "$name" | grep x64.exe )
        if [ "$choice" == "" ];then
            echo skip $name
            continue
        fi
        if [ "$name" == "" -o "$browser_download_url" == "" ];then
            echo "value is none"
            continue
        fi

        curl -L $browser_download_url -o $the_dir/$name

    done

}

update_moonlight(){
    cd "$bashdir"
    the_dir="$upload_dir/moonlight"
    mkdir -p "$the_dir"

    curl -s https://api.github.com/repos/moonlight-stream/moonlight-qt/releases?per_page=1 > 1.log
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
        choice=$(echo "$name"  | grep Portable | grep x64 )
        if [ "$choice" == "" ];then
            echo skip $name
            continue
        fi
        if [ "$name" == "" -o "$browser_download_url" == "" ];then
            echo "value is none"
            continue
        fi

        curl -L $browser_download_url -o $the_dir/$name

    done

}


update_ImageGlass(){
    cd "$bashdir"
    the_dir="$upload_dir/ImageGlass"
    mkdir -p "$the_dir"

    curl -s https://api.github.com/repos/d2phap/ImageGlass/releases?per_page=1 > 1.log
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
        choice=$(echo "$name"  | grep x64 | grep msi )
        if [ "$choice" == "" ];then
            echo skip $name
            continue
        fi
        if [ "$name" == "" -o "$browser_download_url" == "" ];then
            echo "value is none"
            continue
        fi

        curl -L $browser_download_url -o $the_dir/$name

    done

}

run_zerotier_docker(){
    mkdir -p $bashdir/zerotier
    cd $bashdir/zerotier
    #
    curl -L "https://github.com/docker/compose/releases/download/v2.32.1/docker-compose-$(uname -s)-$(uname -m)" -o  docker-compose
    chmod 755  docker-compose
    #cp docker-compose /usr/bin/docker-compose
    PATH=$(pwd):$PATH
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

do_main(){
    echo "prepare cmd"
    prepare_cmd
    echo "download local files"
    update_legado
    update_notepadpp
    update_moonlight
    update_ImageGlass

    echo "list files"
    find "$upload_dir"
    #
    run_zerotier_docker
    #
    echo "send all file"
    #update_file_tool
    update_file_use_rsync
    #update_file_tool_ssh
    update_file_rsync_to_pc
    #
    end_clean_file
}

do_main
echo "----eof----"
