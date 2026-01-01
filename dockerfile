# Dockerfile
FROM nvidia/cuda:12.6.3-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps
RUN apt-get update && apt-get install --no-install-recommends -y \
    git curl ca-certificates \
    build-essential cmake pkg-config \
    python3 python3-pip python3-venv python3-dev \
    ffmpeg \
 && rm -rf /var/lib/apt/lists/*

# Node.js (UI braucht Node > 18)  [oai_citation:2‡GitHub](https://github.com/ostris/ai-toolkit?utm_source=chatgpt.com)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
 && apt-get update && apt-get install --no-install-recommends -y nodejs \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Repo holen (inkl. Submodules)
ARG AITOOLKIT_REF=main
RUN git clone --recursive https://github.com/ostris/ai-toolkit.git \
 && cd ai-toolkit \
 && git checkout "${AITOOLKIT_REF}" \
 && git submodule update --init --recursive

WORKDIR /app/ai-toolkit

# Torch zuerst (Repo-README empfiehlt Torch separat; Beispiel CU126)  [oai_citation:3‡GitHub](https://github.com/ostris/ai-toolkit?utm_source=chatgpt.com)
# Hinweis: wenn du andere CUDA Wheels willst -> TORCH_INDEX_URL anpassen.
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu126
RUN pip3 install --no-cache-dir --upgrade pip \
 && pip3 install --no-cache-dir torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 --index-url "${TORCH_INDEX_URL}" \
 && pip3 install --no-cache-dir -r requirements.txt

# UI bauen
WORKDIR /app/ai-toolkit/ui
RUN npm ci \
 && npm run build \
 && npm run update_db

# Runtime
EXPOSE 8675
WORKDIR /app/ai-toolkit
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
