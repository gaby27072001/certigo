import CertigoData
import CertigoDomain
import SwiftUI
import WidgetKit

private struct CertigoWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> CertigoWidgetEntry {
    CertigoWidgetEntry(date: .now, snapshot: nil, status: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (CertigoWidgetEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context, completion: @escaping (Timeline<CertigoWidgetEntry>) -> Void
  ) {
    let now = Date.now
    let entry = loadEntry(at: now)
    var entries = [entry]
    if let snapshot = entry.snapshot, entry.status == .available {
      entries.append(
        CertigoWidgetEntry(
          date: snapshot.validUntil,
          snapshot: nil,
          status: .stale
        ))
    }
    completion(
      Timeline(
        entries: entries,
        policy: .after(now.addingTimeInterval(30 * 60))
      ))
  }

  private func loadEntry(at now: Date = .now) -> CertigoWidgetEntry {
    let store = CertigoWidgetStore(sharedContainerOnly: true)
    do {
      guard let snapshot = try store.read(now: now) else {
        return CertigoWidgetEntry(date: now, snapshot: nil, status: .empty)
      }
      return CertigoWidgetEntry(date: now, snapshot: snapshot, status: .available)
    } catch CertigoWidgetStoreError.appGroupUnavailable {
      return CertigoWidgetEntry(
        date: now, snapshot: nil, status: .sharedContainerUnavailable)
    } catch CertigoWidgetStoreError.staleSnapshot {
      return CertigoWidgetEntry(date: now, snapshot: nil, status: .stale)
    } catch {
      return CertigoWidgetEntry(date: now, snapshot: nil, status: .unreadable)
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
    .configurationDisplayName("Certigo")
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
