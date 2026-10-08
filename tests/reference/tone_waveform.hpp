#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace audio::tone {

inline constexpr float kHeadroom = 0.24f;
inline constexpr float kAttackMs = 3.0f;
inline constexpr float kReleaseMs = 4.0f;
inline constexpr float kSecondHarmonic = 0.025f;
inline constexpr float kTwoPi = 6.283185307179586f;

inline uint32_t envelope_samples(float duration_ms, uint32_t sample_rate) {
    return std::max<uint32_t>(
        1, static_cast<uint32_t>(sample_rate * duration_ms / 1000.0f));
}

inline float smoothstep(float position) {
    const float t = std::clamp(position, 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

inline float attack_gain(uint32_t elapsed, uint32_t sample_rate) {
    return smoothstep(static_cast<float>(elapsed) /
                      envelope_samples(kAttackMs, sample_rate));
}

inline float release_gain(uint32_t elapsed, uint32_t sample_rate) {
    const uint32_t samples = envelope_samples(kReleaseMs, sample_rate);
    return 1.0f - smoothstep(static_cast<float>(elapsed) /
                             std::max<uint32_t>(1, samples - 1));
}

inline float one_shot_gain(uint32_t elapsed, uint32_t total,
                           uint32_t sample_rate) {
    if (total == 0 || elapsed >= total) return 0.0f;
    const uint32_t remaining = total - elapsed - 1;
    return attack_gain(elapsed, sample_rate) *
           smoothstep(static_cast<float>(remaining) /
                      std::max<uint32_t>(
                          1, envelope_samples(kReleaseMs, sample_rate) - 1));
}

// Nearly a sine: a very quiet second harmonic adds warmth without FM sidebands.
inline float soft_sample(float phase) {
    return (std::sin(phase) + kSecondHarmonic * std::sin(2.0f * phase)) /
           (1.0f + kSecondHarmonic);
}

inline int16_t to_pcm(float sample) {
    return static_cast<int16_t>(std::clamp(sample, -1.0f, 1.0f) * 32767.0f);
}

}  // namespace audio::tone
