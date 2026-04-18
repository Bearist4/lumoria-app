//
//  NotificationCard.swift
//  Lumoria App
//
//  Design: figma.com/design/09xVBFOsdBBcmbA0Iql3qv/App?node-id=1051-51775
//
//  Single-notification tile. Colour comes from `kind.backgroundColor`;
//  the eyebrow, time, and body are the same shape across all four
//  variants. Swipe-to-delete lives on the parent List row.
//

import SwiftUI

struct NotificationCard: View {

    let notification: LumoriaNotification

    @EnvironmentObject private var memoriesStore: MemoriesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Text(notification.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.Text.OnColor.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(resolvedMessage)
                .font(.callout)
                .foregroundStyle(Color.Text.OnColor.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(notification.kind.backgroundColor)
        )
    }

    /// Swaps in the decrypted memory name for throwbacks that carry a
    /// `memory_id`. The DB stores a generic fallback because memory
    /// names are encrypted — the substitution happens here, where the
    /// plaintext cache lives.
    private var resolvedMessage: String {
        guard notification.kind == .throwback,
              let id = notification.memoryId,
              let memory = memoriesStore.memories.first(where: { $0.id == id })
        else {
            return notification.message
        }
        return String(localized: "You were in \(memory.name). Take a look back.")
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(notification.kind.eyebrow)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.Text.OnColor.black)

            Spacer(minLength: 0)

            Text(timeString)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.Text.OnColor.black)
        }
        .opacity(0.6)
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: notification.createdAt)
    }
}

#Preview {
    VStack(spacing: 12) {
        NotificationCard(notification: LumoriaNotification(
            kind: .throwback,
            title: "One year ago today",
            message: "You were in Lake Tahoe. Take a look back."
        ))
        NotificationCard(notification: LumoriaNotification(
            kind: .onboarding,
            title: "Your first ticket is waiting",
            message: "Turn your next trip into something beautiful. It only takes a moment."
        ))
        NotificationCard(notification: LumoriaNotification(
            kind: .news,
            title: "New templates just landed",
            message: "Fresh designs are waiting. Go make something beautiful."
        ))
        NotificationCard(notification: LumoriaNotification(
            kind: .link,
            title: "Your friend is in!",
            message: "Your link has been redeemed. A new collection slot is ready for you."
        ))
    }
    .padding(24)
    .background(Color.Background.default)
    .environmentObject(MemoriesStore())
}
