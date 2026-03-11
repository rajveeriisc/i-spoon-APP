# Comprehensive Code Review & Problem Report - iSpoon Project

## 1. Backend (ispoon-backend)

### Architectural Inconsistencies & Redundancies
- **Duplicate Logic:** Multiple versions of services and repositories exist, creating ambiguity:
    - `userService.js` vs `user.service.js`
    - `userModel.js` vs `user.repository.js`
- **Pattern Bypass:** `firebaseAuthController.js` performs direct SQL queries using the `pool` object, bypassing the established Service and Repository/Model layers. This fragments business logic and makes maintenance difficult.

### Data Sync & Integrity Risks
- **Idempotency Issues:** `upsertBites` in `biteModel.js` uses `ON CONFLICT DO NOTHING`. If a bite record is updated on the mobile device (e.g., corrected timestamp or invalidation) and re-synced, the server will ignore the changes rather than updating the existing record.

### Security & DevOps
- **Missing Test Automation:** `package.json` lacks a unified `npm test` script. While individual scripts exist, there's no CI-ready entry point.
- **Root Clutter:** Temporary scripts (`test-auth-complete.js`, `run-migration-007.js`) and log files (`fix-env.txt`) are scattered in the root directory instead of being organized into a `scripts/` folder.

---

## 2. Frontend (smartspoon)

### Extensive Technical Debt (77+ Issues)
- **UI Deprecations:**
    - `withOpacity` is used extensively but is deprecated in Flutter 3.x; must migrate to `.withValues(alpha: ...)`.
    - `surfaceVariant` is used for themes but is deprecated in favor of `surfaceContainerHighest`.
    - `value` in form fields is deprecated; `initialValue` should be used.
- **Code Bloat:** Multiple files (e.g., `home_page.dart`) contain unused imports of `provider` and internal services, which slows down compilation and increases binary size.
- **Stability Risks:** Warnings for `use_build_context_synchronously` in notification screens indicate potential crashes if context is accessed after an async gap where the widget might have been unmounted.

### Platform Integration
- **Isolate Communication:** The background BLE task (`SpoonTaskHandler`) communicates with the main UI isolate via `SharedPreferences` polling every 10 seconds. This is a high-latency, indirect bridge that can lead to UI lag or race conditions.
- **Complexity:** The `ProxyProvider` chain in `main.dart` is highly nested and deeply coupled, making the app's initialization sequence difficult to debug and unit test.

---

## 3. General Project Structure

- **Orphaned Files:** Root-level Swift files (`BLEApp.swift`, `BLEManager.swift`, `BLEConnectionView.swift`) appear to be leftovers from a prototype and should be moved into the iOS project folder or removed.
- **Documentation Mismatch:** The `imu.md` documentation describes a packet-based real-time processing model, but the implementation in `motion_analysis_service.dart` still maintains state for full-meal accumulation, leading to potential memory issues on long eating sessions.
