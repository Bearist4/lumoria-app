//
//  AvatarCropSheet.swift
//  Lumoria App
//
//  Full-screen sheet that lets the user reposition and zoom an image
//  inside a fixed square viewport, then commits a square UIImage back to
//  the caller. Used by `ProfileView` after picking a new avatar so the
//  user can frame their face the way they want.
//

import SwiftUI
import UIKit

struct AvatarCropSheet: View {

    let image: UIImage
    let onCommit: (UIImage) -> Void
    let onCancel: () -> Void

    // MARK: - Tunables

    /// Side length of the on-screen crop window.
    private let cropSize: CGFloat = 300
    /// Side length of the output (pre-compression) image.
    private let outputSize: CGFloat = 512
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    // MARK: - Transform state

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                imageLayer(proxy: proxy)

                cropMask

                cropBorder

                controls
            }
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            scale = clampedScale(lastScale * value)
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
            )
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Image

    private func imageLayer(proxy: GeometryProxy) -> some View {
        let base = baseScale()
        let size = image.size
        let w = size.width * base * scale
        let h = size.height * base * scale

        return Image(uiImage: image)
            .resizable()
            .frame(width: w, height: h)
            .position(
                x: proxy.size.width / 2 + offset.width,
                y: proxy.size.height / 2 + offset.height
            )
            .allowsHitTesting(false)
    }

    /// Factor that scales the raw image so it *covers* the crop window at
    /// `scale == 1`. Prevents gaps on either axis.
    private func baseScale() -> CGFloat {
        let size = image.size
        return max(cropSize / size.width, cropSize / size.height)
    }

    private func clampedScale(_ raw: CGFloat) -> CGFloat {
        min(maxScale, max(minScale, raw))
    }

    // MARK: - Crop window overlays

    /// Darkens everything outside the square crop window.
    private var cropMask: some View {
        ZStack {
            Color.black.opacity(0.55)
            Rectangle()
                .frame(width: cropSize, height: cropSize)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private var cropBorder: some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 2)
            .frame(width: cropSize, height: cropSize)
            .allowsHitTesting(false)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            HStack {
                LumoriaIconButton(
                    systemImage: "xmark",
                    size: .large,
                    position: .onDark,
                    action: onCancel
                )

                Spacer()

                LumoriaIconButton(
                    systemImage: "checkmark",
                    size: .large,
                    position: .success
                ) {
                    onCommit(render())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            Text("Drag to reposition · pinch to zoom")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 32)
        }
    }

    // MARK: - Render

    /// Rasterizes the transformed image into a square UIImage matching
    /// what's visible inside the crop window.
    private func render() -> UIImage {
        let base = baseScale()
        let total = base * scale
        let size = image.size
        let scaledW = size.width * total
        let scaledH = size.height * total

        // Top-left of the (scaled) image relative to the crop window's
        // top-left, in crop-window points.
        let dx = (cropSize - scaledW) / 2 + offset.width
        let dy = (cropSize - scaledH) / 2 + offset.height

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize)
        )
        return renderer.image { ctx in
            // Map crop-window points → output pixels.
            let factor = outputSize / cropSize
            ctx.cgContext.scaleBy(x: factor, y: factor)

            image.draw(in: CGRect(x: dx, y: dy, width: scaledW, height: scaledH))
        }
    }
}

// MARK: - Preview

#Preview {
    struct Host: View {
        @State private var present = true
        var body: some View {
            Color.gray.ignoresSafeArea()
                .fullScreenCover(isPresented: $present) {
                    AvatarCropSheet(
                        image: UIImage(systemName: "person.fill")?
                            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
                            ?? UIImage()
                    ) { _ in
                        present = false
                    } onCancel: {
                        present = false
                    }
                }
        }
    }
    return Host()
}
