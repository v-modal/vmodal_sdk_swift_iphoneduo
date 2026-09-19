# ``VModalSDK``

Build concurrency-safe VModal 1.2.5 clients for Apple platforms.

## Overview

Start with a rotating ``MutableAPIKeyProvider`` and ``VModal/configure(projectID:apiKeyProvider:baseURL:timeout:mode:maxRetries:)``.
Use ``VModalProject/listCollections(mode:cancellation:)`` to discover content,
then create a ``VModalScope`` so collection and stream identity stays consistent
across uploads, searches, and index jobs.

An ``UploadTask`` begins immediately. Observe its progress stream, await its
result, or cancel it. Close the owning project or ``VModalClient`` when the
application session ends. Both close operations are idempotent.

The default gateway mode sends bearer authentication and omits direct identity
fields. Signed upload requests use a separate transport and an explicit header
allowlist. Response readers and uploads enforce bounded data flow.

### Topics

- <doc:GettingStarted>
- <doc:APIReference>
- ``VModal``
- ``VModalClient``
- ``VModalProject``
- ``VModalScope``
- ``SDKConfig``
- ``APIKeyProvider``
- ``MutableAPIKeyProvider``
- ``UploadSource``
- ``UploadTask``
- ``VModalError``
