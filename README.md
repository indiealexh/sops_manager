# sops_manager

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Project structure (updated on 2025-10-03)

```
lib/
  app.dart                      # SopsManagerApp: MaterialApp + theme
  main.dart                     # Entry point only
  pages/
    install_check_page.dart     # Requirements check UI
    setup_page.dart             # Initial setup UI (paths + create files)
    manage_page.dart            # Manage keys + updatekeys/lock/unlock
  services/
    sops_service.dart           # All SOPS/AGE related I/O and CLI helpers
  models/
    public_key_entry.dart       # Data model for public-age-keys entries
    proc_result.dart            # Simple wrapper for CLI results
  utils/
    file_path.dart              # Cross‑platform path helper
  widgets/
    public_key_entry_card.dart  # Editor UI for a single key entry
    outputs_panel.dart          # Reusable scrollable output panel
    responsive_action_bar.dart  # Wrap-based responsive button bar
```

Notes:
- App behavior is unchanged; this is a pure organization refactor for discoverability.
- If you add new pages or services, follow the same folder conventions.
- Desktop entitlements and pubspec dependencies remain as they were.
