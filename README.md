# PaperCursor 0.4

English · [简体中文](README.zh-CN.md)

PaperCursor is a native macOS app for customizing your cursor. Switch between themes, adjust the size, and try each cursor on light or dark backgrounds before applying it to your desktop. The preview area lets you click buttons, hover over links, select text, and drag.

Choose from three built-in themes:

- **Paper Cat (纸片猫):** The Classic style keeps the original proportions and smile, and the cat blinks when you click. Cat Only uses the tip of the left ear as the click point and raises a paw over links.
- **Pixel Jelly (像素果冻):** A playful pixel art theme.
- **Two-Tone Arrow (双色箭头):** An arrow with separate fill and outline colors.

## Try it on your Mac

1. Open PaperCursor (纸片光标) on an Apple Silicon Mac running macOS 26 or later.
2. Choose a theme and adjust its size from 75% to 150%. For Two-Tone Arrow, you can also change the fill and outline colors.
3. Click **Apply to Desktop (应用到桌面)** to enable live theming. Changes to the theme, style, size, or colors take effect on the desktop as you make them. Restore the original cursor from the app window or menu bar to return to preview mode.

PaperCursor restores the previous cursor when it quits normally. If the app exits unexpectedly, a recovery process in the same login session attempts to restore the cursor. The app also checks for a recovery record on its next launch.

Preview settings are stored locally, and all theme assets ship with the app. Desktop cursor replacement uses private WindowServer interfaces. Apps that draw their own cursors, some system surfaces, and different macOS versions may behave differently. The current build is signed for local use. Public distribution requires Developer ID signing and notarization.

## Build from source

Open [PaperCursor.xcodeproj](PaperCursor.xcodeproj) in Xcode 26 or later and run the **PaperCursor** scheme. The app uses SwiftUI, AppKit, and Core Graphics. [WindowServer.swift](Sources/WindowServer.swift) and [DesktopThemeEngine.swift](Sources/DesktopThemeEngine.swift) handle reading, applying, and restoring system cursors. All three themes are drawn in [CursorTheme.swift](Sources/CursorTheme.swift).

## What we've verified

On an Apple Silicon Mac running macOS 26.6.2, a separate test app confirmed the image sizes and hotspots of the arrow, pointing hand, and text cursors. We also verified 150% scaling, manual restoration, and recovery after forcibly terminating the app.

We verified the Paper Cat blink frames for both the face and raised paw, the return to open eyes, and the click point. The text cursor can take over during a blink. Clicks in the PaperCursor window trigger the desktop blink.

In 0.4, we verified live desktop updates for theme, style, size, and color changes. During continuous adjustments, the median time per desktop update was about 18 ms for Paper Cat resizing and 25 ms for Two-Tone Arrow recoloring at 150% size. Rapid changes are grouped into a single update. Mouse clicks in other apps, macOS 27, multiple displays, full-screen mode, and browser-drawn cursors still need testing.

The theme list takes inspiration from [MaCursor](https://writronic.com/macursor/), and the interactive preview from [CursorMagic](https://pocketgiant.co/software/cursormagic/). All cursor artwork is original to this project.
