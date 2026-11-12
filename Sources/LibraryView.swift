import SwiftUI

struct LibraryView: View {
    @Bindable var library: ThemeLibrary
    @Environment(\.colorScheme) private var colorScheme
    @State private var background: PreviewBackground = .light

    private var inkAccent: Color {
        colorScheme == .dark ? Color(red: 1, green: 0.69, blue: 0.50) : Color(red: 0.58, green: 0.27, blue: 0.16)
    }

    private var sidebar: Color {
        colorScheme == .dark ? Color(red: 0.14, green: 0.13, blue: 0.13) : Color(red: 0.967, green: 0.947, blue: 0.916)
    }

    private var surface: Color {
        colorScheme == .dark ? Color(red: 0.108, green: 0.10, blue: 0.10) : Color(red: 0.994, green: 0.983, blue: 0.963)
    }

    var body: some View {
        HStack(spacing: 0) {
            themeList
                .frame(width: 222)
            Rectangle()
                .fill(.primary.opacity(0.085))
                .frame(width: 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 19) {
                titleRow
                PreviewBoard(settings: library.settings, background: background)
                    .id(library.settings.theme)
                    .layoutPriority(1)
                adjustments
                actions
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(surface)
        }
        .frame(minWidth: 760, minHeight: 540)
        .tint(inkAccent)
    }

    private var themeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("光标主题")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 9)
                .padding(.bottom, 5)
                .accessibilityAddTraits(.isHeader)

            ForEach(CursorTheme.allCases) { theme in
                themeRow(theme)
            }
            Spacer(minLength: 20)
            desktopStatus
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 25)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(sidebar)
    }

    private func themeRow(_ theme: CursorTheme) -> some View {
        let selected = theme == library.settings.theme
        return Button {
            library.select(theme)
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.swatch)
                    CursorDrawing(settings: ThemeSettings(theme: theme, paperCatStyle: library.settings.paperCatStyle), role: .arrow)
                        .frame(width: 31, height: 35)
                }
                .frame(width: 41, height: 41)
                Text(theme.name)
                    .font(.system(size: 14, weight: selected ? .semibold : .medium))
                Spacer(minLength: 2)
                if library.applied?.theme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(inkAccent)
                }
            }
            .padding(7)
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(ThemeRowStyle(selected: selected, accent: inkAccent))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(library.applied?.theme == theme ? "桌面正在使用" : "")
        .accessibilityIdentifier("theme-\(theme.rawValue)")
    }

    private var desktopStatus: some View {
        VStack(alignment: .leading, spacing: 11) {
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(library.applied == nil ? Color.secondary.opacity(0.7) : inkAccent)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(library.needsRecovery ? "等待恢复" : "桌面正在使用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(library.applied?.theme.name ?? "系统光标")
                .font(.system(size: 14, weight: .semibold))
                .accessibilityIdentifier("desktop-status")
        }
        .padding(.horizontal, 9)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(library.settings.theme.name)
                    .font(.system(size: 32, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(library.settings.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 2)
            Picker("预览背景", selection: $background) {
                ForEach(PreviewBackground.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 114)
            .padding(.top, 5)
            .accessibilityIdentifier("preview-background")
        }
    }

    private var adjustments: some View {
        VStack(spacing: 13) {
            HStack(spacing: 12) {
                Label("大小", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 68, alignment: .leading)
                Slider(value: $library.settings.scale, in: 0.75...1.5, step: 0.05) { Text("光标大小") }
                    .labelsHidden()
                    .accessibilityIdentifier("cursor-size")
                Text(library.settings.scale.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            if library.settings.theme == .paperCat {
                Divider()
                HStack(spacing: 12) {
                    Label("样式", systemImage: "pawprint")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 68, alignment: .leading)
                    Picker("纸片猫样式", selection: $library.settings.paperCatStyle) {
                        ForEach(PaperCatStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 148)
                    .accessibilityIdentifier("cat-style")
                    Spacer()
                }
            } else if library.settings.theme == .twoTone {
                Divider()
                HStack(spacing: 23) {
                    ColorPicker("填充", selection: colorBinding(\.fill), supportsOpacity: false)
                        .accessibilityIdentifier("fill-color")
                    ColorPicker("描边", selection: colorBinding(\.outline), supportsOpacity: false)
                        .accessibilityIdentifier("outline-color")
                    Spacer()
                    Button("重置配色") {
                        library.settings.fill = ThemeSettings().fill
                        library.settings.outline = ThemeSettings().outline
                    }
                    .buttonStyle(.borderless)
                }
                .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }

    private func colorBinding(_ key: WritableKeyPath<ThemeSettings, RGB>) -> Binding<Color> {
        Binding {
            library.settings[keyPath: key].color
        } set: { color in
            if let converted = RGB(color: color) { library.settings[keyPath: key] = converted }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let message = library.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(inkAccent)
                    .accessibilityIdentifier("desktop-message")
            }
            HStack(spacing: 12) {
                Spacer()
                Button("恢复原光标") { library.restore() }
                    .disabled(library.applied == nil && !library.needsRecovery)
                    .accessibilityIdentifier("restore-cursor")
                Button(library.canApplyManually ? "应用到桌面" : "已应用") {
                    library.apply()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!library.canApplyManually)
                .accessibilityIdentifier("apply-theme")
            }
            .controlSize(.large)
        }
    }
}

private struct ThemeRowStyle: ButtonStyle {
    let selected: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                accent.opacity(configuration.isPressed ? 0.17 : (selected ? 0.095 : 0)),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(accent.opacity(selected ? 0.32 : 0), lineWidth: 1)
            }
    }
}
