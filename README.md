# AuthentiScan: An AI-Driven Object Recognition Application For Counterfeit Detection

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-%2302569B?logo=flutter)](https://flutter.dev)
[![Flask](https://img.shields.io/badge/Backend-Flask-%23000000?logo=flask)](https://flaskproject.net/)
[![YOLOv8](https://img.shields.io/badge/AI%20Engine-YOLOv8-%23006400)](https://github.com/ultralytics/ultralytics)
[![License](https://img.shields.io/badge/Academic-Project-blue)](#)

**Author:** Ivan Isaac Lupang  
**Degree:** Bachelor of Software Engineering with Honors  
**Institution:** Universiti Malaysia Sarawak (UNIMAS)  
**Year:** 2026  
**Project Phase:** Final Year Project (FYP 2) Final Showcase  

---

## 📌 About The Project
The proliferation of counterfeit consumer electronics represents a multi-million dollar economic challenge and a critical public safety hazard in Malaysia. Standard enforcement workflows rely heavily on manual visual inspection by officers, a process that is inherently slow, subjective, and prone to human error. 

**AuthentiScan** solves this bottleneck by providing an AI-driven mobile application designed to assist enforcement officers in the real-time detection of counterfeit mobile accessories (specifically high-risk charging adapters). By employing state-of-the-art computer vision, the system identifies microscopic authentication anomalies—such as typography discrepancies, incorrect regulatory markings, and structural layout deviations—directly from a mobile device without requiring proprietary external hardware.

### 🎯 Key Objectives Achieved
* **Real-Time Edge-Inference:** Developed a high-performance cross-platform mobile application capable of capturing and processing real-time visual feeds.
* **High-Accuracy Differentiation:** Achieved robust classification thresholds using a custom-trained object detection model specifically tuned to look for micro-text anomalies.
* **Low-Latency Architecture:** Maintained an end-to-end processing pipeline latency of under 1.5 seconds per scan over a local area network, optimized for fast-paced field operations.

---

## ⚡ Key Features
* **Dual-Mode Scan Vector:** Supports seamless processing from both a live high-definition device camera feed and high-resolution local gallery image uploads.
* **Dynamic Inverse Scaling:** Implements mathematical bounding-box and text normalization layers to guarantee crisp, legible visual boundaries on-screen regardless of whether the source image resolution is 720p or a native 4K photo.
* **Persistent Network Configuration:** Features local state storage via `shared_preferences` to preserve host backend API endpoints across app lifecycles, enabling instant hot-swapping during live deployment.
* **Native Gestural Interception:** Embedded OS back-button and swipe overrides to preserve the UI state-machine stack, ensuring fluid multi-item scanning routines without application drops.

---

## 🛠️ System Architecture & Tech Stack
AuthentiScan utilizes a **Decoupled Hybrid Client-Server Architecture** designed using an Evolutionary Prototyping methodology to abstract heavy computer vision computations away from mobile hardware constraints.

```text
┌─────────────────────────┐     multipart/form-data     ┌────────────────────────┐
│     Flutter Client      │ ──────────────────────────> │   Python Flask API     │
│ (Camera View / Gallery) │ <────────────────────────── │  (YOLOv8 Inference)    │
└─────────────────────────┘      JSON Payload Response  └────────────────────────┘

```

* **Frontend (Mobile App):** `Flutter` / `Dart`
* Manages camera hardware initialization, layout painting via CustomPainters, state preservation, and asynchronous HTTP networking.


* **Backend (REST API):** `Python` / `Flask`
* Exposes an inference endpoint that ingests image data streams, handles volatile disk storage overhead, and marshals output coordinates.


* **AI Core:** `YOLOv8` (Ultralytics)
* An optimized, single-stage deep learning framework chosen for high inference speed and structural accuracy on small targets.


* **Data Pipelines:** `Roboflow` (Annotation) & `Google Colab` (NVIDIA T4 Accelerated Training).

---

## 📂 Repository Structure

This is a clean monorepo containing all individual microservices and engineering documentation:

```text
📦 AuthentiScan
 ┣ 📂 authentiscan_app      # Flutter cross-platform mobile codebase
 ┣ 📂 authentiscan_api      # Python Flask RESTful backend endpoint logic
 ┣ 📂 model_training        # Jupyter/Colab notebooks & hyperparameter weights
 ┗ 📜 README.md

```

---

## 🚀 Deployment and Setup

### 1. Backend Server Setup

Navigate into the API directory, install dependencies, and spin up the microservice:

```bash
cd authentiscan_api
pip install -r requirements.txt
python app.py

```

### 2. Frontend App Compilation

Ensure you have the Flutter SDK configured, match the backend API's IP address inside the application settings, and build the release variant:

```bash
cd authentiscan_app
flutter clean
flutter pub get
flutter build apk --release

```

Deploy the generated `app-release.apk` found under `build/app/outputs/flutter-apk/` to your target Android device.

---

## 🎓 Academic Disclaimer

This project was developed as an undergraduate Final Year Project (FYP) for the Faculty of Computer Science and Information Technology at Universiti Malaysia Sarawak (UNIMAS). All datasets, hardware test vectors, and operational testing methodologies were simulated for validation purposes within an academic prototyping context.
