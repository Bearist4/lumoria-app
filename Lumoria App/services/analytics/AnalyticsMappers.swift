//
//  AnalyticsMappers.swift
//  Lumoria App
//
//  Converters between domain types and their analytics-wire-format enums.
//  Isolated here so domain refactors don't silently break the tracking
//  plan — changes to these mappings always show up in this file's diff.
//

import Foundation

extension TicketCategory {
    /// Wire format string for the `ticket_category` property.
    var analyticsProp: TicketCategoryProp {
        switch self {
        case .plane:         return .plane
        case .train:         return .train
        case .parksGardens:  return .parks_gardens
        case .publicTransit: return .public_transit
        case .concert:       return .concert
        }
    }
}

extension TicketTemplateKind {
    /// Wire format string for the `ticket_template` property.
    var analyticsTemplate: TicketTemplateProp {
        switch self {
        case .afterglow: return .afterglow
        case .studio:    return .studio
        case .terminal:  return .terminal
        case .heritage:  return .heritage
        case .prism:     return .prism
        case .express:   return .express
        case .orient:    return .orient
        case .night:     return .night
        }
    }

    /// Broad category the template belongs to.
    var analyticsCategory: TicketCategoryProp {
        switch self {
        case .afterglow, .studio, .terminal, .heritage, .prism:
            return .plane
        case .express, .orient, .night:
            return .train
        }
    }
}

extension TicketOrientation {
    /// Wire format string for the `ticket_orientation` property.
    var analyticsProp: OrientationProp {
        self == .horizontal ? .horizontal : .vertical
    }
}

extension NewTicketStep {
    /// Wire format string for the `funnel_step_reached` property.
    /// `.import` folds into `.form` so the Amplitude tracking plan keeps
    /// its existing shape; the source distinction lives on the separate
    /// `source` property via `TicketSourceProp`.
    var analyticsProp: FunnelStepProp {
        switch self {
        case .category:    return .category
        case .template:    return .template
        case .orientation: return .orientation
        case .import:      return .form
        case .form:        return .form
        case .style:       return .style
        case .success:     return .success
        }
    }
}
