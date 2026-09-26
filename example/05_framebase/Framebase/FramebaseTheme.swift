import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum FramebaseTheme {
    static let paper = Color(red: 236 / 255, green: 233 / 255, blue: 226 / 255)
    static let ink = Color(red: 37 / 255, green: 44 / 255, blue: 41 / 255)
    static let rust = Color(red: 170 / 255, green: 79 / 255, blue: 45 / 255)
    static let secondary = Color(red: 112 / 255, green: 111 / 255, blue: 103 / 255)
    static let field = Color(red: 223 / 255, green: 220 / 255, blue: 212 / 255)
    static let peach = Color(red: 236 / 255, green: 162 / 255, blue: 124 / 255)
}

extension Font {
    static func framebaseTitle(_ size: CGFloat) -> Font { .custom("Instrument Sans", size: size).weight(.semibold) }
    static func framebaseBody(_ size: CGFloat) -> Font { .custom("Instrument Sans", size: size) }
}

struct FramebaseMark: View {
    var body: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(FramebaseTheme.rust)
            .accessibilityHidden(true)
    }
}

struct FrameImage: View {
    let match: FrameMatch

    var body: some View {
        Group {
            if let data = match.imageData {
                decodedImage(data)
            } else if let url = match.fallbackURL {
                AsyncImage(url: url) { image in image.resizable() } placeholder: { placeholder }
            } else {
                placeholder
            }
        }
        .scaledToFill()
        .clipped()
        .background(FramebaseTheme.field)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var placeholder: some View {
        ZStack {
            FramebaseTheme.field
            Image(systemName: "photo").font(.title).foregroundStyle(FramebaseTheme.secondary)
        }
    }

    @ViewBuilder
    private func decodedImage(_ data: Data) -> some View {
        #if canImport(UIKit)
        if let image = UIImage(data: data) { Image(uiImage: image).resizable() } else { placeholder }
        #else
        if let image = NSImage(data: data) { Image(nsImage: image).resizable() } else { placeholder }
        #endif
    }
}

extension View {
    func framebaseBadge() -> some View {
        self
            .font(.framebaseBody(15)).foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 9))
            .padding(8)
    }

    func framebaseCard() -> some View {
        padding(16).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
