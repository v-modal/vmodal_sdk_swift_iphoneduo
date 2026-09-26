<p align="center">
  <img src="Framebase/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="148" alt="Framebase app icon">
</p>

<h1 align="center">Framebase</h1>

<p align="center">
  <strong>Find the exact moment. Play the original footage.</strong><br>
  A complete, native SwiftUI reference app powered by VModalSDK.
</p>

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white">
  <img alt="iOS 16 or newer" src="https://img.shields.io/badge/iOS-16%2B-111111?logo=apple">
  <img alt="SwiftUI" src="https://img.shields.io/badge/UI-SwiftUI-0A84FF">
  <img alt="License MIT" src="https://img.shields.io/badge/code-MIT-2E7D6E">
</p>

Framebase is a product-style SwiftUI example for finding moments inside a
small video library with natural-language visual search. It demonstrates the
complete native Apple flow: runtime authentication, streamed uploads,
asynchronous indexing, grouped frame results, and playback of the local source
video at the returned timestamp.

The bundled library contains three short city-street recordings. Try searches
such as `A bus on a city street`, `People crossing the street`, or
`Cars at an intersection`.

> Framebase is deliberately more than a hello-world screen. It is a compact
> production reference for the complete video-search lifecycle, including the
> awkward parts: progress, cancellation, account changes, index polling,
> defensive result mapping, persistence, and local timestamp playback.

## Bundled library

| Neighborhood crossing | Downtown traffic | Evening junction |
| --- | --- | --- |
| ![A street crossing in San Francisco](Framebase/Assets.xcassets/neighborhood_crossing.imageset/neighborhood_crossing.jpg) | ![Downtown traffic in Singapore](Framebase/Assets.xcassets/downtown_traffic.imageset/downtown_traffic.jpg) | ![An evening junction in Mexico City](Framebase/Assets.xcassets/evening_junction.imageset/evening_junction.jpg) |
| San Francisco · 00:55 | Singapore · 00:15 | Mexico City · 01:15 |

The SwiftUI interface follows the same library → grouped results → local
playback flow as the Flutter Framebase example, while using native iPhone and
iPad navigation, file import, and video playback.

## Quick start

Framebase requires iOS 16 or newer, Swift 6, Xcode 26.6 or newer, and the local
`VModalSDK` package. From the Swift SDK repository root, verify the selected
toolchain and build the app:

```bash
bash install.sh check
bash build.sh framebase_ios
```

Then select an available iPhone simulator and run Framebase:

```bash
device="$(bash install.sh device_id)"
bash run.sh framebase --device "$device"
```

Open **Search settings** from the library menu, enter a valid VModal API key,
and connect. The key is held in memory only. It is not stored, logged, bundled
as an asset, or compiled into the application. Replacing or disconnecting the
key closes the previous SDK client and clears its in-memory provider.

Framebase uses the application-owned collection `framebase_streets` and stream
`street_study` inside the authenticated account. If that collection has no
ready image index, choose **Prepare videos for search**. The app copies its
bundled assets into app-private storage, uploads them sequentially with
progress, creates an image index, polls the job until it is ready, and then
enables search.

Uploading and indexing use the authenticated account and may consume service
quota. The app never deletes remote data. Imported MP4 files must be smaller
than 100 MB and are copied into Application Support while security-scoped file
access is valid.

## How it works

```mermaid
flowchart LR
    A[Bundled or imported MP4] --> B[Streamed upload]
    B --> C[Image index]
    C --> D[Natural-language search]
    D --> E[Grouped frame matches]
    E --> F[Local AVPlayer playback]
```

Remote services identify the moment; playback stays local. Search results are
joined back to validated source clips, grouped by recording, and opened with
`AVPlayer` at a bounded timestamp. No remote media URL is used as a playback
fallback.

## What the code demonstrates

- `MutableAPIKeyProvider` and `auth.me()` for runtime authentication.
- `UploadSource`, streamed upload progress, and cancellation.
- Image-index creation, status polling, and recovery of a pending job after
  relaunch.
