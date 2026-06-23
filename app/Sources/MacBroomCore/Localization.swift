import Foundation

/// Supported UI languages. `.system` follows the OS preferred languages and
/// falls back to English when none of the supported languages match.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, en, tr, es, fr

    public var id: String { rawValue }

    /// Name shown in the language picker (in its own language; `.system`
    /// localizes to the active language).
    public var displayName: String {
        switch self {
        case .system: return Localization.string(.languageSystem)
        case .en: return "English"
        case .tr: return "Türkçe"
        case .es: return "Español"
        case .fr: return "Français"
        }
    }

    /// Concrete language used for lookups — resolves `.system` against the OS
    /// preferred languages, defaulting to English when unsupported.
    public var resolved: AppLanguage {
        guard self == .system else { return self }
        for code in Locale.preferredLanguages {
            switch code.lowercased().prefix(2) {
            case "tr": return .tr
            case "es": return .es
            case "fr": return .fr
            case "en": return .en
            default: continue
            }
        }
        return .en
    }
}

/// Every user-facing string key. Values with `%@` / `%d` are `String(format:)`
/// templates; see `Localization.tables`.
public enum L10n: String, CaseIterable {
    case tabAI, tabSystem, tabDeveloper, tabApps, tabAutomation
    case refreshHelp, settingsHelp, open, quit, clean, loading, back, backToList
    case fdaTitle, fdaBannerDesc, fdaSettingsDesc, openFDA, openInSettings
    case searchingTargets, scanningTargets, cleaningProgress, freed, backTargets, selectedSuffix
    case cleaningProgressBytes, removingProgressBytes
    case removingProgress, removedFreed, removedPartial, someProtected, itemsInUse
    case removableEmpty, itemsBytes, remove, confirmDeleteTitle, cancel, confirmDeleteMessage
    case aiEmpty, aiSafety, groupCountBytes, systemSafety, selectAll, deselectAll, systemEmpty
    case analyzeQuestion, analyzeSubtitle, noTargetsInCategory, clearSelection, analyzeButton
    case settingsTitle, done, deletionMethod, about, aboutVersion, engineAttribution, totalReclaimed
    case language, languageSystem, disk, memory, diskFree, memoryTotal
    case categoryAI, categorySystem, categoryDeveloper
    case targetAppCaches, targetEditors, targetGuiApps, targetDevMisc
    case targetXcode, targetPkgCaches
    case autoCleanTitle, autoCleanDesc, autoCleanNoTools, autoCleanLast
    case freqOff, freqHourly, freqDaily, freqWeekly, freqMonthly
    case appearance, appearanceSystem, appearanceLight, appearanceDark
    case aiAutomationInfo, aiAutomationOpen, automationTitle, automationDesc, save
    case everyNHours, weekdayLabel, timeLabel, monthDayLabel, intervalLabel
    case deletePermanentTitle, deleteTrashTitle, deletePermanentDetail, deleteTrashDetail
    case errEngineNotFound, errNonZero, errDecode
    case diskAnalysisTitle, diskAnalysisOpen, diskAnalysisDesc, analyzing, largeFilesEmpty
    case revealInFinder, deleteFilesButton, largeFilesWarning
}

/// String lookup + persisted language selection. Core display strings
/// (`DeleteMode`, `CleanCategory`, `EngineError`) read `current`; the SwiftUI
/// layer drives it through `LocalizationManager`.
public enum Localization {
    public static let defaultsKey = "appLanguage"

    /// Persisted selection (defaults to `.system`).
    public static var current: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? AppLanguage.system.rawValue
            return AppLanguage(rawValue: raw) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    /// Resolve a key for the given (or current) language, falling back to
    /// English, then to the raw key name.
    public static func string(_ key: L10n, language: AppLanguage = current) -> String {
        let lang = language.resolved
        return tables[lang]?[key] ?? tables[.en]?[key] ?? key.rawValue
    }

    static let tables: [AppLanguage: [L10n: String]] = [.en: en, .tr: tr, .es: es, .fr: fr]

