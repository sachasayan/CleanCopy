# CleanCopy - Codebase Overview

## 1. Introduction

CleanCopy is a macOS menu bar utility designed to streamline the process of sharing web links. Its primary function is to take a URL copied to the clipboard, fetch the title of the corresponding webpage, and replace the clipboard content with a rich text (RTF) link using the fetched title as the display text.

The application is built using SwiftUI for the menu bar interface and leverages standard macOS frameworks like AppKit, UserNotifications, and ServiceManagement for core functionalities. It runs as an "accessory" application, meaning it doesn't have a Dock icon or a main application window, operating solely through its menu bar icon.

## 2. Core Functionality Workflow

The main workflow is initiated by the user:

1.  **User copies a URL** to the system clipboard (e.g., `https://www.example.com`).
2.  **User clicks the CleanCopy menu bar icon** and selects the "Convert URL" menu item.

This triggers the following internal process managed by the `ClipboardManager`:

1.  **Read Clipboard:** The application reads the current string content from the general pasteboard (`NSPasteboard.general`).
2.  **Validate URL:** It checks if the clipboard string is a valid URL with a scheme (e.g., `http`, `https`). If not, the process stops silently.
3.  **Fetch Page Title (Asynchronous):**
    *   A `URLSession` data task is initiated to fetch the HTML content of the URL.
    *   A timeout is set to prevent indefinite waiting.
4.  **Parse Title:**
    *   The fetched HTML data is decoded (trying UTF-8 then ISO Latin 1).
    *   A regular expression (`<title[^>]*>(.*?)</title>`) is used to extract the content of the `<title>` tag.
    *   Whitespace is trimmed from the extracted title.
5.  **Handle Title Fallbacks:**
    *   If no title tag is found, the title is empty after trimming, or the HTML cannot be decoded, the URL's host or the full URL string is used as a fallback title.
6.  **Handle Fetch Errors:**
    *   If a network error occurs during the fetch (`URLSession` error), a user notification is displayed indicating the failure, and the URL itself is used as the link text.
7.  **Create Rich Text Link:**
    *   An `NSAttributedString` is created with the determined title (fetched or fallback).
    *   The `.link` attribute is applied to the string, pointing to the original URL.
8.  **Update Clipboard:**
    *   The system pasteboard's contents are cleared.
    *   The newly created `NSAttributedString` (rich text link) is written to the pasteboard.

The menu also provides standard "About" and "Quit" options.

## 3. Application Lifecycle & Setup

The application's startup and background behavior are managed primarily by the `AppDelegate`:

*   **Activation Policy:** On launch (`applicationDidFinishLaunching`), the app's activation policy is set to `.accessory`, hiding the Dock icon and preventing a main window from appearing.
*   **Notification Permissions:** The app requests user authorization for sending notifications (used for error reporting) and sets the `AppDelegate` as the notification center delegate to handle foreground notifications.
*   **Login Item Prompt (First Launch):**
    *   The app checks `UserDefaults` to see if it has previously prompted the user about launching at login.
    *   If not prompted before, it displays an `NSAlert` asking the user if they want CleanCopy to start automatically on login.
    *   If the user agrees, it uses the `ServiceManagement` framework (`SMAppService.mainApp.register()`) to register itself as a login item. This relies on configuration within the app's `Info.plist`.

## 4. Architecture & Key Components

The application follows a relatively simple structure based on SwiftUI's App lifecycle and standard AppKit patterns:

