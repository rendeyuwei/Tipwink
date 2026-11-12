import AppKit
import SwiftUI

enum PreviewBackground: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: Self { self }
    var title: String { self == .light ? "浅色" : "深色" }
    var base: Color {
        self == .light ? Color(red: 0.964, green: 0.917, blue: 0.86) : Color(red: 0.15, green: 0.128, blue: 0.132)
    }
    var ink: Color { self == .light ? Color(red: 0.25, green: 0.17, blue: 0.14) : .white }
    var accent: Color {
        self == .light ? Color(red: 0.53, green: 0.235, blue: 0.135) : Color(red: 1, green: 0.72, blue: 0.57)
    }
}

struct CursorDrawing: View {
    let settings: ThemeSettings
    let role: CursorRole
    var expression: CatExpression = .open

    var body: some View {
        Image(nsImage: CursorArtwork.image(settings, role: role, expression: expression))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .accessibilityHidden(true)
    }
}

struct PreviewBoard: View {
    let settings: ThemeSettings
    let background: PreviewBackground
    @State private var clicked = false
    @State private var opened = false
    @State private var blinkingRole: CursorRole?
    @State private var blinkTask: Task<Void, Never>?
    @State private var dragProgress: CGFloat = 0
    @GestureState private var dragDelta: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("试用区", systemImage: "cursorarrow.motionlines")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(background.ink.opacity(0.74))
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 0) {
                tile(.arrow) {
                    SampleButton(settings: settings, role: .arrow, expression: expression(for: .arrow),
                                 title: clicked ? "已点中" : "点一下", color: background.ink) {
                        clicked.toggle()
                        blink(.arrow)
                    }
                    .frame(width: 91, height: 28)
                    .background(background.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                }

                separator
                tile(.link) {
                    SampleButton(settings: settings, role: .link, expression: expression(for: .link),
                                 title: opened ? "已打开" : "试用链接", color: background.accent) {
                        opened.toggle()
                        blink(.link)
                    }
                    .frame(width: 100, height: 28)
                }

                separator
                tile(.text) {
                    SampleText(settings: settings, color: background.ink)
                        .frame(width: 104, height: 28)
                }
            }
            .frame(maxHeight: .infinity)
            dragTrack
        }
        .padding(17)
        .frame(minHeight: 246, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 17)
                .fill(background.base)
            Canvas { context, size in
                var dots = Path()
                for x in stride(from: 10.0, to: size.width, by: 14) {
                    for y in stride(from: 10.0, to: size.height, by: 14) {
                        dots.addEllipse(in: CGRect(x: x, y: y, width: 1.6, height: 1.6))
                    }
                }
                context.fill(dots, with: .color(background.ink.opacity(0.15)))
            }
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .accessibilityHidden(true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 17)
                .strokeBorder(background.ink.opacity(0.12), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .onDisappear {
            blinkTask?.cancel()
            blinkingRole = nil
        }
    }

    private func expression(for role: CursorRole) -> CatExpression {
        blinkingRole == role ? .blink : .open
    }

    private func blink(_ role: CursorRole) {
        guard settings.theme == .paperCat else { return }
        blinkTask?.cancel()
        blinkingRole = role
        blinkTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(CatExpression.blinkDuration)) }
            catch { return }
            guard !Task.isCancelled else { return }
            blinkingRole = nil
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(background.ink.opacity(0.15))
            .frame(width: 1, height: 72)
            .accessibilityHidden(true)
    }

    private func tile<Control: View>(_ role: CursorRole, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 8) {
            CursorDrawing(settings: settings, role: role, expression: expression(for: role))
                .frame(width: 64 * settings.scale, height: 72 * settings.scale)
                .frame(height: 111)
            Text(role.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(background.ink.opacity(0.76))
            control()
        }
        .frame(maxWidth: .infinity)
    }

    private var dragTrack: some View {
        HStack(spacing: 10) {
            Text("拖动")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(background.ink.opacity(0.7))
            GeometryReader { proxy in
                let travel = max(1, proxy.size.width - 24)
                let position = min(travel, max(0, dragProgress * travel + dragDelta))

                Capsule()
                    .fill(background.ink.opacity(0.08))
                    .frame(height: 4)
                    .padding(.horizontal, 8)
                    .position(x: proxy.size.width / 2, y: 10)

                RoundedRectangle(cornerRadius: 5)
                    .fill(background.accent)
                    .frame(width: 24, height: 19)
                    .overlay {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(background == .light ? .white : .black)
                    }
                    .offset(x: position)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragDelta) { value, state, _ in state = value.translation.width }
                            .onEnded { value in
                                dragProgress = min(1, max(0, dragProgress + value.translation.width / travel))
                            }
                    )
                    .accessibilityLabel("拖动试用")
                    .accessibilityValue(Double(dragProgress).formatted(.percent.precision(.fractionLength(0))))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: dragProgress = min(1, dragProgress + 0.1)
                        case .decrement: dragProgress = max(0, dragProgress - 0.1)
                        @unknown default: break
                        }
                    }
            }
            .frame(width: 89, height: 20)
            Spacer()
        }
    }
}

