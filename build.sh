
---

# 🧪 build.sh (Production Ready)

```bash
#!/usr/bin/env bash

set -e

MODEL_SIZE=${1:-s}
IMG_SIZE=${2:-416}
IMAGE_NAME="yolov9-builder-${MODEL_SIZE}-${IMG_SIZE}"
OUTPUT_FILE="yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx"

echo "=== YOLOv9 ONNX Builder ==="
echo "Model: $MODEL_SIZE"
echo "Image Size: $IMG_SIZE"

# ---- Disk Check ----
FREE_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

if [ "$FREE_GB" -lt 5 ]; then
  echo "❌ Not enough disk space (${FREE_GB}GB available)"
  exit 1
fi

# ---- Optional Cleanup ----
read -p "Clean Docker before build? (y/N): " CLEAN
if [[ "$CLEAN" == "y" || "$CLEAN" == "Y" ]]; then
  docker system prune -a -f
fi

# ---- Build ----
docker build --no-cache -t $IMAGE_NAME -f - . <<EOF
FROM python:3.11 AS build
RUN apt-get update && apt-get install --no-install-recommends -y libgl1 git cmake build-essential && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /bin/
WORKDIR /yolov9
RUN git clone https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system onnx==1.18.0 onnxruntime==1.17.3 onnx-simplifier==0.4.36 onnxscript
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt
RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py
RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz ${IMG_SIZE} --simplify --include onnx
FROM scratch
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /${OUTPUT_FILE}
EOF

# ---- Extract ----
CID=$(docker create $IMAGE_NAME)
docker cp $CID:/$OUTPUT_FILE .
docker rm $CID

# ---- Cleanup Image ----
docker rmi $IMAGE_NAME

echo "✅ Model ready: $OUTPUT_FILE"

# ---- Print Frigate Config ----
echo ""
echo "=== Frigate Config ==="
cat <<CFG
detectors:
  onnx:
    type: onnx
    device: cuda

model:
  path: /models/$OUTPUT_FILE
  width: $IMG_SIZE
  height: $IMG_SIZE
CFG
