import AppKit
import CoreGraphics

let side = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                           space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("ctx")
}
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

let nsGC = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsGC
let font = NSFont(name: "Georgia-Bold", size: 760) ?? NSFont.systemFont(ofSize: 760, weight: .bold)
let text = NSAttributedString(string: "?", attributes: [.font: font, .foregroundColor: NSColor.white])
let size = text.size()
text.draw(at: NSPoint(x: (Double(side) - size.width) / 2, y: (Double(side) - size.height) / 2 - 30))
NSGraphicsContext.restoreGraphicsState()

guard let image = ctx.makeImage() else { fatalError("image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! png.write(to: URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset/icon.png"))
print("wrote icon.png")
