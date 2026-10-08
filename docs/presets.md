# Presets / v1
SAVE/LOADはmacOSのfile panel。JSON schema_version=1、name (1〜128 byte)、parameters。省略値はBaseline、unknown field/enum、不正型、範囲外、非有限値、未対応versionを拒否。frequency_hz 200〜1200、harmonic_2 0〜0.2、harmonic_3 0〜0.15、attack_ms 0〜50、release_ms 0〜100、gain 0〜1、waveform sine/triangle。8KB以上のJSONは読み込まない。
A/Bはそれぞれの設定を保持し、同じtransportを継続、比較モードでは4096sampleの定常RMS推定から0.12 RMSへ音量を合わせる (gain上限1、元gain=0は無音)。表示/保存するgainはオリジナル。Baseline/Loadで比較モード解除。エンベロープでの音量差は残る。Undoは直前の操作1段階。ドラッグ開始時の値を保存する。
EXPORT Cはv1ヘッダー、WAVは500ms tone+500ms release/silenceのmono PCM16 44.1kHz。出力は比較音量補正ではなく保存された設定を使う。
