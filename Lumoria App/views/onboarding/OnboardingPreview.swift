//
//  OnboardingPreview.swift
//  Lumoria App
//
//  Xcode preview host — one #Preview per step/sheet. Each preview is a
//  dedicated struct with its own @StateObject initialized via autoclosure
//  so MainActor construction doesn't trip the preview build.
//

#if DEBUG
import SwiftUI

// MARK: - Preview-only mock service

private final class PreviewProfileService: ProfileServicing, @unchecked Sendable {
    var stored: Profile
    init(step: OnboardingStep) {
        self.stored = Profile(
            userId: UUID(),
            showOnboarding: true,
            onboardingStep: step
        )
    }
    func fetch() async throws -> Profile { stored }
    func setStep(_ step: OnboardingStep) async throws { stored.onboardingStep = step }
    func setShowOnboarding(_ value: Bool) async throws { stored.showOnboarding = value }
    func replay() async throws {
        stored.showOnboarding = true
        stored.onboardingStep = .welcome
    }
}

// MARK: - Backdrops

private struct PreviewMemoriesBackdrop: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Memories").font(.largeTitle.bold())
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.15), in: Circle())
                    Image(systemName: "plus")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.15), in: Circle())
                        .onboardingAnchor("memories.plus")
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)

            Spacer()
            VStack(spacing: 8) {
                Text("No memories yet").font(.title2.bold()).foregroundStyle(.secondary)
                Text("A trip, a weekend, a night worth holding onto.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct PreviewMemoriesWithTileBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("Memories").font(.largeTitle.bold()); Spacer() }
                .padding(.horizontal, 16).padding(.top, 16)

            HStack(alignment: .top) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color.white, Color.orange.opacity(0.4)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 160, height: 220)
                    Text("Ski Trip 2024").font(.subheadline.bold())
                    Text("0 ticket").font(.caption).foregroundStyle(.secondary)
                }
                .onboardingAnchor("memories.newTile")
                Spacer()
            }
            .padding(16)
            Spacer()
        }
    }
}

private struct PreviewMemoryDetailBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15), in: Circle())
                Spacer()
                Image(systemName: "map")
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15), in: Circle())
                Image(systemName: "plus")
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15), in: Circle())
                    .onboardingAnchor("memoryDetail.plus")
                Image(systemName: "ellipsis")
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15), in: Circle())
            }
            .padding(.horizontal, 16).padding(.top, 16)

            Text("😀").font(.system(size: 48))
                .padding(.top, 24).padding(.leading, 24)
            Text("Ski Trip 2024").font(.title.bold())
                .padding(.leading, 24).padding(.top, 8)

            Spacer()
        }
        .background(Color(red: 0.90, green: 0.83, blue: 0.82))
    }
}

private struct PreviewCategoryBackdrop: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("New ticket").font(.largeTitle.bold())
            Text("Select a category").font(.title3.bold()).padding(.top, 8)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16),
                          GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(height: 140)
                        .overlay(Text("Category").foregroundStyle(.secondary))
                }
            }
            .onboardingAnchor("funnel.categories")
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

private struct PreviewTemplateBackdrop: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("New ticket").font(.largeTitle.bold())
            Text("Pick a template").font(.title3.bold()).padding(.top, 8)
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .frame(height: 140)
                        .overlay(Text("Template \(idx + 1)").foregroundStyle(.secondary))
                        .onboardingAnchor(idx == 0 ? "funnel.firstTemplate" : "unused.\(idx)")
                }
            }
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

private struct PreviewFormBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New ticket").font(.largeTitle.bold())
            Text("Fill your ticket's information").font(.title3.bold()).padding(.top, 8)
            Text("Departure").font(.headline).padding(.top, 8)
            VStack(alignment: .leading) {
                Text("Airport *").font(.caption)
                RoundedRectangle(cornerRadius: 12).fill(Color.white).frame(height: 50)
            }
            VStack(alignment: .leading) {
                Text("Date *").font(.caption)
                RoundedRectangle(cornerRadius: 12).fill(Color.white).frame(height: 50)
            }
            Spacer()
        }
        .onboardingAnchor("funnel.firstField")
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

private struct PreviewStyleBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New ticket").font(.largeTitle.bold())
            Text("Choose the style of your ticket").font(.title3.bold()).padding(.top, 8)
            RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.15)).frame(height: 180)
                .padding(.top, 8)
            VStack(alignment: .leading) {
                Text("Available styles").font(.headline)
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16).fill(Color.white).frame(width: 160, height: 160)
                    RoundedRectangle(cornerRadius: 16).fill(Color.black).frame(width: 160, height: 160)
                }
            }
            .onboardingAnchor("funnel.styles")
            .padding(.top, 16)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

private struct PreviewSuccessBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All done!").font(.largeTitle.bold())
            RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.15)).frame(height: 240)
            VStack(spacing: 12) {
                Text("Export Ticket")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                Text("Add to Memory")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(.black, in: RoundedRectangle(cornerRadius: 16))
            }
            .onboardingAnchor("success.actions")
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

