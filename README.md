# MindBurst ✦

**Offline-First Personal Memory & Thought-Capture Assistant for Android and Desktop**

MindBurst is an offline-first mobile application designed to quickly capture raw, unstructured thoughts (via voice or text in casual English or Tanglish) and convert them into structured, actionable memories using a local AI abstraction layer.

---

## 🌟 Key Features

- **💥 Instant Thought Capture ("Burst")**: Capture fleeting thoughts via keyboard or tap-to-speak voice recognition with an animated waveform indicator.
- **🧠 Local AI Breakdown**: Runs offline rule-based heuristic extraction or on-device quantized GGUF neural models (e.g. Gemma 3 4B) with Tanglish and Indian-English support.
- **🛡️ "Understanding" Confirmation Gate**: Review, edit, and categorize memories before committing them to the database. Cancelation cleanly rolls back uncommitted data.
- **🗂️ Lifecycle Retention Policies**: Categorize items as `Temporary` (auto-hidden upon completion), `Keep Until Delete`, or `Permanent`.
- **🔎 Grounded Memory Q&A ("Ask")**: Natural-language conversational search strictly grounded on your saved memories with zero hallucinations.
- **🔒 100% Private & Offline**: SQLite on-device storage with foreign key constraints, migration tracking, and zero cloud dependency.

---

## 🚀 Mobile APK Build (GitHub Actions CI/CD)

This repository includes automated Android APK builds via [GitHub Actions](.github/workflows/build_apk.yml):
1. Pushing to `main` triggers an Ubuntu build runner using Buildozer.
2. The generated `.apk` file is automatically published under the **Actions** tab as an artifact ready for download.

---

## 💻 Running Desktop Preview Locally

Requires Python 3.10:
```bash
# Install dependencies
pip install kivy==2.3.1 kivymd==2.0.0 pillow requests urllib3 asynckivy asyncgui materialyoucolor materialshapes pytest

# Launch mobile portrait preview
python main.py
```
Or double-click `run_desktop.bat` on Windows.

---

## 🧪 Test Suite

Run the full 11-phase test suite (112 tests):
```bash
pytest
```
All 112 unit and integration tests pass with 100% test coverage across all subsystems.
