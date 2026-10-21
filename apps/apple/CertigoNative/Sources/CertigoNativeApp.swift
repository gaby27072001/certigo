import Foundation

enum NativeTrackAppearance {
    // Catalog contracts have a certification code, not a visual domain index.
    static func band(for code: String) -> Int {
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().split(
            separator: "-"
        ).first {
        case "AI": 1
        case "PL": 2
        case "MS": 3
        case "DP": 4
        case "SC": 5
        default: 0
        }
    }
}

struct NativeCatalogFilter {
    var query = ""
    var family = ""
    var availableOnly = false

    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !family.isEmpty || availableOnly
    }

    static func family(for code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased().split(separator: "-").first.map(String.init) ?? ""
    }

    func includes(code: String, title: String, summary: String, available: Bool) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (family.isEmpty || Self.family(for: code) == family)
            && (!availableOnly || available)
            && (text.isEmpty
                || [code, title, summary].contains {
                    $0.range(
                        of: text, options: [.caseInsensitive, .diacriticInsensitive],
                        locale: Locale(identifier: "en_US_POSIX")) != nil
                })
    }

    mutating func clear() { self = Self() }
}

struct NativePathCoverage {
    let completedActivities: Int
    let totalActivities: Int
    let completedUnits: Int
    let totalUnits: Int
    let lockedActivities: Int

    init(units: [[String]]) {
        func complete(_ status: String) -> Bool {
            status == "completed" || status == "mastered"
        }
        let statuses = units.flatMap { $0 }
        completedActivities = statuses.filter(complete).count
        totalActivities = statuses.count
        completedUnits = units.filter { !$0.isEmpty && $0.allSatisfy(complete) }.count
        totalUnits = units.count
        lockedActivities = statuses.filter { $0 == "locked" }.count
    }

    var remainingActivities: Int { totalActivities - completedActivities }
}

struct NativeActivityDestination {
    let lessonID: String
    let title: String

