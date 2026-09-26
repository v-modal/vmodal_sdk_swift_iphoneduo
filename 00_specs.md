# VModal Apple Swift SDK reproduction specification

Status: implementation specification  
Target package: `uinterface/sdk_swift_apple/`  
Behavioral reference: `uinterface/sdk_flutter/` version `1.2.2`  
Primary guide reviewed: `uinterface/sdk_flutter/docs/sdk_doc.md`

## 1. Goal

Build a native Swift package that reproduces the public behavior, wire contract,
validation, cancellation, bounded-memory transport, signed upload, multipart
resume, and scoped organization model of `sdk_flutter` for Apple applications.

The result must be usable directly from Swift and SwiftUI without embedding
Flutter or Dart. Swift naming may follow Apple conventions, but JSON keys,
HTTP methods, paths, field omission rules, default values, ordering guarantees,
retry behavior, and error meaning must remain compatible with the Flutter SDK.

> Current compatibility override: the active release target is Xcode 26.6 with
> its iOS 26.5 SDK. Xcode 27.1/iPhone Duo implementation and gates are retained
> as commented future code until that toolchain is available in CI.

<!-- FUTURE_IPHONE_DUO_XCODE_27_1
The first production target is iPhone. The package must build with the iOS 27.1
SDK and work correctly on iPhone Duo, including while the app changes display,
size class, pose, scene, or Split View allocation. The networking package itself
must remain UI-independent.
-->

## 2. Required interpretation of parity

“Reproduce the Flutter SDK” means behavioral and data-contract parity, not a
line-by-line Dart-to-Swift translation.

- A Swift request created from equivalent inputs must use the same method,
  route, query items, form fields, repeated fields, JSON keys, and default
  values as Flutter.
- A Swift response must retain the complete decoded JSON object and expose the
  same typed convenience fields.
- Validation must happen before transport when it happens before transport in
  Flutter.
- Ordering guarantees must match for collection listing, batch search, bulk
  upload, multipart completion, metadata tags, and repeated query/form values.
- Cancellation, retries, limits, upload integrity, checkpoint compatibility,
  credential isolation, and close ownership are part of the contract.
- Disabled Flutter methods must exist as compatibility methods and fail locally;
  they must not silently call stale or undocumented endpoints.

### Critical part

1. **Exact wire parity.** Preserve snake_case wire names and distinguish an
   omitted value from an explicit empty string. In particular,
   `metadata_text: ""` is meaningful, metadata tags are ordered repeated
   values, and `re_process` is always sent during signed-upload finalization.
2. **Identity isolation.** Gateway mode sends only
   `Authorization: Bearer <current key>` as caller identity. It must never send
   `X-User-Id`, `X-Tenant-Id`, `X-User-Email`, `X-Userid`, or nested user IDs.
3. **Scoped organization.** Public project and collection names encode to one
   backend collection as `projectId + "__" + collectionName`; `streamName` maps
   directly to the backend stream. Authentication identity must never be
   inferred from any of these names.
4. **Streaming and bounded memory.** Upload bytes and multipart ranges must be
   streamed. Response bodies must enforce the limits before or while reading:
   JSON/text 8 MiB, errors 1 MiB, binary 64 MiB, checkpoints 1 MiB.
5. **Mutation safety.** Only `GET` and `HEAD` retry automatically. A timed-out
   or ambiguous `POST`/`DELETE`/upload is sent once and must be reconciled by
   the feature-specific protocol before an explicit retry.
6. **Multipart correctness.** Resume keys include the full upload contract;
   stale checkpoints are rejected; remote part size and MD5/ETag are reconciled;
   final parts are complete, unique, and ordered before completion.
7. **Concurrency correctness.** Swift 6 strict-concurrency checking must pass.
   Shared credential state, close state, task state, checkpoint state, and work
   schedulers must be actor- or lock-isolated. No data race may be hidden with
   casual `@unchecked Sendable` conformance.
8. **iPhone Duo resilience.** A display or scene transition must not recreate
   the client, lose upload progress, change a request scope, or cancel work
   unless the owning task explicitly cancels it.

### Critical coupling

The implementation is coupled to the following sources, in this precedence
order:

1. Backend route authorities:
   `../vmx_avideo/infra/search_api_ui/routers/apionly_routes.py` and
   `../vmx_avideo/infra/search_api_ui/routers/apionly_serve_img.py`.
2. Cross-SDK wire authority: `uinterface/sdk_python`.
3. Mobile behavior and public parity authority: the current checked-in
   `uinterface/sdk_flutter/lib/`, especially `routes.dart`, `routes.g.dart`,
   `models.dart`, `resources.dart`, `http.dart`, `transport.dart`, `upload.dart`,
   `collection_uploads.dart`, `content_scope.dart`, and `vmodal.dart`.
4. Reviewed normalized route mirror:
   `uinterface/sdk_flutter/test/fixtures/routes_contract.json`.
5. Flutter regression behavior: `uinterface/sdk_flutter/test/*.dart`.

When these disagree, do not guess. First compare the backend route authorities
and Python SDK, then update the Flutter mirror if it is stale, and only then
port the reviewed contract to Swift. A Swift-only route or payload divergence is
not acceptable.

The following couplings require explicit regression tests:

- route name/category/method/path/source to the normalized route fixture;
- gateway base normalization and users-API base stripping;
- `projectId__collectionName` encoding and decoding;
- server snake_case to Swift camelCase model mapping;
- CCTV fields across direct upload, signed single upload, multipart, resume,
  bulk upload, and transcode;
- multipart checkpoint protocol `vmodal_multipart_v2` and version `2`;
- adaptive upload vectors shared with the Android and Flutter SDKs;
- SDK version and public documentation examples.

## 3. Deliverable layout

Implement the package with this structure. Additional small internal files are
allowed when they keep responsibilities clear.