private final class CursorSampleButton: NSButton {
    var sampleCursor: NSCursor = .arrow {
        didSet {
            guard sampleCursor !== oldValue, let window else { return }
            window.invalidateCursorRects(for: self)
            let pointer = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if window.isKeyWindow, bounds.contains(pointer) { sampleCursor.set() }
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: sampleCursor)
    }
}

private struct SampleButton: NSViewRepresentable {
    let settings: ThemeSettings
    let role: CursorRole
    let expression: CatExpression
    let title: String
    let color: Color
    let onPress: () -> Void

    final class Coordinator: NSObject {
        var onPress: (() -> Void)?
        var lastSettings: ThemeSettings?
        var openCursor: NSCursor = .arrow
        var closedCursor: NSCursor?

        @objc func press() {
            onPress?()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> CursorSampleButton {
        let button = CursorSampleButton()
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.press)
        button.setAccessibilityIdentifier("preview-\(role.rawValue)")
        if role == .link { button.setAccessibilityRole(.link) }
        return button
    }

    func updateNSView(_ button: CursorSampleButton, context: Context) {
        context.coordinator.onPress = onPress
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor(color)
        ]
        if role == .link { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
        button.setAccessibilityLabel(title)
        let coordinator = context.coordinator
        if coordinator.lastSettings != settings {
            coordinator.openCursor = CursorArtwork.cursor(settings, role: role)
            coordinator.closedCursor = settings.theme == .paperCat
                ? CursorArtwork.cursor(settings, role: role, expression: .blink)
                : nil
            coordinator.lastSettings = settings
        }
        button.sampleCursor = expression == .blink ? (coordinator.closedCursor ?? coordinator.openCursor)
                                                   : coordinator.openCursor
    }
}

private final class CursorSampleText: NSTextField {
    var sampleCursor: NSCursor = .iBeam {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: sampleCursor)
    }
}

private struct SampleText: NSViewRepresentable {
    let settings: ThemeSettings
    let color: Color

    final class Coordinator {
        var lastSettings: ThemeSettings?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> CursorSampleText {
        let field = CursorSampleText()
        field.stringValue = "选中这行字"
        field.font = .systemFont(ofSize: 12)
        field.alignment = .center
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.isEditable = false
        field.isSelectable = true
        field.setAccessibilityIdentifier("preview-text")
        return field
    }

    func updateNSView(_ field: CursorSampleText, context: Context) {
        field.textColor = NSColor(color)
        if context.coordinator.lastSettings != settings {
            field.sampleCursor = CursorArtwork.cursor(settings, role: .text)
            context.coordinator.lastSettings = settings
        }
    }
}
