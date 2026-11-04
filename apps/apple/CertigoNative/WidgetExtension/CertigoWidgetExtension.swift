import CertigoData
import CertigoDomain
import SwiftUI
import WidgetKit

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
    if let snapshot = try? store.read(now: now) {
      return CertigoWidgetEntry(date: now, snapshot: snapshot, status: .available)
    }
    let defaultSnapshot = CertigoWidgetSnapshot.defaultInitialSnapshot(now: now)
    return CertigoWidgetEntry(date: now, snapshot: defaultSnapshot, status: .available)
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

@main
struct CertigoWidgetBundle: WidgetBundle {
  var body: some Widget {
    CertigoDailyWidget()
  }
}
