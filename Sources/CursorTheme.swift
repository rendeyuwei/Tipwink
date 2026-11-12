import AppKit
import SwiftUI

enum CursorRole: String, CaseIterable {
    case arrow
    case link
    case text

    static let catEar = CGPoint(x: 6, y: 5)
    static let ghostTip = CGPoint(x: 6, y: 5)
    static let crosshairCenter = CGPoint(x: 16, y: 18)

    var title: String {
        switch self {
        case .arrow: "指向"
        case .link: "链接"
        case .text: "文字"
        }
    }

    var hotSpot: CGPoint {
        switch self {
        case .arrow: CGPoint(x: 4, y: 4)
        case .link: CGPoint(x: 12, y: 4)
        case .text: CGPoint(x: 16, y: 18)
        }
    }
}

enum CatExpression {
    case open
    case blink

    static let blinkDuration: TimeInterval = 0.15
}

enum PaperCatStyle: String, CaseIterable, Identifiable, Codable {
    case classic
    case catOnly

    var id: Self { self }

    var title: String {
        switch self {
        case .classic: "经典"
        case .catOnly: "纯猫"
        }
    }

    var detail: String {
        switch self {
        case .classic: "小猫趴在箭头边，点一下就眨眼。"
        case .catOnly: "用左耳尖指向，点一下就眨眼。遇到链接会抬爪。"
        }
    }
}

enum CursorTheme: String, CaseIterable, Identifiable, Codable {
    case paperCat
    case pixelJelly
    case twoTone
    case paperPlane
    case gummyGhost
    case nightCrosshair

    var id: Self { self }

    var name: String {
        switch self {
        case .paperCat: "纸片猫"
        case .pixelJelly: "像素果冻"
        case .twoTone: "双色箭头"
        case .paperPlane: "纸飞机"
        case .gummyGhost: "软糖幽灵"
        case .nightCrosshair: "夜光准星"
        }
    }

    var detail: String {
        switch self {
        case .paperCat: PaperCatStyle.classic.detail
        case .pixelJelly: "葡萄紫和薄荷绿，像一颗小小的像素糖。"
        case .twoTone: "自由搭配填充和描边，做一套日常指针。"
        case .paperPlane: "冰蓝色的折纸机翼，用机鼻指向。"
        case .gummyGhost: "用左上角的小尖定位，移到链接上会抬手。"
        case .nightCrosshair: "薄荷绿的刻线围出中心点，方便精确对位。"
        }
    }

    var swatch: Color {
        switch self {
        case .paperCat: Color(red: 0.99, green: 0.88, blue: 0.78)
        case .pixelJelly: Color(red: 0.88, green: 0.84, blue: 1)
        case .twoTone: Color(red: 0.81, green: 0.90, blue: 0.88)
        case .paperPlane: Color(red: 0.79, green: 0.88, blue: 0.98)
        case .gummyGhost: Color(red: 0.93, green: 0.86, blue: 0.94)
        case .nightCrosshair: Color(red: 0.15, green: 0.23, blue: 0.29)
        }
    }
}

struct RGB: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(_ hex: UInt32) {
        red = Double((hex >> 16) & 255) / 255
        green = Double((hex >> 8) & 255) / 255
        blue = Double(hex & 255) / 255
    }

    init?(color: Color) {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        red = Double(converted.redComponent)
        green = Double(converted.greenComponent)
        blue = Double(converted.blueComponent)
    }

    var color: Color { Color(red: red, green: green, blue: blue) }
    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

struct ThemeSettings: Codable, Equatable {
    var theme: CursorTheme = .paperCat
    var scale: Double = 1
    var fill = RGB(0x224345)
    var outline = RGB(0xECFFFC)
    var paperCatStyle: PaperCatStyle = .classic

    var detail: String { theme == .paperCat ? paperCatStyle.detail : theme.detail }

    var imageSize: CGSize {
        CGSize(width: (32 * scale).rounded(), height: (36 * scale).rounded())
    }