```text
sdk_swift_apple/
├── 00_specs.md
├── Package.swift
├── Package.resolved
├── .xcode-version
├── .swift-version
├── .swift-format
├── .gitignore
├── .gitleaks.toml
├── README.md
├── CHANGELOG.md
├── LICENSE
├── install.sh
├── build.sh
├── run.sh
├── test.sh
├── cli.sh
├── env.sh
├── security_check.sh
├── Sources/VModalSDK/
│   ├── VModal.swift
│   ├── VModalClient.swift
│   ├── SDKConfig.swift
│   ├── APIKeyProvider.swift
│   ├── ContentScope.swift
│   ├── Routes.swift
│   ├── Routes.generated.swift
│   ├── Transport.swift
│   ├── HTTPClient.swift
│   ├── Errors.swift
│   ├── JSONValue.swift
│   ├── Models.swift
│   ├── Resources/
│   │   ├── AuthResource.swift
│   │   ├── SearchesResource.swift
│   │   ├── CollectionsResource.swift
│   │   ├── IndexesResource.swift
│   │   ├── AdminResource.swift
│   │   ├── R2Resource.swift
│   │   ├── ImagesResource.swift
│   │   └── DisabledResources.swift
│   └── Upload/
│       ├── UploadSource.swift
│       ├── UploadTask.swift
│       ├── SignedUploadTransport.swift
│       ├── CollectionUploads.swift
│       ├── UploadSessionStore.swift
│       ├── AdaptiveUpload.swift
│       └── VideoTranscoder.swift
├── Tests/VModalSDKTests/
│   ├── Fixtures/routes_contract.json
│   ├── Fakes.swift
│   └── ... parity test files
├── example/StarterIOS/
├── Tools/
│   ├── RouteSync/
│   ├── ReleaseManifest/
│   ├── SDKSimulation/
│   ├── LiveTest/
│   ├── LiveCCTVTest/
│   └── PerformanceBenchmark/
├── release/public_publish.yml
└── docs/
```

`Package.swift` must expose one library product named `VModalSDK`. Prefer only
Apple frameworks (`Foundation`, `CryptoKit`, and where needed `OSLog`) and no
third-party runtime dependencies. The package should use Swift 6 language mode
with complete strict-concurrency diagnostics.

Recommended deployment floor is iOS 16.0 while building and testing against
the iOS 27.1 SDK. iOS 27/27.1-only UI APIs belong in the example app behind
availability checks; they must not raise the core SDK deployment floor.

## 4. Public Swift surface

### 4.1 Preferred scoped facade

Use Swift spellings while retaining a clear one-to-one map to Flutter:

```swift
public enum VModal {
    public static func configure(
        projectID: String,
        apiKeyProvider: any APIKeyProvider,
        baseURL: URL? = nil,
        timeout: Duration = .seconds(30),
        mode: SDKMode = .gateway,
        maxRetries: Int = 1
    ) throws -> VModalProject

    public static func fromClient(
        projectID: String,
        client: VModalClient
    ) throws -> VModalProject
}
```

Configuration and scope creation perform no network I/O and must not read the
credential. `fromClient` transfers close ownership to `VModalProject`.

`VModalProject` exposes:

- immutable normalized `projectID`;
- `scope(collectionName:streamName:) throws -> VModalScope`;
- `listCollections(mode:cancellation:) async throws -> [String]`;
- idempotent `close() async`.

`listCollections` preserves backend order, retains only the first duplicate,
returns only names with the exact `projectID + "__"` prefix, and throws a
malformed-response error when a collection under that prefix has an invalid
logical name.

`VModalScope` is immutable and `Sendable`. It exposes:

- `upload(_:options:) -> UploadTask<VideoUploadResponse>`;
- `uploadMetadata(_:options:cancellation:) async throws`;
- `search(_:options:cancellation:) async throws`;
- `addAssets(collectionID:assetIDs:options:cancellation:) async throws`;
- `updateAsset(filename:changes:cancellation:) async throws`;
- `createIndex(options:cancellation:) async throws`;
- `listIndexJobs(options:cancellation:) async throws`;
- `indexStatus(jobID:cancellation:) async throws`;
- `deleteIndex(version:options:cancellation:) async throws`;
- `deleteCollection(options:cancellation:) async throws`.

Port these immutable option values with the Flutter defaults:

| Swift type | Required defaults |
|---|---|
| `ScopedUploadOptions` | mode `vid_file`, modality `vid_raw`, TTL `12600`, default `VideoUploadOptions` |
| `ScopedMetadataOptions` | mode `img_file`, write mode `append`, overlap `false` |
| `ScopedSearchOptions` | mode `vid_file`, sources `ocr/asr/image`, combine `union`, offset `0`, limit `50`, text score `0.90`, image score `1.5` |
| `ScopedAddAssetsOptions` | mode `vid_file` |
| `ScopedAssetChanges` | mode `vid_file`; optional description and tags |
| `ScopedCreateIndexOptions` | mode `vid_file`, insert `append`, create index `true`, version `new_version`, reprocess/dry-run `false` |
| `ScopedIndexJobsOptions` | limit `200`; optional status and mode |
| `ScopedDeleteIndexOptions` | mode `vid_file`, dry-run/confirm `false` |
| `ScopedDeleteCollectionOptions` | mode `vid_file`, scope `all`, dry-run/confirm `false` |

None of the scoped option types may contain project, collection, stream, user,
tenant, or email override fields.

### 4.2 Advanced client

`VModalClient` remains public for compatibility and advanced operations. It
owns its control transport and signed-upload transport, exposes resources named
`auth`, `searches`, `collections`, `indexes`, `admin`, `r2`, `images`, `gdrive`,
and `sql`, and closes both transports exactly once.

Required conveniences:

- `health(cancellation:) async throws -> HealthResponse`;
- `authCheck(cancellation:) async throws -> Bool`;
- environment-map factory equivalent to Flutter `fromEnvironment`;
- clearly labeled `unsafeDirect(...)` factory;
- `close() async`.

The environment-map factory exists for parity, tests, CI, and command-line
clients. It reads the same keys and precedence as Flutter:

1. base: explicit, `VMODAL_BASE_URL`, `TEST_CLIENT_SERVER_API_URL`, environment
   default;
2. key: explicit, `VMODAL_API_KEY`, `VMODAL_API_TOKEN`,
   `TEST_CLIENT_CLERK_USER_API_TOKEN`, `TEST_CLIENT_USER_TOKEN`;
3. identity: `VMODAL_USER_ID`, `VMODAL_TENANT_ID`, `VMODAL_USER_EMAIL`;
4. timeout: `VMODAL_TIMEOUT`; retries: `VMODAL_MAX_RETRIES`;
5. `VMODAL_ENV` accepts only `dev` or `prd`.

When identity resolution is enabled and no user ID is configured, call
`auth.me`, require a nonblank `user_id`, create the resolved client, and
transfer transport ownership without prematurely closing the transferred
transports. Any bootstrap failure closes all owned transports.

