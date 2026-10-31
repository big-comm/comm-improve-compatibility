# comm-improve-compatibility

Compatibility and general improvements package for Manjaro-based distributions, providing custom hooks and optimized configurations for better system integration.

## 📋 Description

The `comm-improve-compatibility` is a utility package that brings together various hooks, scripts, and configurations to improve system compatibility and overall functionality. This package centralizes adjustments that would be too specific to be distributed in separate packages but are important for the overall user experience.

## 🔧 Features

- Custom hooks for system integration
- USB sticks and external disks keep working after a kernel upgrade, until the reboot (`kernel-modules-hook`)
- The GRUB boot loader on disk is reinstalled whenever the `grub` package is upgraded (`install-grub`)
- Optimization and compatibility scripts
- Optimized default configurations
- System adjustments for better performance
- Integrations between different system components

## 📦 Installation

```bash

# Or via package manager
pamac install comm-improve-compatibility
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ✨ Acknowledgments

- Inspired by the biglinux-improve-compatibility package from BigLinux
- Community of developers and users who contribute to the project
