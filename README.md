[Telegram channel](https://t.me/cmplog)

**SymTube** is a modern native YouTube client for classic smartphones running **Symbian^3, Anna, and Belle**. The project brings back video viewing capabilities to iconic Nokia devices, bypassing the limitations.

---

## Features

* **Home:** Current recommendations and popular videos.
* **YouTube Shorts:** Full support for short videos with infinite scrolling and looping.
* **Search:** Quick search with suggestions.
* **Authorization:** Login via Google OAuth with a QR code to access your subscriptions and history.
* **Player:**
* Volume control with hardware buttons.
* Stylish OSD volume indicator.
* Background playback support. 
* **Interface:** Fully adapted for touch controls, supports screen orientation changes.
* English, Russian and Polish languages are supported initially.

---

## Architecture

The project consists of two parts:
1. **Client (this repository):** A C++/Qt (QML) application running directly on the smartphone.
2. **Server (Backend):** A high-performance Rust layer that processes YouTube API data and proxies the video stream.

**Server-side repository:** [yt-api-legacy](https://github.com/ZendoMusic/yt-api-legacy)

---

## Client Installation

1. Make sure you have Qt (version 4.7.3 or higher recommended) and Qt Mobility installed on your smartphone. 
2. Download the latest .sis installation file from the [Releases]() section.
3. Install the application on your device.
4. When you first launch the application, you must specify the address of the production server (instance) in the settings. You can set up your own server or use a public one.

---

## Development

Building the client requires a configured **Nokia SDK** environment (Qt Creator + GCCE/RVCT).

1. Open `SymTube.pro` in Qt Creator.
2. Build and create the installation package using `createpackage`.

---

## Acknowledgments

* **Computershik** — for adapting and developing the client.
* **ZendoMusic** — for developing the server side in Rust.
* All members of the Symbian community for their support and testing.

---
*SymTube — Made with love for the classics.*
