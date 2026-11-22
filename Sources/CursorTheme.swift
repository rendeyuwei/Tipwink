import AppKit
import SwiftUI

enum CursorRole: String, CaseIterable {
    case arrow
    case link
    case text

    static let catEar = CGPoint(x: 6, y: 5)
    static let pencilTip = CGPoint(x: 5, y: 4)

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

enum PaperCatBreed: String, CaseIterable, Identifiable, Codable {
    case orangeTabby
    case britishBlue
    case ragdoll

    var id: Self { self }

    var title: String {
        switch self {
        case .orangeTabby: "橘纹美短"
        case .britishBlue: "英短蓝猫"
        case .ragdoll: "布偶猫"
        }
    }
}

enum CursorTheme: String, CaseIterable, Identifiable, Codable {
    case paperCat
    case pixelJelly
    case twoTone
    case pencil

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        let identifier = try value.decode(String.self)
        switch identifier {
        case "paperPlane", "gummyGhost", "nightCrosshair":
            self = .pencil
        default:
            guard let theme = Self(rawValue: identifier) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Unknown cursor theme: \(identifier)")
            }
            self = theme
        }
    }

    var id: Self { self }

    var name: String {
        switch self {
        case .paperCat: "纸片猫"
        case .pixelJelly: "像素果冻"
        case .twoTone: "双色箭头"
        case .pencil: "铅笔"
        }
    }

    var detail: String {
        switch self {
        case .paperCat: PaperCatStyle.classic.detail
        case .pixelJelly: "葡萄紫和薄荷绿，像一颗小小的像素糖。"
        case .twoTone: "自由搭配填充和描边，做一套日常指针。"
        case .pencil: "琥珀色短铅笔，用笔尖指向和点击。"
        }
    }

    var swatch: Color {
        switch self {
        case .paperCat: Color(red: 0.99, green: 0.88, blue: 0.78)
        case .pixelJelly: Color(red: 0.88, green: 0.84, blue: 1)
        case .twoTone: RGB(0xF7E0EA).color
        case .pencil: RGB(0xF6E7CD).color
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
    var fill = RGB(0xFF78AE)
    var outline = RGB(0x541B3D)
    var paperCatStyle: PaperCatStyle = .classic
    var paperCatBreed: PaperCatBreed = .orangeTabby

    var detail: String { theme == .paperCat ? paperCatStyle.detail : theme.detail }

    var imageSize: CGSize {
        CGSize(width: (32 * scale).rounded(), height: (36 * scale).rounded())
    }

    func hotSpot(for role: CursorRole) -> CGPoint {
        let base = switch (theme, role) {
        case (.paperCat, .arrow) where paperCatStyle == .catOnly: CursorRole.catEar
        case (.pencil, .arrow): CursorRole.pencilTip
        default: role.hotSpot
        }
        return CGPoint(x: base.x * imageSize.width / 32, y: base.y * imageSize.height / 36)
    }

    func hasSameAppearance(as other: ThemeSettings) -> Bool {
        guard theme == other.theme, scale == other.scale else { return false }
        switch theme {
        case .paperCat:
            return paperCatStyle == other.paperCatStyle && paperCatBreed == other.paperCatBreed
        case .pixelJelly, .pencil: return true
        case .twoTone: return fill == other.fill && outline == other.outline
        }
    }
}

extension ThemeSettings {
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let breed = try values.decodeIfPresent(String.self, forKey: .paperCatBreed)
        self.init(
            theme: try values.decode(CursorTheme.self, forKey: .theme),
            scale: try values.decode(Double.self, forKey: .scale),
            fill: try values.decode(RGB.self, forKey: .fill),
            outline: try values.decode(RGB.self, forKey: .outline),
            paperCatStyle: try values.decodeIfPresent(PaperCatStyle.self, forKey: .paperCatStyle) ?? .classic,
            paperCatBreed: breed.flatMap(PaperCatBreed.init(rawValue:)) ?? .orangeTabby
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
            drawCat(role, style: settings.paperCatStyle, breed: settings.paperCatBreed, expression: expression, in: context)
        case .pixelJelly:
            drawPixel(role, in: context)
        case .twoTone:
            let shape = switch role {
            case .arrow: arrow
            case .link: hand
            case .text: beam
            }
            paint(shape, fill: settings.fill, stroke: settings.outline, width: 2, in: context)
        case .pencil:
            drawPencil(role, in: context)
        }
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
    struct CatColors {
        let fur: RGB
        let muzzle: RGB
        let ears: RGB
        let markings: RGB
        let iris: RGB
        let paw: RGB
        let pads: RGB
    }

    static let catInk = RGB(0x35272A)
    static let catPaper = RGB(0xFFFCF3)
    static let faceEar = CGPoint(x: 3.3, y: 2.2)

    static func catColors(for breed: PaperCatBreed) -> CatColors {
        switch breed {
        case .orangeTabby:
            CatColors(
                fur: RGB(0xFFC17C), muzzle: RGB(0xFFF0D6), ears: RGB(0xF49779),
                markings: RGB(0xB85A2F), iris: RGB(0x613B29), paw: RGB(0xFFF0D6), pads: RGB(0xF48F64)
            )
        case .britishBlue:
            CatColors(
                fur: RGB(0x8896AF), muzzle: RGB(0xA7B2C3), ears: RGB(0xAC8FA8),
                markings: RGB(0x51476E), iris: RGB(0xFFC365), paw: RGB(0xABB9D4), pads: RGB(0x8877B4)
            )
        case .ragdoll:
            CatColors(
                fur: RGB(0xF9EDDA), muzzle: RGB(0xFFF8EA), ears: RGB(0xBE8C76),
                markings: RGB(0x8E6657), iris: RGB(0x7DC8F2), paw: RGB(0xF4E4D5), pads: RGB(0xAE786A)
            )
        }
    }

    static let tabbyHead = path {
        $0.move(to: faceEar)
        $0.addQuadCurve(to: CGPoint(x: 7.6, y: 5.6), control: CGPoint(x: 5, y: 2.2))
        $0.addQuadCurve(to: CGPoint(x: 14.1, y: 5.1), control: CGPoint(x: 10.4, y: 4.7))
        $0.addQuadCurve(to: CGPoint(x: 18.9, y: 2.6), control: CGPoint(x: 17.2, y: 2.6))
        $0.addQuadCurve(to: CGPoint(x: 19.8, y: 8.8), control: CGPoint(x: 20.2, y: 2.6))
        $0.addCurve(to: CGPoint(x: 20.2, y: 17.5), control1: CGPoint(x: 22.1, y: 11.5),
                    control2: CGPoint(x: 22.4, y: 15.1))
        $0.addQuadCurve(to: CGPoint(x: 11.2, y: 20.3), control: CGPoint(x: 17.8, y: 20.4))
        $0.addQuadCurve(to: CGPoint(x: 1.9, y: 16.3), control: CGPoint(x: 3.9, y: 20.2))
        $0.addQuadCurve(to: CGPoint(x: 2.4, y: 8.4), control: CGPoint(x: 0.2, y: 12.4))
        $0.addQuadCurve(to: faceEar, control: CGPoint(x: 2.1, y: 2.7))
        $0.closeSubpath()
    }

    static let britishHead = path {
        $0.move(to: faceEar)
        $0.addQuadCurve(to: CGPoint(x: 7.7, y: 5.4), control: CGPoint(x: 5.4, y: 2))
        $0.addQuadCurve(to: CGPoint(x: 14.5, y: 5.4), control: CGPoint(x: 11, y: 4.2))
        $0.addQuadCurve(to: CGPoint(x: 19.1, y: 3.3), control: CGPoint(x: 17.4, y: 2.5))
        $0.addQuadCurve(to: CGPoint(x: 19.6, y: 8.1), control: CGPoint(x: 20.5, y: 3.9))
        $0.addCurve(to: CGPoint(x: 11.2, y: 20.8), control1: CGPoint(x: 25.4, y: 15.1),
                    control2: CGPoint(x: 20.5, y: 21.1))
        $0.addCurve(to: CGPoint(x: 2.5, y: 7.9), control1: CGPoint(x: 1.9, y: 20.8),
                    control2: CGPoint(x: -2.5, y: 15.7))
        $0.addQuadCurve(to: faceEar, control: CGPoint(x: 1.1, y: 3.5))
        $0.closeSubpath()
    }

    static let ragdollHead = path {
        $0.move(to: faceEar)
        $0.addQuadCurve(to: CGPoint(x: 7.8, y: 5.1), control: CGPoint(x: 4.9, y: 2.1))
        $0.addQuadCurve(to: CGPoint(x: 14.2, y: 5.1), control: CGPoint(x: 11, y: 4.4))
        $0.addQuadCurve(to: CGPoint(x: 18.9, y: 2.8), control: CGPoint(x: 17.5, y: 2.7))
        $0.addQuadCurve(to: CGPoint(x: 19.5, y: 8.8), control: CGPoint(x: 20.2, y: 3.8))
        $0.addQuadCurve(to: CGPoint(x: 22, y: 13.7), control: CGPoint(x: 19.8, y: 11.7))
        $0.addLine(to: CGPoint(x: 20.4, y: 14.1))
        $0.addLine(to: CGPoint(x: 21.1, y: 16.2))
        $0.addQuadCurve(to: CGPoint(x: 11.2, y: 20.5), control: CGPoint(x: 17.8, y: 20.5))
        $0.addQuadCurve(to: CGPoint(x: 1.1, y: 16.1), control: CGPoint(x: 4.7, y: 20.3))
        $0.addLine(to: CGPoint(x: 1.9, y: 14.1))
        $0.addLine(to: CGPoint(x: 0.4, y: 13.5))
        $0.addQuadCurve(to: CGPoint(x: 2.6, y: 8.8), control: CGPoint(x: 2.2, y: 11.6))
        $0.addQuadCurve(to: faceEar, control: CGPoint(x: 1.9, y: 3.2))
        $0.closeSubpath()
    }

    static let innerEars = path {
        $0.addLines(between: [CGPoint(x: 3.8, y: 4.2), CGPoint(x: 6.7, y: 6.5), CGPoint(x: 3.9, y: 8)])
        $0.closeSubpath()
        $0.addLines(between: [CGPoint(x: 18.5, y: 4.5), CGPoint(x: 18.7, y: 8), CGPoint(x: 15.8, y: 6.5)])
        $0.closeSubpath()
    }

    static let tabbyStripes = path {
        $0.move(to: CGPoint(x: 8.1, y: 5.7))
        $0.addQuadCurve(to: CGPoint(x: 9.1, y: 8.6), control: CGPoint(x: 8.4, y: 7.8))
        $0.move(to: CGPoint(x: 11.6, y: 5.3))
        $0.addQuadCurve(to: CGPoint(x: 11.6, y: 8.1), control: CGPoint(x: 11.3, y: 6.6))
        $0.move(to: CGPoint(x: 14.8, y: 5.7))
        $0.addQuadCurve(to: CGPoint(x: 13.9, y: 8.4), control: CGPoint(x: 14.1, y: 7))
        $0.move(to: CGPoint(x: 19.6, y: 10.8))
        $0.addLine(to: CGPoint(x: 17.7, y: 11.3))
        $0.move(to: CGPoint(x: 20.4, y: 13.5))
        $0.addLine(to: CGPoint(x: 18.6, y: 13.7))
    }

    static let ragdollPoints = path {
        $0.move(to: CGPoint(x: 0, y: 0))
        $0.addLine(to: CGPoint(x: 22, y: 0))
        $0.addLine(to: CGPoint(x: 24, y: 14.7))
        $0.addQuadCurve(to: CGPoint(x: 16.6, y: 14.5), control: CGPoint(x: 19.7, y: 17.3))
        $0.addQuadCurve(to: CGPoint(x: 11.2, y: 5.5), control: CGPoint(x: 13.9, y: 10.6))
        $0.addQuadCurve(to: CGPoint(x: 5.9, y: 14.4), control: CGPoint(x: 8.6, y: 10.9))
        $0.addQuadCurve(to: CGPoint(x: -1, y: 14.3), control: CGPoint(x: 3.2, y: 16.4))
        $0.closeSubpath()
    }

    static let catSmile = path {
        $0.move(to: CGPoint(x: 8.9, y: 16.7))
        $0.addQuadCurve(to: CGPoint(x: 10.8, y: 16.3), control: CGPoint(x: 9.7, y: 17.8))
        $0.addQuadCurve(to: CGPoint(x: 12.5, y: 16.5), control: CGPoint(x: 11.7, y: 17.6))
    }

    static let classicCatArrow = path {
        $0.move(to: CursorRole.arrow.hotSpot)
        $0.addLine(to: CGPoint(x: 18.7, y: 16))
        $0.addLine(to: CGPoint(x: 12, y: 17.2))
        $0.addLine(to: CGPoint(x: 15.2, y: 23.5))
        $0.addLine(to: CGPoint(x: 11.1, y: 25.4))
        $0.addLine(to: CGPoint(x: 8.3, y: 19.2))
        $0.addLine(to: CGPoint(x: 4.5, y: 23.3))
        $0.closeSubpath()
    }

    static let claspingPaw = CGPath(ellipseIn: CGRect(x: 11.8, y: 22.3, width: 4.7, height: 4.9), transform: nil)

    static let raisedPaw = path {
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

    static func drawCat(
        _ role: CursorRole, style: PaperCatStyle, breed: PaperCatBreed, expression: CatExpression, in context: CGContext
    ) {
        let colors = catColors(for: breed)
        switch (role, style) {
        case (.arrow, .classic):
            paint(classicCatArrow, fill: catInk, stroke: catPaper, width: 2.25, in: context)
            drawCatFace(breed, colors: colors, expression: expression,
                        earAt: CGPoint(x: 15.8, y: 16.3), scale: 0.76, in: context)
            paintCatSticker(claspingPaw, fill: colors.paw, halo: 2.3, outline: 0.95, in: context)
        case (.link, .classic):
            paintCatSticker(hand, fill: colors.paw, halo: 4.5, outline: 1.75, in: context)
            let pad = expression == .blink ? colors.markings : colors.pads
            dot(19.7, 23.7, 5.9, color: pad, in: context)
            for toe in [CGPoint(x: 15.8, y: 20.6), CGPoint(x: 19, y: 18.8), CGPoint(x: 22.3, y: 19.9)] {
                dot(toe.x, toe.y, 2.25, color: pad, in: context)
            }
        case (.arrow, .catOnly):
            drawCatFace(breed, colors: colors, expression: expression,
                        earAt: CursorRole.catEar, scale: 1.18, in: context)
        case (.link, .catOnly):
            drawCatFace(breed, colors: colors, expression: expression,
                        earAt: CGPoint(x: 8.4, y: 13.2), scale: 1.04, in: context)
            paintCatSticker(raisedPaw, fill: colors.paw, halo: 3.7, outline: 1.5, in: context)
            dot(12, 13.8, 3.8, color: colors.pads, in: context)
            dot(10.3, 10.5, 1.35, color: colors.pads, in: context)
            dot(12.4, 8.6, 1.45, color: colors.pads, in: context)
            dot(14.3, 10.4, 1.35, color: colors.pads, in: context)
        case (.text, _):
            paint(beam, fill: catInk, stroke: catPaper, width: 2.1, in: context)
            dot(11, 7.8, 2, color: colors.pads, in: context)
            dot(21, 28.2, 2, color: colors.pads, in: context)
        }
    }

    static func drawCatFace(
        _ breed: PaperCatBreed, colors: CatColors, expression: CatExpression,
        earAt anchor: CGPoint, scale: CGFloat, in context: CGContext
    ) {
        let head = switch breed {
        case .orangeTabby: tabbyHead
        case .britishBlue: britishHead
        case .ragdoll: ragdollHead
        }
        context.saveGState()
        context.translateBy(x: anchor.x, y: anchor.y)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -faceEar.x, y: -faceEar.y)
        paint(head, fill: colors.fur, stroke: catPaper, width: 3.7, in: context)

        context.saveGState()
        context.addPath(head)
        context.clip()
        if breed == .ragdoll {
            context.setFillColor(colors.markings.cgColor)
            context.addPath(ragdollPoints)
            context.fillPath()
        }
        context.setFillColor(colors.ears.cgColor)
        context.addPath(innerEars)
        context.fillPath()
        if breed == .orangeTabby { stroke(tabbyStripes, color: colors.markings, width: 1.45, in: context) }
        context.setFillColor(colors.muzzle.cgColor)
        context.fillEllipse(in: CGRect(x: 5.1, y: 13.2, width: 12, height: 6.2))
        context.restoreGState()
        stroke(head, color: catInk, width: 1.45, in: context)

        drawCatEye(at: CGPoint(x: 7, y: 11.8), iris: colors.iris, expression: expression, in: context)
        drawCatEye(at: CGPoint(x: 15, y: 11.4), iris: colors.iris, expression: expression, in: context)
        dot(10.8, 15.1, 1.5, color: colors.pads, in: context)
        stroke(catSmile, color: catInk, width: 0.75, in: context)
        context.restoreGState()
    }

    static func drawCatEye(at eye: CGPoint, iris: RGB, expression: CatExpression, in context: CGContext) {
        switch expression {
        case .open:
            dot(eye.x, eye.y, 3.35, color: catInk, in: context)
            dot(eye.x, eye.y, 2.8, color: iris, in: context)
            dot(eye.x - 0.36, eye.y - 0.12, 2, color: catInk, in: context)
            dot(eye.x - 0.65, eye.y - 0.65, 0.78, color: catPaper, in: context)
        case .blink:
            let line = path {
                $0.move(to: CGPoint(x: eye.x - 1.4, y: eye.y + 0.2))
                $0.addQuadCurve(to: CGPoint(x: eye.x + 1.4, y: eye.y + 0.2),
                                control: CGPoint(x: eye.x, y: eye.y - 1.75))
            }
            stroke(line, color: catInk, width: 1.12, in: context)
        }
    }

    static func paintCatSticker(_ shape: CGPath, fill: RGB, halo: CGFloat, outline: CGFloat, in context: CGContext) {
        paint(shape, fill: fill, stroke: catPaper, width: halo, in: context)
        stroke(shape, color: catInk, width: outline, in: context)
    }
}

private extension CursorArtwork {
    static let pencilInk = RGB(0x302927)
    static let pencilRim = RGB(0xFFFBF3)
    static let pencilRed = RGB(0xB6483C)

    static let pencilBody = path {
        $0.move(to: .zero)
        $0.addLine(to: CGPoint(x: 3.78, y: 7.8))
        $0.addQuadCurve(to: CGPoint(x: 4, y: 8.88), control: CGPoint(x: 4, y: 8.28))
        $0.addLine(to: CGPoint(x: 4, y: 24))
        $0.addQuadCurve(to: CGPoint(x: 3.2, y: 24.8), control: CGPoint(x: 4, y: 24.8))
        $0.addLine(to: CGPoint(x: -3.2, y: 24.8))
        $0.addQuadCurve(to: CGPoint(x: -4, y: 24), control: CGPoint(x: -4, y: 24.8))
        $0.addLine(to: CGPoint(x: -4, y: 8.88))
        $0.addQuadCurve(to: CGPoint(x: -3.78, y: 7.8), control: CGPoint(x: -4, y: 8.28))
        $0.closeSubpath()
    }

    static let pencilBarrel = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [RGB(0xF5C568).cgColor, RGB(0xF9D080).cgColor, RGB(0xE6A840).cgColor, RGB(0xBC792B).cgColor] as CFArray,
        locations: [0, 0.2, 0.66, 1]
    )

    static let pencilWood = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [RGB(0xFFF5E6).cgColor, RGB(0xF5E5CD).cgColor, RGB(0xAD9989).cgColor] as CFArray,
        locations: [0, 0.45, 1]
    )

    static let pencilHand = path {
        $0.move(to: CGPoint(x: 9.2, y: 18.7))
        $0.addLine(to: CGPoint(x: 9.2, y: 7))
        $0.addCurve(to: CursorRole.link.hotSpot, control1: CGPoint(x: 9.2, y: 5.2), control2: CGPoint(x: 10.4, y: 4))
        $0.addCurve(to: CGPoint(x: 14.8, y: 7), control1: CGPoint(x: 13.6, y: 4), control2: CGPoint(x: 14.8, y: 5.2))
        $0.addLine(to: CGPoint(x: 14.8, y: 13.7))
        $0.addQuadCurve(to: CGPoint(x: 19.3, y: 14.5), control: CGPoint(x: 17.4, y: 12))
        $0.addQuadCurve(to: CGPoint(x: 24, y: 16.5), control: CGPoint(x: 22.3, y: 13.5))
        $0.addQuadCurve(to: CGPoint(x: 27, y: 19.6), control: CGPoint(x: 26.9, y: 16.3))
        $0.addLine(to: CGPoint(x: 26.5, y: 23.8))
        $0.addQuadCurve(to: CGPoint(x: 23.8, y: 29.5), control: CGPoint(x: 25.8, y: 27.3))
        $0.addQuadCurve(to: CGPoint(x: 21.4, y: 30.5), control: CGPoint(x: 23, y: 30.5))
        $0.addLine(to: CGPoint(x: 15, y: 30.5))
        $0.addQuadCurve(to: CGPoint(x: 12, y: 29.1), control: CGPoint(x: 13.1, y: 30.5))
        $0.addLine(to: CGPoint(x: 5.7, y: 22.2))
        $0.addQuadCurve(to: CGPoint(x: 5.5, y: 18.7), control: CGPoint(x: 4, y: 20.3))
        $0.addQuadCurve(to: CGPoint(x: 9.2, y: 18.7), control: CGPoint(x: 7.1, y: 17.2))
        $0.closeSubpath()
    }

    static let pencilTextCaps = path {
        $0.move(to: CGPoint(x: 11.4, y: 8))
        $0.addLine(to: CGPoint(x: 20.6, y: 8))
        $0.move(to: CGPoint(x: 11.4, y: 28))
        $0.addLine(to: CGPoint(x: 20.6, y: 28))
    }

    static let pencilText = path {
        $0.addPath(pencilTextCaps)
        $0.move(to: CGPoint(x: CursorRole.text.hotSpot.x, y: 8))
        $0.addLine(to: CGPoint(x: CursorRole.text.hotSpot.x, y: 28))
    }

    static func drawPencil(_ role: CursorRole, in context: CGContext) {
        context.setLineJoin(.round)
        switch role {
        case .arrow:
            drawPencilPointer(in: context)
        case .link:
            stroke(pencilHand, color: pencilRim, width: 3.15, in: context)
            context.setFillColor(RGB(0xF8E9CA).cgColor)
            context.addPath(pencilHand)
            context.fillPath()

            context.saveGState()
            context.addPath(pencilHand)
            context.clip()
            context.setFillColor(pencilRed.cgColor)
            context.fill(CGRect(x: 8, y: 26.7, width: 19, height: 4))
            context.setFillColor(RGB(0xB77548).cgColor)
            context.fill(CGRect(x: 8, y: 26.5, width: 19, height: 0.62))
            context.restoreGState()

            stroke(pencilHand, color: pencilInk, width: 1.16, in: context)
        case .text:
            stroke(pencilText, color: pencilRim, width: 3.8, in: context)
            stroke(pencilText, color: pencilInk, width: 1.8, in: context)
            stroke(pencilTextCaps, color: pencilRed, width: 1.65, in: context)
        }
    }

    static func drawPencilPointer(in context: CGContext) {
        context.saveGState()
        let tip = CursorRole.pencilTip
        context.translateBy(x: tip.x, y: tip.y)
        context.rotate(by: -.pi / 5)
        stroke(pencilBody, color: pencilRim, width: 3.15, in: context)

        context.saveGState()
        context.addPath(pencilBody)
        context.clip()
        fillPencilSection(CGRect(x: -4, y: 0, width: 8, height: 24.8),
                          gradient: pencilBarrel, fallback: RGB(0xE6A840), in: context)
        fillPencilSection(CGRect(x: -4, y: 0, width: 8, height: 7.6),
                          gradient: pencilWood, fallback: RGB(0xF5E5CD), in: context)
        context.setFillColor(pencilInk.cgColor)
        context.fill(CGRect(x: -4, y: 0, width: 8, height: 3.3))
        context.setFillColor(RGB(0x654832).cgColor)
        context.fill(CGRect(x: -4, y: 7.6, width: 8, height: 0.72))
        context.restoreGState()

        stroke(pencilBody, color: pencilInk, width: 1.07, in: context)
        context.restoreGState()
    }

    static func fillPencilSection(_ bounds: CGRect, gradient: CGGradient?, fallback: RGB, in context: CGContext) {
        guard let gradient else {
            context.setFillColor(fallback.cgColor)
            context.fill(bounds)
            return
        }
        context.saveGState()
        context.clip(to: bounds)
        context.drawLinearGradient(
            gradient, start: CGPoint(x: bounds.minX, y: 0), end: CGPoint(x: bounds.maxX, y: 0), options: []
        )
        context.restoreGState()
    }
}