## 5. Configuration and credentials

### 5.1 `SDKConfig`

Provide an immutable, `Sendable` configuration with:

- base URL;
- optional user ID, tenant ID, and email for unsafe direct mode;
- static token or an API-key provider;
- request timeout, response idle timeout, mode, and maximum retries.

Defaults match Flutter: 30-second request timeout, idle timeout equal to request
timeout, gateway mode, and one retry. Validate positive timeouts, nonnegative
retry count, mode, and URL before transport.

URL rules:

- trim trailing `/`;
- accept only HTTP(S);
- reject URL user information;
- require HTTPS except for `localhost`, `127.0.0.1`, `::1`, and the expanded
  IPv6 loopback;
- append `/api/v1/proxy/search_api` exactly once in gateway mode;
- derive users-API origin by removing that suffix;
- do not introduce a second independently configured users-API base URL.

`description`/debug output may report whether fields are configured, but must
never contain a token, credential-provider output, decoded private base value,
request body, response body, or filesystem path.

### 5.2 API-key provider

Define a `Sendable` provider read immediately before every request. An async
Swift protocol is acceptable and preferred for actor isolation:

```swift
public protocol APIKeyProvider: Sendable {
    func current() async throws -> String
}
```

Provide an actor-based `MutableAPIKeyProvider` with `rotate`, `clear`, and
permanent `close`. Rotation validates before replacing the old key. Clearing
fails closed until rotation. Closing permanently disables reads and rotation.

Key validation must trim outer whitespace, reject blank values, reject more
than 8192 characters, and reject ASCII control characters. Header values reject
control characters and values longer than 4096 characters.

Do not add Keychain persistence to the core provider. Applications own login,
refresh, and persistence. The SDK owns only safe in-memory consumption.

## 6. Content-scope contract

`projectID`, `collectionName`, and `streamName` are trimmed, required, at most
80 characters, and match `^[A-Za-z0-9_]+$`. Project and collection names must
not contain `__`. The encoded `projectID__collectionName` must also be at most
80 characters.

example:

```text
food_app + global + catalog     -> food_app__global / catalog
food_app + user_123 + favorites -> food_app__user_123 / favorites
```

Account switching creates fresh project/client state. API-key rotation alone
does not change identity or content scope. Simultaneously active scopes must
remain isolated even when their async operations overlap.

## 7. Routes and URL construction

Generate `Routes.generated.swift` from the reviewed route manifest. Do not hand
maintain separate copies in resources. The generated values may retain the
Flutter base64 anti-grep convention, but this is obfuscation only and must not
be described as encryption or credential protection.

Control API prefix: `/api/external/v1`  
Users API prefix: `/api/v1`

| Category | Method | Relative path | Swift operation |
|---|---:|---|---|
| active | GET | `/health` | `auth.health`, `authCheck` |
| active | POST | `/search` | `searches.searchVideo` |
| active | GET | `/collection/groups` | `collections.listGroups` |
| active | POST | `/collection/upload` | `collections.uploadFile` |
| active | POST | `/collection/upload/metadata` | `uploadMetadataJSONL` |
| active | POST | `/collection/description/update` | `updateDescription` |
| active | DELETE | `/collection/delete` | `collections.delete` |
| active | POST | `/collection/{collection_id}/assets/create` | `addAssets` |
| active | GET | `/indexation/jobs` | `indexes.jobsList` |
| active | POST | `/indexation/job/create` | `indexes.createIndex` |
| active | GET | `/indexation/job/{job_id}` | `indexes.indexStatus` |
| active | DELETE | `/indexation/index/delete` | `indexes.deleteIndex` |
| active | GET | `/admin/user-stats` | `admin.userStats` |
| image | POST | `/image/get_url` | `images.getURL` |
| image | POST | `/image/get_url_bulk` | `images.getURLBulk` |
| image | POST | `/image/get_image` | image byte/file methods |
| image | POST | `/image/get_image_bulk` | `getImageBulkFromURLs` |
| users API | GET | `/auth/me` | `auth.me` |
| users API | GET | `/admin/usage` | `admin.usage` |
| users API | GET | `/admin/cache/stats` | `admin.cacheStats` |
| users API | GET | `/get_r2_credentials/` | route retained for parity |
| users API | GET | `/upload_file/` | `r2.presignUploadFile` |
| users API | POST | `/upload_folder_video/` | `r2.presignUploadFolderVideo` |
| signed | POST | `/collections/external_upload_get_signed_url` | presign |
| signed | POST | `/collection/upload/done` | finalize |
| multipart | POST | `/collections/external_upload_multipart/create` | create |
| multipart | POST | `/collections/external_upload_multipart/sign_parts` | sign parts |
| multipart | GET | `/collections/external_upload_multipart/status` | reconcile |
| multipart | POST | `/collections/external_upload_multipart/complete` | complete |
| multipart | POST | `/collections/external_upload_multipart/abort` | abort |
| fallback | POST | `/api/internal/v1/collection/upload/metadata` | metadata 404 fallback |

Retain disabled/deprecated manifest entries and local-failure methods for
Google Drive upload, folder upload, embedding models, auto-index get/set,
collection create/edit, private GDrive methods, and SQL query. The deprecated
Google Drive collection route is not a supported public operation.

Path placeholders must use path-segment escaping. Query construction must use
an ordered list of `URLQueryItem`, not a dictionary, because repeated values
such as `metadata_tags` must remain repeated and ordered. An absolute API URL
is allowed only when scheme, case-insensitive host, and effective port exactly
match the configured origin. Redirect following is disabled.

## 8. Transport contract

### 8.1 Request and response abstractions

Create public transport-neutral values equivalent to Flutter:

- `VModalRequest`: method, URL, headers, optional JSON body, form fields,
  replayable file parts, response mode, and cancellation;
- `VModalResponse`: status, headers, declared length, and async byte stream;
- `VModalTransport`: async send and idempotent close;
- `URLSessionVModalTransport`: default implementation;
- `VModalFilePart`: field name, filename, exact length, MIME type, and a fresh
  stream opener.

Multipart field name max is 128, filename max 1024, content type max 255, and
control characters are invalid. File parts must reject nonexistent files.
Known MIME mappings are JSON/JSONL, text, JPEG, PNG, and MP4; otherwise use
`application/octet-stream`.

Use `URLSession` delegates or `URLSession.AsyncBytes` so limits and
cancellation apply during consumption rather than after an unbounded `Data`
allocation. Inject a session/transport for deterministic tests.

