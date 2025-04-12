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
    ping6 -c 2 ftp.mozilla.org
}

#https://docs.github.com/en/rest/releases/releases?apiVersion=2022-11-28#list-releases-for-a-repository
# windows rsync daemon
update_file_rsync_to_pc(){
    ip=$PC_IP
    echo "推送PC $upload_dir"
    cd "$upload_dir" || echo cd failed
    echo "统计数据大小:$(du -sh .)"

    # 把就日志拉下来
    rsync -vzrP   rsync1@$ip::rsync-data/update_date.log "/tmp/update_date.log"  --password-file="$keyfile"
    # 产生新的日志
    echo "时间:$(date +%F_%T)" > "update_date.log"
    echo "统计数据大小:$(du -sh .)" >> "update_date.log"
    find . -type f -printf '%s\t%p\n' >> "update_date.log"
    echo "============================分割线================================" >> "update_date.log"
    # 追加原始日志在后面
    cat "/tmp/update_date.log" >> update_date.log
    # 再把日志推送回电脑
    rsync -vzrP ./  rsync1@$ip::rsync-data --password-file="$keyfile"
    echo ret=$?
}



# 通用github下载模板
# bitwarden 文件名不包含版本号，增加 add_tag 标记，来追加版本号
soft_json_config='
[
{"soft_dir_name": "trzsz","soft_repo": "trzsz/trzsz-go","soft_filter": "win.*x86"},
{"soft_dir_name": "trzsz","soft_repo": "trzsz/trzsz-go","soft_filter": "linux.*x86"},

{"soft_dir_name": "trzsz-ssh","soft_repo": "trzsz/trzsz-ssh","soft_filter": "win.*x86"},
{"soft_dir_name": "trzsz-ssh","soft_repo": "trzsz/trzsz-ssh","soft_filter": "linux.*x86"},

{"soft_dir_name": "legado","soft_repo": "gedoor/legado","soft_filter": ""},
{"soft_dir_name": "notepadpp","soft_repo": "notepad-plus-plus/notepad-plus-plus","soft_filter": "x64.exe"},
{"soft_dir_name": "moonlight","soft_repo": "moonlight-stream/moonlight-qt","soft_filter": "Portable.*x64"},
{"soft_dir_name": "ImageGlass","soft_repo": "d2phap/ImageGlass","soft_filter": "x64.*msi"},
{"soft_dir_name": "bitwarden","soft_repo": "bitwarden/android","soft_filter": "bitwarden.apk", "add_tag": true },
{"soft_dir_name": "LibChecker","soft_repo": "LibChecker/LibChecker","soft_filter": "apk"},
{"soft_dir_name": "Win32-OpenSSH","soft_repo": "PowerShell/Win32-OpenSSH","soft_filter": "Win64", "add_tag": true },
{"soft_dir_name": "v2rayN","soft_repo": "2dust/v2rayN","soft_filter": "^(?=.*windows)(?=.*desktop)(?!.*arm).+", "add_tag": true },
{"soft_dir_name": "my-win-openssh","soft_repo": "tick-guo/openssh-portable","soft_filter": ""},
{}
]
'


DB_FILE="/tmp/_db/db.sqlite3"
function insert_line(){

echo > /tmp/insert.sql
echo "
INSERT INTO software_versions (
    soft_desc,
    soft_dir,
    soft_file,
    md5sum,
    file_size,
    url
) VALUES (
    '$1',  -- 描述
    '$2', -- dir or mode
    '$3',  -- file
    '$4',  -- 32位MD5示例
    '$5', -- file_size
    '$6'  -- url
); " > /tmp/insert.sql
cat /tmp/insert.sql
sqlite3 "$DB_FILE"  < /tmp/insert.sql
return $?
}

function db_check_url_exist(){
    echo > /tmp/count.sql
    echo " select count(1) from software_versions where url = '$1';"  > /tmp/count.sql
    count=$(sqlite3 "$DB_FILE"  < /tmp/count.sql)
    if [ $? -eq 0 ];then
        echo count=$count
        if [ "$count" == 0 ];then
            echo "需要下载"
        else
            echo "不需要下载"
        fi
        return $count
    else
        # 0 就需要下载
        echo "需要下载"
        return 0
    fi
}

