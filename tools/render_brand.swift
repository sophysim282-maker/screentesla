#!/usr/bin/env swift
import AppKit
import Foundation
let fm = FileManager.default
let base = URL(fileURLWithPath: fm.currentDirectoryPath)
func color(_ r: CGFloat,_ g: CGFloat,_ b: CGFloat,_ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
let navy=color(0.025,0.055,0.12), teal=color(0.1,0.85,0.76), cyan=color(0.25,0.78,1)
func box(_ rect: NSRect,_ radius: CGFloat,_ fill: NSColor,_ stroke: NSColor? = nil,_ width: CGFloat = 1) {
 let p=NSBezierPath(roundedRect: rect,xRadius: radius,yRadius: radius);fill.setFill();p.fill()
 if let stroke=stroke {stroke.setStroke();p.lineWidth=width;p.stroke()}
}
func line(_ points: [NSPoint],_ c: NSColor,_ width: CGFloat) {
 let p=NSBezierPath();p.lineCapStyle = .round;p.lineJoinStyle = .round
 if let first=points.first {p.move(to:first)};for v in points.dropFirst(){p.line(to:v)};p.lineWidth=width;c.setStroke();p.stroke()
}
func scene(_ rect: NSRect) {
 NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:rect,xRadius:18,yRadius:18).addClip()
 NSGradient(starting:color(0.05,0.3,0.42),ending:color(0.05,0.12,0.28))!.draw(in:rect,angle:65)
 let sun=NSBezierPath(ovalIn:NSRect(x:rect.minX+rect.width*0.68,y:rect.minY+rect.height*0.55,width:rect.height*0.25,height:rect.height*0.25));color(0.9,1,0.83).setFill();sun.fill()
 let a=NSBezierPath();a.move(to:NSPoint(x:rect.minX-10,y:rect.minY));a.line(to:NSPoint(x:rect.minX+rect.width*0.4,y:rect.minY+rect.height*0.67));a.line(to:NSPoint(x:rect.maxX+10,y:rect.minY));a.close();color(0.1,0.65,0.66).setFill();a.fill()
 let b=NSBezierPath();b.move(to:NSPoint(x:rect.minX-10,y:rect.minY));b.line(to:NSPoint(x:rect.minX+rect.width*0.71,y:rect.minY+rect.height*0.48));b.line(to:NSPoint(x:rect.maxX+10,y:rect.minY+rect.height*0.1));b.line(to:NSPoint(x:rect.maxX+10,y:rect.minY));b.close();color(0.17,0.87,0.74).setFill();b.fill()
 NSGraphicsContext.restoreGraphicsState()
}
func render(_ width: Int,_ height: Int,_ icon: Bool,_ path: String) {
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:3,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let context=NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
 let logical=icon ? NSSize(width:1024,height:1024) : NSSize(width:1800,height:900)
 context.cgContext.scaleBy(x:CGFloat(width)/logical.width,y:CGFloat(height)/logical.height)
 let bounds=NSRect(origin:.zero,size:logical)
 NSGradient(starting:navy,ending:color(0.03,0.18,0.25))!.draw(in:bounds,angle:35)
 if icon {
  // Two interlocking screens: clear silhouette, generous iOS mask-safe margin.
  box(NSRect(x:310,y:324,width:510,height:390),60,color(0.06,0.17,0.25),cyan,24)
  box(NSRect(x:345,y:360,width:440,height:318),34,color(0.04,0.24,0.32))
  line([NSPoint(x:500,y:275),NSPoint(x:625,y:275)],cyan,22)
  line([NSPoint(x:565,y:300),NSPoint(x:565,y:324)],cyan,22)
  box(NSRect(x:198,y:218,width:260,height:490),55,navy,teal,26)
  box(NSRect(x:233,y:264,width:190,height:395),27,color(0.05,0.27,0.35))
  line([NSPoint(x:297,y:242),NSPoint(x:359,y:242)],teal,12)
  let play=NSBezierPath();play.move(to:NSPoint(x:570,y:448));play.line(to:NSPoint(x:570,y:585));play.line(to:NSPoint(x:678,y:516));play.close();NSColor.white.setFill();play.fill()
  for i in 0..<3 {let r=CGFloat(i)*48+105;let p=NSBezierPath();p.appendArc(withCenter:NSPoint(x:322,y:745),radius:r,startAngle:12,endAngle:74,clockwise:false);p.lineWidth=18;p.lineCapStyle = .round;teal.withAlphaComponent(CGFloat(3-i)/4).setStroke();p.stroke()}
 } else {
  // Ambient rings and a single visual journey between nearby screens.
  for i in 0..<5 {let p=NSBezierPath(ovalIn:NSRect(x:650-CGFloat(i)*70,y:40-CGFloat(i)*70,width:780+CGFloat(i)*140,height:780+CGFloat(i)*140));p.lineWidth=2;cyan.withAlphaComponent(0.055).setStroke();p.stroke()}
  let glow=NSShadow();glow.shadowColor=teal.withAlphaComponent(0.2);glow.shadowBlurRadius=80;glow.shadowOffset = .zero
  NSGraphicsContext.saveGraphicsState();glow.set()
  box(NSRect(x:755,y:245,width:795,height:460),46,color(0.05,0.14,0.22),cyan.withAlphaComponent(0.75),5)
  NSGraphicsContext.restoreGraphicsState()
  scene(NSRect(x:779,y:270,width:747,height:410))
  line([NSPoint(x:1060,y:187),NSPoint(x:1260,y:187)],color(0.22,0.47,0.53),13)
  line([NSPoint(x:1160,y:200),NSPoint(x:1160,y:245)],color(0.22,0.47,0.53),13)
  box(NSRect(x:322,y:141,width:307,height:591),52,navy,teal,6)
  scene(NSRect(x:339,y:182,width:273,height:526))
  line([NSPoint(x:443,y:160),NSPoint(x:508,y:160)],teal,7)
  box(NSRect(x:426,y:685,width:98,height:15),7,navy)
  let path=NSBezierPath();path.move(to:NSPoint(x:660,y:504));path.curve(to:NSPoint(x:1003,y:757),controlPoint1:NSPoint(x:690,y:760),controlPoint2:NSPoint(x:883,y:816));path.lineWidth=6;path.lineCapStyle = .round;teal.withAlphaComponent(0.8).setStroke();path.stroke()
  line([NSPoint(x:978,y:787),NSPoint(x:1006,y:756),NSPoint(x:970,y:744)],teal,6)
  for (x,y,r) in [(240.0,665.0,7.0),(1430,760,10),(1550,160,6),(716,176,9)] {color(0.4,0.9,0.9,0.5).setFill();NSBezierPath(ovalIn:NSRect(x:x,y:y,width:r,height:r)).fill()}
 }
 context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
 let url=base.appendingPathComponent(path);try! fm.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
 try! rep.representation(using:.png,properties:[:])!.write(to:url)
}
let catalog="App/BrandAssets.xcassets";let icons=catalog+"/AppIcon.appiconset"
try fm.createDirectory(atPath:icons,withIntermediateDirectories:true)
try "{\"info\":{\"version\":1,\"author\":\"xcode\"}}".write(toFile:catalog+"/Contents.json",atomically:true,encoding:.utf8)
var images=[[String:String]]()
for (idiom,size,scales) in [("iphone",20.0,[2,3]),("iphone",29,[2,3]),("iphone",40,[2,3]),("iphone",60,[2,3]),("ipad",20,[1,2]),("ipad",29,[1,2]),("ipad",40,[1,2]),("ipad",76,[1,2]),("ipad",83.5,[2]),("ios-marketing",1024,[1])] {
 for scale in scales {
  let pixels=Int(size*Double(scale)),file="icon-\(idiom)-\(size)-\(scale).png";render(pixels,pixels,true,icons+"/"+file)
  let value=size.rounded()==size ? String(Int(size)) : String(size)
  images.append(["idiom":idiom,"size":"\(value)x\(value)","scale":"\(scale)x","filename":file])
 }
}
try JSONSerialization.data(withJSONObject:["images":images,"info":["version":1,"author":"xcode"]],options:.prettyPrinted).write(to:base.appendingPathComponent(icons+"/Contents.json"))
render(1800,900,false,"App/ScreenLinkCover.png")
render(1024,1024,true,"build/ScreenLink-icon-preview.png")
render(1800,900,false,"build/ScreenLink-cover-preview.png")
print("Original ScreenLink icon and cover rendered; opaque icon asset slots and artwork ready.")
