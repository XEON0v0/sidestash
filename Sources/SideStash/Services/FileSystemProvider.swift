import Foundation

protocol FileSystemProvider: AnyObject, Sendable {
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL]
    func moveItem(at srcURL: URL, to dstURL: URL) throws
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func removeItem(at URL: URL) throws
    func fileExists(atPath path: String) -> Bool
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    func replaceItemAt(_ originalItemURL: URL, withItemAt newItemURL: URL, backupItemName: String?, options: FileManager.ItemReplacementOptions) throws -> URL?
    func trashItem(at url: URL) throws -> URL
}

extension FileManager: FileSystemProvider {
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories, attributes: nil)
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL] {
        try contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
    }

    func trashItem(at url: URL) throws -> URL {
        var resultingItemURL: NSURL?
        try trashItem(at: url, resultingItemURL: &resultingItemURL)
        guard let result = resultingItemURL as? URL else {
            throw CocoaError(.fileNoSuchFile)
        }
        return result
    }
}
