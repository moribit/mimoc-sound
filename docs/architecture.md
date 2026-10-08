# Tone Studio architecture / Phase 0

調査対象: 空の /Users/mimoc/mimoc-sound、mimoc-ui b41759edea8d7744bb58d3a9cb6050b0d90bbe1e、Mobus_ESP_IDF fix/after-release a0a2cb3902445a3d03507a678d921b4b87d70f7e。

## Firmware
`components/drivers/audio/include/tone_waveform.hpp` は正弦波＋0.025×第二倍音を1.025で正規化。headroom 0.24、attack 3ms、release 4ms、smoothstep、signed int16 (32767倍・切捨て)。Baselineはこの独立関数の再現であり全ファームウェア既定音色ではない。
`max98357a.hpp` は44.1kHz、I2S Philips stereo、MAX98357Aへの出力とライフサイクルを担当。起動音はboot_sounds.hppのパターンからgb_synth.hppを経由。モールスは常駐tone taskから生成。音量にはrequested^1.1、保存音量のdB変換、headroom、出力補正が重なるためStudio gainは最終線形gainとして区別する。
SoftFmの保存IDは互換維持されるが現行render_tone_sampleではSynth Beep (94% square、6% pulse、1.006倍detune、polyBLEP) に対応。BrightFmには指数attack/settle、FM、air、formantがある。Sine/Triangle/Organ/SquareSoftも存在。
作業ツリーには未コミットのmorse_audio_engine.hpp、DMA変更がある。こちらは512点補間sine、固定小数点、128フレーム境界、6 DMA descriptor、RoundedSineを導入している。既定held Morseを純正弦へ変更するため、コミット済みBaselineと一致しない。既存変更は編集しない。

## mimoc-ui
src/platform/macos/window.m はAppKit、Mono1ページ配置のframebuffer、60Hz tick。固定サイズ、クリック、矢印/Return/Space入力。ドラッグ、文字入力、リサイズは不足。
Runtimeは固定容量node/animation、整数座標、column/row/stack/clip、focused_idとActionによるフォーカス/状態分離。widgetsにはbutton/toggle/progress/tuner/knob、Slider/NumericInputはない。mono1.Rendererのline/pixel/fontでグラフを実装できる。
依存はvendor/mimoc-uiの独立Git checkoutで固定する。元リポジトリは書込許可範囲外のため拡張はこのcheckoutでテスト・コミットする。

## Boundaries
Tone Engineはstd.mathのみでsample生成。UIが固定容量SPSC command queueに設定をpublishし、CoreAudio callbackがconsumeする。callbackは割当・I/O・lockなし。波形解析用sampleも固定容量SPSCでUIへ送り、FFT/描画はUI threadで実行。音声はAudioUnit DefaultOutputのmono float32、44.1kHz client format (device変換はCoreAudio)。WAVはmono little-endian PCM16。
