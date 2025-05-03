#!/bin/bash

docker-compose down -v
docker image prune -a -f
docker buildx prune -a -f