    // MARK: - English (also the fallback)
    private static let en: [L10n: String] = [
        .tabAI: "AI", .tabSystem: "System", .tabDeveloper: "Developer", .tabApps: "Apps", .tabAutomation: "Automation",
        .refreshHelp: "Rediscover targets", .settingsHelp: "Settings",
        .open: "Open", .quit: "Quit", .clean: "Clean", .loading: "Loading…",
        .back: "Back", .backToList: "Back to list",
        .fdaTitle: "Full Disk Access",
        .fdaBannerDesc: "Grant access to clean all caches.",
        .fdaSettingsDesc: "MacBroom needs Full Disk Access to clean some system caches.",
        .openFDA: "Open Full Disk Access", .openInSettings: "Open in System Settings",
        .searchingTargets: "Searching targets…", .scanningTargets: "Scanning selected targets…",
        .cleaningProgress: "Cleaning… %d/%d", .freed: "%@ freed",
        .cleaningProgressBytes: "Cleaning… %d/%d · %@ freed",
        .removingProgressBytes: "Removing… %d/%d · %@ freed",
        .backTargets: "Targets", .selectedSuffix: "%@ selected",
        .removingProgress: "Removing… %d/%d", .removedFreed: "Removed · %@ freed",
        .removedPartial: "%@ freed · %d item(s) couldn’t be removed",
        .someProtected: "Some items are in a protected location. Granting Full Disk Access may complete removal.",
        .itemsInUse: "These items may be in use by another app.",
        .removableEmpty: "No removable apps found.",
        .itemsBytes: "%d item(s) · %@", .remove: "Remove",
        .confirmDeleteTitle: "Permanently delete %@ and %d selected item(s)?",
        .cancel: "Cancel",
        .confirmDeleteMessage: "This can’t be undone. System-critical components are protected.",
        .aiEmpty: "No AI cache to clean.",
        .aiSafety: "Identity, sessions, memory and history are preserved — only regenerable caches are listed.",
        .groupCountBytes: "%d · %@",
        .systemSafety: "Review first — only regenerable caches are listed.",
        .selectAll: "Select all", .deselectAll: "Deselect all", .systemEmpty: "No system cache to clean.",
        .analyzeQuestion: "What should we analyze?",
        .analyzeSubtitle: "Only your selection is scanned — it’s faster.",
        .noTargetsInCategory: "No targets found in this category.",
        .clearSelection: "Clear", .analyzeButton: "Analyze (%d)",
        .settingsTitle: "Settings", .done: "Done", .deletionMethod: "Deletion method",
        .about: "About", .aboutVersion: "MacBroom %@ · GPL-3.0",
        .engineAttribution: "Cleaning engine provided by tw93/mole (GPL-3.0).",
        .totalReclaimed: "Total reclaimed: %@",
        .language: "Language", .languageSystem: "System (automatic)",
        .disk: "Disk", .memory: "Memory", .diskFree: "%@ free", .memoryTotal: "%@ total",
        .categoryAI: "AI Tools", .categorySystem: "System", .categoryDeveloper: "Developer",
        .targetAppCaches: "App caches", .targetEditors: "Code editors",
        .targetGuiApps: "GUI app caches", .targetDevMisc: "Developer leftovers",
        .targetXcode: "Xcode DerivedData", .targetPkgCaches: "Package manager caches",
        .autoCleanTitle: "Automatic AI cleaning",
        .autoCleanDesc: "Clean a tool's caches automatically on a schedule.",
        .autoCleanNoTools: "No AI tools detected yet.", .autoCleanLast: "Last cleaned: %@",
        .freqOff: "Off", .freqHourly: "Hourly", .freqDaily: "Daily",
        .freqWeekly: "Weekly", .freqMonthly: "Monthly",
        .appearance: "Appearance", .appearanceSystem: "System", .appearanceLight: "Light", .appearanceDark: "Dark",
        .aiAutomationInfo: "Schedule MacBroom to clean your AI caches automatically.",
        .aiAutomationOpen: "Set up automation",
        .automationTitle: "AI Automation", .automationDesc: "Choose when each tool is cleaned. Applied when you press Save.",
        .save: "Save", .everyNHours: "Every %d h", .weekdayLabel: "Day", .timeLabel: "Time",
        .monthDayLabel: "Day of month", .intervalLabel: "Interval",
        .deletePermanentTitle: "Delete permanently", .deleteTrashTitle: "Move to Trash",
        .deletePermanentDetail: "Reclaims space immediately (can’t be undone).",
        .deleteTrashDetail: "Reversible; space frees up when the Trash is emptied.",
        .errEngineNotFound: "Cleaning engine not found.",
        .errNonZero: "Engine failed (%d): %@", .errDecode: "Couldn’t parse engine output: %@",
        .diskAnalysisTitle: "Disk Analysis",
        .diskAnalysisOpen: "Find large files",
        .diskAnalysisDesc: "The largest files in your home folder. These are your own files, not caches.",
        .analyzing: "Scanning for large files…",
        .largeFilesEmpty: "No large files found.",
        .revealInFinder: "Reveal in Finder",
        .deleteFilesButton: "Delete %d file(s)",
        .largeFilesWarning: "These are your personal files, not regenerable caches. They will be moved to the Trash — this can’t be undone from here.",
    ]

