#!/bin/sh
# 编译并安装 tengine 基础镜像内容（在 Dockerfile 的 RUN 中执行）
# 可选构建参数：TENGINE_VERSION（留空则取上游最新正式 release，prerelease 不会被选中）
set -e

CONFIG="
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        --with-cc-opt=-Wno-error=unterminated-string-initialization \
        --add-module=modules/ngx_http_upstream_check_module \
        --add-module=modules/headers-more-nginx-module-0.42 \
        --add-module=modules/ngx_http_upstream_session_sticky_module \
        "

# 未指定 tengine 版本时，取上游最新正式 release（GitHub 的 latest 接口不含 prerelease）
if [ -z "$TENGINE_VERSION" ]; then
    TENGINE_VERSION=$(wget -qO- -t5 -T10 "https://api.github.com/repos/alibaba/tengine/releases/latest" \
        | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
fi
echo "tengine 版本: $TENGINE_VERSION"

# 运行用户
addgroup -S nginx
adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx
adduser -u 82 -D -S -G www-data www-data

# 构建依赖
apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    curl \
    libxslt-dev \
    gd-dev \
    geoip-dev

# 源码与第三方模块
curl -L "https://github.com/alibaba/tengine/archive/$TENGINE_VERSION.tar.gz" -o tengine.tar.gz
mkdir -p /usr/src
tar -zxC /usr/src -f tengine.tar.gz
rm tengine.tar.gz
cd /usr/src/tengine-$TENGINE_VERSION

curl -L "https://github.com/openresty/headers-more-nginx-module/archive/v0.42.tar.gz" -o more.tar.gz
tar -zxC modules -f more.tar.gz
rm more.tar.gz
ls -l modules

# 第一遍：带 --with-debug 编译，保留 debug 版二进制与动态模块
./configure $CONFIG --with-debug
make -j"$(getconf _NPROCESSORS_ONLN)"
mv objs/nginx objs/nginx-debug
mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so
mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so
mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so
mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so

# 第二遍：去掉 debug 编译并安装
./configure $CONFIG
make -j"$(getconf _NPROCESSORS_ONLN)"
make install

# 安装静态页、debug 版二进制与动态模块
rm -rf /etc/nginx/html/
mkdir /etc/nginx/conf.d/
mkdir -p /usr/share/nginx/html/
install -m644 html/index.html /usr/share/nginx/html/
install -m644 html/50x.html /usr/share/nginx/html/
install -m755 objs/nginx-debug /usr/sbin/nginx-debug
install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so
install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so
install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so
install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so
ln -s ../../usr/lib/nginx/modules /etc/nginx/modules
strip /usr/sbin/nginx*
strip /usr/lib/nginx/modules/*.so
rm -rf /usr/src/tengine-$TENGINE_VERSION

# 取出 envsubst，丢弃 gettext 其余部分
apk add --no-cache --virtual .gettext gettext
mv /usr/bin/envsubst /tmp/

# 收集运行期依赖后清理构建依赖
runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                | tr ',' '\n' \
                | sort -u \
                | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
)"
apk add --no-cache --virtual .nginx-rundeps $runDeps
apk del .build-deps
apk del .gettext
mv /tmp/envsubst /usr/local/bin/

# 运行期依赖
apk add --no-cache tzdata
apk add --no-cache curl ca-certificates

# 日志转发给 docker 日志驱动
ln -sf /dev/stdout /var/log/nginx/access.log
ln -sf /dev/stderr /var/log/nginx/error.log

rm -f /tmp/install.sh
