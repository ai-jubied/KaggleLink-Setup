# Contributing to KaggleLink

Thank you for your interest in contributing to the KaggleLink project! This document provides guidelines and instructions for contributing.

## Getting Started

1. **Fork the repository** to your GitHub account
2. **Clone your fork** to your local machine
3. **Create a new branch** for your feature or bugfix: `git checkout -b feature/your-feature-name`

## Development Setup

1. **Set up your environment:**
   ```bash
   # Clone the repository
   git clone https://github.com/ai-jubied/KaggleLink-Setup.git
   cd kagglelink
   
   # Make scripts executable
   chmod +x *.sh
   ```

2. **Test your changes:**
   To test your changes, you can build a Docker container:
   ```bash
   docker build -t kagglelink-test \
     --build-arg AUTH_KEYS_URL_ARG=your-public-key-url \
     --build-arg ZROK_TOKEN_ARG=your-zrok-token .
   
   docker run -it kagglelink-test
   ```

## Submitting Changes

1. **Commit your changes** with a clear commit message
   ```bash
   git commit -m "Add feature: concise description of your changes"
   ```

2. **Push your branch** to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create a Pull Request** from your branch to the main repository's main branch

## Code Style Guidelines

- Use clear, descriptive variable and function names
- Add comments for complex sections of code
- Follow the existing code style and structure
- Test your changes thoroughly before submitting

## Issues and Feature Requests

- Check the existing issues before creating a new one
- Provide clear steps to reproduce any bugs
- For feature requests, explain the use case and benefits

## Code of Conduct

- Be respectful and inclusive in all communications
- Help others learn and grow through constructive feedback
- Focus on the problem, not the person

Thank you for contributing to KaggleLink and helping make it better for everyone! 