# Running Jayla in Xcode

How to build and run the Jayla app on the iOS Simulator and on a physical
iPhone, plus the gotchas we hit setting it up.

- **Bundle identifier:** `com.joannesun.Jayla`
- **Minimum iOS version:** 26.5 (set in the target's *Minimum Deployments*)
- **Open the project:** `open Jayla.xcodeproj` (or double-click it in Finder)

---

## Option A — iOS Simulator (fastest, no setup)

1. In the top toolbar, click the run-destination dropdown (it may say
   *My Mac* or a device name).
2. Under **iOS Simulators**, pick an iPhone (e.g. **iPhone 17**).
3. Press **⌘R** (the ▶ button) to build and run. The simulator boots and
   installs the app.

Because a fresh simulator has no saved data, the app opens on the
**onboarding screen** (name, birthday, photo).

> If the *iOS Simulators* section is empty, install a runtime:
> **Xcode → Settings (⌘,) → Components → download an iOS 26.5 simulator.**

---

## Option B — Physical iPhone (what we set up)

Requires an iPhone running **iOS 26.5 or newer** (the app's minimum), a
**data-capable USB cable**, and an Apple ID.

### 1. Connect and trust the phone
1. Plug the iPhone into the Mac with a data cable (charge-only cables will
   not work — the device simply never appears).
2. **Unlock** the phone. If a **"Trust This Computer?"** prompt appears, tap
   **Trust** and enter your passcode.
3. Confirm the Mac sees it: **Xcode → Window → Devices and Simulators**
   (⇧⌘2). The iPhone should appear in the left list. First time, Xcode shows
   *"Preparing iPhone for development…"* — let it finish.

   You can also verify from Terminal:
   ```sh
   xcrun devicectl list devices
   ```
   The phone should be listed as `available (paired)`.

### 2. Set a signing team
On the first device run, Xcode needs a signing team, or it errors with
*"Signing for 'Jayla' requires a development team."*

1. **Left-click** the blue **Jayla** project at the very top of the left
   sidebar (a single normal click — right-click only shows a context menu
   without these tabs).
2. In the editor pane on the right, under **TARGETS**, select **Jayla**.
3. Click the **Signing & Capabilities** tab (in the row *General · Signing &
   Capabilities · Resource Tags · Info · Build Settings · Build Phases*).
4. Tick **Automatically manage signing**.
5. Set **Team** to your Apple ID. If the list is empty, choose
   **Add an Account…**, sign in, then select the resulting *Personal Team*.

> A free Apple ID works for running on your own device, but the build
> expires after **7 days** and must be re-installed from Xcode. A paid Apple
> Developer account removes that limit.

### 3. Enable Developer Mode on the phone
The **Developer Mode** setting only appears *after* the phone has been paired
with Xcode (step 1). It is hidden before that.

1. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**.
2. Restart the phone when prompted.

### 4. Select the phone and run
1. In the top toolbar, open the destination dropdown and select your
   **iPhone**.
2. Press **⌘R**.

### 5. Trust the developer app (first launch only)
The first install, iOS blocks the app as an *"Untrusted Developer."*

1. On the iPhone: **Settings → General → VPN & Device Management**.
2. Tap the **Jayla** developer app → **Trust**.
3. Tap the Jayla icon on the Home Screen to open it.

The app opens on the **onboarding screen** on first launch.

---

## Resetting app data

Jayla stores data locally with SwiftData. To get back to the onboarding
screen (or clear an old profile that predates a schema change), delete the
app's data:

- **Simulator:** long-press the app icon → **Remove App → Delete App**. Or
  reset the whole simulator: **Simulator menu → Device → Erase All Content
  and Settings**.
- **Physical iPhone:** long-press the app icon → **Remove App → Delete App**.
- **Mac build (native macOS run):** the store lives in the app's sandbox
  container — delete these files while the app is **stopped**:
  ```sh
  rm -f ~/Library/Containers/com.joannesun.Jayla/Data/Library/Application\ Support/default.store*
  ```

Then run again (⌘R) for a fresh install.

---

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| iPhone not in the run dropdown | Not paired/trusted yet, charge-only cable, or Developer Mode off. See Option B steps 1 & 3. |
| Mac shows "No devices found" | Cable is charge-only or phone is locked/untrusted. Try another cable/port, unlock, tap Trust. |
| "Developer Mode" missing in Settings | The phone hasn't been paired with Xcode yet — do Option B step 1 first, then it appears. |
| "Signing requires a development team" | Set a Team in **Signing & Capabilities** (Option B step 2). |
| "Untrusted Developer" on launch | Trust the app under **Settings → General → VPN & Device Management** (Option B step 5). |
| App opens on the home screen, not onboarding | An old profile already exists — reset app data (see above). |
| Code changes / colors don't show | You're running a stale build or on **My Mac** instead of a phone. Clean (⇧⌘K), pick the right destination, run again. |
| Device is "ineligible" | The iPhone's iOS is older than the app's minimum (26.5). Update the phone, or lower the deployment target. |

---

## Note: "My Mac" vs a phone

Jayla is a portrait **phone** app. Xcode may default the run destination to
**My Mac**, which builds a resizable Mac window — it works but looks
stretched, and there's no home-screen icon to long-press. For the intended
experience, always pick an **iPhone simulator** or your **physical iPhone**
from the destination dropdown.
