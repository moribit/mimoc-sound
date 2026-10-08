# Implementation status
| Phase | 状況 | 内容・検証範囲 |
|---|---|---|
| 0 | 完了 | 3 repo/API/未コミット差分調査 |
| 1 | 完了 | DSP・PCM16・WAV・legacy soft sine Baseline |
| 2 | 完了 | macOS CoreAudio再生とリアルタイム変更確認 |
| 3 | 完了・取り込み待ち | 独立mimoc-ui checkoutで汎用controls/desktop canvasを実装・test・commit。元repoは書込範囲外 |
| 4 | 完了 | GUI、Slider、direct entry、キー、A/B、Undo、保存/復元 |
| 5 | 完了 | Morse、WPM、Custom、PCM/model envelope/FFT/peak/RMS/clip |
| 6 | 方式A完了 | JSON→C99用設定header、共通renderer、ホスト比較。実ファームウェアへの組込は未実施。方式B保留 |
| 7 | ホスト検証完了 | DSP/audio/UI handler/PCM/reference、mimoc-ui test、RV32 smoke。実機CH32/ESP32-S3未検証 |
| 8 | 完了 | README/技術資料/2 OS CI設定。remote CI未実行 |

## Limitations and next checks
Baselineはtone_waveform.hppのlegacy soft sineでありSoftFm/Synth Beepや未コミットRoundedSineの完全再現ではない。三角波は帯域制限なし。0ms envelopeは最低1ms。Undoは1段階。プリセット管理はfile panel、グラフはmimoc-ui mono renderer、envelopeはモデル。
GUI実操作で再生・周波数drag・入力・保存・読み込み復元を確認。自動操作file panelタイムアウトからEscapeで復帰しPRESET LOADEDを確認した。最終.appでSOS再生中の周波数変更とnative zoomによるリサイズを確認。長時間device stressは追加確認が必要。
ESP32-S3のI2S/音響、Flash中のDMA安定性、cycle/stack/RAM、48kHz device、CH32全体firmware build/実機、Linux CLI cross-buildは成功。Linux/Windows/WASM GUI、Zig C ABI Xtensaは未検証。BLE未実装。
Phase別SHAは同梱COMMIT-SHAS.txt。tone-studio.bundleとdeps/mimoc-ui.bundleで履歴を復元できる。
