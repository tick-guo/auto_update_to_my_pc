#!/bin/bash
cd "$(dirname $0)" || exit 1
bashdir="$(pwd)"

upload_dir="$bashdir/download_store/"
keyfile="$bashdir/sync-passwd"

prepare_cmd(){
    echo "准备阶段"
    echo cur_dir=$(pwd)
    # 机密
    echo "$super_secret" > $keyfile
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
    echo "测试ping ipv6"
    ping -6 -c 2 www.baidu.com
}

#https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository

update_file_use_rsync(){
    echo "推送 $upload_dir"
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

update_file_tool_ssh(){
    echo "push $upload_dir"
    chmod 600 id_rsa
    echo $(date) > "$upload_dir/date.log"
    ssh -i id_rsa -o StrictHostKeyChecking=no "$env_user@$env_ip" "pwd"
    scp -i id_rsa  -P "$env_port" -r  "$upload_dir" "$env_user@$env_ip:/root/xxx/"
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
    echo "send all file"
    #update_file_tool
    update_file_use_rsync
    #
    end_clean_file
}

do_main
echo "----eof----"