*   **`CleanCopyApp` (struct):** The main entry point conforming to SwiftUI's `App` protocol. It defines the `MenuBarExtra` scene which creates the menu bar icon and its associated menu. It also initializes and holds the `ClipboardManager`.
*   **`AppDelegate` (class):** An `NSObject` conforming to `NSApplicationDelegate` and `UNUserNotificationCenterDelegate`. It's integrated into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor`. Handles application-level events like launch, termination (optional), notification handling, and the login item registration logic.
*   **`ClipboardManager` (class):** An `ObservableObject` containing the core logic for the application's primary function: reading the clipboard, validating URLs, fetching/parsing web page titles, creating rich text links, handling errors, and updating the clipboard. It's instantiated by `CleanCopyApp`.
*   **`MenuBarExtra` (SwiftUI Scene):** Defines the UI element in the system menu bar, including its icon (`link.circle`) and the menu items ("Convert URL", "About", "Quit"). Actions from these menu items trigger methods on the `ClipboardManager` or `NSApplication`.

### Interaction Flow Diagram

```mermaid
graph TD
    A[User Copies URL] --> B(User Clicks "Convert URL");
    B --> C{ClipboardManager};
    C -- Reads Clipboard --> D{Validate URL};
    D -- Valid URL --> E[Fetch Page Title Async];
    D -- Invalid URL --> F[End/Ignore];
    E -- Success (Title Found) --> G{Create Rich Text Link (Title)};
    E -- Success (No Title) --> H{Create Rich Text Link (URL)};
    E -- Failure (Network Error) --> I{Show Error Notification};
    I --> H;
    G --> J[Update Clipboard];
    H --> J;
    J --> K[End];

    subgraph AppDelegate
        L[App Launch] --> M{Set Accessory Policy};
        L --> N{Request Notifications};
        L --> O{Check First Launch};
        O -- Yes --> P{Prompt Login Item};
        P -- User Agrees --> Q[Register Login Item];
    end

    subgraph MenuBarExtra
        R[Menu Icon] --> S["Convert URL"];
        R --> T["About"];
        R --> U["Quit"];
        S --> C;
        T --> V[Show About Dialog];
        U --> W[Terminate App];
    end
```

## 5. Build & Packaging

*   **Development:** The project is built using Xcode and the Swift toolchain.
*   **Makefile:** A `Makefile` is provided to simplify common tasks:
    *   `make build` (or `make`): Compiles the Debug configuration of the app into the `./build` directory.
    *   `make package`: Builds the app (if needed) and creates a distributable DMG file (`CleanCopy.dmg`) in the project root using the `create-dmg` utility.
    *   `make clean`: Removes the `./build` directory and the `CleanCopy.dmg` file.
*   **Prerequisites:**
    *   Xcode and Command Line Tools.
    *   `create-dmg` (installable via Homebrew: `brew install create-dmg`) is required for the `make package` command.

## 6. Project Structure & Configuration

Key files and directories in the project:

*   `CleanCopy/CleanCopyApp.swift`: Contains the main SwiftUI `App` struct, `AppDelegate`, and `ClipboardManager` class.
*   `CleanCopy/Info.plist`: Application configuration file (bundle identifier, version, login item helper configuration, etc.).
*   `CleanCopy/CleanCopy.entitlements`: Defines application sandbox entitlements/permissions.
*   `CleanCopy/Assets.xcassets`: Contains app icons and other image assets.
*   `CleanCopy.xcodeproj/`: Xcode project file and settings.
*   `Makefile`: Defines build, package, and clean commands.
*   `README.md`: Basic project description and build instructions.
*   `dmg-resources/`: Contains assets used during DMG creation (background image, license).
*   `.gitignore`: Specifies intentionally untracked files for Git.

## 7. Dependencies

The project relies primarily on standard macOS frameworks provided by Apple:

*   **SwiftUI:** For defining the `MenuBarExtra` interface.
*   **AppKit:** Underlying framework for macOS applications, used for `NSApplication`, `NSPasteboard`, `NSAlert`, `NSAttributedString`, etc.
*   **UserNotifications:** For displaying system notifications (e.g., on errors).
*   **ServiceManagement:** For registering the application as a login item.
*   **Foundation:** Core utilities (URL, URLSession, String, Error handling, etc.).

No external third-party libraries are used.