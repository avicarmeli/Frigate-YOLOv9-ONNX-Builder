# Frigate YOLOv9 ONNX Builder

Build optimized YOLOv9 ONNX models for Frigate (0.16.3) using a reproducible Docker pipeline.

---

## Overview

This repository provides a **fully working pipeline** to build YOLOv9 models in ONNX format for use with Frigate NVR.

### Goals

- Produce **clean single-file ONNX models**
- Allow control over:
  - model size (S / M)
  - input resolution (320 / 416 / 640)
- Ensure compatibility with **Frigate 0.16.3 ONNX detector**

---

## Why Custom Models?

Frigate ships with default models, but building your own allows:

- Better performance tuning (GPU vs CPU)
- Control over resolution vs accuracy
- Smaller models for edge devices
- Reproducible builds

---

## Why ONNX (Frigate 0.16.3)

Frigate 0.16.3+ uses ONNX as the **primary inference backend**.

Benefits:

- Works with **ONNX Runtime (CPU + GPU)**
- No extra conversion steps
- Portable across systems
- Simpler deployment
- Matches Frigate’s current architecture

---

## Model Variants

### YOLOv9 Sizes

| Model | Description |
|------|------------|
| S    | Small, fast, lower accuracy |
| M    | Medium, better accuracy, heavier |

---

### Input Resolutions

| Size | Use Case |
|------|--------|
| 320  | Fastest, lowest accuracy |
| 416  | **Best balance (recommended)** |
| 640  | Highest accuracy, heavier |

---

### Recommendation

> ✅ **yolov9-s-416** is the best general-purpose model  
> It provides excellent performance/accuracy balance for Frigate.

---

## Full Working Build Command

```bash
docker build -f - . --build-arg MODEL_SIZE=s --build-arg IMG_SIZE=416 <<'EOF'
FROM python:3.11 AS build
RUN apt-get update && apt-get install --no-install-recommends -y libgl1 git cmake build-essential && rm -rf /var/lib/apt/lists/*
COPY --from=ghcr.io/astral-sh/uv:0.8.0 /uv /bin/
WORKDIR /yolov9
RUN git clone https://github.com/WongKinYiu/yolov9.git .
RUN uv pip install --system -r requirements.txt
RUN uv pip install --system onnx==1.18.0 onnxruntime==1.17.3 onnx-simplifier==0.4.36 onnxscript
ARG MODEL_SIZE
ARG IMG_SIZE
ADD https://github.com/WongKinYiu/yolov9/releases/download/v0.1/yolov9-${MODEL_SIZE}-converted.pt yolov9-${MODEL_SIZE}.pt
RUN sed -i "s/ckpt = torch.load(attempt_download(w), map_location='cpu')/ckpt = torch.load(attempt_download(w), map_location='cpu', weights_only=False)/g" models/experimental.py
RUN python3 export.py --weights ./yolov9-${MODEL_SIZE}.pt --imgsz ${IMG_SIZE} --simplify --include onnx
FROM scratch
ARG MODEL_SIZE
ARG IMG_SIZE
COPY --from=build /yolov9/yolov9-${MODEL_SIZE}.onnx /yolov9-${MODEL_SIZE}-${IMG_SIZE}.onnx
EOF
