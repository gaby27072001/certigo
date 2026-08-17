using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

internal sealed record OfficialCertificationMetadata(
    string Title,
    string Summary,
    DateOnly BlueprintDate,
    IReadOnlyList<CertificationDomainDto> Domains,
    string Prerequisites,
    string StudyGuideUrl,
    string ExamUrl,
    string Lifecycle,
    string LifecycleNote,
    string ExamDetailsNote,
    string ReplacementCode = "",
    string MigrationNote = "");

internal static class OfficialCertificationCatalog
{
    private const string SchedulingNotice =
        "La duree, le format et le tarif de l'examen sont confirmes lors de la planification et peuvent changer.";

    private static readonly IReadOnlyDictionary<string, OfficialCertificationMetadata> Entries =
        new Dictionary<string, OfficialCertificationMetadata>(StringComparer.OrdinalIgnoreCase)
        {
            ["AZ-900"] = new(
                Title: "Microsoft Azure Fundamentals",
                Summary:
                    "Valide les concepts du cloud, l'architecture et les services Azure, ainsi que la gestion et la gouvernance Azure.",
                BlueprintDate: new DateOnly(2026, 7, 20),
                Domains:
                [
                    new("cloud-concepts", "Describe cloud concepts", 25, 30),
                    new("azure-architecture-services", "Describe Azure architecture and services", 35, 40),
                    new("azure-management-governance", "Describe Azure management and governance", 30, 35),
                ],
                Prerequisites:
                    "Aucun prerequis formel. Une experience dans un domaine informatique est recommandee.",
                StudyGuideUrl:
                    "https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-900",
                ExamUrl: "https://learn.microsoft.com/en-us/credentials/certifications/exams/az-900/",
                Lifecycle: "active",
                LifecycleNote: string.Empty,
                ExamDetailsNote: SchedulingNotice),
            ["DP-900"] = new(
                Title: "Microsoft Azure Data Fundamentals",
                Summary:
                    "Valide les concepts de donnees et les services Azure pour les charges relationnelles, non relationnelles et analytiques.",
                BlueprintDate: new DateOnly(2026, 7, 21),
                Domains:
                [
                    new("core-data-concepts", "Describe core data concepts", 25, 30),
                    new("relational-data-azure", "Identify considerations for relational data on Azure", 20, 25),
                    new(
                        "non-relational-data-azure",
                        "Describe considerations for working with non-relational data on Azure",
                        15,
                        20),
                    new("analytics-workload-azure", "Describe an analytics workload on Azure", 25, 30),
                ],
                Prerequisites:
                    "Aucun prerequis formel. Une familiarite avec les donnees relationnelles, non relationnelles et analytiques est recommandee.",
                StudyGuideUrl:
                    "https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/dp-900",
                ExamUrl: "https://learn.microsoft.com/en-us/credentials/certifications/exams/dp-900/",
                Lifecycle: "active",
                LifecycleNote: string.Empty,
                ExamDetailsNote: SchedulingNotice),
            ["AZ-104"] = new(
                Title: "Microsoft Azure Administrator",
                Summary:
                    "Valide l'administration des identites, de la gouvernance, du stockage, du calcul, des reseaux et du monitoring Azure.",
                BlueprintDate: new DateOnly(2026, 4, 17),
                Domains:
                [
                    new("identities-governance", "Manage Azure identities and governance", 20, 25),
                    new("storage", "Implement and manage storage", 15, 20),
                    new("compute", "Deploy and manage Azure compute resources", 20, 25),
                    new("virtual-networking", "Implement and manage virtual networking", 15, 20),
                    new("monitor-resources", "Monitor and maintain Azure resources", 10, 15),
                ],
                Prerequisites:
                    "Experience recommandee avec les systemes d'exploitation, les reseaux, les serveurs, la virtualisation, PowerShell, Azure CLI, le portail Azure, ARM ou Bicep et Microsoft Entra ID.",
                StudyGuideUrl:
                    "https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104",
                ExamUrl: "https://learn.microsoft.com/en-us/credentials/certifications/exams/az-104/",
                Lifecycle: "active",
                LifecycleNote: string.Empty,
                ExamDetailsNote: SchedulingNotice),
            ["AI-900"] = new(
                Title: "Microsoft Azure AI Fundamentals",
                Summary:
                    "Couvrait les bases des charges de travail IA, du machine learning, de la vision, du traitement du langage et de l'IA generative sur Azure.",
                BlueprintDate: new DateOnly(2025, 5, 2),
                Domains:
                [
                    new(
                        "ai-workloads-considerations",
                        "Describe Artificial Intelligence workloads and considerations",
                        15,
                        20),
                    new(
                        "machine-learning-azure",
                        "Describe fundamental principles of machine learning on Azure",
                        15,
                        20),
                    new("computer-vision", "Describe features of computer vision workloads on Azure", 15, 20),
                    new(
                        "natural-language-processing",
                        "Describe features of Natural Language Processing workloads on Azure",
                        15,
                        20),
                    new("generative-ai", "Describe features of generative AI workloads on Azure", 20, 25),
                ],
                Prerequisites:
                    "Aucun prerequis technique formel. Des notions de cloud et d'applications client-serveur etaient utiles.",
                StudyGuideUrl:
                    "https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/ai-900",
                ExamUrl: "https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-900/",
                Lifecycle: "retired",
                LifecycleNote: "Examen retire le 30 juin 2026. Il n'est plus disponible a la planification.",
                ExamDetailsNote: string.Empty,
                ReplacementCode: "AI-901",
                MigrationNote:
                    "La progression AI-900 reste disponible dans Certigo. Pour une nouvelle preparation, utilise AI-901."),
            ["AI-901"] = new(
                Title: "Microsoft Azure AI Fundamentals",
                Summary:
                    "Valide les concepts et capacites de l'IA ainsi que l'implementation de solutions avec Microsoft Foundry.",
                BlueprintDate: new DateOnly(2026, 4, 15),
                Domains:
                [
                    new("ai-concepts-capabilities", "Identify AI concepts and capabilities", 40, 45),
                    new(
                        "foundry-ai-solutions",
                        "Implement AI solutions by using Microsoft Foundry",
                        55,
                        60),
                ],
                Prerequisites:
                    "Connaissances conceptuelles des solutions IA Azure, bases techniques, syntaxe Python et familiarite avec les ressources Azure.",
                StudyGuideUrl:
                    "https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/ai-901",
                ExamUrl: "https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-901/",
                Lifecycle: "active",
                LifecycleNote: "Certification active.",
                ExamDetailsNote: SchedulingNotice,
                MigrationNote:
                    "AI-901 remplace AI-900 pour les nouvelles preparations, sans supprimer la progression AI-900 existante."),
        };

