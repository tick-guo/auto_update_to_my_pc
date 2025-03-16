#!/bin/bash 

# 分段写法 
#curl https://ftp.mozilla.org/pub/fenix/releases/ > 1.log
#cat 1.log  | grep fenix | grep -v beta | grep -vE "b[0-9]" > 2.log
#cat 2.log  |  grep -Po '\d+\.\d+\.\d+|\d+\.\d+' > 3.log
#vermax=$(cat 3.log | sort -V | tail -n1)
# 合并写法
vermax=$(curl https://ftp.mozilla.org/pub/fenix/releases/    | grep fenix | grep -v beta | grep -vE "b[0-9]"  |  grep -Po '\d+\.\d+\.\d+|\d+\.\d+'  | sort -V | tail -n1 )
echo firefox android vermax=$vermax
if [ "$vermax" != "" ];then
    wget https://ftp.mozilla.org/pub/fenix/releases/${vermax}/android/fenix-${vermax}-android-arm64-v8a/fenix-${vermax}.multi.android-arm64-v8a.apk
else 
    echo vermax is null
fi

