# CleanCopy - Codebase Overview

## 1. Introduction

CleanCopy is a macOS menu bar utility designed to streamline the process of sharing web links. Its primary function is to take a URL copied to the clipboard, fetch the title of the corresponding webpage, and replace the clipboard content with a rich text (RTF) link using the fetched title as the display text.

The application can operate in two modes:
*   **Manual Mode:** The user explicitly clicks "Convert URL" in the menu bar to process the current clipboard content.
*   **Automatic Mode (enabled by default):** The application monitors the clipboard for changes and automatically attempts to convert copied URLs. The user can toggle this mode off via the menu bar item.

The application is built using SwiftUI for the menu bar interface and leverages standard macOS frameworks like AppKit, UserNotifications, ServiceManagement, Foundation, and Combine for core functionalities. It runs as an "accessory" application, meaning it doesn't have a Dock icon or a main application window, operating solely through its menu bar icon.

## 2. Core Functionality Workflow

The conversion process is managed by the `ClipboardManager`.

**A. Manual Trigger:**

1.  **User copies a URL** to the system clipboard (e.g., `https://www.example.com`).
2.  **User clicks the CleanCopy menu bar icon** and selects the "Convert URL" menu item.
3.  This triggers the `processClipboardContent` method.

**B. Automatic Trigger (when "Auto Convert" is enabled):**

1.  **User copies a URL** to the system clipboard.
2.  **Clipboard Monitoring:** A `Timer` polls the `NSPasteboard.general.changeCount` every second. This monitoring starts automatically when the app launches.
3.  **Change Detection:** If the `changeCount` differs from the last known value:
    *   The `ClipboardManager` checks if the clipboard content contains Rich Text (`.rtf` or `.rtfd`). If so, it ignores the change to prevent processing its own output or other rich text.
    *   If the content is likely plain text, it triggers the `processClipboardContent` method.

**C. Core Conversion Process (`processClipboardContent`):**

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
    *   If a network error occurs during the fetch (`URLSession` error), a user notification is displayed indicating the failure. The clipboard is updated with a link using the URL itself as the text *only if* the clipboard content hasn't changed again since the fetch began.
7.  **Create Rich Text Link:**
    *   An `NSAttributedString` is created with the determined title (fetched or fallback).
    *   The `.link` attribute is applied to the string, pointing to the original URL.
8.  **Update Clipboard & Notify:**
    *   The system pasteboard's contents are cleared.
    *   The newly created `NSAttributedString` (rich text link) is written to the pasteboard.
    *   The internal `lastChangeCount` is updated to match the pasteboard's new state.
    *   A user notification is displayed confirming the successful update (requires notification permissions).

The menu also provides standard "About" and "Quit" options.

## 3. Application Lifecycle & Setup

The application's startup and background behavior are managed primarily by the `AppDelegate`:

*   **Activation Policy:** On launch (`applicationDidFinishLaunching`), the app's activation policy is set to `.accessory`, hiding the Dock icon and preventing a main window from appearing.
*   **Notification Permissions & Prompt:**
    *   The app requests user authorization for sending notifications (used for error reporting and success confirmation).
    *   It sets the `AppDelegate` as the notification center delegate to handle foreground notifications.
    *   After requesting authorization, it checks the current notification settings. If notifications are explicitly denied, and the user hasn't been prompted before (tracked via `UserDefaults`), it displays an `NSAlert` explaining the benefits of notifications and provides a button to open System Settings directly to the app's notification preferences.
*   **Login Item Prompt (First Launch):**
    *   The app checks `UserDefaults` to see if it has previously prompted the user about launching at login.
    *   If not prompted before, it displays an `NSAlert` asking the user if they want CleanCopy to start automatically on login.
    *   If the user agrees, it uses the `ServiceManagement` framework (`SMAppService.mainApp.register()`) to register itself as a login item. This relies on configuration within the app's `Info.plist`.

## 4. Architecture & Key Components

The application follows a relatively simple structure based on SwiftUI's App lifecycle and standard AppKit patterns:

*   **`CleanCopyApp` (struct):** The main entry point conforming to SwiftUI's `App` protocol. It defines the `MenuBarExtra` scene which creates the menu bar icon and its associated menu. It initializes and holds the `ClipboardManager` as a `@StateObject`.
*   **`AppDelegate` (class):** An `NSObject` conforming to `NSApplicationDelegate` and `UNUserNotificationCenterDelegate`. It's integrated into the SwiftUI lifecycle via `@NSApplicationDelegateAdaptor`. Handles application-level events like launch, termination (optional), notification handling (including checking status and prompting if denied), and the login item registration logic.
*   **`ClipboardManager` (class):** An `ObservableObject` containing the core logic for the application's primary function. It manages:
    *   The state for automatic conversion (`@Published var isAutoConvertEnabled`), which defaults to `true`.
    *   A `Timer` for polling the clipboard when automatic mode is active. Monitoring is started automatically during initialization because the default state is enabled.
    *   Tracking the last pasteboard `changeCount` to detect changes.
    *   The `processClipboardContent` method containing the steps for reading the clipboard, validating URLs, fetching/parsing web page titles, creating rich text links, handling errors, and updating the clipboard.
    *   Methods to `startMonitoring()`, `stopMonitoring()`, and `toggleAutoConvert()`.
    *   Triggering user notifications for success and errors.
