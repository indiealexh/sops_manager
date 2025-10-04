# sops_manager

Flutter App to help manage SOPS encrypted files

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

