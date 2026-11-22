# Tipwink

**A macOS menu bar app for cursor themes.**

Try the pointer, link hand, and text cursor on light and dark backgrounds. When you find a theme you like, apply it to your desktop.

**[Download for Mac](https://github.com/rendeyuwei/Tipwink/releases/latest/download/Tipwink-macOS-arm64.zip)** · [Website](https://rendeyuwei.github.io/Tipwink/) · [Release notes](https://github.com/rendeyuwei/Tipwink/releases/latest) · [简体中文](README.zh-CN.md)

Apple silicon · macOS 26 or later

![Paper Cat, Pixel Jelly, Two-Tone Arrow, and Pencil on light and dark backgrounds](docs/images/cursor-preview.png)

## Get started

1. Download and unzip `Tipwink-macOS-arm64.zip`. Move `Tipwink.app` to Applications and open it.
2. Choose a theme. Try clicking, hovering over the sample link, selecting text, and dragging in the preview. The size slider ranges from 75% to 150%.
3. Choose **应用到桌面** (Apply to Desktop). Once applied, changes to the theme, style, size, and colors take effect as you make them.

The menu bar icon lets you reopen the library and switch themes. Choose **恢复原光标** (Restore Original Cursor) in the library or the menu bar to switch back.

To update, quit Tipwink and replace it in Applications with the latest download. [Release notes](https://github.com/rendeyuwei/Tipwink/releases/latest)

## Themes

| Theme | Description |
| --- | --- |
| **Paper Cat** | A cat that blinks when you click. Cat Only mode (纯猫) uses the tip of an ear for pointing and a raised paw for links. |
| **Pixel Jelly** | Pixel-art cursors in purple with mint accents. |
| **Two-Tone Arrow** | A classic cursor set with independent fill and outline colors. |
| **Pencil** | A short amber pencil with the click point at its tip. |

## Compatibility

Desktop themes apply to the macOS system cursors. Apps and system views can display cursors of their own.

Custom macOS pointer colors can override a theme. If Tipwink shows **重设后应用…** (Apply After Reset), choose it, select **Reset Colors** under **Pointer** in Display settings, and return to Tipwink to apply the selected theme. [Apple’s pointer settings guide](https://support.apple.com/guide/mac-help/mchlp2920/mac)

The direct download is signed with Developer ID and notarized by Apple.

## Feedback

For cursor issues, include your macOS version, Tipwink version, selected theme, and the app or screen where the issue appears. [Report an issue or suggest an improvement](https://github.com/rendeyuwei/Tipwink/issues)

## Build from source

Open `Tipwink.xcodeproj` in Xcode 26 or later. Select the **Tipwink** scheme and **My Mac**, then run the app. [Xcode project](Tipwink.xcodeproj) · [Release and update guide](docs/updates.md)

## Credits

Tipwink draws its cursor artwork in code. MaCursor and CursorMagic inspired the theme library and interactive preview. [MaCursor](https://writronic.com/macursor/) · [CursorMagic](https://pocketgiant.co/software/cursormagic/)
