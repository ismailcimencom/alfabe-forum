#!/bin/bash
cd /opt/alfabe-forum

docker compose stop nginx
certbot renew --standalone --quiet
docker compose start nginx
