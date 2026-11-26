#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace brum_shaders {

inline int channelDiffSum(uint32_t a, uint32_t b) {
  const int dr = static_cast<int>((a >> 16) & 0xffu) - static_cast<int>((b >> 16) & 0xffu);
  const int dg = static_cast<int>((a >> 8) & 0xffu) - static_cast<int>((b >> 8) & 0xffu);
  const int db = static_cast<int>(a & 0xffu) - static_cast<int>(b & 0xffu);
  return std::abs(dr) + std::abs(dg) + std::abs(db);
}

inline uint32_t blend50(uint32_t a, uint32_t b) {
  const uint32_t r = (((a >> 16) & 0xffu) + ((b >> 16) & 0xffu) + 1u) >> 1;
  const uint32_t g = (((a >> 8) & 0xffu) + ((b >> 8) & 0xffu) + 1u) >> 1;
  const uint32_t bl = ((a & 0xffu) + (b & 0xffu) + 1u) >> 1;
  return 0xff000000u | (r << 16) | (g << 8) | bl;
}

inline void applyCasSharpen(uint32_t *pixels, int width, int height, int strengthPct = 70) {
  if (!pixels || width <= 2 || height <= 2) return;
  const std::size_t count = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
  std::vector<uint32_t> src(pixels, pixels + count);
  const int strength = std::clamp(strengthPct, 0, 120);

  for (int y = 0; y < height; ++y) {
    const int yUp = (y > 0) ? (y - 1) : 0;
    const int yDn = (y + 1 < height) ? (y + 1) : (height - 1);
    const std::size_t row = static_cast<std::size_t>(y) * width;
    const std::size_t rowUp = static_cast<std::size_t>(yUp) * width;
    const std::size_t rowDn = static_cast<std::size_t>(yDn) * width;

    for (int x = 0; x < width; ++x) {
      const int xLt = (x > 0) ? (x - 1) : 0;
      const int xRt = (x + 1 < width) ? (x + 1) : (width - 1);

      const uint32_t c = src[row + x];
      const uint32_t n = src[rowUp + x];
      const uint32_t s = src[rowDn + x];
      const uint32_t w = src[row + xLt];
      const uint32_t e = src[row + xRt];

      if (c == n && c == s && c == w && c == e) continue;

      auto sharpenChan = [&](unsigned shift) -> uint32_t {
        const int vc = static_cast<int>((c >> shift) & 0xffu);
        const int vn = static_cast<int>((n >> shift) & 0xffu);
        const int vs = static_cast<int>((s >> shift) & 0xffu);
        const int vw = static_cast<int>((w >> shift) & 0xffu);
        const int ve = static_cast<int>((e >> shift) & 0xffu);

        const int mn = std::min({vc, vn, vs, vw, ve});
        const int mx = std::max({vc, vn, vs, vw, ve});
        const int avg = (vn + vs + vw + ve) >> 2;
        const int cand = vc + (((vc - avg) * strength) / 100);
        return static_cast<uint32_t>(std::clamp(cand, mn, mx));
      };

      const uint32_t r = sharpenChan(16);
      const uint32_t g = sharpenChan(8);
      const uint32_t b = sharpenChan(0);
      pixels[row + x] = 0xff000000u | (r << 16) | (g << 8) | b;
    }
  }
}

