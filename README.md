# JJIce

JJIce keeps a crowded macOS menu bar manageable. Place items to hide on the left side of the divider, then click the arrow to collapse or restore them.

Requires the latest macOS. JJIce is unsigned and distributed outside the App Store.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/JJIce/main/install.sh | bash
```

The installer downloads the latest Release, installs `JJIce.app` into `/Applications`, and removes the quarantine attribute for the unsigned app.

Manual install:

1. Download `JJIce-macos.zip` from [Releases](https://github.com/yigegongjiang/JJIce/releases)
2. Unzip it and move `JJIce.app` to `/Applications`
3. Run before first launch:

```bash
xattr -dr com.apple.quarantine /Applications/JJIce.app
```

## Use

1. Launch JJIce; the menu bar shows a divider and an arrow
2. Hold `Command` and drag items to hide to the left side of the divider
3. Click the arrow to collapse or expand
4. Right-click the arrow for Launch at Login / Help / About / Quit

JJIce remembers the collapsed state. Launch at Login is enabled by default and can be disabled from the menu.

## Behavior

- Left of divider: hidden when collapsed
- Right of divider: always visible
- Unsigned app: macOS may block first launch; the install script handles this automatically