### 8.2 Response rules

- Successful status is 200 through 299.
- Empty successful JSON body becomes an empty object.
- Nonempty JSON must decode to exactly one top-level object with string keys.
- A malformed length below `-1`, malformed JSON, multiple JSON values, array
  top level, or non-string object key maps to malformed response.
- Reject a declared over-limit body before reading its stream.
- Reject chunk overflow immediately while reading and cancel that attempt.
- Reset the idle timeout after each body event; timeout cancels the attempt.
- Per-call binary caps may lower but never raise the 64 MiB SDK ceiling.

### 8.3 Retry rules

Only `GET` and `HEAD` can retry. Retry recognized transport/cancellation failures
that belong to the attempt, and statuses 500, 502, 503, and 504, up to
`maxRetries`. Use a fresh child cancellation state for each attempt and delays
of `50 ms * (attempt number)`. Caller cancellation always wins and must surface
as operation canceled. `POST` and `DELETE` never auto-retry.

### 8.4 Error mapping and redaction

Expose a typed Swift error family carrying message, status code, optional body,
and details. It must distinguish authentication, API, validation,
feature-disabled, transport, response-too-large, malformed-response, and
operation-canceled errors.

- 401 -> authentication error with message `authentication failed`;
- 422 -> validation error with message `validation failed` and structured
  `detail` when present;
- other non-2xx -> API error with message `api request failed`.

Read at most 1 MiB of an error body. Preserve a safely decoded structured body,
but recursively replace Unix paths, Windows drive paths, UNC paths, and `file:`
URLs with `****`. Error descriptions must not print response bodies.

## 9. JSON and response models

Implement a `JSONValue: Codable, Sendable, Equatable` enum and use
`[String: JSONValue]` as each response's `raw` object. Do not expose shared
mutable `[String: Any]` state.

Port all Flutter request models and their exact snake_case encoders:

- `SearchRequest`;
- `DeleteCollectionRequest`;
- `CollectionAddAssetsRequest`;
- `IndexationSubmitRequest`;
- `IndexationDeleteRequest`;
- `ImageRecord` and `ImageURLRecord`.

Port every response wrapper, including generic/raw wrappers:

- health, search, groups and group item;
- signed URL, multipart create/sign/status/complete and part records;
- direct upload, video upload, video bulk upload, folder/metadata/update/delete/
  add-assets results;
- index job list/submit/status/delete;
- admin user stats, user profile, usage, and cache stats;
- R2 presigned file/folder results;
- image URL, image URL bulk, image bytes/base64, and image bulk results.

Unknown fields remain in `raw`. Numeric coercion matches Flutter: integral
numbers or numeric strings become integers; finite numbers or numeric strings
become doubles; invalid, fractional-to-int, NaN, and infinite values fall back
to zero where Flutter does.

### 9.1 Search request

Defaults are `query_text = ""`, mode `vid_file`, group `agroup`, stream
`astream`, sources `ocr/asr/image`, combine mode `union`, offset `0`, limit
`50`, text threshold `0.90`, and image threshold `1.5`.

At least one of query text, image query, or metadata text must be nonblank.
Keep the deprecated structured metadata map temporarily, but reject combining
it with `queryMetadataText`. Both serialize under `query_metadata`.

For `vid_file`, `start_date` and `end_date` are a pair. Date-only
`YYYY-MM-DD` values are accepted. Datetimes must parse as ISO-8601 and end in
`Z` or an explicit `+/-HH:MM` offset. The SDK sends them unchanged. Start is
inclusive and end is exclusive by backend contract.

## 10. Resources

### 10.1 Auth and search

`AuthResource` implements health, authenticated health check, and users-API
profile lookup. `SearchesResource.searchVideo` validates then sends the exact
`SearchRequest` JSON.

`searchBatch` defaults to mini-batch size 10 and four workers. It must:

- validate all inputs before starting network work;
- return immediately with an empty array for empty input;
- process each worker's contiguous mini-batch serially;
- keep no more than `nWorker` searches in flight;
- preserve input order;
- stop scheduling after failure and report the failure with the lowest input
  index among observed failures;
- share caller cancellation without canceling unrelated requests.

### 10.2 Collections and indexes

Collections must implement group listing, direct multipart-form upload,
metadata JSONL upload with the same 404-only fallback, add assets, update item
description/tags, and deletion preview/confirmation. Direct upload accepts the
same additive CCTV fields as signed upload.

Index jobs list accepts optional status/mode/group and limit 1 through 1000
(default 200). Index status first uses the job route; only a 404 falls back to
listing up to 1000 jobs and matching `job_id`. Create and delete validate their
request objects before transport.

### 10.3 Admin, R2, and images

Admin user stats uses the control API; usage and cache stats use the users API.
R2 presign methods use the users API and preserve the Flutter defaults,
including `expires_in = 900`.

Image bulk gateway payloads must remove nested `userid` and `user_id`. Identity
overrides are emitted only in unsafe direct mode. Provide three single-image
download forms:

1. bounded `Data` return;
2. streaming to caller-owned output without closing it;
3. atomic file save using a unique sibling temp file, flush/close, and rename.

An unsuccessful atomic save removes its temp and leaves an existing destination
unchanged.

## 11. Upload subsystem

### 11.1 Upload source

`UploadSource` is immutable, reopenable, and has a known nonnegative length,
filename, content type, stable source ID, version tag, optional local file, and
exact range opener. File sources use absolute path as source ID and
`size:modification-time-ms` as version tag. Validate the file version before and
after a range read. Early EOF, mutation, truncation, or excess bytes is a
transport failure. Never buffer the full source merely to make it replayable.

### 11.2 Upload task and progress

`UploadTask<Result>` starts immediately and exposes:

- an async result;
- an `AsyncStream<UploadProgress>` suitable for multiple observers;
- running/succeeded/failed/canceled state;
- idempotent cancel.

Progress is monotonic. Coalesce events until either uploaded bytes advance by
at least 1% of total or 250 ms elapsed. Emit the first useful event and exactly
one terminal 100% event for nonempty uploads. Cancellation wins the terminal
race and completes the result as operation canceled.

### 11.3 Signed transport

The default signed transport streams PUT bytes with exact `Content-Length`,
phase timeout, task cancellation, local MD5, returned ETag, and no redirects.
Allow HTTPS signed URLs and loopback HTTP only.

