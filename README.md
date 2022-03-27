# Simple docker image of Tengine web server based on Alpine #
***

- [more about Tengine](http://tengine.taobao.org)
- [docs](http://tengine.taobao.org/documentation.html)

in this image added [Upstream check module](http://tengine.taobao.org/document/http_upstream_check.html)

docker-compose:
```
version: "3"

services:
  tengine:
    #image: axizdkr/tengine
    image: tengine:v1.0
    container_name: tengine
    hostname: tengine
    restart: always
    ports:
     - 80:80
    volumes:
     - /etc/timezone:/etc/timezone
     - $PWD/conf/nginx.conf:/etc/nginx/nginx.conf
     - $PWD/conf/proxy.conf:/etc/nginx/proxy.conf
     - $PWD/conf/ip.conf:/etc/nginx/ip.conf
     - $PWD/conf/ip.conf.default:/etc/nginx/ip.conf.default
     - $PWD/conf/confs:/etc/nginx/confs
```

