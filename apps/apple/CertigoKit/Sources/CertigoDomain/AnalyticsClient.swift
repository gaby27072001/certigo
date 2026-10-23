/// Implementations must enforce explicit consent before persisting or sending events.
/// No free-form learner content, identity, secrets, or third-party SDK is part of this API.
public protocol AnalyticsClient: Sendable {
    func record(_ event: AnalyticsEvent) async throws
}

public enum AnalyticsEvent: Equatable, Sendable {
    public enum Entry: String, Sendable {
        case icon, widget, notification, intent, spotlight, link
    }

    case appOpened(source: Entry)
    case dailySituationOpened
    case offlineModeEntered
    case widgetInteraction
}
