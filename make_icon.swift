// jj-ice app 图标生成器 (CoreGraphics, 无外部依赖)。
// 设计: 冰蓝渐变圆角方块 + 白色"菜单栏"胶囊; 胶囊内左侧 3 个圆点(展示中的图标) + 右侧 chevron(收纳/展开隐藏图标)。
// 用法: swift make_icon.swift [输出 icns 路径]   缺省输出到 Resources/AppIcon.icns
// 全尺寸 png 渲进临时 .iconset 后交给 iconutil 合成 icns; 仓库只留 icns, png 随时可重生成。

import Cocoa
import ImageIO

let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
          green:   CGFloat((hex >> 8) & 0xFF) / 255,
          blue:    CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(_ size: Int, to path: String) {
  guard let ctx = CGContext(data: nil, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
  // 设计基于 1024 画布, y 向下(SVG 习惯): 先按尺寸缩放, 再翻转 y。
  let scale = CGFloat(size) / 1024.0
  ctx.scaleBy(x: scale, y: scale)
  ctx.translateBy(x: 0, y: 1024)
  ctx.scaleBy(x: 1, y: -1)

  let squircle = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                        cornerWidth: 184, cornerHeight: 184, transform: nil)

  // 背景冰蓝渐变 + 顶部玻璃高光 (裁剪到圆角方块内)
  ctx.saveGState()
  ctx.addPath(squircle); ctx.clip()
  let bg = CGGradient(colorsSpace: cs,
                      colors: [col(0x74DBFF), col(0x2FA1E8), col(0x0E6FD0)] as CFArray,
                      locations: [0, 0.55, 1])!
  ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
  let gloss = CGGradient(colorsSpace: cs,
                         colors: [col(0xFFFFFF, 0.30), col(0xFFFFFF, 0)] as CFArray,
                         locations: [0, 0.45])!
  ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 512), options: [])
  ctx.restoreGState()

  // 菜单栏胶囊 (先画阴影后画白胶囊)
  ctx.addPath(CGPath(roundedRect: CGRect(x: 232, y: 398, width: 560, height: 168),
                     cornerWidth: 84, cornerHeight: 84, transform: nil))
  ctx.setFillColor(col(0x06203A, 0.18)); ctx.fillPath()
  ctx.addPath(CGPath(roundedRect: CGRect(x: 232, y: 386, width: 560, height: 168),
                     cornerWidth: 84, cornerHeight: 84, transform: nil))
  ctx.setFillColor(col(0xFFFFFF, 0.97)); ctx.fillPath()

  // 展示中的图标圆点
  ctx.setFillColor(col(0x0E6FD0))
  for cx in [342.0, 434.0, 526.0] {
    ctx.addEllipse(in: CGRect(x: cx - 30, y: 470 - 30, width: 60, height: 60))
  }
  ctx.fillPath()

  // chevron: 收纳/展开隐藏图标
  ctx.setStrokeColor(col(0x0E6FD0))
  ctx.setLineWidth(30); ctx.setLineCap(.round); ctx.setLineJoin(.round)
  ctx.move(to: CGPoint(x: 712, y: 418))
  ctx.addLine(to: CGPoint(x: 656, y: 470))
  ctx.addLine(to: CGPoint(x: 712, y: 522))
  ctx.strokePath()

  guard let img = ctx.makeImage(),
        let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                   "public.png" as CFString, 1, nil) else { return }
  CGImageDestinationAddImage(dest, img, nil)
  CGImageDestinationFinalize(dest)
}

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"

// iconutil 只认 <name>.iconset 目录 + 固定文件名, 故先落临时目录再合成。
let iconset = FileManager.default.temporaryDirectory
  .appendingPathComponent("jj-ice-AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let files: [(Int, String)] = [
  (16,   "icon_16x16.png"),
  (32,   "icon_16x16@2x.png"),
  (32,   "icon_32x32.png"),
  (64,   "icon_32x32@2x.png"),
  (128,  "icon_128x128.png"),
  (256,  "icon_128x128@2x.png"),
  (256,  "icon_256x256.png"),
  (512,  "icon_256x256@2x.png"),
  (512,  "icon_512x512.png"),
  (1024, "icon_512x512@2x.png"),
]
for (sz, name) in files { render(sz, to: iconset.appendingPathComponent(name).path) }

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outPath]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)

guard iconutil.terminationStatus == 0 else {
  FileHandle.standardError.write("iconutil failed (exit \(iconutil.terminationStatus))\n".data(using: .utf8)!)
  exit(1)
}
print("rendered \(files.count) sizes -> \(outPath)")