    func hotSpot(for role: CursorRole) -> CGPoint {
        let base = switch (theme, role) {
        case (.paperCat, .arrow) where paperCatStyle == .catOnly: CursorRole.catEar
        case (.gummyGhost, .arrow): CursorRole.ghostTip
        case (.nightCrosshair, .arrow): CursorRole.crosshairCenter
        default: role.hotSpot
        }
        return CGPoint(x: base.x * imageSize.width / 32, y: base.y * imageSize.height / 36)
    }

    func hasSameAppearance(as other: ThemeSettings) -> Bool {
        guard theme == other.theme, scale == other.scale else { return false }
        switch theme {
        case .paperCat: return paperCatStyle == other.paperCatStyle
        case .pixelJelly, .paperPlane, .gummyGhost, .nightCrosshair: return true
        case .twoTone: return fill == other.fill && outline == other.outline
        }
    }
}

extension ThemeSettings {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            theme: try values.decode(CursorTheme.self, forKey: .theme),
            scale: try values.decode(Double.self, forKey: .scale),
            fill: try values.decode(RGB.self, forKey: .fill),
            outline: try values.decode(RGB.self, forKey: .outline),
            paperCatStyle: try values.decodeIfPresent(PaperCatStyle.self, forKey: .paperCatStyle) ?? .classic
        )
    }
}

