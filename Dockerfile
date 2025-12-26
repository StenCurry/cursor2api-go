# ================================
# 前端构建阶段
# ================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# 复制前端依赖文件
COPY frontend/package*.json ./

# 安装依赖
RUN npm ci --registry=https://registry.npmmirror.com

# 复制前端源码
COPY frontend/ ./

# 构建前端
RUN npm run build

# ================================
# 后端构建阶段
# ================================
FROM golang:1.22-alpine AS backend-builder

WORKDIR /app

# 安装必要的包
RUN apk add --no-cache git ca-certificates

# 复制 go mod 文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源码
COPY . .

# 构建应用
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o CurryAPI .

# ================================
# 运行阶段
# ================================
FROM alpine:latest

# 安装 ca-certificates 和时区数据
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非 root 用户
RUN adduser -D -g '' appuser

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=backend-builder /app/CurryAPI .

# 复制 jscode 目录（Cursor 环境模拟所需）
COPY --from=backend-builder /app/jscode ./jscode

# 复制前端构建产物到 dist 目录（与 main.go 中的路径一致）
COPY --from=frontend-builder /app/frontend/dist ./dist

# 更改所有者
RUN chown -R appuser:appuser /app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8002

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8002/health || exit 1

# 启动应用
CMD ["./CurryAPI"]
