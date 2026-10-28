import BrandAssets
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
}