enum CursorArtwork {
    static func bitmap(
        _ settings: ThemeSettings, role: CursorRole, expression: CatExpression = .open, pixelsPerPoint: Int
    ) -> CGImage? {
        let size = settings.imageSize
        let width = Int(size.width) * pixelsPerPoint
        let height = Int(size.height) * pixelsPerPoint
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(width) / 32, y: -CGFloat(height) / 36)
        draw(settings, role: role, expression: expression, in: context)
        return context.makeImage()
    }

    static func image(
        _ settings: ThemeSettings, role: CursorRole, expression: CatExpression = .open, density: Int = 4
    ) -> NSImage {
        let result = NSImage(size: settings.imageSize)
        for scale in Set([1, density]).sorted() {
            guard let bitmap = bitmap(settings, role: role, expression: expression, pixelsPerPoint: scale)
            else { continue }
            let representation = NSBitmapImageRep(cgImage: bitmap)
            representation.size = settings.imageSize
            result.addRepresentation(representation)
        }
        return result
    }

    static func cursor(_ settings: ThemeSettings, role: CursorRole, expression: CatExpression = .open) -> NSCursor {
        NSCursor(image: image(settings, role: role, expression: expression, density: 2),
                 hotSpot: settings.hotSpot(for: role))
    }

    private static let arrow = path {
        $0.move(to: CGPoint(x: 4, y: 4))
        $0.addLine(to: CGPoint(x: 23, y: 19))
        $0.addLine(to: CGPoint(x: 14.7, y: 20.4))
        $0.addLine(to: CGPoint(x: 19, y: 28.8))
        $0.addLine(to: CGPoint(x: 14.4, y: 31))
        $0.addLine(to: CGPoint(x: 10.3, y: 22.4))
        $0.addLine(to: CGPoint(x: 4.5, y: 28.5))
        $0.closeSubpath()
    }

    private static let hand = path {
        $0.move(to: CGPoint(x: 9, y: 18))
        $0.addLine(to: CGPoint(x: 9, y: 7))
        $0.addQuadCurve(to: CGPoint(x: 15, y: 7), control: CGPoint(x: 12, y: 1))
        $0.addLine(to: CGPoint(x: 15, y: 13))
        $0.addQuadCurve(to: CGPoint(x: 20, y: 13.5), control: CGPoint(x: 17.5, y: 11))
        $0.addQuadCurve(to: CGPoint(x: 24, y: 15.5), control: CGPoint(x: 22.5, y: 12))
        $0.addQuadCurve(to: CGPoint(x: 28, y: 19.4), control: CGPoint(x: 28, y: 14.8))
        $0.addLine(to: CGPoint(x: 27.3, y: 24.2))
        $0.addQuadCurve(to: CGPoint(x: 23.4, y: 31), control: CGPoint(x: 26.9, y: 28.6))
        $0.addLine(to: CGPoint(x: 14, y: 31))
        $0.addQuadCurve(to: CGPoint(x: 9.8, y: 25.5), control: CGPoint(x: 11, y: 29.7))
        $0.addLine(to: CGPoint(x: 5.1, y: 21.5))
        $0.addQuadCurve(to: CGPoint(x: 9, y: 18), control: CGPoint(x: 3.3, y: 17.2))
        $0.closeSubpath()
    }

    private static let beam = path {
        $0.addLines(between: [
            CGPoint(x: 9, y: 6), CGPoint(x: 23, y: 6), CGPoint(x: 23, y: 9.5),
            CGPoint(x: 17.8, y: 9.5), CGPoint(x: 17.8, y: 26.5), CGPoint(x: 23, y: 26.5),
            CGPoint(x: 23, y: 30), CGPoint(x: 9, y: 30), CGPoint(x: 9, y: 26.5),
            CGPoint(x: 14.2, y: 26.5), CGPoint(x: 14.2, y: 9.5), CGPoint(x: 9, y: 9.5)
        ])
        $0.closeSubpath()
    }

    private static let pixelArrow = path {
        $0.addLines(between: [
            CGPoint(x: 4, y: 4), CGPoint(x: 8, y: 4), CGPoint(x: 8, y: 7),
            CGPoint(x: 11, y: 7), CGPoint(x: 11, y: 10), CGPoint(x: 15, y: 10),
            CGPoint(x: 15, y: 13), CGPoint(x: 19, y: 13), CGPoint(x: 19, y: 16),
            CGPoint(x: 23, y: 16), CGPoint(x: 23, y: 21), CGPoint(x: 16, y: 21),
            CGPoint(x: 16, y: 24), CGPoint(x: 19, y: 24), CGPoint(x: 19, y: 28),
            CGPoint(x: 16, y: 28), CGPoint(x: 16, y: 31), CGPoint(x: 12, y: 31),
            CGPoint(x: 12, y: 26), CGPoint(x: 9, y: 26), CGPoint(x: 9, y: 29),
            CGPoint(x: 4, y: 29)
        ])
        $0.closeSubpath()
    }

    private static let pixelHand = path {
        $0.addLines(between: [
            CGPoint(x: 12, y: 4), CGPoint(x: 16, y: 4), CGPoint(x: 16, y: 13),
            CGPoint(x: 21, y: 13), CGPoint(x: 21, y: 15), CGPoint(x: 26, y: 15),
            CGPoint(x: 26, y: 17), CGPoint(x: 29, y: 17), CGPoint(x: 29, y: 25),
            CGPoint(x: 26, y: 25), CGPoint(x: 26, y: 29), CGPoint(x: 23, y: 29),
            CGPoint(x: 23, y: 32), CGPoint(x: 13, y: 32), CGPoint(x: 13, y: 29),
            CGPoint(x: 10, y: 29), CGPoint(x: 10, y: 26), CGPoint(x: 7, y: 26),
            CGPoint(x: 7, y: 23), CGPoint(x: 5, y: 23), CGPoint(x: 5, y: 19),
            CGPoint(x: 9, y: 19), CGPoint(x: 9, y: 21), CGPoint(x: 10, y: 21),
            CGPoint(x: 10, y: 6), CGPoint(x: 12, y: 6)
        ])
        $0.closeSubpath()
    }

    private static func draw(
        _ settings: ThemeSettings, role: CursorRole, expression: CatExpression, in context: CGContext
    ) {
        switch settings.theme {
        case .paperCat:
            drawCat(role, style: settings.paperCatStyle, expression: expression, in: context)
        case .pixelJelly:
            drawPixel(role, in: context)
        case .twoTone:
            let shape = switch role {
            case .arrow: arrow
            case .link: hand
            case .text: beam
            }
            paint(shape, fill: settings.fill, stroke: settings.outline, width: 2, in: context)
        case .paperPlane:
            drawPaperPlane(role, in: context)
        case .gummyGhost:
            drawGummyGhost(role, in: context)
        case .nightCrosshair:
            drawNightCrosshair(role, in: context)
        }
    }

    private static let catInk = RGB(0x35272A)
    private static let catCream = RGB(0xFFF3DB)
    private static let catPaper = RGB(0xFFFCF3)
    private static let catPeach = RGB(0xFFA475)
    private static let originalEar = CGPoint(x: 15.6, y: 16.3)

    private static let catHead = path {
        $0.move(to: CGPoint(x: 15, y: 26))
        $0.addQuadCurve(to: CGPoint(x: 16, y: 21.5), control: CGPoint(x: 14.3, y: 23.5))
        $0.addLine(to: originalEar)
        $0.addQuadCurve(to: CGPoint(x: 20.1, y: 19), control: CGPoint(x: 17.5, y: 16.1))
        $0.addQuadCurve(to: CGPoint(x: 24, y: 19), control: CGPoint(x: 22, y: 18.4))
        $0.addQuadCurve(to: CGPoint(x: 28.4, y: 16.6), control: CGPoint(x: 27.7, y: 16.4))
        $0.addLine(to: CGPoint(x: 28, y: 21.8))
        $0.addCurve(to: CGPoint(x: 25, y: 30), control1: CGPoint(x: 31.8, y: 25),
                    control2: CGPoint(x: 28.7, y: 29.5))
        $0.addQuadCurve(to: CGPoint(x: 15, y: 26), control: CGPoint(x: 19, y: 31.1))
        $0.closeSubpath()
    }

    private static let classicCatArrow = path {
        $0.move(to: CursorRole.arrow.hotSpot)
        $0.addLine(to: CGPoint(x: 18.7, y: 16))
        $0.addLine(to: CGPoint(x: 12, y: 17.2))
        $0.addLine(to: CGPoint(x: 15.2, y: 23.5))
        $0.addLine(to: CGPoint(x: 11.1, y: 25.4))
        $0.addLine(to: CGPoint(x: 8.3, y: 19.2))
        $0.addLine(to: CGPoint(x: 4.5, y: 23.3))
        $0.closeSubpath()
    }

    private static let raisedPaw = path {
        $0.move(to: CursorRole.link.hotSpot)
        $0.addQuadCurve(to: CGPoint(x: 15.2, y: 7.8), control: CGPoint(x: 14.4, y: 4.2))
        $0.addQuadCurve(to: CGPoint(x: 16.1, y: 15), control: CGPoint(x: 17.2, y: 11.6))
        $0.addCurve(to: CGPoint(x: 10, y: 20.4), control1: CGPoint(x: 15.1, y: 18.2),
                    control2: CGPoint(x: 12.8, y: 20.8))
        $0.addQuadCurve(to: CGPoint(x: 7.8, y: 13.1), control: CGPoint(x: 6.6, y: 18.8))
        $0.addQuadCurve(to: CGPoint(x: 9.7, y: 6.2), control: CGPoint(x: 8.1, y: 9.3))
        $0.addQuadCurve(to: CursorRole.link.hotSpot, control: CGPoint(x: 10.5, y: 4.3))
        $0.closeSubpath()
    }

    private static func drawCat(
        _ role: CursorRole, style: PaperCatStyle, expression: CatExpression, in context: CGContext
    ) {
        switch (role, style) {
        case (.arrow, .classic):
            drawCatFace(expression, in: context)
            paint(classicCatArrow, fill: catInk, stroke: catPaper, width: 2.25, in: context)
        case (.link, .classic):
            paint(hand, fill: catCream, stroke: catPaper, width: 4.5, in: context)
            paint(hand, fill: catCream, stroke: catInk, width: 1.75, in: context)
            let pad = expression == .blink ? RGB(0xE4775A) : catPeach
            dot(19.7, 23.7, 5.9, color: pad, in: context)
            for toe in [CGPoint(x: 15.8, y: 20.6), CGPoint(x: 19, y: 18.8), CGPoint(x: 22.3, y: 19.9)] {
                dot(toe.x, toe.y, 2.25, color: pad, in: context)
            }
        case (.arrow, .catOnly):
            drawCatFace(expression, earAt: CursorRole.catEar, scale: 1.48, in: context)
        case (.link, .catOnly):
            drawCatFace(expression, earAt: CGPoint(x: 10.7, y: 14.2), scale: 1.20, in: context)
            paintSticker(raisedPaw, in: context)
            dot(12, 13.8, 3.8, color: catPeach, in: context)
            dot(10.3, 10.5, 1.35, color: catPeach, in: context)
            dot(12.4, 8.6, 1.45, color: catPeach, in: context)
            dot(14.3, 10.4, 1.35, color: catPeach, in: context)
        case (.text, _):
            paint(beam, fill: catInk, stroke: catPaper, width: 2.1, in: context)
            dot(11, 7.8, 2, color: catPeach, in: context)
            dot(21, 28.2, 2, color: catPeach, in: context)
        }
    }

    private static func drawCatFace(
        _ expression: CatExpression, earAt anchor: CGPoint, scale: CGFloat, in context: CGContext
    ) {
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -originalEar.x, y: -originalEar.y)
        drawCatFace(expression, in: context)
        context.restoreGState()
    }

    private static func drawCatFace(_ expression: CatExpression, in context: CGContext) {
        paintSticker(catHead, in: context)

        for x: CGFloat in [18.5, 24.6] {
            if expression == .blink {
                let eye = path {
                    $0.move(to: CGPoint(x: x - 1.2, y: 24.6))
                    $0.addQuadCurve(to: CGPoint(x: x + 1.2, y: 24.6), control: CGPoint(x: x, y: 22.7))
                }
                stroke(eye, color: catInk, width: 1.05, in: context)
            } else {
                dot(x, 24.4, 1.4, color: catInk, in: context)
            }
        }

        let blush = RGB(0xF6A290)
        dot(17.4, 25.9, 1.25, color: blush, in: context)
        dot(26.7, 25.8, 1.65, color: blush, in: context)
        dot(21.6, 25.8, 1.25, color: catPeach, in: context)

        let smile = path {
            $0.move(to: CGPoint(x: 20.4, y: 27))
            $0.addQuadCurve(to: CGPoint(x: 21.6, y: 26.5), control: CGPoint(x: 21, y: 27.6))
            $0.addQuadCurve(to: CGPoint(x: 22.8, y: 27), control: CGPoint(x: 22.2, y: 27.6))
        }
        stroke(smile, color: catInk, width: 0.55, in: context)
    }

    private static func paintSticker(_ shape: CGPath, in context: CGContext) {
        paint(shape, fill: catCream, stroke: catPaper, width: 4.1, in: context)
        paint(shape, fill: catCream, stroke: catInk, width: 1.5, in: context)
    }

    private static func stroke(_ shape: CGPath, color: RGB, width: CGFloat, in context: CGContext) {
        context.setLineCap(.round)
        context.setLineWidth(width)
        context.setStrokeColor(color.cgColor)
        context.addPath(shape)
        context.strokePath()
    }

    private static func drawPixel(_ role: CursorRole, in context: CGContext) {
        let grape = RGB(0x352365)
        let jelly = RGB(0xA489F4)
        let mint = RGB(0xA5F8DD)
        let halo = RGB(0xFFF9FF)
        let shape = switch role {
        case .arrow: pixelArrow
        case .link: pixelHand
        case .text: beam
        }
        paint(shape, fill: jelly, stroke: halo, width: 4.2, square: true, in: context)
        paint(shape, fill: jelly, stroke: grape, width: 1.8, square: true, in: context)
        let sparkle = switch role {
        case .arrow: CGRect(x: 7, y: 8, width: 2.5, height: 4)
        case .link: CGRect(x: 17, y: 21, width: 6, height: 3)
        case .text: CGRect(x: 10.2, y: 7, width: 3.1, height: 1.6)
        }
        context.setFillColor(mint.cgColor)
        context.fill(sparkle)
    }

    private static func path(_ build: (CGMutablePath) -> Void) -> CGPath {
        let result = CGMutablePath()
        build(result)
        return result
    }

    private static func paint(
        _ shape: CGPath, fill: RGB, stroke: RGB, width: CGFloat, square: Bool = false,
        in context: CGContext
    ) {
        context.setLineJoin(square ? .miter : .round)
        context.setLineWidth(width)
        context.setFillColor(fill.cgColor)
        context.setStrokeColor(stroke.cgColor)
        context.addPath(shape)
        context.drawPath(using: .fillStroke)
    }

    private static func dot(_ x: CGFloat, _ y: CGFloat, _ size: CGFloat, color: RGB, in context: CGContext) {
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size))
    }
}

