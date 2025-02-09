#!/bin/bash
cd "$(dirname $0)" || exit 1
bashdir="$(pwd)"

upload_dir="$bashdir/download_store/"
keyfile="$bashdir/sync-passwd"

# 局部测试代码， 最后合并到正式代码

# 通用github下载模板
soft_json_config='
[
{"soft_dir_name": "trzsz","soft_repo": "trzsz/trzsz-go","soft_filter": "win.*x86"},
{"soft_dir_name": "legado","soft_repo": "gedoor/legado","soft_filter": ""},
{"soft_dir_name": "notepadpp","soft_repo": "notepad-plus-plus/notepad-plus-plus","soft_filter": "x64.exe"},
{"soft_dir_name": "moonlight","soft_repo": "moonlight-stream/moonlight-qt","soft_filter": "Portable.*x64"},
{"soft_dir_name": "ImageGlass","soft_repo": "d2phap/ImageGlass","soft_filter": "x64.*msi"},
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
            #echo "$name => $browser_download_url"
            choice=$(echo "$name"  | grep "${soft_filter}" )
            if [ "$choice" == "" ];then
                #echo skip $name
                continue
            fi
            if [[ "$name" == "" || "$browser_download_url" == "" ]];then
                echo "value is none"
                continue
            fi

            echo "符合下载命名：$name"
            check_file_is_exist "${soft_dir_name}/$name" && curl -L $browser_download_url -o $the_dir/$name

        done      
        echo "结束本轮下载"
        
    done 
    
}

update_github_soft