Never attach the VModal bearer token or cookies to a presigned destination.
Allowed caller-supplied headers are only `Content-MD5`, `Content-Type`,
`Content-Length`, `x-amz-*`, and `x-goog-*`. Explicitly reject authorization,
cookie, origin, referer, and identity headers.

### 11.4 Video upload options

Match these defaults:

| Option | Default/constraint |
|---|---|
| multipart | `false`; size never enables it automatically |
| multipart threshold | 100 MiB informational compatibility value |
| part size | 64 MiB; minimum 5 MiB |
| max concurrency | 4; valid 1...16 |
| max part attempts | 5; valid 1...10 |
| part timeout | 300 seconds, positive |
| resume | `true` |
| checkpoint store | shared in-process memory store |
| transcoder | passthrough |
| reprocess | `false` |

The current Flutter contract rejects source files larger than 100 MiB before
upload, including explicit multipart. Keep this behavior until the shared
cross-SDK contract changes; do not interpret the multipart threshold as an
automatic mode switch.

### 11.5 Signed single upload

The state machine is:

```text
validate -> request presigned URL -> stream bytes -> validate success
         -> POST upload/done -> compose VideoUploadResponse
```

Presign sends source name, collection, stream, mode, modality, and TTL.
Finalization sends key plus the same organization and source fields, CCTV
fields, and `re_process`. A successful byte PUT is not a complete SDK operation
until finalization succeeds.

### 11.6 Bulk upload

Bulk results retain source order. Aggregate progress is monotonic. The first
failure cancels remaining work. All files and all multipart parts share one
signed-PUT concurrency budget; concurrency must not multiply at nested levels.
Multiple sources cannot share one explicit `video_filename`. Duplicate
multipart checkpoint contracts fail before work starts.

### 11.7 Experimental multipart upload

Multipart is explicit and experimental. A 404 from a multipart gateway maps to
feature disabled with guidance to retry using single upload; no silent strategy
change is permitted.

Checkpoint contract fields and order are:

```text
protocol = vmodal_multipart_v2
base_url
user_id
source_id
source_version
filename
content_type
size_bytes
part_size_bytes
mode
group_name
stream_name
modality
```

Compute the session key as SHA-256 of compact UTF-8 JSON with this exact field
order and Dart-compatible scalar encoding. Swift dictionaries are unordered,
so the hash input must be emitted by a dedicated ordered encoder. Checkpoint
JSON version is `2` and stores contract, request ID, upload ID, object key, part
count, part size, and a string-keyed `part_md5` map.

File checkpoints use SHA-256 of the session key as filename, enforce the 1 MiB
limit, and use temp -> backup -> primary atomic replacement with rollback.

Resume behavior:

1. Load and strictly validate checkpoint against the current contract.
2. If resume is disabled, abort the known remote session, remove local state,
   and create a new session.
3. Query status. A missing remote session removes the stale checkpoint and
   creates a new session.
4. Reject duplicate, invalid, or out-of-range remote part numbers.
5. Reconcile accepted parts by exact part length and case-insensitive
   ETag/local-MD5 equality.
6. Sign missing parts and upload within the shared permit pool.
7. On 403, reconcile first, then refresh only that part's URL when another
   attempt remains.
8. Retry signed failures, transport failures, and 408/429/500/502/503/504 with
   exponential delay `min(30 s, 250 ms << min(attempt-1, 6))`.
9. Fetch final status; require every part exactly once in numeric order with
   expected size and digest.
10. Complete multipart, require a nonblank ETag, finalize upload, remove the
    checkpoint, and emit terminal progress.

### 11.8 Adaptive policy

Port `AdaptiveUploadPolicy` values exactly. Tiers are `<100 MiB`, `<1 GiB`,
`<8 GiB`, and `>=8 GiB`; profiles are conservative, cellular, balanced, and
fast. The table values are `[part MiB, concurrency, attempts, timeout seconds]`:

| Tier | Conservative | Cellular | Balanced | Fast |
|---|---|---|---|---|
| small | 5,1,6,360 | 8,2,5,300 | 16,3,4,240 | 32,4,3,180 |
| medium | 8,1,6,480 | 16,2,5,360 | 32,3,4,300 | 64,4,3,240 |
| large | 16,1,7,720 | 32,2,6,600 | 64,3,5,480 | 128,4,4,360 |
| huge | 32,1,8,900 | 64,2,7,720 | 128,3,6,600 | 256,4,5,480 |

Raise part size when needed to stay at or below 10,000 parts. Adaptive settings
do nothing when multipart is false. Network and memory observations are inputs
provided by the application; the core SDK does not request monitoring or device
permissions.

## 12. CCTV and transcode contract

The fields `videoFilename`, `metadataText`, ordered `metadataTags`,
`startDatetimeUser`, and `reProcess` must survive option snapshots, adaptive
copies, signed single, multipart, resume, bulk, direct form upload, and
transcoding.

- Public filename and start timestamp require mode `vid_file`.
- Public filename is a nonblank bare filename with no `/` or `\`.
- When both source and public names have extensions, they must match
  case-insensitively.
- Timestamp is nonblank and ends in `Z` or explicit `+/-HH:MM`.
- Send timestamp text unchanged; never calculate `start_ts_unix_user_ms`.
- When timestamp exists without an explicit public name, derive the original
  source filename.
- A generated transcode filename never becomes the public CCTV filename.
- The backend response owns normalized datetime, epoch milliseconds, and
  `timestamp_source`.

Define an application-injected `VideoTranscoder` protocol and a default
passthrough implementation. A real transcoder requires a file-backed source.
Validate the original against the 100 MiB limit before transcoding, require a
nonempty produced file, upload the produced file, preserve original path/size in
the response, and delete only a distinct produced temp after complete success.
Do not delete the caller's original. Do not add FFmpeg or another transcoder as
a core package dependency.

## 13. iOS 27.1 and iPhone Duo requirements

Apple's iPhone Duo guidance requires apps to build with the latest SDK, adapt
using size classes, avoid main-screen assumptions, respect asymmetric safe
areas, and verify Split View and fold/display transitions. See
[Apple: Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/)
and the requested
[developer summary](https://dev.to/arshtechpro/iphone-duo-for-ios-developers-what-actually-changes-in-your-swift-code-5gc5).

### 13.1 Core package

The SDK is headless and must not import SwiftUI or UIKit in its core target.
Consequently it must not reference:

- `UIScreen.main`;
- device orientation for behavior;
- safe-area geometry;
- a singleton window or scene;
- one-display assumptions;
- view lifecycle callbacks as request ownership.

Long-running work belongs to explicit `Task`/`UploadTask` ownership. A pose,
window, scene phase, or size-class change must not restart an upload. The client
must be safe to share across multiple scenes. If an app-scoped project is shared,
individual scene destruction must not close it; ownership must be centralized
at the app/session layer.

The default signed transport is foreground. Define a transport protocol that
allows a future/app-provided background `URLSession` implementation, but do not
claim background survival unless identifier restoration, delegate callbacks,
file-based upload requirements, and checkpoint recovery are implemented and
tested.

### 13.2 Starter SwiftUI example

The example must:

- use size classes and available container geometry, never orientation checks;
- use standard `NavigationStack`, `NavigationSplitView`, `TabView`, `List`, and
  `ScrollView` where appropriate;
- keep interactive foreground content inside each actual safe-area edge while
  allowing background artwork to extend;
- never assume left/right or top/bottom safe-area symmetry;
- avoid `UIScreen.main`; obtain display scale from the environment/traits and
  a screen from the current `UIWindowScene` only when truly needed;
- keep upload/search view models alive through pose and layout transitions;
- show progress and cancellation without tying the upload lifetime to one
  transient view instance;
- conditionally adopt iOS 27.1 reserved-region or arrangement APIs only where
  standard containers do not already solve the layout;
- continue to run on the declared deployment floor using `if #available`.

