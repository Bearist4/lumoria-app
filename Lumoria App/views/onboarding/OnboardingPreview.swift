//
//  OnboardingPreview.swift
//  Lumoria App
//
//  Xcode preview host that lets you cycle through every onboarding step
//  + sheet without running the full app. Stubs a ProfileService in-memory
//  so the coordinator has no network dependency.
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

@MainActor
private func makeCoordinator(step: OnboardingStep) -> OnboardingCoordinator {
    OnboardingCoordinator(service: PreviewProfileService(step: step))
}

// MARK: - Backdrops per step

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
            .padding(.horizontal, 16)
            .padding(.top, 16)

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
            HStack {
                Text("Memories").font(.largeTitle.bold())
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

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
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Text("😀").font(.system(size: 48))
                .padding(.top, 24)
                .padding(.leading, 24)
            Text("Ski Trip 2024").font(.title.bold())
                .padding(.leading, 24)
                .padding(.top, 8)

            Spacer()
        }
        .background(Color(red: 0.90, green: 0.83, blue: 0.82))
    }
}

private struct PreviewCategoryBackdrop: View {
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    var body: some View {
        VStack(alignment: .leading) {
            Text("New ticket").font(.largeTitle.bold())
            Text("Select a category").font(.title3.bold()).padding(.top, 8)
            LazyVGrid(columns: columns, spacing: 16) {
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Tour

private struct OnboardingOverlayStepPreview: View {
    let step: OnboardingStep
    @StateObject private var coordinator: OnboardingCoordinator

    init(step: OnboardingStep) {
        self.step = step
        _coordinator = StateObject(
            wrappedValue: OnboardingCoordinator(service: PreviewProfileService(step: step))
        )
    }

    var body: some View {
        backdrop
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.93))
            .onboardingOverlay(
                step: step,
                coordinator: coordinator,
                anchorID: anchorID,
                tip: tipCopy
            )
            .alert(
                "Leave the tutorial?",
                isPresented: $coordinator.showLeaveAlert
            ) {
                Button("Leave", role: .destructive) { }
                Button("Stay", role: .cancel) { }
            } message: {
                Text("You can replay it anytime from Settings.")
            }
            .task { await coordinator.loadOnAuth() }
    }

    @ViewBuilder private var backdrop: some View {
        switch step {
        case .createMemory:      PreviewMemoriesBackdrop()
        case .memoryCreated:     PreviewMemoriesWithTileBackdrop()
        case .enterMemory:       PreviewMemoryDetailBackdrop()
        case .pickCategory:      PreviewCategoryBackdrop()
        case .pickTemplate:      PreviewTemplateBackdrop()
        case .fillInfo:          PreviewFormBackdrop()
        case .pickStyle:         PreviewStyleBackdrop()
        case .allDone:           PreviewSuccessBackdrop()
        case .exportOrAddMemory: PreviewExportBackdrop()
        default:                 Color.clear
        }
    }

    private var anchorID: String {
        switch step {
        case .createMemory:      return "memories.plus"
        case .memoryCreated:     return "memories.newTile"
        case .enterMemory:       return "memoryDetail.plus"
        case .pickCategory:      return "funnel.categories"
        case .pickTemplate:      return "funnel.firstTemplate"
        case .fillInfo:          return "funnel.firstField"
        case .pickStyle:         return "funnel.styles"
        case .allDone:           return "success.actions"
        case .exportOrAddMemory: return "export.groups"
        default:                 return ""
        }
    }

    private var tipCopy: OnboardingTipCopy {
        switch step {
        case .createMemory:
            return .init(title: "Create a memory",
                         body: "Memories gather tickets into one place. Create one by tapping the + button.")
        case .memoryCreated:
            return .init(title: "Your memory has been created",
                         body: "Once you will have tickets added to this memory, they will appear on this tile. Tap this memory to open it.")
        case .enterMemory:
            return .init(title: "Create your first ticket",
                         body: "Let's fill this memory with your first ticket. Tap the + button to start.",
                         leadingEmoji: "😀")
        case .pickCategory:
            return .init(title: "Pick a category",
                         body: "Tickets are separated into categories. Pick a category to continue.")
        case .pickTemplate:
            return .init(title: "Pick a template",
                         body: "Each category has different templates that match it. You can also check the content of each template by tapping the information button.")
        case .fillInfo:
            return .init(title: "Fill the required information",
                         body: "Every template have specific information attached to it. Fill all the required information to edit your ticket.")
        case .pickStyle:
            return .init(title: "Select a style",
                         body: "Some templates have alternative styles. Scroll through the options and tap the one you like to change how your ticket looks.")
        case .allDone:
            return .init(title: "Ticket created!",
                         body: "Your ticket has been created. You can find it in All Tickets. You can now add it to a Memory or Export your ticket to use it in another app.")
        case .exportOrAddMemory:
            return .init(title: "Export your ticket",
                         body: "Choose the export option that matches what you want to achieve.")
        default:
            return .init(title: "", body: "")
        }
    }
}

// MARK: - Previews

#Preview("1 · Welcome sheet") {
    ZStack { Color(white: 0.95).ignoresSafeArea() }
        .sheet(isPresented: .constant(true)) {
            WelcomeSheetView()
                .environmentObject(makeCoordinator(step: .welcome))
        }
}

#Preview("2 · createMemory") {
    OnboardingOverlayStepPreview(step: .createMemory)
}

#Preview("3 · memoryCreated") {
    OnboardingOverlayStepPreview(step: .memoryCreated)
}

#Preview("4 · enterMemory") {
    OnboardingOverlayStepPreview(step: .enterMemory)
}

#Preview("5 · pickCategory") {
    OnboardingOverlayStepPreview(step: .pickCategory)
}

#Preview("6 · pickTemplate") {
    OnboardingOverlayStepPreview(step: .pickTemplate)
}

#Preview("7 · fillInfo") {
    OnboardingOverlayStepPreview(step: .fillInfo)
}

#Preview("8 · pickStyle") {
    OnboardingOverlayStepPreview(step: .pickStyle)
}

#Preview("9 · allDone") {
    OnboardingOverlayStepPreview(step: .allDone)
}

#Preview("10 · exportOrAddMemory") {
    OnboardingOverlayStepPreview(step: .exportOrAddMemory)
}

#Preview("11 · Resume sheet") {
    ZStack { Color(white: 0.95).ignoresSafeArea() }
        .sheet(isPresented: .constant(true)) {
            ResumeSheetView()
                .environmentObject(makeCoordinator(step: .pickCategory))
        }
}

#Preview("12 · End sheet") {
    ZStack { Color(white: 0.95).ignoresSafeArea() }
        .sheet(isPresented: .constant(true)) {
            OnboardingEndSheetView()
                .environmentObject(makeCoordinator(step: .endCover))
        }
}
#endif
