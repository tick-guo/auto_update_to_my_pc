@echo on
rem D:\a\auto_update_to_my_pc\auto_update_to_my_pc
echo %CD%
echo %PATH%
CUR=%CD%

call :zerotier-docker-win
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
exit /b

echo "结束2"
