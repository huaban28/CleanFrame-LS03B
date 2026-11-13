# Experimental 2022 LS03B source

Read the [owner report](../../../docs/ls03b-owner-report.md) and upstream [staged setup guide](../../../docs/agent-tv-setup-guide.md) first. This folder does not extend upstream's reference helper or allowlist. It is not an unattended installer. The newly parameterized public source and runner have not been deployed; only their private predecessor was tested on the reported TV.

## Before preparing source

Use your own SDK-generated launcher identity and Samsung certificates. Establish a read-only original baseline first with the native getters, relevant operation database rows and typed preference reads. A failed query or empty value is not the baseline used here. Do not use this template for empty/missing originals, different database scopes, different startup/autostart values or unreviewed firmware.

Keep an owner-created JSON file under `.local/`, with these fields:

- `model`: exact model, which this profile restricts to QN75LS03BAFXZA.
- `firmware`: exact firmware, restricted to T-PTMAKUC-1720.7.
- `package_id`, `app_id`: your SDK-generated identities.
- `original_home`: the successfully queried original native Home assignment.
- `original_strings`: your exact string values keyed by `db/appfw/home_appid`, `db/appfw/startup_appid`, `db/appfw/booting_appid_backup`, `db/first_screen/type`.
- `original_autostart`: the observed integer value for `db/menu/smart_hub/ontvsetting/auto_start`.

This template supports only the recorded case where all four original strings equal the nonempty original native Home ID and autostart is 1. Preserve query return codes, row scopes, native library hashes, original files and the helper source separately as recovery evidence. The source contains exact hashes for the reviewed firmware's operation and AUL libraries.

## Prepare and build offline

From the repository root, after creating your private configuration:

```sh
python scripts/native-home/frame-2022/prepare.py --config .local/ls03b.json --output .local/ls03b-source
dotnet build .local/ls03b-source/FrameQuery.csproj -c Release -o .local/ls03b-out
```

The project targets .NET Core 3.1, matching the runtime used on the reported TV. Use a toolchain capable of this target. Do not commit SDKs, generated source/configuration, binaries, debug symbols or recovery data.

## Windows transport

`Run-HomeTrial.ps1` needs a separate private JSON transport config containing `sdk_path`, `tv_ip`, `model`, `build_folder` and `result_folder`. Both folders must already exist; use private absolute paths. `build_folder` must hold the reviewed DLL, runtimeconfig and deps files; the result folder stores private diagnostics. The runner checks the TV model over the local information endpoint and reconnects SDB before uploading. It binds a temporary callback listener to the local interface routed to your TV and validates the peer address. It does not add firewall rules or router port forwarding.

```powershell
# Substitute your actual private config path. Preflight still uploads/executes temporary files.
& .\scripts\native-home\frame-2022\Run-HomeTrial.ps1 -ConfigPath .\.local\ls03b-transport.json -Mode preflight
```

Prepare concrete commands for `-Mode apply` and `-Mode restore` only after the source, identity, baseline, transport and recovery files have been reviewed for that owner. Announce device interruptions and obtain explicit authority before writes. Preflight succeeding does not prove setter permissions, physical Home behavior or recovery.

Apply writes only the native main operation and Home preference. It checks both getters, row scopes and original preferences, and attempts rollback on a failed apply. Restore accepts only the reviewed original/target states and restores both Home values; it polls original preferences for up to ten seconds. Inspect `NATIVE_HELPER_EXIT` and the final markers; an outer script exit alone does not prove success. Never treat a failed verification as proof that no writes occurred.

Physically test Home from streaming, entering/exiting Art Mode, wake, exact restoration, reapply and a full power cycle. Keep wake destination, Art Mode's Home action, remote Home and normal startup as separate results. A later firmware update may invalidate execution and restore. Stop on unknown state rather than widening guards.
