import CertigoData
import CertigoDomain
import SwiftUI
import WidgetKit
#if canImport(AppIntents)
  import AppIntents
#endif

private struct CertigoWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> CertigoWidgetEntry {
    let now = Date.now
    let initialSnapshot = CertigoWidgetSnapshot.defaultInitialSnapshot(now: now)
    return CertigoWidgetEntry(date: now, snapshot: initialSnapshot, status: .available)
  }

  func getSnapshot(in context: Context, completion: @escaping (CertigoWidgetEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<CertigoWidgetEntry>) -> Void
  ) {
    let now = Date.now
    let entry = loadEntry(at: now)
    let entries = [entry]
    completion(
      Timeline(
        entries: entries,
        policy: .after(now.addingTimeInterval(30 * 60))
      ))
  }

  private func loadEntry(at now: Date = .now) -> CertigoWidgetEntry {
    let store = CertigoWidgetStore(sharedContainerOnly: false)
    switch store.loadState(now: now) {
    case .ready(let snapshot):
      return CertigoWidgetEntry(date: now, snapshot: snapshot, status: .available)
    case .unconfigured:
      let defaultSnapshot = CertigoWidgetSnapshot.defaultInitialSnapshot(now: now)
      return CertigoWidgetEntry(date: now, snapshot: defaultSnapshot, status: .available)
    }
  }
}

struct CertigoDailyWidget: Widget {
  private let kind = "com.certigo.native.daily-widget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CertigoWidgetProvider()) { entry in
      CertigoWidgetCardView(entry: entry)
        .environment(\.locale, entry.snapshot?.language.locale ?? Locale.current)
    }
    .configurationDisplayName("CertiGo")
    .description("A gentle reminder of your learning progress.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular,
    ])
  }
}

#if canImport(WidgetKit) && canImport(AppIntents)
  @available(iOS 18.0, *)
  struct LaunchCertiGoAIIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir CertiGo AI"
    static let description = IntentDescription(
      "Ouvre instantanément l'assistant CertiGo AI pour poser une question sur tes cours ou l'actualité Tech."
    )
    static let openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult & OpensIntent {
      let timestamp = Date.now.timeIntervalSince1970
      if let sharedDefaults = UserDefaults(suiteName: "group.com.certigo.shared") {
        sharedDefaults.set("hubIA", forKey: "certigo.PendingDeepLinkTarget")
        sharedDefaults.set(timestamp, forKey: "certigo.PendingDeepLinkTimestamp")
      }
      UserDefaults.standard.set("hubIA", forKey: "certigo.PendingDeepLinkTarget")
      UserDefaults.standard.set(timestamp, forKey: "certigo.PendingDeepLinkTimestamp")
      return .result(opensIntent: OpenURLIntent(URL(string: "certigo://ai")!))
    }
  }

  @available(iOS 18.0, *)
  struct CertiGoAIControlCenterWidget: ControlWidget {
    static let kind = "com.certigo.mobileapp.control.ai"

    var body: some ControlWidgetConfiguration {
      StaticControlConfiguration(kind: Self.kind) {
        ControlWidgetButton(action: LaunchCertiGoAIIntent()) {
          Label("CertiGo AI", systemImage: "sparkles")
        }
      }
      .displayName("✦ CertiGo AI")
      .description(
        "Ouvre instantanément l'assistant CertiGo AI pour poser une question sur tes cours ou l'actualité Tech."
      )
    }
  }
#endif

@main
struct CertigoWidgetBundle: WidgetBundle {
  var body: some Widget {
    CertigoDailyWidget()
    #if canImport(WidgetKit) && canImport(AppIntents)
      CertiGoAIControlCenterWidget()
    #endif
  }
}
