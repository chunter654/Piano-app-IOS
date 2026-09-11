import AppKit
// The bottom-left corner of a masked icon, magnified, to see whether the mask
// is cutting into the keybed or the outer key.
let src = CommandLine.arguments[1], out = CommandLine.arguments[2]
let img = NSImage(contentsOfFile: src)!
let cg = NSBitmapImageRep(data: img.tiffRepresentation!)!.cgImage!
let side: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let masked = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                       bytesPerRow: 0, space: cs,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
// The real mask is a continuous curve, not a circular arc.
let r = side * 0.183      // measured, not assumed: see Tools/IconRenderer
let n: CGFloat = 1.7
let steps = 160
let mp = CGMutablePath()
let rect = CGRect(x: 0, y: 0, width: side, height: side)
func corner(_ c: CGPoint, _ ax: CGPoint, _ ay: CGPoint) {
    for step in 0...steps {
        let a = CGFloat(step) / CGFloat(steps) * .pi / 2
        let u = pow(cos(a), 2 / n), v = pow(sin(a), 2 / n)
        mp.addLine(to: CGPoint(x: c.x + (ax.x * u + ay.x * v) * r,
                               y: c.y + (ax.y * u + ay.y * v) * r))
    }
}
mp.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
mp.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
corner(CGPoint(x: rect.maxX - r, y: rect.minY + r), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0))
mp.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
corner(CGPoint(x: rect.maxX - r, y: rect.maxY - r), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1))
mp.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
corner(CGPoint(x: rect.minX + r, y: rect.maxY - r), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0))
mp.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
corner(CGPoint(x: rect.minX + r, y: rect.minY + r), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: -1))
mp.closeSubpath()
masked.addPath(mp)
masked.clip()
masked.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
let m = masked.makeImage()!
// Bottom-left 300 square, on grey so the mask's cut is visible.
let crop = m.cropping(to: CGRect(x: 0, y: 1024 - 300, width: 300, height: 300))!
let outCtx = CGContext(data: nil, width: 600, height: 600, bitsPerComponent: 8,
                       bytesPerRow: 0, space: cs,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
outCtx.setFillColor(CGColor(red: 0.42, green: 0.44, blue: 0.47, alpha: 1))
outCtx.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
outCtx.interpolationQuality = .none
outCtx.draw(crop, in: CGRect(x: 0, y: 0, width: 600, height: 600))
let rep = NSBitmapImageRep(cgImage: outCtx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
