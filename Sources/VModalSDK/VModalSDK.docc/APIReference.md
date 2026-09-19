# Operation Parity Reference

VModalSDK 1.2.5 maps the supported Flutter 1.2.2 operations to typed Swift
resources. Every async operation accepts an optional ``CancellationToken``.

## Scoped API

Prefer ``VModalProject/scope(collectionName:streamName:)`` and the immutable
``VModalScope`` operations: `upload`, `uploadMetadata`, `search`, `addAssets`,
`updateAsset`, `createIndex`, `listIndexJobs`, `indexStatus`, `deleteIndex`, and
`deleteCollection`. ``VModalProject/listCollections(mode:cancellation:)``
removes the project prefix from backend collection names.

## Client resources

- Authentication: `auth.health`, `auth.authCheck`, and `auth.me`.
- Searches: `searches.searchVideo` and ordered, bounded-concurrency
  `searches.searchBatch`.
- Collections: `listGroups`, direct streaming `uploadFile`,
  `uploadMetadataJSONL` with a 404-only fallback, `addAssets`,
  `updateDescription`, and confirmed/preview `delete`.
- Indexes: `jobsList`, `createIndex`, `indexStatus` with a 404-only list
  fallback, and `deleteIndex`.
- Administration: control-API `userStats`, plus users-API `usage` and
  `cacheStats`.
- R2: users-API `presignUploadFile` and `presignUploadFolderVideo`; both
  default to a 900-second expiration.
- Images: `getURL`, `getURLBulk`, bounded `getImageFromURL`, streaming
  `writeImageFromURL`, atomic `saveImageFromURL`, and
  `getImageBulkFromURLs`. Gateway mode removes identity overrides.
- Uploads: `videoUpload` and ordered `videoUploadBulk` return immediate
  ``UploadTask`` values. Signed single upload is the default. Experimental
  multipart is enabled only by `VideoUploadOptions(multipart: true)`.

## CCTV, adaptive upload, and transcode

``VideoUploadOptions`` carries `videoFilename`, `metadataText`, ordered
`metadataTags`, `startDatetimeUser`, and `reProcess` through single,
experimental multipart, resume, bulk, adaptive, and injected-transcode paths.
Absolute video timestamps require `Z` or an explicit UTC offset. Adaptive
conditions are caller observations and never trigger monitoring permissions.
A non-passthrough ``VideoTranscoder`` requires a file-backed source and its
distinct output is deleted only after complete upload finalization.

## Deliberately unavailable operations

Folder upload, embedding-model listing, collection auto-index get/set,
collection create/edit, private Google Drive operations, and SQL query are
represented by synchronous methods that throw ``FeatureDisabledError`` before
transport. The deprecated Google Drive collection-upload route remains in the
route manifest but is not a supported public operation.

## Ownership and limits

Gateway mode uses bearer authentication and emits no direct identity fields.
``MutableAPIKeyProvider`` rotation is visible to the next request. Control
responses are limited to 8 MiB, error bodies to 1 MiB, binary responses to
64 MiB, and checkpoints to 1 MiB. Close the client/project owner once; close is
idempotent and does not belong to a transient view lifecycle.
