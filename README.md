# 🔍 SearchGlass

<p align="center">
  A Liquid Glass-inspired search button for the iOS Settings app.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-16-blue?style=for-the-badge&logo=apple" />
  <img src="https://img.shields.io/badge/Jailbreak-Rootless-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Theos-Build-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Architecture-arm64%20%2F%20arm64e-green?style=for-the-badge" />
</p>

---

## ✨ About

**SearchGlass** is a jailbreak tweak that adds a modern, Liquid Glass-inspired search button to the **main screen of the iOS Settings app**.

The project is designed to visually integrate with the native Settings interface while preserving the original iOS search system.

SearchGlass does **not replace the native Settings search interface**.

Instead, the tweak provides an additional search button that acts as a visual entry point to the **real iOS Settings search interface**.

The goal is to make the button feel like a native part of iOS rather than a traditional jailbreak modification.

---

# 🔎 Features

### 🧊 Liquid Glass-inspired interface

SearchGlass uses a translucent glass-style appearance designed to blend with the Settings interface.

The button includes:

- Translucent background
- Background blur
- Glass-like appearance
- Rounded corners
- Refraction / distortion
- Specular highlights
- Dynamic appearance
- Search icon
- Microphone icon
- Search label

All credits from Liquid Glass source goes to Dylv “Liquid (Gl)Ass” tweak.

---

## 📍 Main Settings screen only

The SearchGlass button is designed to appear **only on the main/root screen of the Settings application**.

It should not appear inside individual Settings sections such as:

- Display & Brightness
- Accessibility
- Wallpaper
- Siri & Search
- Battery
- Privacy & Security
- General
- Wi-Fi
- Bluetooth
- and other Settings subpages

This keeps the interface clean and prevents the button from being duplicated throughout the Settings application.

---

# 🪟 Glass Effect

SearchGlass attempts to reproduce several visual characteristics of Apple's modern glass interfaces.

### 💎 Translucency

The button uses a translucent surface instead of a completely opaque background.

This allows the content behind the button to remain partially visible.

### 🌫️ Blur

A blurred background helps integrate the button with the Settings interface.

The blur reacts naturally to the content behind the button.

### 🔮 Refraction

The glass surface includes a refraction/distortion effect.

This effect is intended to simulate the appearance of light passing through a physical glass surface.

The refraction helps distinguish the button from a standard translucent `UIView`.

### ✨ Specular Highlights

SearchGlass also includes visible specular highlighting.

The highlight simulates light reflecting across the glass surface.

The effect is designed to complement the translucent glass rather than completely overpower the native iOS interface.

---

# 🎨 Dynamic Appearance

SearchGlass automatically adapts its content to the current iOS appearance.

## ☀️ Light Mode

When iOS is using Light Mode:

- Search text → Black
- Search icon → Black
- Microphone icon → Black
- Glass appearance → Light/translucent

## 🌙 Dark Mode

When iOS is using Dark Mode:

- Search text → White
- Search icon → White
- Microphone icon → White
- Glass appearance → Dark/translucent

This allows the button to remain readable in both appearance modes.

---

# 🔍 Native iOS Search

The SearchGlass button is connected to the native Settings search interface.

When the button is tapped, it opens the **real iOS Settings search interface**.

SearchGlass does not attempt to create a separate search engine or replace Apple's search controller.

The purpose of the button is simply to provide a custom visual entry point to the existing iOS functionality.

---

# 📱 User Experience

The intended experience is simple:

1. Open **Settings**
2. Stay on the main Settings screen
3. SearchGlass appears near the bottom of the interface
4. Tap the SearchGlass button
5. The native iOS Settings search interface opens

When navigating into another Settings section, SearchGlass should no longer be displayed.

---

# 🛠️ Requirements

SearchGlass is intended for:

- iOS 16
- Jailbroken devices
- Rootless jailbreak environments
- arm64 devices
- arm64e devices
- Theos

Compatibility with other iOS versions may vary because the tweak interacts with private UIKit / Settings classes and methods.

---

# 📦 Installation

Download the latest `.deb` package from the **Releases** section of this repository.

Install the package using your preferred package manager.

Supported installation methods may include:

- Sileo
- Zebra
- Installer
- Manual `.deb` installation

After installation, restart or respring the device if necessary.

---

# 🧰 Building From Source

SearchGlass is built using **Theos**.

Clone the repository:

```bash
git clone https://github.com/YOUR-USERNAME/SearchGlass.git