    public static OfficialCertificationMetadata? Find(string code)
        => Entries.GetValueOrDefault(code);

    public static string TitleFor(string code, string fallback)
        => Find(code)?.Title ?? fallback;

    public static IReadOnlyList<TrackSummaryDto> MissingReplacementSummaries(
        IEnumerable<string> existingCodes)
    {
        var codes = existingCodes.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var metadata = Find("AI-901");
        if (!codes.Contains("AI-900") || codes.Contains("AI-901") || metadata is null)
            return Array.Empty<TrackSummaryDto>();

        return
        [
            new TrackSummaryDto(
                Id: "ai-901",
                Code: "AI-901",
                Title: metadata.Title,
                Level: "fundamentals",
                Summary: metadata.Summary,
                UnitCount: 0,
                LessonCount: 0,
                Domains: metadata.Domains,
                Prerequisites: metadata.Prerequisites,
                StudyGuideUrl: metadata.StudyGuideUrl,
                ExamUrl: metadata.ExamUrl,
                BlueprintDate: metadata.BlueprintDate,
                Lifecycle: metadata.Lifecycle,
                LifecycleNote:
                    "Certification active. Parcours Certigo planifie, en attente de contenu publie.",
                ExamDetailsNote: metadata.ExamDetailsNote,
                LearningAvailable: false,
                MigrationNote: metadata.MigrationNote)
        ];
    }
}
