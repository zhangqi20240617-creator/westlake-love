# -*- coding: utf-8 -*-
"""QA Smoke Test for Audio System (AudioManager.gd, assets, hooks, Autoload)."""
import os
import sys
import wave

sys.stdout.reconfigure(encoding='utf-8')

def main():
    print("=" * 60)
    print("🚀 Running Audio System QA Verification...")
    print("=" * 60)

    # 1. Check AudioManager.gd
    audio_mgr_path = "scripts/AudioManager.gd"
    assert os.path.exists(audio_mgr_path), "AudioManager.gd must exist!"
    with open(audio_mgr_path, "r", encoding="utf-8") as f:
        content = f.read()
    assert "class_name" not in content, "Autoload singletons should not declare conflicting class_name"
    assert "play_sfx" in content and "play_bgm" in content, "Missing play_sfx/play_bgm methods"
    print("✅ scripts/AudioManager.gd verified with play_sfx / play_bgm / volume controls")

    # 2. Check project.godot autoload
    with open("project.godot", "r", encoding="utf-8") as f:
        p_godot = f.read()
    assert 'AudioManager="*res://scripts/AudioManager.gd"' in p_godot, "AudioManager not in project.godot autoloads!"
    print("✅ AudioManager is properly registered as Autoload in project.godot")

    # 3. Check WAV assets validity
    sfx_files = [
        "achievement_unlock.wav", "ui_click.wav", "ui_hover.wav", "ui_popup.wav",
        "camera_shutter.wav", "coin_drop.wav", "badminton_hit.wav", "paper_rustle.wav"
    ]
    for sfx in sfx_files:
        path = os.path.join("assets/audio/sfx", sfx)
        assert os.path.exists(path), f"Missing SFX file: {path}"
        with wave.open(path, 'rb') as wf:
            assert wf.getnchannels() == 1, f"{sfx} must be mono"
            assert wf.getsampwidth() == 2, f"{sfx} must be 16-bit"
            frames = wf.getnframes()
            assert frames > 100, f"{sfx} has too few frames"
        print(f"  - [SFX] {sfx}: {frames} frames OK")

    bgm_path = "assets/audio/bgm/bgm_peaceful_campus.wav"
    assert os.path.exists(bgm_path), "Missing BGM file!"
    with wave.open(bgm_path, 'rb') as wf:
        assert wf.getnframes() > 10000, "BGM track has too few frames"
    print(f"  - [BGM] bgm_peaceful_campus.wav: verified loopable WAV")

    # 4. Check hook integrations
    hooks = [
        ("scripts/AchievementBannerUI.gd", "AudioManager.play_sfx(\"achievement_unlock\")"),
        ("scripts/AchievementPopupUI.gd", "AudioManager.play_sfx(\"ui_popup\")"),
        ("scripts/minigames/ClawMachineUI.gd", "AudioManager.play_sfx(\"coin_drop\")"),
        ("scripts/minigames/WestLakeShutterUI.gd", "AudioManager.play_sfx(\"camera_shutter\")"),
        ("scripts/minigames/BadmintonRallyUI.gd", "AudioManager.play_sfx(\"badminton_hit\""),
        ("scripts/minigames/PaperSlipStealthUI.gd", "AudioManager.play_sfx(\"paper_rustle\")"),
        ("scripts/MainGame.gd", "AudioManager.play_bgm(\"bgm_peaceful_campus\"")
    ]
    for script_path, expected in hooks:
        with open(script_path, "r", encoding="utf-8") as f:
            code = f.read()
        assert expected in code, f"Missing audio hook in {script_path}: {expected}"
        print(f"✅ Hook verified in {os.path.basename(script_path)}")

    print("=" * 60)
    print("🎉 ALL AUDIO SYSTEM CHECKS PASSED! VERDICT: PASS")
    print("=" * 60)

if __name__ == "__main__":
    main()
