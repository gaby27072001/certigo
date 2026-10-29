import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
import Prism
import Testing

@Suite("Lot O — 1-for-1 Surgical Parity Between Figma Pro Ground Truth (49 Page 01 + 4 System/Resilience Screens) and SwiftUI")
struct FigmaExactScreenParityTests {

    @Test("All 49 Page 01 Figma Pro ground-truth screens exist with exact nodeIds, frame names, and verbatim texts")
    func all49Page01GroundTruthScreensMatchFigmaProJsonWordForWord() throws {
        #expect(CertiGoFigmaExactScreenParity.page01Screens.count == 49)
        #expect(CertiGoFigmaExactScreenParity.systemAndResilienceScreens.count == 4)
        #expect(CertiGoFigmaExactScreenParity.allScreens.count == 53)
        #expect(CertiGoFigmaExactScreenParity.verifyAllGroundTruthScreens())

        let expectedNodeIds: Set<String> = [
            "37:375", "42:375", "49:368", "58:705", "73:332", "62:346",
            "26:807", "26:826", "26:863", "26:890", "26:912", "26:939", "26:1009",
            "73:393", "73:442", "73:509", "73:575", "73:743",
            "73:818", "73:898", "73:958", "73:1019", "73:1070",
            "79:332", "78:332", "81:345", "85:317",
            "88:317", "89:317", "97:287", "97:417", "97:498", "97:636",
            "132:182", "132:264", "132:339", "132:438", "132:519",
            "132:581", "132:651", "132:759", "132:877", "132:945", "132:1009",
            "142:385", "142:478", "142:540", "144:137", "145:122"
        ]
        #expect(expectedNodeIds.count == 49)
        #expect(Set(CertiGoFigmaExactScreenParity.page01Screens.map(\.nodeId)) == expectedNodeIds)

        let expectedGroundTruthByNodeId: [String: (name: String, texts: [String])] = [
            "26:807": (
                name: "15 · Carte Déclic Visuelle (Micro-Leçon 20s)",
                texts: [
                    "✕", "5", "CONTINUER", "COMMENT VERROUILLER L'ISOLATION À 100 %",
                    "✕  Internet Public  ➔  publicNetworkAccess: Disabled",
                    "✓  VNet (10.0.2.4)  ➔  privatelink.blob.core.windows.net",
                    "1. Désactive l'accès réseau public",
                    "Passe la propriété publicNetworkAccess sur « Disabled » dans le pare-feu de la ressource PaaS.",
                    "2. Lie la zone DNS Privée au VNet",
                    "Crée un Virtual Network Link vers privatelink.* pour résoudre le FQDN en IP privée 10.x.",
                    "💡 CARTE DÉCLIC · MICRO-LEÇON 20 SEC",
                    "« Attention au piège : créer un Private Endpoint ne désactive PAS l'accès public par défaut ! »"
                ]
            ),
            "26:826": (
                name: "16 · Exercice Grille 2×2 Visuelle (Duolingo 3D)",
                texts: [
                    "✕", "5",
                    "Lequel de ces services fournit l'orchestration d'agents IA et le RAG vectoriel dans Azure ?",
                    "Azure AI Foundry", "AWS VPC", "Kubernetes CKA", "Azure VNet", "VÉRIFIER"
                ]
            ),
            "26:863": (
                name: "17 · Exercice Constructeur CLI & Code",
                texts: [
                    "✕", "5",
                    "Complète la commande Azure CLI pour créer le lien DNS privé sans auto-enregistrement :",
                    "1  az network private-dns link vnet create \\\n2    -g rg-prod \\\n3    -z privatelink.blob.core.windows.net \\\n4    -v vnet-hub -e false",
                    "link vnet create", "-e false", "--public-ip true", "zone delete", "VÉRIFIER"
                ]
            ),
            "26:890": (
                name: "18 · Validation Réussie + Bouton IA [✦ EXPLIQUER MA RÉPONSE]",
                texts: [
                    "✕", "5", "✓  Excellent ! Bonne réponse", "EXPLIQUER MA RÉPONSE", "CONTINUER",
                    "✓  Un alias CNAME vers privatelink.blob.core.windows.net",
                    "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ",
                    "Quel enregistrement DNS redirige automatiquement le nom public vers la zone privatelink ?"
                ]
            ),
            "26:912": (
                name: "19 · Célébration de Fin d'Étape (Coussin 3D Validé ✓, Précision 94 % & Série)",
                texts: [
                    "Étape terminée !", "Private Endpoint & DNS privé maîtrisé",
                    "RYTHME", "14 sec ⚡", "PRÉCISION", "94 %", "SÉRIE", "12 j 🔥",
                    "RETOUR AU PARCOURS", "✓"
                ]
            ),
            "26:939": (
                name: "20 · Réponse IA & Comparateur Côte-à-Côte",
                texts: [
                    "←   Comparer 2 services Azure",
                    "Service Endpoint",
                    "• Garde l'IP publique du service PaaS\n\n• Pas besoin de DNS privé\n\n• Non routable depuis On-Premises (VPN / ExpressRoute)",
                    "Private Endpoint",
                    "• Crée une NIC avec IP privée (10.x) dans ton Subnet\n\n• Requiert une zone privatelink\n\n• Accessible depuis On-Premises",
                    "✓ RÈGLE D'OR POUR L'EXAMEN AZ-104",
                    "Dès que l'énoncé mentionne « depuis On-Premises via ExpressRoute » ou « IP privée 10.x », choisis toujours Private Endpoint !",
                    "Parcours", "Examens", "Social", "Moi"
                ]
            ),
            "26:1009": (
                name: "22 · Lancement Examen Blanc (Feuille Apple Pay + Vrai Blason Officiel AZ-104)",
                texts: [
                    "Parcours", "Examens", "Social", "Moi", "Examens · AZ-104", "AZ-104 ▾",
                    "CONDITIONS PEARSON VUE", "Examen Blanc Complet (50 Q)",
                    "90 min · Seuil 700/1000 · Dernier : 785 ✓",
                    "DÉMARRER L'EXAMEN COMPLET", "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104",
                    "1. Identité & Gouvernance Entra ID", "Poids officiel : 20–25 %", "88 %",
                    "2. Stockage & Sécurité des données", "Poids officiel : 15–20 %", "82 %",
                    "3. Déploiement Calcul, VM & AKS"
                ]
            ),
            "37:375": (
                name: "01 · Accueil Fondateur (Îlots Waymo + Rail Mimo Logos 3D)",
                texts: [
                    "✓", "Concepts Cloud Azure", "✓", "Identité Entra ID", "CONTINUER",
                    "Rôles RBAC & PIM", "🧪 MINI-LAB PRATIQUE", "Réparer un accès RBAC refusé",
                    "▶", "Accès Conditionnel", "AZ-104 ▾", "🔥 14", "💎 480", "❤️ 5", "65%",
                    "UNITÉ 1 · Identité Entra ID", "📖", "Parcours"
                ]
            ),
            "42:375": (
                name: "02 · Popover Flottant (Logos Officiels + Nom Actif Seul)",
                texts: [
                    "✓", "Concepts Cloud Azure", "✓", "Identité Entra ID", "CONTINUER",
                    "Rôles RBAC & PIM", "🧪 MINI-LAB PRATIQUE", "Réparer un accès RBAC refusé",
                    "▶", "Accès Conditionnel", "AZ-104 ▾", "🔥 14", "💎 480", "❤️ 5", "65%",
                    "UNITÉ 1 · Identité Entra ID", "📖", "Parcours"
                ]
            ),
            "49:368": (
                name: "03 · Feuille Flottante Épurée (Mix B+C : Haut Centré + 3 Boutons [📖 | COMMENCER | ✦])",
                texts: [
                    "✓", "Concepts Cloud Azure", "✓", "Identité Entra ID", "CONTINUER",
                    "Rôles RBAC & PIM", "🧪 MINI-LAB PRATIQUE", "Réparer un accès RBAC refusé",
                    "▶", "Accès Conditionnel", "AZ-104 ▾", "🔥 14", "💎 480", "❤️ 5", "65%",
                    "UNITÉ 1 · Identité Entra ID", "📖", "Parcours"
                ]
            ),
            "58:705": (
                name: "14 · Fiche Mémo Dépliée (Structure C Tableau Apple Pay : Activité · Sujets Clés · Règle d'Or)",
                texts: [
                    "✓", "Concepts Cloud Azure", "✓", "Identité Entra ID", "CONTINUER",
                    "Rôles RBAC & PIM", "🧪 MINI-LAB PRATIQUE", "Réparer un accès RBAC refusé",
                    "▶", "Accès Conditionnel", "AZ-104 ▾", "🔥 14", "💎 480", "❤️ 5", "65%",
                    "UNITÉ 1 · Identité Entra ID", "📖", "Parcours"
                ]
            ),
            "62:346": (
                name: "05 · Feuille Flottante d'Explication IA (Mix B+D : 3 Cartes Colorées sur Question + [✦ Question IA | CONTINUER])",
                texts: [
                    "✕", "❤️ 4", "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ", "ISOLATION PAAS · PRIVATE LINK",
                    "Une VM dans VNet-Prod doit lire un coffre Key Vault via une IP privée 10.0.2.4 sans exposition Internet.",
                    "B", "Lecteur (Reader)", "✓", "C", "Propriétaire (Owner)", "D",
                    "Administrateur de l'accès utilisateur", "✕", "Pas tout à fait...",
                    "Bonne réponse : Lecteur (Reader)", "EXPLIQUER MON ERREUR", "J'AI COMPRIS",
                    "Explication de ta réponse"
                ]
            ),
            "73:332": (
                name: "04 · Exercice Flashcard Empilée Duolingo (Possibilité 4 Validée)",
                texts: [
                    "4", "Contributeur (Contributor)", "Lecteur (Reader)", "Propriétaire (Owner)",
                    "Administrateur de l'accès", "✕", "Incorrect · Bonne réponse : Lecteur",
                    "EXPLIQUER MON ERREUR", "CONTINUER", "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ",
                    "Une VM dans VNet-Prod doit lire un coffre Key Vault via une IP privée 10.0.2.4 sans exposition Internet.\nQuel service déploies-tu ?"
                ]
            ),
            "73:393": (
                name: "Q_TYPE_01 · QCM Scénario & Pilule Bleu Ciel (Possibilité 4)",
                texts: [
                    "5", "Rôles RBAC & PIM", "Contributeur (Contributor)", "Lecteur (Reader)",
                    "Propriétaire (Owner)", "Administrateur de l'accès", "VÉRIFIER",
                    "Un auditeur externe doit vérifier toutes les ressources d'un abonnement Azure en lecture seule.\nQuel rôle intégré lui attribuer ?"
                ]
            ),
            "73:442": (
                name: "Q_TYPE_02 · Sélection de Symboles de Services (Grille 2×2)",
                texts: [
                    "5", "Sécurité Azure", "Key Vault", "Entra ID", "Azure Firewall", "Blob Storage",
                    "VÉRIFIER",
                    "Quel service Azure permet de stocker les clés cryptographiques et certificats TLS dans un coffre matériel ?"
                ]
            ),
            "73:509": (
                name: "Q_TYPE_03 · Schéma d'Architecture Interactif",
                texts: [
                    "5", "Architecture VNet", "Quelle brique placer dans l'emplacement [ ? ]",
                    "pour filtrer le trafic HTTPS (WAF Couche 7)", "🌐", "Clients", "HTTPS", "➔", "?",
                    "Couche 7", "+ WAF", "➔", "VNet Privé", "App Web",
                    "Flux : Internet ➔ Inspection WAF L7 ➔ VNet",
                    "Azure Application Gateway (WAF)", "Azure Load Balancer (Couche 4 TCP/UDP)",
                    "Azure NAT Gateway"
                ]
            ),
            "73:575": (
                name: "Q_TYPE_04 · Saisie au Clavier iOS",
                texts: [
                    "5", "Azure CLI", "az group", "lock", "create", "--lock-type CanNotDelete -g RG-Prod",
                    "VÉRIFIER", "\"lock\"", "lock", "list", "A", "Z", "E", "R", "T", "Y", "U", "I"
                ]
            ),
            "73:743": (
                name: "Q_TYPE_05 · Assemblage de Briques (Word Bank)",
                texts: [
                    "5", "PowerShell & CLI", "az", "network", "vnet", "create", "--name ProdVNet",
                    "-g RG-Core", "delete", "vm", "--sku Basic", "list", "VÉRIFIER",
                    "Construis la commande CLI qui crée le réseau virtuel ProdVNet dans le groupe RG-Core :"
                ]
            ),
            "73:818": (
                name: "Q_TYPE_06 · Paires à Relier (Symboles ↔ Rôles)",
                texts: [
                    "5", "Services Azure", "Entra ID", "Key Vault", "VNet", "Firewall",
                    "Coffre de secrets & clés", "Identité & SSO", "Filtrage réseau L3-L7",
                    "Réseau virtuel isolé", "VÉRIFIER",
                    "Associe chaque symbole de service Cloud à sa fonction exacte :"
                ]
            ),
            "73:898": (
                name: "Q_TYPE_07 · Diagnostic d'Erreur dans une Règle JSON",
                texts: [
                    "5", "Rôles Personnalisés", "1", "\"Name\": \"VM Audit Reader\",", "2",
                    "\"IsCustom\": true,", "3", "\"Actions\": [ \"Microsoft.Compute/*/read\" ],", "4",
                    "\"NotActions\": [ \"*\" ],", "5", "\"AssignableScopes\": [ \"/subscriptions/sub-1\" ]",
                    "VÉRIFIER",
                    "Ce rôle personnalisé doit uniquement lire les VMs. Touche la ligne JSON qui bloque tout :"
                ]
            ),
            "73:958": (
                name: "Q_TYPE_08 · Classer dans l'Ordre (Hiérarchie Scope)",
                texts: [
                    "5", "Gouvernance Azure", "1", "Groupe d'administration",
                    "Management Group (Multi-abonnements)", "≡", "2", "Abonnement (Subscription)",
                    "Facturation & limites globales", "≡", "3", "Groupe de ressources",
                    "Conteneur logique de cycle de vie", "≡", "4", "Ressource individuelle",
                    "Ex. Machine virtuelle, Key Vault, VNet", "≡"
                ]
            ),
            "73:1019": (
                name: "Q_TYPE_09 · Verdict Architecture (Autorisé vs Bloqué)",
                texts: [
                    "5", "Verrous Azure", "Alice pourra-t-elle supprimer la base SQL ?",
                    "1. PERMISSION RBAC D'ALICE", "✓  Rôle « Propriétaire (Owner) » sur l'abonnement",
                    "2. VERROU SUR LE GROUPE DE RESSOURCES", "🔒  Verrou « CanNotDelete » actif sur RG-Prod",
                    "3. ACTION TENTÉE PAR ALICE", "Supprimer la ressource « sql-prod-db »", "✓",
                    "AUTORISÉ", "Owner est prioritaire", "🔒", "BLOQUÉ", "Le verrou s'applique", "VÉRIFIER"
                ]
            ),
            "73:1070": (
                name: "Q_TYPE_10 · Multi-Sélection à Cases à Cocher",
                texts: [
                    "5", "Entra ID PIM", "Authentification multifacteur (MFA)", "✓",
                    "Justification métier + approbation", "✓", "Redémarrage du contrôleur de domaine",
                    "Suppression du groupe de ressources", "VÉRIFIER",
                    "Quelles vérifications peux-tu exiger lors de l'activation d'un rôle Entra PIM ? (Choisis 2 réponses)"
                ]
            ),
            "78:332": (
                name: "06B · Réponse Écrite Style Gemini (avec Bouton Historique & Barre Vocale)",
                texts: [
                    "Quelle est la différence entre RBAC et Azure Policy ?", "CertiGo IA",
                    "Ces deux services assurent la gouvernance Azure, mais ils agissent sur deux dimensions différentes :",
                    "•  Azure RBAC (Qui fait quoi) : Gère les accès des utilisateurs et groupes en attribuant des rôles (Lecteur, Contributeur, Propriétaire).",
                    "•  Azure Policy (Sous quelles règles) : Vérifie la conformité des ressources elles-mêmes (ex. imposer une région ou un tag obligatoire).",
                    "💡  À retenir pour l'examen AZ-104 :",
                    "•  Priorité des règles : Même un utilisateur Propriétaire (Owner) est bloqué si une Azure Policy interdit la région choisie.",
                    "•  Cumul : Un utilisateur doit être autorisé à la fois par son rôle RBAC et par les stratégies Azure Policy actives.",
                    "Si tu veux, je peux te montrer un exemple JSON ou te poser une question type examen sur ce sujet.",
                    "Copier", "📖  Sauver en Mémo", "🎯 Quiz", "+", "Demander à CertiGo IA..."
                ]
            ),
            "79:332": (
                name: "06 · Accueil Hub IA (Style Gemini + Suggestions + Barre Écrit & Vocal [ılı])",
                texts: [
                    "Bonjour Gabriel,", "Comment veux-tu réviser aujourd'hui ?", "📘",
                    "Explique-moi RBAC vs Azure Policy", "Synthèse claire + astuce d'examen AZ-104", "🎙️",
                    "Simuler un entretien oral à voix haute", "Mode Conversation Vocale Live avec l'IA",
                    "🎯", "Analyse mes 3 dernières erreurs", "Diagnostic ciblé sur tes points faibles",
                    "⚡", "Génère un exemple Azure CLI commenté", "Commandes prêtes pour le lab pratique",
                    "+", "Écrire ou parler à CertiGo IA...", "Parcours", "Examens"
                ]
            ),
            "81:345": (
                name: "06C · Conversation Vocale Live (Option 1 : Logo IA Animé + Texte Épuré + Indicateur Voix Utilisateur Central)",
                texts: [
                    "« Et si je suis Propriétaire mais qu'une Azure Policy bloque la région ? »",
                    "C'est toujours l'Azure Policy qui l'emporte. Même avec le rôle Propriétaire, la création sera refusée tant que la région ne respecte pas la règle..."
                ]
            ),
            "85:317": (
                name: "06D · Historique des Conversations IA (Choix A : Tiroir Push Claude 85% Largeur)",
                texts: [
                    "Quelle est la différence entre RBAC et Azure Policy ?", "CertiGo IA",
                    "Ces deux services assurent la gouvernance Azure, mais ils agissent sur deux dimensions différentes :",
                    "•  Azure RBAC (Qui fait quoi) : Gère les accès des utilisateurs et groupes en attribuant des rôles (Lecteur, Contributeur, Propriétaire).",
                    "•  Azure Policy (Sous quelles règles) : Vérifie la conformité des ressources elles-mêmes (ex. imposer une région ou un tag obligatoire).",
                    "💡  À retenir pour l'examen AZ-104 :",
                    "•  Priorité des règles : Même un utilisateur Propriétaire (Owner) est bloqué si une Azure Policy interdit la région choisie.",
                    "•  Cumul : Un utilisateur doit être autorisé à la fois par son rôle RBAC et par les stratégies Azure Policy actives.",
                    "Si tu veux, je peux te montrer un exemple JSON ou te poser une question type examen sur ce sujet.",
                    "Copier", "📖  Sauver en Mémo", "🎯 Quiz", "+", "Demander à CertiGo IA...",
                    "CertiGo IA", "🔍   Rechercher une discussion...", "Épinglées",
                    "Différence RBAC vs Azure Policy"
                ]
            ),
            "88:317": (
                name: "07 · Onglet Social : Podium 3D Semaine (Variante A Validée)",
                texts: [
                    "Social", "⏳ Semaine · 3j", "Ajouter", "🏆 Podium Semaine", "👥 Mes Amis (12)",
                    "SL", "2", "Sarah L.", "14 étapes", "2e", "GC", "1", "Toi (Gabriel)",
                    "19 étapes · 🔥14", "1er", "TM", "3", "Thomas M."
                ]
            ),
            "89:317": (
                name: "25 · Onglet Social : Vue « Mes Amis (12) & Ajouter un Ami » (Variante A)",
                texts: [
                    "Social", "⏳ Semaine · 3j", "Ajouter", "Parcours", "Examens", "Social", "Moi",
                    "🏆 Podium Semaine", "👥 Mes Amis (12)", "🔍   Chercher ou ajouter un pseudo...",
                    "🔗  Partager mon lien d'invitation d'ami", "Copier",
                    "EN LIGNE / ACTIFS AUJOURD'HUI", "SL", "Sarah Laurent",
                    "En train de réviser GCP ACE · 🔥 18j", "👋 Salut", "TM"
                ]
            ),
            "97:287": (
                name: "08 · Onglet Moi (Variante A : Stylo Photo + Bouton Statistiques Pro + Vrais Blasons Officiels)",
                texts: [
                    "Mon Profil", "GC", "Gabriel Chambaud", "@gabriel  ·  Membre CertiGo PRO",
                    "14 jours", "Série active", "42 étapes", "Chapitres validés", "1er (Or)",
                    "Podium Semaine", "Voir mes Statistiques & Analyses Pro", "➔",
                    "CERTIFICATIONS PROFESSIONNELLES", "Microsoft AZ-104",
                    "Azure Administrator Associate · 12/18", "65%", "Microsoft AZ-900",
                    "Azure Fundamentals · Certifié ✓"
                ]
            ),
            "97:417": (
                name: "26 · Détail Certification avec Vrai Blason Officiel Microsoft Associate",
                texts: [
                    "←  Moi", "Détail Certification", "MICROSOFT CERTIFIED ASSOCIATE",
                    "Azure Administrator (AZ-104)", "PROGRESSION PARCOURS", "65 % (12/18)",
                    "DERNIER EXAMEN BLANC", "760 / 1000 ✓", "MAÎTRISE PAR DOMAINE OFFICIEL",
                    "1. Identité & Gouvernance Entra ID", "85%", "2. Stockage & Comptes Azure", "72%",
                    "3. Calcul & Conteneurs (VMs / AKS)", "64%", "4. Réseaux Virtuels (VNet / DNS)",
                    "45%", "🎓  Partager ma progression sur LinkedIn"
                ]
            ),
            "97:498": (
                name: "08B-1 · Statistiques Pro (Haut : Forme 84 %, Radar 5 Axes, Télémétrie & Heatmap)",
                texts: [
                    "←  Moi", "Statistiques Pro", "30 jours ▾", "84%", "INDICE DE FORME EXAMEN",
                    "Prêt pour l'examen AZ-104", "📈 +12 % cette semaine · Seuil officiel dépassé",
                    "⚡ Top 4 % des candidats", "RADAR DE COMPÉTENCES TECHNIQUES",
                    "Identité (92%)", "Stockage\n(84%)", "Calcul (78%)", "Réseau (58%)", "Sécurité\n(88%)",
                    "88 %", "Précision globale", "+6% vs sem. dernière", "14 sec"
                ]
            ),
            "97:636": (
                name: "08B-2 · Statistiques Pro (Bas en défilant : 3 Anneaux, Courbe /1000 & Forces/Faiblesses)",
                texts: [
                    "←  Moi", "Statistiques Pro", "30 jours ▾", "ANNEAUX DE PERFORMANCE",
                    "●  Régularité : 18 / 15 min/j", "●  Précision QCM : 88 % (Cible 80%)",
                    "●  Labs & Oral IA : 6 / 5 séances", "PROGRESSION EXAMEN (/1000)", "810 / 1000",
                    "Seuil de réussite officiel (700)",
                    "Sem. 1 (540)          Sem. 2 (640)          Sem. 3 (730)          Sem. 4 (810)",
                    "DIAGNOSTIC DE TON COACH IA", "💪 POINTS FORTS",
                    "• Entra ID & RBAC\n  94 % de réussite\n\n• Azure Policy\n  91 % de réussite\n\n• Key Vault & KMS\n  89 % de réussite",
                    "🎯 À TRAVAILLER",
                    "• VNet Peering & BGP\n  54 % de réussite\n\n• App Gateway WAF\n  61 % de réussite",
                    "⚡ Cibler en 5 min", "Parcours"
                ]
            ),
            "132:182": (
                name: "OB_01 · Étape 1 : Ouverture (Design 4 + Vrai Logo AWS + Multi-Parcours & Veille IA)",
                texts: [
                    "CertiGo", "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.",
                    "Suis plusieurs parcours en parallèle : certifications officielles, acteurs majeurs de l'IA et nouveautés Tech ajoutées chaque semaine.",
                    "Multi-Parcours", "En parallèle", "Certifs + IA", "Veille & Acteurs",
                    "Nouveautés 🔄", "Chaque semaine", "C'EST PARTI !", "J'AI DÉJÀ UN COMPTE"
                ]
            ),
            "132:264": (
                name: "OB_02 · Étape 2 : Objectifs (Certifications + Veille IA & Nouvelles Tech)",
                texts: [
                    "←", "1/7", "CHOIX MULTIPLE POSSIBLE", "Qu'est-ce qui t'amène sur CertiGo ?",
                    "Tu peux combiner certifications officielles et veille sur les nouvelles avancées Tech & IA.",
                    "🎓", "Décrocher 1 ou plusieurs certifications",
                    "Microsoft, AWS, Google Cloud, GitHub ou Cisco", "✓", "✦",
                    "Me tenir à jour sur l'IA & la Tech",
                    "Maîtriser les acteurs de l'IA (OpenAI, Claude, Foundry…)", "✓", "🚀",
                    "Accélérer ma carrière & mes projets",
                    "Pratiquer sur des cas réels d'architecture & CLI", "🏢",
                    "Valider des compétences en entreprise"
                ]
            ),
            "132:339": (
                name: "OB_03A · Étape 3A : Choisir Plusieurs Certifications en Parallèle (Vrai Logo AWS)",
                texts: [
                    "←", "2/7", "🔀 MULTI-PARCOURS : SUIS PLUSIEURS CERTIFS EN PARALLÈLE",
                    "Quelles certifications veux-tu  ?", "Microsoft", "PARCOURS 1 ACTIF",
                    "AZ-104 · Azure Administrator",
                    "Microsoft · Réseaux VNet, Entra ID, Stockage & Calcul", "✓",
                    "PARCOURS 2 EN PARALLÈLE", "SAA-C03 · Solutions Architect",
                    "AWS · Architecture résiliente, VPC, S3 & IAM", "✓", "PARCOURS 3 EN PARALLÈLE",
                    "GitHub Copilot & AI Dev", "GitHub · IA générative, Prompting & Sécurité du code",
                    "✓", "DÉBUTANT · FUNDAMENTALS"
                ]
            ),
            "132:438": (
                name: "OB_03B · Étape 3B (Nouveau) : Cours sur les Acteurs de l'IA, Veille Tech & Catalogue Vivant",
                texts: [
                    "←", "3/7", "✦ BIEN PLUS QU'UNE APP DE CERTIFICATION : RADAR IA & TECH",
                    "Reste à la pointe de l'IA\net des nouvelles Tech.",
                    "En parallèle de tes certifications, quels parcours d'actualité technologique et d'IA veux-tu suivre ?",
                    "🧠", "NOUVEAU · COURS DÉDIÉS", "Les Grands Acteurs & Modèles de l'IA",
                    "OpenAI (GPT/o3), Anthropic Claude, Google Gemini, Mistral & Meta", "✓", "🤖",
                    "AVANCÉES IA EN DIRECT", "Agents IA, MCP & Outils Développeur",
                    "Microsoft Foundry, GitHub Copilot, Serveurs MCP, RAG & Orchestration", "✓", "⚡",
                    "MIS À JOUR CHAQUE SEMAINE", "Radar Hebdo des Nouveautés Cloud"
                ]
            ),
            "132:519": (
                name: "OB_04 · Étape 4 : Calibrage du Niveau & Échéance d'Examen (Validé)",
                texts: [
                    "←", "4/7", "CALIBRAGE SUR-MESURE", "Quel est ton niveau actuel ?", "▮▯▯",
                    "Je débute sur le Cloud & l'IA", "On part des bases visuelles étape par étape.",
                    "▮▮▯", "Intermédiaire (Recommandé)",
                    "Je connais déjà les bases et je veux pratiquer.", "✓", "▮▮▮",
                    "Avancé · Sprint & Examens",
                    "Débloque directement les cas complexes et labs CLI.",
                    "QUAND VISES-TU TA 1re CERTIFICATION ?", "⚡ Dans 30 jours", "Sprint intensif",
                    "🎯 Dans 6 semaines"
                ]
            ),
            "132:581": (
                name: "OB_06A · Étape 5A : Choix du Rythme & Heure du Rappel (Avant Pop-up iOS)",
                texts: [
                    "←", "5/7", "HABITUDE & RÉGULARITÉ", "Fixe ton rythme quotidien",
                    "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                    "5 min / jour", "Régulier · 1 étape / jour", "10 min / jour",
                    "Recommandé · Progression ×3", "20 min / jour", "Intensif · Sprint rapide",
                    "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                    "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                    "CertiGo · Rappel & Radar IA 🔥", "19:30",
                    "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                    "Heure du rappel quotidien", "19 : 30"
                ]
            ),
            "132:651": (
                name: "OB_06B · Pop-up Système Natif iOS 1 : Autorisation des Notifications Push",
                texts: [
                    "←", "5/7", "HABITUDE & RÉGULARITÉ", "Fixe ton rythme quotidien",
                    "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                    "5 min / jour", "Régulier · 1 étape / jour", "10 min / jour",
                    "Recommandé · Progression ×3", "20 min / jour", "Intensif · Sprint rapide",
                    "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                    "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                    "CertiGo · Rappel & Radar IA 🔥", "19:30",
                    "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                    "Heure du rappel quotidien", "19 : 30"
                ]
            ),
            "132:759": (
                name: "OB_06C · Pop-up Système iOS 2 : Ajouter le Widget Série & IA sur l'Écran d'Accueil (Style Duolingo)",
                texts: [
                    "←", "5/7", "HABITUDE & RÉGULARITÉ", "Fixe ton rythme quotidien",
                    "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                    "5 min / jour", "Régulier · 1 étape / jour", "10 min / jour",
                    "Recommandé · Progression ×3", "20 min / jour", "Intensif · Sprint rapide",
                    "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                    "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                    "CertiGo · Rappel & Radar IA 🔥", "19:30",
                    "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                    "Heure du rappel quotidien", "19 : 30"
                ]
            ),
            "132:877": (
                name: "OB_07 · Étape 6 : Plan Épuré & Graphique Comparatif (Avec CertiGo vs Sans CertiGo)",
                texts: [
                    "←", "6/7", "✓ TON PLAN MULTI-PARCOURS EST PRÊT",
                    "3,4× plus rapide\navec la méthode CertiGo.",
                    "Prêt pour l'examen dès le 18 Juin · Veille IA en continu",
                    "MAÎTRISE DES CERTIFICATIONS & DE L'IA", "✦ Avec CertiGo (810+)",
                    "Sans CertiGo (Seul / PDF)", "Aujourd'hui", "Semaine 3", "18 Juin 🎯",
                    "Parcours actifs : AZ-104 · AWS · Acteurs IA 🔄",
                    "🔄 Nouveaux chapitres, examens blancs et cours sur les derniers modèles IA débloqués chaque semaine.",
                    "SAUVEGARDER MON PLAN  →"
                ]
            ),
            "132:945": (
                name: "OB_08A · Étape 7A : Création du Profil en 1 Tap (Épuré sans bandeau en haut)",
                texts: [
                    "←", "7/7", "Crée ton profil pour\nsauvegarder tes parcours",
                    "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.",
                    "   Continuer avec Apple", "Continuer avec Microsoft", "Continuer avec Google",
                    "✉️   Continuer avec mon adresse e-mail",
                    "Explorer ma 1re leçon sans créer de compte  →",
                    "En continuant, tu acceptes les Conditions d'utilisation et la Politique de confidentialité de CertiGo."
                ]
            ),
            "132:1009": (
                name: "OB_08B · Pop-up Système Natif iOS 3 : Feuille « Connexion avec Apple (Face ID) »",
                texts: [
                    "←", "7/7", "Crée ton profil pour\nsauvegarder tes parcours",
                    "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.",
                    "   Continuer avec Apple", "Continuer avec Microsoft", "Continuer avec Google",
                    "✉️   Continuer avec mon adresse e-mail",
                    "Explorer ma 1re leçon sans créer de compte  →",
                    "En continuant, tu acceptes les Conditions d'utilisation et la Politique de confidentialité de CertiGo.",
                    "Connexion avec l'identifiant Apple", "✕",
                    "Créez un compte pour CertiGo à l'aide de votre identifiant Apple.", "Nom",
                    "Gabriel Chambaud", "Masquer mon adresse e-mail", "✓", "Continuer"
                ]
            ),
            "142:385": (
                name: "21 · Onglet Examens (Variante C Centrée & Épurée)",
                texts: [
                    "Parcours", "Examens", "Social", "Moi", "Examens · AZ-104", "AZ-104 ▾",
                    "CONDITIONS PEARSON VUE", "Examen Blanc Complet (50 Q)",
                    "90 min · Seuil 700/1000 · Dernier : 785 ✓",
                    "DÉMARRER L'EXAMEN COMPLET", "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104",
                    "1. Identité & Gouvernance Entra ID", "Poids officiel : 20–25 %", "88 %",
                    "2. Stockage & Sécurité des données", "Poids officiel : 15–20 %", "82 %",
                    "3. Déploiement Calcul, VM & AKS"
                ]
            ),
            "142:478": (
                name: "23 · Examen Blanc Chronométré en Cours (Cockpit Centré)",
                texts: [
                    "✕", "⏱  42 : 18", "🏳 Marquer", "12 ✓", "13 🏳", "14 / 50", "15", "16", "17",
                    "ÉTUDE DE CAS CONTOSO · SÉCURITÉ",
                    "50 VMs dans VNet-Spoke doivent lire les secrets d'un coffre Azure Key Vault sans exposition Internet et avec contrôle RBAC unifié.\nQuelle architecture déployez-vous ?",
                    "A", "Service Endpoint + Stratégie d'accès Key Vault classique sur le sous-réseau",
                    "B", "Private Endpoint + Zone DNS privatelink + Rôle RBAC Key Vault Secrets User",
                    "C", "Azure NAT Gateway + Pare-feu public Key Vault limité à l'IP sortante", "D"
                ]
            ),
            "142:540": (
                name: "24 · Rapport Examen Blanc & Score /1000 (Carrousel Haut ●○○ + Bas Épuré)",
                texts: [
                    "✓ EXAMEN RÉUSSI · +85 PTS AU-DESSUS DU SEUIL", "785", "/ 1000",
                    "📈 +70 pts vs Essai #2", "ÉCHELLE OFFICIELLE PEARSON VUE (SEUIL : 700)",
                    "Seuil 700", "0", "1000", "›", "✓ 39 Exactes", "78 % réussite",
                    "✕ 11 Erreurs", "3 marquées 🏳", "⏱ 38 min", "45 sec / Q",
                    "SCORE PAR DOMAINE OFFICIEL AZ-104", "Identité & Gouvernance Entra ID", "88 %"
                ]
            ),
            "144:137": (
                name: "27 · CertiGo PRO (Variante 27-A Validée : Tableau Comparatif Gratuit vs PRO + Tarifs)",
                texts: [
                    "✕", "✦  CERTIGO PRO", "Réussis tes certifications\n2,8× plus vite.",
                    "AVANTAGES INCLUS", "GRATUIT", "PRO ✦", "Parcours Multi-Certifs & Veille IA",
                    "✓", "✓ Illimité", "Vies & Énergie quotidienne", "5 ❤️", "∞ Illimité",
                    "Coach IA Vocal Live & Explications", "Limité", "✦ 24/7 Max",
                    "Examens Blancs Pearson VUE (/1000)", "1 essai", "✓ Illimités"
                ]
            ),
            "145:122": (
                name: "28 · Paramètres Complets (Style 1 ChatGPT iOS 2026 Validé : Icônes Vectorielles Fines)",
                texts: [
                    "Paramètres", "✕", "GC", "Gabriel Chambaud",
                    "gabriel@certigo" + ".app · CertiGo PRO Actif", "›", "Parcours & Examens",
                    "Parcours actifs en parallèle", "AZ-104 + 2  ›", "Langue des cours & examens",
                    "FR + Termes EN  ›", "Mode Examen Blanc (Pearson)", "Chrono 90m  ›",
                    "Cours téléchargés (Hors-Ligne)", "142 Mo  ›", "Coach IA Vocal & Écrit",
                    "Voix du Coach IA Live", "Nova (1,0×)  ›"
                ]
            )
        ]

        #expect(expectedGroundTruthByNodeId.count == 49)

        for (nodeId, expected) in expectedGroundTruthByNodeId {
            let content = try #require(
                CertiGoFigmaExactScreenParity.content(forNodeId: nodeId),
                "Missing screen for Figma nodeId \(nodeId)"
            )
            #expect(content.nodeId == nodeId)
            #expect(content.isPage01GroundTruthScreen == true)
            #expect(content.figmaFrameName == expected.name, "Mismatched frame name for \(nodeId)")
            #expect(content.exactTexts == expected.texts, "Mismatched exactTexts for \(nodeId) (\(content.screenCode))")
            #expect(content.texts == expected.texts)
            #expect(CertiGoFigmaExactScreenParity.content(forScreenId: content.screenCode) == content)
            #expect(CertiGoFigmaExactScreenParity.content(forScreenId: content.figmaScreenKey) == content)
            #expect(CertiGoFigmaExactScreenContent.screen(forId: nodeId) == content)
        }
    }

    @Test("All 53 descriptors in CertiGoMasterScreenCatalog resolve to exact Figma content including SYS-01, SYS-02, RES-01, and RES-02")
    func all53MasterCatalogDescriptorsResolveToExactFigmaContent() throws {
        for descriptor in CertiGoMasterScreenCatalog.allScreens {
            let content = try #require(
                descriptor.exactFigmaContent,
                "Missing exactFigmaContent for \(descriptor.screenCode) (\(descriptor.nodeId))"
            )
            #expect(content.screenCode == descriptor.screenCode)
            #expect(content.nodeId == descriptor.nodeId)
            #expect(content.chapterKind == descriptor.chapterKind)
            #expect(content.mascotPose == descriptor.mascotPose)
            #expect(!content.exactTexts.isEmpty)
        }

        // Verify alias resolution between OB_01 / OB-01, 06 / 06A, 07 / 07A, SYS_01 / SYS-01, RES_01 / RES-01
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "OB_01")?.nodeId == "132:182")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "OB-01")?.nodeId == "132:182")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "OB_08B")?.nodeId == "132:1009")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "06")?.nodeId == "79:332")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "06A")?.nodeId == "79:332")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "07")?.nodeId == "88:317")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "07A")?.nodeId == "88:317")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "SYS-01")?.nodeId == "161:93")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "SYS-02")?.nodeId == "161:134")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "RES-01")?.nodeId == "162:93")
        #expect(CertiGoFigmaExactScreenParity.content(forScreenId: "RES-02")?.nodeId == "162:120")
    }

    @Test("PrismHomeTodayScreens default AZ-104 path steps include the exact Figma Pro Screen 01 titles")
    func todayScreenDefaultAZ104StepsIncludeExactFigmaTitles() {
        let steps = TodayScreenModel.defaultAZ104PathSteps
        #expect(steps.count == 5)
        let titles = steps.map(\.title)
        #expect(titles.contains("Concepts Cloud Azure"))
        #expect(titles.contains("Identité Entra ID"))
        #expect(titles.contains("Rôles RBAC & PIM"))
        #expect(titles.contains("Accès Conditionnel"))
        #expect(titles.contains("Réparer un accès RBAC refusé"))
        #expect(TodayScreenModel.pathSteps(forRouteCode: "AZ-104") == steps)
    }

    @Test("Every crest, brand logo (including official AWS logo), and cloud service icon referenced by the 53 screens exists in Prism.xcassets")
    func allReferencedAssetsInExactScreensExistOnDisk() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let xcassetsRoot = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")

        for screen in CertiGoFigmaExactScreenParity.allScreens {
            if let pose = screen.mascotPose {
                let mascotDir = xcassetsRoot.appendingPathComponent("\(pose.rawValue).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: mascotDir.path),
                    "Missing mascot imageset \(pose.rawValue) for screen \(screen.screenCode)"
                )
            }
            for routeCode in screen.officialCrestRouteCodes {
                let crestAsset = CertiGoOfficialAssetCatalog.certificationAssetName(forRouteCode: routeCode)
                let crestDir = xcassetsRoot.appendingPathComponent("\(crestAsset).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: crestDir.path),
                    "Missing crest imageset \(crestAsset) for screen \(screen.screenCode)"
                )
            }
            for vendorId in screen.brandVendorIds {
                let brandAsset = CertiGoOfficialAssetCatalog.brandLogoAssetName(forVendorId: vendorId)
                let brandDir = xcassetsRoot.appendingPathComponent("\(brandAsset).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: brandDir.path),
                    "Missing brand logo imageset \(brandAsset) for screen \(screen.screenCode)"
                )
            }
            for serviceAsset in screen.serviceAssetNames {
                let serviceDir = xcassetsRoot.appendingPathComponent("\(serviceAsset).imageset")
                #expect(
                    FileManager.default.fileExists(atPath: serviceDir.path),
                    "Missing service imageset \(serviceAsset) for screen \(screen.screenCode)"
                )
            }
        }
    }

    @Test("CertiGoFigmaSceneGraphStore loads all 53 screens (4,712 nodes, 1,429 valid SVG vectors, and 407 conflict-free interactive hotspots)")
    func sceneGraphStoreLoadsAll53ScreensWithExactNodesVectorsAndHotspots() throws {
        let store = CertiGoFigmaSceneGraphStore.shared
        #expect(store.totalScreenCount == CertiGoFigmaSceneGraphStore.expectedScreenCount)
        #expect(store.totalScreenCount == 53)
        #expect(store.totalNodeCount == CertiGoFigmaSceneGraphStore.expectedTotalNodeCount)
        #expect(store.totalNodeCount == 4712)
        #expect(store.totalVectorCount == CertiGoFigmaSceneGraphStore.expectedVectorCount)
        #expect(store.totalVectorCount == 1429)
        #expect(store.totalHotspotCount == CertiGoFigmaSceneGraphStore.expectedHotspotCount)
        #expect(store.totalHotspotCount == 407)

        for screen in CertiGoFigmaExactScreenParity.allScreens {
            let treeByNode = try #require(
                store.nodeTree(forScreenNodeId: screen.nodeId),
                "Missing scene graph tree for nodeId \(screen.nodeId)"
            )
            let treeByCode = try #require(
                store.nodeTree(forScreenId: screen.screenCode),
                "Missing scene graph tree for screenCode \(screen.screenCode)"
            )
            #expect(treeByNode == treeByCode)
            #expect(treeByNode.i == screen.nodeId)
            #expect(treeByNode.w == 393)
            #expect(treeByNode.h == 852)

            for vec in treeByNode.vectorNodes {
                let vp = try #require(vec.vp, "Missing vp on VECTOR \(vec.i) in \(screen.screenCode)")
                let commands = CertiGoFigmaSVGCommand.parse(vp)
                #expect(!commands.isEmpty, "Empty parsed SVG commands for VECTOR \(vec.i)")
            }

            for hotspot in treeByNode.hotspotNodes {
                let dest = try #require(hotspot.d)
                #expect(
                    store.nodeTree(forScreenNodeId: dest) != nil,
                    "Hotspot on \(hotspot.i) points to unknown screen nodeId \(dest)"
                )
                if hotspot.i != screen.nodeId {
                    for descendant in hotspot.allNodes where descendant.i != hotspot.i {
                        if let childDest = descendant.d {
                            #expect(
                                childDest == dest,
                                "Nested destination conflict in \(screen.nodeId): \(hotspot.i) (\(dest)) vs \(descendant.i) (\(childDest))"
                            )
                        }
                    }
                }
            }
        }

        // Verify Q_TYPE_01..10 VÉRIFIER buttons and Onboarding CONTINUER buttons point to next step and never to 79:332
        let verifierAndContinuerExpectations: [String: [String: String]] = [
            "73:393": ["73:437": "73:442", "73:438": "73:442", "73:439": "73:442"],
            "73:442": ["73:504": "73:509", "73:505": "73:509", "73:506": "73:509"],
            "73:509": ["73:570": "73:575", "73:571": "73:575", "73:572": "73:575"],
            "73:575": ["73:607": "73:743"],
            "73:743": ["73:813": "73:818", "73:814": "73:818", "73:815": "73:818"],
            "73:818": ["73:893": "73:898", "73:894": "73:898", "73:895": "73:898"],
            "73:898": ["73:953": "73:958", "73:954": "73:958", "73:955": "73:958"],
            "73:958": ["73:1014": "73:1019", "73:1015": "73:1019", "73:1016": "73:1019"],
            "73:1019": ["73:1065": "73:1070", "73:1066": "73:1070", "73:1067": "73:1070"],
            "73:1070": ["73:1117": "26:890", "73:1118": "26:890", "73:1119": "26:890"],
            "132:264": ["132:335": "132:339", "132:336": "132:339", "132:337": "132:339"],
            "132:519": ["132:577": "132:581", "132:578": "132:581", "132:579": "132:581"],
            "132:581": ["132:647": "132:651", "132:648": "132:651", "132:649": "132:651"]
        ]
        for (screenId, expectedButtons) in verifierAndContinuerExpectations {
            let tree = try #require(store.nodeTree(forScreenNodeId: screenId))
            let nodesById = Dictionary(uniqueKeysWithValues: tree.allNodes.map { ($0.i, $0) })
            for (btnId, expectedNext) in expectedButtons {
                let btn = try #require(nodesById[btnId], "Missing CTA node \(btnId) in \(screenId)")
                #expect(btn.d == expectedNext, "Expected \(btnId) in \(screenId) to point to \(expectedNext), got \(String(describing: btn.d))")
                #expect(btn.d != "79:332", "CTA \(btnId) in \(screenId) must never point to AI Hub 79:332")
            }
        }

        // Verify enriched sub-button hotspots across screens 02, 03, 14, 05, 20, 21, 22, 23, 24, 26, and 08B-2
        let expectedSubHotspotsByScreen: [String: [String: String]] = [
            "42:375": [
                "42:479": "37:375", "42:490": "37:375", "42:522": "37:375",
                "42:532": "37:375", "42:540": "37:375", "42:548": "132:339"
            ],
            "49:368": [
                "49:471": "37:375", "58:360": "58:705",
                "49:493": "73:332", "49:497": "79:332"
            ],
            "58:705": [
                "58:820": "37:375", "58:851": "49:368",
                "58:857": "73:332", "58:861": "79:332"
            ],
            "62:346": [
                "62:350": "37:375", "62:409": "37:375", "62:417": "73:332",
                "62:439": "26:939", "62:447": "26:807"
            ],
            "26:939": ["26:942": "26:890"],
            "142:385": [
                "142:417": "142:540", "142:424": "26:1009", "142:438": "26:1009",
                "142:443": "73:332", "142:450": "73:332", "142:457": "73:332",
                "142:464": "73:332", "142:471": "73:332"
            ],
            "26:1009": [
                "151:200": "142:385", "151:206": "142:385",
                "151:236": "142:478", "151:240": "142:385"
            ],
            "142:478": [
                "142:483": "142:385", "142:532": "142:385", "142:536": "142:540"
            ],
            "142:540": ["142:608": "79:332", "142:616": "142:385"],
            "97:417": ["97:421": "97:287", "97:467": "142:385"],
            "97:636": ["97:640": "97:287"]
        ]
        for (screenId, subHotspots) in expectedSubHotspotsByScreen {
            let tree = try #require(store.nodeTree(forScreenNodeId: screenId))
            let nodesById = Dictionary(uniqueKeysWithValues: tree.allNodes.map { ($0.i, $0) })
            for (nodeId, expectedDest) in subHotspots {
                let node = try #require(nodesById[nodeId], "Missing node \(nodeId) in \(screenId)")
                #expect(node.d == expectedDest, "Expected \(nodeId) in \(screenId) to point to \(expectedDest)")
            }
        }

        // Verify root tap gesture is suppressed on hub/popover screens (01, 02, 03, 14, 05, 06, 07, 08, 21, etc.)
        for hubScreenId in ["37:375", "42:375", "49:368", "58:705", "62:346", "79:332", "88:317", "97:287", "142:385", "97:498", "97:636"] {
            let root = try #require(store.nodeTree(forScreenNodeId: hubScreenId))
            #expect(root.shouldAttachRootTapGesture == false, "Expected root tap disabled on \(hubScreenId)")
        }
        for linearScreenId in ["132:182", "73:332", "73:393", "26:807", "142:478", "142:540", "161:93", "162:93"] {
            let root = try #require(store.nodeTree(forScreenNodeId: linearScreenId))
            #expect(root.shouldAttachRootTapGesture == true, "Expected root tap enabled on \(linearScreenId)")
        }

        // Verify deduplicated merge of 08B-1 (97:498) + 08B-2 (97:636)
        let merged = try #require(store.mergedStatistiquesProNodes())
        let topChildIds = Set((merged.top.c ?? []).map(\.i))
        let bottomChildIds = Set((merged.bottom.c ?? []).map(\.i))
        #expect(!topChildIds.contains("97:609"))
        #expect((merged.top.c ?? []).allSatisfy { $0.y < 740.0 })
        #expect(!bottomChildIds.contains("97:640"))
        #expect(!bottomChildIds.contains("97:642"))
        #expect(!bottomChildIds.contains("97:643"))
        #expect((merged.bottom.c ?? []).allSatisfy { $0.y >= 92.0 })
        #expect(bottomChildIds.contains("97:683"))

        // Verify chapter quick-picker groups cover all 53 screens in exact order
        #expect(CertiGoQuickChapterGroup.allCases.count == 9)
        #expect(CertiGoQuickChapterGroup.orderedScreenNodeIds.count == 53)
        #expect(Set(CertiGoQuickChapterGroup.orderedScreenNodeIds).count == 53)

        // Verify image fill hash resolution and color/stroke/shadow parsers
        #expect(
            PrismRGBA.figmaHex("#2563eb:50").alpha == 0.5
        )
        #expect(
            PrismRGBA.figmaGradientRGBAs("grad:#dbeafe,#eff6ff,#ffffff").count == 3
        )
        #expect(
            PrismRGBA.figmaStrokeIsDashed("#60a5fa:2.5:d") == true
        )
        #expect(
            PrismRGBA.figmaStrokeWidth("#60a5fa:2.5:d") == 2.5
        )
        #expect(
            PrismRGBA.figmaShadowSpec("0:8:28:#0a1224:18")?.radius == 28
        )
    }

    @Test("All 24 Blason 1A mascot PNGs in Prism.xcassets/Mascots are >= 300x300 @3x RGBA pure cutouts with transparent (0,0) corner")
    func all24MascotPNGsAre300x300PureTransparentCutouts() throws {
        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            let parent = root.deletingLastPathComponent()
            guard parent != root else { throw CocoaError(.fileNoSuchFile) }
            root = parent
        }
        let xcassetsRoot = root.appendingPathComponent("apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets")

        #expect(CertiGoMascotPose.allCases.count == 24)
        for pose in CertiGoMascotPose.allCases {
            let slug = String(pose.rawValue.split(separator: "/").last ?? "")
            let pngURL = xcassetsRoot
                .appendingPathComponent("\(pose.rawValue).imageset")
                .appendingPathComponent("\(slug).png")
            let data = try Data(contentsOf: pngURL)
            #expect(data.count > 26, "Invalid PNG file for \(pose.rawValue)")

            // PNG IHDR starts at byte 16: 4-byte width, 4-byte height, 1-byte bitDepth, 1-byte colorType
            let width = (Int(data[16]) << 24) | (Int(data[17]) << 16) | (Int(data[18]) << 8) | Int(data[19])
            let height = (Int(data[20]) << 24) | (Int(data[21]) << 16) | (Int(data[22]) << 8) | Int(data[23])
            let colorType = Int(data[25])
            #expect(width >= 300, "Expected width >= 300 for \(pose.rawValue), got \(width)")
            #expect(height >= 300, "Expected height >= 300 for \(pose.rawValue), got \(height)")
            #expect(colorType == 6, "Expected RGBA colorType == 6 for \(pose.rawValue), got \(colorType)")

            #if canImport(SwiftUI) && canImport(UIKit)
            let snapshot = try PrismSnapshotHarness.decodePNG(data)
            #expect(snapshot.width == width)
            #expect(snapshot.height == height)
            // Verify top-left pixel (0,0) alpha channel is 0 (100% transparent background)
            #expect(snapshot.pixels[3] == 0, "Expected transparent (0,0) pixel for \(pose.rawValue)")
            #endif
        }
    }

    @Test("CertiGoFigmaLiveRuntimeState drives interactive QCM options, Popover 02 brands, Settings toggles, Social Salut, and Exam 23/24 carousel")
    func liveRuntimeStateDrivesInteractiveControlsAcrossAllFigmaScreens() throws {
        let store = CertiGoFigmaSceneGraphStore.shared
        var coordinator = PrismAppShellCoordinatorModel()
        var live = CertiGoFigmaLiveRuntimeState()

        // 1. Popover 02 (42:375) vendor switching & active route selection
        #expect(live.selectedVendorInPopover == "microsoft")
        #expect(live.activeRouteCode == "AZ-104")
        let awsTap = live.handleTap(onNodeId: "42:498", inScreenNodeId: "42:375", coordinator: &coordinator)
        #expect(awsTap == nil)
        #expect(live.selectedVendorInPopover == "aws")
        #expect(live.currentPopoverCards.map(\.code) == ["SAA-C03", "CLF-C02", "AIF-C01"])

        let popoverTree = try #require(store.nodeTree(forScreenNodeId: "42:375"))
        let livePopover = live.applyingLiveState(to: popoverTree)
        #expect(livePopover.node(withId: "42:528")?.tx == "SAA-C03")
        #expect(livePopover.node(withId: "42:538")?.tx == "CLF-C02")
        #expect(livePopover.node(withId: "42:546")?.tx == "AIF-C01")

        let selectSAAC03 = live.handleTap(onNodeId: "42:522", inScreenNodeId: "42:375", coordinator: &coordinator)
        #expect(selectSAAC03 == "37:375")
        #expect(live.activeRouteCode == "SAA-C03")
        #expect(coordinator.parallelTracksPreference.activeTrackCode == "SAA-C03")

        let homeTree = try #require(store.nodeTree(forScreenNodeId: "37:375"))
        let liveHome = live.applyingLiveState(to: homeTree)
        #expect(liveHome.node(withId: "37:447")?.tx == "SAA-C03 ▾")

        let examsTree = try #require(store.nodeTree(forScreenNodeId: "142:385"))
        let liveExams = live.applyingLiveState(to: examsTree)
        #expect(liveExams.node(withId: "142:416")?.tx == "Examens · SAA-C03")
        #expect(liveExams.node(withId: "142:423")?.tx == "SAA-C03 ▾")

        // Verify Google, GitHub, and Cisco vendor catalogs in Popover 02
        live.handleTap(onNodeId: "42:505", inScreenNodeId: "42:375", coordinator: &coordinator)
        #expect(live.currentPopoverCards.map(\.code) == ["ACE", "PCA", "PDE"])
        live.handleTap(onNodeId: "42:511", inScreenNodeId: "42:375", coordinator: &coordinator)
        #expect(live.currentPopoverCards.map(\.code) == ["GH-300", "GH-900", "GH-AS"])
        live.handleTap(onNodeId: "42:514", inScreenNodeId: "42:375", coordinator: &coordinator)
        #expect(live.currentPopoverCards.map(\.code) == ["CCNA", "CKA", "TF-003"])

        // 2. QCM single-choice (Q_TYPE_01 73:393) & multi-choice (Q_TYPE_10 73:1070) & CLI (Q_TYPE_04 73:575)
        #expect(live.isOptionSelected("73:425", inScreen: "73:393") == true)
        live.handleTap(onNodeId: "73:421", inScreenNodeId: "73:393", coordinator: &coordinator)
        #expect(live.isOptionSelected("73:421", inScreen: "73:393") == true)
        #expect(live.isOptionSelected("73:425", inScreen: "73:393") == false)
        let q1Tree = try #require(store.nodeTree(forScreenNodeId: "73:393"))
        let liveQ1 = live.applyingLiveState(to: q1Tree)
        #expect(liveQ1.node(withId: "73:422")?.f == "#1cb0f6")
        #expect(liveQ1.node(withId: "73:423")?.f == "#ddf4ff")
        #expect(liveQ1.node(withId: "73:426")?.f == "#e5e5e5")
        #expect(liveQ1.node(withId: "73:427")?.f == "#ffffff")

        // Multi-choice Q_TYPE_10 (73:1070)
        #expect(live.isOptionSelected("73:1107", inScreen: "73:1070") == false)
        live.handleTap(onNodeId: "73:1107", inScreenNodeId: "73:1070", coordinator: &coordinator)
        #expect(live.isOptionSelected("73:1107", inScreen: "73:1070") == true)
        let q10Tree = try #require(store.nodeTree(forScreenNodeId: "73:1070"))
        let liveQ10 = live.applyingLiveState(to: q10Tree)
        #expect(liveQ10.node(withId: "73:1111")?.f == "#1cb0f6")

        // Q_TYPE_04 (73:575) CLI input & Q_TYPE_08 (73:958) row swap
        live.handleTap(onNodeId: "73:617", inScreenNodeId: "73:575", coordinator: &coordinator)
        #expect(live.qType04InputText == "list")
        live.handleTap(onNodeId: "73:615", inScreenNodeId: "73:575", coordinator: &coordinator)
        #expect(live.qType04InputText == "lock")

        #expect(live.qType08OrderedRowNodeIds == ["73:982", "73:990", "73:998", "73:1006"])
        live.handleTap(onNodeId: "73:982", inScreenNodeId: "73:958", coordinator: &coordinator)
        #expect(live.qType08OrderedRowNodeIds == ["73:990", "73:982", "73:998", "73:1006"])

        // 3. AI Hub (79:332, 78:332, 81:345, 85:317)
        let ai06Tree = try #require(store.nodeTree(forScreenNodeId: "79:332"))
        let liveAI06 = live.applyingLiveState(to: ai06Tree)
        #expect(liveAI06.node(withId: "79:370")?.tx == "")

        let aiDest = live.handleTap(onNodeId: "79:360", inScreenNodeId: "79:332", coordinator: &coordinator)
        #expect(aiDest == "78:332")
        #expect(live.aiActiveTopicId == "last-3-errors")
        live.handleTap(onNodeId: "78:366", inScreenNodeId: "78:332", coordinator: &coordinator)
        #expect(live.isAIResponseCopied == true)
        let ai06BTree = try #require(store.nodeTree(forScreenNodeId: "78:332"))
        let liveAI06B = live.applyingLiveState(to: ai06BTree)
        #expect(liveAI06B.node(withId: "78:370")?.tx == "✓ Copié")
        #expect(liveAI06B.node(withId: "78:377")?.tx == "")

        #expect(live.isVoiceLiveListening == true)
        live.handleTap(onNodeId: "81:365", inScreenNodeId: "81:345", coordinator: &coordinator)
        #expect(live.isVoiceLiveListening == false)

        let ai06DTree = try #require(store.nodeTree(forScreenNodeId: "85:317"))
        let liveAI06D = live.applyingLiveState(to: ai06DTree)
        #expect(liveAI06D.node(withId: "85:376")?.tx == "")
        let historyDest = live.handleTap(onNodeId: "85:380", inScreenNodeId: "85:317", coordinator: &coordinator)
        #expect(historyDest == "78:332")
        #expect(live.aiActiveTopicId == "vnet-peering-cli")

        // 4. Mock Exam 23 (142:478) & Report Carousel 24 (142:540)
        #expect(live.isCurrentExamQuestionFlagged == false)
        live.handleTap(onNodeId: "142:487", inScreenNodeId: "142:478", coordinator: &coordinator)
        #expect(live.isCurrentExamQuestionFlagged == true)
        live.handleTap(onNodeId: "142:520", inScreenNodeId: "142:478", coordinator: &coordinator)
        #expect(live.currentExamSelectedOptionNodeId == "142:520")
        let exam23Tree = try #require(store.nodeTree(forScreenNodeId: "142:478"))
        let liveExam23 = live.applyingLiveState(to: exam23Tree)
        #expect(liveExam23.node(withId: "142:488")?.tx == "🏳 Marquée ✓")
        #expect(liveExam23.node(withId: "142:521")?.f == "#2563eb")

        #expect(live.examReportCarouselIndex == 0)
        live.handleTap(onNodeId: "142:573", inScreenNodeId: "142:540", coordinator: &coordinator)
        #expect(live.examReportCarouselIndex == 1)
        let exam24Tree = try #require(store.nodeTree(forScreenNodeId: "142:540"))
        let liveExam24Card1 = live.applyingLiveState(to: exam24Tree)
        #expect(liveExam24Card1.node(withId: "142:550")?.tx == "⏱ RYTHME CHRONO & CALIBRATION PEARSON VUE")
        live.handleTap(onNodeId: "142:573", inScreenNodeId: "142:540", coordinator: &coordinator)
        #expect(live.examReportCarouselIndex == 2)
        let liveExam24Card2 = live.applyingLiveState(to: exam24Tree)
        #expect(liveExam24Card2.node(withId: "142:550")?.tx == "🎯 ANALYSE DES 11 ERREURS & RELANCE COACH IA")

        // 5. Social 25 (89:317) 👋 Salut buttons & Copier
        #expect(live.isFriendSaluted("89:493") == false)
        live.handleTap(onNodeId: "89:493", inScreenNodeId: "89:317", coordinator: &coordinator)
        #expect(live.isFriendSaluted("89:493") == true)
        live.handleTap(onNodeId: "89:480", inScreenNodeId: "89:317", coordinator: &coordinator)
        #expect(live.isFriendInviteCopied == true)
        let social25Tree = try #require(store.nodeTree(forScreenNodeId: "89:317"))
        let liveSocial25 = live.applyingLiveState(to: social25Tree)
        #expect(liveSocial25.node(withId: "89:495")?.f == "#dcfce7")
        #expect(liveSocial25.node(withId: "89:496")?.tx == "👏 Salué ✓")
        #expect(liveSocial25.node(withId: "89:496")?.f == "#15803d")
        #expect(liveSocial25.node(withId: "89:484")?.tx == "✓ Copié")

        // 6. Profile 08 (97:287) -> Detail 26 (97:417) & Settings 28 (145:122) toggles & cycles
        let certDetailDest = live.handleTap(onNodeId: "97:374", inScreenNodeId: "97:287", coordinator: &coordinator)
        #expect(certDetailDest == "97:417")
        #expect(live.selectedProfileCertificationCode == "SAA-C03")
        let detail26Tree = try #require(store.nodeTree(forScreenNodeId: "97:417"))
        let liveDetail26 = live.applyingLiveState(to: detail26Tree)
        #expect(liveDetail26.node(withId: "97:439")?.tx == "Solutions Architect (SAA-C03)")

        #expect(live.isSettingsToggleOn("145:174") == true)
        live.handleTap(onNodeId: "145:174", inScreenNodeId: "145:122", coordinator: &coordinator)
        #expect(live.isSettingsToggleOn("145:174") == false)
        live.handleTap(onNodeId: "145:146", inScreenNodeId: "145:122", coordinator: &coordinator)
        #expect(live.currentSettingsLanguageLabel == "Français intégral  ›")
        live.handleTap(onNodeId: "145:152", inScreenNodeId: "145:122", coordinator: &coordinator)
        #expect(live.currentSettingsExamModeLabel == "Temps majoré ×1,5  ›")
        live.handleTap(onNodeId: "145:163", inScreenNodeId: "145:122", coordinator: &coordinator)
        #expect(live.currentSettingsCoachVoiceLabel == "Nova (1,2×)  ›")
        let settings28Tree = try #require(store.nodeTree(forScreenNodeId: "145:122"))
        let liveSettings28 = live.applyingLiveState(to: settings28Tree)
        #expect(liveSettings28.node(withId: "145:174")?.f == "#cbd5e1")
        #expect(liveSettings28.node(withId: "145:175")?.x == 2.0)
        #expect(liveSettings28.node(withId: "145:147")?.tx == "Français intégral  ›")
        #expect(liveSettings28.node(withId: "145:153")?.tx == "Temps majoré ×1,5  ›")
        #expect(liveSettings28.node(withId: "145:164")?.tx == "Nova (1,2×)  ›")
        #expect(live.handleTap(onNodeId: "145:157", inScreenNodeId: "145:122", coordinator: &coordinator) == "162:93")
    }

    @Test("Switching activeRouteCode dynamically adapts path steps on 01/02/03, Memo 14, Exams 21, Apple Pay Sheet 22, and Report 24 across SAA-C03, GH-300, ACE, and CKA")
    func switchingActiveRouteCodeDynamicallyAdaptsPathMemoAndExamsAcrossCertifications() throws {
        let store = CertiGoFigmaSceneGraphStore.shared
        let screen01 = try #require(store.nodeTree(forScreenNodeId: "37:375"))
        let screen03 = try #require(store.nodeTree(forScreenNodeId: "49:368"))
        let screen14 = try #require(store.nodeTree(forScreenNodeId: "58:705"))
        let screen21 = try #require(store.nodeTree(forScreenNodeId: "142:385"))
        let screen22 = try #require(store.nodeTree(forScreenNodeId: "26:1009"))
        let screen24 = try #require(store.nodeTree(forScreenNodeId: "142:540"))

        let routeCodes = ["SAA-C03", "GH-300", "ACE", "CKA"]
        for routeCode in routeCodes {
            var live = CertiGoFigmaLiveRuntimeState()
            live.activeRouteCode = routeCode
            let expectedCurriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: routeCode)
            #expect(live.currentCurriculum == expectedCurriculum)
            #expect(expectedCurriculum.stepTitles.count == 5)
            #expect(expectedCurriculum.examDomains.count == 5)

            // Screen 01 (37:375): 5 path steps, unit banner, and percentage
            let live01 = live.applyingLiveState(to: screen01)
            #expect(live01.node(withId: "37:457")?.tx == expectedCurriculum.unitBannerTitle)
            #expect(live01.node(withId: "37:456")?.tx == expectedCurriculum.unitProgressPercentText)
            #expect(live01.node(withId: "37:394")?.tx == expectedCurriculum.stepTitles[0])
            #expect(live01.node(withId: "37:405")?.tx == expectedCurriculum.stepTitles[1])
            #expect(live01.node(withId: "37:419")?.tx == expectedCurriculum.stepTitles[2])
            #expect(live01.node(withId: "37:425")?.tx == expectedCurriculum.stepTitles[3])
            #expect(live01.node(withId: "37:439")?.tx == expectedCurriculum.stepTitles[4])

            // Screen 03 (49:368): active step title and preview subtitle
            let live03 = live.applyingLiveState(to: screen03)
            #expect(live03.node(withId: "49:450")?.tx == expectedCurriculum.unitBannerTitle)
            #expect(live03.node(withId: "49:487")?.tx == expectedCurriculum.stepTitles[2])
            #expect(live03.node(withId: "49:488")?.tx == expectedCurriculum.stepPreviewSubtitle)

            // Screen 14 (58:705): Memo activity, key topics, and golden rule
            let live14 = live.applyingLiveState(to: screen14)
            #expect(live14.node(withId: "58:787")?.tx == expectedCurriculum.unitBannerTitle)
            #expect(live14.node(withId: "58:836")?.tx == expectedCurriculum.stepTitles[2])
            #expect(live14.node(withId: "58:839")?.tx == expectedCurriculum.memoActivity)
            #expect(live14.node(withId: "58:843")?.tx == expectedCurriculum.memoKeyTopics.0)
            #expect(live14.node(withId: "58:845")?.tx == expectedCurriculum.memoKeyTopics.1)
            #expect(live14.node(withId: "58:847")?.tx == expectedCurriculum.memoKeyTopics.2)
            #expect(live14.node(withId: "58:850")?.tx == expectedCurriculum.memoGoldenRule)

            // Screen 21 (142:385): 5 official weighted exam domains
            let live21 = live.applyingLiveState(to: screen21)
            #expect(live21.node(withId: "142:416")?.tx == "Examens · \(routeCode)")
            #expect(live21.node(withId: "142:442")?.tx == "S'ENTRAÎNER PAR DOMAINE OFFICIEL \(routeCode)")
            #expect(live21.node(withId: "142:446")?.tx == expectedCurriculum.examDomains[0].title)
            #expect(live21.node(withId: "142:447")?.tx == expectedCurriculum.examDomains[0].weightText)
            #expect(live21.node(withId: "142:449")?.tx == expectedCurriculum.examDomains[0].scorePercent)
            #expect(live21.node(withId: "142:474")?.tx == expectedCurriculum.examDomains[4].title)

            // Screen 22 (26:1009): Apple Pay exam launch sheet header and domains
            let live22 = live.applyingLiveState(to: screen22)
            #expect(live22.node(withId: "151:218")?.tx == "\(routeCode) ★")
            #expect(live22.node(withId: "151:221")?.tx == "Examen Blanc \(routeCode)")
            #expect(live22.node(withId: "151:222")?.tx == expectedCurriculum.examOfficialTitle)
            #expect(live22.node(withId: "151:168")?.tx == expectedCurriculum.examDomains[0].title)
            #expect(live22.node(withId: "151:196")?.tx == expectedCurriculum.examDomains[4].title)

            // Screen 24 (142:540): Report /1000 domain breakdown
            let live24 = live.applyingLiveState(to: screen24)
            #expect(live24.node(withId: "142:591")?.tx == "SCORE PAR DOMAINE OFFICIEL \(routeCode)")
            #expect(live24.node(withId: "142:592")?.tx == expectedCurriculum.examDomains[0].title)
            #expect(live24.node(withId: "142:604")?.tx == expectedCurriculum.examDomains[3].title)
        }
    }

    @Test("recordExerciseStepCompletion updates CertigoCortex FSRS ConceptMastery, increments live counters (💎/étapes), and transforms nodes 37:450 and 97:317")
    func recordExerciseStepCompletionUpdatesCortexMasteryAndLiveCounterNodes() throws {
        let store = CertiGoFigmaSceneGraphStore.shared
        let screen01 = try #require(store.nodeTree(forScreenNodeId: "37:375"))
        let screen08 = try #require(store.nodeTree(forScreenNodeId: "97:287"))
        let screenQ1 = try #require(store.nodeTree(forScreenNodeId: "73:393"))

        var live = CertiGoFigmaLiveRuntimeState()
        #expect(live.liveStreakDays == 14)
        #expect(live.liveGemsCount == 480)
        #expect(live.liveHeartsCount == 5)
        #expect(live.completedStepsCount == 42)
        #expect(live.cortexMasteryByConceptId.isEmpty)

        let now = Date(timeIntervalSince1970: 1_776_700_000)
        live.recordExerciseStepCompletion(correct: true, latencyMs: 2_800, now: now)

        #expect(live.completedExerciseCountInSession == 1)
        #expect(live.liveGemsCount == 495)
        #expect(live.completedStepsCount == 43)

        let mastery = try #require(live.cortexMasteryByConceptId["az-104:unit-1-step-3"])
        #expect(mastery.trackId == "AZ-104")
        #expect(mastery.reps == 1)
        #expect(mastery.lapses == 0)
        #expect(mastery.stability > 1.0)
        #expect(mastery.masteryScore > 0.0)

        live.liveStreakDays = 15
        live.liveHeartsCount = 4
        let live01 = live.applyingLiveState(to: screen01)
        #expect(live01.node(withId: "37:449")?.tx == "🔥 15")
        #expect(live01.node(withId: "37:450")?.tx == "💎 495")
        #expect(live01.node(withId: "37:451")?.tx == "❤️ 4")

        let live08 = live.applyingLiveState(to: screen08)
        #expect(live08.node(withId: "97:309")?.tx == "15 jours")
        #expect(live08.node(withId: "97:317")?.tx == "43 étapes")

        let liveQ1 = live.applyingLiveState(to: screenQ1)
        #expect(liveQ1.node(withId: "73:404")?.tx == "4")
    }

    @Test("SVG command cache pre-parses all distinct vector paths in O(1), preserves vector subtrees in applyingLiveState, and identifies pure vector illustration frames")
    func svgCommandCacheAndStaticVectorSubtreeShortCircuit() throws {
        let store = CertiGoFigmaSceneGraphStore.shared
        #expect(store.totalVectorCount == CertiGoFigmaSceneGraphStore.expectedVectorCount)
        #expect(store.parsedSVGCommandsByPath.count == 489)

        var distinctVectorPaths = Set<String>()
        var pureVectorFrameCount = 0
        for root in store.screensByNodeId.values {
            for node in root.allNodes {
                if node.isPureVectorIllustrationFrame {
                    pureVectorFrameCount += 1
                }
                if let vp = node.vp, !vp.isEmpty {
                    distinctVectorPaths.insert(vp)
                    let cached = CertiGoFigmaSVGCommand.cachedParse(vp)
                    #expect(!cached.isEmpty)
                    #expect(store.parsedSVGCommandsByPath[vp] == cached)
                }
            }
        }
        #expect(store.parsedSVGCommandsByPath.count == distinctVectorPaths.count)
        #expect(pureVectorFrameCount >= 20)

        var live = CertiGoFigmaLiveRuntimeState()
        live.activeRouteCode = "SAA-C03"
        let screen01 = try #require(store.nodeTree(forScreenNodeId: "37:375"))
        let transformed01 = live.applyingLiveState(to: screen01)
        #expect(transformed01.vectorNodes == screen01.vectorNodes)

        // Verify UTF-8 fast hex parser parity across #rrggbb and #rrggbb:alphaPercent
        let solid = PrismRGBA.figmaHex("  #2563eb ")
        #expect(solid == PrismRGBA(hex: 0x2563EB, alpha: 1.0))
        let translucent = PrismRGBA.figmaHex("#0f172a:58")
        #expect(translucent == PrismRGBA(hex: 0x0F172A, alpha: 0.58))
        let fractional = PrismRGBA.figmaHex("#ffffff:0.24")
        #expect(fractional == PrismRGBA(hex: 0xFFFFFF, alpha: 0.24))
    }

    @Test("CertiGoNativeLessonSessionEngine and CertiGoNativeAppState drive the 4 Lead-Architect pillars: 15-node 3-unit winding path, real node unlocking, exercise attempt phases (answering -> checked -> explainingError 05 / comparingServices 20 -> celebration 19), timed exam /1000, multi-turn AI chat, and 12-item Social lists")
    func nativeFigmaAppEngineAndStatePillars() throws {
        var appState = CertiGoNativeAppState()

        // 1. Verify 3 full units (15 sinusoidal lesson nodes) & 12 leaderboard/friend items
        #expect(appState.currentUnits.count == 3)
        let allLessons = appState.currentUnits.flatMap(\.lessons)
        #expect(allLessons.count == 15)
        #expect(allLessons[0].state == .completed)
        #expect(allLessons[1].state == .completed)
        #expect(allLessons[2].state == .active)
        #expect(allLessons[3].state == .miniLab)
        #expect(allLessons[4].state == .locked)
        #expect(appState.leaderboardMembers.count == 12)
        #expect(appState.friends.count == 12)
        #expect(appState.examQuestions.count == 12)
        #expect(appState.aiThreads.count == 12)

        // 2. Verify Step Sheet 03 -> Unfolded Memo Sheet 14
        appState.openStepPreviewSheet(forLessonId: allLessons[2].id)
        #expect(appState.activeStepSheet == .preview03(lessonId: "AZ-104-u1-s3"))
        appState.toggleStepMemoSheet14()
        #expect(appState.activeStepSheet == .memo14(lessonId: "AZ-104-u1-s3"))

        // 3. Start lesson session -> Card 15 Declic -> Exercise 1 (Wrong answer -> Red drawer 04 -> AI Explanation Sheet 05)
        appState.startLessonSession(forLessonId: allLessons[2].id)
        #expect(appState.isPresentingLessonSession == true)
        #expect(appState.lessonSession.isShowingDeclicCard15 == true)
        appState.lessonSession.dismissDeclicCard15()
        #expect(appState.lessonSession.isShowingDeclicCard15 == false)
        #expect(appState.lessonSession.attemptPhase == .answering)
        #expect(appState.lessonSession.canCheckCurrentExercise == false)

        // Select wrong option A (Contributor instead of Reader)
        appState.lessonSession.selectOption("opt-a")
        #expect(appState.lessonSession.canCheckCurrentExercise == true)
        let firstCheck = appState.lessonSession.verifyCurrentAnswer()
        #expect(firstCheck == false)
        #expect(appState.lessonSession.attemptPhase == .checked(isCorrect: false))
        #expect(appState.lessonSession.heartsCount == 4)

        // Open AI Error Explanation Sheet 05 & Comparator 20
        appState.lessonSession.openErrorExplanationSheet05()
        #expect(appState.lessonSession.attemptPhase == .explainingError)
        #expect(appState.lessonSession.selectedOptionSummaryText.contains("Contributeur"))
        appState.lessonSession.openServiceComparatorSheet20()
        #expect(appState.lessonSession.attemptPhase == .comparingServices)

        // Advance to Exercise 2 (Q_TYPE_02 2x2 Service Grid) -> Select correct option Key Vault -> Green drawer 18
        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExercise.formatCode == "Q_TYPE_02")
        appState.lessonSession.selectOption("grid-kv")
        let secondCheck = appState.lessonSession.verifyCurrentAnswer()
        #expect(secondCheck == true)
        #expect(appState.lessonSession.attemptPhase == .checked(isCorrect: true))
        #expect(appState.lessonSession.heartsCount == 4)

        // Complete remaining exercises (Q_TYPE_03, Q_TYPE_04 CLI, Q_TYPE_05 Word Bank, Q_TYPE_10 Multi-choice)
        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExercise.formatCode == "Q_TYPE_03")
        appState.lessonSession.selectOption("arch-appgw")
        #expect(appState.lessonSession.verifyCurrentAnswer() == true)

        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExercise.formatCode == "Q_TYPE_04")
        appState.lessonSession.cliInputText = "lock"
        #expect(appState.lessonSession.verifyCurrentAnswer() == true)

        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExercise.formatCode == "Q_TYPE_05")
        for token in ["az", "network", "vnet", "create", "--name ProdVNet", "-g RG-Core"] {
            appState.lessonSession.toggleWordBankBrick(token)
        }
        #expect(appState.lessonSession.verifyCurrentAnswer() == true)

        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.currentExercise.formatCode == "Q_TYPE_10")
        appState.lessonSession.selectOption("m-1")
        appState.lessonSession.selectOption("m-2")
        #expect(appState.lessonSession.verifyCurrentAnswer() == true)

        appState.lessonSession.advanceToNextExerciseOrFinish()
        #expect(appState.lessonSession.isSessionCompleted == true)
        #expect(appState.lessonSession.accuracyPercent == 83)

        // 4. Finish celebration 19 -> Verify active node u1-s3 becomes .completed and next node u1-s4 becomes .active!
        let fixedNow = Date(timeIntervalSince1970: 1_776_800_000)
        appState.completeActiveLessonSessionAndUnlockNextNode(now: fixedNow)
        #expect(appState.isPresentingLessonSession == false)
        #expect(appState.gemsCount == 495)
        #expect(appState.completedStepsTotal == 43)
        let updatedLessons = appState.currentUnits.flatMap(\.lessons)
        #expect(updatedLessons[2].state == .completed)
        #expect(updatedLessons[3].state == .active)
        #expect(appState.cortexMasteryByConceptId["az-104:az-104-u1-s3"] != nil)

        // 5. Timed Mock Exam 23 countdown & /1000 score calculation
        appState.startTimedExam23()
        #expect(appState.isPresentingTimedExam23 == true)
        #expect(appState.formattedExamCountdown == "⏱  89 : 59")
        appState.tickExamTimerOneSecond()
        #expect(appState.formattedExamCountdown == "⏱  89 : 58")
        appState.finishTimedExamAndComputeScore()
        #expect(appState.isPresentingTimedExam23 == false)
        #expect(appState.isPresentingExamReport24 == true)
        #expect(appState.lastComputedExamScoreOutOf1000 >= 700)

        // 6. Multi-turn AI Coach conversation & 06D drawer search
        appState.isLiveAIModelConnected = true
        appState.openAITopic("rbac-vs-policy")
        #expect(appState.chatTurns.count == 1)
        appState.sendAIMessage("Explique le verrou CanNotDelete")
        #expect(appState.chatTurns.count == 2)
        appState.aiDrawerSearchQuery = "Peering"
        #expect(appState.filteredAIThreads.count == 1)
        #expect(appState.filteredAIThreads.first?.topicKey == "vnet-peering-cli")

        // 7. Social friends filter, add friend & salut toggle
        appState.toggleSalutFriend(id: "fr-1")
        #expect(appState.friends[0].isSaluted == true)
        appState.friendSearchQuery = "@devops_alice"
        appState.addNewFriendFromSearch()
        #expect(appState.friends.count == 13)
        #expect(appState.friends[0].handle == "@devops_alice")
    }
}
