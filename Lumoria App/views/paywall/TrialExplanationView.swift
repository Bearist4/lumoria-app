//
//  TrialExplanationView.swift
//  Lumoria App
//
//  Sheet shown when the user taps "Try for 14 days" on the paywall.
//  Walks them through the trial timeline (today / day 13 / day 15),
//  offers a day-13 reminder toggle, and hands off to the actual
//  StoreKit purchase when they confirm.
//
//  Figma: 969:20168
//

import SwiftUI

struct TrialExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    /// User's preference for receiving a day-13 reminder push. Persisted
    /// across sessions so they only have to set it once. Wiring the
    /// actual local notification scheduling is a separate piece of
    /// work — for now we just remember the choice.
    @AppStorage("trial.dayThirteenReminderEnabled")
    private var reminderEnabled: Bool = true

    /// Confirms the trial and kicks off the StoreKit purchase. The
    /// caller is responsible for dismissing this sheet after the
    /// purchase fires.
    let onStartTrial: () -> Void

    /// Whether the parent paywall is currently mid-purchase. Disables
    /// the CTA so the user can't double-fire.
    let isPurchasing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            LumoriaIconButton(
                systemImage: "xmark",
                size: .large,
                position: .onBackground,
                action: { dismiss() }
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)

            titleBlock
                .padding(.horizontal, 24)
                .padding(.top, 24)

            timeline
                .padding(.horizontal, 24)
                .padding(.top, 32)

            reminderRow
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer(minLength: 24)

            footerCaption
                .padding(.horizontal, 24)

            startButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.Background.default)
    }

    // MARK: - Title

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Try everything.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.black)
                trialFreeLine
            }
            Text("Full access from day one. Cancel before day 15 and you won't be charged anything.")
                .font(.body)
                .foregroundStyle(Color.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three-colour split: "Free" (blue) / " for " (secondary text) /
    /// "14 days." (amber).
    private var trialFreeLine: some View {
        (Text("Free")
            .foregroundStyle(Color(red: 0.27, green: 0.51, blue: 0.96))
         + Text(" for ")
            .foregroundStyle(Color.Text.secondary)
         + Text("14 days.")
            .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.30))
        )
        .font(.largeTitle.bold())
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            StepTimelineRow(
                heading: "Today",
                body: "Start enjoying Lumoria's premium features for free."
            ) {
                Image(systemName: "arrow.right")
            }
            StepTimelineRow(
                heading: "Day 13",
                body: "You will get a reminder that your trial is about to expire."
            ) {
                dayBadge(13)
            }
            StepTimelineRow(
                heading: "Day 15",
                body: "If you haven't canceled, your subscription will begin and you will be charged.",
                isLast: true
            ) {
                dayBadge(15)
            }
        }
    }

    /// Calendar SF symbol with the day number drawn on top.
    private func dayBadge(_ day: Int) -> some View {
        ZStack {
            Image(systemName: "calendar")
                .font(.headline)
            Text("\(day)")
                .font(.system(size: 9, weight: .bold))
                .offset(y: 1)
        }
    }

    // MARK: - Reminder toggle

    private var reminderRow: some View {
        HStack {
            Text("Remind me on day 13")
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)
            Spacer()
            Toggle("", isOn: $reminderEnabled)
                .labelsHidden()
                .tint(Color(red: 0.20, green: 0.78, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
        )
    }

    // MARK: - Footer

    private var footerCaption: some View {
        Text("Cancel anytime in your App Store subscriptions.")
            .font(.footnote)
            .foregroundStyle(Color.Text.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var startButton: some View {
        Button {
            onStartTrial()
        } label: {
            Text("Try free for 14 days")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(isPurchasing)
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Trial explanation") {
    TrialExplanationView(
        onStartTrial: { },
        isPurchasing: false
    )
}

#Preview("Trial explanation — purchasing") {
    TrialExplanationView(
        onStartTrial: { },
        isPurchasing: true
    )
}

#endif
