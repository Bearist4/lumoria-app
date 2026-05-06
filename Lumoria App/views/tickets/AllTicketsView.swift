//
//  AllTicketsView.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-16025 (empty)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=955-14104 (populated)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1728-79133 (sort menu)
//          figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1728-79886 (sorted sections)
//
//  Gallery of the user's tickets. Horizontal templates span both grid
//  columns; vertical templates pair up in a 2-column layout. The sort
//  icon opens a contextual menu with date / category options; when a
//  sort is active tickets are rendered in grouped sections with a
//  relative-time or category header, and the icon gets a red badge dot.
//

import ProgressiveBlurHeader
import SwiftUI

struct AllTicketsView: View {

    @EnvironmentObject private var store: TicketsStore
    @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator
    @EnvironmentObject private var sortPresenter: AllTicketsSortPresenter
    @Environment(EntitlementStore.self) private var entitlement
    @Environment(Paywall.PresentationState.self) private var paywallState
    @State private var showFunnel = false
    /// Primes `NewTicketFunnelView.initialImportSource` before presenting
    /// the fullScreenCover. Reset to `nil` inside the cover's onDismiss
    /// so a subsequent "Create from scratch" tap opens the manual flow.
    @State private var pendingImportSource: ImportSource? = nil
    /// ID of the ticket closest to vertical centre of the screen. Drives
    /// the shimmer's `isActive` so only the focused card consumes motion.
    @State private var centredId: UUID?
    /// Drives the per-card locked alert when the user taps a ticket
    /// beyond the Free-tier cap (former early adopter who revoked).
    @State private var showLockedAlert: Bool = false
    /// Drives the early-adopter promo sheet route from the locked
    /// alert when the user has already claimed their invite reward.
    @State private var showEarlyAdopterPromo: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if store.tickets.isEmpty {
                    VStack(spacing: 0) {
                        header
                        emptyState
                    }
                } else {
                    StickyBlurHeader(
                        maxBlurRadius: 8,
                        fadeExtension: 56,
                        tintOpacityTop: 0,
                        tintOpacityMiddle: 0
                    ) {
                        header
                    } content: {
                        content
                    }
                    .refreshable {
                        await store.load()
                        Analytics.track(.galleryRefreshed(ticketCount: store.tickets.count))
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: sortPresenter.field) { _, newValue in
                let prop: GallerySortProp = {
                    switch newValue {
                    case .dateCreated, .dateAdded, .eventDate:
                        return .date
                    case .categoryAZ, .categoryZA:
                        return .category
                    case .none:
                        return GallerySortProp.none
                    }
                }()
                Analytics.track(.gallerySortApplied(sortType: prop))
            }
            .navigationDestination(for: Ticket.self) { ticket in
                TicketDetailView(ticket: ticket)
            }
            .fullScreenCover(
                isPresented: $showFunnel,
                onDismiss: { pendingImportSource = nil }
            ) {
                NewTicketFunnelView(initialImportSource: pendingImportSource)
                    .environmentObject(store)
                    .environmentObject(onboardingCoordinator)
            }
            .sheet(isPresented: $showEarlyAdopterPromo) {
                EarlyAdopterPromoSheet()
                    .environment(entitlement)
            }
            .alert(
                "Ticket locked",
                isPresented: $showLockedAlert
            ) {
                Button("Cancel", role: .cancel) { }
                if entitlement.inviteRewardKind == nil {
                    Button("Invite a friend") {
                        Paywall.present(
                            for: .ticketLimit,
                            entitlement: entitlement,
                            state: paywallState
                        )
                    }
                } else {
                    Button("Become an early adopter") {
                        showEarlyAdopterPromo = true
                    }
                }
            } message: {
                Text(lockedTicketAlertMessage)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("All tickets")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.Text.primary)

                slotIndicator
            }

            Spacer()

