@echo on
rem D:\a\auto_update_to_my_pc\auto_update_to_my_pc
echo %CD%
rem echo %PATH%
set CUR=%CD%

rem call :zerotier-docker-win
call :zerotier-msi-win
echo "结束1"
exit /b

:zerotier-docker-win
    cd zerotier-win
    dir

    mkdir data
    echo > .env
    echo NETWORK_ID=$NETWORK_ID > .env
    echo ZEROTIER_API_SECRET=$ZEROTIER_API_SECRET > .env
    echo ZEROTIER_IDENTITY_PUBLIC=$ZEROTIER_IDENTITY_PUBLIC > .env
    echo ZEROTIER_IDENTITY_SECRET=$ZEROTIER_IDENTITY_SECRET > .env

    rem docker-compose up -d
    docker version
    rem 没有windows的docker镜像  windows/amd64
    docker compose up -d
    docker images
    docker ps
    docker inspect zerotier

    ping  tb4.fun60.fun
exit /b

:zerotier-msi-win
    curl -L https://download.zerotier.com/RELEASES/1.14.2/dist/ZeroTierOne.msi  -o ZeroTierOne.msi
    dir
    rem HOMEDRIVE=C:  HOMEPATH=\Users\runneradmin USERPROFILE=C:\Users\runneradmin

    ZeroTierOne.msi /quiet
    set PATH=C:\Program Files (x86)\ZeroTier\One;%PATH%
    echo 等待服务启动
    sleep 5
    call zerotier-cli.bat info
    echo 修改配置id
    type "C:\ProgramData\ZeroTier\One\identity.public"
    type "C:\ProgramData\ZeroTier\One\identity.secret"
    echo %ZEROTIER_IDENTITY_PUBLIC% > "C:\ProgramData\ZeroTier\One\identity.public"
    echo %ZEROTIER_IDENTITY_SECRET% > "C:\ProgramData\ZeroTier\One\identity.secret"
    type "C:\ProgramData\ZeroTier\One\identity.public"
    type "C:\ProgramData\ZeroTier\One\identity.secret"
    echo 重启服务
    sc stop ZeroTierOneService
    sc start ZeroTierOneService
    sleep 5

    call zerotier-cli.bat info
    call zerotier-cli.bat join %NETWORK_ID%
    call zerotier-cli.bat listnetworks
    call zerotier-cli.bat peers
    echo 等待分配ip
    sleep 5
    call zerotier-cli.bat peers

exit /b

echo "结束2"
