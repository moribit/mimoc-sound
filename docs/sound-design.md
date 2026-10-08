# Sound design and Morse
Baselineから周波数を選び、第二倍音を少量追加し、3/4ms envelopeから調整。gainは最終線形値。三角波の高調波aliasは残る。Attack/Releaseがdotより長いと短点が弱く聞こえるためWPMと一緒に評価する。
Singleは500ms、Dot=E、Dash=T、SOS、CQ CQ、Custom (英数字と . , ? / = +)、5〜60WPM。dot=1.2/WPM秒、dash=3単位、符号間1、文字間3、単語間7。PARISの1語50単位テストあり。標準タイミングと音色envelopeは独立、releaseはgapへ続く。Mo-Bus実キー入力の遅延/通信時刻は再現しない。
解析はUI側1024点Hann radix-2 FFT、43.07Hz/bin、0〜11kHz、-80〜0dB表示。PCM波形、model envelope、peak/RMS/clipを表示。snapshotが満杯の場合drop計数。Codexによる聴覚評価は行わず、人間が試聴して最終評価する。