private extension CursorArtwork {
    static let planeFold = CGPoint(x: 20.2, y: 17.2)
    static let planeTail = CGPoint(x: 17.0, y: 28.6)
    static let planeValley = CGPoint(x: 13.9, y: 21)
    static let planeLeftWing = CGPoint(x: 10.2, y: 24.9)
    static let plane = path {
        $0.addLines(between: [
            CursorRole.arrow.hotSpot, CGPoint(x: 28.8, y: 13.8),
            planeFold, planeTail, planeValley, planeLeftWing
        ])
        $0.closeSubpath()
    }
    static let planeUnderside = path {
        $0.addLines(between: [CursorRole.arrow.hotSpot, planeFold, planeTail, planeValley])
        $0.closeSubpath()
    }
    static let planeNearWing = path {
        $0.addLines(between: [CursorRole.arrow.hotSpot, planeValley, planeLeftWing])
        $0.closeSubpath()
    }

    static func drawPaperPlane(_ role: CursorRole, in context: CGContext) {
        let ink = RGB(0x253653)
        let paper = RGB(0xF0FAFF)
        let sky = RGB(0x90CDF3)
        switch role {
        case .arrow:
            paint(plane, fill: paper, stroke: RGB(0xFFFFFF), width: 4, in: context)
            context.setFillColor(sky.cgColor)
            context.addPath(planeUnderside)
            context.fillPath()
            context.setFillColor(RGB(0xC6E8FB).cgColor)
            context.addPath(planeNearWing)
            context.fillPath()
            context.setLineJoin(.round)
            stroke(plane, color: ink, width: 1.55, in: context)
            let crease = path {
                $0.addLines(between: [CursorRole.arrow.hotSpot, planeFold])
            }
            stroke(crease, color: RGB(0x49749D), width: 1.2, in: context)
        case .link:
            paint(hand, fill: paper, stroke: RGB(0xFFFFFF), width: 4, in: context)
            paint(hand, fill: paper, stroke: ink, width: 1.55, in: context)
            let fold = path {
                $0.addLines(between: [
                    CGPoint(x: 13.6, y: 19.4), CGPoint(x: 23.6, y: 21.2),
                    CGPoint(x: 18.4, y: 23), CGPoint(x: 16.6, y: 26.4)
                ])
                $0.closeSubpath()
            }
            paint(fold, fill: sky, stroke: RGB(0x49749D), width: 0.9, in: context)
        case .text:
            paint(beam, fill: ink, stroke: paper, width: 2.5, in: context)
            drawBeamCaps(sky, in: context)
        }
    }

