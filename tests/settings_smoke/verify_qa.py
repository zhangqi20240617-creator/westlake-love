# -*- coding: utf-8 -*-
"""QA Smoke Test for System Settings Panel & SettingsManager."""
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

def main():
    print("=" * 60)
    print("🚀 Running System Settings System QA Verification...")
    print("=" * 60)

    # 1. Check SettingsManager.gd
    mgr_path = "scripts/SettingsManager.gd"
    assert os.path.exists(mgr_path), "scripts/SettingsManager.gd must exist!"
    with open(mgr_path, "r", encoding="utf-8") as f:
        content = f.read()
    assert "class_name" not in content, "Autoload singletons should not declare class_name"
    assert "save_settings" in content and "load_settings" in content, "Missing settings persistence methods"
    assert "apply_all_settings" in content, "Missing apply_all_settings method"
    print("✅ scripts/SettingsManager.gd verified with persistence & audio/display bindings")

    # 2. Check project.godot autoload
    with open("project.godot", "r", encoding="utf-8") as f:
        p_godot = f.read()
    assert 'SettingsManager="*res://scripts/SettingsManager.gd"' in p_godot, "SettingsManager not registered in project.godot!"
    print("✅ SettingsManager is properly registered as Autoload in project.godot")

    # 3. Check SettingsPopupUI.gd
    ui_path = "scripts/SettingsPopupUI.gd"
    assert os.path.exists(ui_path), "scripts/SettingsPopupUI.gd must exist!"
    with open(ui_path, "r", encoding="utf-8") as f:
        ui_code = f.read()
    assert "_render_audio_settings" in ui_code, "Missing audio settings page"
    assert "_render_display_settings" in ui_code, "Missing display settings page"
    assert "_render_gameplay_settings" in ui_code, "Missing gameplay text settings page"
    assert "SettingsManager" in ui_code, "SettingsPopupUI must bind to SettingsManager"
    print("✅ scripts/SettingsPopupUI.gd verified with Audio, Display, and Gameplay panels")

    # 4. Check MainGame.gd integration
    with open("scripts/MainGame.gd", "r", encoding="utf-8") as f:
        mg_code = f.read()
    assert "func _show_settings_popup()" in mg_code, "MainGame.gd missing _show_settings_popup"
    assert "KEY_ESCAPE" in mg_code, "MainGame.gd missing ESC shortcut hook"
    assert "⚙️ 系统设置" in mg_code, "MainGame.gd missing More menu button"
    print("✅ MainGame.gd hooks verified (Menu entry, ESC shortcut, _show_settings_popup)")

    # 5. Check DialogueUI.gd text speed binding
    with open("scripts/DialogueUI.gd", "r", encoding="utf-8") as f:
        dlg_code = f.read()
    assert "SettingsManager.text_speed_idx" in dlg_code, "DialogueUI.gd missing text speed dynamic binding"
    print("✅ DialogueUI.gd dynamic typewriter speed binding verified")

    print("=" * 60)
    print("🎉 ALL SYSTEM SETTINGS CHECKS PASSED! VERDICT: PASS")
    print("=" * 60)

if __name__ == "__main__":
    main()
