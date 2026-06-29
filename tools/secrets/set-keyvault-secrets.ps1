<#
.SYNOPSIS
  Charge tous les secrets de signature mobile dans Azure Key Vault, en une commande.

.DESCRIPTION
  Lit un fichier de config local (clé=valeur, jamais committé) et pousse chaque
  valeur vers le Key Vault avec le bon nom de secret. Les entrées *_FILE sont
  encodées en base64 (keystore, certificat, profil, clé .p8) ou lues telles
  quelles (JSON du compte de service Play). Les entrées absentes sont ignorées,
  ce qui permet un chargement partiel (ex. Android seul d'abord).

  Pré-requis : Azure CLI (`az`) installé et authentifié (`az login`), avec le
  rôle "Key Vault Secrets Officer" sur le Key Vault cible.

.EXAMPLE
  ./set-keyvault-secrets.ps1 -VaultName law-certigo-dev-a2msqu

.EXAMPLE
  ./set-keyvault-secrets.ps1 -VaultName law-certigo-dev-a2msqu -ConfigPath .\mobile-secrets.env -DryRun
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $VaultName,
  [string] $ConfigPath = (Join-Path $PSScriptRoot 'mobile-secrets.env'),
  [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw "Azure CLI (az) introuvable. Installez-le puis exécutez 'az login'."
}
if (-not (Test-Path $ConfigPath)) {
  throw "Fichier de config introuvable : $ConfigPath`nCopiez mobile-secrets.env.example -> mobile-secrets.env et renseignez-le."
}

# Parse le fichier clé=valeur (ignore lignes vides et commentaires).
$cfg = @{}
foreach ($line in Get-Content -LiteralPath $ConfigPath) {
  $t = $line.Trim()
  if ($t -eq '' -or $t.StartsWith('#')) { continue }
  $idx = $t.IndexOf('=')
  if ($idx -lt 1) { continue }
  $cfg[$t.Substring(0, $idx).Trim()] = $t.Substring($idx + 1).Trim()
}

# Correspondance clé de config -> nom de secret Key Vault + nature.
$map = @(
  @{ Key = 'ANDROID_KEYSTORE_FILE';          Kv = 'mobile-android-keystore-base64';         Kind = 'fileB64' }
  @{ Key = 'ANDROID_KEYSTORE_PASSWORD';      Kv = 'mobile-android-keystore-password';       Kind = 'value'   }
  @{ Key = 'ANDROID_KEY_ALIAS';              Kv = 'mobile-android-key-alias';               Kind = 'value'   }
  @{ Key = 'ANDROID_KEY_PASSWORD';           Kv = 'mobile-android-key-password';            Kind = 'value'   }
  @{ Key = 'PLAY_SERVICE_ACCOUNT_JSON_FILE'; Kv = 'mobile-play-service-account-json';       Kind = 'fileRaw' }
  @{ Key = 'IOS_DIST_CERT_P12_FILE';         Kv = 'mobile-ios-dist-cert-p12-base64';        Kind = 'fileB64' }
  @{ Key = 'IOS_DIST_CERT_PASSWORD';         Kv = 'mobile-ios-dist-cert-password';          Kind = 'value'   }
  @{ Key = 'IOS_PROVISIONING_PROFILE_FILE';  Kv = 'mobile-ios-provisioning-profile-base64'; Kind = 'fileB64' }
  @{ Key = 'IOS_PROVISIONING_PROFILE_NAME';  Kv = 'mobile-ios-provisioning-profile-name';   Kind = 'value'   }
  @{ Key = 'IOS_TEAM_ID';                    Kv = 'mobile-ios-team-id';                     Kind = 'value'   }
  @{ Key = 'ASC_KEY_ID';                     Kv = 'mobile-asc-key-id';                      Kind = 'value'   }
  @{ Key = 'ASC_ISSUER_ID';                  Kv = 'mobile-asc-issuer-id';                   Kind = 'value'   }
  @{ Key = 'ASC_KEY_P8_FILE';                Kv = 'mobile-asc-key-p8-base64';               Kind = 'fileB64' }
  @{ Key = 'IOS_MATCH_PASSWORD';             Kv = 'mobile-ios-match-password';              Kind = 'value'   }
  @{ Key = 'IOS_MATCH_GIT_AUTH';             Kv = 'mobile-ios-match-git-auth';              Kind = 'value'   }
)

function Set-KvSecret {
  param([string] $Name, [string] $Value)
  if ($DryRun) { Write-Host "  [dry-run] $Name"; return }
  # On passe par un fichier temporaire (sans saut de ligne final) pour éviter
  # tout problème d'échappement sur la ligne de commande.
  $tmp = [IO.Path]::GetTempFileName()
  try {
    [IO.File]::WriteAllText($tmp, $Value)
    az keyvault secret set --vault-name $VaultName --name $Name --file $tmp --output none
    if ($LASTEXITCODE -ne 0) { throw "az keyvault secret set a échoué pour '$Name'." }
    Write-Host "  ✔ $Name"
  } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

Write-Host "Chargement des secrets mobiles vers le Key Vault '$VaultName'$(if($DryRun){' (dry-run)'})..."
$set = 0; $skipped = 0
foreach ($m in $map) {
  if (-not $cfg.ContainsKey($m.Key) -or [string]::IsNullOrWhiteSpace($cfg[$m.Key])) { $skipped++; continue }
  $raw = $cfg[$m.Key]
  switch ($m.Kind) {
    'value'   { $val = $raw }
    'fileRaw' { if (-not (Test-Path $raw)) { throw "Fichier introuvable pour $($m.Key) : $raw" }; $val = [IO.File]::ReadAllText($raw) }
    'fileB64' { if (-not (Test-Path $raw)) { throw "Fichier introuvable pour $($m.Key) : $raw" }; $val = [Convert]::ToBase64String([IO.File]::ReadAllBytes($raw)) }
  }
  Set-KvSecret -Name $m.Kv -Value $val
  $set++
}
Write-Host "Terminé : $set secret(s) défini(s), $skipped ignoré(s) (non renseignés)."