    static let ghostInk = RGB(0x3C2D60)
    static let ghostLilac = RGB(0xDCD2FF)
    static let ghostPaper = RGB(0xFFFAFF)
    static let ghostBody = path {
        $0.move(to: CursorRole.ghostTip)
        $0.addQuadCurve(to: CGPoint(x: 9.8, y: 6.6), control: CGPoint(x: 8.3, y: 4.5))
        $0.addCurve(to: CGPoint(x: 25.6, y: 16), control1: CGPoint(x: 19.6, y: 1.9),
                    control2: CGPoint(x: 26, y: 8.8))
        $0.addCurve(to: CGPoint(x: 27, y: 25.6), control1: CGPoint(x: 25.4, y: 21.1),
                    control2: CGPoint(x: 27.5, y: 23.1))
        $0.addQuadCurve(to: CGPoint(x: 22.2, y: 28.5), control: CGPoint(x: 26.5, y: 30.7))
        $0.addQuadCurve(to: CGPoint(x: 18.2, y: 29), control: CGPoint(x: 19.9, y: 27.1))
        $0.addQuadCurve(to: CGPoint(x: 14.2, y: 29.6), control: CGPoint(x: 16.1, y: 31.9))
        $0.addQuadCurve(to: CGPoint(x: 10.1, y: 28.7), control: CGPoint(x: 12.4, y: 27.4))
        $0.addCurve(to: CGPoint(x: 5, y: 26.2), control1: CGPoint(x: 7.1, y: 30.8),
                    control2: CGPoint(x: 4.2, y: 29.5))
        $0.addQuadCurve(to: CGPoint(x: 6.7, y: 17.3), control: CGPoint(x: 6.1, y: 22.1))
        $0.addQuadCurve(to: CursorRole.ghostTip, control: CGPoint(x: 7.6, y: 9.8))
        $0.closeSubpath()
    }
    static let ghostWave = path {
        $0.move(to: CursorRole.link.hotSpot)
        $0.addQuadCurve(to: CGPoint(x: 14.1, y: 6.4), control: CGPoint(x: 14.2, y: 4.1))
        $0.addLine(to: CGPoint(x: 14, y: 10.3))
        $0.addQuadCurve(to: CGPoint(x: 17.3, y: 9.4), control: CGPoint(x: 15.7, y: 7.3))
        $0.addQuadCurve(to: CGPoint(x: 15.7, y: 16.2), control: CGPoint(x: 18.4, y: 12.5))
        $0.addQuadCurve(to: CGPoint(x: 9.2, y: 15.1), control: CGPoint(x: 12.8, y: 19.3))
        $0.addQuadCurve(to: CGPoint(x: 7.2, y: 10.4), control: CGPoint(x: 6.6, y: 12.4))
        $0.addQuadCurve(to: CGPoint(x: 10, y: 11.4), control: CGPoint(x: 8.6, y: 9.3))
        $0.addLine(to: CGPoint(x: 10, y: 6.5))
        $0.addQuadCurve(to: CursorRole.link.hotSpot, control: CGPoint(x: 10, y: 4.2))
        $0.closeSubpath()
    }

