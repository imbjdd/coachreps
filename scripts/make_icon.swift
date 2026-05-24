#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Couldn't create context")
}

// Full-bleed warm off-white background
ctx.setFillColor(CGColor(red: 0.945, green: 0.935, blue: 0.918, alpha: 1.0))
ctx.fill(CGRect(origin: .zero, size: size))

// Subtle darker radial-ish vignette by drawing a centered slightly-darker rounded rect... skip, keep flat.

let cx = size.width / 2
let cy = size.height / 2

// Waveform bars in deep terracotta — 7 bars
let barColor = CGColor(red: 0.82, green: 0.38, blue: 0.26, alpha: 1.0)
ctx.setFillColor(barColor)

let barCount = 7
let barWidth: CGFloat = 78
let barSpacing: CGFloat = 46
let totalBarsWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
let startX = cx - totalBarsWidth / 2

// Each bar's relative height (0..1)
let pattern: [CGFloat] = [0.35, 0.65, 0.95, 0.50, 0.85, 0.60, 0.30]
let maxBarH: CGFloat = 640

for i in 0..<barCount {
    let x = startX + CGFloat(i) * (barWidth + barSpacing)
    let h = maxBarH * pattern[i]
    let y = cy - h / 2
    let rect = CGRect(x: x, y: y, width: barWidth, height: h)
    let path = CGPath(roundedRect: rect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()
}

guard let cgImage = ctx.makeImage() else { fatalError("No image") }

let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Couldn't create dest")
}
CGImageDestinationAddImage(dest, cgImage, nil)
if !CGImageDestinationFinalize(dest) {
    fatalError("Couldn't finalize")
}
print("Wrote icon to \(outURL.path)")
