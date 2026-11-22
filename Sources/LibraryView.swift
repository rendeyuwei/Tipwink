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
        .frame(minWidth: 760, minHeight: 580)
        .tint(inkAccent)
    }

    private var themeList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor Themes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 9)
                .padding(.bottom, 5)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CursorTheme.allCases) { theme in
                        themeRow(theme)
                    }
                }
            }
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
                    CursorDrawing(settings: ThemeSettings(
                        theme: theme,
                        paperCatStyle: library.settings.paperCatStyle,
                        paperCatBreed: library.settings.paperCatBreed
                    ), role: .arrow)
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
        }
        .buttonStyle(ThemeSelectionStyle(selected: selected, accent: inkAccent))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(library.applied?.theme == theme ? Text("Active on Desktop") : Text(verbatim: ""))
        .accessibilityIdentifier("theme-\(theme.rawValue)")
    }

    private var desktopStatus: some View {
        let status: LocalizedStringResource = library.needsRecovery ? "Restore Pending" : "Active on Desktop"
        return VStack(alignment: .leading, spacing: 11) {
            Divider()
            HStack(spacing: 8) {
                Circle()
                    .fill(library.applied == nil ? Color.secondary.opacity(0.7) : inkAccent)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(library.applied?.theme.name ?? "System Cursor")
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
            Picker("Preview Background", selection: $background) {
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
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 68, alignment: .leading)
                Slider(value: $library.settings.scale, in: 0.75...1.5, step: 0.05) { Text("Cursor Size") }
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
                    Label("Style", systemImage: "pawprint")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 68, alignment: .leading)
                    Picker("Paper Cat Style", selection: $library.settings.paperCatStyle) {
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
                Divider()
                breedPicker
            } else if library.settings.theme == .twoTone {
                Divider()
                HStack(spacing: 23) {
                    ColorPicker("Fill", selection: colorBinding(\.fill), supportsOpacity: false)
                        .accessibilityIdentifier("fill-color")
                    ColorPicker("Outline", selection: colorBinding(\.outline), supportsOpacity: false)
                        .accessibilityIdentifier("outline-color")
                    Spacer()
                    Button("Reset Colors") {
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

    private var breedPicker: some View {
        HStack(spacing: 12) {
            Label("Breed", systemImage: "cat")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 68, alignment: .leading)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                ForEach(PaperCatBreed.allCases) { breed in
                    breedButton(breed)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Paper Cat Breed")
        }
    }

    private func breedButton(_ breed: PaperCatBreed) -> some View {
        let selected = library.settings.paperCatBreed == breed
        return Button {
            library.settings.paperCatBreed = breed
        } label: {
            HStack(spacing: 6) {
                CursorDrawing(
                    settings: ThemeSettings(paperCatStyle: .catOnly, paperCatBreed: breed),
                    role: .arrow
                )
                .frame(width: 28, height: 31)
                .offset(y: 2)
                Text(breed.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(inkAccent)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(ThemeSelectionStyle(
            selected: selected, accent: inkAccent, cornerRadius: 9, border: .primary.opacity(0.13)
        ))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("paper-cat-breed-\(breed.rawValue)")
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
            if library.hasPointerColorConflict {
                Text("Custom system pointer colors override desktop themes. Open Settings below and click Reset Colors. Tipwink will apply the theme when you return. You can keep your pointer size.")
                    .font(.system(size: 12))
                    .foregroundStyle(inkAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message = library.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(inkAccent)
                    .accessibilityIdentifier("desktop-message")
            }
            HStack(spacing: 12) {
                Spacer()
                Button("Restore Original Cursor") { library.restore() }
                    .disabled(library.applied == nil && !library.needsRecovery)
                    .accessibilityIdentifier("restore-cursor")
                if library.hasPointerColorConflict {
                    Button("Apply After Reset…") { library.applyAfterColorReset() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("open-pointer-settings")
                } else {
                    let title: LocalizedStringResource = library.canApplyManually ? "Apply to Desktop" : "Applied"
                    Button(title) { library.apply() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!library.canApplyManually)
                        .accessibilityIdentifier("apply-theme")
                }
            }
            .controlSize(.large)
        }
    }
}

private struct ThemeSelectionStyle: ButtonStyle {
    let selected: Bool
    let accent: Color
    var cornerRadius: CGFloat = 13
    var border: Color = .clear

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        configuration.label
            .background(
                accent.opacity(configuration.isPressed ? 0.17 : (selected ? 0.095 : 0)),
                in: shape
            )
            .overlay { shape.strokeBorder(selected ? accent.opacity(0.42) : border, lineWidth: 1) }
            .contentShape(shape)
    }
}
