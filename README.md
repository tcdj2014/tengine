# tengine

基于 `alpine` 从源码编译 [alibaba/tengine](https://github.com/alibaba/tengine)，产出基础镜像 `tengine:latest`（版本标签 `tengine:<tag>`），
供业务镜像 `FROM` 二次封装（静态资源、反代配置等）。

已编译模块（见 `Dockerfile` 中的 `CONFIG`）：

- `ngx_http_upstream_check_module` 健康检查
- `headers-more-nginx-module 0.37`（`more_clear_headers` 等）
- `ngx_http_upstream_session_sticky_module` 会话保持
- 常规 http/stream/mail 模块 + xslt / image_filter / geoip / stream_geoip 动态模块

`TENGINE_VERSION` 构建参数留空时，自动取 GitHub 最新 release。
CI 不传该参数，因此 **构建的始终是上游最新 release，tag 只是镜像标签**。
需要固定版本时用本地构建传 `--build-arg`。

## 镜像内容

| 项 | 值 |
| --- | --- |
| 可执行文件 | `/usr/sbin/nginx`、`/usr/sbin/nginx-debug` |
| 主配置 | `/etc/nginx/nginx.conf`（由 `base-nginx.conf` 覆盖） |
| 站点配置目录 | `/etc/nginx/conf.d/`（`WORKDIR` 所在，`base-proxy.conf` 在此） |
| 动态模块 | `/usr/lib/nginx/modules/`（xslt / image_filter / geoip / stream_geoip） |
| 运行用户 | `nginx:nginx`；另建 `www-data`（uid 82） |
| 端口 | `80`、`443` |
| 日志 | access / error 软链到 stdout / stderr，交给容器日志驱动 |
| 额外依赖 | `tzdata`、`curl`、`ca-certificates`（支持 `TZ` 时区变量） |
| 信号 | `STOPSIGNAL SIGTERM`，`CMD nginx -g daemon off;` |

镜像不再预建 `/opt/wms-static`、`/opt/ots-static` 之类静态目录，业务镜像按需自行 `mkdir` 或挂载卷。

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
# 指定 tengine 源码版本
docker build --pull --no-cache --build-arg TENGINE_VERSION=3.1.0 -t tengine:latest .
```

## CI 构建

触发条件（workflow 为 `push.tags: '*'`）：

- **推 tag** 才会构建，推 branch **不会**触发
- 也可在 Actions → Tengine-Base → Run workflow 手动触发

### 发布新版本

```shell
git push origin main                 # 先推代码，不触发构建
git tag -a 3.3 -m "tengine 3.3"      # tag 名即镜像版本标签
git push origin 3.3                  # 触发构建
```

产出 `tengine:3.3` 与 `tengine:latest`。

### 覆盖已有版本

改动需要重新产出同名镜像时，强制更新 tag（同样会触发一次新构建）：

```shell
git tag -f -a 3.2 -m "tengine 3.2" HEAD
git push -f origin 3.2
```

注意：

- `tengine:latest` 每次构建都会被覆盖，业务侧引用建议固定版本号（如 `tengine:3.2`）
- 强制覆盖 tag 会改写远端 tag，其他人已经拉取的旧 tag 需要手动更新

需要配置仓库 Variables / Secrets：

| 名称 | 类型 | 说明 |
| --- | --- | --- |
| `ALIYUN_REGISTRY` | Variables | 例如 `registry.cn-hangzhou.aliyuncs.com` |
| `ALIYUN_NAME_SPACE` | Variables | 镜像命名空间 |
| `ALIYUN_REGISTRY_USER` | Secrets | 仓库用户名 |
| `ALIYUN_REGISTRY_PASSWORD` | Secrets | 仓库密码 |

推送结果：`<registry>/<namespace>/tengine:latest` 与 `tengine:<tag>`（如 `tengine:3.2`）。
