@echo on
rem D:\a\auto_update_to_my_pc\auto_update_to_my_pc
echo %CD%
echo %PATH%

cd zerotier-win
dir

mkdir data
echo > .env
echo NETWORK_ID=$NETWORK_ID > .env
echo ZEROTIER_API_SECRET=$ZEROTIER_API_SECRET > .env
echo ZEROTIER_IDENTITY_PUBLIC=$ZEROTIER_IDENTITY_PUBLIC > .env
echo ZEROTIER_IDENTITY_SECRET=$ZEROTIER_IDENTITY_SECRET > .env

rem docker-compose up -d
docker compose up -d
docker images
sleep 5
docker-compose logs zerotier
docker inspect zerotier

ping  tb4.fun60.fun

echo "结束"
