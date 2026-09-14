// NON COMPILÉ SUR WINDOWS — voir apps/ios/DEMARRAGE.md.
//
// ⚠️ FICHIER LE PLUS FRAGILE DU SQUELETTE, ET C'EST VOLONTAIRE.
//
// Toute l'API Liquid Glass d'iOS 26 est confinée ici, et nulle part ailleurs.
// Raison : ces appels ont été écrits depuis Windows, contre une documentation.
// Si l'un d'eux est faux, **il y a exactement un fichier à corriger**, et le
// reste du squelette compile quand même.
//
// ─────────────────────────────────────────────────────────────────────────────
// POURQUOI `#if os(iOS)` ET PAS SEULEMENT `#available`
//
// Première erreur de compilation réelle, remontée du Mac le 2026-09-14 :
//
//     error: 'onScrollDown' is unavailable in macOS
//     note: @available(macOS, unavailable)
//
// `#available(iOS 26.0, macOS 26.0, *)` teste une **version**. Il ne peut pas
// couvrir une **indisponibilité de plateforme** : `.onScrollDown` n'est pas
// « absent avant macOS 26 », il est absent de macOS, définitivement. La garde
// portait sur le mauvais axe.
//
// Les deux directives ne résolvent pas le même problème et ne sont pas
// interchangeables :
//
//   `#if os(iOS)`   — COMPILATION. Le code n'existe pas hors iOS. C'est ce
//                     qu'il faut pour un symbole absent d'une plateforme.
//   `#available`    — EXÉCUTION. Le code existe mais peut être trop récent
//                     pour l'appareil. C'est ce qu'il faut pour iOS 17 vs 26.
//
// **Il faut les deux, imbriquées**, et c'est ce que fait ce fichier.
//
// ─────────────────────────────────────────────────────────────────────────────
// POURQUOI macOS APPARAÎT ICI ALORS QUE CERTIGO EST UNE APP iOS
//
// `Package.swift` déclare `.macOS(.v14)` pour **une seule raison** : permettre
// à `swift test` de tourner sans simulateur, ce qui donne une boucle rouge/vert
// rapide. **macOS n'est pas une cible produit.** Aucun rendu n'y est jugé.
//
// Conséquence assumée : sur macOS, tout ce qui suit retombe sur les matériaux
// standard. C'est sans importance — et c'est pourquoi ce fichier garde
// **largement**, y compris des symboles dont la documentation annonce une
// disponibilité macOS. Un effet visuel perdu sur une plateforme qui ne sert
// qu'aux tests ne coûte rien ; un aller-retour avec le Mac coûte une demi-heure.
//
// ─────────────────────────────────────────────────────────────────────────────
// Signatures relevées le 2026-09-11 dans les données DocC d'Apple, et non de
// mémoire :
//   glassEffect(_:in:)          défaut = .regular, DefaultGlassEffectShape()
//   Glass.regular/.clear/.identity, .tint(_:), .interactive(_:)
//   GlassEffectContainer(spacing:content:)   spacing est CGFloat? = nil
//   glassEffectID(_:in:)        l'identifiant est Optional
//   scrollEdgeEffectStyle(_:for:)  style Optional, edges = Edge.Set, SANS défaut
//   ScrollEdgeEffectStyle est une STRUCT (.automatic/.hard/.soft), pas un enum
//   buttonStyle(.glass) / .glassProminent
//
// Deux règles d'Apple que ce fichier fait respecter par construction :
//   1. « Don't use Liquid Glass in the content layer. » → `prismGlass` est
//      réservé à la couche de contrôle ; le contenu passe par `prismContent`.
//   2. « Always avoid glass on glass. » → on n'empile jamais les deux.

import SwiftUI

/// Applique le matériau Liquid Glass, ou son repli.
///
/// Réservé à la **couche de contrôle** : barres flottantes, boutons, contrôles
/// posés au-dessus du contenu. Apple demande explicitement de ne pas
/// l'utiliser dans la couche de contenu.
public struct PrismGlassModifier<S: Shape>: ViewModifier {
    /// Apple gère automatiquement « Réduire la transparence » pour son propre
    /// matériau. Cette valeur ne sert donc **que** sur le chemin de repli, où
    /// le matériau est le nôtre.
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let tint: Color?
    let interactive: Bool
    let shape: S
    let opaqueFallback: Color

