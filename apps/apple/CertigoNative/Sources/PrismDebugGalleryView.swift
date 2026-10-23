#if DEBUG && canImport(SwiftUI)
  import CertigoDomain
  import Prism
  import SwiftUI

  struct PrismDebugGalleryLauncher: ViewModifier {
    @State private var presented = false

    func body(content: Content) -> some View {
      content
        .overlay(alignment: .topTrailing) {
          Button {
            presented = true
          } label: {
            Label {
              Text(verbatim: "Prism D-1")
            } icon: {
              Image(systemName: "slider.horizontal.3")
            }
            .prismTextStyle(.caption)
            .frame(minHeight: PrismSize.minTouch)
            .padding(.horizontal, PrismSpacing.m)
            .background(PrismColor.surface, in: Capsule())
          }
          .accessibilityIdentifier("open-prism-gallery")
          .padding(PrismSpacing.s)
        }
        .sheet(isPresented: $presented) { PrismDebugGalleryView() }
    }
  }

  struct PrismDebugGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.nativeInterfaceCopy) private var copy
    @Environment(\.colorScheme) private var scheme
    @State private var flags = FeatureFlags()
    @State private var configurationError = false
    @State private var remoteJSON = "{}"

    var body: some View {
      NavigationStack {
        List {
          Section {
            ForEach(PrismColorRole.allCases, id: \.rawValue) { role in
              HStack {
                Circle().fill(PrismColor.color(role))
                  .frame(width: PrismSize.brandM, height: PrismSize.brandM)
                  .accessibilityHidden(true)
                Text(verbatim: role.rawValue).prismTextStyle(.body)
              }
            }
          } header: {
            Text(verbatim: "PrismColorRole")
          }
          Section {
            ForEach(PrismRegion.allCases, id: \.rawValue) { region in
              Text(verbatim: region.rawValue)
                .prismTextStyle(.body)
                .foregroundStyle(PrismColor.textPrimary)
                .padding(PrismSpacing.s)
                .background(region.soft.color(in: scheme))
            }
          } header: {
            Text(verbatim: "PrismRegion")
          }
          Section {
            ForEach(PrismSyntax.allCases, id: \.rawValue) { syntax in
              Text(verbatim: syntax.rawValue)
                .prismTextStyle(.code)
                .foregroundStyle(
                  syntax == .flaggedLineBackground ? PrismColor.textPrimary : syntax.color
                )
                .padding(PrismSpacing.s)
                .background(
                  syntax == .flaggedLineBackground ? syntax.color : PrismColor.surfaceArtifact)
            }
          } header: {
            Text(verbatim: "PrismSyntax")
          }
          Section {
            ForEach(PrismTextStyle.allCases, id: \.rawValue) { style in
              Text(verbatim: style.rawValue).prismTextStyle(style)
            }
          } header: {
            Text(verbatim: "PrismTextStyle")
          }
          Section {
            ForEach(spacing, id: \.0) { name, value in
              VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: "\(name) · \(Double(value))")
                Rectangle().fill(PrismColor.accent)
                  .frame(width: value, height: PrismSpacing.xs)
                  .accessibilityHidden(true)
              }
            }
            Text(
              verbatim:
                "Radius · \(PrismRadius.s), \(PrismRadius.m), \(PrismRadius.l), \(PrismRadius.xl), capsule"
            )
            Text(
              verbatim: "Touch · \(PrismSize.minTouch) · Button · \(PrismSize.primaryButtonHeight)")
            Text(verbatim: "Readable · \(PrismSize.readableWidth)")
            Text(
              verbatim:
                "Brand · \(PrismSize.brandS), \(PrismSize.brandM), \(PrismSize.brandL), \(PrismSize.brandXL)"
            )
          } header: {
            Text(verbatim: "PrismSpacing · PrismRadius · PrismSize")
          }
          Section {
            ForEach(PrismMotionToken.allCases, id: \.rawValue) { token in
              Text(
                verbatim:
                  "\(token.rawValue) · \(PrismMotion.resolve(token, reduceMotion: false).duration)s · Reduce Motion \(PrismMotion.resolve(token, reduceMotion: true).duration)s"
              )
            }
            ForEach(PrismHapticToken.allCases, id: \.rawValue) { token in
              Text(verbatim: "Haptic · \(token.rawValue)")
            }
            ForEach(PrismSoundToken.allCases, id: \.rawValue) { token in
              Text(verbatim: "Sound · \(token.rawValue)")
            }
            ForEach(PrismMaterialRole.allCases, id: \.rawValue) { role in
              Text(verbatim: "Material · \(role.rawValue)")
            }
            ForEach(PrismCelebrationLevel.allCases, id: \.rawValue) { level in
              Text(verbatim: "Celebration · \(level.rawValue)")
            }
          } header: {
            Text(verbatim: "Motion · Haptics · Sounds · Materials · Celebrations")
          }
          Section {
            PrismText(text: "PrismText · Display / Body / Code", style: .headline)
            ForEach(PrismGlyph.allCases, id: \.rawValue) { glyph in
              HStack(spacing: PrismSpacing.s) {
                PrismIcon(glyph: glyph, accessibilityLabel: glyph.rawValue)
                Text(verbatim: glyph.rawValue).prismTextStyle(.caption)
              }
            }
            ForEach(PrismCardVariant.allCases, id: \.rawValue) { variant in
              PrismCard(variant: variant) {
                Text(verbatim: "PrismCard · \(variant.rawValue)").prismTextStyle(.body)
              }
            }
            PrismProgressBar(
              configuration: PrismProgressBarConfiguration(
                progress: 0.68, accessibilityLabel: "Progress"))
            PrismProgressRing(
              configuration: PrismProgressRingConfiguration(
                progress: 0.75, centerLabel: "75%", accessibilityLabel: "Ring"))
          } header: {
            Text(verbatim: "Phase 2 · Core Components (Foundation)")
          }
          Section {
            ForEach(PrismSessionLength.allCases) { length in
              Text(verbatim: "SessionLength · \(length.rawValue) · \(length.defaultMinutes)m")
                .prismTextStyle(.callout)
            }
            ForEach(PrismConfidenceLevel.allCases) { level in
              Text(verbatim: "Confidence · \(level.rawValue) · \(level.title)")
                .prismTextStyle(.callout)
            }
            ForEach(PrismMasteryState.allCases, id: \.rawValue) { state in
              MasteryGlyph(state: state)
            }
            ForEach(PrismReadinessBand.allCases, id: \.rawValue) { band in
              Text(verbatim: "ReadinessBand · \(band.rawValue) · \(band.label)")
                .prismTextStyle(.caption)
            }
            PrismOfflineBanner(
              model: PrismOfflineBannerModel(cachedSessionsCount: 2, queuedSubmissionsCount: 1))
          } header: {
            Text(verbatim: "Phase 2 · Learning · Progress · Social · States · A11y")
          }
          Section {
            BrandLabel(product: .azureVirtualMachines, context: .learningContent)
            BrandLabel(product: .microsoftAzure, context: .catalog, examCode: "AZ-900")
            BrandLabel(product: .m365Excel, context: .learningContent, examCode: "MO-200")
            NavigationLink {
              BrandNoticesView()
            } label: {
              Text(verbatim: "BrandNoticesView · Marques et mentions légales")
            }
          } header: {
            Text(verbatim: "Phase 2B · Official Brand Assets (§22A)")
          }
          Section {
            ForEach(AppTab.allCases) { tab in
              HStack(spacing: PrismSpacing.s) {
                Image(systemName: tab.selectedSymbolName)
                  .foregroundStyle(PrismColor.accent)
                Text(verbatim: "\(tab.title) (\(tab.rawValue))")
                  .prismTextStyle(.body)
              }
            }
          } header: {
            Text(verbatim: "Phase 3 · Home / Today & Router (§12–14)")
          }
          Section {
            Text(verbatim: "P1 Formats · choice · situation · predict · spotTheIssue · ordering · commandComposer")
              .prismTextStyle(.callout)
            Text(verbatim: "Offline Cache · \(PrismOfflineSessionCache.maxCachedSessions) pre-composed sessions")
              .prismTextStyle(.caption)
          } header: {
            Text(verbatim: "Phase 4 · Session Player & P1 Formats (§6.2–6.4)")
          }
          Section {
            ForEach(MockExamTimePolicy.allCases) { policy in
              Text(verbatim: "MockExamTimePolicy · \(policy.title)")
                .prismTextStyle(.callout)
            }
          } header: {
            Text(verbatim: "Phase 5 · Feedback, Daily Situation & Mock Exam (§14–15)")
          }
          Section {
            ForEach(AtlasPresentationMode.allCases) { mode in
              Text(verbatim: "AtlasMode · \(mode.title)")
                .prismTextStyle(.callout)
            }
          } header: {
            Text(verbatim: "Phase 6 · Atlas, Concept, Readiness & Passport (§8, §14–15)")
          }
          Section {
            ForEach(MasteryMilestoneKind.allCases) { kind in
              Text(verbatim: "Milestone · \(kind.title)")
                .prismTextStyle(.callout)
            }
          } header: {
            Text(verbatim: "Phase 7 · Gamification (Rhythm, Milestones, Missions)")
          }
          Section {
            ForEach(FeatureFlag.allCases, id: \.rawValue) { flag in
              Picker(
                selection: Binding(
                  get: { flags.debugOverride(for: flag).map { $0 ? 1 : 0 } ?? -1 },
                  set: { selection in
                    flags.setDebugOverride(
                      selection == -1 ? nil : selection == 1, for: flag)
                    configurationError = false
                    do { try flags.saveDebugOverrides(to: .standard) } catch {
                      configurationError = true
                    }
                  })
              ) {
                Text(verbatim: "Compiled").tag(-1)
                Text(verbatim: "OFF").tag(0)
                Text(verbatim: "ON").tag(1)
              } label: {
                Text(verbatim: "\(flag.rawValue) · \(flags.isEnabled(flag) ? "ON" : "OFF")")
                  .prismTextStyle(.callout)
              }
            }

            TextEditor(text: $remoteJSON)
              .prismTextStyle(.codeSmall)
              .accessibilityLabel(Text(verbatim: "Remote kill switch JSON"))
              .frame(minHeight: PrismSize.primaryButtonHeight)
            Button {
              configurationError = false
              do { try flags.applyRemoteJSON(Data(remoteJSON.utf8)) } catch {
                configurationError = true
              }
            } label: {
              Text(verbatim: "Apply remote kill switches")
            }
            if configurationError {
              Label(copy.native(.dataFailure), systemImage: "exclamationmark.triangle")
            }
          } header: {
            Text(verbatim: "FeatureFlags · DEBUG")
          }
        }
        .navigationTitle(Text(verbatim: "Prism D-1"))
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(copy[.done]) { dismiss() }
          }
        }
        .task {
          do { try flags.loadDebugOverrides(from: .standard) } catch { configurationError = true }
        }
      }
    }

    private var spacing: [(String, CGFloat)] {
      [
        ("xxs", PrismSpacing.xxs), ("xs", PrismSpacing.xs), ("s", PrismSpacing.s),
        ("m", PrismSpacing.m), ("l", PrismSpacing.l), ("xl", PrismSpacing.xl),
        ("xxl", PrismSpacing.xxl), ("xxxl", PrismSpacing.xxxl),
        ("huge", PrismSpacing.huge), ("giant", PrismSpacing.giant),
      ]
    }
  }

  #Preview("Prism D-1") { PrismDebugGalleryView() }
#endif
