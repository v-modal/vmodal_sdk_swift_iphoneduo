# Swift SDK reference publication

The generated Swift SDK class and method reference is published at:

**https://v-modal.github.io/vmodal_sdk_swift_iphoneduo/**

The site is hosted by GitHub Pages from the `gh-pages` branch of
`v-modal/vmodal_sdk_swift_iphoneduo`. Its source is the public Swift API and
DocC catalog under `Sources/VModalSDK/`; the generated static site is stored in
this `docs_sdk/` directory. Do not edit generated HTML, JavaScript, JSON, or
asset files by hand. This README is preserved when the site is regenerated.

## Publish the SDK reference

Publication is handled by the manual GitHub Actions workflow
`.github/workflows/sdk_swift_apple_test_release.yml`. To publish only the SDK
reference, run this from the monorepo root:

```bash
gh workflow run .github/workflows/sdk_swift_apple_test_release.yml \
  -f publish_sdk_swift_apple=false \
  -f publish_sdk_docs_only=true
```

The workflow:

1. Scans the Swift SDK tree for secrets.
2. Builds the DocC archive with its GitHub Pages base path.
3. Transforms the archive for static hosting and verifies required pages.
4. Uploads `docs_sdk/` as an immutable workflow artifact.
5. Replaces the public repository's `gh-pages` branch with that artifact.
6. Enables branch-based GitHub Pages and verifies the deployed `RELEASE_SHA`.

A normal source release also publishes the reference when
`publish_sdk_swift_apple=true`. The workflow requires the `GH_TOKEN` secret in
the `sdk-swift-apple-production` environment. Do not report the publication as
successful until the `publish_sdk_docs` job passes its deployed SHA check.

## Generate and inspect locally

Full Xcode is required. From the Swift SDK directory:

```bash
bash cli.sh docs_generate
bash cli.sh docs_check
python -m http.server 8000 --directory docs_sdk
```

Then open `http://localhost:8000/vmodal_sdk_swift_iphoneduo/documentation/vmodalsdk/`.
Commit public API comments, DocC catalog changes, generator changes, this
README, and regenerated `docs_sdk/` output together.
