# Contributing to PocketMind

First off, thank you for considering contributing to **PocketMind**! 🎉 

PocketMind is built with the mission of bringing completely private, offline, on-device intelligence to every smartphone. We welcome contributions from developers, designers, prompt engineers, and AI researchers around the world.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Adding New GGUF Models](#adding-new-gguf-models)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Message Conventions](#commit-message-conventions)

---

## Code of Conduct

This project and everyone participating in it is governed by the [PocketMind Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing GitHub Issues to see if the issue has already been reported.

When filing a bug report, please include:
- **Device information:** Device model, Android/iOS version, RAM capacity.
- **Model used:** e.g., `Qwen 2.5 0.5B Q4_K_M`, `Gemma 2 2B Q8`.
- **Steps to reproduce:** Detailed step-by-step description.
- **Logs:** Run `flutter run -v` or check terminal output for any crash dumps.

### Suggesting Enhancements

Feature requests are eagerly welcomed! Whether it is adding support for:
- New quantized model architectures (e.g., Llama 3.2, DeepSeek, Phi-3.5)
- Multimodal on-device vision models
- Faster GPU backend acceleration (OpenCL / Vulkan / Metal)
- Audio/Whisper on-device speech-to-text

Please open an issue describing your idea, the rationale, and proposed implementation.

### Adding New GGUF Models

To add support for a new model:
1. Open `lib/model_manager.dart`.
2. Add a new `LocalModel` item to `availableModels` with:
   - Quantized direct download URL (HuggingFace direct resolve link).
   - Filename with `.gguf` extension.
   - Recommended RAM, speed ratings, and descriptive subtitle.
3. Verify that the model runs smoothly on standard test hardware without Out-Of-Memory (OOM) crashes.

---

## Development Setup

1. **Prerequisites:**
   - [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.11.5`)
   - Android Studio / VS Code with Dart & Flutter plugins
   - Android NDK & CMake (for C++ llama.cpp compilation via `fllama`)
   - Physical Android device with at least 4 GB RAM recommended for on-device inference testing

2. **Clone & Install:**
   ```bash
   git clone https://github.com/omavcher/pocketmind-offline-ai.git
   cd pocketmind-offline-ai
   flutter pub get
   ```

3. **Firebase Configuration (Optional):**
   - Copy `android/app/google-services.json.example` to `android/app/google-services.json` or configure with your own Firebase test project.

4. **Run the App:**
   ```bash
   flutter run
   ```

---

## Coding Standards

- Follow official [Effective Dart](https://dart.dev/effective-dart) guidelines.
- Run static analysis before submitting code:
  ```bash
  flutter analyze
  ```
- Keep UI responsive: heavy file parsing and model downloads must not block the main Flutter UI thread.
- Ensure all user data stays strictly on-device. Privacy is the core pillar of PocketMind.

---

## Commit Message Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` A new feature (e.g., `feat(models): add Phi-3.5 mini quant support`)
- `fix:` A bug fix (e.g., `fix(parser): resolve crash on malformed docx files`)
- `docs:` Documentation improvements (e.g., `docs: update setup guide for NDK`)
- `perf:` Performance improvements
- `refactor:` Code restructuring without behavioral changes
- `ui:` Visual adjustments and animation polishing

Thank you for helping make private, offline AI accessible to everyone! 🚀
