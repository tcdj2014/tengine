# tengine

基于 `alpine` 从源码编译 [alibaba/tengine](https://github.com/alibaba/tengine)，产出基础镜像 `tengine:latest`（版本标签 `tengine:<tag>`），
供业务镜像 `FROM` 二次封装（静态资源、反代配置等）。

已编译模块（见 `Dockerfile` 中的 `CONFIG`）：

- `ngx_http_upstream_check_module` 健康检查
- `headers-more-nginx-module 0.37`（`more_clear_headers` 等）
- `ngx_http_upstream_session_sticky_module` 会话保持
- 常规 http/stream/mail 模块 + xslt / image_filter / geoip 动态模块

`TENGINE_VERSION` 构建参数留空时，自动取 GitHub 最新 release。

## 文件

| 文件 | 说明 |
| --- | --- |
| `Dockerfile` | 编译脚本（先带 debug 编一份，再去掉 debug 编一份安装） |
| `base-nginx.conf` | 主配置，构建时 COPY 到 `/etc/nginx/nginx.conf` |
| `base-proxy.conf` | 反代公共配置，COPY 到 `/etc/nginx/conf.d/` |
| `build.sh` | 本地构建 |
| `.github/workflows/build.yaml` | CI：amd64/arm64 多架构构建并推送到阿里云 |

## 本地构建

```shell
./build.sh
# 指定版本
docker build --pull --no-cache --build-arg TENGINE_VERSION=3.1.0 -t tengine:latest .
```

## CI 构建

- 手动触发：Actions → Tengine-Base → Run workflow
- 推送 `v*` 标签自动触发：`git tag -a v0.1 -m "..." && git push origin v0.1`
  （workflow 的 `push` 只匹配 tag，推 branch 不会触发）

需要配置仓库 Variables / Secrets：

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| `ALIYUN_REGISTRY` | Variables | 例如 `registry.cn-hangzhou.aliyuncs.com` |
| `ALIYUN_NAME_SPACE` | Variables | 镜像命名空间 |
| `ALIYUN_REGISTRY_USER` | Secrets | 仓库用户名 |
| `ALIYUN_REGISTRY_PASSWORD` | Secrets | 仓库密码 |

推送结果：`<registry>/<namespace>/tengine:latest` 与 `tengine:<tag>`（如 `tengine:3.2`）。
