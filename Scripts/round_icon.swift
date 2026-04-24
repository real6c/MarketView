// Rounded-rect mask, transparent outside corners. Usage:
//   round_icon <in.png> <out.png> <sizePx> <cornerRadiusPx>
import AppKit
import Foundation

guard CommandLine.argc == 5 else {
    FileHandle.standardError.write(Data("Usage: round_icon <in.png> <out.png> <sizePx> <cornerRadiusPx>\n".utf8))
    exit(1)
}

let inPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let side = CGFloat(Double(CommandLine.arguments[3])!)
var radius = CGFloat(Double(CommandLine.arguments[4])!)

guard side > 0, side.isFinite, radius.isFinite,
      let input = NSImage(contentsOf: URL(fileURLWithPath: inPath)) else {
    FileHandle.standardError.write(Data("bad input\n".utf8))
    exit(1)
}

radius = min(radius, side / 2 - 0.5)

let out = NSImage(size: NSSize(width: side, height: side))
out.lockFocus()
NSColor.clear.set()
NSRect(x: 0, y: 0, width: side, height: side).fill()

if let ctx = NSGraphicsContext.current {
    ctx.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: side, height: side)
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    let from = NSRect(x: 0, y: 0, width: input.size.width, height: input.size.height)
    input.draw(
        in: rect,
        from: from,
        operation: .sourceOver,
        fraction: 1.0,
        respectFlipped: true,
        hints: nil
    )
}
out.unlockFocus()

guard let tiff = out.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { exit(1) }
rep.size = NSSize(width: side, height: side)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do { try png.write(to: URL(fileURLWithPath: outPath), options: .atomic) } catch { exit(1) }
