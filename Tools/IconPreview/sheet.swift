import AppKit

// A contact sheet: each icon masked the way iOS masks it, drawn large and then
// at the size it actually occupies on a home screen. The small one is rendered
// at 60 points and then blown up without smoothing, so what you are looking at
// is the real information the icon has at that size.
let out = CommandLine.arguments[1]
let files = Array(CommandLine.arguments.dropFirst(2))

let big: CGFloat = 300
let small: CGFloat = 60
let blow: CGFloat = 3
let gap: CGFloat = 28
let labelH: CGFloat = 34

let totalW = gap + (big + gap) * CGFloat(files.count)
let totalH = gap + labelH + big + gap + small * blow + gap

let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(totalW), height: Int(totalH),
                    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(CGColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: totalW, height: totalH))

func load(_ path: String) -> CGImage {
    let img = NSImage(contentsOfFile: path)!
    return NSBitmapImageRep(data: img.tiffRepresentation!)!.cgImage!
}

func masked(_ cg: CGImage, side: CGFloat, smooth: Bool) -> CGImage {
    let px = Int(side)
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                      bytesPerRow: 0, space: cs,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let rect = CGRect(x: 0, y: 0, width: side, height: side)
    // iOS masks an icon with a continuous curve, not a circular arc. A circular
    // preview mask makes the band round the corner look even when it is not.
    let r = side * 0.2237
    let n: CGFloat = 5
    let steps = 128
    let path = CGMutablePath()
    func corner(_ centre: CGPoint, _ ax: CGPoint, _ ay: CGPoint) {
        for step in 0...steps {
            let a = CGFloat(step) / CGFloat(steps) * .pi / 2
            let u = pow(cos(a), 2 / n), v = pow(sin(a), 2 / n)
            path.addLine(to: CGPoint(x: centre.x + (ax.x * u + ay.x * v) * r,
                                     y: centre.y + (ax.y * u + ay.y * v) * r))
        }
    }
    path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    corner(CGPoint(x: rect.maxX - r, y: rect.minY + r), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    corner(CGPoint(x: rect.maxX - r, y: rect.maxY - r), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1))
    path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
    corner(CGPoint(x: rect.minX + r, y: rect.maxY - r), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    corner(CGPoint(x: rect.minX + r, y: rect.minY + r), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: -1))
    path.closeSubpath()
    c.addPath(path)
    c.clip()
    c.interpolationQuality = smooth ? .high : .none
    c.draw(cg, in: rect)
    return c.makeImage()!
}

func label(_ text: String, at point: CGPoint) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 19, weight: .medium),
        .foregroundColor: NSColor.white,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    ctx.textPosition = point
    CTLineDraw(line, ctx)
}

for (i, file) in files.enumerated() {
    let name = (file as NSString).lastPathComponent
        .replacingOccurrences(of: "icon-", with: "")
        .replacingOccurrences(of: ".png", with: "")
    let cg = load(file)
    let x = gap + (big + gap) * CGFloat(i)

    let bigY = totalH - gap - labelH - big
    ctx.draw(masked(cg, side: big * 3, smooth: true),
             in: CGRect(x: x, y: bigY, width: big, height: big))
    label(name, at: CGPoint(x: x, y: totalH - gap - labelH + 8))

    // 60 points is the home screen. Blown up with no smoothing so the detail
    // that survives at that size is the detail you can see here.
    let tiny = masked(cg, side: small, smooth: true)
    ctx.interpolationQuality = .none
    ctx.draw(tiny, in: CGRect(x: x + (big - small * blow) / 2, y: gap,
                              width: small * blow, height: small * blow))
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
