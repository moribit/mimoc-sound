# mimoc-ui changes / Phase 3
独立checkout vendor/mimoc-uiにcontrols.zig (Slider、NumericInput、selectNext) とmacOS canvas.mを追加。整数座標、割当不要、既存mono1 rendererを使用。既存window.m ABIとnode/runtimeを変更しない。グラフは既存line/pixel、選択はbuttonを使う。v2 canvasはdrag/up、ASCII文字、Tab/矢印、ウィンドウresize (logical座標へ変換) を提供。
zig build test check-embedded成功。check-embeddedはRV32 freestanding smokeであり実CH32基板へのflash検証ではない。元の /Users/mimoc/mimoc-uiは書込制約のため変更なし。独立checkoutのコミットはGit bundleで提供する。
