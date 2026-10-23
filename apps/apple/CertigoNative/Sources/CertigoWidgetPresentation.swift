#if canImport(SwiftUI) && canImport(WidgetKit)
import CertigoDomain
import SwiftUI
import UIKit
import WidgetKit

enum CertigoWidgetEntryStatus: Equatable, Sendable {
  case available
  case empty
  case stale
  case sharedContainerUnavailable
  case unreadable
}

struct CertigoWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: CertigoWidgetSnapshot?
  let status: CertigoWidgetEntryStatus
}

struct CertigoWidgetCardView: View {
  let entry: CertigoWidgetEntry
  private let previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily

  init(entry: CertigoWidgetEntry, family: WidgetFamily? = nil) {
    self.entry = entry
    self.previewFamily = family
  }

  private var family: WidgetFamily { previewFamily ?? environmentFamily }

  private var copy: CertigoWidgetCopy {
    CertigoWidgetCopy(language: entry.snapshot?.language ?? .resolved())
  }

  private var phase: CertigoWidgetPhase {
    entry.snapshot?.phase(at: entry.date) ?? .readyToStart
  }

  private var accent: Color {
    switch phase {
    case .readyToStart: Color(red: 0.12, green: 0.48, blue: 0.91)
    case .inProgress: Color(red: 0.19, green: 0.57, blue: 0.87)
    case .streakAtRisk: Color(red: 0.91, green: 0.36, blue: 0.20)
    case .goalCompleted: Color(red: 0.16, green: 0.62, blue: 0.42)
    }
  }

  var body: some View {
    Group {
      if entry.status == .available, let snapshot = entry.snapshot,
        snapshot.phase(at: entry.date) != nil
      {
        content(snapshot, family: family)
      } else {
        unavailable
      }
    }
    .containerBackground(for: .widget) {
      background
    }
    .widgetURL(entry.snapshot?.destination.url)
    .privacySensitive()
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func content(_ snapshot: CertigoWidgetSnapshot, family: WidgetFamily) -> some View {
    switch family {
    case .systemSmall:
      small(snapshot)
    case .systemMedium, .systemLarge, .systemExtraLarge:
      medium(snapshot)
    case .accessoryCircular:
      accessoryCircular(snapshot)
    case .accessoryRectangular, .accessoryInline:
      accessoryRectangular(snapshot)
    default:
      unavailable
    }
  }

  private func small(_ snapshot: CertigoWidgetSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "flame.fill")
          .foregroundStyle(accent)
        if let streak = snapshot.streakDays {
          Text("\(streak)")
            .font(.headline.weight(.bold).monospacedDigit())
        }
        Spacer(minLength: 4)
        CertigoWidgetMark()
          .frame(width: 22, height: 22)
      }
      Text(copy.title(for: phase))
        .font(.headline.weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 0)
      HStack(spacing: 9) {
        CertigoWidgetRing(
          progress: snapshot.dailyGoalProgress,
          accent: accent,
          accessibilityLabel: copy.dailyGoalAccessibility(progress: snapshot.dailyGoalProgress)
        )
          .frame(width: 38, height: 38)
        VStack(alignment: .leading, spacing: 2) {
          Text(snapshot.activeTrackCode ?? copy.noGoal)
            .font(.caption.weight(.bold))
            .lineLimit(1)
          Text(copy.continueLearning)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
    }
    .padding(14)
  }

