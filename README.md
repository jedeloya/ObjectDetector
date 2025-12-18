# ObjectDetector

A **real‑time object detection demo application** built with **Qt (C++/QML)** and **YOLO**, designed to showcase modern C++ architecture, multimedia pipelines, and on‑device ML inference.

This project is intended as:

* 🚀 A **portfolio‑level demo** of what I can build
* 🧩 A **reference implementation** for developers building similar projects
* 📚 An **educational example** of integrating computer vision into Qt apps

---

## ✨ Features

* 🎥 Real‑time camera capture using **Qt Multimedia**
* 🧠 On‑device object detection with **YOLO** (CoreML backend)
* 📦 Batched frame processing for performance
* 📐 Proper letterbox handling and coordinate scaling
* 🔍 Confidence filtering + Non‑Maximum Suppression (NMS)
* 🖼️ Bounding boxes and labels exposed cleanly to **QML**
* ⏱️ Live inference and parsing time metrics

---

## 🏗️ Architecture Overview

```
QML UI
  └── DetectionController (QObject bridge)
        └── CameraModel
              ├── Camera capture
              ├── Frame batching
              ├── CoreML inference
              └── YoloParser
                    ├── Tensor decoding
                    ├── Confidence filtering
                    └── NMS
```

### Key Components

* **DetectionController**
  Acts as the boundary between QML and C++, exposing detections and timing metrics.

* **CameraModel**
  Owns the camera pipeline, batching logic, and ML inference lifecycle.

* **YoloParser**
  Converts raw model output tensors into structured detections with bounding boxes, labels, and scores.

---

## 🧠 Model

* YOLO‑style object detection model
* Output tensor format: `[batch, num_boxes, 5 + num_classes]`
* Designed to be adaptable to **YOLOv5 / YOLOv8‑style outputs**

> The model itself is not included. You can plug in your own CoreML‑converted YOLO model.

---

## 🛠️ Technologies Used

* **C++17**
* **Qt 6** (Qt Multimedia, QML)
* **CoreML** (Apple Silicon / iOS / macOS)
* **YOLO** object detection

---

## 🎯 Goals of This Project

This project demonstrates:

* Clean C++ architecture with clear responsibilities
* Efficient real‑time multimedia processing
* Practical ML inference integration (not a toy example)
* QML ↔ C++ interoperability done right

It is intentionally written to be **readable, extensible, and reusable**.

---

## 🧩 Using This as a Reference

You are encouraged to:

* Reuse parts of the architecture
* Adapt the camera or ML pipeline
* Replace the model backend
* Use this as a starting point for your own computer‑vision apps

If this helps you, ⭐ the repo or reach out.

---

## 📄 License

This project is licensed under **GPL‑3.0**.

---

## 👤 Author

**José de Jesús Deloya Cruz**
Software Engineer | C++ | Qt | Computer Vision | ML

🔗 GitHub: [https://github.com/jedeloya](https://github.com/jedeloya)