    static func drawGummyGhost(_ role: CursorRole, in context: CGContext) {
        switch role {
        case .arrow:
            drawGhostFace(in: context)
        case .link:
            context.saveGState()
            context.translateBy(x: 5, y: 9)
            context.scaleBy(x: 0.8, y: 0.8)
            drawGhostFace(in: context)
            context.restoreGState()
            paint(ghostWave, fill: ghostLilac, stroke: ghostPaper, width: 3.8, in: context)
            paint(ghostWave, fill: ghostLilac, stroke: ghostInk, width: 1.5, in: context)
            dot(12.4, 13.6, 2.6, color: RGB(0xB09BEE), in: context)
        case .text:
            paint(beam, fill: ghostInk, stroke: ghostPaper, width: 2.5, in: context)
            drawBeamCaps(ghostLilac, in: context)
        }
    }

    static func drawGhostFace(in context: CGContext) {
        paint(ghostBody, fill: ghostLilac, stroke: ghostPaper, width: 4.2, in: context)
        context.saveGState()
        context.addPath(ghostBody)
        context.clip()
        let shadow = path {
            $0.move(to: CGPoint(x: 4, y: 26.5))
            $0.addQuadCurve(to: CGPoint(x: 28, y: 22.2), control: CGPoint(x: 15, y: 29.4))
            $0.addLine(to: CGPoint(x: 28, y: 32))
            $0.addLine(to: CGPoint(x: 4, y: 32))
            $0.closeSubpath()
        }
        context.setFillColor(RGB(0xB49FF0).cgColor)
        context.addPath(shadow)
        context.fillPath()
        context.restoreGState()
        stroke(ghostBody, color: ghostInk, width: 1.55, in: context)
        let shine = path {
            $0.move(to: CGPoint(x: 13.9, y: 9.6))
            $0.addQuadCurve(to: CGPoint(x: 20.4, y: 10.6), control: CGPoint(x: 17.6, y: 7.5))
        }
        stroke(shine, color: ghostPaper, width: 1.6, in: context)
        context.setFillColor(ghostInk.cgColor)
        context.fillEllipse(in: CGRect(x: 12.3, y: 14.9, width: 1.9, height: 2.8))
        context.fillEllipse(in: CGRect(x: 19.1, y: 14.5, width: 1.9, height: 2.8))
        dot(11.2, 19.4, 2.6, color: RGB(0xF8A6C2), in: context)
        dot(22, 18.9, 2.6, color: RGB(0xF8A6C2), in: context)
        let smile = path {
            $0.move(to: CGPoint(x: 15.5, y: 18.4))
            $0.addQuadCurve(to: CGPoint(x: 18.2, y: 18.2), control: CGPoint(x: 17, y: 20.4))
        }
        stroke(smile, color: ghostInk, width: 0.95, in: context)
    }

