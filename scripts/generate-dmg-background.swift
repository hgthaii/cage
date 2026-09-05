import AppKit

guard CommandLine.arguments.count == 2 else { exit(2) }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 720, height: 270)
let image = NSImage(size: size)
image.lockFocus()

NSColor.windowBackgroundColor.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 316, y: 165))
arrow.line(to: NSPoint(x: 404, y: 165))
arrow.move(to: NSPoint(x: 390, y: 178))
arrow.line(to: NSPoint(x: 404, y: 165))
arrow.line(to: NSPoint(x: 390, y: 152))
arrow.lineWidth = 2
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor.tertiaryLabelColor.setStroke()
arrow.stroke()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: output)
