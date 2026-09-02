import Cocoa
let a = CommandLine.arguments
let fontPath = a[1]; let size = CGFloat(Double(a[2])!)
func renk(_ h: String) -> NSColor { let v = UInt32(h, radix: 16)!; return NSColor(deviceRed: CGFloat((v>>16)&255)/255, green: CGFloat((v>>8)&255)/255, blue: CGFloat(v&255)/255, alpha: 1) }
let c1 = renk(a[3]); let c2 = renk(a[4]); let out = a[5]; let metin = a[6]
let url = URL(fileURLWithPath: fontPath) as CFURL
var err: Unmanaged<CFError>?
CTFontManagerRegisterFontsForURL(url, .process, &err)
guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor], let d0 = descs.first else { print("desc-yok"); exit(2) }
let psName = CTFontDescriptorCopyAttribute(d0, kCTFontNameAttribute) as! String
guard let font = NSFont(name: psName, size: size) else { print("font-yok \(psName)"); exit(3) }
let ps = NSMutableParagraphStyle(); ps.baseWritingDirection = .rightToLeft; ps.alignment = .right
let s = NSMutableAttributedString()
var vurgu = false
for p in metin.components(separatedBy: "**") {
  if !p.isEmpty { s.append(NSAttributedString(string: p, attributes: [.font: font, .foregroundColor: vurgu ? c2 : c1, .paragraphStyle: ps])) }
  vurgu.toggle()
}
let line = CTLineCreateWithAttributedString(s)
var asc: CGFloat = 0, dsc: CGFloat = 0, lead: CGFloat = 0
let w = CTLineGetTypographicBounds(line, &asc, &dsc, &lead)
let W = Int(ceil(w)) + 8, H = Int(ceil(asc + dsc)) + 8
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { print("rep-yok"); exit(4) }
guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { print("ctx-yok"); exit(5) }
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
let cg = ctx.cgContext
cg.textPosition = CGPoint(x: 4, y: dsc + 4)
CTLineDraw(line, cg)
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { print("png-yok"); exit(6) }
try! png.write(to: URL(fileURLWithPath: out))
print("\(W) \(H) \(Int(asc))")
