# 使用极小的 Linux 基础镜像
FROM alpine:3.18

# 设置工作目录
WORKDIR /root

# 拷贝 src 到镜像
COPY src/ ./src/

# 确保可执行文件有执行权限
RUN chmod +x -R ./src