test1(){
insert_line "描述" "dir" "file" "md5" "1234" "url"
}


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
                # 文件名 无后缀 不包含点号
                begin_name="${name%.*}"
                # 后缀 不包含点号
                end_type="${name##*.}"
                tag_tmp=$(jq -r '.[0].tag_name' 1.log)
                if [[ "$tag_tmp" == "" ]];then
                    tag_tmp=$(jq -r '.[0].name' 1.log)
                fi

                to_name="${name}_${tag_tmp}.${end_type}"
            else
                to_name=$name
            fi

            #echo "$name => $browser_download_url"
            choice=$(echo "$to_name"  | grep -Pi "${soft_filter}" )
            if [ "$choice" == "" ];then
                #echo skip $name
                continue
            fi
            if [[ "$name" == "" || "$browser_download_url" == "" ]];then
                echo "value is none"
                continue
            fi

            echo "符合下载命名：$name"
            # 用下载地址来判断应该准确， 会不会不同的包更新到同样的地址？
            db_check_url_exist "$browser_download_url"
            if [ $? -eq 0 ];then

                curl -L $browser_download_url -o "$the_dir/$to_name"
                md5=$(md5sum "$the_dir/$to_name" | awk '{print $1}')
                size=$(stat --format=%s "$the_dir/$to_name" )
                insert_line "描述:$soft_dir_name" "$soft_dir_name" "$to_name" "$md5" "$size" "$browser_download_url"
                if [ $? -ne 0 ];then
                    echo "sql insert error "
                fi
            fi

        done
        echo "结束本轮下载"

    done

}

# firefox 定制， 没有在github上
firefox_android_download(){
    echo 准备目录
    local soft_dir_name="firefox_android"
    echo ${soft_dir_name}
    echo "开始下载，只打印需要下载的，忽略的不会显示日志"
    cd "$bashdir"
    the_dir="$upload_dir/${soft_dir_name}"
    mkdir -p "$the_dir"
    echo 检测版本
    vermax=$(curl https://ftp.mozilla.org/pub/fenix/releases/    | grep fenix | grep -v beta | grep -vE "b[0-9]"  |  grep -Po '\d+\.\d+\.\d+|\d+\.\d+'  | sort -V | tail -n1 )
    echo firefox android vermax=$vermax
    if [ "$vermax" != "" ];then
        #wget https://ftp.mozilla.org/pub/fenix/releases/${vermax}/android/fenix-${vermax}-android-arm64-v8a/fenix-${vermax}.multi.android-arm64-v8a.apk
        browser_download_url="https://ftp.mozilla.org/pub/fenix/releases/${vermax}/android/fenix-${vermax}-android-arm64-v8a/fenix-${vermax}.multi.android-arm64-v8a.apk"
    else
        echo vermax is null
        return
    fi
    echo 文件名
    name="fenix-${vermax}.multi.android-arm64-v8a.apk"
    to_name=$name
    #
    echo "符合下载命名：$name"
    cd "$the_dir" || exit 1
    db_check_url_exist "$browser_download_url"
    if [ $? -eq 0 ];then
        wget "$browser_download_url"
        md5=$(md5sum "$name" | awk '{print $1}')
        size=$(stat --format=%s "$name" )
        insert_line "描述:$soft_dir_name" "$soft_dir_name" "$to_name" "$md5" "$size" "$browser_download_url"
        if [ $? -ne 0 ];then
            echo "sql insert error "
        fi
    fi

    echo "结束本轮下载"
}

run_zerotier_docker(){
    mkdir -p $bashdir/zerotier
    cd $bashdir/zerotier || exit 1
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




pull_db_and_check(){
    cd "$bashdir" || exit 1
    local ip=$PC_IP
    rsync -vzrP   rsync1@$ip::rsync-data/_db/db.sqlite3  "/tmp/_db/"  --password-file="$keyfile"
    rsync -vzrP   rsync1@$ip::rsync-data/_db/db.md5      "/tmp/_db/"  --password-file="$keyfile"
    ls -l "/tmp/_db/"
    md51=$(md5sum "/tmp/_db/db.sqlite3" | awk '{print $1}')
    md52=$(cat "/tmp/_db/db.md5" | awk '{print $1}')
    if [ "$md51" != "$md52" ];then
        echo "db check error"
        exit 1
    else
        echo "db check success"
    fi
}

push_db_and_check(){
    cd "$bashdir" || exit 1
    local ip=$PC_IP
    rsync -vzrP "/tmp/_db/db.sqlite3"  rsync1@$ip::rsync-data/_db/ --password-file="$keyfile"
    md5sum "/tmp/_db/db.sqlite3" > "/tmp/_db/db.md5"
    rsync -vzrP "/tmp/_db/db.md5"  rsync1@$ip::rsync-data/_db/ --password-file="$keyfile"
}

do_main(){
    echo "准备命令环境"
    prepare_cmd
    do_action-cache
    echo "先运行docker以便异步准备网络"
    run_zerotier_docker
    # 失败不反馈到 github，否则会发邮件，挺烦的
    check_zerotier_connection || return 0

    #
    pull_db_and_check
    #
    echo "下载文件"
    echo "通用下载模板"
    update_github_soft
    firefox_android_download
    #
    echo "列举文件"
    find "$upload_dir"
    #
    echo "发送文件到PC"
    update_file_rsync_to_pc
    #
    push_db_and_check
    #
    end_clean_file
}

do_main
echo "----eof----"
