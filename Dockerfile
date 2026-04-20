FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1

# 安装 Node.js （满足 >=18）及必要工具
RUN apt-get update \
  && apt-get install -y --no-install-recommends nodejs npm procps \
  && rm -rf /var/lib/apt/lists/*

# 从 uv 官方镜像复制 uv
COPY --from=ghcr.io/astral-sh/uv:0.9.26 /uv /uvx /bin/

WORKDIR /app

# 先复制依赖描述文件以利用缓存
COPY package.json package-lock.json ./
COPY frontend/package.json frontend/package-lock.json ./frontend/
COPY backend/pyproject.toml backend/uv.lock ./backend/

# 安装依赖（Node + Python）
# 生产镜像仅安装运行时依赖，减少体积。
# GPU 相关包（NVIDIA CUDA 运行时、Triton 等）在无 GPU 的容器中不需要，
# 通过 --no-install-package 跳过；torch 改用 CPU-only wheel（约节省 4-5 GB）。
RUN npm ci \
  && npm ci --prefix frontend \
  && cd backend && uv sync --frozen --no-dev \
     --no-install-package torch \
     --no-install-package triton \
     --no-install-package nvidia-cublas-cu12 \
     --no-install-package nvidia-cuda-cupti-cu12 \
     --no-install-package nvidia-cuda-nvrtc-cu12 \
     --no-install-package nvidia-cuda-runtime-cu12 \
     --no-install-package nvidia-cudnn-cu12 \
     --no-install-package nvidia-cufft-cu12 \
     --no-install-package nvidia-cufile-cu12 \
     --no-install-package nvidia-curand-cu12 \
     --no-install-package nvidia-cusolver-cu12 \
     --no-install-package nvidia-cusparse-cu12 \
     --no-install-package nvidia-cusparselt-cu12 \
     --no-install-package nvidia-nccl-cu12 \
     --no-install-package nvidia-nvjitlink-cu12 \
     --no-install-package nvidia-nvshmem-cu12 \
     --no-install-package nvidia-nvtx-cu12 \
  && uv pip install --python .venv/bin/python --no-deps graphiti-core==0.28.2 \
  # camel-oasis==0.2.5 pins neo4j==5.23.0 but graphiti-core==0.28.2 requires >=5.26.0.
  # Force-upgrade neo4j after the frozen sync; the driver API is backward-compatible.
  && uv pip install --python .venv/bin/python "neo4j>=5.26.0" \
  && uv pip install --python .venv/bin/python \
     "torch==2.9.1+cpu" \
     --index-url https://download.pytorch.org/whl/cpu \
  # 依赖安装后立即清理缓存；后续若新增包管理安装步骤，应放在清理前
  && npm cache clean --force \
  && rm -rf /root/.cache

# 复制项目源码
COPY . .

EXPOSE 3000 5001

# 同时启动前后端（开发模式）
CMD ["npm", "run", "dev"]
