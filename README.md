# UPSStatusBar for macOS

A simple macOS status bar application to monitor an Uninterruptible Power Supply (UPS). It can connect to a NUT (Network UPS Tools) server or use the native power source information provided by macOS.

## Features

- **Status Bar Popover**: Click the bolt icon in the status bar to see a quick summary of your UPS status, including charge level, estimated time remaining, and current load.
- **Auto-Refresh**: Data is refreshed automatically every few seconds.
- **Detailed View**: A "Show Details" button to display all available variables from the UPS.
- **NUT Server Support**: Configure the app to connect to a remote NUT server to monitor any UPS on your network.
- **Device Discovery**: Automatically discover available UPS devices on your configured NUT server.
- **Configurable Notifications**: Receive system notifications for important UPS events:
    - Status change (e.g., from Online to On Battery)
    - Battery level drops below a custom threshold
    - Battery becomes fully charged
    - Load exceeds a custom threshold
- **Launch at Login**: Conveniently set the application to start automatically when you log in to your Mac.

## Screenshots

**Main Interface**

![Main Interface](images/main.png)

**Details View**

![Details View](images/detail.png)

**NUT Server Configuration**

![NUT Server Configuration](images/nut.png)

**Settings (Notifications & Startup)**

![Settings](images/settings.png)

## Requirements

- macOS 11.0 or later
- Swift 5.6 or later (or a version of Xcode that includes it)

## How to Build and Run

1.  **Clone the repository.**
2.  **Navigate to the project directory:**
    ```bash
    cd /path/to/repository
    ```
3.  **Build the project:**
    ```bash
    swift build
    ```
4.  **Run the application:**
    ```bash
    swift run UPSStatusBar
    ```
    The application can also be built for release using `swift build -c release`. The final executable will be located in the `.build/release` directory.

## Configuration

- **NUT Server**: Click the "Configure NUT" button in the main popover to set up your NUT server's host, port, and credentials. You can also test the connection and select which UPS to monitor.
- **Notifications & Startup**: Click the gear icon (⚙️) to open the Settings window. Here you can enable or disable different notifications, set thresholds, and toggle the "Launch at Login" option.

---

### 免责声明

请注意：本应用程序尚未经过广泛或重复的测试。请自行承担使用风险，尤其是在启用自动关机等功能时。
