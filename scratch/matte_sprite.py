"""Chroma-key matting pipeline for AI-generated character sprites.

Usage:
  python matte_sprite.py <src.png> <dst.png> [--margin N] [--upscale N]

Keys out a GREEN-DOMINANT background via HSV space (more robust than pure RGB
differences on model-generated skin tones, which often have G > R and G > B by
small margins). Builds a true alpha mask, anti-aliases edges, inpaints the
background region (including the bottom-right watermark corner) to erase any
residue, and LANCZOS-upscales to the target size.
"""
import sys
import argparse
import numpy as np
import cv2
from PIL import Image


def matte(src, dst, margin=35, upscale=2):
    img = cv2.imread(src)  # BGR
    if img is None:
        raise SystemExit(f"cannot read {src}")
    h, w = img.shape[:2]

    # HSV chroma-key: pure green-screen sits at hue ~60 (in OpenCV's 0-179 scale,
    # so 35-75), with high saturation and reasonable value. Skin shadows may have
    # G slightly > R/B but their saturation is much lower.
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    h_ch, s_ch, v_ch = cv2.split(hsv)
    bg_mask = ((h_ch >= 35) & (h_ch <= 75) &
               (s_ch >= 100) & (v_ch >= 100)).astype(np.uint8) * 255

    # Bridge small gaps (hair wisps, anti-aliased edges).
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bg_mask = cv2.morphologyEx(bg_mask, cv2.MORPH_CLOSE, k, iterations=2)

    # Foreground alpha = NOT bg, then soften.
    fg_mask = cv2.bitwise_not(bg_mask)
    fg_mask = cv2.GaussianBlur(fg_mask, (5, 5), 0)

    # Drop tiny disconnected foreground fragments (model sometimes bakes stray
    # body parts like a bow tip floating away from the main subject). Keep only
    # the largest connected component.
    bin_fg = (fg_mask > 128).astype(np.uint8)
    num, lbl, stats, _ = cv2.connectedComponentsWithStats(bin_fg, connectivity=8)
    if num > 1:
        largest = 1 + int(stats[1:, cv2.CC_STAT_AREA].argmax())
        keep = (lbl == largest).astype(np.uint8) * 255
        # Preserve feathered edge by combining with the soft mask.
        fg_mask = np.where(keep > 0, fg_mask, 0).astype(np.uint8)

    # Inpaint background region (TELEA) to erase any residual artifacts.
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # Also force-inpaint the bottom-right watermark corner (ImageGen bakes a
    # watermark there that is NOT on chroma-key pixels, so key alone misses
    # it). Window ~22% width × 9% height, bottom-right.
    wm_w = int(w * 0.22)
    wm_h = int(h * 0.09)
    bg_mask[h - wm_h:h, w - wm_w:w] = 255

    inpainted = cv2.inpaint(img_rgb, bg_mask, 5, cv2.INPAINT_TELEA)

    rgba = np.dstack([inpainted, fg_mask])
    out = Image.fromarray(rgba, "RGBA")
    if upscale and upscale > 1:
        out = out.resize((w * upscale, h * upscale), Image.LANCZOS)

    out.save(dst)
    fg = int((fg_mask > 0).sum())
    print(f"saved {dst} size={out.size} fg={100*fg/(w*h):.1f}%")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--margin", type=int, default=35)
    ap.add_argument("--upscale", type=int, default=2)
    a = ap.parse_args()
    matte(a.src, a.dst, margin=a.margin, upscale=a.upscale)