# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Privacy & Security Model

**PocketMind** is built with a **Privacy-First, On-Device** philosophy:
- **Local Inference:** All LLM inference executes completely on the local device via `llama.cpp` bindings. No prompt or chat history is transmitted to cloud servers.
- **Local Documents:** File parsing (PDF, Word, Excel) and OCR (Google ML Kit) operate locally on your phone.
- **Model Integrity:** Models are downloaded directly from trusted HuggingFace GGUF repositories.

## Reporting a Vulnerability

If you discover a security vulnerability or privacy concern within PocketMind, please report it privately:

1. **Do not create a public GitHub issue.**
2. Send an email to the project maintainers or open a private security advisory on GitHub.
3. Include details of the vulnerability, steps to reproduce, and any relevant logs or screen recordings.

We will acknowledge receipt of your vulnerability report within 48 hours and work with you to patch and disclose the issue responsibly.
