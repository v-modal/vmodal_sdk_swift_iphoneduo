import Foundation
import XCTest

final class XcodeCompatibilityTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    func testXcode26ToolchainAndStarterProject() throws {
        let xcode = try String(contentsOf: root.appendingPathComponent(".xcode-version"))
        let project = try String(contentsOf: root.appendingPathComponent("example/StarterIOS/StarterIOS.xcodeproj/project.pbxproj"))
        XCTAssertEqual(xcode.trimmingCharacters(in: .whitespacesAndNewlines), "26.6")
        XCTAssertTrue(project.contains("LastUpgradeCheck = 2660"))
        XCTAssertTrue(project.contains("CreatedOnToolsVersion = 26.6"))
    }

    func testStarterUsesCompatibleFlexibleLayout() throws {
        let app = try String(contentsOf: root.appendingPathComponent("example/StarterIOS/StarterIOS/StarterIOSApp.swift"))
        let session = try String(contentsOf: root.appendingPathComponent("example/StarterIOS/StarterIOS/AppSession.swift"))
        let view = try String(contentsOf: root.appendingPathComponent("example/StarterIOS/StarterIOS/ContentView.swift"))
        XCTAssertTrue(app.contains("@StateObject private var session"))
        XCTAssertTrue(session.contains("private var upload: UploadTask"))
        XCTAssertTrue(session.contains("guard upload == nil"))
        XCTAssertTrue(view.contains("NavigationSplitView"))
        XCTAssertTrue(view.contains("frame(maxWidth:"))
        XCTAssertFalse(view.contains("UIScreen.main.bounds"))
    }

    func testFramebaseUsesTheSameAppleCompatibilityContract() throws {
        let rootPath = "example/05_framebase/"
        let project = try String(contentsOf: root.appendingPathComponent(rootPath + "Framebase.xcodeproj/project.pbxproj"))
        let app = try String(contentsOf: root.appendingPathComponent(rootPath + "Framebase/FramebaseApp.swift"))
        let library = try String(contentsOf: root.appendingPathComponent(rootPath + "Framebase/LibraryView.swift"))
        XCTAssertTrue(project.contains("IPHONEOS_DEPLOYMENT_TARGET = 16.0"))
        XCTAssertTrue(project.contains("SWIFT_STRICT_CONCURRENCY = complete"))
        XCTAssertTrue(project.contains("SWIFT_VERSION = 6.0"))
        XCTAssertTrue(project.contains("TARGETED_DEVICE_FAMILY = \"1,2\""))
        XCTAssertTrue(app.contains("@StateObject private var session"))
        XCTAssertTrue(library.contains("frame(maxWidth: .infinity)"))
        XCTAssertFalse(library.contains("UIScreen.main.bounds"))
        for resource in [
            "Framebase/Resources/Videos/neighborhood_crossing.mp4",
            "Framebase/Resources/Videos/downtown_traffic.mp4",
            "Framebase/Resources/Videos/evening_junction.mp4",
            "Framebase/Resources/Fonts/InstrumentSans.ttf",
            "Framebase/Resources/Fonts/OFL.txt",
        ] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(rootPath + resource).path), resource)
        }
    }
}

/* FUTURE_IPHONE_DUO_XCODE_27_1
final class DuoCompatibilityTests: XCTestCase {
    func testDuoMatrixCoversRequiredTransitions() throws {
        let matrix = try String(contentsOf: root.appendingPathComponent("docs/iphone_duo_acceptance.md"))
        for term in ["folded", "unfolded", "Split View", "safe areas", "Two windows", "no second"] {
            XCTAssertTrue(matrix.contains(term), term)
        }
    }
}
*/