Do not use hinge angle to calculate layout. Hinge APIs, if demonstrated, are for
interaction/effects only. Layout responds to size class, available geometry,
safe areas, and reserved regions.

### 13.3 Device acceptance matrix

Run the example in the Xcode 27.1 iPhone Duo simulator through:

1. closed portrait;
2. closed landscape;
3. open vertical;
4. open horizontal;
5. a partially folded transition with an upload in progress;
6. Split View at narrow and wide allocations;
7. scene background/foreground during search and upload;
8. two application scenes sharing the intended app-session client.

Verify no clipped controls, no content under a reserved interactive region, no
incorrect symmetric inset math, no lost progress, no duplicate upload, no
scope mutation, and no accidental client close.

## 14. Bash scripts and operational tooling

The Swift sub-repository must include all seven operational scripts present in
the Flutter SDK: `install.sh`, `build.sh`, `run.sh`, `test.sh`, `cli.sh`,
`env.sh`, and `security_check.sh`. They are part of the deliverable and public
release contract, not local conveniences.

### 14.1 Rules shared by every script

Every executable script must:

- start with `#!/usr/bin/env bash`;
- define a top-level multiline `help='...'` containing purpose and real,
  copy-pasteable examples;
- use `set -euo pipefail`, except that `env.sh` must apply strict mode only when
  executed and remain safe when sourced;
- resolve and operate from its own directory rather than the caller's current
  directory;
- prefix functions with the `sdk_` domain;
- give every function a local multiline `help` block with `## Usage:` and a
  real command example;
- expose a bottom-of-file dispatcher, `help`, `-h`, and `--help`;
- return a nonzero status for an unknown command;
- quote paths and values, work on both Apple Silicon and Intel macOS, and never
  print credentials;
- avoid interactive prompts in CI and provide deterministic exit codes;
- never run `git merge`, force-push, or bypass validation;
- pass `bash -n`, ShellCheck, and dispatcher regression tests.

The scripts must not create a Python virtual environment, Conda environment,
Poetry environment, or Pipenv environment. Swift build products stay under the
package `.build/` directory or an explicit temporary/DerivedData directory.

### 14.2 `install.sh`

Purpose: verify and locate the Apple toolchain; do not download or silently
switch Xcode.

Required commands:

```text
bash install.sh check
bash install.sh xcode_path
bash install.sh swift_bin
bash install.sh xcodebuild_bin
bash install.sh simctl_bin
bash install.sh device_list
bash install.sh help
```

Requirements:

- read the reviewed Xcode requirement from `.xcode-version` or the documented
  equivalent and require Xcode 27.1 or newer for the Duo test command;
- resolve tools using `xcrun --find` under the selected `DEVELOPER_DIR`;
- report actionable instructions when Xcode, its license, command-line tools,
  iOS 27.1 runtime, or iPhone Duo simulator is unavailable;
- print versions and paths but no environment secrets;
- allow a user-supplied `DEVELOPER_DIR` and never modify global
  `xcode-select` state;
- run `swift package resolve` during `check` only after toolchain validation;
- do not use Homebrew or curl to install Xcode automatically.

`device_list` must wrap `xcrun simctl list devices available` and be usable by
CI diagnostics when the simulator destination name changes.

### 14.3 `build.sh`

Purpose: format-check, resolve, compile, test, generate documentation, validate
the source package, and build the iOS example.

Required commands:

```text
bash build.sh resolve
bash build.sh format
bash build.sh analyze
bash build.sh test
bash build.sh docs
bash build.sh example_ios
bash build.sh duo_example
bash build.sh package
bash build.sh build
bash build.sh clean
bash build.sh help
```

Command behavior:

- `resolve`: call `install.sh check` and resolve `Package.swift` dependencies;
- `format`: run the Xcode-provided `swift-format` in lint mode over `Sources`,
  `Tests`, `Tools`, and Swift example sources;
- `analyze`: compile with Swift 6 complete strict concurrency, warnings as
  errors for package-owned sources, and no network/live calls;
- `test`: run package unit tests and the starter-app unit tests;
- `docs`: build DocC with warnings treated as errors and place generated docs
  under the documented output directory;
- `example_ios`: build the starter application for a generic iOS simulator
  without signing;
- `duo_example`: build specifically with the iOS 27.1 SDK and an available
  iPhone Duo simulator destination;
- `package`: export to a fresh `mktemp -d`, generate
  `SOURCE_MANIFEST.sha256`, and validate the exported package from that
  directory;
- `build`: execute resolve -> format -> analyze -> test -> docs -> package ->
  example iOS in a fixed order;
- `clean`: delete only verified package-owned `.build`, DocC output, and
  example DerivedData paths.

Before cleanup, verify `Package.swift`, the `VModalSDK` library product, and the
expected package directory. Never clean a repository root, home directory, an
unresolved environment path, or caller-provided arbitrary path.

### 14.4 `run.sh`