    // MARK: - Turkish
    private static let tr: [L10n: String] = [
        .tabAI: "AI", .tabSystem: "Sistem", .tabDeveloper: "Geliştirici", .tabApps: "Uygulamalar", .tabAutomation: "Otomasyon",
        .refreshHelp: "Hedefleri yeniden bul", .settingsHelp: "Ayarlar",
        .open: "Aç", .quit: "Çıkış", .clean: "Temizle", .loading: "Yükleniyor…",
        .back: "Geri", .backToList: "Listeye dön",
        .fdaTitle: "Tam Disk Erişimi",
        .fdaBannerDesc: "Tüm önbellekleri temizlemek için izin verin.",
        .fdaSettingsDesc: "Bazı sistem önbelleklerini temizlemek için MacBroom’a Tam Disk Erişimi vermeniz gerekir.",
        .openFDA: "Tam Disk Erişimi’ni Aç", .openInSettings: "Sistem Ayarları’nda Aç",
        .searchingTargets: "Hedefler aranıyor…", .scanningTargets: "Seçili hedefler taranıyor…",
        .cleaningProgress: "Temizleniyor… %d/%d", .freed: "%@ boşaltıldı",
        .cleaningProgressBytes: "Temizleniyor… %d/%d · %@ boşaltıldı",
        .removingProgressBytes: "Kaldırılıyor… %d/%d · %@ boşaltıldı",
        .backTargets: "Hedefler", .selectedSuffix: "%@ seçili",
        .removingProgress: "Kaldırılıyor… %d/%d", .removedFreed: "Kaldırıldı · %@ boşaltıldı",
        .removedPartial: "%@ boşaltıldı · %d öğe silinemedi",
        .someProtected: "Bazı öğeler korunan konumda. Tam Disk Erişimi vermek silmeyi tamamlayabilir.",
        .itemsInUse: "Bu öğeler başka bir uygulama tarafından kullanılıyor olabilir.",
        .removableEmpty: "Kaldırılabilir uygulama bulunamadı.",
        .itemsBytes: "%d öğe · %@", .remove: "Kaldır",
        .confirmDeleteTitle: "%@ ve seçili %d öğe kalıcı olarak silinsin mi?",
        .cancel: "Vazgeç",
        .confirmDeleteMessage: "Bu işlem geri alınamaz. Sistem-kritik bileşenler korunur.",
        .aiEmpty: "Temizlenecek AI cache bulunamadı.",
        .aiSafety: "Kimlik, oturum, hafıza ve geçmiş verileri korunur — yalnızca yeniden üretilebilir cache listelenir.",
        .groupCountBytes: "%d · %@",
        .systemSafety: "Önce gözden geçirin — yalnızca yeniden oluşturulabilir önbellekler listelenir.",
        .selectAll: "Tümünü seç", .deselectAll: "Seçimi kaldır", .systemEmpty: "Temizlenecek sistem önbelleği bulunamadı.",
        .analyzeQuestion: "Neyi analiz edelim?",
        .analyzeSubtitle: "Yalnızca seçtikleriniz taranır — daha hızlıdır.",
        .noTargetsInCategory: "Bu kategoride hedef bulunamadı.",
        .clearSelection: "Temizle", .analyzeButton: "Analiz Et (%d)",
        .settingsTitle: "Ayarlar", .done: "Bitti", .deletionMethod: "Silme yöntemi",
        .about: "Hakkında", .aboutVersion: "MacBroom %@ · GPL-3.0",
        .engineAttribution: "Temizleme motoru tw93/mole (GPL-3.0) tarafından sağlanır.",
        .totalReclaimed: "Toplam kazanılan: %@",
        .language: "Dil", .languageSystem: "Sistem (otomatik)",
        .disk: "Disk", .memory: "Bellek", .diskFree: "%@ boş", .memoryTotal: "%@ toplam",
        .categoryAI: "AI Araçları", .categorySystem: "Sistem", .categoryDeveloper: "Geliştirici",
        .targetAppCaches: "Uygulama önbellekleri", .targetEditors: "Kod editörleri",
        .targetGuiApps: "GUI uygulama önbellekleri", .targetDevMisc: "Geliştirici artıkları",
        .targetXcode: "Xcode DerivedData", .targetPkgCaches: "Paket yöneticisi önbellekleri",
        .autoCleanTitle: "Otomatik AI temizliği",
        .autoCleanDesc: "Bir aracın önbelleklerini belirlenen sıklıkta otomatik temizler.",
        .autoCleanNoTools: "Henüz AI aracı bulunamadı.", .autoCleanLast: "Son temizlik: %@",
        .freqOff: "Kapalı", .freqHourly: "Saatlik", .freqDaily: "Günlük",
        .freqWeekly: "Haftalık", .freqMonthly: "Aylık",
        .appearance: "Görünüm", .appearanceSystem: "Sistem", .appearanceLight: "Açık", .appearanceDark: "Koyu",
        .aiAutomationInfo: "MacBroom'un AI önbelleklerini otomatik temizlemesini planlayın.",
        .aiAutomationOpen: "Otomasyonu ayarla",
        .automationTitle: "AI Otomasyonu", .automationDesc: "Her aracın ne zaman temizleneceğini seçin. Kaydet'e bastığınızda uygulanır.",
        .save: "Kaydet", .everyNHours: "Her %d saatte", .weekdayLabel: "Gün", .timeLabel: "Saat",
        .monthDayLabel: "Ayın günü", .intervalLabel: "Aralık",
        .deletePermanentTitle: "Kalıcı olarak sil", .deleteTrashTitle: "Çöp Kutusu’na taşı",
        .deletePermanentDetail: "Alanı hemen geri kazanır (geri alınamaz).",
        .deleteTrashDetail: "Geri alınabilir; alan Çöp boşaltılınca boşalır.",
        .errEngineNotFound: "Temizleme motoru bulunamadı.",
        .errNonZero: "Motor hata verdi (%d): %@", .errDecode: "Motor çıktısı çözümlenemedi: %@",
        .diskAnalysisTitle: "Disk Analizi",
        .diskAnalysisOpen: "Büyük dosyaları bul",
        .diskAnalysisDesc: "Ev klasörünüzdeki en büyük dosyalar. Bunlar önbellek değil, kendi dosyalarınızdır.",
        .analyzing: "Büyük dosyalar taranıyor…",
        .largeFilesEmpty: "Büyük dosya bulunamadı.",
        .revealInFinder: "Finder’da göster",
        .deleteFilesButton: "%d dosyayı sil",
        .largeFilesWarning: "Bunlar yeniden oluşan önbellekler değil, kişisel dosyalarınızdır. Çöp Kutusu’na taşınır — buradan geri alınamaz.",
    ]

