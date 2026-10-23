import Foundation

public enum CertigoAppIconVariant: String, Codable, CaseIterable, Sendable {
  case standard
  case streakFire
  case streakAtRisk
  case masteryGold

  public var alternateIconName: String? {
    switch self {
    case .standard: nil
    case .streakFire: "CertigoIconStreakFire"
    case .streakAtRisk: "CertigoIconStreakAtRisk"
    case .masteryGold: "CertigoIconMasteryGold"
    }
  }

  public var previewAssetName: String {
    switch self {
    case .standard: "CertigoIconStandardPreview"
    case .streakFire: "CertigoIconStreakFirePreview"
    case .streakAtRisk: "CertigoIconStreakAtRiskPreview"
    case .masteryGold: "CertigoIconMasteryGoldPreview"
    }
  }

  public func shouldApply(
    supportsAlternateIcons: Bool,
    applicationIsActive: Bool,
    currentAlternateIconName: String?
  ) -> Bool {
    supportsAlternateIcons
      && applicationIsActive
      && alternateIconName != currentAlternateIconName
  }
}

public enum CertigoAppIconSelectionMode: String, Codable, CaseIterable, Sendable {
  case automatic
  case manual
}

public struct CertigoAppIconPreferences: Codable, Equatable, Sendable {
  public var mode: CertigoAppIconSelectionMode
  public var manualVariant: CertigoAppIconVariant

  public init(
    mode: CertigoAppIconSelectionMode = .automatic,
    manualVariant: CertigoAppIconVariant = .standard
  ) {
    self.mode = mode
    self.manualVariant = manualVariant
  }

  public func variant(
    for phase: CertigoWidgetPhase?,
    streakDays: Int?
  ) -> CertigoAppIconVariant {
    guard mode == .automatic else { return manualVariant }
    if phase == .streakAtRisk { return .streakAtRisk }
    if phase == .goalCompleted, let streakDays, streakDays >= 7 {
      return .masteryGold
    }
    if phase == .goalCompleted || (streakDays ?? 0) > 0 {
      return .streakFire
    }
    return .standard
  }
}

public struct CertigoAppIconCopy: Sendable {
  public let language: AppLanguage

  public init(language: AppLanguage) {
    self.language = language
  }

  public var sectionTitle: String {
    switch language {
    case .french: "Icône dynamique de l’app"
    case .english: "Dynamic app icon"
    case .hindi: "ऐप का बदलता आइकन"
    case .chineseSimplified: "动态应用图标"
    case .korean: "다이내믹 앱 아이콘"
    case .spanish: "Icono dinámico de la app"
    case .italian: "Icona dinamica dell’app"
    case .german: "Dynamisches App-Symbol"
    }
  }

  public var automaticMode: String {
    switch language {
    case .french: "Automatique selon la série"
    case .english: "Automatic by streak"
    case .hindi: "स्ट्रीक के अनुसार स्वचालित"
    case .chineseSimplified: "根据连续记录自动切换"
    case .korean: "연속 기록에 따라 자동"
    case .spanish: "Automático según la racha"
    case .italian: "Automatico in base alla serie"
    case .german: "Automatisch nach Serie"
    }
  }

  public var manualMode: String {
    switch language {
    case .french: "Manuel"
    case .english: "Manual"
    case .hindi: "मैन्युअल"
    case .chineseSimplified: "手动"
    case .korean: "수동"
    case .spanish: "Manual"
    case .italian: "Manuale"
    case .german: "Manuell"
    }
  }

  public func title(for variant: CertigoAppIconVariant) -> String {
    switch (language, variant) {
    case (.french, .standard): "Prism"
    case (.english, .standard): "Prism"
    case (.hindi, .standard): "प्रिज़्म"
    case (.chineseSimplified, .standard): "Prism"
    case (.korean, .standard): "Prism"
    case (.spanish, .standard): "Prism"
    case (.italian, .standard): "Prism"
    case (.german, .standard): "Prism"
    case (.french, .streakFire): "Série en feu"
    case (.english, .streakFire): "Streak fire"
    case (.hindi, .streakFire): "स्ट्रीक की लौ"
    case (.chineseSimplified, .streakFire): "连胜之火"
    case (.korean, .streakFire): "연속 기록의 불꽃"
    case (.spanish, .streakFire): "Racha en llamas"
    case (.italian, .streakFire): "Serie ardente"
    case (.german, .streakFire): "Serie in Flammen"
    case (.french, .streakAtRisk): "Série à préserver"
    case (.english, .streakAtRisk): "Streak at risk"
    case (.hindi, .streakAtRisk): "स्ट्रीक बचाएँ"
    case (.chineseSimplified, .streakAtRisk): "守护连续记录"
    case (.korean, .streakAtRisk): "연속 기록 지키기"
    case (.spanish, .streakAtRisk): "Racha por proteger"
    case (.italian, .streakAtRisk): "Serie da proteggere"
    case (.german, .streakAtRisk): "Serie schützen"
    case (.french, .masteryGold): "Maîtrise dorée"
    case (.english, .masteryGold): "Mastery gold"
    case (.hindi, .masteryGold): "गोल्ड मास्टरी"
    case (.chineseSimplified, .masteryGold): "金色精通"
    case (.korean, .masteryGold): "마스터리 골드"
    case (.spanish, .masteryGold): "Maestría dorada"
    case (.italian, .masteryGold): "Padronanza dorata"
    case (.german, .masteryGold): "Goldene Meisterschaft"
    }
  }