- Collection-version discovery before search.
- Natural-language video search with an explicit distance cutoff.
- One bulk URL lookup followed by validated `input_index` correlation and
  cancellable image retrieval.
- Defensive mapping of filenames, result indexes, and relative timestamps.
- Grouping nearby matches from the same source video.
- Opening an app-private local video at the timestamp returned by search.
- Stale-search cancellation and deterministic SDK-client cleanup.

## Project tour

| Area | Start here |
| --- | --- |
| App lifecycle and dependency ownership | [`FramebaseApp.swift`](Framebase/FramebaseApp.swift) |
| Library, import, and preparation flow | [`LibraryView.swift`](Framebase/LibraryView.swift) |
| SDK authentication, upload, index, and search calls | [`FramebaseGateway.swift`](Framebase/FramebaseGateway.swift) |
| Async state machine and cancellation | [`FramebaseSession.swift`](Framebase/FramebaseSession.swift) |
| Grouped result experience | [`SearchView.swift`](Framebase/SearchView.swift) |
| Local playback and moment seeking | [`PlaybackView.swift`](Framebase/PlaybackView.swift) |
| Bounded, account-aware persistence | [`ArchiveStore.swift`](Framebase/ArchiveStore.swift) |

## Assets included

The repository contains everything required to build and experience the sample;
there are no placeholder downloads or runtime asset fetches.

| Asset | Included |
| --- | --- |
| Search library | 3 MP4 recordings in `Framebase/Resources/Videos` |
| Library artwork | 3 matching JPEG image sets in `Assets.xcassets` |
| Typography | Instrument Sans plus its OFL license |
| App identity | Complete RGB app-icon catalog for iPhone, iPad, and App Store |
| Attribution | Exact footage sources and transformations in [`MEDIA_SOURCES.md`](MEDIA_SOURCES.md) |

The videos, stills, font, and font license are byte-for-byte counterparts of the
reviewed Flutter Framebase assets. The native app icon uses the same rust,
peach, ivory, and ink palette as the SwiftUI interface.

The cutoff is an application policy, not a confidence percentage. A broad
nearest-neighbour search can return the closest available street frame even
when the requested subject is absent. Framebase therefore offers a focused
mode that omits weaker matches and an optional looser mode.

Application state such as local clip references, upload flags, a pending index
job, the authenticated account identifier, and at most 40 history events is
stored under Application Support. Credentials, search responses, temporary
image locators, image bytes, SDK objects, cancellation handles, and player
state are not persisted. Account-bound upload and indexing state is reset when
the authenticated user changes.

## Validation

From the Swift SDK repository root:

```bash
bash build.sh format
bash test.sh test
bash test.sh framebase_ios
```

Framebase has credential-free unit and UI tests for archive persistence,
account changes, result mapping, timestamp handling, cancellation, cutoff
enforcement, playback state, and library/search/history navigation. Live
upload, indexing, search, file import, and playback still require an API key
and a physical device or simulator.

## Troubleshooting

- **The app opens but search is unavailable:** open **Search settings**, provide
  a valid API key, and connect before preparing the library.
- **Preparation is still running:** keep the app open while uploads complete.
  A pending index job is restored after relaunch; **Stop waiting** does not
  delete remote work.
- **An imported video is rejected:** use a playable local MP4 smaller than
  100 MB. Framebase validates and copies it before upload.
- **Xcode cannot resolve `VModalSDK`:** keep this example inside the Swift SDK
  repository. The Xcode project intentionally uses the local package at `../..`.

## Footage and license

The bundled clips are exact copies of the Flutter example's edited Pexels
stock footage, with audio removed. Exact source links and transformations are
recorded in [`MEDIA_SOURCES.md`](MEDIA_SOURCES.md). The example source is
available under the [MIT License](../../LICENSE); the bundled footage remains
subject to the [Pexels license](https://www.pexels.com/license/).