    // MARK: - Spanish
    private static let es: [L10n: String] = [
        .tabAI: "IA", .tabSystem: "Sistema", .tabDeveloper: "Desarrollo", .tabApps: "Apps", .tabAutomation: "Automatización",
        .refreshHelp: "Volver a buscar objetivos", .settingsHelp: "Ajustes",
        .open: "Abrir", .quit: "Salir", .clean: "Limpiar", .loading: "Cargando…",
        .back: "Atrás", .backToList: "Volver a la lista",
        .fdaTitle: "Acceso a Todo el Disco",
        .fdaBannerDesc: "Concede acceso para limpiar todas las cachés.",
        .fdaSettingsDesc: "MacBroom necesita Acceso a Todo el Disco para limpiar algunas cachés del sistema.",
        .openFDA: "Abrir Acceso a Todo el Disco", .openInSettings: "Abrir en Ajustes del Sistema",
        .searchingTargets: "Buscando objetivos…", .scanningTargets: "Analizando los objetivos seleccionados…",
        .cleaningProgress: "Limpiando… %d/%d", .freed: "%@ liberados",
        .cleaningProgressBytes: "Limpiando… %d/%d · %@ liberados",
        .removingProgressBytes: "Eliminando… %d/%d · %@ liberados",
        .backTargets: "Objetivos", .selectedSuffix: "%@ seleccionados",
        .removingProgress: "Eliminando… %d/%d", .removedFreed: "Eliminado · %@ liberados",
        .removedPartial: "%@ liberados · no se pudieron eliminar %d elemento(s)",
        .someProtected: "Algunos elementos están en una ubicación protegida. Conceder Acceso a Todo el Disco puede completar la eliminación.",
        .itemsInUse: "Es posible que otra app esté usando estos elementos.",
        .removableEmpty: "No se encontraron apps que se puedan eliminar.",
        .itemsBytes: "%d elemento(s) · %@", .remove: "Eliminar",
        .confirmDeleteTitle: "¿Eliminar permanentemente %@ y %d elemento(s) seleccionado(s)?",
        .cancel: "Cancelar",
        .confirmDeleteMessage: "Esto no se puede deshacer. Los componentes críticos del sistema están protegidos.",
        .aiEmpty: "No hay caché de IA para limpiar.",
        .aiSafety: "Se conservan identidad, sesiones, memoria e historial — solo se listan cachés regenerables.",
        .groupCountBytes: "%d · %@",
        .systemSafety: "Revisa primero — solo se listan cachés regenerables.",
        .selectAll: "Seleccionar todo", .deselectAll: "Deseleccionar todo", .systemEmpty: "No hay caché del sistema para limpiar.",
        .analyzeQuestion: "¿Qué analizamos?",
        .analyzeSubtitle: "Solo se analiza tu selección — es más rápido.",
        .noTargetsInCategory: "No se encontraron objetivos en esta categoría.",
        .clearSelection: "Limpiar", .analyzeButton: "Analizar (%d)",
        .settingsTitle: "Ajustes", .done: "Listo", .deletionMethod: "Método de eliminación",
        .about: "Acerca de", .aboutVersion: "MacBroom %@ · GPL-3.0",
        .engineAttribution: "Motor de limpieza proporcionado por tw93/mole (GPL-3.0).",
        .totalReclaimed: "Total recuperado: %@",
        .language: "Idioma", .languageSystem: "Sistema (automático)",
        .disk: "Disco", .memory: "Memoria", .diskFree: "%@ libres", .memoryTotal: "%@ en total",
        .categoryAI: "Herramientas de IA", .categorySystem: "Sistema", .categoryDeveloper: "Desarrollo",
        .targetAppCaches: "Cachés de apps", .targetEditors: "Editores de código",
        .targetGuiApps: "Cachés de apps con interfaz", .targetDevMisc: "Restos de desarrollo",
        .targetXcode: "Xcode DerivedData", .targetPkgCaches: "Cachés de gestores de paquetes",
        .autoCleanTitle: "Limpieza automática de IA",
        .autoCleanDesc: "Limpia las cachés de una herramienta según una frecuencia.",
        .autoCleanNoTools: "Aún no se detectan herramientas de IA.", .autoCleanLast: "Última limpieza: %@",
        .freqOff: "Apagado", .freqHourly: "Cada hora", .freqDaily: "Diario",
        .freqWeekly: "Semanal", .freqMonthly: "Mensual",
        .appearance: "Apariencia", .appearanceSystem: "Sistema", .appearanceLight: "Claro", .appearanceDark: "Oscuro",
        .aiAutomationInfo: "Programa MacBroom para limpiar tus cachés de IA automáticamente.",
        .aiAutomationOpen: "Configurar automatización",
        .automationTitle: "Automatización de IA", .automationDesc: "Elige cuándo se limpia cada herramienta. Se aplica al pulsar Guardar.",
        .save: "Guardar", .everyNHours: "Cada %d h", .weekdayLabel: "Día", .timeLabel: "Hora",
        .monthDayLabel: "Día del mes", .intervalLabel: "Intervalo",
        .deletePermanentTitle: "Eliminar permanentemente", .deleteTrashTitle: "Mover a la Papelera",
        .deletePermanentDetail: "Libera espacio de inmediato (no se puede deshacer).",
        .deleteTrashDetail: "Reversible; el espacio se libera al vaciar la Papelera.",
        .errEngineNotFound: "No se encontró el motor de limpieza.",
        .errNonZero: "El motor falló (%d): %@", .errDecode: "No se pudo analizar la salida del motor: %@",
        .diskAnalysisTitle: "Análisis de disco",
        .diskAnalysisOpen: "Buscar archivos grandes",
        .diskAnalysisDesc: "Los archivos más grandes de tu carpeta de inicio. Son tus propios archivos, no cachés.",
        .analyzing: "Buscando archivos grandes…",
        .largeFilesEmpty: "No se encontraron archivos grandes.",
        .revealInFinder: "Mostrar en Finder",
        .deleteFilesButton: "Eliminar %d archivo(s)",
        .largeFilesWarning: "Son tus archivos personales, no cachés regenerables. Se moverán a la Papelera — esto no se puede deshacer desde aquí.",
    ]

