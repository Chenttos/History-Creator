

# 🔍 SearchGlass
<p align="center">
  <strong>A Liquid Glass-inspired search button for the iOS Settings app.</strong>
</p>
<p align="center">
  <img src="https://img.shields.io/badge/iOS-16-blue?style=for-the-badge&logo=apple" />
  <img src="https://img.shields.io/badge/Jailbreak-Rootless-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Theos-Build-orange?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Architecture-arm64%2Farm64e-green?style=for-the-badge" />
</p>
---
## ✨ About
**SearchGlass** is a jailbreak tweak that adds a modern, Liquid Glass-inspired search button to the **main screen of the iOS Settings app**.
The goal of the project is to recreate the visual language of Apple's modern translucent interfaces while keeping the native Settings experience intact.
Instead of replacing the native Settings search system, SearchGlass provides an additional visual entry point that interacts with the **real iOS Settings search interface**.
The tweak is designed to feel like it belongs inside iOS rather than looking like a traditional jailbreak modification.
---
# 🫧 Features
## 🔍 Glass Search Button
SearchGlass adds a dedicated glass-style search button to the bottom portion of the main Settings screen.
The button includes:
- Liquid Glass-inspired transparency
- Background blur
- Translucency
- Refraction/distortion
- Highlighting
- Rounded corners
- Dynamic appearance
- Search icon
- Microphone icon
- Search label
The visual effect is designed to react naturally with the content behind the button.
---
## ✨ Liquid Glass Appearance
SearchGlass attempts to reproduce several characteristics associated with Apple's Liquid Glass visual design.
### 🫧 Blur
The button uses a translucent blurred background rather than a completely opaque color.
This allows the Settings content behind the button to remain partially visible.
### 🔮 Refraction
The glass layer includes a refraction/distortion effect intended to create the appearance of light passing through a physical glass surface.
This helps separate the button from a normal translucent `UIView`.
### ✨ Specular Highlights
SearchGlass also includes visible specular highlighting.
The highlight is intended to simulate light reflecting across the surface of the glass.
The highlight dynamically follows the appearance of the interface and is designed to remain subtle enough to preserve the native iOS aesthetic.
---
# 🎨 Dynamic Appearance
SearchGlass automatically adapts to the current iOS appearance.
## ☀️ Light Mode
When iOS is using Light Mode:
```text
Text       → Black
Search     → Black
Microphone → Black
Glass      → Light/translucent

🌙 Dark Mode

When iOS is using Dark Mode:

Text       → White
Search     → White
Microphone → White
Glass      → Dark/translucent

This allows the button to remain readable regardless of the current system appearance.

No manual configuration is required.

⸻

🏠 Main Settings Screen Only

One of the most important design decisions in SearchGlass is that the custom search button is intended to appear only on the main Settings screen.

It should not remain visible while navigating through individual Settings sections.

For example:

Settings
│
├── Display & Brightness
│   └── SearchGlass hidden
│
├── Accessibility
│   └── SearchGlass hidden
│
├── Wallpaper
│   └── SearchGlass hidden
│
├── Battery
│   └── SearchGlass hidden
│
└── Main Settings page
    └── SearchGlass visible

This prevents the tweak from cluttering every Settings page.

⸻

🔎 Native iOS Search

SearchGlass does not attempt to create a completely separate Settings search engine.

When the button is tapped, it is intended to open the native iOS Settings search interface.

This means the search experience remains compatible with the actual Settings application.

Conceptually:

┌──────────────────────────────┐
│           Settings           │
│                              │
│  Display & Brightness        │
│  Home Screen                 │
│  Accessibility               │
│  Wallpaper                   │
│  Siri & Search               │
│  Battery                     │
│                              │
│        ┌──────────────┐      │
│        │ 🔍 Search 🎙 │      │
│        └──────────────┘      │
└──────────────────────────────┘
                 │
                 ▼
        Native iOS Search

⸻

🎯 Design Goals

SearchGlass was designed around several principles.

1. Keep the native Settings experience

The tweak should enhance Settings rather than completely redesign it.

2. Use the native search system

The custom button should act as an entry point to Apple’s existing search interface.

3. Stay visually consistent

The button dynamically adapts to Light and Dark Mode.

4. Avoid unnecessary UI

The button should only be present where it makes sense: the main Settings page.

5. Recreate modern glass effects

Blur, translucency, refraction and specular highlights are used to create a more realistic glass surface.

⸻

📱 Compatibility

SearchGlass is primarily designed for:

* iOS 16
* Jailbroken devices
* Rootless jailbreak environments
* Settings.app

The tweak was developed and tested around the iOS 16 UIKit/Settings environment.

Compatibility with other iOS versions may vary.

Because Settings uses private classes and implementation details, Apple changing internal APIs can potentially affect compatibility.

⸻

🧩 Jailbreak Compatibility

SearchGlass is designed for modern rootless jailbreak environments.

The package is intended to be installed through jailbreak package managers such as:

* Sileo
* Zebra
* Installer

The exact compatibility depends on the jailbreak and iOS version being used.

⸻

📦 Installation

Method 1 — Package Manager

Download the latest .deb release from the GitHub Releases page.

Then install it using your preferred package manager.

Supported package managers may include:

* Sileo
* Zebra
* Installer

After installation, restart or respring the affected UI if necessary.

⸻

Method 2 — Manual Installation

The .deb package can also be installed manually from a terminal environment.

For example:

dpkg -i SearchGlass.deb

If dependencies need to be configured afterward:

apt-get install -f

Then restart the relevant process or respring the device.

⚠️ The exact installation command may vary depending on the jailbreak environment.

⸻

🛠️ Building From Source

SearchGlass is built using Theos.

A typical development environment includes:

* Theos
* iOS SDK
* Clang
* Make
* A jailbroken test device

Clone the repository:

git clone https://github.com/winaviation-tweaks/SearchGlass.git

Enter the project directory:

cd SearchGlass

Then build the package:

make package

For a rootless jailbreak package:

make package THEOS_PACKAGE_SCHEME=rootless

The generated .deb package will be available in the project’s packages directory.

⸻

🔧 Project Structure

A typical SearchGlass project contains files similar to:

SearchGlass/
│
├── Makefile
├── control
├── Tweak.xm
│
├── layout/
│   └── ...
│
├── .github/
│   └── workflows/
│       └── ...
│
└── packages/
    └── SearchGlass.deb

The primary tweak implementation is contained in:

Tweak.xm

⸻

🧪 Development

SearchGlass uses Objective-C/Objective-C++ tweak code to interact with UIKit and the Settings application.

The project relies on runtime hooks to integrate the custom interface into Settings.

Because Settings contains private implementation details, some functionality may depend on the exact iOS build.

⸻

⚠️ Important Notes

SearchGlass modifies the behavior and appearance of Apple’s Settings application.

It may rely on private classes, methods, or implementation details that are not part of Apple’s public SDK.

Therefore:

* Compatibility is not guaranteed across iOS versions.
* Future iOS updates may break functionality.
* Settings may change its internal view hierarchy.
* Some jailbreak environments may require additional adjustments.
* The tweak should be tested on a secondary/test device when possible.

⸻

🐛 Known Limitations

Because SearchGlass integrates directly with Settings, there are several potential limitations.

Settings updates

Apple can change the Settings UI in future iOS versions.

A new Settings version may require the tweak to be updated.

Private APIs

Some functionality depends on private iOS implementation details.

Jailbreak differences

Different jailbreaks can provide different runtime environments.

A tweak working correctly on one jailbreak may require adjustments on another.

⸻

🧑‍💻 Contributing

Contributions are welcome.

If you find a bug, please open an issue and include as much information as possible.

Useful information includes:

iOS version:
iOS build:
Device:
Jailbreak:
Jailbreak version:
SearchGlass version:

If possible, also provide:

* A screenshot
* A crash log
* Console output
* Steps to reproduce the problem

⸻

💡 Feature Requests

Feature suggestions are welcome.

Some possible future improvements include:

* More realistic glass refraction
* Improved specular lighting
* Dynamic highlight movement
* Additional glass materials
* Custom glass intensity
* Animation improvements
* More iOS version compatibility
* User-configurable appearance
* Additional Settings integrations

⸻

🔄 Updates

SearchGlass will receive updates when necessary to maintain compatibility with newer jailbreak environments or changes to Settings.

Versioning follows semantic versioning where practical:

MAJOR.MINOR.PATCH

For example:

v1.0.0
v1.0.1
v1.1.0
v2.0.0

⸻

📜 Changelog

v1.0.0

🎉 Initial Release

* Added Liquid Glass-inspired Settings search button
* Added translucent glass appearance
* Added blur
* Added refraction/distortion
* Added specular highlights
* Added dynamic Light/Dark Mode colors
* Added search icon
* Added microphone icon
* Added native Settings search integration
* Restricted custom button to the main Settings screen
* Added rootless jailbreak support

⸻

📸 Screenshots

Screenshots can be added here to demonstrate the tweak in both Light Mode and Dark Mode.

Recommended screenshots:

🌙 Dark Mode

SearchGlass with white text/icons
and dark translucent glass.

☀️ Light Mode

SearchGlass with black text/icons
and light translucent glass.

⸻

❤️ Credits

SearchGlass was created as an experimental jailbreak customization project focused on bringing Apple’s modern glass-inspired interface concepts to older iOS environments.

Special thanks to the jailbreak and Theos communities for the tools and research that make projects like this possible.

⸻

⚖️ Disclaimer

SearchGlass is an independent jailbreak project and is not affiliated with, endorsed by, or sponsored by Apple Inc.

“iOS”, “Settings”, and other Apple-related trademarks belong to their respective owners.

Use this tweak at your own risk.

⸻

📄 License

This project is open source.

See the repository license for the specific terms governing modification, redistribution and use.

⸻

<p align="center">
  Made for jailbreak customization ❤️
</p>
<p align="center">
  <strong>SearchGlass — bringing glass to Settings.</strong>
</p>
```

