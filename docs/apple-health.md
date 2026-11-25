# Apple Health in GainGuide

Install the signed iOS app and open Today → Account → Settings → Apple Health. Select categories, choose a historical period (90 days by default), consent to Supabase storage and answer Apple's separate read-permission prompt. The PWA and other clients can read synchronized data, export it and disconnect or delete it. They cannot open the iPhone HealthKit store.

## Coverage and source verification

| Category | HealthKit readings and standardized units | Expected sources when enabled |
| --- | --- | --- |
| Activity | Steps, active and basal kcal, walking/running metres, exercise minutes | iPhone and Apple Watch. Apple Exercise Time requires a contributing device or workout. |
| Body | Weight and lean mass in kg, body fat in percentage points, BMI in kg/m² | RENPHO documents weight, body fat and BMI. Lean mass availability depends on the writer. |
| Nutrition | Dietary kcal, protein/carbohydrate/fat/fibre in grams, water in mL | MyFitnessPal supports meal summaries and most nutrients. Check each nutrient and water independently. |
| Recovery | Sleep intervals with original stage codes, asleep hours, resting bpm, HRV SDNN in ms and breaths/minute | Sleep Cycle supports Apple Health sync. Watch model, sleep tracking settings and source app determine which readings and stages exist. |

To verify a particular phone, inspect Health → Browse → the measurement → Show All Data. Compare the timestamp and source against the exported sample or query the authenticated `health_sources` view. No data and withheld read access look alike to the app. It never estimates a missing metric or fills a missing day with zero.

## Synchronization and analysis

Each consent decision authorizes one account and one iOS installation. Connecting another installation takes over synchronization. Changes to category selection or lookback start a fresh import. Samples outside a new lookback are retained. Disconnect stops uploads. Delete removes the account’s imported samples, totals, settings and checkpoints. It leaves the HealthKit originals and GainGuide workout history intact.

The user's Supabase session uploads pages of 400 from an anchored query for each selected HealthKit type. A database transaction verifies account, consent revision and previous anchor, then updates UUID-keyed samples, removes tombstones and advances the checkpoint. HealthKit is the offline journal. No additional local health-measurement database is required. Failed pages retry with backoff while the process runs and resume on launch, foreground or manual sync. The store can be inaccessible while the phone is locked. iOS schedules observer delivery at its discretion. Force-quit, background settings, battery and connectivity can delay it.

Activity totals come from HealthKit's merged cumulative statistics. Nutrition uses one source per nutrient per day to avoid counting a mirrored diary twice. MyFitnessPal has priority, then bundle identifier order. This can omit foods recorded only in a secondary diary. Individual samples preserve every source. Sleep duration is the union of actual asleep intervals split at local midnight. Awake and in-bed time are excluded. Unspecified asleep contributes to duration without an invented stage. Body composition uses the last reading of each day. Recovery rates use observed readings. Reporting days use the import's IANA zone and timestamps are stored as instants. Week begins Monday. Averages divide by observed days only.

Use the publishable key and the user's authenticated JWT with the Data API. All views run with invoker rights. `health_daily`, `health_periods`, `health_workout_periods`, `health_exercise_progress`, `health_sources` and `health_export_samples` support external analysis. Join health and workout period views on user_id, period and beginning. Exercise progress compares best reps at the same load across sessions and exposes loads for comparing weight at the same reps. The History export includes daily totals, original readings, stage labels and source identifiers, even in a range without workouts.

## Deployment and physical-device acceptance

1. Run the Apple Health migration after existing migrations on staging, then run `psql -v ON_ERROR_STOP=1 -f supabase/tests/apple_health.sql` using a disposable migrated database. Deploy the migration before shipping either client. The existing Supabase URL and publishable key are used.
2. On macOS install Flutter stable and Xcode with the iOS SDK. Run `flutter pub get`. Open `ios/Runner.xcworkspace`, select the release team and replace the sample bundle ID with a registered App ID. Enable HealthKit and its Background Delivery option for Runner in every signing configuration. Regenerate provisioning profiles. The entitlements and read-purpose string are checked in. No HealthKit write, clinical records or research entitlement is needed.
3. Publish the privacy policy before distribution. Disclose the categories and metadata above, fitness-analysis purpose, Supabase as processor, account linkage, access controls, deletion, retention/backups, operator contact and any applicable regional rights. Confirm actual hosting and backup-retention details with the operator. Provide an accessible policy URL in the app and App Store Connect. Complete the Health & Fitness privacy labels for collected data linked to identity, including app functionality. Do not route measurements into advertising, tracking, crash reports or iCloud backups. Explain the opt-in path in App Review notes.
4. Test a signed build on an iPhone. Grant only one category, deny one type, verify source/units and absence of fabricated zeroes. Test linked Apple Watch and iPhone steps against Health. Add, edit and delete a manual measurement. Sync twice. Disconnect networking midway, reconnect, switch accounts, sign out, lock/unlock and foreground. Confirm only the consenting account changes. Observe background delivery on-device. Test both revoke-only and confirmed cloud deletion. Verify export for a date without workouts.
5. Build and release the signed iOS binary and existing web bundle through their normal release paths. The simulator and SQL fixtures cannot establish which apps have actually written to a specific person's Health store.

## References

- [Apple HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Apple HealthKit read queries](https://developer.apple.com/documentation/healthkit/reading-data-from-healthkit)
- [Background entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery)
- [Aggregate statistics](https://developer.apple.com/documentation/healthkit/hkstatistics)
- [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) and [App Review Guidelines §5.1.3](https://developer.apple.com/app-store/review/guidelines/)
- [MyFitnessPal supported directions and data](https://support.myfitnesspal.com/hc/en-us/articles/360032271092-Apple-Health-connection-and-syncing)
- [RENPHO setup](https://renpho.com/pages/user-manual-body-composition-scale) and [vendor's HealthKit coverage](https://apps.apple.com/ca/app/renpho-health/id1543340610)
- [Sleep Cycle and Apple Health](https://support.sleepcycle.com/hc/en-us/articles/207388435-Does-Sleep-Cycle-support-the-Apple-Health-app)
