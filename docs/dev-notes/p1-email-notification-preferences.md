# Feature: Email Notification Preferences (Settings UI)

**What was built:**
Added a new "Notifications" tab to the frontend Settings page, allowing users to independently toggle transactional emails via the `PATCH /settings/user` endpoint.

**Patterns used:**
- We followed the existing Settings section pattern where the `PATCH` payload directly spreads into the `updateUserSettings` mutation hook.
- We used the `lucide-react` `Bell` icon and appended the new section configuration directly into the constant `SETTINGS_SECTIONS`.

**Gotchas & Edge Cases:**
- Discovered and fixed a UI routing bug: The `bookings` tab inside the Settings page existed as a component but was inadvertently missing from the `SETTINGS_SECTIONS` export definition. This was causing a TypeScript union mismatch which we resolved by formally registering it in the UI arrays.

**Decisions made:**
- The master toggle `"Enable email notifications"` dynamically adjusts the opacity and disables pointer-events of the child features to make it explicitly clear that flipping the master switch pauses everything without needing to wipe the state of the individual toggles.
