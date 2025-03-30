# CleanCopy

A macOS application (description placeholder - please update with actual app details).

## Building the Application

This project uses a `Makefile` to simplify common development tasks.

### Prerequisites

*   Xcode and Command Line Tools
*   For packaging (`make package`): `create-dmg` (Install via Homebrew: `brew install create-dmg`)

### Makefile Commands

*   **`make build`** (or just `make`)
    Builds the Debug configuration of the application. The output `.app` file will be located in `./build/Build/Products/Debug/`.

*   **`make package`**
    Builds the Debug configuration (if not already built) and then packages the application into a distributable DMG file named `CleanCopy.dmg` in the project root directory.
    *Requires `create-dmg` to be installed.*

*   **`make clean`**
    Removes the build directory (`./build`) and the generated DMG file (`CleanCopy.dmg`).