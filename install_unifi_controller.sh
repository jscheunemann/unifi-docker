#!/usr/bin/env bash

ARCH=$(docker version --format='{{.Server.Arch}}')

docker load -i mongo-${ARCH}.tar.gz
docker load -i bash-${ARCH}.tar.gz
docker load -i unifi-controller-${ARCH}.tar.gz

docker-compose up -d
