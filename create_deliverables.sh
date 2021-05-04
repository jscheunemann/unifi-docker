#!/usr/bin/env bash

ARCH=$(docker version --format='{{.Server.Arch}}')

docker build -t unifi-controller .
docker pull mongo:3.6
docker pull bash:latest

docker tag unifi-controller:latest scheunemann/unifi-controller
docker tag mongo:3.6 scheunemann/mongo
docker tag bash:latest scheunemann/bash

docker save scheunemann/unifi-controller | gzip > unifi-controller-${ARCH}.tar.gz
docker save scheunemann/mongo | gzip > mongo-${ARCH}.tar.gz
docker save scheunemann/bash | gzip > bash-${ARCH}.tar.gz

tar czvf unifi-controller.tgz install_unifi_controller.sh docker-compose.yml Dockerfile unifi-controller-${ARCH}.tar.gz mongo-${ARCH}.tar.gz bash-${ARCH}.tar.gz