    // MARK: - French
    private static let fr: [L10n: String] = [
        .tabAI: "IA", .tabSystem: "Système", .tabDeveloper: "Développeur", .tabApps: "Apps", .tabAutomation: "Automatisation",
        .refreshHelp: "Rechercher à nouveau les cibles", .settingsHelp: "Réglages",
        .open: "Ouvrir", .quit: "Quitter", .clean: "Nettoyer", .loading: "Chargement…",
        .back: "Retour", .backToList: "Retour à la liste",
        .fdaTitle: "Accès complet au disque",
        .fdaBannerDesc: "Autorisez l’accès pour nettoyer tous les caches.",
        .fdaSettingsDesc: "MacBroom a besoin de l’Accès complet au disque pour nettoyer certains caches système.",
        .openFDA: "Ouvrir l’Accès complet au disque", .openInSettings: "Ouvrir dans Réglages Système",
        .searchingTargets: "Recherche des cibles…", .scanningTargets: "Analyse des cibles sélectionnées…",
        .cleaningProgress: "Nettoyage… %d/%d", .freed: "%@ libérés",
        .cleaningProgressBytes: "Nettoyage… %d/%d · %@ libérés",
        .removingProgressBytes: "Suppression… %d/%d · %@ libérés",
        .backTargets: "Cibles", .selectedSuffix: "%@ sélectionnés",
        .removingProgress: "Suppression… %d/%d", .removedFreed: "Supprimé · %@ libérés",
        .removedPartial: "%@ libérés · %d élément(s) n’ont pas pu être supprimés",
        .someProtected: "Certains éléments sont dans un emplacement protégé. Accorder l’Accès complet au disque peut terminer la suppression.",
        .itemsInUse: "Ces éléments sont peut-être utilisés par une autre app.",
        .removableEmpty: "Aucune app supprimable trouvée.",
        .itemsBytes: "%d élément(s) · %@", .remove: "Supprimer",
        .confirmDeleteTitle: "Supprimer définitivement %@ et %d élément(s) sélectionné(s) ?",
        .cancel: "Annuler",
        .confirmDeleteMessage: "Cette action est irréversible. Les composants critiques du système sont protégés.",
        .aiEmpty: "Aucun cache d’IA à nettoyer.",
        .aiSafety: "Identité, sessions, mémoire et historique sont préservés — seuls les caches régénérables sont listés.",
        .groupCountBytes: "%d · %@",
        .systemSafety: "Vérifiez d’abord — seuls les caches régénérables sont listés.",
        .selectAll: "Tout sélectionner", .deselectAll: "Tout désélectionner", .systemEmpty: "Aucun cache système à nettoyer.",
        .analyzeQuestion: "Que faut-il analyser ?",
        .analyzeSubtitle: "Seule votre sélection est analysée — c’est plus rapide.",
        .noTargetsInCategory: "Aucune cible trouvée dans cette catégorie.",
        .clearSelection: "Effacer", .analyzeButton: "Analyser (%d)",
        .settingsTitle: "Réglages", .done: "Terminé", .deletionMethod: "Méthode de suppression",
        .about: "À propos", .aboutVersion: "MacBroom %@ · GPL-3.0",
        .engineAttribution: "Moteur de nettoyage fourni par tw93/mole (GPL-3.0).",
        .totalReclaimed: "Total récupéré : %@",
        .language: "Langue", .languageSystem: "Système (automatique)",
        .disk: "Disque", .memory: "Mémoire", .diskFree: "%@ libres", .memoryTotal: "%@ au total",
        .categoryAI: "Outils d’IA", .categorySystem: "Système", .categoryDeveloper: "Développeur",
        .targetAppCaches: "Caches d’apps", .targetEditors: "Éditeurs de code",
        .targetGuiApps: "Caches d’apps graphiques", .targetDevMisc: "Restes de développement",
        .targetXcode: "Xcode DerivedData", .targetPkgCaches: "Caches des gestionnaires de paquets",
        .autoCleanTitle: "Nettoyage IA automatique",
        .autoCleanDesc: "Nettoie les caches d’un outil selon une fréquence définie.",
        .autoCleanNoTools: "Aucun outil d’IA détecté pour l’instant.", .autoCleanLast: "Dernier nettoyage : %@",
        .freqOff: "Désactivé", .freqHourly: "Toutes les heures", .freqDaily: "Quotidien",
        .freqWeekly: "Hebdomadaire", .freqMonthly: "Mensuel",
        .appearance: "Apparence", .appearanceSystem: "Système", .appearanceLight: "Clair", .appearanceDark: "Sombre",
        .aiAutomationInfo: "Planifiez le nettoyage automatique de vos caches d'IA par MacBroom.",
        .aiAutomationOpen: "Configurer l'automatisation",
        .automationTitle: "Automatisation IA", .automationDesc: "Choisissez quand chaque outil est nettoyé. Appliqué quand vous enregistrez.",
        .save: "Enregistrer", .everyNHours: "Toutes les %d h", .weekdayLabel: "Jour", .timeLabel: "Heure",
        .monthDayLabel: "Jour du mois", .intervalLabel: "Intervalle",
        .deletePermanentTitle: "Supprimer définitivement", .deleteTrashTitle: "Mettre à la corbeille",
        .deletePermanentDetail: "Libère l’espace immédiatement (irréversible).",
        .deleteTrashDetail: "Réversible ; l’espace est libéré en vidant la corbeille.",
        .errEngineNotFound: "Moteur de nettoyage introuvable.",
        .errNonZero: "Le moteur a échoué (%d) : %@", .errDecode: "Impossible d’analyser la sortie du moteur : %@",
        .diskAnalysisTitle: "Analyse du disque",
        .diskAnalysisOpen: "Trouver les gros fichiers",
        .diskAnalysisDesc: "Les plus gros fichiers de votre dossier personnel. Ce sont vos fichiers, pas des caches.",
        .analyzing: "Recherche de gros fichiers…",
        .largeFilesEmpty: "Aucun gros fichier trouvé.",
        .revealInFinder: "Afficher dans le Finder",
        .deleteFilesButton: "Supprimer %d fichier(s)",
        .largeFilesWarning: "Ce sont vos fichiers personnels, pas des caches régénérables. Ils seront placés dans la Corbeille — irréversible depuis ici.",
    ]
}
