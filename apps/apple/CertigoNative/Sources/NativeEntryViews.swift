import Foundation

#if canImport(SwiftUI)
    import AVFoundation
    import CertigoData
    import CertigoDomain
    import Observation
    import SwiftUI
    import UIKit

    struct NativeEntry: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @State private var showDemo = false
        #if DEBUG
            @State private var showDeveloper = false
        #endif
        @State private var pendingLessonLink: EditorialPilotLessonLink?
        @State private var pendingWidgetRoute: CertigoWidgetRoute?
        @State private var invalidLessonLink = false

        var body: some View {
            #if CERTIGO_PRODUCTION_DISTRIBUTION
                NativeProductionEntry(
                    pendingLessonLink: $pendingLessonLink,
                    pendingWidgetRoute: $pendingWidgetRoute)
            #else
                developmentEntry
            #endif
        }

        private var developmentEntry: some View {
            NavigationStack {
                NativeReadingPage {
                    NativeEntryHeading(
                        title: copy.native(.welcomeTitle),
                        message: copy.native(.welcomeHint), prominent: true)
                    NativeReadingSection(title: copy.native(.tryLearning)) {
                        NativePrimaryButton(title: copy.exploreDemo, symbol: "play.circle") {
                            showDemo = true
                        }
                        .accessibilityIdentifier("open-native-demo")
                        Text(
                            copy.native(.fictionalBoundary)
                        )
                        .foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            NativeShowcaseTile(code: "AZ", title: "Microsoft Azure")
                            NativeShowcaseTile(code: "GH", title: "GitHub & Copilot")
                            NativeShowcaseTile(code: "DP", title: "Microsoft Fabric")
                            NativeShowcaseTile(code: "AWS", title: "AWS")
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("entry-ecosystem-artwork")
                    DisclosureGroup(copy.appLanguage) { NativeAppLanguagePicker() }
                    #if DEBUG
                        if let pendingLessonLink {
                            NativeReadingSection(title: copy.native(.sharedLesson)) {
                                Text(
                                    "\(copy.native(.editorialPilot)) · \(pendingLessonLink.lessonID)"
                                )
                                Button(copy.native(.openLinkedLesson), systemImage: "book") {
                                    showDeveloper = true
                                }
                                .accessibilityIdentifier("continue-to-linked-lesson")
                            }
                        }
                        NativeReadingSection(title: copy.native(.development)) {
                            Button(
                                copy.native(.openConnector),
                                systemImage: "wrench.and.screwdriver"
                            ) {
                                showDeveloper = true
                            }
                            .frame(minHeight: 44)
                            Text(
                                copy.native(.testOnly)
                            )
                            .foregroundStyle(.secondary)
                        }
                    #endif
                }
                .navigationTitle("Certigo")
                .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                #if DEBUG
                    .sheet(isPresented: $showDeveloper) {
                        NativeDeveloperConnector(
                            pendingLessonLink: $pendingLessonLink,
                            pendingWidgetRoute: $pendingWidgetRoute
                        )
                        .interactiveDismissDisabled()
                    }
                #endif
            }
            .onOpenURL(perform: handleIncomingURL)
            .alert(copy.native(.lessonLinkUnavailable), isPresented: $invalidLessonLink) {
                Button(copy[.done], role: .cancel) { invalidLessonLink = false }
            } message: {
                Text(copy.native(.lessonLinkInvalid))
            }
        }

        private func handleIncomingURL(_ url: URL) {
            if let route = CertigoWidgetRoute(url: url) {
                pendingWidgetRoute = route
                #if DEBUG
                    showDeveloper = true
                #endif
                return
            }
            guard url.scheme == "https", url.host == EditorialPilotLessonLink.host else { return }
            guard let link = EditorialPilotLessonLink(url: url) else {
                pendingLessonLink = nil
                invalidLessonLink = true
                return
            }
            pendingLessonLink = link
        }
    }

    #if CERTIGO_PRODUCTION_DISTRIBUTION
        @MainActor
        private struct NativeProductionEntry: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @Binding private var pendingWidgetRoute: CertigoWidgetRoute?
            @State private var model: NativeModel
            @State private var provider: MSALAuthenticationProvider?
            @State private var configurationIssue: NativePresentationMessage?
            @State private var showDemo = false

            init(
                pendingLessonLink: Binding<EditorialPilotLessonLink?>,
                pendingWidgetRoute: Binding<CertigoWidgetRoute?>
            ) {
                self._pendingLessonLink = pendingLessonLink
                self._pendingWidgetRoute = pendingWidgetRoute
                do {
                    let configured = try CIAMConfigurationEnvironment.configuredProductionProvider(
                        infoDictionary: Bundle.main.infoDictionary ?? [:],
                        bundleIdentifier: Bundle.main.bundleIdentifier,
                        isDevelopmentBuild: false
                    ) { configuration in
                        try MSALAuthenticationProvider(
                            configuration: configuration,
                            presentation: Self.authenticationPresentationController)
                    }
                    _model = State(
                        initialValue: NativeModel(
                            authentication: (configured.provider, configured.configuration)))
                    _provider = State(initialValue: configured.provider)
                    _configurationIssue = State(initialValue: nil)
                } catch {
                    _model = State(initialValue: NativeModel())
                    _provider = State(initialValue: nil)
                    _configurationIssue = State(initialValue: Self.safeMessage(for: error))
                }
            }

            var body: some View {
                Group {
                    if let configurationIssue {
                        VStack(spacing: 24) {
                            NativeAppLanguagePicker().padding(20)
                            ContentUnavailableView(
                                copy.native(.signInUnconfigured),
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text(configurationIssue.resolved(using: copy)))
                        }
                    } else if model.profile == nil && model.deletionStage == nil {
                        NavigationStack {
                            NativeReadingPage {
                                NativeEntryHeading(
                                    title: copy.native(.productionTitle),
                                    message:
                                        copy.native(.productionHint)
                                )
                                NativeAppLanguagePicker()
                                NativeReadingSection(title: copy.native(.continueLearning)) {
                                    Text(copy.signInWithMicrosoft)
                                    NativePrimaryButton(
                                        title: copy.signInWithMicrosoft,
                                        symbol: "person.crop.circle"
                                    ) {
                                        Task { await model.connect() }
                                    }
                                    .disabled(model.busy)
                                    if model.busy { ProgressView() }
                                    Divider()
                                    Button(copy.exploreDemo, systemImage: "play.circle") {
                                        showDemo = true
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(model.busy)
                                    Text(copy.contentLanguageNote)
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            .navigationTitle("Certigo")
                            .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                            .alert(
                                copy.native(.signInIncomplete),
                                isPresented: Binding(
                                    get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }
                                )
                            ) {
                                Button(copy[.done], role: .cancel) { model.errorMessage = nil }
                            } message: {
                                Text(model.errorMessage?.resolved(using: copy) ?? "")
                            }
                        }
                    } else {
                        NativeRoot(
                            model: model, pendingLessonLink: $pendingLessonLink,
                            pendingWidgetRoute: $pendingWidgetRoute)
                    }
                }
                .onOpenURL { url in
                    if let route = CertigoWidgetRoute(url: url) {
                        pendingWidgetRoute = route
                        return
                    }
                    _ = provider?.handleCallback(url, sourceApplication: nil)
                }
                .task {
                    if configurationIssue == nil {
                        _ = await model.restoreAccountDeletionIfNeeded()
                    }
                }
            }

            @MainActor
            private static func authenticationPresentationController() throws -> UIViewController {
                let windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                guard var controller = windows.first(where: \.isKeyWindow)?.rootViewController
                else {
                    throw CIAMAuthenticationFailure.configuration
                }
                while let presented = controller.presentedViewController {
                    controller = presented
                }
                return controller
            }

            private static func safeMessage(for error: Error) -> NativePresentationMessage {
                switch error {
                case CIAMConfigurationEnvironmentError.productionBuildRequired:
                    .copy(.configurationDistributionOnly)
                case CIAMConfigurationEnvironmentError.unsupportedProductionBundle:
                    .copy(.configurationAppStoreBundle)
                case CIAMConfigurationEnvironmentError.missingValue(let key):
                    .configuration(name: key, production: true, missing: true)
                case CIAMConfigurationEnvironmentError.invalidValue(let key):
                    .configuration(name: key, production: true, missing: false)
                case CIAMConfigurationEnvironmentError.callbackNotDeclared:
                    .copy(.configurationDeclareProductionCallback)
                case CIAMConfigurationEnvironmentError.callbackCollision:
                    .copy(.configurationDuplicateProductionCallback)
                case CIAMConfigurationEnvironmentError.redirectDoesNotMatchBundle:
                    .copy(.configurationCallbackBundle)
                case is CIAMConfigurationEnvironmentError:
                    .copy(.configurationCorrectProduction)
                case is CIAMConfigurationError:
                    .copy(.configurationProductionValidation)
                default:
                    .copy(.configurationInitializationFailed)
                }
            }
        }
    #endif

    #if DEBUG
        @MainActor
        private struct NativeDeveloperConnector: View {
            @Environment(\.nativeInterfaceCopy) private var copy
            @Environment(\.dismiss) private var dismiss
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @Binding private var pendingWidgetRoute: CertigoWidgetRoute?
            @State private var model: NativeModel
            @State private var usesCIAM: Bool
            @State private var ciamProvider: MSALAuthenticationProvider?
            @State private var configurationIssue: NativePresentationMessage?

            init(
                pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil),
                pendingWidgetRoute: Binding<CertigoWidgetRoute?> = .constant(nil)
            ) {
                self._pendingLessonLink = pendingLessonLink
                self._pendingWidgetRoute = pendingWidgetRoute
                do {
                    let configured = try CIAMConfigurationEnvironment.configuredProvider(
                        environment: ProcessInfo.processInfo.environment,
                        bundleIdentifier: Bundle.main.bundleIdentifier,
                        infoDictionary: Bundle.main.infoDictionary ?? [:],
                        isDevelopmentBuild: true
                    ) { configuration in
                        try MSALAuthenticationProvider(
                            configuration: configuration,
                            presentation: Self.authenticationPresentationController
                        )
                    }
                    if let configured {
                        _model = State(
                            initialValue: NativeModel(
                                authentication: (configured.provider, configured.configuration)))
                        _usesCIAM = State(initialValue: true)
                        _ciamProvider = State(initialValue: configured.provider)
                    } else {
                        _model = State(initialValue: NativeModel())
                        _usesCIAM = State(initialValue: false)
                        _ciamProvider = State(initialValue: nil)
                    }
                    _configurationIssue = State(initialValue: nil)
                } catch {
                    _model = State(initialValue: NativeModel())
                    _usesCIAM = State(initialValue: true)
                    _ciamProvider = State(initialValue: nil)
                    _configurationIssue = State(
                        initialValue: Self.safeConfigurationMessage(for: error))
                }
            }

            var body: some View {
                Group {
                    if let configurationIssue {
                        ContentUnavailableView(
                            copy.native(.ciamUnavailable),
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(configurationIssue.resolved(using: copy))
                        )
                        .accessibilityIdentifier("ciam-configuration-error")
                    } else if usesCIAM && model.profile == nil {
                        ciamSignIn
                    } else {
                        NativeRoot(
                            model: model, pendingLessonLink: $pendingLessonLink,
                            pendingWidgetRoute: $pendingWidgetRoute,
                            closeDeveloper: { dismiss() })
                    }
                }
                .onOpenURL { url in
                    _ = ciamProvider?.handleCallback(url, sourceApplication: nil)
                }
                .overlay(alignment: .topTrailing) {
                    if configurationIssue != nil {
                        Button(copy.native(.close)) { dismiss() }
                            .buttonStyle(.bordered).padding()
                    }
                }
            }

            private var ciamSignIn: some View {
                NavigationStack {
                    NativeReadingPage {
                        NativeEntryHeading(
                            title: copy.native(.testLearning),
                            message: copy.native(.ciamTestScope))
                        NativeReadingSection(title: copy.native(.ciamTestSignIn)) {
                            Text(copy.native(.ciamExplicit))
                            NativePrimaryButton(
                                title: copy.native(.ciamSignIn), symbol: "person.crop.circle"
                            ) {
                                Task { await model.connect() }
                            }
                            .disabled(model.busy)
                        }
                    }
                    .modifier(NativeDeveloperToolbar(close: { dismiss() }))
                    .navigationTitle("Certigo")
                    .alert(
                        copy.native(.ciamIncomplete),
                        isPresented: Binding(
                            get: { model.errorMessage != nil },
                            set: { if !$0 { model.errorMessage = nil } }
                        )
                    ) {
                        Button(copy[.done], role: .cancel) { model.errorMessage = nil }
                    } message: {
                        Text(model.errorMessage?.resolved(using: copy) ?? "")
                    }
                }
            }

            @MainActor
            private static func authenticationPresentationController() throws -> UIViewController {
                let windows = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                guard var controller = windows.first(where: \.isKeyWindow)?.rootViewController
                else {
                    throw CIAMAuthenticationFailure.configuration
                }
                while let presented = controller.presentedViewController {
                    controller = presented
                }
                return controller
            }

            private static func safeConfigurationMessage(for error: Error)
                -> NativePresentationMessage
            {
                if let error = error as? CIAMConfigurationEnvironmentError {
                    switch error {
                    case .invalidOptIn: return .copy(.configurationOptIn)
                    case .missingValue(let name):
                        return .configuration(name: name, production: false, missing: true)
                    case .invalidValue(let name):
                        return .configuration(name: name, production: false, missing: false)
                    case .releaseOptInNotAllowed: return .copy(.configurationDevelopmentOnly)
                    case .productionBuildRequired: return .copy(.configurationDistributionOnly)
                    case .unsupportedProductionBundle: return .copy(.configurationAppStoreBundle)
                    case .missingBundleIdentifier: return .copy(.configurationMissingBundle)
                    case .callbackNotDeclared: return .copy(.configurationCallbackUnregistered)
                    case .callbackCollision: return .copy(.configurationCallbackDuplicate)
                    case .redirectDoesNotMatchBundle: return .copy(.configurationDerivedRedirect)
                    }
                }
                if let error = error as? CIAMConfigurationError {
                    switch error {
                    case .invalidIdentity:
                        return
                            .copy(.configurationIdentity)
                    case .invalidAuthority:
                        return .copy(.configurationAuthority)
                    case .issuerMismatch:
                        return .copy(.configurationIssuer)
                    case .invalidAPIScope:
                        return
                            .copy(.configurationScope)
                    case .invalidAPIURL:
                        return .copy(.configurationAPIURL)
                    case .invalidRedirect, .redirectNotRegistered:
                        return .copy(.configurationRedirect)
                    case .callbackNotDeclared:
                        return
                            .copy(.configurationCallbackDeclaration)
                    case .callbackCollision:
                        return .copy(.configurationCallbackCollision)
                    }
                }
                return
                    .copy(.configurationReview)
            }
        }
    #endif
#endif
