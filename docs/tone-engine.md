# Tone Engine
44.1kHz、f32位相は周期ごとwrap、正弦/三角＋第2/3倍音を和で正規化。最大gain 1でも振幅1以下。最終PCM16は32767倍の切捨て。5ms exponential smoothing、波形変更もcrossfade。smoothstep attack/releaseは現在のenvelopeから開始し最低1msのde-clickを適用。Engineは固定サイズでOS/UI依存なし。
Baselineはtone_waveform.hppのsoft_sampleとheadroom 0.24、3/4msを再現。全体音量変換と未コミットDMA整数実装は別物。ゼロms設定は安全性のため1msへ、三角波は帯域制限なしのため高域aliasに注意。
