# iPhone Duo acceptance matrix

Deferred until Xcode 27.1 and its iPhone Duo simulator are available in CI.
The former acceptance contract is retained below as a comment for restoration.

<!-- FUTURE_IPHONE_DUO_XCODE_27_1
Run with Xcode 27.1 and the iOS 27.1 runtime. Resolve the installed destination
with `xcrun simctl list devices available`; CI must use the exact iPhone Duo
simulator UDID and must not substitute another device.

| Scenario | Expected result |
|---|---|
| Portrait, folded | Primary navigation and current detail remain reachable; no clipped controls |
| Portrait, unfolded | Split columns use available width; content remains inside safe areas |
| Landscape, folded and unfolded | Rotation preserves the selected collection and search text |
| Split View at every divider position | No fixed-width overflow; compact navigation remains usable |
| Fold or resize during upload | The same `UploadTask` continues; no second control request or PUT starts |
| Background then foreground | Visible state is retained and progress resumes rendering |
| Two windows | Both scenes use the intended app-session client; closing a view does not close it |
| Cancel upload/search | Only the selected operation is canceled; a later request succeeds |
| Dynamic Type and VoiceOver | Labels remain readable and actionable controls have accessible names |

Automation builds and launches `example/StarterIOS`. Network continuity and
request-count assertions use injected transports in `DuoCompatibilityTests`;
the simulator pass covers geometry, scene lifecycle, and interaction.
-->
