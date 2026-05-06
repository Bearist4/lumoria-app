import Foundation

extension Locale {
    /// Locale used for everything rendered inside a ticket. Tickets are
    /// designed in English and ship in English regardless of device
    /// locale — translating them would multiply the design surface.
    static let ticket = Locale(identifier: "en_US_POSIX")
}

extension LocalizedStringResource {
    /// Returns a copy with `.ticket` locale, so resolving the resource
    /// always produces the English string used in ticket art.
    var withTicketLocale: LocalizedStringResource {
        var copy = self
        copy.locale = .ticket
        return copy
    }
}
