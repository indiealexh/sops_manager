# SOPS Manager

Desktop Flutter app that helps you manage SOPS‑encrypted configuration files and the Age recipients that can decrypt them.

- Guides you through first‑run setup (requirements → pick identity and project root → confirm → finish)
- Creates/updates public-age-keys.yaml and .sops.yaml
- Scans your project for files matched by path_regex and shows which are encrypted
- Batch runs common sops actions: updatekeys, decrypt (unlock), encrypt (lock)

## Requirements
- SOPS CLI available on PATH
- Age tools on PATH (age, age-keygen) and an Age identity file (e.g. ~/.config/age/keys.txt)
- Flutter SDK with desktop support enabled (macOS, Linux, or Windows)

To verify tools, the app runs:
- `age --version`
- `sops --version`

If either is missing, the Requirements screen will tell you. Install instructions:
- age: https://github.com/FiloSottile/age
- sops: https://github.com/getsops/sops

## Quick start
1) Install age and sops and ensure both commands work in a terminal.
2) Clone this repo and run the app.
   - macOS: `flutter run -d macos`
   - Linux: `flutter run -d linux`
   - Windows: `flutter run -d windows`
3) Follow the onboarding flow:
   - Requirements: checks that age and sops are installed.
   - Setup: pick your Age identity file and the project root directory you want to manage. The app will derive your public key via `age-keygen -y` when possible (you can paste it manually too).
   - Confirm: shows detected path_regex patterns from .sops.yaml (if present), how many files match, and currently configured recipients.
   - Finish: writes/updates the project files and opens Manage.

## What the app does
- Creates or updates two files in your project root:
  - public-age-keys.yaml — a list of Age recipient keys and their owners.
  - .sops.yaml — ensures creation_rules contain an `age:` recipient list that matches public-age-keys.yaml.
- Scans the project for files that match your .sops.yaml `path_regex` rules and marks which are already sops-encrypted.
- Runs sops in batch for selected files:
  - Update recipients: `sops updatekeys -y <file>`
  - Decrypt in place: `sops -d -i <file>` (Unlock Project)
  - Encrypt in place: `sops -e -i <file>` (Lock Project)
- Uses `SOPS_AGE_KEY_FILE=<your identity path>` when calling sops so you don’t have to export it manually.

## Manage page (day‑to‑day use)
- Public keys editor (left): edit entries for public-age-keys.yaml. Each entry has:
  - `key`: Age recipient (age1…)
  - `ownerType`: one of `user` or `cluster`
  - `owner`: free‑form label (person, cluster name, etc.)
- Actions:
  - “Save Keys & Update .sops.yaml” — writes public-age-keys.yaml and updates recipients in all creation_rules found in .sops.yaml (creating it if missing).
  - “sops updatekeys” — runs updatekeys on selected files.
  - “Unlock Project” — decrypts selected files in place.
  - “Lock Project” — encrypts selected files in place.
- Files panel (right):
  - “Scan” lists files matched by `path_regex` in .sops.yaml; defaults to YAML/JSON/.env if no config exists.
  - Shows pattern chips, a text filter, and whether each file is Encrypted or Plain.
  - Use Select All / Select None and checkboxes to choose which files to operate on.
- Logs panel: live INFO/WARN/ERROR messages with filters, search, clear, and copy‑to‑clipboard.

## Under the hood (how it works)
- CLI integration: Process.run is used to call `age-keygen` and `sops`. For `sops`, the environment variable `SOPS_AGE_KEY_FILE` is set to the chosen identity path for each call.
- File scanning:
  - Reads `path_regex` patterns from `.sops.yaml` (if present). If none are found, defaults to `.*\.(yaml|yml|json|env)$`.
  - Walks the project directory recursively and inspects small files (≤ 5 MB). For YAML/JSON, detects sops files by searching for a `sops:` block (YAML) or a top‑level "sops" key (JSON).
- Project files:
  - `public-age-keys.yaml` is written using a simple line‑based format:
    
    ```yaml
    publicKeys:
      - key: age1...
        ownerType: user
        owner: alice
    ```
  - `.sops.yaml` recipients are updated for each `creation_rules` item. If an `age:` block exists, it is replaced; otherwise it is added.
- Concurrency: long‑running sops operations run in parallel (default 4 at a time) using a simple semaphore.
- Preferences: stored via shared_preferences
  - `themeMode` (system/light/dark)
  - `lastProjectRoot`, `lastAgeIdentityPath`, `onboardingComplete`

## Security notes
- The app does not read your private key material; it only passes the path to sops via `SOPS_AGE_KEY_FILE`.
- Paths and settings are stored in your local user preferences (plain text). Avoid using this on shared machines/accounts.
- Decrypting “in place” modifies files on disk. Ensure you have a clean working tree and understand your git workflow before running bulk decrypt/encrypt.

## Project structure
```
lib/
  main.dart                     # Entry point
  app.dart                      # MaterialApp + theme persistence
  pages/
    install_check_page.dart     # Requirements check UI
    setup_page.dart             # Initial setup UI (paths + create files)
    manage_page.dart            # Manage keys + updatekeys/lock/unlock + logs
    onboarding_stepper.dart     # Optional guided flow combining the above
  services/
    sops_service.dart           # All SOPS/AGE I/O and CLI helpers
    log_bus.dart                # Simple event bus for logs
  models/
    public_key_entry.dart       # Data model for public-age-keys entries
    log_entry.dart              # Log entry model
    proc_result.dart            # Wrapper for CLI results
  utils/
    file_path.dart              # Cross‑platform path helper
  widgets/
    app_shell.dart              # Navigation shell (Requirements/Setup/Manage)
    public_key_entry_card.dart  # Editor UI for a single key entry
    outputs_panel.dart          # Reusable scrollable output panel
    log_view.dart               # Log viewer with filters/search
    responsive_action_bar.dart  # Wrap-based responsive button bar
```

## Development
- Get Flutter dependencies: `flutter pub get`
- Run on desktop: `flutter run -d macos|linux|windows`
- Build release: `flutter build macos|linux|windows`

This app uses Material 3 and shared_preferences; on macOS it uses CocoaPods (generated by Flutter). The file picker comes from file_selector.

## Troubleshooting
- “age not found / sops not found”: ensure both are installed and available on PATH for the GUI process (on macOS you may need to launch the app from a terminal so it inherits your shell PATH, or adjust LaunchServices environment).
- “Could not derive public key”: run `age-keygen -y ~/.config/age/keys.txt` yourself and paste the resulting `age1…` key into the Public key field.
- Recipients didn’t update: `.sops.yaml` must contain `creation_rules`. This tool updates/creates only the `age:` block inside each rule; it doesn’t alter other SOPS settings.
- Large repositories: scanning skips files larger than 5 MB and follows no symlinks.

---

If you spot inaccuracies or want additional features, please open an issue or PR.