    @ViewBuilder
    public func body(content: Content) -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                // Le système applique lui-même « Réduire la transparence »,
                // « Augmenter le contraste » et « Réduire les animations » sur
                // le matériau natif. Le refaire à la main le dégraderait.
                content.glassEffect(Self.verre(tint: tint, interactive: interactive), in: shape)
            } else {
                repli(content)
            }
        #else
            repli(content)
        #endif
    }

    /// Le chemin sans Liquid Glass : iOS antérieur à 26, et toute plateforme
    /// hors iOS. Ici le matériau est le nôtre, donc l'accessibilité est à notre
    /// charge.
    @ViewBuilder
    private func repli(_ content: Content) -> some View {
        if reduceTransparency {
            content.background(opaqueFallback, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }

    #if os(iOS)
        @available(iOS 26.0, *)
        private static func verre(tint: Color?, interactive: Bool) -> Glass {
            var valeur = Glass.regular
            if let tint { valeur = valeur.tint(tint) }
            if interactive { valeur = valeur.interactive() }
            return valeur
        }
    #endif
}

extension View {
    /// Couche de **contrôle** : Liquid Glass sur iOS 26, matériau fin avant.
    ///
    /// La teinte passe par `Glass.tint(_:)` et jamais par un `background`
    /// coloré : Apple calcule une plage de tons appliquée à la luminosité du
    /// contenu dessous, alors qu'un aplat est opaque et « casse le caractère
    /// visuel de Liquid Glass ».
    public func prismGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        opaqueFallback: Color = Color(prism: PrismPalette.lightSurface),
        in shape: some Shape = Capsule()
    ) -> some View {
        modifier(
            PrismGlassModifier(
                tint: tint,
                interactive: interactive,
                shape: shape,
                opaqueFallback: opaqueFallback
            )
        )
    }

    /// Couche de **contenu** : matériaux standard, jamais Liquid Glass.
    ///
    /// Apple : « Don't use Liquid Glass in the content layer. » Les quatre
    /// matériaux standard restent la bonne réponse, y compris sur iOS 26 — ils
    /// ne sont pas dépréciés. Disponibles sur toutes les plateformes depuis
    /// iOS 15 / macOS 12, donc aucune garde n'est nécessaire ici.
    public func prismContent(in shape: some Shape) -> some View {
        background(.regularMaterial, in: shape)
    }

    /// Identifiant de morphing, pour qu'une forme de verre s'étire vers la
    /// suivante au lieu de disparaître puis réapparaître.
    ///
    /// Sans effet hors iOS 26, où la transition retombe sur l'animation
    /// SwiftUI ordinaire.
    @ViewBuilder
    public func prismGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                glassEffectID(id, in: namespace)
            } else {
                self
            }
        #else
            self
        #endif
    }

    /// Le fondu du contenu qui passe sous une barre flottante.
    ///
    /// `.soft` donne « une frontière floue et subtile entre les contrôles
    /// épinglés et le contenu qui défile ». C'est ce qui évite que le texte
    /// vienne buter net contre la barre.
    @ViewBuilder
    public func prismScrollEdge(_ edges: Edge.Set = .all) -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                scrollEdgeEffectStyle(.soft, for: edges)
            } else {
                self
            }
        #else
            self
        #endif
    }

    /// Réduit la barre d'onglets quand l'utilisateur descend, comme Apple
    /// Music.
    ///
    /// ⚠️ **`TabBarMinimizeBehavior.onScrollDown` est marqué
    /// `@available(macOS, unavailable)`** — pas « trop récent pour macOS » :
    /// absent de macOS. C'est le symbole qui a produit la première erreur de
    /// compilation réelle de ce squelette, parce que la garde d'origine testait
    /// une version au lieu d'une plateforme.
    @ViewBuilder
    public func prismTabBarMinimize() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabBarMinimizeBehavior(.onScrollDown)
            } else {
                self
            }
        #else
            self
        #endif
    }
}

/// Regroupe plusieurs formes de verre pour qu'elles fusionnent en approchant.
///
/// Sur iOS 26, c'est un vrai `GlassEffectContainer` — « SwiftUI rend les effets
/// ensemble, ce qui améliore les performances de rendu ». Ailleurs, c'est une
/// simple pile transparente.
public struct PrismGlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    public init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: spacing) { content }
            } else {
                content
            }
        #else
            content
        #endif
    }
}

/// Style de bouton de la couche de contrôle.
///
/// Sur iOS 26 c'est le matériau natif ; ailleurs, le bouton Prism plein.
public struct PrismControlButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        let etiquette =
            configuration.label
            .prismType("labelLarge")
            .padding(.horizontal, PrismSpace.md)
            .padding(.vertical, PrismSpace.xs)

        #if os(iOS)
            if #available(iOS 26.0, *) {
                // Le contenu posé sur le verre `regular` bascule clair/sombre
                // tout seul pour maximiser son contraste. Forcer
                // `foregroundStyle` casserait précisément ce comportement.
                etiquette
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
                    .animation(
                        reduceMotion ? nil : .snappy(duration: 0.16),
                        value: configuration.isPressed)
            } else {
                repli(etiquette, enfonce: configuration.isPressed)
            }
        #else
            repli(etiquette, enfonce: configuration.isPressed)
        #endif
    }

    @ViewBuilder
    private func repli(_ etiquette: some View, enfonce: Bool) -> some View {
        etiquette
            .foregroundStyle(Color(prism: PrismPalette.lightSurface))
            .background(Color(prism: PrismPalette.primary), in: Capsule())
            .scaleEffect(reduceMotion ? 1 : (enfonce ? 0.97 : 1))
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: enfonce)
    }
}
