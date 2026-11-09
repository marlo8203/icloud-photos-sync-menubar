import Foundation

/// The local files that `icloudpd --auto-delete --dry-run` says it would delete: the files of photos that
/// were deleted in iCloud. Nothing is deleted by that run, so the app can move them to the Trash itself.
public func parseWouldDelete(_ output: String) -> [String] {
    let marker = "[DRY RUN] Would delete "
    var paths: [String] = []
    for line in output.split(whereSeparator: \.isNewline) {
        guard let range = line.range(of: marker) else { continue }
        let rest = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        // "… in iCloud library …" is the message of --delete-list, not a local file
        if rest.isEmpty || rest.contains(" in iCloud library") { continue }
        if !paths.contains(rest) { paths.append(rest) }
    }
    return paths
}

/// Sidecar files go to the Trash with their photo, but they are not photos for Photos.
public func isSidecar(_ path: String) -> Bool {
    path.lowercased().hasSuffix(".xmp")
}

/// `icloudpd --delete-list` ends with exit code 1 when an entry was not found, ambiguous or refused, and logs
/// `Delete list summary: deleted=1 not_found=1 failed=0 ambiguous=0` (`would_delete=` in a dry run).
/// A photo that is not found is already gone from iCloud, so nothing is left to retry; refused (iCloud asked to
/// try again later) and ambiguous entries still are a problem.
public func deleteListSucceeded(exitCode: Int32, output: String) -> Bool {
    if exitCode == 0 { return true }
    guard exitCode == 1, let line = output.split(whereSeparator: \.isNewline).last(where: { $0.contains("Delete list summary:") })
    else { return false }
    func count(_ key: String) -> Int? {
        guard let range = line.range(of: "\(key)=") else { return nil }
        return Int(line[range.upperBound...].prefix(while: \.isNumber))
    }
    return count("failed") == 0 && count("ambiguous") == 0
}
