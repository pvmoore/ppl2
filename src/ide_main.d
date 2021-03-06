module ide_main;

import ide.ide;
import dlangui;

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {

    Platform.instance.uiLanguage("en");
    Platform.instance.uiTheme("theme_dark");

    currentTheme().fontSize = 14;
    currentTheme().fontFace = "Segoe UI";

    FontManager.fontGamma   = 2.0;
    FontManager.hintingMode = HintingMode.Normal;
    FontManager.minAnitialiasedFontSize = 0;

    // Fullscreen

    Window window = Platform.instance.createWindow("PPL IDE", null, WindowFlag.Resizable, 800, 600);

    //Platform.instance().defaultWindowIcon("topaz");

    auto ide = new IDE(args, window);

    window.mainWidget = ide;

    ide.ready();

    window.show();
    window.maximizeWindow();

    return Platform.instance.enterMessageLoop();
}