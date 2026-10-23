import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    @main
    struct CertigoNativeApp: App {
        var body: some Scene {
            WindowGroup {
                NativeLanguageRoot()
                    #if DEBUG
                        .modifier(PrismDebugGalleryLauncher())
                    #endif
            }
        }
    }

    private struct NativeLanguagePreferenceKey: EnvironmentKey {
        static let defaultValue: Binding<AppLanguagePreference> = .constant(.system)
    }

    private struct NativeInterfaceCopyKey: EnvironmentKey {
        static let defaultValue = AppInterfaceCopy(language: .english)
    }

    extension EnvironmentValues {
        var nativeLanguagePreference: Binding<AppLanguagePreference> {
            get { self[NativeLanguagePreferenceKey.self] }
            set { self[NativeLanguagePreferenceKey.self] = newValue }
        }

        var nativeInterfaceCopy: AppInterfaceCopy {
            get { self[NativeInterfaceCopyKey.self] }
            set { self[NativeInterfaceCopyKey.self] = newValue }
        }
    }

    private struct NativeLanguageRoot: View {
        @Environment(\.scenePhase) private var scenePhase
        @State private var preference = AppLanguagePreference.load(from: .standard)
        @State private var preferredLanguages = Locale.preferredLanguages

        private var effectiveLanguage: AppLanguage {
            preference.effectiveLanguage(fromPreferredLanguages: preferredLanguages)
        }

        var body: some View {
            NativeEntry()
                .tint(NativePrism.tint)
                .environment(\.locale, effectiveLanguage.locale)
                .environment(\.nativeInterfaceCopy, AppInterfaceCopy(language: effectiveLanguage))
                .environment(
                    \.nativeLanguagePreference,
                    Binding(
                        get: { preference },
                        set: {
                            $0.save(to: .standard)
                            preference = $0
                        })
                )
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        preferredLanguages = Locale.preferredLanguages
                        preference = AppLanguagePreference.load(from: .standard)
                    }
                }
        }
    }

    struct NativeAppLanguagePicker: View {
        @Environment(\.nativeLanguagePreference) private var preference
        @Environment(\.nativeInterfaceCopy) private var copy

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Picker(
                    copy.appLanguage,
                    selection: Binding(
                        get: { preference.wrappedValue.rawValue },
                        set: { raw in
                            guard let value = AppLanguagePreference(rawValue: raw) else { return }
                            preference.wrappedValue = value
                        })
                ) {
                    Text(copy.systemDefault).tag(AppLanguagePreference.system.rawValue)
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        Text(
                            "\(language.nativeDisplayName) · "
                                + language.localizedDisplayName(in: copy.language)
                        )
                        .tag(AppLanguagePreference.explicit(language).rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityIdentifier("app-interface-language")
                Text(copy.contentLanguageNote)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("app-content-language-note")
            }
        }
    }
#endif