  public var systemConfirmationNote: String {
    switch language {
    case .french: "iOS affiche une confirmation système lors d’un changement réel d’icône."
    case .english: "iOS shows a system confirmation when the icon actually changes."
    case .hindi: "आइकन बदलने पर iOS सिस्टम पुष्टि दिखाता है।"
    case .chineseSimplified: "图标实际更改时，iOS 会显示系统确认。"
    case .korean: "아이콘이 실제로 바뀔 때 iOS 시스템 확인이 표시됩니다."
    case .spanish: "iOS muestra una confirmación del sistema cuando cambia el icono."
    case .italian: "iOS mostra una conferma di sistema quando l’icona cambia."
    case .german: "iOS zeigt bei einem tatsächlichen Symbolwechsel eine Systembestätigung."
    }
  }

  public var currentIconLabel: String {
    switch language {
    case .french: "Icône actuelle"
    case .english: "Current icon"
    case .hindi: "वर्तमान आइकन"
    case .chineseSimplified: "当前图标"
    case .korean: "현재 아이콘"
    case .spanish: "Icono actual"
    case .italian: "Icona attuale"
    case .german: "Aktuelles Symbol"
    }
  }

  public var automaticChoiceLabel: String {
    switch language {
    case .french: "Choix automatique"
    case .english: "Automatic choice"
    case .hindi: "स्वचालित चयन"
    case .chineseSimplified: "自动选择"
    case .korean: "자동 선택"
    case .spanish: "Selección automática"
    case .italian: "Scelta automatica"
    case .german: "Automatische Auswahl"
    }
  }

  public var unsupportedMessage: String {
    switch language {
    case .french: "Le changement d’icône n’est pas disponible sur cet appareil."
    case .english: "Changing the app icon isn’t available on this device."
    case .hindi: "इस डिवाइस पर ऐप आइकन बदलना उपलब्ध नहीं है।"
    case .chineseSimplified: "此设备不支持更改应用图标。"
    case .korean: "이 기기에서는 앱 아이콘을 변경할 수 없어요."
    case .spanish: "Este dispositivo no permite cambiar el icono de la app."
    case .italian: "Il cambio dell’icona non è disponibile su questo dispositivo."
    case .german: "Das Ändern des App-Symbols ist auf diesem Gerät nicht verfügbar."
    }
  }

  public var changeFailedMessage: String {
    switch language {
    case .french: "L’icône n’a pas pu être modifiée. Réessayez."
    case .english: "The app icon couldn’t be changed. Try again."
    case .hindi: "ऐप आइकन नहीं बदला जा सका। फिर से कोशिश करें।"
    case .chineseSimplified: "无法更改应用图标，请重试。"
    case .korean: "앱 아이콘을 변경하지 못했어요. 다시 시도해 주세요."
    case .spanish: "No se pudo cambiar el icono. Inténtalo de nuevo."
    case .italian: "Impossibile cambiare l’icona. Riprova."
    case .german: "Das App-Symbol konnte nicht geändert werden. Versuch es erneut."
    }
  }

  public var preferenceFailedMessage: String {
    switch language {
    case .french: "Le choix de l’icône n’a pas pu être enregistré."
    case .english: "The icon preference couldn’t be saved."
    case .hindi: "आइकन की पसंद सहेजी नहीं जा सकी।"
    case .chineseSimplified: "无法保存图标偏好设置。"
    case .korean: "아이콘 설정을 저장하지 못했어요."
    case .spanish: "No se pudo guardar la preferencia del icono."
    case .italian: "Impossibile salvare la preferenza dell’icona."
    case .german: "Die Symbolauswahl konnte nicht gespeichert werden."
    }
  }
}
