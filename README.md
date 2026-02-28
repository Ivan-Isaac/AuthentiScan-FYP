# AuthentiScan: An AI-Driven Object Recognition Application For Counterfeit Detection

**Author:** Ivan Isaac Lupang  
**Degree:** Bachelor of Software Engineering with Honors (Software Engineering)  
**Institution:** Universiti Malaysia Sarawak (UNIMAS)  
**Year:** 2026

---

## 📌 About The Project
The proliferation of counterfeit goods represents a significant economic challenge and public safety risk in Malaysia. Current enforcement methods rely heavily on manual visual inspection, which is time-consuming and subjective. 

**AuthentiScan** is an AI-driven mobile application designed to assist enforcement officers in the real-time detection of counterfeit mobile accessories (specifically branded chargers and power banks). By employing computer vision, the system identifies macroscopic authentication features such as logo misalignments and text anomalies without the need for proprietary hardware.

### 🎯 Key Objectives
* Develop a mobile application capable of real-time counterfeit object detection.
* Achieve a detection accuracy exceeding 70% mAP using custom-trained models.
* Maintain a response latency of under 5 seconds per scan for efficient field operations.

---

## 🛠️ System Architecture & Tech Stack
This project utilizes a **Hybrid Client-Server Architecture** developed through an Evolutionary Prototyping methodology.

* **Frontend (Mobile App):** `Flutter` / `Dart` 
  * Handles image capture, secure transmission, and result visualization (bounding boxes and confidence scores).
* **Backend (REST API):** `Python` / `Flask` 
  * Manages the intensive computational load of running AI inference and logs scan history.
* **AI Inference Engine:** `YOLOv8` (Ultralytics) 
  * A state-of-the-art, one-stage object detection model optimized for speed and efficiency.
* **Model Training Environment:** `Google Colab` (NVIDIA GPUs)

---

## 📂 Repository Structure
This is a monorepo containing all components of the AuthentiScan system:

```text
📦 AuthentiScan
 ┣ 📂 authentiscan_app      # Flutter mobile application codebase
 ┣ 📂 authentiscan_api      # Python Flask backend server and API
 ┣ 📂 model_training        # Jupyter/Colab notebooks & data prep scripts
 ┣ 📂 docs                  # FYP documentation, diagrams, and slides
 ┗ 📜 README.md
```
---

## 🚀 Future Implementation (FYP 2)

This repository is currently transitioning from the System Design phase (FYP 1) to the Implementation phase (FYP 2).

Upcoming Milestones:

1. Custom dataset construction and annotation for mobile accessories.

2. YOLOv8 model training and hyperparameter tuning.

3. System integration bridging the Flutter client and Flask backend.

4. Performance evaluation and user acceptance testing (UAT).
