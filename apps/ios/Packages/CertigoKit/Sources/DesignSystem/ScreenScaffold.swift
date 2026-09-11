// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// `ScreenScaffold` est le seul moyen prévu d'écrire un écran. Il rend
// lui-même le chargement, l'erreur **avec sa reprise**, et le vide. Un écran
// qui oublierait le cas d'erreur ne peut pas exister : le scaffold le réclame
// par son type.

import SwiftUI

/// Enveloppe d'écran qui prend en charge les quatre états de chargement.
public struct ScreenScaffold<Value, Content: View>: View {
    private let state: LoadState<Value>
    private let content: (Value) -> Content

    public init(
        _ state: LoadState<Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            LoadingState()
        case .loaded(let value):
            content(value)
        case .failed(let failure, let retry):
            FailureState(failure: failure, retry: retry)
        }
    }
}

/// L'état de chargement. Discret, et annoncé à VoiceOver.
struct LoadingState: View {
    var body: some View {
        VStack(spacing: PrismSpace.md) {
            ProgressView()
            Text("Chargement…")
                .prismType("bodyMedium")
                .foregroundStyle(Color(prism: PrismPalette.lightTextSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chargement en cours")
    }
}

/// L'état d'échec. **La reprise n'est pas optionnelle** : elle vient du type.
struct FailureState: View {
    let failure: LoadFailure
    let retry: @MainActor () -> Void

    var body: some View {
        VStack(spacing: PrismSpace.md) {
            Text(failure.title)
                .prismType("titleMedium")
                .foregroundStyle(Color(prism: PrismPalette.lightTextPrimary))
            Text(failure.message)
                .prismType("bodyMedium")
                .foregroundStyle(Color(prism: PrismPalette.lightTextSecondary))
                .multilineTextAlignment(.center)
            Button(failure.retryLabel) { retry() }
                .buttonStyle(PrismPrimaryButtonStyle())
        }
        .padding(PrismSpace.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Le style de bouton principal Prism.
public struct PrismPrimaryButtonStyle: ButtonStyle {
    /// Le mouvement est informatif, jamais décoratif : il est supprimé lorsque
    /// l'utilisateur a demandé moins d'animations. C'est l'équivalent exact de
    /// `MediaQuery.disableAnimations` côté Flutter, dont `AGENTS.md` exige la
    /// préservation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .prismType("labelLarge")
            .foregroundStyle(Color(prism: PrismPalette.lightSurface))
            .padding(.horizontal, PrismSpace.lg)
            .padding(.vertical, PrismSpace.sm)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.button, style: .continuous)
                    .fill(Color(prism: PrismPalette.primary))
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: configuration.isPressed)
    }
}
