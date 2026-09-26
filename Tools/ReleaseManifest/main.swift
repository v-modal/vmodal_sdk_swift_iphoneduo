import CryptoKit
import Foundation
import VModalSDK

let roots = [
    "Package.swift", ".xcode-version", ".swift-version", ".swift-format", ".gitignore", ".gitleaks.toml",
    "00_specs.md", "README.md", "CHANGELOG.md", "LICENSE", "install.sh", "build.sh", "run.sh", "test.sh",
    "cli.sh", "env.sh", "security_check.sh", "Sources", "Tests", "example", "Tools", "docs", "release",
]
let excluded = [".build", "DerivedData", "ztmp", ".swiftpm", "xcuserdata"]

func relativePath(_ url: URL, under directory: URL) -> String? {
    let root = directory.resolvingSymlinksInPath().standardizedFileURL.path
    let file = url.resolvingSymlinksInPath().standardizedFileURL.path
    let prefix = root.hasSuffix("/") ? root : root + "/"
    guard file.hasPrefix(prefix) else { return nil }
    return String(file.dropFirst(prefix.count))
}

func manifestFiles(_ directory: URL) -> [URL] {
    let keys: [URLResourceKey] = [.isRegularFileKey]
    let values = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys)
    return (values?.compactMap { $0 as? URL } ?? []).filter { url in
        guard let relative = relativePath(url, under: directory) else { return false }
        return (try? url.resourceValues(forKeys: Set(keys)).isRegularFile) == true
            && !excluded.contains(where: { relative.split(separator: "/").contains(Substring($0)) })
            && relative != "SOURCE_MANIFEST.sha256"
    }.sorted { $0.path < $1.path }
}

func writeManifest(_ directory: URL) throws {
    let rows = try manifestFiles(directory).map { url -> String in
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard let relative = relativePath(url, under: directory) else {
            throw ValidationError("manifest file is outside export directory: \(url.path)")
        }
        return "\(hash)  \(relative)"
    }
    try Data((rows.joined(separator: "\n") + "\n").utf8).write(to: directory.appendingPathComponent("SOURCE_MANIFEST.sha256"), options: .atomic)
}

func exportPackage(_ source: URL, _ destination: URL) throws {
    guard source.standardizedFileURL != destination.standardizedFileURL else { throw ValidationError("export destination must differ from source") }
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    for root in roots {
        let from = source.appendingPathComponent(root); let to = destination.appendingPathComponent(root)
        guard FileManager.default.fileExists(atPath: from.path) else { continue }
        try FileManager.default.createDirectory(at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: from, to: to)
    }
    for file in manifestFiles(destination) {
        guard let relative = relativePath(file, under: destination) else { continue }
        if excluded.contains(where: { relative.split(separator: "/").contains(Substring($0)) }) { try FileManager.default.removeItem(at: file) }
    }
    try writeManifest(destination)
}

func verifyVersion(_ directory: URL) throws {
    let checks = [
        ("Package.swift", "SDK release: \(vmodalSDKVersion)"),
        ("Sources/VModalSDK/VModalClient.swift", "vmodalSDKVersion = \"\(vmodalSDKVersion)\""),
        ("CHANGELOG.md", "## \(vmodalSDKVersion)"),
        ("Sources/VModalSDK/VModalSDK.docc/VModalSDK.md", "VModal \(vmodalSDKVersion)"),
        ("release/public_publish.yml", "SDK_VERSION: \(vmodalSDKVersion)"),
    ]
    for (path, marker) in checks {
        let text = try String(contentsOf: directory.appendingPathComponent(path))
        guard text.contains(marker) else { throw ValidationError("version mismatch in \(path)") }
    }
}

let args = Array(ProcessInfo.processInfo.arguments.dropFirst())
do {
    switch args.first {
    case "version": try verifyVersion(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)); print(vmodalSDKVersion)
    case "manifest": guard args.count == 2 else { throw ValidationError("Usage: ReleaseManifest manifest DIRECTORY") }; try writeManifest(URL(fileURLWithPath: args[1]).standardizedFileURL)
    case "export": guard args.count == 3 else { throw ValidationError("Usage: ReleaseManifest export SOURCE DESTINATION") }; try exportPackage(URL(fileURLWithPath: args[1]).standardizedFileURL, URL(fileURLWithPath: args[2]).standardizedFileURL)
    default: throw ValidationError("Usage: ReleaseManifest version|manifest|export")
    }
} catch { FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1) }
