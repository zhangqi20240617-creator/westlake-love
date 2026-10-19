import os
import sys

def verify_club_master():
    print("Running D3 Club Master Smoke Test...")
    game_manager_path = "scripts/GameManager.gd"
    ending_screen_path = "scripts/EndingScreen.gd"

    # 1. Verify GALLERY_ITEMS in GameManager
    with open(game_manager_path, 'r', encoding='utf-8') as f:
        gm_content = f.read()

    assert 'flag_club_achievement_master' in gm_content, "GALLERY_ITEMS is missing flag_club_achievement_master"
    assert 'grad_club_master' in gm_content, "GALLERY_ITEMS is missing grad_club_master pose/bg"

    # 2. Verify EndingScreen logic
    with open(ending_screen_path, 'r', encoding='utf-8') as f:
        es_content = f.read()

    assert '_is_club_master_complete' in es_content, "Missing _is_club_master_complete function"
    assert '_play_club_master_epilogue' in es_content, "Missing _play_club_master_epilogue function"
    assert 'call_deferred' in es_content or '_play_club_master_epilogue' in es_content, "Missing defer logic for the second act"
    assert 'flag_club_achievement_master' in es_content, "Missing unlocking mechanism in _play_club_master_epilogue"
    
    print("======================")
    print("VERDICT: PASS")
    print("======================")

if __name__ == '__main__':
    verify_club_master()
