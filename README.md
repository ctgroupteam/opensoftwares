# OpenSoftwares CRM

Production-ready, lightweight Android mobile CRM built for OpenSoftwares' internal founding team and channel partners.

---

## ═══ Architecture & 3-Table Schema ═══
The entire CRM is modeled into 3 ultra-fast, indexed PostgreSQL tables in Supabase:
1. **`crm_profiles`**: User identities, roles (`admin_founder`, `founder`, `channel_partner`), teams (`Gulbarga`, `Solapur`, `Both`), permissions, and disabled state.
2. **`crm_records`**: High-performance polymorphic entity table for all business modules:
   - `product`, `lead`, `task`, `partner`, `partner_visit`, `followup`, `collection`, `meeting`, `notice`, `quick_alert`, `activity_log`.
   - Synced via Supabase Realtime across all founding members.
3. **`crm_notifications`**: FCM HTTP v1 device tokens, push notifications, and alert acknowledgment audit trail.

---

## ═══ Security & Secrets Protocol ═══
- **Flutter App Client**: Ships strictly with `Supabase URL`, `anonKey`, and `google-services.json`.
- **Sensitive Secrets**: `SUPABASE_SERVICE_ROLE_KEY`, `DB_CONNECTION_STRING`, and `firebase-sa.json` live in `secrets.env` (outside git and never compiled into the APK).
- **Protected Files**: `.gitignore` excludes `secrets.env`, `firebase-sa.json`, `key.properties`, and `*.jks`.

---

## ═══ Admin Founder & Credentials ═══
- **Admin Founder**: `Yahya Mundewadi`
- **Mobile Number**: `9307426215` (Email alias: `9307426215@opensoftwares.app`)
- **Password**: `#kotlin`
- **Console Second Password**: `#kotlin`

---

## ═══ How to Add Users ═══
1. Open the app and log in as the Admin Founder (`9307426215` / `#kotlin`).
2. Open the navigation Drawer and tap **Admin Panel (Root)**.
3. Enter the secondary passcode (`#kotlin`).
4. Tap **New User**:
   - Enter Full Name, 10-digit Mobile Number, Assigned Password, Role (`Founders` or `Channel Partner`), and Assigned Team (`Gulbarga`, `Solapur`, `Both`).
   - The user is created instantly via backend secure RPC / Edge Function without exposing keys.

---

## ═══ Push Notifications & Quick Alert ═══
- **Notification Channels**:
  - `alerts`: Maximum importance with custom repeating alarm sound (`alarm_alert.wav`) and `0x04` insistent flag until acknowledged.
  - `reminders`: High importance for meetings and scheduled follow-ups.
  - `general`: Default importance for team tasks and notices.
- **Quick Alert**: Broadcaster screen allowing 4-5 word messages to trigger repeating sound on receiving devices with live acknowledgment roster ("Seen" / "Snoozed").

---

## ═══ Production Release Artifacts ═══
- **Dedicated Output Folder**: `output apk/`
- **Production Signed APK**: `output apk/OpenSoftwares-CRM-release.apk` (Size: ~10.0 MB)
- **Production Keystore Location**: `android/app/opensoftwares-release.jks` (Key Alias: `opensoftwares`)
- **Obfuscation Symbols**: `build/symbols`

### How to Rebuild the APK:
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi --obfuscate --split-debug-info=build/symbols
```

---

## ═══ Developer Attribution ═══
Crafted by **Yahya Mundewadi - yahya.in**
