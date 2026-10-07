import AppKit
let size = NSSize(width: 1000, height: 700)
let image = NSImage(size: size)
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
let lines = ["SYNTHETIC RECORD — NOT A REAL PATIENT", "Date: 2026-10-06", "Glucose: 105 mg/dL", "Reference range: 70-100 mg/dL", "Historical record for testing only"]
for (index, text) in lines.enumerated() {
    (text as NSString).draw(at: NSPoint(x: 40, y: 600 - index * 90), withAttributes: [.font: NSFont.systemFont(ofSize: 34), .foregroundColor: NSColor.black])
}
image.unlockFocus()
let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
try representation.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/private/tmp/chippy-synthetic-lab.png"))
