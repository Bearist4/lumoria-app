import Testing
@testable import Lumoria_App

@Suite("TicketShimmer")
struct TicketShimmerTests {

    @Test("shimmer mode assignment per template")
    func perTemplate() {
        #expect(TicketTemplateKind.prism.shimmer == .holographic)
        #expect(TicketTemplateKind.studio.shimmer == .holographic)
        #expect(TicketTemplateKind.heritage.shimmer == .paperGloss)
        #expect(TicketTemplateKind.terminal.shimmer == .paperGloss)
        #expect(TicketTemplateKind.orient.shimmer == .paperGloss)
        #expect(TicketTemplateKind.express.shimmer == .paperGloss)
        #expect(TicketTemplateKind.afterglow.shimmer == .softGlow)
        #expect(TicketTemplateKind.night.shimmer == .softGlow)
    }

    @Test("no template is .none by default")
    func noDefaultNone() {
        for kind in TicketTemplateKind.allCases {
            #expect(kind.shimmer != TicketShimmer.none)
        }
    }
}
