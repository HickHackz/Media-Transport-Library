#!/bin/bash

if [ $# -ne 1 ];then
  echo "wrong command"
  echo "exec: bash build-image.sh \$http_proxy"
  exit
fi

docker build --build-arg http_proxy=$1 -t st2110app:v0.1 ./