# jj-ice

jj-ice keeps a crowded macOS menu bar manageable. Place items to hide on the left side of the divider, then click the arrow to collapse or restore them.

Requires the latest macOS. jj-ice is unsigned and distributed outside the App Store.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/yigegongjiang/jj-ice/main/install.sh | bash
```

The installer downloads the latest Release, installs `jj-ice.app` into `/Applications`, and removes the quarantine attribute for the unsigned app.

Manual install:

1. Download `jj-ice-macos.zip` from [Releases](https://github.com/yigegongjiang/jj-ice/releases)
2. Unzip it and move `jj-ice.app` to `/Applications`
3. Run before first launch:

```bash
xattr -dr com.apple.quarantine /Applications/jj-ice.app
```

## Use

1. Launch jj-ice; the menu bar shows a divider and an arrow
2. Hold `Command` and drag items to hide to the left side of the divider
3. Click the arrow to collapse or expand
4. Right-click the arrow for Launch at Login / Help / About / Quit

jj-ice remembers the collapsed state. Launch at Login is enabled by default and can be disabled from the menu.

## Behavior

- Left of divider: hidden when collapsed
- Right of divider: always visible
- Unsigned app: macOS may block first launch; the install script handles this automatically