    var resumeTitle: String { "Resume \(title)" }
    func actionTitle(_ action: String) -> String { "\(action) · \(title)" }
}

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

    // THESIS: A decision workshop extends the objective-first demo; no invented course or metrics.
    // OWN-WORLD: Prism violet, semantic surfaces, SF text, native navigation and glass controls.
    // STORY: Read a situation, decide, wait, understand; every demo result is explicitly synthetic.
    // FIRST VIEWPORT: One colored objective plane, one resume action, then quiet supporting rows.
    // FORM: Reviewable extension of approved A, not a new identity; bounded iPad reading width.
    enum NativePrism {
        // Prism spectrumInk / spectrumGlow; solid fills never use the brighter foreground role.
        private static let ink: [UInt32] = [
            0x3B35F2, 0x901BAE, 0xA91A66, 0x924A13, 0x177331, 0x176C7A,
        ]
        private static let glow: [UInt32] = [
            0x8097F8, 0xD764F8, 0xF95DA5, 0xEC7B26, 0x2DBC55, 0x2CB0C7,
        ]
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let edge = Color(
            uiColor: UIColor { traits in
                traits.accessibilityContrast == .high ? .label : .separator
            })
        static let tint = accent(band: 0)
        static let objectiveFill = Color(uiColor: color(ink[0]))
        static let confirmed = accent(band: 4)
        static let pending = accent(band: 3)

        static func accent(for code: String) -> Color {
            accent(band: NativeTrackAppearance.band(for: code))
        }

        private static func accent(band: Int) -> Color {
            Color(
                uiColor: UIColor { traits in
                    let dark = traits.userInterfaceStyle == .dark
                    let base = color(dark ? glow[band] : ink[band])
                    guard traits.accessibilityContrast == .high else { return base }
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    let target: CGFloat = dark ? 1 : 0
                    return UIColor(
                        red: red + (target - red) * 0.25,
                        green: green + (target - green) * 0.25,
                        blue: blue + (target - blue) * 0.25, alpha: 1)
                })
        }

        private static func color(_ hex: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }

    struct NativeReadingPage<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { content }
                    .padding(20)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .background(NativePrism.canvas)
        }
    }

    private struct NativeCatalogSearch: ViewModifier {
        let enabled: Bool
        @Binding var query: String

        @ViewBuilder func body(content: Content) -> some View {
            if enabled {
                content.searchable(text: $query, prompt: "Code, title or topic")
            } else {
                content
            }
        }
    }

    struct NativeReadingSection<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct NativeReadingCard<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    NativePrism.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(NativePrism.edge, lineWidth: 1)
                }
        }
    }

    struct NativePrimaryButton: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            Group {
                if #available(iOS 26.0, *), !reduceTransparency {
                    button.buttonStyle(.glassProminent)
                } else {
                    button.buttonStyle(.borderedProminent)
                }
            }
            .tint(NativePrism.objectiveFill)
        }

        private var button: some View {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.center)
            }
            .controlSize(.large)
        }
    }

    struct NativeChoiceButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                .padding(16)
                .background(
                    configuration.isPressed
                        ? Color(uiColor: .tertiarySystemFill) : NativePrism.surface,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    struct NativeEntryHeading: View {
        let title: String
        let message: String
        var prominent = false

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "book.pages")
                    .font(.title2).symbolRenderingMode(.monochrome).accessibilityHidden(true)
                Text(title).font(prominent ? .largeTitle.bold() : .title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.body)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
            .background(
                NativePrism.objectiveFill,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private struct NativeEntry: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @State private var showDemo = false
        #if DEBUG
            @State private var showDeveloper = false
        #endif
        @State private var pendingLessonLink: EditorialPilotLessonLink?
        @State private var invalidLessonLink = false

        var body: some View {
            #if CERTIGO_PRODUCTION_DISTRIBUTION
                NativeProductionEntry(pendingLessonLink: $pendingLessonLink)
            #else
                developmentEntry
            #endif
        }

        private var developmentEntry: some View {
            NavigationStack {
                NativeReadingPage {
                    NativeEntryHeading(
                        title: "One question. A clearer idea.",
                        message: "Explore Certigo’s native learning preview.", prominent: true)
                    NativeAppLanguagePicker()
                    NativeReadingSection(title: "Try the learning experience") {
                        NativePrimaryButton(title: copy.exploreDemo, symbol: "play.circle") {
                            showDemo = true
                        }
                        .accessibilityIdentifier("open-native-demo")
                        Text(
                            "Goals, answers and explanations are fictional. No account, network or real result is used."
                        )
                        .foregroundStyle(.secondary)
                    }
                    #if DEBUG
                        if let pendingLessonLink {
                            NativeReadingSection(title: "Shared lesson link") {
                                Text(
                                    "Non-certifying editorial pilot · \(pendingLessonLink.lessonID)"
                                )
                                Button("Continue to linked lesson", systemImage: "book") {
                                    showDeveloper = true
                                }
                                .accessibilityIdentifier("continue-to-linked-lesson")
                            }
                        }
                        NativeReadingSection(title: "Development") {
                            Button(
                                "Open the test API connector",
                                systemImage: "wrench.and.screwdriver"
                            ) {
                                showDeveloper = true
                            }
                            .frame(minHeight: 44)
                            Text(
                                "For test accounts only. This is not production sign-in."
                            )
                            .foregroundStyle(.secondary)
                        }
                    #endif
                }
                .navigationTitle("Certigo")
                .fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }
                #if DEBUG
                    .sheet(isPresented: $showDeveloper) {
                        NativeDeveloperConnector(pendingLessonLink: $pendingLessonLink)
                    }
                #endif
            }
            .onOpenURL(perform: handleIncomingURL)
            .alert("Lesson link unavailable", isPresented: $invalidLessonLink) {
                Button("OK", role: .cancel) { invalidLessonLink = false }
            } message: {
                Text("This link does not identify a supported editorial pilot lesson.")
            }
        }

        private func handleIncomingURL(_ url: URL) {
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
            @State private var model: NativeModel
            @State private var provider: MSALAuthenticationProvider?
            @State private var configurationIssue: String?
            @State private var showDemo = false

            init(pendingLessonLink: Binding<EditorialPilotLessonLink?>) {
                self._pendingLessonLink = pendingLessonLink
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
                                "Microsoft sign-in is not configured",
                                systemImage: "person.crop.circle.badge.exclamationmark",
                                description: Text(configurationIssue))
                        }
                    } else if model.profile == nil && model.deletionStage == nil {
                        NavigationStack {
                            NativeReadingPage {
                                NativeEntryHeading(
                                    title: "Make your next decision clearer.",
                                    message:
                                        "Your learning goals, practice and confirmed progress, together in Certigo."
                                )
                                NativeAppLanguagePicker()
                                NativeReadingSection(title: "Continue your learning") {
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
                                "Microsoft sign-in did not complete",
                                isPresented: Binding(
                                    get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } }
                                )
                            ) {
                                Button("OK", role: .cancel) { model.errorMessage = nil }
                            } message: {
                                Text(model.errorMessage ?? "")
                            }
                        }
                    } else {
                        NativeRoot(model: model, pendingLessonLink: $pendingLessonLink)
                    }
                }
                .onOpenURL { url in
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

            private static func safeMessage(for error: Error) -> String {
                switch error {
                case CIAMConfigurationEnvironmentError.productionBuildRequired:
                    "Microsoft sign-in is only enabled for the Distribution build."
                case CIAMConfigurationEnvironmentError.unsupportedProductionBundle:
                    "Use the existing Certigo App Store bundle identifier."
                case CIAMConfigurationEnvironmentError.missingValue(let key):
                    "Distribution is missing \(key). Configure the verified production identity before sign-in."
                case CIAMConfigurationEnvironmentError.invalidValue(let key):
                    "Distribution has an invalid \(key). Correct the verified production configuration."
                case CIAMConfigurationEnvironmentError.callbackNotDeclared:
                    "Declare the app-derived Microsoft callback in the Distribution Info.plist."
                case CIAMConfigurationEnvironmentError.callbackCollision:
                    "The Microsoft callback is duplicated in the Distribution Info.plist."
                case CIAMConfigurationEnvironmentError.redirectDoesNotMatchBundle:
                    "The Microsoft callback must match this app's bundle identifier."
                case is CIAMConfigurationEnvironmentError:
                    "Correct the Distribution Microsoft sign-in configuration."
                case is CIAMConfigurationError:
                    "The Distribution Microsoft sign-in configuration failed validation."
                default:
                    "Microsoft sign-in could not be initialized. No manual-token fallback is available."
                }
            }
        }
    #endif

    #if DEBUG
        @MainActor
        private struct NativeDeveloperConnector: View {
            @Environment(\.dismiss) private var dismiss
            @Binding private var pendingLessonLink: EditorialPilotLessonLink?
            @State private var model: NativeModel
            @State private var usesCIAM: Bool
            @State private var ciamProvider: MSALAuthenticationProvider?
            @State private var configurationIssue: String?

            init(pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil)) {
                self._pendingLessonLink = pendingLessonLink
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
                            "CIAM test sign-in is unavailable",
                            systemImage: "person.crop.circle.badge.exclamationmark",
                            description: Text(configurationIssue)
                        )
                        .accessibilityIdentifier("ciam-configuration-error")
                    } else if usesCIAM && model.profile == nil {
                        ciamSignIn
                    } else {
                        NativeRoot(model: model, pendingLessonLink: $pendingLessonLink)
                    }
                }
                .onOpenURL { url in
                    _ = ciamProvider?.handleCallback(url, sourceApplication: nil)
                }
                .safeAreaInset(edge: .top) {
                    HStack {
                        Text("Developer connector").font(.subheadline)
                        Spacer()
                        Button("Close") { dismiss() }
                    }
                    .padding()
                    .background(.background)
                }
            }

            private var ciamSignIn: some View {
                NavigationStack {
                    NativeReadingPage {
                        NativeEntryHeading(
                            title: "Test your connected learning.",
                            message: "CIAM development configuration · test accounts only.")
                        NativeReadingSection(title: "CIAM test sign-in") {
                            Text("Sign in explicitly with the locally configured test identity.")
                            NativePrimaryButton(
                                title: "Sign in with CIAM", symbol: "person.crop.circle"
                            ) {
                                Task { await model.connect() }
                            }
                            .disabled(model.busy)
                        }
                    }
                    .navigationTitle("Certigo")
                    .alert(
                        "CIAM sign-in did not complete",
                        isPresented: Binding(
                            get: { model.errorMessage != nil },
                            set: { if !$0 { model.errorMessage = nil } }
                        )
                    ) {
                        Button("OK", role: .cancel) { model.errorMessage = nil }
                    } message: {
                        Text(model.errorMessage ?? "")
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

            private static func safeConfigurationMessage(for error: Error) -> String {
                if let error = error as? CIAMConfigurationEnvironmentError {
                    return error.localizedDescription
                }
                if let error = error as? CIAMConfigurationError {
                    switch error {
                    case .invalidIdentity:
                        return
                            "Set valid client, tenant, and API audience identifiers in the local Xcode scheme."
                    case .invalidAuthority:
                        return "Correct the CIAM authority in the local Xcode scheme."
                    case .issuerMismatch:
                        return "Set the issuer matching the configured CIAM tenant and authority."
                    case .invalidAPIScope:
                        return
                            "Set one API scope for the configured audience in the local Xcode scheme."
                    case .invalidAPIURL:
                        return "Set the existing API HTTPS base URL, including its /api path."
                    case .invalidRedirect, .redirectNotRegistered:
                        return "Set the exact CIAM redirect registered for this app."
                    case .callbackNotDeclared:
                        return
                            "The callback scheme must already be declared in this app's Info.plist."
                    case .callbackCollision:
                        return "The CIAM callback scheme collides with another app callback scheme."
                    }
                }
                return
                    "Review the local Xcode scheme and registered app callback. Manual token sign-in is disabled while CIAM is opted in."
            }
        }
    #endif

    private enum DemoCatalogScenario: String, CaseIterable {
        case ready = "Available"
        case loading = "Loading"
        case empty = "Empty"
        case error = "Error"
    }

    private enum DemoSocialSection: String, CaseIterable {
        case friends = "Friends"
        case teams = "Teams"
    }

    private struct NativeDemoRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.dismiss) private var dismiss
        @AppStorage("certigo.native-design-demo.v1") private var savedState = ""
        @State private var flow = NativeDemoFlow()
        @State private var tab = NativeDemoTab.catalog
        @State private var learnSection = NativeDemoLearnSection.explore
        @State private var objectivePath: [NativeDemoRoute] = []
        @State private var catalogPath: [NativeDemoRoute] = []
        @State private var scenario = DemoCatalogScenario.ready
        @State private var offline = false
        @State private var issue: String?
        @State private var showScenarios = false
        @State private var showReset = false
        @State private var persistence = NativeDemoPersistence.awaitingRestoration
        @State private var socialSection = DemoSocialSection.friends

        var body: some View {
            TabView(selection: mainTabSelection) {
                Group {
                    if learnSection == .myLearning {
                        NavigationStack(path: $objectivePath) {
                            objective.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    } else {
                        NavigationStack(path: $catalogPath) {
                            catalog.navigationDestination(for: NativeDemoRoute.self) { route in
                                destination(for: route)
                            }
                        }
                    }
                }
                .tabItem { Label(copy.learn, systemImage: "book") }.tag(NativeDemoDestination.learn)
                NavigationStack {
                    unavailableService(
                        copy.coach, symbol: "bubble.left.and.bubble.right",
                        description:
                            "Coach is not connected in this preview. No AI response, conversation history or saved memory is created."
                    )
                }
                .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                .tag(NativeDemoDestination.coach)
                NavigationStack {
                    social
                }
                .tabItem { Label(copy.social, systemImage: "person.2") }.tag(
                    NativeDemoDestination.social)
                NavigationStack { followUp }
                    .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                    .tag(NativeDemoDestination.profile)
            }
            .tint(NativePrism.tint)
            .sheet(isPresented: $showScenarios) {
                NavigationStack {
                    Form {
                        Section(copy.appLanguage) { NativeAppLanguagePicker() }
                        Section("Catalog states · simulation") {
                            Picker("Catalog", selection: $scenario) {
                                ForEach(DemoCatalogScenario.allCases, id: \.self) {
                                    Text($0.rawValue)
                                }
                            }
                            Toggle("Simulate offline mode", isOn: $offline)
                        }
                        Section {
                            Text(
                                "These settings do not change the device network or a server."
                            )
                        }
                    }
                    .navigationTitle("Demo settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(copy[.done]) { showScenarios = false }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear only the saved demonstration?", isPresented: $showReset
            ) {
                Button("Reset the demo", role: .destructive) {
                    flow = NativeDemoFlow()
                    objectivePath = []
                    catalogPath = []
                    tab = .catalog
                    learnSection = .explore
                    scenario = .ready
                    offline = false
                    persistence.reset(&savedState)
                }
            }
            .alert("Demo restoration unavailable", isPresented: issuePresented) {
                Button(copy[.done], role: .cancel) { issue = nil }
            } message: {
                Text(issue ?? "")
            }
            .task {
                guard persistence == .awaitingRestoration else { return }
                do {
                    if let snapshot = try persistence.restore(savedState) {
                        flow = snapshot.flow
                        let navigation = snapshot.navigation
                        tab = navigation.selectedTab
                        learnSection = navigation.learnSection
                        objectivePath = navigation.objectivePath
                        catalogPath = navigation.catalogPath
                    } else {
                        learnSection = flow.objective == nil ? .explore : .myLearning
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                } catch {
                    issue =
                        "The saved demonstration cannot be read. Reset only the demo in its settings."
                }
            }
            .onChange(of: flow) { _, value in
                persistDemoSnapshot(flow: value)
            }
            .onChange(of: tab) { _, _ in persistDemoSnapshot() }
            .onChange(of: learnSection) { _, _ in persistDemoSnapshot() }
            .onChange(of: objectivePath) { _, _ in persistDemoSnapshot() }
            .onChange(of: catalogPath) { _, _ in persistDemoSnapshot() }
        }

        private var mainTabSelection: Binding<NativeDemoDestination> {
            Binding(
                get: { tab.destination },
                set: { destination in
                    tab = NativeDemoTab.selecting(destination, learnSection: learnSection)
                })
        }

        private var learnSectionSelection: Binding<NativeDemoLearnSection> {
            Binding(
                get: { learnSection },
                set: { section in
                    learnSection = section
                    tab = NativeDemoTab.selecting(.learn, learnSection: section)
                })
        }

        private var learnSelector: some View {
            Picker(copy.learn, selection: learnSectionSelection) {
                Text(copy.myLearning).tag(NativeDemoLearnSection.myLearning)
                Text(copy.explore).tag(NativeDemoLearnSection.explore)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("learn-section")
        }

        private func unavailableService(_ title: String, symbol: String, description: String)
            -> some View
        {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    ContentUnavailableView(
                        "\(title) is not connected", systemImage: symbol,
                        description: Text(description))
                    Text(
                        "This is a navigation preview, not a working \(title.lowercased()) service."
                    )
                    .foregroundStyle(.secondary)
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(title)
            .toolbar { demoToolbar }
        }

        private var social: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Picker(copy.social, selection: $socialSection) {
                        ForEach(DemoSocialSection.allCases, id: \.self) { section in
                            Text(section == .friends ? copy.friends : copy.teams).tag(section)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    ContentUnavailableView(
                        "\(socialSection == .friends ? copy.friends : copy.teams) · not connected",
                        systemImage: socialSection == .friends ? "person.2" : "person.3",
                        description: Text(
                            "Social is unavailable in this navigation preview. No real relationships, invitations, team membership or sharing are loaded."
                        ))
                    DemoPrimaryButton(title: "Return to Learn", symbol: "book") {
                        tab = NativeDemoTab.selecting(.learn, learnSection: learnSection)
                    }
                }
                .padding(20)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.social)
            .toolbar { demoToolbar }
        }

        @ViewBuilder private func destination(for route: NativeDemoRoute) -> some View {
            switch route {
            case .preparation:
                preparation
            case .exercise:
                exercise
            case .goalDetail(let goal):
                goalDetail(goal)
            }
        }

        private func persistDemoSnapshot(flow currentFlow: NativeDemoFlow? = nil) {
            guard persistence == .ready else { return }
            do {
                let flowToPersist = currentFlow ?? flow
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flowToPersist, learnSection: learnSection)
                let snapshot = try NativeDemoSnapshot.make(
                    flow: flowToPersist, navigation: navigation)
                try persistence.save(snapshot, to: &savedState)
            } catch {
                issue =
                    "The demonstration could not be saved. You can continue in the current session."
            }
        }

        private var issuePresented: Binding<Bool> {
            Binding(get: { issue != nil }, set: { if !$0 { issue = nil } })
        }

        private func resumeExercise() {
            do {
                let navigation = try NativeDemoNavigationState.make(
                    selectedTab: tab, objectivePath: objectivePath,
                    catalogPath: catalogPath, flow: flow
                ).resumingExercise(for: flow)
                objectivePath = navigation.objectivePath
                learnSection = .myLearning
                tab = navigation.selectedTab
            } catch {
                issue =
                    "The question cannot be reopened. Choose a goal in Learn > Explore."
            }
        }

        private var objective: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    learnSelector
                    if let goal = flow.objective {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(goal.displayName).font(.largeTitle.bold())
                            Text(goal.displayTitle).font(.title2.weight(.semibold))
                            Text(flow.activitySummary)
                                .font(.subheadline)
                            NavigationLink(value: flow.startRoute) {
                                Label(flow.startLabel, systemImage: "arrow.right.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .tint(.white)
                            .accessibilityIdentifier("resume-demo")
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.white)
                        .background(
                            NativePrism.objectiveFill,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The decision workshop").font(.title2.bold())
                            Text(goal.practice.intent)
                            Text(
                                "Read a situation, make a choice, understand the explanation."
                            )
                            .foregroundStyle(.secondary)
                            Label(
                                "Fictional content · not a published course",
                                systemImage: "text.book.closed"
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Divider()
                        Button("Switch goal", systemImage: "square.grid.2x2") {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                        Button("View demo history", systemImage: "clock.arrow.circlepath") {
                            tab = .followUp
                        }
                        .frame(minHeight: 44)
                    } else {
                        ContentUnavailableView(
                            "Your next learning goal",
                            systemImage: "scope",
                            description: Text(
                                "Explore two fictional situations. No account or real result is needed."
                            )
                        )
                        DemoPrimaryButton(title: copy[.chooseGoal], symbol: "arrow.right") {
                            learnSection = .explore
                            tab = .catalog
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private var catalog: some View {
            List {
                Section {
                    demoNotice
                    learnSelector
                }
                switch scenario {
                case .ready:
                    if flow.objective == nil {
                        Section {
                            Text(
                                "Choose a demo goal to begin. These French examples are fictional, not published courses."
                            )
                        }
                    }
                    Section("Demonstration workshops") {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            NavigationLink(value: NativeDemoRoute.goalDetail(goal)) {
                                HStack(spacing: 16) {
                                    Image(systemName: goal.symbol).font(.title2)
                                        .foregroundStyle(NativePrism.tint)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.displayName).font(.headline)
                                        Text(goal.displayTitle).foregroundStyle(.secondary)
                                        Text(goal.practice.intent).font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("1 fictional situation · 1 question · French")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if flow.objective == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(NativePrism.tint)
                                            .accessibilityLabel("Selected goal")
                                    }
                                }
                                .frame(minHeight: 44)
                            }
                        }
                    }
                case .loading:
                    Section {
                        ForEach(NativeDemoFlow.Objective.allCases, id: \.self) { goal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(goal.displayTitle).font(.headline)
                                Text("A situation to explore").font(.subheadline)
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityHidden(true)
                        }
                        Label("\(copy.loading) · \(copy[.demo])", systemImage: "hourglass")
                            .accessibilityIdentifier("demo-catalog-loading")
                        Button("Finish simulated loading") { scenario = .ready }
                    }
                case .empty:
                    Section {
                        ContentUnavailableView(
                            "No goals in this example", systemImage: "books.vertical",
                            description: Text("The empty catalog is a demonstration scenario.")
                        )
                        Button("Show demo goals") { scenario = .ready }
                    }
                case .error:
                    Section {
                        ContentUnavailableView(
                            "Catalog unavailable · simulation",
                            systemImage: "wifi.exclamationmark",
                            description: Text(
                                "Your demo state is preserved. No server is contacted."))
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            scenario = .ready
                        }
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.learn)
            .toolbar { demoToolbar }
        }

        private func goalDetail(_ goal: NativeDemoFlow.Objective) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    Text(goal.displayName).font(.largeTitle.bold()).foregroundStyle(
                        NativePrism.tint)
                    Text(goal.displayTitle).font(.title2.bold())
                    Text(
                        "A short scenario to explore the native experience. This is not a published catalog."
                    )
                    DemoReadingSection(title: "The decision to explore", text: goal.practice.intent)
                    DemoReadingSection(
                        title: "The fictional situation", text: goal.practice.situation)
                    Label("Read, choose, understand · no grade", systemImage: "text.bubble")
                    Label("Local demo restoration", systemImage: "clock.arrow.circlepath")
                    DemoPrimaryButton(title: copy[.chooseGoal], symbol: "scope") {
                        flow.choose(goal)
                        learnSection = .myLearning
                        catalogPath = []
                        objectivePath = []
                        tab = .objective
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Goal overview").navigationBarTitleDisplayMode(.inline)
        }

        private var preparation: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(progress: NativeDemoPracticeProgress(current: .situation))
                        Text(practice.title).font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        DemoReadingSection(title: "The situation", text: practice.situation)
                        DemoReadingSection(title: "Your task", text: practice.intent)
                        Divider()
                        DemoReadingSection(
                            title: "Before you choose",
                            text:
                                "Identify what the team wants to manage and what it wants to delegate. Focus on that boundary, not a provider name."
                        )
                        DemoPrimaryButton(title: "Open the question", symbol: "arrow.right") {
                            objectivePath = [.exercise]
                        }
                        .accessibilityIdentifier("demo-open-question")
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("Preparation").navigationBarTitleDisplayMode(.inline)
            .toolbar { demoToolbar }
        }

        private var exercise: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoNotice
                    if let practice = flow.practice {
                        DemoPracticeTrail(
                            progress: NativeDemoPracticeProgress(
                                current: flow.phase == .reviewed ? .explanation : .decision))
                        switch flow.phase {
                        case .answering:
                            Label(
                                flow.selection == nil
                                    ? "Choose an answer" : "Answer selected",
                                systemImage: flow.selection == nil
                                    ? "circle" : "checkmark.circle.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                flow.selection == nil ? Color.secondary : NativePrism.tint
                            )
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-answer-state")
                            Text(practice.title).font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(practice.situation).textSelection(.enabled)
                            Text(practice.question)
                                .font(.title3.weight(.semibold))
                                .accessibilityAddTraits(.isHeader)
                            VStack(spacing: 12) {
                                ForEach(Array(NativeDemoFlow.options.enumerated()), id: \.offset) {
                                    index, option in
                                    Button {
                                        flow.select(index)
                                    } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Image(
                                                systemName: flow.selection == index
                                                    ? "checkmark.circle.fill" : "circle")
                                            Text(option).multilineTextAlignment(.leading)
                                            Spacer(minLength: 0)
                                        }
                                        .frame(
                                            maxWidth: .infinity, minHeight: 44, alignment: .leading
                                        )
                                        .padding(12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(
                                        flow.selection == index ? NativePrism.tint : .primary
                                    )
                                    .background(
                                        Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                flow.selection == index
                                                    ? NativePrism.tint : Color(uiColor: .separator),
                                                lineWidth: flow.selection == index ? 2 : 1)
                                    }
                                    .accessibilityAddTraits(
                                        flow.selection == index ? .isSelected : []
                                    )
                                    .accessibilityLabel(option)
                                    .accessibilityValue(
                                        flow.selection == index
                                            ? "Selected" : "Not selected"
                                    )
                                    .accessibilityIdentifier("demo-option-\(index)")
                                }
                            }
                            Text("You can change your choice before the simulated submission.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: "\(copy.submitAnswer) · \(copy[.demo])", symbol: "paperplane"
                            ) {
                                flow.submit()
                            }
                            .disabled(!flow.canSubmit)
                            .accessibilityHint("Choose an answer before continuing.")
                            .accessibilityIdentifier("demo-submit")
                        case .pending:
                            Label {
                                Text("\(copy.pending) · \(copy[.demo])")
                            } icon: {
                                Image(systemName: "clock.fill").foregroundStyle(.orange)
                            }
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-pending-state")
                            Text("Your choice is saved in the demo.")
                                .font(.headline)
                            selectedAnswer
                            Text(
                                "No verdict, score or reward is calculated on this device."
                            )
                            if offline {
                                Label(
                                    "\(copy[.offline]) · \(copy[.demo])", systemImage: "wifi.slash")
                                Text(
                                    "The demo answer remains pending. The offline scenario pauses the next simulation step."
                                )
                                DemoPrimaryButton(
                                    title: "Turn off the offline scenario",
                                    symbol: "wifi"
                                ) { offline = false }
                            } else {
                                Text(
                                    "The next action simulates a server response. It does not contact an API."
                                )
                                DemoPrimaryButton(
                                    title: "Simulate the fictional explanation",
                                    symbol: "text.bubble"
                                ) {
                                    flow.receiveMockExplanation(offline: offline)
                                }
                                .accessibilityIdentifier("demo-receive-mock")
                            }
                        case .reviewed:
                            Label(
                                "Fictional explanation · no verdict",
                                systemImage: "text.bubble"
                            )
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("demo-explanation-state")
                            selectedAnswer
                            DemoReadingSection(
                                title: "The decisive constraint", text: practice.constraint)
                            DemoReadingSection(
                                title: "Understanding the decision", text: practice.explanation)
                            DemoResponsibilities(rows: practice.responsibilities)
                            DemoTakeaway(text: practice.takeaway)
                            Text(
                                "This is a design fixture, not the correction of a published question. It appears for every choice: the demo gives no verdict or score."
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                            DemoPrimaryButton(
                                title: copy.progressAndHistory,
                                symbol: "arrow.right"
                            ) { tab = .followUp }
                            Button(
                                "Practice the demo question again",
                                systemImage: "arrow.counterclockwise"
                            ) {
                                flow.restartQuestion()
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Practice · demo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                }
            }
        }

        private var selectedAnswer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your demo choice").font(.headline)
                if let selection = flow.selection {
                    Text(NativeDemoFlow.options[selection])
                }
            }
            .accessibilityElement(children: .combine)
        }

        private var followUp: some View {
            List {
                Section {
                    demoNotice
                    Text("Preview profile").font(.title2.bold())
                    Text("No account is signed in. This screen shows only the local demonstration.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink {
                        demoHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(minHeight: 44)
                    }
                    NavigationLink {
                        List {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section("Demonstration controls") {
                                Button("Preview states & offline simulation") {
                                    showScenarios = true
                                }
                                .frame(minHeight: 44)
                                Button("Reset the demo", role: .destructive) { showReset = true }
                                    .frame(minHeight: 44)
                            }
                            Section("Appearance & accessibility") {
                                Text(
                                    "The preview follows system appearance and text size. Navigation uses system transitions and controls respect Reduce Transparency."
                                )
                            }
                            Section("Account") {
                                Text(
                                    "Account, privacy and notification settings are not connected in this preview. No account preferences are changed."
                                )
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.profile)
            .toolbar { demoToolbar }
        }

        private var demoHistory: some View {
            List {
                Section { demoNotice }
                Section("Demo history") {
                    if let goal = flow.objective {
                        Text(goal.displayTitle).font(.headline)
                        Button(action: resumeExercise) {
                            Label(copy.resume, systemImage: flow.phase.symbol)
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("resume-demo-follow-up")
                        Text(flow.activitySummary)
                        if flow.phase == .reviewed {
                            Text(goal.practice.takeaway)
                        }
                        Text("This saved demonstration is not certification progress.")
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            copy[.chooseGoal], systemImage: "scope",
                            description: Text(copy[.noHistory]))
                        Button(copy[.chooseGoal]) {
                            learnSection = .explore
                            tab = .catalog
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(copy.progressAndHistory)
            .toolbar { demoToolbar }
        }

        private struct DemoReadingSection: View {
            let title: String
            let text: String

            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                    Text(text).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private struct DemoPracticeTrail: View {
            let progress: NativeDemoPracticeProgress

            var body: some View {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { steps }
                    VStack(alignment: .leading, spacing: 8) { steps }
                }
                .font(.subheadline)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(progress.accessibilityLabel)
            }

            @ViewBuilder private var steps: some View {
                ForEach(NativeDemoPracticeStage.allCases, id: \.self) { step in
                    let state = progress.state(for: step)
                    Label(
                        step.rawValue,
                        systemImage: state.symbol
                    )
                    .foregroundStyle(state == .current ? NativePrism.tint : Color.secondary)
                    .fontWeight(state == .current ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private struct DemoTakeaway: View {
            let text: String

            var body: some View {
                GroupBox {
                    Text(text)
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } label: {
                    Label("Takeaway", systemImage: "lightbulb")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }

        private struct DemoResponsibilities: View {
            let rows: [NativeDemoPractice.Responsibility]

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Who manages what?").font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(rows, id: \.layer) { row in
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.layer).font(.subheadline.weight(.semibold))
                            Text(row.owner)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }

        private var demoNotice: some View {
            VStack(alignment: .leading, spacing: 4) {
                Label("Demo · fictional data and results", systemImage: "testtube.2")
                Text("Learning examples: French").font(.caption)
            }
            .font(.subheadline).foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("synthetic-demo-notice")
        }

        @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Demo settings", systemImage: "slider.horizontal.3") {
                        showScenarios = true
                    }
                    Button(
                        "Reset the demo", systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showReset = true
                    }
                } label: {
                    Label("Demo options", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private struct DemoPrimaryButton: View {
        let title: String
        let symbol: String
        let action: () -> Void

        var body: some View {
            NativePrimaryButton(title: title, symbol: symbol, action: action)
        }
    }

    #Preview("Learn · demonstration") { NativeDemoRoot() }
#endif

// A demo-only state machine: no API identity, scoring, answer keys, rewards or production progress.
struct NativeDemoFlow: Codable, Equatable {
    enum Objective: String, Codable, CaseIterable {
        case fundamentals = "Cloud · découverte"
        case operations = "Cloud · exploitation"

        var displayName: String {
            switch self {
            case .fundamentals: "Cloud · discovery"
            case .operations: "Cloud · operations"
            }
        }
        var displayTitle: String {
            switch self {
            case .fundamentals: "Cloud fundamentals"
            case .operations: "Cloud services in practice"
            }
        }
        var title: String {
            switch self {
            case .fundamentals: "Les fondamentaux du cloud"
            case .operations: "Les services cloud au quotidien"
            }
        }
        var symbol: String {
            switch self {
            case .fundamentals: "cloud"
            case .operations: "server.rack"
            }
        }
        var practice: NativeDemoPractice {
            switch self {
            case .fundamentals: .fundamentals
            case .operations: .operations
            }
        }
    }
    enum Phase: String, Codable {
        case answering, pending, reviewed
        var symbol: String {
            switch self {
            case .answering: "circle"
            case .pending: "clock"
            case .reviewed: "text.bubble"
            }
        }
    }
    enum InvalidSnapshot: Error { case inconsistentState }
    static let options = [
        "Une infrastructure à administrer (IaaS)",
        "Une plateforme gérée (PaaS)", "Un logiciel prêt à l’emploi (SaaS)",
    ]
    private(set) var objective: Objective?
    private(set) var selection: Int?
    private(set) var phase = Phase.answering

    var canSubmit: Bool { objective != nil && selection != nil && phase == .answering }
    var practice: NativeDemoPractice? { objective?.practice }
    var startRoute: NativeDemoRoute {
        phase == .answering && selection == nil ? .preparation : .exercise
    }
    var startLabel: String {
        startRoute == .preparation ? "Explore the situation" : resumeLabel
    }
    var activitySummary: String {
        switch phase {
        case .answering:
            selection == nil
                ? "A situation to explore · no grade"
                : "An editable choice · not submitted"
        case .pending: "Demo answer pending · no confirmed result"
        case .reviewed: "Fictional explanation available · no verdict"
        }
    }
    var resumeLabel: String {
        switch phase {
        case .answering: selection == nil ? "Start a question" : "Resume your choice"
        case .pending: "Resume the pending answer"
        case .reviewed: "Read the fictional explanation again"
        }
    }
    mutating func choose(_ objective: Objective) {
        guard self.objective != objective else { return }
        self.objective = objective
        restartQuestion()
    }
    mutating func select(_ index: Int) {
        guard objective != nil, phase == .answering, Self.options.indices.contains(index) else {
            return
        }
        selection = index
    }
    mutating func submit() {
        guard canSubmit else { return }
        phase = .pending
    }
    mutating func receiveMockExplanation(offline: Bool) {
        guard phase == .pending, !offline else { return }
        phase = .reviewed
    }
    mutating func restartQuestion() {
        selection = nil
        phase = .answering
    }
    static func restore(_ data: Data) throws -> Self {
        let flow = try JSONDecoder().decode(Self.self, from: data)
        guard flow.selection.map({ options.indices.contains($0) }) ?? true,
            flow.objective != nil || (flow.selection == nil && flow.phase == .answering),
            flow.phase == .answering || flow.selection != nil
        else {
            throw InvalidSnapshot.inconsistentState
        }
        return flow
    }
}

enum NativeDemoPracticeStage: String, CaseIterable {
    case situation = "Situation"
    case decision = "Decision"
    case explanation = "Explanation"

    var position: Int {
        switch self {
        case .situation: 1
        case .decision: 2
        case .explanation: 3
        }
    }
}

enum NativeDemoPracticeStepState: Equatable {
    case completed, current, upcoming

    var symbol: String {
        switch self {
        case .completed: "circle.fill"
        case .current: "circle.inset.filled"
        case .upcoming: "circle"
        }
    }
}

struct NativeDemoPracticeProgress {
    let current: NativeDemoPracticeStage

    func state(for stage: NativeDemoPracticeStage) -> NativeDemoPracticeStepState {
        if stage == current { return .current }
        return stage.position < current.position ? .completed : .upcoming
    }

    var accessibilityLabel: String {
        let stageCount = NativeDemoPracticeStage.allCases.count
        return "Stage \(current.position) of \(stageCount): \(current.rawValue). "
            + "Stages describe the learning flow, not whether an answer is correct."
    }
}

struct NativeDemoPractice: Sendable {
    struct Responsibility: Sendable {
        let layer: String
        let owner: String
    }
    let title: String
    let intent: String
    let situation: String
    let question: String
    let constraint: String
    let explanation: String
    let takeaway: String
    let responsibilities: [Responsibility]

    static let fundamentals = Self(
        title: "Déployer sans gérer les serveurs",
        intent: "Distinguer une plateforme gérée d’une infrastructure à administrer.",
        situation:
            "L’équipe Exemple veut déployer son application sans administrer le système d’exploitation des serveurs. Elle souhaite garder la responsabilité de son code et de ses données.",
        question: "Quel modèle de service correspond à cette situation fictive ?",
        constraint:
            "L’équipe veut déléguer l’administration du système d’exploitation, pas son application.",
        explanation:
            "Dans cet exemple inventé, une plateforme gérée (PaaS) correspond à cette limite : le fournisseur prend en charge la plateforme et son système. L’équipe déploie son code. Une infrastructure (IaaS) lui laisserait la gestion du système ; un logiciel prêt à l’emploi (SaaS) ne lui fournit pas le même cadre pour déployer son application.",
        takeaway:
            "Le critère utile est la responsabilité conservée par l’équipe, pas seulement la présence de serveurs dans le cloud.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Exemple"),
            .init(
                layer: "Plateforme et système d’exploitation",
                owner: "Le fournisseur, dans cet exemple PaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])

    static let operations = Self(
        title: "Garder la main sur le système",
        intent: "Identifier ce qui reste à administrer dans une infrastructure cloud.",
        situation:
            "L’équipe Atelier exploite une application qui exige une configuration particulière du système d’exploitation. Elle veut installer ses composants système et gérer elle-même les mises à jour, sans entretenir de serveurs physiques.",
        question:
            "Quel modèle de service lui laisse cette responsabilité dans ce scénario fictif ?",
        constraint:
            "L’équipe veut conserver le contrôle du système d’exploitation tout en déléguant le matériel.",
        explanation:
            "Dans cet exemple inventé, une infrastructure à administrer (IaaS) laisse à l’équipe le choix et la gestion du système d’exploitation. Le fournisseur prend en charge le matériel. Une plateforme gérée (PaaS) ou un logiciel prêt à l’emploi (SaaS) ne lui donnent pas cette même responsabilité système.",
        takeaway:
            "Déléguer le matériel ne signifie pas déléguer les mises à jour du système : la frontière dépend du modèle choisi.",
        responsibilities: [
            .init(layer: "Application et données", owner: "L’équipe Atelier"),
            .init(
                layer: "Système d’exploitation et mises à jour",
                owner: "L’équipe Atelier, dans cet exemple IaaS"),
            .init(layer: "Infrastructure physique", owner: "Le fournisseur"),
        ])
}

enum NativeDemoDestination: String, CaseIterable, Hashable {
    case learn, coach, social, profile
}

enum NativeDemoLearnSection: String, Codable {
    case myLearning, explore
}

// Retain version-one storage identifiers; visible destinations use the approved English names.
enum NativeDemoTab: String, Codable, CaseIterable, Hashable {
    case objective, catalog, followUp, coach, social

    var destination: NativeDemoDestination {
        switch self {
        case .objective, .catalog: .learn
        case .followUp: .profile
        case .coach: .coach
        case .social: .social
        }
    }

    static func selecting(
        _ destination: NativeDemoDestination, learnSection: NativeDemoLearnSection
    ) -> Self {
        switch destination {
        case .learn: learnSection == .myLearning ? .objective : .catalog
        case .coach: .coach
        case .social: .social
        case .profile: .followUp
        }
    }
}

enum NativeDemoRoute: Codable, Equatable, Hashable {
    case preparation
    case exercise
    case goalDetail(NativeDemoFlow.Objective)
}

struct NativeDemoNavigationState: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, inconsistentRoute }
    private static let maximumEncodedBytes = 4_096

    let selectedTab: NativeDemoTab
    let objectivePath: [NativeDemoRoute]
    let catalogPath: [NativeDemoRoute]
    let learnSection: NativeDemoLearnSection

    init(
        selectedTab: NativeDemoTab, objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute], learnSection: NativeDemoLearnSection? = nil
    ) {
        self.selectedTab = selectedTab
        self.objectivePath = objectivePath
        self.catalogPath = catalogPath
        self.learnSection = learnSection ?? (selectedTab == .catalog ? .explore : .myLearning)
    }

    private enum CodingKeys: String, CodingKey {
        case selectedTab, objectivePath, catalogPath, learnSection
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedTab: try values.decode(NativeDemoTab.self, forKey: .selectedTab),
            objectivePath: try values.decode([NativeDemoRoute].self, forKey: .objectivePath),
            catalogPath: try values.decode([NativeDemoRoute].self, forKey: .catalogPath),
            learnSection: try values.decodeIfPresent(
                NativeDemoLearnSection.self, forKey: .learnSection))
    }

    static func make(
        selectedTab: NativeDemoTab,
        objectivePath: [NativeDemoRoute],
        catalogPath: [NativeDemoRoute],
        flow: NativeDemoFlow,
        learnSection: NativeDemoLearnSection? = nil
    ) throws -> Self {
        let state = Self(
            selectedTab: selectedTab, objectivePath: objectivePath, catalogPath: catalogPath,
            learnSection: learnSection)
        try state.validate(for: flow)
        return state
    }

    static func restore(_ data: Data, for flow: NativeDemoFlow) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let state = try JSONDecoder().decode(Self.self, from: data)
        try state.validate(for: flow)
        return state
    }

    func resumingExercise(for flow: NativeDemoFlow) throws -> Self {
        try Self.make(
            selectedTab: .objective, objectivePath: [.exercise],
            catalogPath: catalogPath, flow: flow)
    }

    private func validate(for flow: NativeDemoFlow) throws {
        let objectiveRoutesAreValid =
            objectivePath.count <= 1
            && objectivePath.allSatisfy { $0 == .exercise || $0 == .preparation }
            && (objectivePath.isEmpty || flow.objective != nil)
        let catalogRoutesAreValid =
            catalogPath.count <= 1
            && catalogPath.allSatisfy {
                if case .goalDetail = $0 { true } else { false }
            }
        let sectionMatchesTab =
            (selectedTab != .objective || learnSection == .myLearning)
            && (selectedTab != .catalog || learnSection == .explore)
        guard objectiveRoutesAreValid, catalogRoutesAreValid, sectionMatchesTab else {
            throw InvalidSnapshot.inconsistentRoute
        }
    }
}

enum NativeDemoPersistence {
    case awaitingRestoration, ready, preservingRejectedSnapshot

    mutating func restore(_ savedState: String) throws -> NativeDemoSnapshot? {
        self = .preservingRejectedSnapshot
        let snapshot =
            savedState.isEmpty ? nil : try NativeDemoSnapshot.restore(Data(savedState.utf8))
        self = .ready
        return snapshot
    }

    func save(_ snapshot: NativeDemoSnapshot, to savedState: inout String) throws {
        guard self == .ready else { return }
        savedState = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
    }

    mutating func reset(_ savedState: inout String) {
        savedState = ""
        self = .ready
    }
}

struct NativeDemoSnapshot: Codable, Equatable {
    enum InvalidSnapshot: Error { case tooLarge, unsupportedSchema }

    private static let maximumEncodedBytes = 8_192
    let schema: Int
    let flow: NativeDemoFlow
    let navigation: NativeDemoNavigationState

    static func make(
        flow: NativeDemoFlow, navigation: NativeDemoNavigationState
    ) throws -> Self {
        let validatedNavigation = try NativeDemoNavigationState.make(
            selectedTab: navigation.selectedTab,
            objectivePath: navigation.objectivePath,
            catalogPath: navigation.catalogPath,
            flow: flow, learnSection: navigation.learnSection)
        return Self(schema: 1, flow: flow, navigation: validatedNavigation)
    }

    static func restore(_ data: Data) throws -> Self {
        guard data.count <= maximumEncodedBytes else {
            throw InvalidSnapshot.tooLarge
        }
        let decoder = JSONDecoder()
        do {
            let snapshot = try decoder.decode(Self.self, from: data)
            guard snapshot.schema == 1 else {
                throw InvalidSnapshot.unsupportedSchema
            }
            return try make(flow: snapshot.flow, navigation: snapshot.navigation)
        } catch DecodingError.keyNotFound(let key, _) where key.stringValue == "schema" {
            let legacyFlow = try NativeDemoFlow.restore(data)
            let legacyNavigation = try NativeDemoNavigationState.make(
                selectedTab: legacyFlow.objective == nil ? .catalog : .objective,
                objectivePath: [], catalogPath: [], flow: legacyFlow)
            return try make(flow: legacyFlow, navigation: legacyNavigation)
        }
    }
}

#if canImport(SwiftUI)
    private struct NativeAccountDeletionView: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Bindable var model: NativeModel
        @Environment(\.dismiss) private var dismiss
        @Environment(\.scenePhase) private var scenePhase
        private enum Focus: Hashable { case status, error }
        @AccessibilityFocusState private var focused: Focus?

        var body: some View {
            Form {
                Section {
                    Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($focused, equals: .status)
                    if model.deletionBusy { ProgressView(copy.loading) }
                    if let message = model.deletionMessage {
                        Text(message).accessibilityIdentifier("account-deletion-message")
                            .accessibilityFocused($focused, equals: .error)
                    }
                }
                if [.explanation, .verifying, .confirmation].contains(
                    model.deletionStage ?? .explanation)
                {
                    Section("Before you continue") {
                        Text(
                            "Permanently delete your Certigo account, confirmed learning and progression. Local drafts and downloaded account references are removed only after the server confirms completion."
                        )
                        Text(
                            "This is irreversible. There is no cancellation endpoint after submission. Residual production backups may rotate for up to 30 days, a pseudonymous tombstone remains for 30 days and identity-free deletion audit logs for 90 days. These are not an undo period."
                        )
                        if model.canReauthenticateForDeletion {
                            Button(
                                "Continue to verify identity",
                                systemImage: "person.badge.shield.checkmark"
                            ) {
                                Task { await model.verifyDeletionIdentity() }
                            }
                            .disabled(model.deletionBusy)
                        } else {
                            Text(
                                "Remote deletion requires configured Microsoft sign-in. It is unavailable for the demo and manual development connector."
                            )
                        }
                    }
                } else if model.deletionStage == .pending || model.deletionStage == .unconfirmed
                    || model.deletionStage == .checking
                {
                    Section("Server status") {
                        if let status = model.deletionStatus, status.status == .pending {
                            Text(
                                "\(status.completedSteps) of \(status.totalSteps) server steps confirmed."
                            )
                            Text(
                                "Deletion is pending, not completed. Learning is paused and local data is retained. Status checks do not advance unfinished deletion steps."
                            )
                            if status.retryAfterSeconds != nil {
                                Text(
                                    "The server requested a retry delay. Refresh status before retrying if the action is not available yet."
                                )
                            }
                        }
                        Button("Check status", systemImage: "arrow.clockwise") {
                            Task { await model.refreshDeletionStatus() }
                        }
                        .disabled(model.deletionBusy)
                        Button(
                            "Sign in to check the same account", systemImage: "person.crop.circle"
                        ) {
                            Task { await model.recoverDeletionConnection(interactive: true) }
                        }
                        .disabled(model.deletionBusy)
                        Button(copy.retry, role: .destructive) {
                            Task { await model.retryAccountDeletion() }
                        }
                        .disabled(!model.canRetryDeletion)
                        if model.deletionStatus?.status == .notRequested {
                            Button("Resume account to verify identity") {
                                Task { await model.resumeAccountAfterStatusCheck() }
                            }
                            .disabled(model.deletionBusy)
                        }
                    }
                } else if model.deletionStage == .cleanupFailed {
                    Section {
                        Text(
                            "\(copy.confirmed). Cleanup on this device is not complete."
                        )
                        Button(copy.retry, systemImage: "arrow.clockwise") {
                            Task { await model.retryDeletionCleanup() }
                        }
                        .disabled(model.deletionBusy)
                    }
                } else if model.deletionStage == .completed {
                    Section {
                        Text(
                            "The server confirmed account deletion and this device confirmed local cleanup. Residual retention periods still apply."
                        )
                        Button("Return to sign-in") { model.acknowledgeAccountDeletion() }
                    }
                }
            }
            .navigationTitle(copy.accountDeletion)
            .navigationBarBackButtonHidden(model.deletionBusy || !model.canCancelDeletion)
            .toolbar {
                if model.canCancelDeletion {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy[.cancel]) {
                            Task {
                                await model.cancelAccountDeletion()
                                if model.deletionStage == nil { dismiss() }
                            }
                        }
                    }
                }
            }
            .alert(
                "Permanently delete this Certigo account?",
                isPresented: Binding(
                    get: { model.deletionStage == .confirmation },
                    set: { _ in })
            ) {
                Button(copy[.deleteAccount], role: .destructive) {
                    Task { await model.confirmAccountDeletion() }
                }
                Button(copy[.cancel], role: .cancel) { model.discardDeletionProof() }
            } message: {
                Text(
                    "Microsoft verified the same account. Only Delete account submits the irreversible request. Completion may require retries."
                )
            }
            .onChange(of: model.deletionStage) { _, _ in focused = .status }
            .onChange(of: model.deletionMessage) { _, message in
                focused = message == nil ? .status : .error
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.discardDeletionProof() }
            }
            .onAppear { if model.deletionStage == nil { model.showAccountDeletion() } }
            .onDisappear {
                model.discardDeletionProof()
                if model.canCancelDeletion { Task { await model.cancelAccountDeletion() } }
            }
        }

        private var title: String {
            switch model.deletionStage {
            case .verifying: "Verify your Microsoft identity"
            case .confirmation: "Identity verified"
            case .checking: "Checking account deletion"
            case .pending: "Deletion pending"
            case .unconfirmed: "Account status unconfirmed"
            case .cleanupFailed: "Local cleanup requires attention"
            case .completed: "Account deleted"
            default: "Delete your Certigo account"
            }
        }
    }

    private struct NativeRoot: View {
        @Environment(\.nativeInterfaceCopy) private var copy
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @Bindable var model: NativeModel
        @Binding var pendingLessonLink: EditorialPilotLessonLink?
        @State private var selectedTrack: String?
        @State private var selectedLesson: String?
        @State private var savingGoalID: String?
        @State private var navigation = NativeLearningNavigation()
        @State private var columns: NavigationSplitViewVisibility = .automatic
        @State private var compactColumn: NavigationSplitViewColumn = .sidebar
        @State private var showEditorialPilot = false
        @State private var requestedLessonID: String?
        @State private var loadingTrackID: String?
        @State private var loadingPathRequestID: UUID?
        @State private var loadingLessonID: String?
        @State private var loadingLessonRequestID: UUID?
        @State private var downloadTrack: Track?
        @State private var catalogFilter = NativeCatalogFilter()
        @State private var resumeTrackID: String?

        init(
            model: NativeModel,
            pendingLessonLink: Binding<EditorialPilotLessonLink?> = .constant(nil)
        ) {
            self.model = model
            self._pendingLessonLink = pendingLessonLink
        }

        var body: some View {
            Group {
                if model.requiresDeletionSurface {
                    NavigationStack { NativeAccountDeletionView(model: model) }
                } else if model.profile == nil {
                    connection
                } else {
                    TabView(selection: $model.selectedTab) {
                        learning
                            .tabItem { Label(copy.learn, systemImage: "book") }
                            .tag(NativeResumeState.Tab.learn)
                        NavigationStack {
                            coach
                        }
                        .tabItem { Label(copy.coach, systemImage: "bubble.left.and.bubble.right") }
                        .tag(NativeResumeState.Tab.coach)
                        NavigationStack {
                            NativeReadingPage {
                                Picker(copy.social, selection: $navigation.social) {
                                    Text(copy.friends).tag(NativeLearningNavigation.Social.friends)
                                    Text(copy.teams).tag(NativeLearningNavigation.Social.teams)
                                }
                                .pickerStyle(.menu)
                                ContentUnavailableView(
                                    navigation.social == .friends
                                        ? "Friends are not connected"
                                        : "Teams are not connected",
                                    systemImage: "person.2",
                                    description: Text(
                                        "Invitations, sharing and group activity are not available. No relationships are created here."
                                    ))
                                NativeReadingSection(title: "Private learning comes first") {
                                    Text(
                                        "Your Profile is your private learning record, not a friend profile."
                                    )
                                    Text(
                                        "Detailed results, mistakes, readiness and Coach context are not published by visiting Social."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                NativeReadingSection(
                                    title: navigation.social == .friends
                                        ? "Friends · not active" : "Teams · not active"
                                ) {
                                    Text(
                                        navigation.social == .friends
                                            ? "Friend discovery, invitations and shared profiles are not enabled. No contacts are uploaded and no invitations are sent."
                                            : "Team membership, roles, invitations and challenges are not enabled. A shared team would not grant access to private results or readiness."
                                    )
                                    Text(
                                        "Any future sharing needs a separate, explicit opt-in with a preview of the content and audience. No sharing controls are active here."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                Button("Return to learning", systemImage: "book") {
                                    model.selectedTab = .learn
                                }
                                .frame(minHeight: 44)
                            }
                            .navigationTitle(copy.social)
                        }
                        .tabItem { Label(copy.social, systemImage: "person.2") }
                        .tag(NativeResumeState.Tab.social)
                        NavigationStack { profile }
                            .tabItem { Label(copy.profile, systemImage: "person.crop.circle") }
                            .tag(NativeResumeState.Tab.profile)
                    }
                }
            }
            .onChange(of: model.profile?.id, initial: true) { _, owner in
                navigation = NativeLearningNavigation(hasGoal: model.profile?.activeTrackId != nil)
                selectedTrack = nil
                selectedLesson = nil
                catalogFilter.clear()
                resumeTrackID = nil
                columns = .automatic
                compactColumn = .sidebar
                loadingTrackID = nil
                loadingPathRequestID = nil
                loadingLessonID = nil
                loadingLessonRequestID = nil
                if owner == nil { savingGoalID = nil }
            }
            .onChange(of: model.restorationRevision) { _, _ in
                selectedTrack = model.path?.trackId ?? model.offlinePack?.trackId
                selectedLesson = model.lesson?.id
                if model.lesson != nil {
                    columns = .detailOnly
                    compactColumn = .detail
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.busy {
                    ProgressView(
                        savingGoalID == nil ? copy.loading : "Saving active goal…"
                    )
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        if reduceTransparency {
                            NativePrism.surface
                        } else {
                            Rectangle().fill(.regularMaterial)
                        }
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(NativePrism.edge).frame(height: 1)
                            .accessibilityHidden(true)
                    }
                }
            }
            .alert(
                "Operation not confirmed",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .task { await model.restore() }
            .sheet(isPresented: $showEditorialPilot) {
                NativeEditorialPilotView(
                    model: model,
                    requestedLessonID: requestedLessonID
                )
            }
        }

        private var coach: some View {
            NativeReadingPage {
                NativeReadingSection(title: "Help for your learning") {
                    Label(
                        "AI assistance is not active", systemImage: "bubble.left.and.bubble.right"
                    )
                    .font(.headline)
                    Text(
                        "No chat, AI generation, conversation history or saved Coach memory is enabled in this client."
                    )
                    .foregroundStyle(.secondary)
                }
                NativeReadingSection(title: "Current learning context") {
                    if let goal = model.profile?.activeTrackId {
                        LabeledContent("Confirmed goal", value: trackTitle(goal))
                    } else {
                        Text("No active goal is confirmed.")
                    }
                    if let lesson = model.lesson {
                        Text(lesson.title).font(.headline)
                        Text(coachPhase)
                    }
                    Text(
                        "This context is shown on this device, not sent to an AI service. A future assistant must distinguish unanswered questions, pending correction and authorized feedback."
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Button("Choose context in Learn", systemImage: "book") {
                        model.selectedTab = .learn
                    }
                    .frame(minHeight: 44)
                }
                NativeReadingSection(title: "What scoped help could support") {
                    Text("Explain a concept · Help me plan · Review a difficulty")
                    Text(
                        "These are intentions, not active prompts. There is no composer, hidden memory or automatic goal change. The server remains authoritative for correction, readiness and XP."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(copy.coach)
        }

        private var coachPhase: String {
            switch model.outcome {
            case .pendingCorrection: copy[.pendingCorrection]
            case .corrected: copy.confirmed
            case nil: "Answer selection · no confirmed result shown"
            }
        }

        private var visibleTracks: [Track] {
            model.tracks.filter {
                navigation.showsTrack(
                    $0.id, activeID: model.profile?.activeTrackId, openedID: selectedTrack)
                    && (navigation.learn != .explore
                        || catalogFilter.includes(
                            code: $0.code, title: $0.title, summary: $0.summary,
                            available: $0.learningAvailable))
            }
        }

        private var catalogFamilies: [String] {
            Set(model.tracks.map { NativeCatalogFilter.family(for: $0.code) })
                .filter { !$0.isEmpty }.sorted()
        }

        private var learning: some View {
            NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn)
            {
                List(selection: $selectedTrack) {
                    Section {
                        Picker(copy.learn, selection: $navigation.learn) {
                            Text(copy.myLearning).tag(NativeLearningNavigation.Learn.myLearning)
                            Text(copy.explore).tag(NativeLearningNavigation.Learn.explore)
                        }
                        .pickerStyle(.menu)
                    }
                    if navigation.learn == .myLearning {
                        Section {
                            confirmedGoal
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        myLearningPlan
                    } else {
                        Section {
                            Text("Find your next learning goal.")
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text(
                                "Explore certifications. Your active goal changes only when you choose it."
                            )
                            .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.clear)
                        Section("Find a certification") {
                            Picker("Code family", selection: $catalogFilter.family) {
                                Text("All code families").tag("")
                                ForEach(catalogFamilies, id: \.self) { family in
                                    Text("\(family) certifications").tag(family)
                                }
                            }
                            Toggle("Available practice only", isOn: $catalogFilter.availableOnly)
                            Text(
                                "Searches the loaded catalog on this device. Code families are not provider metadata. Language and format filters are unavailable because the catalog does not declare them."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            Text("\(visibleTracks.count) of \(model.tracks.count) certifications")
                                .font(.subheadline)
                            if catalogFilter.isActive {
                                Button("Clear filters", systemImage: "xmark.circle") {
                                    catalogFilter.clear()
                                }
                            }
                        }
                    }
                    Section("Continue on this device") {
                        if let lesson = model.lesson,
                            navigation.learn == .explore
                                || lesson.trackId.lowercased()
                                    != model.profile?.activeTrackId?.lowercased()
                        {
                            Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        Button("Restore downloaded activity", systemImage: "internaldrive") {
                            Task { await model.restoreDownloadedActivity() }
                        }
                        .disabled(model.busy)
                        if navigation.learn == .myLearning && model.profile?.activeTrackId == nil {
                            Text(
                                "Choose an active goal in Explore. Browsing never changes your goal."
                            )
                            Button(copy.explore) { navigation.learn = .explore }
                        }
                    }
                    Section("Guided reading") {
                        Button("Assistants IA responsables", systemImage: "text.book.closed") {
                            requestedLessonID = nil
                            showEditorialPilot = true
                        }
                        Text("French editorial pilot · estimated 18 minutes · not a certification.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let pendingLessonLink {
                        Section("Shared lesson link") {
                            Text("Editorial pilot · \(pendingLessonLink.lessonID)")
                            Button("Open linked lesson", systemImage: "arrow.up.right.square") {
                                requestedLessonID = pendingLessonLink.lessonID
                                self.pendingLessonLink = nil
                                showEditorialPilot = true
                            }
                            .disabled(model.busy)
                            .accessibilityIdentifier("open-linked-editorial-lesson")
                        }
                    }
                    Section(
                        navigation.learn == .explore
                            ? "Certification collection" : "Your learning goals"
                    ) {
                        ForEach(visibleTracks) { track in
                            NavigationLink(value: track.id) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(track.code, systemImage: "books.vertical")
                                        .symbolRenderingMode(.hierarchical)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(NativePrism.accent(for: track.code))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            NativePrism.surface,
                                            in: Capsule(style: .continuous))
                                    Text(track.title).font(.title3.weight(.semibold))
                                    Text(track.summary).font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if !track.learningAvailable {
                                        Text("Practice is not available yet.")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(model.busy)
                        }
                    }
                    if model.tracks.isEmpty {
                        Text("No catalog entries are loaded. This is not a search result.")
                    } else if navigation.learn == .explore && visibleTracks.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No matching certifications", systemImage: "magnifyingglass",
                                description: Text(
                                    "Change the query or clear the filters. The loaded catalog is unchanged."
                                ))
                            Button("Clear filters") { catalogFilter.clear() }
                        }
                    }
                }
                .disabled(
                    model.busy || loadingTrackID != nil || loadingLessonID != nil
                )
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(NativePrism.canvas)
                .navigationTitle(copy.learn)
                .modifier(
                    NativeCatalogSearch(
                        enabled: navigation.learn == .explore, query: $catalogFilter.query))
            } content: {
                path
            } detail: {
                session
            }
            .onChange(of: selectedTrack) { _, id in
                if let resumeTrackID, resumeTrackID == id {
                    self.resumeTrackID = nil
                    return
                }
                guard let track = model.tracks.first(where: { $0.id == id }),
                    track.learningAvailable
                else { return }
                guard model.path?.trackId != track.id else { return }
                if model.offlinePack?.trackId == track.id && model.lesson != nil { return }
                selectedLesson = nil
                requestPath(track)
            }
            .onChange(of: selectedLesson) { _, id in
                guard model.lesson?.id != id else { return }
                if let id, model.offlinePack?.lessons.contains(where: { $0.id == id }) == true {
                    Task { await model.openCachedLesson(id) }
                    return
                }
                guard
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == id
                    }
                    )
                else { return }
                requestLesson(node)
            }
            .confirmationDialog(
                "Download public question packs?",
                isPresented: Binding(
                    get: { downloadTrack != nil },
                    set: { if !$0 { downloadTrack = nil } })
            ) {
                if let track = downloadTrack {
                    Button("Download public content") {
                        downloadTrack = nil
                        Task { await model.downloadQuestionPack(track) }
                    }
                }
            } message: {
                Text(
                    "This downloads the whole current public release, not just this certification. No solutions are downloaded. Answers stay local until you choose Submit; correction and XP require the server."
                )
            }
        }

        @ViewBuilder private var myLearningPlan: some View {
            Section("Learning plan") {
                if let path = model.path,
                    path.trackId.lowercased() == model.profile?.activeTrackId?.lowercased()
                {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(
                        "\(coverage.remainingActivities) of \(coverage.totalActivities) activities remain"
                    )
                    .font(.headline)
                    ForEach(path.units) { unit in
                        LabeledContent(unit.title, value: "\(unit.lessons.count) activities")
                    }
                    Text("Open the plan to inspect available activities and server-reported locks.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Open your confirmed goal to load its units and remaining activities.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Review & Practice") {
                Text(
                    "Practice an available activity in your plan. Personalized review scheduling is not connected."
                )
                .foregroundStyle(.secondary)
                Text("Confirmed corrections can be read again without starting a new attempt.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Goal overview") {
                if let goal = model.profile?.activeTrackId,
                    let track = model.tracks.first(where: {
                        $0.id.lowercased() == goal.lowercased()
                    })
                {
                    Button("Open overview · \(track.title)", systemImage: "list.bullet.rectangle") {
                        selectedTrack = track.id
                        columns = .all
                        compactColumn = .content
                    }
                    Text(
                        "Inspect the catalog summary, availability and declared content information. Browsing never changes your goal."
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Choose an available certification in Explore to confirm a learning goal.")
                        .foregroundStyle(.secondary)
                }
            }
        }

        private var confirmedGoal: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let goalID = model.profile?.activeTrackId {
                    NativeEntryHeading(
                        title: model.tracks.first(where: {
                            $0.id.lowercased() == goalID.lowercased()
                        })?.title ?? goalID,
                        message: copy.confirmed)
                    Text("Next session").font(.headline)
                    if let track = model.tracks.first(where: {
                        $0.id.lowercased() == goalID.lowercased()
                    }) {
                        if let lesson = model.lesson,
                            lesson.trackId.lowercased() == goalID.lowercased()
                        {
                            let destination = NativeActivityDestination(
                                lessonID: lesson.id, title: lesson.title)
                            NativePrimaryButton(
                                title: destination.actionTitle(copy.resume), symbol: "play.circle"
                            ) {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(
                                "Your current activity is kept on this device; this does not submit it."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        } else if let path = model.path,
                            path.trackId.lowercased() == goalID.lowercased(),
                            let next = path.units.flatMap(\.lessons).first(where: {
                                $0.status == .inProgress || $0.status == .available
                            })
                        {
                            let destination = NativeActivityDestination(
                                lessonID: next.id, title: next.title)
                            NativePrimaryButton(
                                title: destination.actionTitle(copy.startSession),
                                symbol: "play.circle"
                            ) {
                                selectedTrack = path.trackId
                                selectedLesson = destination.lessonID
                                columns = .detailOnly
                                compactColumn = .detail
                            }
                            .disabled(model.busy || loadingTrackID != nil || loadingLessonID != nil)
                            Text(
                                "Next available activity in the loaded plan, not a personalized review recommendation."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        } else {
                            NativePrimaryButton(
                                title: "\(copy.startSession) · \(track.title)",
                                symbol: "arrow.right"
                            ) {
                                selectedTrack = track.id
                                columns = .all
                                compactColumn = .content
                            }
                            .disabled(
                                !track.learningAvailable || model.busy || loadingTrackID != nil)
                        }
                    }
                    if let path = model.path,
                        path.trackId.lowercased() == goalID.lowercased()
                    {
                        LabeledContent(
                            "Readiness · last loaded from server",
                            value: "\(path.readinessScore) %"
                        )
                        .font(.subheadline)
                        Text("A learning indicator, not an exam pass probability.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Open this goal to load its current learning path and readiness.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                    NativeEntryHeading(
                        title: "A clearer path starts with one goal.",
                        message: "No active goal has been confirmed by the server.")
                    NativePrimaryButton(title: "Explore certifications", symbol: "books.vertical") {
                        navigation.learn = .explore
                    }
                }
            }
            .accessibilityIdentifier("confirmed-learning-goal")
        }

        private func resumeCurrentActivity(_ lesson: Lesson) {
            if selectedTrack != lesson.trackId { resumeTrackID = lesson.trackId }
            selectedTrack = lesson.trackId
            selectedLesson = lesson.id
            columns = .detailOnly
            compactColumn = .detail
        }

        private func requestPath(_ track: Track) {
            let requestID = UUID()
            loadingTrackID = track.id
            loadingPathRequestID = requestID
            Task {
                await model.loadPath(track)
                guard loadingPathRequestID == requestID else { return }
                loadingTrackID = nil
                loadingPathRequestID = nil
            }
        }

        private func requestLesson(_ node: PathLesson) {
            let requestID = UUID()
            loadingLessonID = node.id
            loadingLessonRequestID = requestID
            Task {
                await model.loadLesson(node)
                guard loadingLessonRequestID == requestID else { return }
                loadingLessonID = nil
                loadingLessonRequestID = nil
            }
        }

        private var profile: some View {
            NativeReadingPage {
                if let profile = model.profile {
                    NativeEntryHeading(
                        title: profile.displayName,
                        message: "Your learning, at your pace.")
                    NativeReadingSection(title: "Confirmed learning") {
                        LabeledContent("Confirmed XP", value: "\(profile.xp)")
                        if let goal = profile.activeTrackId {
                            LabeledContent(
                                "Confirmed active goal",
                                value: model.tracks.first(where: {
                                    $0.id.lowercased() == goal.lowercased()
                                })?.title ?? goal)
                        } else {
                            Text("No server-confirmed active goal.")
                        }
                    }
                }
                NativeReadingSection(title: "Your account") {
                    NavigationLink {
                        progressHistory
                    } label: {
                        Label(copy.progressAndHistory, systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    Divider()
                    NavigationLink {
                        Form {
                            Section(copy.appLanguage) { NativeAppLanguagePicker() }
                            Section("Account") {
                                NavigationLink(copy.accountDeletion) {
                                    NativeAccountDeletionView(model: model)
                                }
                                Section("Reading & accessibility") {
                                    Text(
                                        "Text size, VoiceOver, contrast, motion and transparency follow your iPhone or iPad system settings. Reading voices are selected in the lesson audio controls."
                                    )
                                    Text("No separate accessibility preference is stored here.")
                                        .foregroundStyle(.secondary)
                                }
                                Section("Data & privacy") {
                                    Text(
                                        "Downloaded public questions, unsent answers and pending submissions are device-local. Confirmed history is synchronized by the server."
                                    )
                                    Text(
                                        "Disconnecting is not account deletion. There is no Coach memory or active social sharing to clear in this client."
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                .disabled(model.busy)
                            }
                            Section(connectionSectionTitle) {
                                Text(connectionDescription)
                                Button(
                                    copy[.signOut], systemImage: "person.crop.circle.badge.xmark"
                                ) {
                                    Task { await model.disconnect() }
                                }
                                .disabled(model.busy)
                            }
                        }
                        .navigationTitle(copy.settings)
                    } label: {
                        Label(copy.settings, systemImage: "gearshape")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            .navigationTitle(copy.profile)
        }

        private var connectionSectionTitle: String {
            #if DEBUG
                "Development connection"
            #else
                "Microsoft account"
            #endif
        }

        private var connectionDescription: String {
            #if DEBUG
                "Test connector only. Production sign-in is not enabled."
            #else
                "Connected with your Microsoft account."
            #endif
        }

        private var connection: some View {
            NavigationStack {
                Form {
                    Section {
                        NativeEntryHeading(
                            title: "Connect a test workspace.",
                            message:
                                "Development access only. Your production account uses Microsoft sign-in."
                        )
                        Text(
                            "This developer connector is not production sign-in. No Apple account or new identity is created."
                        )
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Certigo · development")
                    }
                    .scrollContentBackground(.hidden)
                    .background(NativePrism.canvas)
                    Section("Test connection") {
                        TextField("HTTPS API URL", text: $model.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityIdentifier("developer-api-url")
                        SecureField("Test account access token", text: $model.token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                            .accessibilityIdentifier("developer-access-token")
                        Button("Connect the test account") { Task { await model.connect() } }
                            .disabled(model.busy || model.baseURL.isEmpty || model.token.isEmpty)
                    }
                    Section {
                        Text(
                            "The token stays in this device’s secure vault. Pending answers are never graded locally."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Certigo")
            }
        }

        private var path: some View {
            List(selection: $selectedLesson) {
                if let track = model.tracks.first(where: {
                    $0.id == (selectedTrack ?? model.offlinePack?.trackId ?? model.path?.trackId)
                }) {
                    Section("Goal overview") {
                        Label(track.code, systemImage: "books.vertical")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(NativePrism.accent(for: track.code))
                        Text(track.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(track.summary)
                        Text(
                            "Practice uses the supported question-bank reader when available; this catalog does not declare per-certification formats."
                        )
                        Text(
                            "Availability: \(track.learningAvailable ? "learning path available" : "practice not available in this catalog")"
                        )
                        Text(
                            "Language, provider, publication version and prerequisite reasons are not declared by this catalog. The interface language does not translate learning content."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if let lesson = model.lesson, lesson.trackId == track.id,
                            let manifest = lesson.publicManifestId
                        {
                            LabeledContent("Loaded public content version", value: manifest)
                        }
                    }
                    if track.learningAvailable {
                        Section("Offline question pack") {
                            Button(
                                "Download public question packs", systemImage: "arrow.down.circle"
                            ) {
                                downloadTrack = track
                            }
                            .disabled(model.busy)
                            if let pack = model.offlinePack, pack.trackId == track.id {
                                Text("Downloaded public content. No local correction or XP.")
                                    .font(.footnote).foregroundStyle(.secondary)
                                ForEach(pack.lessons, id: \.id) { lesson in
                                    NavigationLink(value: lesson.id) {
                                        Label(lesson.title, systemImage: "internaldrive")
                                    }
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                }
                if let path = model.path,
                    selectedTrack == nil || selectedTrack == path.trackId
                {
                    if let track = model.tracks.first(where: { $0.id == path.trackId }) {
                        activeGoalSection(track)
                    }
                    Section {
                        Text(path.trackName).font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        LabeledContent(
                            "Confirmed readiness · last loaded", value: "\(path.readinessScore) %")
                        Button("Refresh progress", systemImage: "arrow.clockwise") {
                            Task { await model.refreshProgress() }
                        }
                        .disabled(model.busy)
                    }
                    Section("Learning plan") {
                        let coverage = NativePathCoverage(
                            units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                        Text(
                            "\(coverage.completedActivities) of \(coverage.totalActivities) activities completed"
                        )
                        Text(
                            "\(coverage.remainingActivities) activities remain in this loaded path, including \(coverage.lockedActivities) locked."
                        )
                        .font(.subheadline).foregroundStyle(.secondary)
                        Text(
                            "Completed means the server returned completed or mastered. This is activity coverage, not an exam score."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(path.units) { unit in
                        Section("Unit · \(unit.title)") {
                            ForEach(unit.lessons) { lesson in
                                NavigationLink(value: lesson.id) {
                                    Label {
                                        VStack(alignment: .leading) {
                                            Text(lesson.title)
                                                .font(.headline)
                                            Text("\(lesson.estMinutes) min").foregroundStyle(
                                                .secondary)
                                            Text(activityStatus(lesson.status))
                                                .font(.caption).foregroundStyle(.secondary)
                                            if !lesson.canOpen {
                                                Text(
                                                    "Locked by the server. A prerequisite reason is not provided."
                                                )
                                                .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    } icon: {
                                        Image(systemName: lesson.canOpen ? "book" : "lock")
                                    }
                                }
                                .disabled(
                                    !lesson.canOpen || model.busy || loadingLessonID != nil)
                            }
                        }
                    }
                    Section("Review & Practice") {
                        Text("Scheduled review recommendations are not connected in this client.")
                            .foregroundStyle(.secondary)
                        Text(
                            "Choose an available activity above for practice. A completed result can be read again without starting another attempt."
                        )
                        if let lesson = model.lesson, lesson.trackId == path.trackId {
                            Button("\(copy.resume) · \(lesson.title)", systemImage: "play.circle") {
                                resumeCurrentActivity(lesson)
                            }
                            .disabled(model.busy)
                        }
                    }
                } else if let selectedTrack,
                    let track = model.tracks.first(where: { $0.id == selectedTrack })
                {
                    if !track.learningAvailable {
                        Section {
                            Text(
                                "This certification can be explored, but its practice cannot be opened. Choose another certification in Explore."
                            )
                        }
                    } else if loadingTrackID == track.id {
                        Section {
                            ProgressView(copy.loading)
                                .frame(maxWidth: .infinity, minHeight: 88)
                        }
                    } else {
                        Section {
                            ContentUnavailableView(
                                "Learning path not loaded",
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    "Load or retry this certification’s path. This does not change your active goal."
                                )
                            )
                            Button("Load or retry path", systemImage: "arrow.clockwise") {
                                requestPath(track)
                            }
                            .disabled(model.busy || loadingTrackID != nil)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Choose a certification", systemImage: "books.vertical",
                        description: Text("Its learning path will load from the server.")
                    )
                }
                savedAnswers
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(NativePrism.canvas)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .navigationTitle(
                selectedTrack.map(trackTitle) ?? model.path?.trackName ?? "Learning path")
        }

        private var progressHistory: some View {
            NativeReadingPage {
                coverageSummary
                NativeReadingSection(title: "Confirmed session results") {
                    Text(
                        "Across your devices · \(model.serverHistory.count) summaries loaded\(model.historyNextCursor == nil ? "" : " · more pages available")"
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(
                        "These are loaded attempts, not all-time question coverage. Pending answers are not confirmed results; no average or pass probability is inferred."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if model.historyLoading {
                        ProgressView(copy.loading)
                    }
                    if let error = model.historyError {
                        Label(
                            error,
                            systemImage: model.historyOffline
                                ? "wifi.slash" : "exclamationmark.triangle"
                        )
                        .accessibilityIdentifier("history-error")
                    }
                    if let refreshedAt = model.historyRefreshedAt {
                        Text(
                            "Last loaded \(refreshedAt.formatted(date: .abbreviated, time: .shortened))"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if model.serverHistory.isEmpty && model.historyError == nil {
                            Text(
                                model.historyNextCursor == nil
                                    ? copy[.noHistory]
                                    : "No confirmed attempts in this page. More history is available."
                            )
                        }
                    } else if !model.historyLoading && model.historyError == nil {
                        Text("Confirmed history has not been loaded.")
                    }
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmed) { item in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.seal")
                                    .font(.subheadline).foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(item.lessonId)).font(.headline)
                                Text(trackTitle(item.trackId)).foregroundStyle(.secondary)
                                Text(
                                    item.submittedAt,
                                    format: .dateTime.year().month().day().hour().minute())
                                Text(
                                    "Recorded score: \(item.scorePct) % · Earned XP: \(item.xpEarned)"
                                )
                                Text(
                                    "Server-confirmed summary · full correction is in saved answers when available."
                                )
                                .font(.caption).foregroundStyle(.secondary)
                                if let saved = model.localHistorySubmission(for: item),
                                    saved.status == .pendingCorrection && saved.result == nil
                                {
                                    Button("Retrieve full correction") {
                                        Task { await model.retry(saved) }
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(model.busy)
                                }
                            }
                        }
                    }
                    Button("Refresh history", systemImage: "arrow.clockwise") {
                        Task { await model.refreshHistory() }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.historyLoading)
                    if model.historyNeedsSignIn && model.canReconnectHistory {
                        Button("Sign in again", systemImage: "person.crop.circle") {
                            Task { await model.reconnectHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.busy || model.historyLoading)
                    }
                    if model.historyNextCursor != nil {
                        Button("Load more", systemImage: "chevron.down") {
                            Task { await model.loadMoreHistory() }
                        }
                        .frame(minHeight: 44)
                        .disabled(model.historyLoading)
                    }
                }
                NativeReadingSection(title: "On this device") {
                    Text(
                        "Drafts are never uploaded by viewing history. Local dates are activity start dates, not server submission times."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    if let presentation = model.historyPresentation {
                        ForEach(presentation.confirmedOnDevice) { saved in
                            NativeReadingCard {
                                Label(copy.confirmed, systemImage: "checkmark.circle")
                                    .foregroundStyle(NativePrism.confirmed)
                                Text(lessonTitle(saved.lessonId)).font(.headline)
                                Text(
                                    saved.submission.startedAt,
                                    format: .dateTime.year().month().day())
                                if let result = saved.result {
                                    Text(
                                        "Confirmed score: \(result.scorePct) % · Earned XP: \(result.rewards.xpEarned)"
                                    )
                                }
                                Text(
                                    "Server acknowledgement saved locally; not in the loaded history pages."
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        ForEach(presentation.onDevice) { saved in
                            savedAnswer(saved)
                        }
                        if presentation.onDevice.isEmpty && presentation.confirmedOnDevice.isEmpty {
                            Text("No additional saved submissions on this device.")
                        }
                    } else if model.historyError != nil {
                        Text(
                            "The local history presentation could not be verified. Saved answers remain available in Learn."
                        )
                    }
                    if model.lesson != nil {
                        Label(
                            model.outcome == nil
                                ? "Current local activity" : "Current submitted activity",
                            systemImage: "doc.text")
                        Button(copy.resume, systemImage: "play.circle") {
                            model.selectedTab = .learn
                            columns = .detailOnly
                            compactColumn = .detail
                        }
                        .frame(minHeight: 44)
                    }
                }
                NativeReadingSection(title: "Readiness · last loaded from server") {
                    if let profile = model.profile {
                        LabeledContent("Confirmed XP", value: "\(profile.xp)")
                    }
                    if let path = model.path {
                        Text(path.trackName)
                        LabeledContent("Confirmed readiness", value: "\(path.readinessScore) %")
                    }
                    Text(
                        "History pages do not update your balance, readiness or active learning goal."
                    )
                    Text(
                        "Readiness is a server-returned learning indicator for the named path, not a calibrated probability of passing the exam. Its formula version, evidence window and last calculation time are not supplied by this client contract."
                    )
                    .font(.subheadline).foregroundStyle(.secondary)
                    if model.path == nil {
                        Text(
                            "Readiness is unknown until a learning path is loaded. Unknown is not zero."
                        )
                    }
                }
            }
            .navigationTitle(copy.progressAndHistory)
            .task {
                if !model.historyAttempted { await model.refreshHistory() }
            }
        }

        private var coverageSummary: some View {
            NativeReadingSection(title: "Activity & coverage") {
                if let path = model.path {
                    let coverage = NativePathCoverage(
                        units: path.units.map { $0.lessons.map { $0.status.rawValue } })
                    Text(path.trackName).font(.headline)
                    LabeledContent(
                        "Completed activities",
                        value: "\(coverage.completedActivities) of \(coverage.totalActivities)")
                    LabeledContent(
                        "Completed units",
                        value: "\(coverage.completedUnits) of \(coverage.totalUnits)")
                    Text(
                        "Snapshot of the currently loaded server path, not a time-period report. Completed or mastered activities count; empty units do not count as complete."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(
                        "Load a learning path to see its activity denominator. Coverage is not known yet."
                    )
                }
                if let lesson = model.lesson {
                    let selectedCount = lesson.questions.filter {
                        model.selections[$0.id] != nil
                    }.count
                    Text(lesson.title).font(.headline)
                    LabeledContent(
                        "Locally selected answers",
                        value: "\(selectedCount) of \(lesson.questions.count) questions")
                    Text(
                        "Selection is not submission or correctness. Total questions covered across the whole path are not provided."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                Text(
                    "Viewing this snapshot never switches your active goal. History is separate and may contain other goals."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }

        private func activityStatus(_ status: NodeStatus) -> String {
            switch status {
            case .locked: "Locked"
            case .available: "Available to practice"
            case .inProgress: "In progress"
            case .completed: "Completed · server state"
            case .mastered: "Mastered · server state"
            }
        }

        @ViewBuilder private var savedAnswers: some View {
            if !model.queue.isEmpty {
                Section("Saved answers") {
                    ForEach(model.queue) { saved in
                        savedAnswer(saved)
                    }
                }
            }
        }

        private func savedAnswer(_ saved: SavedSubmission) -> some View {
            NativeReadingCard {
                Text(lessonTitle(saved.lessonId)).font(.headline)
                switch saved.status {
                case .pendingCorrection:
                    Label("Correction pending", systemImage: "clock")
                        .foregroundStyle(NativePrism.pending)
                    Button(copy.retry) {
                        Task { await model.retry(saved) }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.busy)
                case .corrected:
                    if let result = saved.result {
                        Text("Confirmed score: \(result.scorePct) %")
                        ForEach(result.results) { item in
                            Text(item.explanation)
                        }
                    }
                case .failed:
                    Label(
                        "Submission rejected · answers preserved",
                        systemImage: "exclamationmark.triangle")
                    Text(
                        "This is a local status; the server may already have recorded the attempt."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        private func trackTitle(_ id: String) -> String {
            model.tracks.first(where: { $0.id.lowercased() == id.lowercased() })?.title ?? id
        }

        private func lessonTitle(_ id: String) -> String {
            if let lesson = model.lesson, lesson.id == id { return lesson.title }
            if let lesson = model.path?.units.flatMap(\.lessons).first(where: { $0.id == id }) {
                return lesson.title
            }
            return model.offlinePack?.lessons.first(where: { $0.id == id })?.title ?? id
        }

        @ViewBuilder private func activeGoalSection(_ track: Track) -> some View {
            let state = NativeActiveGoalPresentation(
                targetID: track.id, confirmedID: model.profile?.activeTrackId,
                savingID: savingGoalID, busy: model.busy)
            Section("Active learning goal") {
                Label(state.status, systemImage: state.symbol)
                    .accessibilityIdentifier("active-goal-status")
                if let current = model.profile?.activeTrackId {
                    Text(
                        "Server-confirmed goal: \(model.tracks.first(where: { $0.id == current })?.title ?? current)"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    Text("No active goal is confirmed by the server.")
                        .foregroundStyle(.secondary)
                }
                NativePrimaryButton(title: state.action, symbol: "scope") {
                    savingGoalID = track.id
                    Task {
                        await model.chooseActiveTrack(track)
                        savingGoalID = nil
                    }
                }
                .frame(minHeight: 44)
                .disabled(!state.canChoose)
                .accessibilityIdentifier("choose-active-goal")
                Text(
                    "Browsing does not change your goal. This action requests a server-confirmed change; your current activity and saved submissions stay available."
                )
                .font(.subheadline).foregroundStyle(.secondary)
            }
        }

        private var session: some View {
            Group {
                if let lesson = model.lesson,
                    selectedTrack == nil || selectedTrack == lesson.trackId,
                    selectedLesson == nil || selectedLesson == lesson.id
                {
                    ScrollViewReader { reader in
                        NativeReadingPage {
                            Text(lesson.title).font(.title).bold()
                                .accessibilityAddTraits(.isHeader)
                                .id("session-reading-start")
                            Label("Read · Decide · Understand", systemImage: "text.book.closed")
                                .font(.subheadline).foregroundStyle(NativePrism.tint)
                            DisclosureGroup("Read lesson aloud") {
                                NativeLessonAudioControls(
                                    content: NativeLessonReadingContent(
                                        lessonTitle: lesson.title,
                                        blocks: lesson.blocks.map {
                                            (type: $0.type, title: $0.title, body: $0.body)
                                        }),
                                    ownerID: model.profile?.id
                                )
                                .id(lesson.id)
                            }
                            .frame(minHeight: 44)
                            Text(
                                "Answer the questions, then submit your answers for server correction."
                            )
                            .foregroundStyle(.secondary)
                            ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                                if let title = block.title {
                                    Text(title).font(.headline)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                if let body = block.body {
                                    Text(.init(body)).textSelection(.enabled)
                                }
                                if let code = block.code {
                                    ScrollView(.horizontal) {
                                        Text(code).font(.body.monospaced()).textSelection(.enabled)
                                    }
                                    .padding(16)
                                    .background(
                                        NativePrism.surface,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                if let question = block.check {
                                    questionView(question)
                                }
                            }
                            if let outcome = model.outcome {
                                switch outcome {
                                case .pendingCorrection:
                                    NativeReadingCard {
                                        Label(
                                            copy[.pendingCorrection],
                                            systemImage: "clock"
                                        )
                                        .font(.headline).foregroundStyle(NativePrism.pending)
                                        Text(
                                            "Correction will be requested after reconnecting. No score or XP is confirmed yet."
                                        )
                                        .foregroundStyle(.secondary)
                                    }
                                    .accessibilityIdentifier("pending-correction")
                                case .corrected(let result):
                                    NativeReadingSection(title: "Your confirmed result") {
                                        Label(
                                            copy.confirmed, systemImage: "checkmark.seal"
                                        )
                                        .foregroundStyle(NativePrism.confirmed)
                                        LabeledContent("Score", value: "\(result.scorePct) %")
                                        LabeledContent(
                                            "XP earned", value: "\(result.rewards.xpEarned)")
                                    }
                                    ForEach(result.results) { item in
                                        NativeReadingCard {
                                            Label(
                                                item.correct ? "Correct answer" : "Review needed",
                                                systemImage: item.correct
                                                    ? "checkmark.circle" : "book"
                                            )
                                            .font(.headline)
                                            .foregroundStyle(
                                                item.correct
                                                    ? NativePrism.confirmed : NativePrism.pending)
                                            if let question = lesson.blocks.compactMap(\.check)
                                                .first(where: { $0.id == item.itemId })
                                            {
                                                Text(.init(question.stem)).font(.headline)
                                            }
                                            Text(.init(item.explanation)).textSelection(.enabled)
                                        }
                                    }
                                    NativeReadingSection(title: copy[.continueLearning]) {
                                        Button("Read again", systemImage: "text.book.closed") {
                                            reader.scrollTo("session-reading-start", anchor: .top)
                                        }
                                        .frame(minHeight: 44)
                                        .accessibilityIdentifier("read-confirmed-lesson-again")
                                        if let node = model.path?.units.flatMap(\.lessons).first(
                                            where: {
                                                $0.id == lesson.id && $0.canOpen
                                            }), model.path?.trackId == lesson.trackId
                                        {
                                            let destination = NativeActivityDestination(
                                                lessonID: lesson.id, title: lesson.title)
                                            NativePrimaryButton(
                                                title: destination.actionTitle(copy.practiceAgain),
                                                symbol: "arrow.clockwise"
                                            ) {
                                                requestLesson(node)
                                            }
                                            .disabled(model.busy || loadingLessonID != nil)
                                            Text(
                                                "Starts a new answer selection for this activity. Your confirmed attempt stays in history."
                                            )
                                            .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text(
                                                "Open an available activity in the learning plan to practice again. Reading does not create another attempt."
                                            )
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                NativePrimaryButton(
                                    title: copy.submitAnswer, symbol: "paperplane"
                                ) {
                                    Task { await model.submit() }
                                }
                                .disabled(!model.canSubmit)
                                .accessibilityIdentifier("submit-for-correction")
                            }
                        }
                    }
                } else if let selectedLesson,
                    let node = model.path?.units.flatMap(\.lessons).first(where: {
                        $0.id == selectedLesson
                    })
                {
                    if loadingLessonID == node.id {
                        ProgressView(copy.loading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                "Lesson unavailable",
                                systemImage: "wifi.exclamationmark",
                                description: Text(
                                    "The selected lesson could not be loaded."
                                )
                            )
                            Button(copy.retry, systemImage: "arrow.clockwise") {
                                requestLesson(node)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.busy || loadingLessonID != nil)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ContentUnavailableView(
                        "One session at a time", systemImage: "book",
                        description: Text("Choose an activity in the learning path.")
                    )
                }
            }
            .navigationTitle(copy.startSession)
        }

        private func questionView(_ question: QuizItem) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(.init(question.stem)).font(.headline)
                    .accessibilityAddTraits(.isHeader)
                ForEach(question.options) { option in
                    Button {
                        model.select(option, question: question)
                    } label: {
                        Label(
                            option.label,
                            systemImage: model.selections[question.id] == option.id
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NativeChoiceButtonStyle())
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                model.selections[question.id] == option.id
                                    ? NativePrism.tint : NativePrism.edge,
                                lineWidth: model.selections[question.id] == option.id ? 2 : 1)
                    }
                    .disabled(model.outcome != nil || model.busy)
                    .accessibilityAddTraits(
                        model.selections[question.id] == option.id ? .isSelected : []
                    )
                    .accessibilityValue(
                        model.selections[question.id] == option.id ? "Selected" : "Not selected")
                }
            }
            .onAppear { model.questionAppeared(question.id) }
        }
    }

    @MainActor
    struct NativeLessonAudioControls: View {
        @Environment(\.scenePhase) private var scenePhase
        @State private var speech = NativeLessonSpeech()
        let content: NativeLessonReadingContent
        let ownerID: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Read lesson aloud").font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(
                    "Reads selected learning text only. Code, questions and corrections are not read. Choose a reading voice; the content language is not detected."
                )
                .font(.subheadline).foregroundStyle(.secondary)
                Picker("Reading voice", selection: $speech.voiceID) {
                    Text("Choose a voice").tag("")
                    ForEach(speech.voices, id: \.identifier) { voice in
                        Text("\(voice.name) · \(voice.language)").tag(voice.identifier)
                    }
                }
                .disabled(speech.state != .idle)
                if speech.voices.isEmpty {
                    Text("No reading voices are available on this device.")
                }
                Picker("Reading speed", selection: $speech.rate) {
                    Text("Slower").tag(AVSpeechUtteranceDefaultSpeechRate * 0.8)
                    Text("Standard").tag(AVSpeechUtteranceDefaultSpeechRate)
                }
                .disabled(speech.state != .idle)
                Text(speech.state.label).font(.subheadline)
                    .accessibilityIdentifier("lesson-audio-state")
                ViewThatFits(in: .horizontal) {
                    HStack { playbackButtons }
                    VStack(alignment: .leading) { playbackButtons }
                }
                if let issue = speech.issue {
                    Text(issue).foregroundStyle(.primary)
                        .accessibilityIdentifier("lesson-audio-error")
                }
            }
            .onDisappear { speech.stop() }
            .onChange(of: content) { _, _ in speech.stop() }
            .onChange(of: ownerID) { _, _ in speech.reset() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { speech.stop() }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIAccessibility.voiceOverStatusDidChangeNotification)
            ) { _ in
                if UIAccessibility.isVoiceOverRunning { speech.stop() }
            }
        }

        @ViewBuilder private var playbackButtons: some View {
            switch speech.state {
            case .idle:
                Button("Read lesson", systemImage: "speaker.wave.2") {
                    speech.read(content)
                }
                .frame(minHeight: 44)
            case .reading:
                Button("Pause reading", systemImage: "pause") { speech.pause() }
                    .frame(minHeight: 44)
            case .paused:
                Button("Resume reading", systemImage: "play") { speech.resume() }
                    .frame(minHeight: 44)
            }
            if speech.state != .idle {
                Button("Stop reading", systemImage: "stop") { speech.stop() }
                    .frame(minHeight: 44)
            }
        }
    }

    @MainActor
    @Observable
    private final class NativeLessonSpeech: NSObject, AVSpeechSynthesizerDelegate {
        enum State {
            case idle, reading, paused

            var label: String {
                switch self {
                case .idle: "Audio stopped"
                case .reading: "Reading lesson"
                case .paused: "Audio paused"
                }
            }
        }

        let voices = AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language, $0.name, $0.identifier) < ($1.language, $1.name, $1.identifier)
        }
        var voiceID = ""
        var rate = AVSpeechUtteranceDefaultSpeechRate
        private(set) var state = State.idle
        private(set) var issue: String?
        private let synthesizer = AVSpeechSynthesizer()
        private var utteranceID: ObjectIdentifier?

        override init() {
            super.init()
            synthesizer.delegate = self
            synthesizer.usesApplicationAudioSession = false
        }

        func read(_ content: NativeLessonReadingContent) {
            guard state == .idle else { return }
            issue = nil
            guard !voices.isEmpty else {
                issue = "No reading voices are available on this device."
                return
            }
            guard !UIAccessibility.isVoiceOverRunning else {
                issue =
                    "VoiceOver is active. Use VoiceOver to read this content; optional audio stays stopped to avoid overlapping speech."
                return
            }
            guard !voiceID.isEmpty else {
                issue = "Choose a reading voice before starting."
                return
            }
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else {
                issue = "That voice is unavailable. Choose an available reading voice."
                return
            }
            let text: String
            do {
                text = try content.spokenText(
                    renderingMarkdown: NativeLessonReadingContent.plainText)
            } catch {
                issue =
                    "The lesson text could not be prepared for reading. No audio was started; you can still read the lesson on screen."
                return
            }
            guard !text.isEmpty else {
                issue = "No lesson text is available to read."
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = rate
            utteranceID = ObjectIdentifier(utterance)
            state = .reading
            synthesizer.speak(utterance)
        }

        func pause() {
            guard state == .reading else { return }
            if synthesizer.pauseSpeaking(at: .immediate) {
                state = .paused
            } else {
                issue = "Reading could not be paused. Stop reading and try again."
            }
        }

        func resume() {
            guard state == .paused else { return }
            guard !UIAccessibility.isVoiceOverRunning else {
                stop()
                issue =
                    "VoiceOver is active. Optional audio stays stopped to avoid overlapping speech."
                return
            }
            if synthesizer.continueSpeaking() {
                state = .reading
            } else {
                issue = "Reading could not be resumed. Stop reading and try again."
            }
        }

        func stop() {
            utteranceID = nil
            synthesizer.stopSpeaking(at: .immediate)
            state = .idle
            issue = nil
        }

        func reset() {
            stop()
            voiceID = ""
            rate = AVSpeechUtteranceDefaultSpeechRate
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor [weak self] in self?.finished(id) }
        }

        private func finished(_ id: ObjectIdentifier) {
            guard utteranceID == id else { return }
            utteranceID = nil
            state = .idle
        }
    }
#endif

struct NativeLessonReadingContent: Equatable {
    enum Part: Equatable {
        case title(String)
        case text(String)
        case markdown(String)
    }

    let parts: [Part]

    init(lessonTitle: String, blocks: [(type: String, title: String?, body: String?)]) {
        let readableTypes: Set<String> = ["hook", "concept", "example", "recap"]
        var parts: [Part] = [.title(lessonTitle)]
        for block in blocks where readableTypes.contains(block.type) {
            if let title = block.title { parts.append(.title(title)) }
            if let body = block.body { parts.append(.markdown(body)) }
        }
        self.parts = parts
    }

    init(
        editorialTitle: String,
        objective: String,
        hook: String,
        keyIdeas: [String],
        exampleSituation: String,
        exampleSteps: [String],
        exampleDecision: String,
        recap: String
    ) {
        var parts: [Part] = [
            .title(editorialTitle),
            .text(objective),
            .text(hook),
            .title("Idées clés"),
        ]
        parts.append(contentsOf: keyIdeas.map(Part.text))
        parts.append(.title("Exemple résolu"))
        parts.append(.text(exampleSituation))
        parts.append(
            contentsOf: exampleSteps.enumerated().map {
                .text("\($0.offset + 1). \($0.element)")
            })
        parts.append(.text(exampleDecision))
        parts.append(.title("À retenir"))
        parts.append(.text(recap))
        self.parts = parts
    }

    func spokenText(renderingMarkdown: (String) throws -> String) throws -> String {
        try parts.map { part in
            let text: String
            switch part {
            case .title(let title): text = title
            case .text(let value): text = value
            case .markdown(let body): text = try renderingMarkdown(body)
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    #if canImport(Darwin)
        static func plainText(_ markdown: String) throws -> String {
            // Match Text's inline Markdown while preserving paragraph whitespace.
            let value = try AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .throwError))
            return String(value.characters)
        }
    #endif
}

struct NativeActiveGoalPresentation {
    let targetID: String
    let confirmedID: String?
    let savingID: String?
    let busy: Bool

    var isConfirmed: Bool {
        confirmedID?.lowercased()
            == targetID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isSaving: Bool { savingID == targetID }
    var canChoose: Bool { !busy && savingID == nil && !isConfirmed }
    var status: String {
        if isSaving { return "Goal change pending · waiting for the server" }
        return isConfirmed ? "This is your confirmed active goal" : "Viewing a goal · not selected"
    }
    var symbol: String { isSaving ? "clock" : isConfirmed ? "checkmark.circle" : "eye" }
    var action: String { isSaving ? "Saving active goal…" : "Choose as active goal" }
}

struct NativeLearningNavigation {
    enum Tab: String, CaseIterable { case learn, coach, social, profile }
    enum Learn { case myLearning, explore }
    enum Social { case friends, teams }
    var tab: Tab = .learn
    var learn: Learn
    var social: Social = .friends

    init(hasGoal: Bool = false) {
        learn = hasGoal ? .myLearning : .explore
    }

    func showsTrack(_ id: String, activeID: String?, openedID: String?) -> Bool {
        learn == .explore || id.lowercased() == activeID?.lowercased() || id == openedID
    }
}
