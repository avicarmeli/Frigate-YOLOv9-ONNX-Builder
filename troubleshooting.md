# Troubleshooting

This document covers real-world issues encountered when building and using YOLOv9 ONNX models for Frigate.

> ✅ Verified working with **Frigate 0.16.3**

---

## 🔴 Build Issues

### Build Fails Randomly / Inconsistently

**Symptoms:**
- Build fails mid-way
- Same command sometimes works, sometimes doesn't

**Cause:**
Docker layer caching or partial dependency states

**Solution:**
```bash
docker build --no-cache ...
```

---

### HEREDOC Build Fails

**Symptoms:**
- Docker build exits immediately
- Syntax errors or missing instructions

**Cause:**
Incorrect HEREDOC formatting

**Rules:**
- Must use quotes:
  ```bash
  <<'EOF'
  ```
- `EOF` must start at column 0 (no spaces)
- No trailing characters after `EOF`

---

### Docker Context Errors

**Symptoms:**
- Build cannot find files
- Strange path-related errors

**Cause:**
Using `~` instead of `.` as build context

**Correct:**
```bash
docker build -f - .
```

---

### Disk Space Exhausted

**Symptoms:**
- Build fails with no clear error
- "no space left on device"

**Solution:**
```bash
docker system prune -a
df -h
```

---

### torch.load Error

**Cause:**
PyTorch behavior change

**Fix (already in pipeline):**
```python
weights_only=False
```

---

## 🟡 Model Export Issues

### ONNX Export Produces `.data` File

**Problem:**
Frigate 0.16.3 does **NOT reliably handle external ONNX data files**

**Solution:**
- Use this pipeline only
- Ensure single `.onnx` output

---

### ONNX Model Too Large

**Fix:**
Use:
```bash
MODEL_SIZE=s IMG_SIZE=416
```

---

## 🔵 Docker Extraction Issues

### Cannot Find Model File

Check:
```bash
docker run --rm -it <image> ls /
```

Expected:
```
/yolov9-s-416.onnx
```

---

## 🟢 Frigate Issues (0.16.3 Specific)

### Model Not Loading

Check:
```yaml
model:
  path: /models/yolov9-s-416.onnx
```

And:
```yaml
volumes:
  - ./models:/models
```

---

### Detector Not Using GPU

```yaml
detectors:
  onnx:
    type: onnx
    device: cuda
```

Check:
```bash
nvidia-smi
```

---

### Frigate Crashes

Likely causes:
- invalid ONNX
- wrong resolution
- corrupted file

**Fix:**
Rebuild + replace model

---

## ⚙️ Performance Issues

### Recommended Setup

- Model: `yolov9-s-416.onnx`
- Frigate: 0.16.3
- GPU: RTX 3060

---

## 🧠 Best Practices

- Always build with `--no-cache`
- Keep >5GB free disk
- Avoid `.data` models
- Use 416 resolution

---

## 📌 Recovery Steps

```bash
docker system prune -a
./build.sh s 416
```

Restart Frigate.

---

## 💬 Notes

This pipeline is tested specifically with **Frigate 0.16.3**.

Newer versions may behave differently.
