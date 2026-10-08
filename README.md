# Mo-Bus Tone Studio
Zig 0.17 + mimoc-uiのmacOS音色調整アプリ。CoreAudioで再生しながら周波数・倍音・Attack/Release・gainを調整し、JSON/WAV/Cヘッダーへ出力します。

## Build and launch
Zig **0.17.0**、macOS Apple Silicon、Xcode Command Line Tools、Python 3が必要。
```sh
python3 tools/bootstrap.py
zig build -Doptimize=ReleaseSafe
zig build run -Doptimize=ReleaseSafe
```
Finderから開けるアプリを作る場合:
```sh
python3 tools/package_app.py
open "zig-out/Tone Studio.app"
```
GUIなしの生成・エクスポート:
```sh
./zig-out/bin/tone-render presets/warm-morse.json warm.wav warm.h
```
引数なしはBaselineのtone.wav、.zig-cache/baseline.h。LinuxではCLI/DSPのみ。GUIはmacOS専用。

## Adjust and compare
6本のSliderをdrag、右の値をclickまたはEnterで直接入力。Tab/上下でfocus、左右で微調整、SpaceでPlay/Stop、ZまたはUNDOで1段階Undo。WAVEFORMでSine/Triangle。Loop offは500ms単音。MキーまたはMORSE TESTで現在のSingle/Dot/Dash/SOS/CQ CQ/Customを再生し、パターンbuttonで切替、WPM DN/UPで5〜60WPM。Customは英数字等を入力するmacOSダイアログ。
A/Bは2つの設定を保持し、同じ再生条件を継続。定常RMSを0.12へ合わせる比較用補正を適用。比較中も元gainを保存・表示する。Baseline/LOADで比較モードを解除。
右側はPCM、envelope model、1024点FFT、Peak/RMS/clip。LATEはcallback遅延指標。MONITOR DROPは解析consumerの遅れで、file panel中も増える。音声threadはUIから独立。

## Presets and firmware
BASELINEで既存legacy soft sine、LOADでpresets/*.jsonを選択、SAVEで現在の値を保存。schema v1、範囲外や未知fieldは拒否。WAVとEXPORT Cはfile panelで保存先を選択。
生成ヘッダーと`integration/tone_studio_renderer.h`をESP-IDFのinclude directoryへコピー。`tone_init`/`tone_key`/`tone_next`をaudio producer taskから呼び、mono sampleを既存I2S形式へ渡す。既存DMA callbackには浮動小数点処理を追加しない。詳細は[Mo-Bus integration](docs/mobus-integration.md)。実機導入・性能/音響の検証は未実施。

## Verify
```sh
zig fmt --check build.zig src
zig build test
(cd vendor/mimoc-ui && zig build test check-embedded)
python3 tools/verify_pcm.py
```
既存Baselineの定常PCMとC99 rendererは現ホストで差0 LSB。Attack/Releaseのone-shot境界の差は記録済み。[検証結果](docs/validation.md)と[PCM測定値](docs/pcm-verification.json)を参照。聴覚評価は人間が行います。

## Source and history
mimoc-uiは独立Git checkout、検証済みrevisionはdeps/mimoc-ui.rev。deps/mimoc-ui.bundleを同梱し、bootstrapはネットワークなしで再構築可能。元のmimoc-uiリポジトリへ取り込むにはbundleをfetchして必要なcommitをcherry-pickする。
この作業環境ではルート.gitへの書込が拒否されたため、Phase 0〜8の履歴をtone-studio.bundleで提供。通常環境で `python3 tools/restore_history.py` を実行するとファイルを上書きせずGit履歴を復元する。既存.gitがあれば自動処理せず停止する。

技術資料: [Architecture](docs/architecture.md)、[Tone Engine](docs/tone-engine.md)、[Presets](docs/presets.md)、[Sound design](docs/sound-design.md)、[mimoc-ui changes](docs/mimoc-ui-changes.md)、[Phase status](docs/implementation-status.md)。
