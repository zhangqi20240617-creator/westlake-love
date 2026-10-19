# -*- coding: utf-8 -*-
"""Generate clean, lightweight, pleasant procedural WAV audio assets using built-in wave module."""
import os
import math
import struct
import wave

SAMPLE_RATE = 22050  # 22.05 kHz is lightweight and fast

def create_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as wf:
        wf.setnchannels(1)        # Mono
        wf.setsampwidth(2)        # 16-bit
        wf.setframerate(SAMPLE_RATE)
        # Pack to 16-bit signed integers
        packed = struct.pack(f'<{len(samples)}h', *[int(max(-32767, min(32767, s))) for s in samples])
        wf.writeframes(packed)
    print(f"Generated {filename} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")

def make_chime(notes, duration_per_note=0.12, decay_rate=4.0):
    """Generate a sparkling arpeggio chime (e.g. for achievement unlock)."""
    samples = []
    total_time = len(notes) * duration_per_note + 1.2
    total_samples = int(total_time * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for idx, freq in enumerate(notes):
        start_sample = int(idx * duration_per_note * SAMPLE_RATE)
        note_len = total_samples - start_sample
        for t_idx in range(note_len):
            t = t_idx / SAMPLE_RATE
            env = math.exp(-t * decay_rate)
            # Fundamental + soft octave overtone
            sig = (math.sin(2 * math.pi * freq * t) * 0.7 +
                   math.sin(2 * math.pi * freq * 2 * t) * 0.2 +
                   math.sin(2 * math.pi * freq * 3 * t) * 0.1)
            samples[start_sample + t_idx] += sig * env * 14000.0
            
    return samples

def make_click(duration=0.04):
    """Subtle crisp UI button click."""
    count = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 90.0)
        # High-pass snappy pulse
        freq = 1200.0 - (t * 8000.0)
        val = math.sin(2 * math.pi * max(100.0, freq) * t) * env * 18000.0
        samples.append(val)
    return samples

def make_hover(duration=0.025):
    """Soft subtle tick."""
    count = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 120.0)
        val = math.sin(2 * math.pi * 880.0 * t) * env * 7000.0
        samples.append(val)
    return samples

def make_popup(duration=0.18):
    """Smooth swoosh upward pitch rise."""
    count = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        progress = i / count
        freq = 300.0 + progress * 550.0
        env = math.sin(math.pi * progress) ** 1.5
        val = math.sin(2 * math.pi * freq * t) * env * 15000.0
        samples.append(val)
    return samples

def make_shutter():
    """Dual mechanical camera click."""
    samples = []
    # Click 1 (Mirror up)
    for i in range(int(0.04 * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 70.0)
        samples.append(math.sin(2 * math.pi * 1600.0 * t) * env * 18000.0)
    # Pause
    samples.extend([0.0] * int(0.05 * SAMPLE_RATE))
    # Click 2 (Curtain close)
    for i in range(int(0.06 * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 60.0)
        samples.append(math.sin(2 * math.pi * 950.0 * t) * env * 22000.0)
    return samples

def make_coin():
    """Double bright metallic arcade coin drop."""
    samples = []
    for freq in [1480.0, 1975.0]:
        for i in range(int(0.09 * SAMPLE_RATE)):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 18.0)
            samples.append((math.sin(2 * math.pi * freq * t) * 0.8 + 
                            math.sin(2 * math.pi * freq * 2.05 * t) * 0.2) * env * 16000.0)
    return samples

def make_racket():
    """Badminton string impact."""
    count = int(0.08 * SAMPLE_RATE)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 45.0)
        freq = 650.0 - t * 3000.0
        samples.append(math.sin(2 * math.pi * max(120.0, freq) * t) * env * 24000.0)
    return samples

def make_paper_slide():
    """Soft paper rustle."""
    count = int(0.12 * SAMPLE_RATE)
    samples = []
    import random
    rng = random.Random(42)
    for i in range(count):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (i / count))
        noise = (rng.random() * 2.0 - 1.0) * 0.5
        tone = math.sin(2 * math.pi * 700.0 * t) * 0.5
        samples.append((noise + tone) * env * 9000.0)
    return samples

def make_ambient_loop(duration=16.0):
    """A soft, peaceful, looping ambient background chord progression (Cmaj9 - Am7 - Fmaj7 - G6)."""
    count = int(duration * SAMPLE_RATE)
    samples = [0.0] * count
    
    # 4 bars: 4 seconds each
    chords = [
        [261.63, 329.63, 392.00, 493.88], # Cmaj9
        [220.00, 261.63, 329.63, 392.00], # Am7
        [174.61, 220.00, 261.63, 329.63], # Fmaj7
        [196.00, 246.94, 293.66, 392.00]  # G6
    ]
    bar_samples = int(4.0 * SAMPLE_RATE)
    
    for bar_idx, chord in enumerate(chords):
        offset = bar_idx * bar_samples
        for note in chord:
            for s in range(bar_samples):
                t = s / SAMPLE_RATE
                # Smooth slow attack & slow release envelope
                env = math.sin(math.pi * (s / bar_samples)) ** 1.2
                # Warm soft sine + subtle warm octave
                val = (math.sin(2 * math.pi * note * t) * 0.75 +
                       math.sin(2 * math.pi * note * 0.5 * t) * 0.25) * env
                samples[offset + s] += val * 3500.0
                
    return samples

if __name__ == "__main__":
    out_sfx = "d:/zkgame/assets/audio/sfx"
    out_bgm = "d:/zkgame/assets/audio/bgm"
    os.makedirs(out_sfx, exist_ok=True)
    os.makedirs(out_bgm, exist_ok=True)
    
    # 1. 璀璨成就解锁 (五度和弦琶音 C5 -> E5 -> G5 -> B5 -> C6)
    create_wav(os.path.join(out_sfx, "achievement_unlock.wav"), 
               make_chime([523.25, 659.25, 783.99, 987.77, 1046.50, 1318.51], 0.09, 3.2))
    
    # 2. UI 点击
    create_wav(os.path.join(out_sfx, "ui_click.wav"), make_click())
    # 3. UI 悬停
    create_wav(os.path.join(out_sfx, "ui_hover.wav"), make_hover())
    # 4. 弹窗打开
    create_wav(os.path.join(out_sfx, "ui_popup.wav"), make_popup())
    
    # 5. 西湖快门
    create_wav(os.path.join(out_sfx, "camera_shutter.wav"), make_shutter())
    # 6. 娃娃机投币
    create_wav(os.path.join(out_sfx, "coin_drop.wav"), make_coin())
    # 7. 羽毛球击球
    create_wav(os.path.join(out_sfx, "badminton_hit.wav"), make_racket())
    # 8. 传纸条滑动
    create_wav(os.path.join(out_sfx, "paper_rustle.wav"), make_paper_slide())
    
    # 9. 校园宁静轻音乐 BGM 循环曲
    create_wav(os.path.join(out_bgm, "bgm_peaceful_campus.wav"), make_ambient_loop())
    
    print("All core audio assets synthesized successfully!")
