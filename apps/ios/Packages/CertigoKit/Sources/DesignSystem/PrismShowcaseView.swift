// NON COMPILÉ — voir apps/ios/DEMARRAGE.md.
//
// L'écran que l'application affiche au lancement. Ce n'est pas un
// « Hello World » : il rend les vraies valeurs de Prism, et il démontre les
// trois traits de la grammaire d'Apple Music retenus pour Certigo :
//
//   1. **La couleur vient du contenu et irradie sa région.** Chez Apple Music
//      elle vient de la pochette ; ici de la piste de certification, via la
//      bande OKLCH à clarté constante que Prism lui attribue.
//   2. **Les contrôles flottent au-dessus du contenu** au lieu de le border.
//      Rien n'est collé aux bords, et le contenu passe *sous* la barre.
//   3. **Le mouvement est continu** : la barre s'étire vers son état suivant
//      au lieu de disparaître puis réapparaître (`glassEffectID`).
//
// Séparation des couches, imposée par Apple et outillée par `PrismGlass.swift` :
// le **contenu** utilise les matériaux standard, la **couche de contrôle**
// utilise Liquid Glass. Jamais l'inverse, jamais les deux superposés.

import Foundation
import SwiftUI

/// Une piste de certification, réduite à ce que la vitrine doit montrer.
public struct ShowcaseTrack: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let symbol: String
    public let progress: Double

    public init(id: String, title: String, symbol: String, progress: Double) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.progress = progress
    }

    /// La bande du spectre attribuée à cette piste. Déterministe.
    public var band: PrismBand { PrismSpectrum.band(forTrackId: id) }

    /// Six pistes réelles du catalogue Certigo, choisies parce qu'elles
    /// tombent chacune sur une bande différente — vérifié en calculant
    /// l'empreinte FNV-1a des 91 identifiants présents dans `content/`.
    public static let sample: [ShowcaseTrack] = [
        ShowcaseTrack(
            id: "az-900", title: "Azure Fundamentals",
            symbol: "cloud.fill", progress: 0.72),
        ShowcaseTrack(
            id: "dp-900", title: "Azure Data Fundamentals",
            symbol: "cylinder.split.1x2.fill", progress: 0.41),
        ShowcaseTrack(
            id: "az-104", title: "Azure Administrator",
            symbol: "gearshape.2.fill", progress: 0.18),
        ShowcaseTrack(
            id: "ms-900", title: "Microsoft 365 Fundamentals",
            symbol: "square.grid.2x2.fill", progress: 0.93),
        ShowcaseTrack(
            id: "ai-agent-builder-associate", title: "AI Agent Builder",
            symbol: "sparkles", progress: 0.05),
        ShowcaseTrack(
            id: "github-copilot", title: "GitHub Copilot",
            symbol: "chevron.left.forwardslash.chevron.right", progress: 0.56),
    ]
}

/// Ce que la section « État » affiche une fois chargée.
public struct PrismDemoPayload: Sendable, Equatable {
    public let headline: String
    public let detail: String

    public init(headline: String, detail: String) {
        self.headline = headline
        self.detail = detail
    }
}

/// La vitrine du système de design Prism.
public struct PrismShowcaseView: View {
    @State private var demoState: LoadState<PrismDemoPayload> = .idle
    @State private var selectedTrack: ShowcaseTrack = ShowcaseTrack.sample[0]
    @State private var isFilterExpanded = false
    @Namespace private var glassNamespace
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    // MARK: Couleurs dérivées de l'apparence

    private var isDark: Bool { colorScheme == .dark }

    private var background: Color {
        Color(prism: isDark ? PrismPalette.darkBg : PrismPalette.lightBg)
    }

    private var textPrimary: Color {
        Color(prism: isDark ? PrismPalette.darkTextPrimary : PrismPalette.lightTextPrimary)
    }

    private var textSecondary: Color {
        Color(prism: isDark ? PrismPalette.darkTextSecondary : PrismPalette.lightTextSecondary)
    }

    /// Le rôle de la bande qui convient à l'apparence courante.
    private func accent(_ band: PrismBand) -> Color {
        Color(prism: isDark ? band.glow : band.ink)
    }