  private func medium(_ snapshot: CertigoWidgetSnapshot) -> some View {
    HStack(spacing: 18) {
      VStack(alignment: .leading, spacing: 9) {
        HStack(spacing: 6) {
          Image(systemName: "flame.fill").foregroundStyle(accent)
          if let streak = snapshot.streakDays {
            Text("\(streak) \(copy.streakLabel)")
              .font(.subheadline.weight(.semibold).monospacedDigit())
          }
        }
        Text(copy.title(for: phase))
          .font(.title3.weight(.bold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        HStack(spacing: 6) {
          CertigoWidgetMark().frame(width: 20, height: 20)
          Text(snapshot.activeTrackCode ?? copy.noGoal)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Spacer(minLength: 4)
          Text("\(snapshot.totalXP) XP")
            .font(.caption.weight(.semibold).monospacedDigit())
        }
        Spacer(minLength: 0)
        Text(copy.continueLearning)
          .font(.caption.weight(.bold))
          .foregroundStyle(accent)
      }
      Spacer(minLength: 0)
      VStack(spacing: 6) {
        CertigoWidgetRing(
          progress: snapshot.dailyGoalProgress,
          accent: accent,
          accessibilityLabel: copy.dailyGoalAccessibility(progress: snapshot.dailyGoalProgress)
        )
          .frame(width: 72, height: 72)
        if let earned = snapshot.dailyXPEarned, let goal = snapshot.dailyGoalXP {
          Text("\(earned) / \(goal) XP")
            .font(.caption2.weight(.semibold).monospacedDigit())
            .lineLimit(1)
        }
      }
    }
    .padding(16)
  }

  private func accessoryCircular(_ snapshot: CertigoWidgetSnapshot) -> some View {
    ZStack {
      if let progress = snapshot.dailyGoalProgress {
        CertigoWidgetRing(
          progress: progress,
          accent: accent,
          accessibilityLabel: copy.dailyGoalAccessibility(progress: progress)
        )
          .padding(2)
      }
      VStack(spacing: 0) {
        Image(systemName: phase == .goalCompleted ? "checkmark" : "flame.fill")
          .font(.system(size: 14, weight: .bold))
        if let streak = snapshot.streakDays {
          Text("\(streak)")
            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
        }
      }
      .foregroundStyle(accent)
    }
    .widgetLabel {
      Text(snapshot.activeTrackCode ?? copy.continueLearning)
    }
  }

  private func accessoryRectangular(_ snapshot: CertigoWidgetSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 5) {
        Image(systemName: phase == .goalCompleted ? "checkmark.circle.fill" : "flame.fill")
          .foregroundStyle(accent)
        if let streak = snapshot.streakDays {
          Text("\(streak) \(copy.streakLabel)")
            .fontWeight(.semibold)
        }
      }
      Text(copy.title(for: phase))
        .font(.headline)
        .lineLimit(1)
      if let code = snapshot.activeTrackCode {
        Text(code)
          .font(.caption2.weight(.bold))
          .foregroundStyle(accent)
      }
    }
  }

  private var unavailable: some View {
    VStack(alignment: .leading, spacing: 8) {
      CertigoWidgetMark().frame(width: 26, height: 26)
      Text(entry.status == .sharedContainerUnavailable ? copy.sharingNotConfigured : copy.openCertigo)
        .font(.headline)
        .lineLimit(3)
    }
    .padding(14)
  }

  private var background: some View {
    LinearGradient(
      colors: [
        accent.opacity(phase == .goalCompleted ? 0.13 : 0.10),
        Color(uiColor: .secondarySystemGroupedBackground),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

struct CertigoWidgetRing: View {
  let progress: Double?
  let accent: Color
  let accessibilityLabel: String

  var body: some View {
    ZStack {
      Circle()
        .stroke(accent.opacity(0.16), lineWidth: 5)
      if let progress {
        Circle()
          .trim(from: 0, to: min(1, max(0, progress)))
          .stroke(
            accent.gradient,
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
      Text(progress.map { "\((Int(($0 * 100).rounded())))%" } ?? "—")
        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
        .minimumScaleFactor(0.75)
    }
    .accessibilityLabel(accessibilityLabel)
  }
}

struct CertigoWidgetMark: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.12, green: 0.48, blue: 0.91),
              Color(red: 0.31, green: 0.39, blue: 0.87),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      Image(systemName: "sparkle")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
    }
    .accessibilityHidden(true)
  }
}
#endif