    static let crosshair = path {
        let center = CursorRole.crosshairCenter
        for direction in [-1.0, 1.0] {
            let inner = 5.2 * direction
            let outer = 12.4 * direction
            $0.move(to: CGPoint(x: center.x + inner, y: center.y))
            $0.addLine(to: CGPoint(x: center.x + outer, y: center.y))
            $0.move(to: CGPoint(x: center.x, y: center.y + inner))
            $0.addLine(to: CGPoint(x: center.x, y: center.y + outer))
        }
    }

    static func drawNightCrosshair(_ role: CursorRole, in context: CGContext) {
        let ink = RGB(0x102431)
        let mint = RGB(0xACFBE3)
        switch role {
        case .arrow:
            stroke(crosshair, color: ink, width: 5, in: context)
            stroke(crosshair, color: mint, width: 2.1, in: context)
            let center = CursorRole.crosshairCenter
            dot(center.x, center.y, 3.9, color: ink, in: context)
            dot(center.x, center.y, 1.95, color: mint, in: context)
        case .link:
            paint(hand, fill: ink, stroke: ink, width: 3.9, in: context)
            paint(hand, fill: ink, stroke: mint, width: 1.6, in: context)
            let palmMark = path {
                $0.addLines(between: [CGPoint(x: 16, y: 22), CGPoint(x: 22, y: 22)])
                $0.move(to: CGPoint(x: 19, y: 19))
                $0.addLine(to: CGPoint(x: 19, y: 25))
            }
            stroke(palmMark, color: mint, width: 1.55, in: context)
        case .text:
            paint(beam, fill: mint, stroke: ink, width: 2.4, in: context)
        }
    }

    static func drawBeamCaps(_ color: RGB, in context: CGContext) {
        let caps = path {
            $0.addLines(between: [CGPoint(x: 11.6, y: 7.75), CGPoint(x: 20.4, y: 7.75)])
            $0.move(to: CGPoint(x: 11.6, y: 28.25))
            $0.addLine(to: CGPoint(x: 20.4, y: 28.25))
        }
        stroke(caps, color: color, width: 1.5, in: context)
    }
}