inline void applyEdgeUpscale2x(const uint32_t *src, int srcW, int srcH,
                               std::vector<uint32_t> &dst, int &dstW, int &dstH) {
  if (!src || srcW <= 0 || srcH <= 0) {
    dstW = 0;
    dstH = 0;
    dst.clear();
    return;
  }
  if (srcW > 640 || srcH > 480) {
    dstW = srcW;
    dstH = srcH;
    dst.assign(src, src + static_cast<std::size_t>(srcW) * srcH);
    applyCasSharpen(dst.data(), dstW, dstH, 65);
    return;
  }

  dstW = srcW * 2;
  dstH = srcH * 2;
  dst.resize(static_cast<std::size_t>(dstW) * static_cast<std::size_t>(dstH));

  constexpr int kTol = 12;
  for (int y = 0; y < srcH; ++y) {
    const int yUp = (y > 0) ? (y - 1) : 0;
    const int yDn = (y + 1 < srcH) ? (y + 1) : (srcH - 1);
    const std::size_t row = static_cast<std::size_t>(y) * srcW;
    const std::size_t rowUp = static_cast<std::size_t>(yUp) * srcW;
    const std::size_t rowDn = static_cast<std::size_t>(yDn) * srcW;
    const std::size_t outTop = static_cast<std::size_t>(y * 2) * dstW;
    const std::size_t outBot = outTop + dstW;

    for (int x = 0; x < srcW; ++x) {
      const int xLt = (x > 0) ? (x - 1) : 0;
      const int xRt = (x + 1 < srcW) ? (x + 1) : (srcW - 1);

      const uint32_t P = src[row + x] | 0xff000000u;
      const uint32_t A = src[rowUp + x] | 0xff000000u;
      const uint32_t D = src[rowDn + x] | 0xff000000u;
      const uint32_t C = src[row + xLt] | 0xff000000u;
      const uint32_t B = src[row + xRt] | 0xff000000u;

      uint32_t p0 = P, p1 = P, p2 = P, p3 = P;
      const bool diffAB = channelDiffSum(A, B) > kTol;
      const bool diffCD = channelDiffSum(C, D) > kTol;
      const bool diffAD = channelDiffSum(A, D) > kTol;
      const bool diffCB = channelDiffSum(C, B) > kTol;

      if (diffAD && diffCB) {
        if (channelDiffSum(C, A) <= kTol && channelDiffSum(C, D) > kTol && diffAB) {
          p0 = (C == A) ? A : blend50(C, A);
        }
        if (channelDiffSum(A, B) <= kTol && channelDiffSum(A, C) > kTol && channelDiffSum(B, D) > kTol) {
          p1 = (A == B) ? B : blend50(A, B);
        }
        if (channelDiffSum(D, C) <= kTol && channelDiffSum(D, B) > kTol && channelDiffSum(C, A) > kTol) {
          p2 = (D == C) ? C : blend50(D, C);
        }
        if (channelDiffSum(B, D) <= kTol && diffAB && diffCD) {
          p3 = (B == D) ? D : blend50(B, D);
        }
      }

      const std::size_t ox = static_cast<std::size_t>(x) * 2;
      dst[outTop + ox] = p0;
      dst[outTop + ox + 1] = p1;
      dst[outBot + ox] = p2;
      dst[outBot + ox + 1] = p3;
    }
  }
}

inline void applySharpBilinearPrescale(const uint32_t *src, int srcW, int srcH,
                                       std::vector<uint32_t> &dst, int &dstW, int &dstH) {
  if (!src || srcW <= 0 || srcH <= 0) {
    dstW = 0;
    dstH = 0;
    dst.clear();
    return;
  }
  if (srcW > 640 || srcH > 480) {
    dstW = srcW;
    dstH = srcH;
    dst.assign(src, src + static_cast<std::size_t>(srcW) * srcH);
    applyCasSharpen(dst.data(), dstW, dstH, 35);
    return;
  }
  dstW = srcW * 2;
  dstH = srcH * 2;
  dst.resize(static_cast<std::size_t>(dstW) * static_cast<std::size_t>(dstH));
  for (int y = 0; y < srcH; ++y) {
    const std::size_t sRow = static_cast<std::size_t>(y) * srcW;
    const std::size_t dTop = static_cast<std::size_t>(y * 2) * dstW;
    const std::size_t dBot = dTop + dstW;
    for (int x = 0; x < srcW; ++x) {
      const uint32_t px = src[sRow + x] | 0xff000000u;
      const std::size_t ox = static_cast<std::size_t>(x) * 2;
      dst[dTop + ox] = px;
      dst[dTop + ox + 1] = px;
      dst[dBot + ox] = px;
      dst[dBot + ox + 1] = px;
    }
  }
}

} // namespace brum_shaders
