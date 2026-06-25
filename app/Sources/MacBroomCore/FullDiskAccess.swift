import Foundation

/// Best-effort detection of whether this app currently has **Full Disk Access**.
///
/// macOS exposes no direct API, so we probe a TCC-protected file that can only
/// be opened with FDA. Must run in the app process (TCC evaluates the caller).
///
/// Note: for an UNSIGNED local build, TCC ties the grant to the binary, so a
/// rebuild can invalidate a previously-granted permission — detection then
/// (correctly) reports "not granted" until re-granted. Signed/notarized
/// release builds keep the grant.
public enum FullDiskAccess {
    /// Files that require Full Disk Access to even open for reading.
    private static let probes: [String] = [
        "~/Library/Application Support/com.apple.TCC/TCC.db",
        "~/Library/Safari/CloudTabs.db",
        "~/Library/Application Support/com.apple.TCC/TCC.db-wal",
    ]

    public static var isGranted: Bool {
        let fm = FileManager.default
        for raw in probes {
            let path = (raw as NSString).expandingTildeInPath
            guard fm.fileExists(atPath: path) else { continue }
            // The file exists and we can stat it → try to actually open it.
            // A successful open means TCC let us through (FDA granted).
            if let fh = FileHandle(forReadingAtPath: path) {
                try? fh.close()
                return true
            }
            // Exists but can't open → TCC denied → no FDA.
            return false
        }
        // Couldn't even see a probe file (TCC hides the directory without FDA),
        // so treat as not granted.
        return false
    }
}
