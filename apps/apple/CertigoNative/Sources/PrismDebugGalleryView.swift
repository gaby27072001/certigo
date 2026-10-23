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