    private func region(_ band: PrismBand) -> Color {
        Color(prism: isDark ? band.softDark : band.softLight)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            background.ignoresSafeArea()
            irradiation.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: PrismSpace.xl) {
                    header
                    trackSection
                    typographySection
                    paletteSection
                    loadStateSection
                    footer
                    // Dégagement : le contenu passe SOUS la barre flottante,
                    // il ne s'arrête pas net à son bord.
                    Color.clear.frame(height: 96)
                }
                .padding(PrismSpace.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .prismScrollEdge(.top)

            floatingControls
                .padding(.bottom, PrismSpace.md)
        }
    }

    // MARK: 1. La couleur vient du contenu et irradie sa région

    /// Le halo de la piste sélectionnée, qui teinte le haut de l'écran et
    /// s'éteint vers le milieu. C'est l'équivalent du halo de pochette d'Apple
    /// Music, appliqué à une piste de certification.
    private var irradiation: some View {
        LinearGradient(
            colors: [region(selectedTrack.band), background.opacity(0)],
            startPoint: .top,
            endPoint: .center
        )
        .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: selectedTrack.id)
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: PrismSpace.xs) {
            Text("Certigo")
                .prismType("displayLarge")
                .foregroundStyle(accent(selectedTrack.band))
            Text("Squelette natif iOS — Prism sur Liquid Glass")
                .prismType("bodyLarge")
                .foregroundStyle(textSecondary)
            Text("Aucune de ces lignes n'avait été compilée avant ce lancement.")
                .prismType("bodySmall")
                .foregroundStyle(Color(prism: PrismPalette.xpGold))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Les six bandes

    private var trackSection: some View {
        section("Parcours", subtitle: "une bande réfractée par piste") {
            VStack(spacing: PrismSpace.xs) {
                ForEach(ShowcaseTrack.sample) { track in
                    Button {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) {
                            selectedTrack = track
                        }
                    } label: {
                        trackRow(track)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(track.title), bande \(track.band.name), "
                            + "\(Int(track.progress * 100)) pour cent"
                    )
                    .accessibilityAddTraits(track.id == selectedTrack.id ? [.isSelected] : [])
                }
            }
        }
    }

    private func trackRow(_ track: ShowcaseTrack) -> some View {
        let isSelected = track.id == selectedTrack.id
        return HStack(spacing: PrismSpace.sm) {
            Image(systemName: track.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(prism: PrismPalette.lightSurface))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(prism: track.band.vivid)))
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .prismType("titleSmall")
                    .foregroundStyle(textPrimary)
                ProgressView(value: track.progress)
                    .tint(Color(prism: track.band.vivid))
            }
            Text("\(Int(track.progress * 100)) %")
                .prismType("labelMedium")
                .foregroundStyle(accent(track.band))
                .monospacedDigit()
        }
        .padding(PrismSpace.sm)
        .background(
            // La région de la piste est teintée par SA bande : la couleur vient
            // du contenu, pas d'un thème global.
            RoundedRectangle(cornerRadius: PrismRadius.md, style: .continuous)
                .fill(region(track.band).opacity(isSelected ? 1 : 0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.md, style: .continuous)
                .strokeBorder(accent(track.band).opacity(isSelected ? 0.55 : 0), lineWidth: 1.5)
        )
    }

    // MARK: Typographie

    private var typographySection: some View {
        section("Typographie", subtitle: "\(PrismTypeScale.all.count) créneaux") {
            VStack(alignment: .leading, spacing: PrismSpace.sm) {
                ForEach(PrismTypeScale.all, id: \.name) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .prismType(entry.name)
                            .foregroundStyle(textPrimary)
                        Text(
                            "\(Int(entry.slot.size)) pt · graisse \(Int(entry.slot.weight)) · "
                                + "style natif \(PrismFont.nativeStyle(for: entry.name).rawValue)"
                        )
                        .prismType("labelSmall")
                        .foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Contraste

    private var paletteSection: some View {
        section("Contraste", subtitle: "WCAG, calculé à l'exécution") {
            VStack(spacing: PrismSpace.xs) {
                ForEach(PrismContrast.auditedPairs, id: \.name) { pair in
                    let ratio = PrismContrast.ratio(pair.foreground, on: pair.background)
                    HStack(spacing: PrismSpace.sm) {
                        Text("Aa")
                            .prismType("titleMedium")
                            .foregroundStyle(Color(prism: pair.foreground))
                            .frame(width: 52, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.md, style: .continuous)
                                    .fill(Color(prism: pair.background))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pair.name)
                                .prismType("labelMedium")
                                .foregroundStyle(textPrimary)
                            Text(String(format: "%.2f:1", ratio))
                                .prismType("bodySmall")
                                .foregroundStyle(
                                    ratio >= PrismContrast.aaNormalText
                                        ? Color(prism: PrismPalette.success)
                                        : Color(prism: PrismPalette.error)
                                )
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(pair.name), contraste \(String(format: "%.1f", ratio)) pour un")
                }
            }
        }
    }

    // MARK: États de chargement

    private var loadStateSection: some View {
        section("États", subtitle: "ScreenScaffold en fonctionnement") {
            VStack(alignment: .leading, spacing: PrismSpace.sm) {
                ScreenScaffold(demoState) { payload in
                    VStack(alignment: .leading, spacing: PrismSpace.xxs) {
                        Text(payload.headline)
                            .prismType("titleMedium")
                            .foregroundStyle(Color(prism: PrismPalette.success))
                        Text(payload.detail)
                            .prismType("bodyMedium")
                            .foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 140)

                HStack(spacing: PrismSpace.xs) {
                    Button("Charger") { load(shouldFail: false) }
                        .buttonStyle(PrismPrimaryButtonStyle())
                    Button("Échouer") { load(shouldFail: true) }
                        .buttonStyle(PrismPrimaryButtonStyle())
                }
            }
        }
    }

    /// Simule un chargement. Le cas d'échec passe par le **vrai** chemin
    /// `LoadState.failed`, reprise comprise : si le bouton « Réessayer »
    /// apparaît et fonctionne, la contrainte de type tient à l'exécution.
    private func load(shouldFail: Bool) {
        demoState = .loading
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if shouldFail {
                demoState = .failed(
                    LoadFailure(
                        title: "Impossible de charger",
                        message: "Le serveur n'a pas répondu. Cette erreur est simulée."
                    ),
                    retry: { load(shouldFail: false) }
                )
            } else {
                demoState = .loaded(
                    PrismDemoPayload(
                        headline: "Chargé",
                        detail: "Le scaffold a rendu les quatre états sans une ligne de logique "
                            + "dans la vue."
                    )
                )
            }
        }
    }

    // MARK: 2 et 3. Les contrôles flottent, et le mouvement est continu

    /// La barre flottante.
    ///
    /// **Elle n'a pas de fond de verre à elle** : chaque pilule porte son
    /// propre verre, et le `PrismGlassGroup` les fait fusionner en
    /// s'approchant. C'est le motif documenté par Apple, et cela évite le
    /// verre sur verre qu'Apple interdit explicitement.
    private var floatingControls: some View {
        PrismGlassGroup(spacing: 28) {
            HStack(spacing: PrismSpace.sm) {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
                        isFilterExpanded.toggle()
                    }
                } label: {
                    Label(
                        isFilterExpanded ? "Fermer" : selectedTrack.band.name.capitalized,
                        systemImage: isFilterExpanded ? "xmark" : "circle.hexagongrid.fill"
                    )
                }
                .buttonStyle(PrismControlButtonStyle())
                .prismGlassID("filtre", in: glassNamespace)

                if isFilterExpanded {
                    ForEach(Array(ShowcaseTrack.sample.prefix(3))) { track in
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) {
                                selectedTrack = track
                                isFilterExpanded = false
                            }
                        } label: {
                            Text(track.band.name)
                        }
                        .buttonStyle(PrismControlButtonStyle())
                        .prismGlassID("bande-\(track.id)", in: glassNamespace)
                    }
                }
            }
        }
        .accessibilityLabel("Contrôles de parcours")
    }

    // MARK: Pied

    private var footer: some View {
        Text(
            "Cible iOS 17.0 · Xcode 26.6 · Swift 6 · aucune dépendance externe.\n"
                + "Liquid Glass actif à partir d'iOS 26 ; matériaux standard en deçà.\n"
                + "Projet Xcode généré par XcodeGen — voir apps/ios/DEMARRAGE.md."
        )
        .prismType("labelSmall")
        .foregroundStyle(textSecondary)
    }

    // MARK: Gabarit de section — couche de CONTENU

    @ViewBuilder
    private func section(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: PrismSpace.sm) {
            HStack(alignment: .firstTextBaseline, spacing: PrismSpace.xs) {
                Text(title)
                    .prismType("headlineSmall")
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .prismType("labelMedium")
                    .foregroundStyle(textSecondary)
            }
            content()
                .padding(PrismSpace.cardInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Couche de contenu : matériau standard, **pas** Liquid Glass.
                // Apple : « Don't use Liquid Glass in the content layer. »
                .prismContent(
                    in: RoundedRectangle(cornerRadius: PrismRadius.lg, style: .continuous))
        }
    }
}

#Preview("Prism — clair") {
    PrismShowcaseView()
}

#Preview("Prism — sombre") {
    PrismShowcaseView()
        .preferredColorScheme(.dark)
}

#Preview("Prism — texte agrandi") {
    PrismShowcaseView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
