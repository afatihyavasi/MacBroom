import Foundation

/// A short, accurate "why is this safe to remove?" hint for a clean candidate.
///
/// Conservative by design: everything mole surfaces is a regenerable cache, so
/// the default is `.reasonRegenerable`. The refinements only fire when the path
/// or label states the fact plainly (it's in the Trash; it's a superseded
/// version) — never a guess that could over-claim safety.
public enum CleanReason {
    public static func key(category: String, label: String, path: String) -> L10n {
        if path.range(of: "/.Trash", options: .caseInsensitive) != nil { return .reasonTrash }
        // mole only ever lists OLD versions (it keeps the current one), and the
        // word "version" appears in those curated labels, so this stays accurate.
        if label.range(of: "version", options: .caseInsensitive) != nil { return .reasonOldVersion }
        if category == "ai" { return .reasonAICache }
        return .reasonRegenerable
    }
}

public extension CleanCandidate {
    /// Localizable key for the "why is this safe?" hint shown under each row.
    var reasonKey: L10n { CleanReason.key(category: category, label: label, path: path) }
}
