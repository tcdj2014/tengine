## Dockerfile
FROM alpine:3.24

ARG TENGINE_VERSION=

ENV TENGINE_VERSION="${TENGINE_VERSION}" \
  TENGINE_BASEDIR="/etc/nginx/conf.d/"

RUN rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

# 本地打包修改镜像源
# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 编译安装 tengine：configure 参数、debug/正式两遍编译、依赖清理都在 install.sh 里
# 注：Alpine 3.24 为 GCC 15，需 -Wno-error=unterminated-string-initialization（详见 install.sh）
COPY install.sh /tmp/install.sh
RUN sh /tmp/install.sh

EXPOSE 80 443
COPY base-nginx.conf /etc/nginx/nginx.conf
COPY base-proxy.conf ${TENGINE_BASEDIR}/

WORKDIR ${TENGINE_BASEDIR}

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