            HStack(spacing: 8) {
                if !store.tickets.isEmpty {
                    LumoriaIconButton(
                        systemImage: "arrow.up.arrow.down",
                        showBadge: sortPresenter.field != nil
                    ) {
                        sortPresenter.present()
                    }
                }
                LumoriaIconButton(
                    systemImage: "plus",
                    action: { presentNewTicketOrPaywall() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        // Header must stay transparent — the StickyBlurHeader's blur
        // IS the background. An opaque fill here would hide the
        // progressive blur of content scrolling underneath.
    }

    @ViewBuilder
    private var slotIndicator: some View {
        // Tier-level hasPremium so we always show slots for free users,
        // even while the kill-switch is off.
        if !entitlement.tier.hasPremium {
            let cap = FreeCaps.ticketCap(rewardKind: entitlement.inviteRewardKind)
            let remaining = max(0, cap - store.tickets.count)
            if remaining == 0 {
                if entitlement.inviteRewardKind == nil {
                    // User can still claim a +2 ticket bonus by inviting.
                    Button {
                        Paywall.present(
                            for: .ticketLimit,
                            entitlement: entitlement,
                            state: paywallState
                        )
                    } label: {
                        LumoriaUpgradeIncentive(resource: .tickets)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Invite already redeemed — no more slots to earn,
                    // surface the warning subheadline. Tapping a ticket
                    // creation triggers the NoSlotsSheet via the same
                    // `Paywall.present` path (router branches on
                    // `inviteRewardKind != nil`).
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.Feedback.Warning.icon)
                        Text("No slots available")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.Feedback.Warning.text)
                    }
                }
            } else {
                Text("\(remaining) available slots")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.Text.tertiary)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            SevenPointStar()
                .fill(Color.Text.tertiary)
                .frame(width: 56, height: 56)

            Text("Your gallery starts here")
                .font(.title2.bold())
                .foregroundStyle(Color.Text.tertiary)

            HStack(spacing: 4) {
                Text("Tap")
                EmptyStateInlineBadge(systemImage: "plus")
                Text("to craft your first ticket.")
            }
            .font(.body)
            .foregroundStyle(Color.Text.tertiary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        // Multi-leg public-transport tickets (and any future grouped
        // tickets) collapse into a single representative entry here.
        // The detail view pages through the full group on tap.
        let collapsed = store.tickets.collapsedToGroupRepresentatives()
        switch sortPresenter.field {
        case .none:
            grid(for: collapsed)
        case .dateCreated, .dateAdded, .eventDate:
            // TODO: differentiate by which date column is picked.
            // For now all three date options reuse the existing
            // grouped-by-date layout; ascending flips section order.
            let groups = TicketGrouping.byDate(collapsed, now: Date())
            groupedSections(
                groups: sortPresenter.ascending ? groups.reversed() : groups
            )
        case .categoryAZ:
            // `byCategory` returns groups in first-occurrence order;
            // sort by the group id (= category label string) for true
            // alphabetical ordering.
            let groups = TicketGrouping.byCategory(collapsed)
                .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
            groupedSections(groups: groups)
        case .categoryZA:
            let groups = TicketGrouping.byCategory(collapsed)
                .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedDescending }
            groupedSections(groups: groups)
        }
    }

    // MARK: - Populated grid

    private func grid(for tickets: [Ticket]) -> some View {
        // LazyVStack so off-screen ticket previews aren't materialised
        // up-front. With dozens of tickets the eager VStack built every
        // template view eagerly, which made scroll stutter while the
        // last rows were still rendering.
        LazyVStack(spacing: 32) {
            ForEach(Array(rows(for: tickets).enumerated()), id: \.offset) { _, row in
                rowView(for: row)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Grouped layout

    private func groupedSections(groups: [TicketGroup]) -> some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 16) {
                    Text(group.title)
                        .font(.title3.bold())
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 24)

                    LazyVStack(spacing: 32) {
                        ForEach(Array(rows(for: group.tickets).enumerated()), id: \.offset) { _, row in
                            rowView(for: row)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func rowView(for row: GridRow) -> some View {
        switch row {
        case .horizontal(let ticket):
            ticketLink(ticket)
        case .verticalPair(let a, let b):
            HStack(alignment: .top, spacing: 16) {
                ticketLink(a)
                ticketLink(b)
            }
        case .verticalSingle(let ticket):
            HStack(alignment: .top, spacing: 16) {
                ticketLink(ticket)
                Color.clear
            }
        }
    }

    private func ticketLink(_ ticket: Ticket) -> some View {
        let isLocked = lockedTicketIds.contains(ticket.id)
        return NavigationLink(value: ticket) {
            ZStack(alignment: .topTrailing) {
                TicketPreview(ticket: ticket, isCentered: centredId == ticket.id)
                    .trackCenteredRow(id: ticket.id, into: $centredId)
                    .ticketInspect()

                if let count = groupCount(for: ticket) {
                    LumoriaGroupBadge(count: count)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(TicketCardButtonStyle())
        .freeTierLocked(isLocked) { showLockedAlert = true }
    }

    /// Gated entry to the new-ticket funnel. Free-tier users at the
    /// cap see the paywall router instead — same pattern as
    /// MemoriesView. Without this gate the + button would happily
    /// open the funnel and the user only hits the wall at commit.
    private func presentNewTicketOrPaywall() {
        if store.canCreate(entitlement: entitlement) {
            pendingImportSource = nil
            showFunnel = true
        } else {
            Paywall.present(
                for: .ticketLimit,
                entitlement: entitlement,
                state: paywallState
            )
        }
    }

    /// IDs of tickets locked under the current Free-tier cap. Empty
    /// for premium / grandfathered users. Used by `ticketLink` to dim
    /// + gate items beyond the cap after a former early adopter
    /// revokes their seat.
    private var lockedTicketIds: Set<UUID> {
        FreeCaps.lockedTicketIDs(
            tickets: store.tickets,
            cap: FreeCaps.ticketCap(rewardKind: entitlement.inviteRewardKind),
            isPremium: entitlement.tier.hasPremium
        )
    }

    /// Body copy for the per-ticket locked alert. Same branching as
    /// the memory side: invite path if still claimable, otherwise
    /// delete-or-become-early-adopter.
    private var lockedTicketAlertMessage: String {
        let cap = FreeCaps.ticketCap(rewardKind: entitlement.inviteRewardKind)
        if entitlement.inviteRewardKind == nil {
            return String(localized: "You're at the Free tier limit of \(cap) tickets. Invite a friend to unlock 2 more slots.")
        }
        return String(localized: "You're at the Free tier limit of \(cap) tickets. Delete an older ticket to free this one up, or become an early adopter for unlimited slots.")
    }

    /// Number of legs in the ticket's group, or nil when the ticket
    /// stands alone. Used to gate the leg-count badge so single-ticket
    /// cards stay unbadged.
    private func groupCount(for ticket: Ticket) -> Int? {
        guard ticket.groupId != nil else { return nil }
        let count = store.tickets.groupSiblings(of: ticket).count
        return count > 1 ? count : nil
    }

    // MARK: - Row partitioning

    private enum GridRow {
        case horizontal(Ticket)
        case verticalPair(Ticket, Ticket)
        case verticalSingle(Ticket)
    }

    /// Packs vertical tickets into side-by-side pairs regardless of
    /// horizontal tickets interleaved between them. Preserves each
    /// ticket's original creation order: the first vertical stays
    /// in place and pulls the next available vertical forward to
    /// pair with it. Horizontals keep their absolute position.
    private func rows(for tickets: [Ticket]) -> [GridRow] {
        var out: [GridRow] = []
        var remaining = tickets

        while !remaining.isEmpty {
            let first = remaining.removeFirst()
            switch first.orientation {
            case .horizontal:
                out.append(.horizontal(first))
            case .vertical:
                if let pairIdx = remaining.firstIndex(where: { $0.orientation == .vertical }) {
                    let partner = remaining.remove(at: pairIdx)
                    out.append(.verticalPair(first, partner))
                } else {
                    out.append(.verticalSingle(first))
                }
            }
        }
        return out
    }
}

// MARK: - Grouping model

struct TicketGroup: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let tickets: [Ticket]
}

enum TicketGrouping {

    /// Groups by relative creation time: Today / This week / This month /
    /// This year / year label for older. Empty buckets are omitted. Groups
    /// list newest-first, tickets within a group list newest-first.
    static func byDate(_ tickets: [Ticket], now: Date) -> [TicketGroup] {
        let calendar = Calendar.current
        let sorted = tickets.sorted { $0.createdAt > $1.createdAt }

        var buckets: [(key: String, title: LocalizedStringKey, order: Int, tickets: [Ticket])] = []

        func appendTo(
            key: String,
            title: LocalizedStringKey,
            order: Int,
            ticket: Ticket
        ) {
            if let idx = buckets.firstIndex(where: { $0.key == key }) {
                buckets[idx].tickets.append(ticket)
            } else {
                buckets.append((key, title, order, [ticket]))
            }
        }

        for ticket in sorted {
            let date = ticket.createdAt
            if calendar.isDateInToday(date) {
                appendTo(key: "today", title: "Today", order: 0, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                appendTo(key: "week", title: "This week", order: 1, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                appendTo(key: "month", title: "This month", order: 2, ticket: ticket)
            } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
                appendTo(key: "year", title: "This year", order: 3, ticket: ticket)
            } else {
                let year = calendar.component(.year, from: date)
                // Negative order keeps older years after the relative
                // buckets while still sorting newer-year-first.
                appendTo(
                    key: "y-\(year)",
                    title: LocalizedStringKey("\(year)"),
                    order: 10_000 - year,
                    ticket: ticket
                )
            }
        }

        return buckets
            .sorted { $0.order < $1.order }
            .map { TicketGroup(id: $0.key, title: $0.title, tickets: $0.tickets) }
    }

    /// Groups by ticket category label (plane / train / …). Ordering
    /// mirrors first-occurrence in the source list so newly added
    /// categories appear where they naturally fall.
    static func byCategory(_ tickets: [Ticket]) -> [TicketGroup] {
        var buckets: [(key: String, tickets: [Ticket])] = []

        for ticket in tickets {
            let key = ticket.kind.categoryLabel
            if let idx = buckets.firstIndex(where: { $0.key == key }) {
                buckets[idx].tickets.append(ticket)
            } else {
                buckets.append((key, [ticket]))
            }
        }

        return buckets.map {
            TicketGroup(
                id: $0.key,
                title: LocalizedStringKey($0.key),
                tickets: $0.tickets
            )
        }
    }
}

// MARK: - Previews

#Preview("Empty") {
    AllTicketsView()
        .environmentObject(TicketsStore())
        .environmentObject(MemoriesStore())
        .environmentObject(AllTicketsSortPresenter())
        .environmentObject(OnboardingCoordinator())
        .environment(EntitlementStore.previewInstance(tier: .free, monetisationEnabled: true))
        .environment(Paywall.PresentationState())
}

#Preview("Populated") {
    let store = TicketsStore()
    store.seedSamples()
    return AllTicketsView()
        .environmentObject(store)
        .environmentObject(MemoriesStore())
        .environmentObject(AllTicketsSortPresenter())
        .environmentObject(OnboardingCoordinator())
        .environment(EntitlementStore.previewInstance(tier: .free, monetisationEnabled: true))
        .environment(Paywall.PresentationState())
}
