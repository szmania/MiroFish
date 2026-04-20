FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1

# 安装 Node.js （满足 >=18）及必要工具
RUN apt-get update \
  && apt-get install -y --no-install-recommends nodejs npm \
  && rm -rf /var/lib/apt/lists/*

# 从 uv 官方镜像复制 uv
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /uvx /bin/

WORKDIR /app

# 先复制依赖描述文件以利用缓存
COPY package.json package-lock.json ./
COPY frontend/package.json frontend/package-lock.json ./frontend/
COPY backend/pyproject.toml backend/uv.lock ./backend/

# 安装依赖（Node + Python）
RUN npm ci \
  && npm ci --prefix frontend \
  # 生产镜像仅安装运行时依赖，减少体积
  && cd backend && uv sync --frozen --no-dev \
  && uv pip install --python .venv/bin/python --no-deps graphiti-core==0.28.2 \
  # 依赖安装后立即清理缓存；后续若新增包管理安装步骤，应放在清理前
  && npm cache clean --force \
  && rm -rf /root/.cache

# 复制项目源码
COPY . .

EXPOSE 3000 5001

# 同时启动前后端（开发模式）
CMD ["npm", "run", "dev"]
