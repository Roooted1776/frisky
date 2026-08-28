# Apple Health Import

`HealthKitProfileImport` is an optional, owner-only, read-only import of birth
date and blood type from Apple Health into the Edit draft (see
`RedMedView`'s empty-profile funnel and `EditProfileView`). It never writes to
Health, never runs on the passerby / scanner shell, and profile persistence
still requires Save (Face ID on first fill).

## Currently parked (personal team signing)

`AppConfig.healthKitImportEnabled = false` and `RedMed.entitlements` is a bare
`<dict/>` (no HealthKit key). Free / personal Apple Developer teams cannot
provision the **HealthKit** capability, so Xcode's automatic signing fails the
whole build ("Cannot create a iOS App Development provisioning profile") while
the entitlement is present — the same class of problem as CoreNFC
(`docs/NFC-RESTORE.md`) and Associated Domains. Keep the flag and the
entitlements file in lockstep.

While parked, `HealthKitProfileImport.isAvailable` is always `false`, so the
"Fill from Apple Health" button never renders on the empty-profile funnel and
`readCharacteristics()` is unreachable from the UI. `HealthKit.framework`
stays linked in `project.pbxproj` (framework linking does not require the
entitlement). `NSHealthShareUsageDescription` is **omitted** from `Info.plist`
while parked so Review does not see an unused Health purpose string.

## Restore (paid Program)

1. Add `com.apple.developer.healthkit` = `true` back to
   `RedMed-Xcode/RedMed/RedMed.entitlements`.
2. Flip `AppConfig.healthKitImportEnabled` to `true`.
3. Add `NSHealthShareUsageDescription` to `Info.plist`:
   `RedMed reads birth date and blood type from Apple Health to fill your medical ID. Nothing is written back to Health, and nothing is sent off this iPhone.`
4. Build with a paid Apple Developer Program team selected (not a personal /
   free team) so automatic signing can provision the capability.
