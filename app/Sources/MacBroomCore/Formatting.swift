import Foundation

public enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useMB, .useGB, .useKB]
        return f
    }()

    public static func bytes(_ value: Int64) -> String {
        byteFormatter.string(fromByteCount: value)
    }
}
