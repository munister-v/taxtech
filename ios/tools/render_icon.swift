// Іконка застосунку: сяйво з фірмових кольорів і монета-«к».
// Запуск: swift ios/tools/render_icon.swift ios/Kopiyka/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
import AppKit
import SwiftUI

func hex(_ v: UInt32) -> Color {
    Color(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

struct Icon: View {
    var body: some View {
        ZStack {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.42, 0.55], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                hex(0x022C22), hex(0x065F46), hex(0x8B5CF6),
                hex(0x064E3B), hex(0x10B981), hex(0x38BDF8),
                hex(0x011A14), hex(0x0F766E), hex(0x14B8A6),
            ])
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.75)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 560, height: 560)
                .shadow(color: .black.opacity(0.25), radius: 40, y: 24)
            Circle()
                .strokeBorder(hex(0x065F46).opacity(0.25), lineWidth: 18)
                .frame(width: 500, height: 500)
            Text("к")
                .font(.system(size: 420, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [hex(0x059669), hex(0x0F766E), hex(0x6D28D9)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .offset(y: -22)
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render(to path: String) {
    let r = ImageRenderer(content: Icon())
    r.scale = 1
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("written", path, cg.width, "x", cg.height)
}

MainActor.assumeIsolated { render(to: CommandLine.arguments[1]) }
