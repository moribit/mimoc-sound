# Mo-Bus integration
## Method A (implemented)
GUI EXPORT Cでtone presetヘッダーを生成。`integration/tone_studio_renderer.h`と同じinclude directoryへ置く。C99の固定容量state、割当/RTOS/I2S依存なし。
```c
#include "my_preset.h"
tone_engine voice;
tone_init(&voice,tone_studio_exported_parameters());
tone_key(&voice,1);
int16_t mono=tone_next(&voice); // call once per 44.1kHz frame
```
既存audio taskでmonoを左右slotへ複製して既存I2S writerへ渡す。key(false)後releaseを生成し、無音bufferを流してから停止する。変更時はvoice.targetへ新設定を渡す。これは追加voiceとして統合し、既存Morse/起動音経路を置換しない。gainはheadroom込みの最終線形値なのでsound_settingsの音量を二重適用しない。現在の未コミットIRAM DMA callbackへ浮動小数点処理を入れない。audio task側で生成し専用bufferへ渡す設計を選ぶ。
PCとC参照の比較テストを実行する。実ESP32-S3のlibm、FMA、固定小数点DMAへの変換による誤差は実機で確認する必要がある。既存ファームウェア作業ツリーは変更していない。
## Method B (deferred)
Zig 0.17のXtensa ESP32-S3 backend/ESP-IDF ABIをこの環境では検証できない。C ABI採用前にtarget support、クロスビルド、CPU cycle、task stack、IRAM/Flash/PSRAM配置を測る。現在は方式Aを優先。BLE転送は対象外。
