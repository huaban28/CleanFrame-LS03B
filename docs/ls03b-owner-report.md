# 2022 Frame: owner report and experimental source

This fork records work on **QN75LS03BAFXZA**, **T-PTMAKUC-1720.7**, Tizen 6.5.0, ARMv7/32-bit. The build reported `T-PTMAKUC-REL-202602250225`. This is one owner's result, not support for all Samsung TVs or every LS03B firmware. Upstream base: `845f332d083502fab39be49869052966103b564a`.

## Observed results

| Flow | Observation |
| --- | --- |
| Independently signed CleanFrame | Installed and visible on the TV |
| YouTube | Opened from CleanFrame |
| Native main-operation assignment alone | Getter and database changes succeeded, but physical Home still opened Samsung Home, including after a full power cycle |
| Main operation plus Home preference | Home from YouTube opened CleanFrame |
| Art Mode | Entering Art Mode and waking worked in owner tests |
| Art Mode's own Home action / wake destination | Samsung Home can appear; the remote Home button still opens CleanFrame. Owner accepted this behavior |
| Complete rollback | Native getters, operation row, all recorded preferences and physical Samsung Home matched the baseline |
| Reapply | Returned to CleanFrame Home behavior |
| Netflix before patch | Selecting Netflix in CleanFrame entered Art Mode; developer-tool launch of the same native app ID opened Netflix |
| Netflix after patch | Owner confirmed Netflix opened from CleanFrame after installing an update using explicit default application control targeted at Netflix |
| Full power-cycle persistence with the combined change | **Not tested**; the earlier cold-cycle test was operation-only |
| Long-running stability / firmware updates | **Not established** |
| Fire TV HDMI wake/input switching | Reported separately. Fire TV HDMI-CEC was disabled for diagnosis; resolution and cause remain unconfirmed |

## Changes and limits

The working Home trial assigns `http://tizen.org/appcontrol/operation/main` and `db/appfw/home_appid` to the owner's own launcher ID. It does not write startup, boot-backup, first-screen, autostart, power-button or Art Mode settings. Samsung may update derived startup preferences asynchronously: a restore's immediate final verification failed once, while a subsequent read confirmed exact restoration. The helper now waits up to ten seconds for those recorded preferences to settle. This timing fix has been compiled; the subsequent logged restore/reapply also succeeded.

The Netflix patch changes only `org.tizen.netflix-app` to an explicit `launchAppControl` request with the default operation and the same application ID. Other apps retain the existing launch API. This is an observed workaround; the platform-level reason for the original Art Mode transition was not established. It is not a general claim that `application.launch` cannot launch Netflix.

## Native experiment

See [experimental source and preparation](../scripts/native-home/frame-2022/README.md). The public version uses owner-supplied placeholders and private configuration; those newly parameterized templates and runner have **not been deployed to the TV**. They are derived from the private helper that was tested, but source refactoring is not device validation. No compiled helper, signed widget, personal baseline or certificates are included.

The native route uses an undocumented developer package-name execution workaround as restricted SDK UID 901. Apply and recovery depend on the same SDB/network transport. No independent recovery transport has been demonstrated. Firmware/library hash guards must not be bypassed. Preserve recovery data outside the checkout before experimenting; do not uninstall the launcher while it owns Home.

## Credits

CleanFrame and its original implementation are by Nathan Clark. The native approach builds on its published helper and compatibility notes. This fork preserves upstream MIT licensing and all third-party notices. Samsung and streaming-service names remain their owners' trademarks.