private struct PreviewExportBackdrop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export your ticket").font(.largeTitle.bold())
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 16).fill(Color.white).frame(height: 90)
                    .overlay(Text("Social Media").foregroundStyle(.secondary))
                RoundedRectangle(cornerRadius: 16).fill(Color.white).frame(height: 90)
                    .overlay(Text("Instant messaging").foregroundStyle(.secondary))
                RoundedRectangle(cornerRadius: 16).fill(Color.white).frame(height: 90)
                    .overlay(Text("Camera roll").foregroundStyle(.secondary))
            }
            .onboardingAnchor("export.groups")
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16)
    }
}

// MARK: - Step preview hosts (one struct per step)

private struct CreateMemoryPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .createMemory)
    )
    var body: some View {
        PreviewMemoriesBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .createMemory,
                coordinator: coordinator,
                anchorID: "memories.plus",
                tip: .init(
                    title: "Create a memory",
                    body: "Memories gather tickets into one place. Create one by tapping the + button."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct MemoryCreatedPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .memoryCreated)
    )
    var body: some View {
        PreviewMemoriesWithTileBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .memoryCreated,
                coordinator: coordinator,
                anchorID: "memories.newTile",
                tip: .init(
                    title: "Your memory has been created",
                    body: "Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct EnterMemoryPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .enterMemory)
    )
    var body: some View {
        PreviewMemoryDetailBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onboardingOverlay(
                step: .enterMemory,
                coordinator: coordinator,
                anchorID: "memoryDetail.plus",
                tip: .init(
                    title: "Create your first ticket",
                    body: "Let's fill this memory with your first ticket. Tap the + button to start.",
                    leadingEmoji: "😀"
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct PickCategoryPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .pickCategory)
    )
    var body: some View {
        PreviewCategoryBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .pickCategory,
                coordinator: coordinator,
                anchorID: "funnel.categories",
                tip: .init(
                    title: "Pick a category",
                    body: "Tickets are separated into categories. Pick a category to continue."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct PickTemplatePreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .pickTemplate)
    )
    var body: some View {
        PreviewTemplateBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .pickTemplate,
                coordinator: coordinator,
                anchorID: "funnel.firstTemplate",
                tip: .init(
                    title: "Pick a template",
                    body: "Each category has different templates that match it. You can also check the content of each template by tapping the information button."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct FillInfoPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .fillInfo)
    )
    var body: some View {
        PreviewFormBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .fillInfo,
                coordinator: coordinator,
                anchorID: "funnel.firstField",
                tip: .init(
                    title: "Fill the required information",
                    body: "Every template have specific information attached to it. Fill all the required information to edit your ticket."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct PickStylePreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .pickStyle)
    )
    var body: some View {
        PreviewStyleBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .pickStyle,
                coordinator: coordinator,
                anchorID: "funnel.styles",
                tip: .init(
                    title: "Select a style",
                    body: "Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct AllDonePreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .allDone)
    )
    var body: some View {
        PreviewSuccessBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .allDone,
                coordinator: coordinator,
                anchorID: "success.actions",
                tip: .init(
                    title: "Ticket created!",
                    body: "Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

private struct ExportOrAddMemoryPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .exportOrAddMemory)
    )
    var body: some View {
        PreviewExportBackdrop()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: .exportOrAddMemory,
                coordinator: coordinator,
                anchorID: "export.groups",
                tip: .init(
                    title: "Export your ticket",
                    body: "Choose the export option that matches what you want to achieve."
                )
            )
            .task { await coordinator.loadOnAuth() }
    }
}

// MARK: - Sheet preview hosts

private struct WelcomeSheetPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .welcome)
    )
    var body: some View {
        ZStack { Color(white: 0.95).ignoresSafeArea() }
            .sheet(isPresented: .constant(true)) {
                WelcomeSheetView().environmentObject(coordinator)
            }
    }
}

private struct ResumeSheetPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .pickCategory)
    )
    var body: some View {
        ZStack { Color(white: 0.95).ignoresSafeArea() }
            .sheet(isPresented: .constant(true)) {
                ResumeSheetView().environmentObject(coordinator)
            }
    }
}

private struct EndSheetPreview: View {
    @StateObject private var coordinator = OnboardingCoordinator(
        service: PreviewProfileService(step: .endCover)
    )
    var body: some View {
        ZStack { Color(white: 0.95).ignoresSafeArea() }
            .sheet(isPresented: .constant(true)) {
                OnboardingEndSheetView().environmentObject(coordinator)
            }
    }
}

// MARK: - Previews

#Preview("1 · Welcome sheet") { WelcomeSheetPreview() }
#Preview("2 · createMemory")       { CreateMemoryPreview() }
#Preview("3 · memoryCreated")      { MemoryCreatedPreview() }
#Preview("4 · enterMemory")        { EnterMemoryPreview() }
#Preview("5 · pickCategory")       { PickCategoryPreview() }
#Preview("6 · pickTemplate")       { PickTemplatePreview() }
#Preview("7 · fillInfo")           { FillInfoPreview() }
#Preview("8 · pickStyle")          { PickStylePreview() }
#Preview("9 · allDone")            { AllDonePreview() }
#Preview("10 · exportOrAddMemory") { ExportOrAddMemoryPreview() }
#Preview("11 · Resume sheet")      { ResumeSheetPreview() }
#Preview("12 · End sheet")         { EndSheetPreview() }

#endif