Purpose: run deterministic SDK simulation or launch the starter app on one
explicitly chosen simulator/device.

Required commands:

```text
bash run.sh sim
bash run.sh example --device DEVICE_UDID
bash run.sh duo
bash run.sh help
```

- `sim` runs the offline `SDKSimulation` executable target.
- `example` requires an explicit device UDID, builds/installs the starter app,
  and launches its bundle ID without choosing an arbitrary device.
- `duo` resolves an available iPhone Duo simulator, boots it when necessary,
  and launches the example. If zero or multiple candidates remain after
  filtering, fail with the available-device list and require `--device`.
- Never erase, reset, or delete a simulator from these commands.

### 14.5 `test.sh`

Purpose: provide stable offline, regression, security, packaging, simulator,
and explicit live gates.

Required commands:

```text
bash test.sh test
bash test.sh regression STEP
bash test.sh sim
bash test.sh duo
bash test.sh security
bash test.sh package
bash test.sh live
bash test.sh cctv_live
bash test.sh all
bash test.sh clean
bash test.sh help
```

Requirements:

- `test` runs toolchain checks, build analysis, package tests, and example unit
  tests entirely offline after dependency resolution;
- `regression STEP` accepts only documented stage identifiers and runs an
  ordered cumulative subset of parity suites;
- `sim` runs deterministic fake-transport simulation;
- `duo` runs the iPhone Duo build/UI acceptance suite;
- `security` delegates to `security_check.sh all`;
- `package` delegates to `build.sh package`;
- `live` sources `env.sh`, validates the credential, then runs the live
  collection -> index -> advertised LanceDB version -> search gate;
- `cctv_live` runs the opt-in timestamp, metadata, and absolute-time search
  gate;
- `all` has a fixed safe order and remains offline: test -> security -> package
  -> simulation -> Duo simulator. It must never include live gates;
- `clean` delegates only to the guarded build cleanup.

Live commands must require explicit invocation and must not echo API keys. A
failed live mutation must print enough nonsecret identifiers for state
reconciliation rather than blindly retrying it.

### 14.6 `cli.sh`

Purpose: central command wrapper for generated routes, DocC, and release
metadata.

Required commands:

```text
bash cli.sh routes_generate
bash cli.sh routes_check
bash cli.sh docs_generate
bash cli.sh docs_check
bash cli.sh docs_precommit
bash cli.sh release_check
bash cli.sh release_manifest [DIRECTORY]
bash cli.sh help
```

The script must source the repository `isetup_env.sh` when repository tooling
needs it and set `PYTHONPATH` to the repository root, while the Swift generation
logic itself remains in checked-in Swift executable targets rather than inline
Python or shell heredocs.

- route generation reads the reviewed normalized manifest and produces
  `Routes.generated.swift` deterministically;
- route check regenerates to a temporary file and requires byte equality;
- docs generation/check uses one deterministic DocC pipeline;
- the pre-commit command runs only when staged Swift SDK files are relevant,
  regenerates/checks outputs, and fails if generated changes are not staged;
- release checks verify version equality across package source, changelog, and
  release metadata;
- manifest generation hashes the exact staged public artifact.

### 14.7 `env.sh`

Purpose: derive live/release aliases from existing repository variables without
storing values.

Required functions and commands:

```text
source env.sh && sdk_env_live
source env.sh && sdk_env_release
bash env.sh live
bash env.sh release
bash env.sh help
```

`sdk_env_live` derives, without overwriting explicit values:

```text
VMODAL_API_KEY  <- TEST_CLIENT_CLERK_USER_API_TOKEN
VMODAL_BASE_URL <- TEST_CLIENT_SERVER_API_URL
VMODAL_USER_ID  <- TEST_CLIENT_USER_ID
VMODAL_ENV      <- prd when unset
```

`sdk_env_release` preserves an existing release token alias but stores no token.
The file must be safe and idempotent when sourced repeatedly. Its tests use
sentinel values and assert the sentinel never appears on stdout/stderr.

Any future Swift SDK environment variable must first be derived from an
existing variable when possible. A genuinely new variable must be documented
and centralized in this `env.sh`, not scattered through workflows.

### 14.8 `security_check.sh`

Purpose: enforce workflow, toolchain, version, license, route, package, secret,
and forbidden-command policy.

Required commands and fixed `all` order:

```text
bash security_check.sh workflow
bash security_check.sh toolchain
bash security_check.sh version
bash security_check.sh license
bash security_check.sh routes
bash security_check.sh package
bash security_check.sh secrets
bash security_check.sh forbidden
bash security_check.sh all
bash security_check.sh help
```

`all` runs workflow -> toolchain -> version -> license -> routes -> package ->
secrets -> forbidden.

- workflow checks require least-privilege permissions, full commit-SHA action
  pins, `persist-credentials: false`, tested-source causality, protected release
  environment, and a secret-detection gate;
- toolchain checks require the reviewed Xcode/Swift/iOS SDK versions and Duo
  runtime for Duo-specific CI;
- version checks require one SDK version across the public constant,
  `Package.swift`/release metadata, DocC, and changelog;
- license checks require the MIT license and matching package metadata;
- route checks reject plaintext private route/base literals in public library
  source, verify deterministic generation, and compare the route fixture;
- package checks reject `.env`, `ztmp`, `.build`, DerivedData, checkpoints,
  credentials, local Xcode user data, and generated transient files;
- secrets runs a version- and checksum-pinned detector with redacted output;
- forbidden rejects `git merge`, force pushes, validation bypass flags,
  credential logging, and unpinned workflow actions.

Public-source route hiding is only anti-grep obfuscation. Security tests must
not present it as authorization, encryption, or a replacement for server-side
access control.

### 14.9 Extra tools and release files

The scripts require checked-in, testable tools rather than large inline shell
implementations:

| Tool/file | Responsibility |
|---|---|
| `Tools/RouteSync` | parse authority/mirror, emit route table, list literals, check drift |
| `Tools/ReleaseManifest` | verify version, export allowlisted sources, hash manifest |
| `Tools/SDKSimulation` | deterministic offline end-to-end example |
| `Tools/LiveTest` | collection/index/version/search live gate |
| `Tools/LiveCCTVTest` | CCTV upload and absolute-time search live gate |
| `Tools/PerformanceBenchmark` | single/bulk throughput, memory, progress, and active PUT metrics |
| `release/public_publish.yml` | public Swift package/DocC publication workflow mirror |
| `.xcode-version` | reviewed Xcode requirement used by scripts and CI |
| `.swift-version` | reviewed Swift language/toolchain expectation |
| `.swift-format` | deterministic formatting policy |
| `.gitleaks.toml` | repository-specific secret scan configuration |

