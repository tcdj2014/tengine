FROM alpine:3.15.2


ENV TENGINE_VERSION 2.3.3
ENV NGX_DEVEL_KIT_V 0.3.1
ENV NGX_DEVEL_KIT https://github.com/vision5/ngx_devel_kit/archive/v$NGX_DEVEL_KIT_V.tar.gz
ENV LUA_NGINX_MODULE_V 0.10.20
ENV LUA_NGINX_MODULE https://github.com/openresty/lua-nginx-module/archive/v$LUA_NGINX_MODULE_V.tar.gz

RUN rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

ENV CONFIG "\
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
        --with-luajit-lib=/app/luajit/lib \
        --with-luajit-inc=/app/luajit/include/luajit-2.1 \
        --with-lua-inc=/app/luajit/include/luajit-2.1 \
        --with-lua-lib=/app/luajit/lib \
        --with-ld-opt=-Wl,-rpath,/app/luajit/lib \
        --add-module=modules/ngx_http_upstream_check_module \
        --add-module=modules/headers-more-nginx-module-0.33 \
	    --add-module=modules/ngx_http_upstream_session_sticky_module \
        --add-module=modules/ngx_devel_kit-$NGX_DEVEL_KIT_V \
        --add-module=modules/lua-nginx-module-$LUA_NGINX_MODULE_V \
        "
RUN     addgroup -S nginx \
        && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
        && adduser -u 82 -D -S -G www-data www-data \
        && sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
        && apk add --no-cache --virtual .build-deps \
                musl-dev \
                libgcc \
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
                geoip-dev \
                git
#        && wget http://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz -O lua.tar.gz \
#        && tar zxvf lua.tar.gz \
#        && cd LuaJIT-2.1.0-beta3 \
#        && make \
#        && make install PREFIX=/app/luajit \
#        && export LUAJIT_LIB=/app/luajit/lib/ \
#        && export LUAJIT_INC=/app/luajit/include/luajit-2.1/ \
#        && ls -l /app/luajit \
#        && ls -l /app/luajit/lib \
#        && ls -l /app/luajit/include \
#        && ls -l /app/luajit/include/luajit-2.1 \
#        && test -e /app/luajit/lib/libluajit-5.1.so.2 \
#        && ln -s  /app/luajit/lib/libluajit-5.1.so.2 /lib/

RUN     git clone https://github.com/openresty/luajit2.git \
        && cd luajit2 \
        && make \
        && make install PREFIX=/app/luajit \
        && ls -l /app/luajit \
        && ls -l /app/luajit/lib \
        && ls -l /app/luajit/include \
        && ls -l /app/luajit/include/luajit-2.1

RUN     curl -L "https://github.com/alibaba/tengine/archive/$TENGINE_VERSION.tar.gz" -o tengine.tar.gz \
        && mkdir -p /usr/src \
        && tar -zxC /usr/src -f tengine.tar.gz \
        && rm tengine.tar.gz \
        && cd /usr/src/tengine-$TENGINE_VERSION \
        && curl -L "https://github.com/openresty/headers-more-nginx-module/archive/v0.33.tar.gz" -o more.tar.gz \
        && tar -zxC /usr/src/tengine-$TENGINE_VERSION/modules -f more.tar.gz \
	    && rm  more.tar.gz \
	    && wget $NGX_DEVEL_KIT \
        && tar -zxC /usr/src/tengine-$TENGINE_VERSION/modules -f v$NGX_DEVEL_KIT_V.tar.gz \
        && rm v$NGX_DEVEL_KIT_V.tar.gz \
        && wget $LUA_NGINX_MODULE \
        && tar -zxC /usr/src/tengine-$TENGINE_VERSION/modules -f v$LUA_NGINX_MODULE_V.tar.gz \
        && rm v$LUA_NGINX_MODULE_V.tar.gz \
	    && ls -l /usr/src/tengine-$TENGINE_VERSION/modules \
	    && ./configure $CONFIG --with-debug \
        && make -j$(getconf _NPROCESSORS_ONLN) \
        && mv objs/nginx objs/nginx-debug \
        && ls -l objs \
        && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
        && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
        && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
        && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
        && ./configure $CONFIG \
        && make -j$(getconf _NPROCESSORS_ONLN) \
        && make install \
        && rm -rf /etc/nginx/html/ \
        && mkdir /etc/nginx/conf.d/ \
        && mkdir -p /usr/share/nginx/html/ \
        && install -m644 html/index.html /usr/share/nginx/html/ \
        && install -m644 html/50x.html /usr/share/nginx/html/ \
        && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
        && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
        && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
        && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
        && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
        && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
        && strip /usr/sbin/nginx* \
        && strip /usr/lib/nginx/modules/*.so \
        && rm -rf /usr/src/tengine-$NGINX_VERSION \
        \
        # Bring in gettext so we can get `envsubst`, then throw
        # the rest away. To do this, we need to install `gettext`
        # then move `envsubst` out of the way so `gettext` can
        # be deleted completely, then move `envsubst` back.
        && apk add --no-cache --virtual .gettext gettext \
        && mv /usr/bin/envsubst /tmp/ \
        \
        && runDeps="$( \
                scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
                        | tr ',' '\n' \
                        | sort -u \
                        | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
        )" \
        && apk add --no-cache --virtual .nginx-rundeps $runDeps \
        && apk del .build-deps \
        && apk del .gettext \
        && mv /tmp/envsubst /usr/local/bin/ \
        \
        # Bring in tzdata so users could set the timezones through the environment
        # variables
        && apk add --no-cache tzdata \
        \
        # forward request and error logs to docker log collector
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf
COPY proxy.conf /etc/nginx/proxy.conf
COPY ip.conf /etc/nginx/ip.conf
COPY ip.conf.default /etc/nginx/ip.conf.default
COPY confs /etc/nginx/confs

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
