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
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    imageLayer(proxy: proxy)
                    cropMask
                    cropBorder
                }
                // imageLayer / cropMask / cropBorder all disable hit
                // testing, so without an explicit content shape the
                // ZStack has no hit-testable area and gestures fire
                // only on whatever happens to be opaque underneath
                // (e.g. the image bounds). Forcing a full-bleed
                // rectangle hit area lets drag/pinch register
                // everywhere — including outside the image frame.
                .contentShape(Rectangle())
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                offset = clampedOffset(CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                ))
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            },
                        MagnificationGesture()
                            .onChanged { value in
                                scale = clampedScale(lastScale * value)
                                // Re-clamp the existing offset against
                                // the new scaled image size — zooming
                                // out past the current pan can leave a
                                // gap inside the crop window otherwise.
                                offset = clampedOffset(offset)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                lastOffset = offset
                            }
                    )
                )
            }
            .ignoresSafeArea()
        }
        // Overlays attach to the outer ZStack, which respects the
        // safe area — keeps the X / checkmark inside the Dynamic
        // Island / home-indicator inset on every device.
        .overlay(alignment: .top) {
            topControls
        }
        .overlay(alignment: .bottom) {
            bottomHint
        }
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

    /// Clamps the pan offset so the (scaled) image always covers the
    /// crop window — no black gap can appear on any edge.
    private func clampedOffset(_ raw: CGSize) -> CGSize {
        let total = baseScale() * scale
        let scaledW = image.size.width * total
        let scaledH = image.size.height * total
        let maxX = max(0, (scaledW - cropSize) / 2)
        let maxY = max(0, (scaledH - cropSize) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, raw.width)),
            height: min(maxY, max(-maxY, raw.height))
        )
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

    private var topControls: some View {
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
        .padding(.vertical, 12)
    }

    private var bottomHint: some View {
        Text("Drag to reposition · pinch to zoom")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
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
