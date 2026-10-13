import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.17, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 36, y: 36, width: 952, height: 952), xRadius: 220, yRadius: 220).fill()
for (x, color, end) in [
    (340.0, NSColor(calibratedRed: 0.87, green: 0.52, blue: 0.36, alpha: 1), 375.0),
    (684.0, NSColor(calibratedRed: 0.28, green: 0.77, blue: 0.69, alpha: 1), 420.0),
] {
    let track = NSBezierPath()
    track.lineWidth = 40
    track.appendArc(withCenter: NSPoint(x: x, y: 512), radius: 126, startAngle: 0, endAngle: 360)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    track.stroke()
    let arc = NSBezierPath()
    arc.lineWidth = 40
    arc.lineCapStyle = .round
    arc.appendArc(withCenter: NSPoint(x: x, y: 512), radius: 126, startAngle: 90, endAngle: end)
    color.setStroke()
    arc.stroke()
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: x - 22, y: 490, width: 44, height: 44)).fill()
}
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