The release exporter uses an explicit allowlist. It includes the seven root
scripts and every public file referenced by README or DocC, excludes generated
and private material, writes a sorted SHA-256 source manifest, and validates the
export as an independent Swift package before publication.

Add repository workflow
`.github/workflows/sdk_swift_apple_test_release.yml`. Keep it thin: select mode
and sub-repository, then call the checked-in scripts. Do not duplicate script
logic or add many workflow-specific environment variables.

### 14.10 Shell acceptance tests

Add regression tests that enumerate all seven scripts and assert:

- each exists and is executable in the release artifact;
- `bash -n SCRIPT` succeeds;
- `bash SCRIPT help` succeeds and contains `Usage`;
- `bash SCRIPT not-a-command` fails;
- `env.sh` is source-safe, idempotent, preserves explicit values, and emits no
  secret sentinel;
- `all` command ordering is fixed and live commands are excluded;
- cleanup guards are present and tested with harmless temporary fixtures;
- local helpers cannot publish forcibly or skip validation;
- route/DocC pre-commit checks detect unstaged generated drift;
- README/DocC commands refer only to scripts included in public export;
- the release manifest contains all seven scripts and required extra tools.

## 15. Test specification

Use deterministic offline tests by default. Inject fake control and signed
transports; use a custom `URLProtocol` or equivalent byte-stream fake for
Foundation behavior. Live tests are a separate explicit suite.

Mirror the Flutter regression groups:

| Swift suite | Required coverage |
|---|---|
| `ConfigRoutesTests` | route fixture exactness, prefixes, origin checks, normalization, redaction |
| `AuthHTTPTests` | key rotation, clear/close fail-closed, gateway headers, 401/422, GET-only retries |
| `TransportTests` | chunked limits, strict object JSON, idle timeout, attempt-local cancellation |
| `ResourcesModelsTests` | every primary encoder, numeric coercion, all resource paths, image identity stripping |
| `ScopedAPITests` | local scope validation, zero-I/O configuration, all operations use one immutable mapping |
| `UploadTests` | exact ranges, EOF/mutation, progress gate, header allowlist, ordered bulk and shared permits |
| `MultipartUploadTests` | opt-in only, resume, reconciliation, digest/ETag, completion ordering, malformed checkpoints |
| `AdaptiveUploadTests` | every Flutter/Android vector and 10,000-part ceiling |
| `CCTVContractTests` | omission vs empty, repeated tags, date/timestamp validation, every upload path |
| `TranscodeUploadTests` | passthrough, temp cleanup, cached/reused output, stream-source rejection |
| `ErrorLeakTests` | endpoint/token/body/path redaction and safe descriptions |
| `DuoCompatibilityTests` | SwiftUI example build plus UI/device matrix on iPhone Duo simulator |

Mandatory assertions include:

- the copied `routes_contract.json` matches the generated Swift route table
  exactly by name, category, method, path, and source;
- all public mutations fail locally when invalid and make zero transport calls;
- gateway requests have bearer auth and no identity headers/fields;
- credential rotation is observed on the next request, not only client creation;
- POST/DELETE are sent once under transport and idle-timeout failures;
- bounded readers stop at the declared or observed limit;
- batch and bulk results preserve input order under mixed completion timing;
- canceling one operation does not poison another operation or a later GET
  retry;
- checkpoint hash and JSON fixtures match Dart output byte-for-byte;
- a fold/resize transition does not create a second upload request.

Required commands once implementation exists:

```bash
cd uinterface/sdk_swift_apple
swift test
xcodebuild test \
  -scheme VModalSDK-Package \
  -destination 'platform=iOS Simulator,name=iPhone Duo'
```

If Xcode's simulator destination spelling changes, resolve it with
`xcrun simctl list devices available` and record the exact CI destination; do
not weaken the iPhone Duo test requirement.

## 16. Documentation and release requirements

`README.md` must start with authentication, list collections, then list index
jobs, matching the progressive Flutter documentation order. It must also show
scoped upload/search, cancellation, key rotation, client close ownership, and
an iPhone Duo-safe SwiftUI integration.

Generate DocC for the public module. Public docs describe typed operations and
must not expose embedded host values, route obfuscation internals, private
implementation code, credentials, or local paths.

The release must include source, license, changelog, README, DocC catalog,
route fixture, and examples referenced by public documentation. Add a
secret-detection gate before any public publishing workflow. Pin the release to
a tested commit so publication cannot export sources different from those that
passed tests.

## 17. Implementation order

1. Package skeleton, JSON value, errors, configuration, key provider, and
   content scope.
2. Generated routes plus exact route-fixture regression test.
3. request/response abstractions, URLSession control transport, bounded readers,
   retry/cancellation, and redaction.
4. request/response models and all non-upload resources.
5. preferred scoped facade and lifecycle ownership.
6. upload source/task, signed single upload, progress, and bulk scheduling.
7. checkpoint stores and experimental multipart state machine.
8. adaptive policy, CCTV propagation, and injected transcode lifecycle.
9. All seven bash scripts, executable tools, shell regression tests, and source
   export validation.
10. DocC, README, starter app, iOS 27.1/iPhone Duo matrix, and release gates.

Each stage must add parity tests before the next stage. Do not defer route,
serializer, or lifecycle mismatches to a final integration pass.

## 18. Definition of done

The Swift reproduction is complete only when:

- every supported Flutter public operation has a documented Swift equivalent;
- disabled/deprecated behavior is intentionally represented;
- routes and serializers pass golden parity tests;
- all default offline Swift tests pass under strict concurrency;
- live tests pass against the same API contract used by Flutter;
- uploads are streamed, bounded, cancelable, integrity-checked, and ordered;
- no gateway identity leak or signed-destination credential leak exists;
- DocC and README match implemented behavior;
- all seven bash scripts pass syntax, help, invalid-command, safety, ordering,
  and public-export regression tests;
- the independent exported package builds and its sorted source manifest is
  reproducible;
- the starter app passes the iPhone Duo pose, Split View, safe-area, and
  multi-scene matrix under Xcode 27.1;
- no existing Flutter, Python, or Android SDK contract was changed merely to
  make the Swift port easier.