*   **`MenuBarExtra` (SwiftUI Scene):** Defines the UI element in the system menu bar, including its icon (`link.circle`) and the menu items:
    *   "Convert URL": Manually triggers `processClipboardContent`.
    *   "Auto Convert" (with checkmark): Toggles the `isAutoConvertEnabled` state in `ClipboardManager` via `toggleAutoConvert()`. The checkmark (`checkmark` / empty space) reflects the current state, starting as checked by default.
    *   "About": Shows a standard About dialog.
    *   "Quit": Terminates the application (ensuring the monitoring timer is stopped).

### Interaction Flow Diagram

```mermaid
graph TD
    subgraph User Interaction
        direction LR
        UserCopy[User Copies URL] --> PB(NSPasteboard);
        UserClickManual[User Clicks "Convert URL"] --> CM(ClipboardManager);
        UserClickToggle[User Clicks "Auto Convert"] --> CM;
    end

    subgraph CleanCopyApp UI
        direction LR
        MB["MenuBarExtra"]
        MB -- Displays --> ToggleState{Auto Convert State (Default: On)};
        MB -- Action --> UserClickManual;
        MB -- Action --> UserClickToggle;
    end

    subgraph ClipboardManager Logic
        direction TB
        style AutoConvertState fill:#lightgrey,stroke:#333,stroke-width:2px

        Init[Initialization] --> AutoConvertState[@Published isAutoConvertEnabled = true];
        Init --> StartMonitor[startMonitoring()]; # Start timer on init

        AutoConvertState -- Controls --> TimerManagement;
        UserClickToggle --> ToggleMethod[toggleAutoConvert()];
        ToggleMethod --> AutoConvertState;

        subgraph TimerManagement
            direction LR
            ToggleMethod -- Enables --> StartMonitor;
            ToggleMethod -- Disables --> StopMonitor[stopMonitoring()];
            StartMonitor --> Timer{Timer (1s)};
            StopMonitor --> Timer_Invalidate[Timer Invalidate];
            Timer -- Fires --> CheckClipboard[checkClipboard()];
        end

        CheckClipboard -- Reads --> PB_ChangeCount{Pasteboard.changeCount};
        CheckClipboard --> CompareCount{Compare with lastChangeCount};

        CompareCount -- No Change --> EndPoll(End Poll Cycle);
        CompareCount -- Change Detected --> UpdateLastCount[Update lastChangeCount];
        UpdateLastCount --> CheckPBTypes{Check Pasteboard Types};
        CheckPBTypes -- Contains RTF? --> EndPoll;
        CheckPBTypes -- Plain Text? --> ProcessContent[processClipboardContent()];

        UserClickManual -- Triggers --> ProcessContent;

        subgraph Core Processing
            direction TB
            ProcessContent -- Reads --> PB_String{Pasteboard String};
            ProcessContent --> ValidateURL{Validate URL};
            ValidateURL -- Invalid --> EndProcess(End Processing);
            ValidateURL -- Valid --> FetchTitle[Fetch Page Title Async];
            FetchTitle -- Failure --> HandleError[handleError()];
            FetchTitle -- Success --> CreateLink[createRichTextLink()];
            HandleError -- If Clipboard Unchanged --> CreateFallbackLink[createRichTextLink (Fallback)];
            HandleError --> NotifyError[Show Error Notification];
            CreateFallbackLink --> UpdatePB_Error[Update Pasteboard];
            CreateLink --> UpdatePB_Success[Update Pasteboard];
            UpdatePB_Success --> UpdateLastCountSuccess[Update lastChangeCount];
            UpdatePB_Success --> NotifySuccess[Show Success Notification];
            UpdatePB_Error --> UpdateLastCountError[Update lastChangeCount];
        end
    end

    CoreProcessing -- Writes --> PB;
    PB -- changeCount --> ClipboardManager_Logic;
    PB -- String --> ClipboardManager_Logic;
    PB -- Types --> ClipboardManager_Logic;

    CleanCopyApp_UI -- Observes --> AutoConvertState;

```

## 5. Build & Packaging

*   **Development:** The project is built using Xcode and the Swift toolchain.
*   **Makefile:** A `Makefile` is provided to simplify common tasks:
    *   `make build` (or `make`): Compiles the Debug configuration of the app into the `./build` directory.
    *   `make run`: Kills any existing instance, builds (if needed), and runs the Debug app.
    *   `make package`: Builds the app (if needed) and creates a distributable DMG file (`CleanCopy.dmg`) in the project root using the `create-dmg` utility.
    *   `make clean`: Removes the `./build` directory and the `CleanCopy.dmg` file.
    *   `make reset`: Cleans build artifacts, preferences, and attempts removal from /Applications.
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
*   **AppKit:** Underlying framework for macOS applications, used for `NSApplication`, `NSPasteboard`, `NSAlert`, `NSAttributedString`, `NSWorkspace`, etc.
*   **UserNotifications:** For requesting permissions, checking settings, and displaying system notifications.
*   **ServiceManagement:** For registering the application as a login item.
*   **Foundation:** Core utilities (URL, URLSession, String, Error handling, UserDefaults, Timer, etc.).
*   **Combine:** Used for the `@Published` property wrapper in `ObservableObject` (`ClipboardManager`).

No external third-party libraries are used.