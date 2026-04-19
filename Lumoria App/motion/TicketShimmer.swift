/// How a ticket surface responds to tilt. One attribute per template.
enum TicketShimmer: String, Codable, CaseIterable {
    /// Angular conic gradient (cyan → magenta → yellow → cyan). Prism, Studio.
    case holographic
    /// Soft white linear sheen sweeping diagonally. Boarding-pass gloss.
    case paperGloss
    /// Radial bloom at ticket center that brightens with tilt. Afterglow, Night.
    case softGlow
    /// No shimmer overlay. Reserved for future templates.
    case none
}
