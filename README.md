<div align="center">
  <img src="docs/assets/vmodal-swift-iphone-duo.png" alt="VModal video search and editing SDK" width="100%">
  <h1>VModal for Apple platforms</h1>
  <p><strong>Give your iOS and macOS apps a multimodal memory.</strong></p>
  <p>Upload video. Find moments by meaning, speech, text, or imagery.<br>Keep the experience native, typed, and 100% Swift.</p>
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift 6.0">
  <img src="https://img.shields.io/badge/iOS-16%2B-111111?logo=apple" alt="iOS 16 or newer">
  <img src="https://img.shields.io/badge/macOS-13%2B-111111?logo=apple" alt="macOS 13 or newer">
  <img src="https://img.shields.io/badge/Xcode-26.6%2B-147EFB?logo=xcode&logoColor=white" alt="Xcode 26.6 or newer">
  <img src="https://img.shields.io/badge/license-MIT-34C759" alt="MIT license">
</div>

<br>

## Start here: support, documentation, demo, and API key

| | Resource | Link |
|---|---|---|
| 💬 | **Discord support** | [Join the V-Modal AI Discord](https://discord.gg/XGxgBQqkaY) |
| 📚 | **SDK documentation** | [Read the Swift package reference](https://v-modal.github.io/vmodal_sdk_swift_iphoneduo/documentation/vmodalsdk/) |
| 📱 | **Starter app and community** | [Open the StarterIOS example](example/StarterIOS) or [visit r/v_modal](https://www.reddit.com/r/v_modal/) |
| 🎞️ | **Framebase product example** | [Browse, prepare, search, and play a local street-video archive](example/05_framebase) |
| 🔑 | **Get an API key** | [Request a VModal API key](https://v-modal.com/page/contact.ts) |

<p align="center"><em>Turn every video library into an experience your users can explore.</em></p>

## Build the feature people remember

VModal brings multimodal video search and mobile-friendly uploads to Swift with
a small, strongly typed API. Your app owns the interface; the SDK handles the
VModal gateway, request models, responses, streaming uploads, progress, and
cancellation.

| Your Apple experience | VModal gives you |
|---|---|
| “Find the cyclist in the red jacket” | Semantic video and image search |
| Search words spoken or shown on screen | AUDIO and TEXT search sources |
| Upload from PhotosPicker or a camera workflow | Streamed, signed uploads with live progress |
| A cancel button that really cancels | Per-operation cancellation tokens |
| Collection and indexing screens | Typed collection, index, usage, and image resources |
| Login and account switching your way | App-owned runtime credentials—no login UI imposed |

## Getting started with one prompt

Copy this prompt into your coding agent:

```text
1. Clone https://github.com/v-modal/vmodal_sdk_swift_iphoneduo.git and enter
   the vmodal_sdk_swift_iphoneduo directory.
2. Inspect the repository instructions and example/StarterIOS/README.md before
   making changes.
3. Use the repository's selected Xcode and Swift toolchain; do not install or
   switch Xcode. Run:
     bash install.sh check
     bash build.sh analyze
     bash test.sh test
4. Start or select an available iPhone simulator. List devices with:
     bash install.sh device_list
   Get the first available iPhone simulator identifier with:
     bash install.sh device_id
5. Run example/StarterIOS on the selected simulator with:
     bash run.sh example --device DEVICE_ID

Keep working until the app builds, installs, and opens. Fix any repository
setup issue you can safely resolve. Do not hard-code credentials or persist an
API key. When the app opens, explain how to enter a runtime VModal API key and
complete the authentication, collection, upload, index, and search flow. If a
required Xcode installation, simulator, or API key is unavailable, stop at that
boundary and report the exact blocker and the next command I should run.
```

### How to get an API key

Request an [API key from VModal](https://v-modal.com/page/contact.ts).

## Start in minutes

[SDK reference: `Sources/VModalSDK/VModalSDK.docc`](Sources/VModalSDK/VModalSDK.docc/GettingStarted.md)

Add the package in Xcode with **File → Add Package Dependencies…**, using:

```text
https://github.com/v-modal/vmodal_sdk_swift_iphoneduo
```

Attach the `VModalSDK` product to your application target. Then create one
project from the API key already loaded by your authenticated app and retain
immutable scopes wherever your app performs content operations:

```swift
import VModalSDK

let keys = try MutableAPIKeyProvider("runtime-api-key")
let project = try VModal.configure(
    projectID: "food_app",
    apiKeyProvider: keys
)
let favorites = try project.scope(
    collectionName: "user_123",
    streamName: "favorites"
)
```

`projectID`, `collectionName`, and `streamName` accept only letters, digits,
and underscore. Each is trimmed and limited to 80 characters. Project and
collection names cannot contain the reserved `__` separator, and their encoded
backend value is also limited to 80 characters. The SDK performs that encoding
internally.

> The SDK never owns your login screen or persists your API key. Authentication identity is separate from project, collection, and stream organization.

## Search video with natural language

```swift
let collections = try await project.listCollections(mode: "vid_file")
guard collections.contains("user_123") else {
    throw ValidationError("No video collection exists for this API key")
}

let results = try await favorites.search(
    "the cyclist crossing the bridge at sunset",
    options: ScopedSearchOptions(
        searchSources: ["image"],
        limit: 20
    )
)

print("\(results.cntActual) moments found")
for moment in results.data {
    print(moment)
}
```

Collection access is key-scoped. A logical name copied from another account or
environment can return HTTP 404 even when the search route is healthy. Use
`ScopedSearchOptions(versionLancedb: version)` when your application tracks a
specific index version.

The response stays typed where the contract is stable and preserves raw JSON so
new server fields remain available immediately.

## Upload with progress and cancellation

The SDK reads an app-accessible file URL as a stream. It does not load the
entire video into memory.

```swift
let source = try UploadSource(fileURL: movieURL)
let upload = favorites.upload(source)

let progress = Task {
    for await value in upload.progress {
        print("Uploading \(value.percent)%")
    }
}

// Connect this to your SwiftUI cancel button when needed:
// upload.cancel()

let uploaded = try await upload.result
progress.cancel()
print("Ready: \(uploaded.filename)")
```

For CCTV footage, provide the public filename and offset-aware recording
origin in `VideoUploadOptions`. The backend—not the SDK—normalizes the datetime
and returns canonical UTC epoch milliseconds. Metadata tags are repeated
independently on the wire.

```swift
let task = favorites.upload(
    try UploadSource(fileURL: cameraClipURL),
    options: ScopedUploadOptions(
        uploadOptions: VideoUploadOptions(
            videoFilename: "entrance-camera.mp4",
            metadataText: "north entrance delivery lane",
            metadataTags: ["entrance", "delivery", "camera-3"],
            startDatetimeUser: "2026-07-30T09:15:00+09:00"
        )
    )
)
let uploaded = try await task.result
print(uploaded.startTsUnixUserMs) // canonical backend value
```

Search the same footage using a metadata string and an absolute range. Start
is inclusive and end is exclusive. Datetime values must include `Z` or an
explicit UTC offset; the SDK preserves the caller text without timezone
conversion.

```swift
let moments = try await favorites.search(
    "vehicle",
    options: ScopedSearchOptions(
        queryMetadataText: "delivery",
        startDate: "2026-07-30T09:15:00.000+09:00",
        endDate: "2026-07-30T09:16:00.000+09:00",
        searchSources: ["image"]
    )
)
```

Signed single upload is the production default for every supported file size.
Multipart upload is experimental and must be enabled explicitly with
`VideoUploadOptions(multipart: true)`; it fails with `FeatureDisabledError`
when the complete backend route family is unavailable.

Uploads use exact file ranges, awaited socket streaming, coalesced progress,
and one network-concurrency budget per bulk task. See the
[API reference](Sources/VModalSDK/VModalSDK.docc/APIReference.md) for upload
limits, timeout behavior, and the performance benchmark command.

## Designed for real Apple lifecycles

- Rotate credentials without rebuilding the client: `try await keys.rotate(newAPIKey)`.
- Cancel search or upload work when a view, scene, or session closes.
- Observe upload progress with `AsyncStream` and update SwiftUI state on the main actor.
- Keep photo picking, Keychain storage, background scheduling, and lifecycle UI in the parent app.
- Close network resources deterministically with `await project.close()`.

For logout or account switching, cancel active work, clear upload persistence,
call `await keys.clear()`, close the project, and create a new project and
scopes for the next identity. Key rotation alone is not an identity, project,
collection, or stream switch.

## Common organization flows

```text
global index       project=video_search  collection=global           stream=uploads
per-user index     project=food_app      collection=user_123         stream=personal_videos
multiple streams   project=food_app      collection=user_123         stream=camera/favorites
catalog            project=shopping_app  collection=product_catalog  stream=merchant_uploads
```

Create a separate `VModalProject` for each developer project. On account
switch, create fresh project/client state; an already running task retains the
immutable scope with which it started.

## Developer use cases from the Apple examples

The included Apple examples are practical product and data-flow references.
Choose the example that matches the feature you are building, then apply the
same SDK contract in your SwiftUI state and lifecycle ownership.

| Developer goal | Apple reference | What to carry into your app |
|---|---|---|
| Learn or troubleshoot the SDK | [StarterIOS](example/StarterIOS) | Start with configuration, collection discovery, uploads, indexing, and search in one small app. |
| Build an upload-and-search screen | [StarterIOS app session](example/StarterIOS/StarterIOS/AppSession.swift) | Keep one scene-owned session, stream upload progress, and cancel operation tasks explicitly. |
| Validate an integration stage by stage | [SDK simulation tool](Tools/SDKSimulation) | Keep authentication, collection discovery, upload, indexing, search, and image rendering as visible stages. |
| Prepare an adaptive Apple interface | [iPhone Duo guide](docs/iphone_duo.md) | Keep SDK and upload ownership independent of window geometry, scene changes, and split layouts. |

When translating these flows:

- Keep one immutable state model for loading, progress, empty, success, error, and cleanup states.
- Convert a selected photo or movie into an app-readable local URL, then create `UploadSource(fileURL:)`.
- Replace callback-style networking with `UploadTask.progress`, `UploadTask.result`, and `upload.cancel()`.
- Preserve collection and stream coupling across upload, index creation, search, and bulk image lookup. Never display a job or result after the user has switched scope or identity.
- Load presigned result images without adding the VModal bearer credential. Refresh expired URLs by repeating the image lookup.
- Treat background transfer and processing as application-owned and platform-specific; the SDK does not schedule background work for your app.

## Advanced low-level resources

`VModalClient` remains supported for auth, usage, image lookup, and advanced
wire-level integration. To combine it with scopes, construct the client first
and transfer lifecycle ownership to the project:

```swift
let client = try await VModalClient.fromEnvironment(
    ProcessInfo.processInfo.environment
)
let project = try VModal.fromClient(
    projectID: "food_app",
    client: client
)

let profile = try await client.auth.me()
let scope = try project.scope(
    collectionName: "user_123",
    streamName: "favorites"
)

await project.close() // closes the transferred client
```

Gateway mode is the default and sends caller identity only as a bearer
credential. `VModalClient.unsafeDirect` is reserved for trusted private
networks.

## Platform support

| Platform | Status | Notes |
|---|---:|---|
| iOS | ✅ Supported | Native Swift and SwiftUI integration |
| macOS | ✅ Supported | Native Swift package support |
| watchOS, tvOS, visionOS | ⛔ Not supported | Not part of the current release contract |
| Android, Flutter Web, Windows, Linux | ⛔ Not supported | Use the matching VModal SDK for that platform |

Minimum toolchain: Swift `6.0`, Xcode `26.6`, iOS `16.0`, and macOS `13.0`.

## Explore the SDK

- [VModal home](https://www.v-modal.com)
- [VModal for developers](https://www.v-modal.com/developers)
- [VModal AI](https://www.v-modal.ai)
- [Read the Swift getting-started guide](Sources/VModalSDK/VModalSDK.docc/GettingStarted.md)
- [Review complete operation parity](Sources/VModalSDK/VModalSDK.docc/APIReference.md)
- [Run the StarterIOS app](example/StarterIOS)
- [Review the iPhone Duo and adaptive-layout guide](docs/iphone_duo.md)
- [Review the API compatibility specification](00_specs.md)
- [Open an issue](https://github.com/v-modal/vmodal_sdk_swift_iphoneduo/issues)

## Development

```bash
git clone https://github.com/v-modal/vmodal_sdk_swift_iphoneduo.git
cd vmodal_sdk_swift_iphoneduo
bash install.sh check
bash build.sh analyze
bash test.sh test
```

The offline gate resolves the package, analyzes Swift concurrency, runs SDK
tests, checks route synchronization, and validates the StarterIOS simulator
build. Live tests require the repository's existing test credentials and are
intentionally separate:

```bash
bash test.sh live
bash test.sh cctv_live
```

## Apple SDK goals

VModalSDK is an open-source Swift package that abstracts multimodal video
infrastructure into focused, developer-friendly operations. It lets Apple app
teams build semantic media experiences without managing vector databases or ML
pipelines locally. The SDK sends typed requests to VModal services and returns
structured, raw-JSON-preserving responses suitable for production UI.

## Understand core features

- **Multimodal search:** Query media with natural-language text, metadata, and image-aware sources.
- **Video analytics:** Index uploaded footage and return contextual timestamps for matching moments.
- **Image recognition:** Search visual objects, text, and scene relationships through the VModal backend.
- **Scoped organization:** Keep project, collection, and stream identity explicit across every operation.
- **Runtime authorization:** Supply and rotate bearer credentials in your app without SDK-owned login UI.
- **Swift concurrency:** Use `async`/`await`, `AsyncStream`, cancellation tokens, and typed failures.

## Evaluate technical architecture

- **Swift native:** Built with Foundation and Swift concurrency for iOS and macOS applications.
- **Small footprint:** Keeps ML and vector-index work in VModal services rather than bundling local models.
- **Streaming transport:** Streams file bytes and progress instead of loading complete video files in memory.
- **Reliable operations:** Provides typed failures, bounded retries, cancellation, and idempotent resource closing.

## Review use cases

- **Camera and field apps:** Upload and find specific moments from captured footage.
- **Security surveillance:** Search recorded video for events using natural-language descriptions.
- **Digital asset management:** Organize and retrieve large collections of business media.
- **Editorial tools:** Find scenes or actions inside long-form footage and B-roll.

## Learn more about VModal

Explore the full platform and developer resources:

- [VModal](https://www.v-modal.com) — the official home of VModal multimodal video and image search.
- [VModal for Developers](https://www.v-modal.com/developers) — API docs, SDKs, and integration guides for building on VModal.
- [VModal AI](https://www.v-modal.ai) — learn how VModal AI powers semantic search across video, speech, text, and imagery.

## License

VModalSDK is available under the [MIT License](LICENSE).
