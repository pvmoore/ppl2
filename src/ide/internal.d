module ide.internal;

public:

import std.stdio  : writefln;
import std.format : format;
import std.array  : array, replace;
import std.string : lastIndexOf;

import common;
import dlangui;
import ppl2 = ppl2;

import ide.actions;
import ide.ide;
import ide.project;
import ide.util;

import ide.editor.syntaxsupport;

import ide.widgets.editortab;
import ide.widgets.editorview;
import ide.widgets.infoview;
import ide.widgets.projectview;

/*
//auto b = new Button()
        //    .text("Hello world"d)
        //    .textColor(0xFF0000)
        //    .fontSize(16)
        //    .margins(Rect(10,10,10,10));
        //
        //b.click = delegate(Widget src) {
        //    window.showMessageBox("Combo clicked"d, "Selected:"d ~ b.text);
        //    //window.close();
        //    return true;
        //};
        //
        //auto t = new TextWidget(null, "Hello"d);
        //
        //auto cb = new CheckBox(null, "Check1"d);
        //auto cb2 = new CheckBox(null, "Check2"d);
        //
        //cb.checkChange = delegate(Widget src, bool checked) {
        //    window.showMessageBox("Checkbox"d, "Checked:%s"d.format(checked));
        //    return true;
        //};
        //
        //auto checks = new HorizontalLayout;
        //checks.addChildren([cb, cb2]);
        //
        //auto r = new RadioButton(null, "Radio1"d);
        //auto r2 = new RadioButton(null, "Radio2"d);
        //
        //auto itb = new ImageTextButton(null, "dialog-ok", "Check box text"d)
        //.padding(10)
        //.backgroundColor(0xffa030);
        //
        //auto radios = new HorizontalLayout;
        //radios.addChildren([r, r2]);

        //radios.focusChange = delegate(Widget src, bool b) {
        //    window.showMessageBox("focus"d, "Change:%s"d.format(b));
        //    return true;
        //};

        //auto el = new EditLine(null, "Edit me ...."d);
        //
        //el.keyEvent = delegate(Widget src, KeyEvent e) {
        //    if(e.action==KeyAction.KeyDown) {
        //        auto ctrl  = (e.flags & KeyFlag.Control)!=0;
        //        auto shift = (e.flags & KeyFlag.Shift)!=0;
        //        auto alt   = (e.flags & KeyFlag.Alt)!=0;
        //        writefln("key: %s %s", e.keyCode, ctrl);
        //    }
        //    return true;
        //};
        //
        //auto combo = new ComboBox(null, [
        //    "item value 1"d,
        //    "item value 2"d,
        //    "item value 3"d,
        //    "item value 4"d,
        //    "item value 5"d,
        //    "item value 6"d
        //]);
        //combo.selectedItemIndex = 3;
        //
        //combo.itemClick = delegate(Widget src, int index) {
        //    writefln("item clicked = %s", index);
        //    return true;
        //};
        //
        //auto vert = new VerticalLayout;
        //vert.addChildren([t, b, itb, checks, radios, el, combo]);
        //
        //vert.mouseEvent = delegate(Widget src, MouseEvent e) {
        //    auto x = e.x;
        //    auto y = e.y;
        //    auto wheel = e.wheelDelta;
        //    auto flags = e.keyFlags;
        //    auto hasMods = e.hasModifiers;
        //    auto ctrl    = (e.flags & MouseFlag.Control)!=0;
        //    auto move    = e.action==MouseAction.Move;
        //    auto left    = e.button==MouseButton.Left;
        //
        //    //if(move) writefln("mouse move: %s", e.pos);
        //    if(e.action==MouseAction.ButtonDown) writefln("button: %s", e.button);
        //    return true;
        //};
        //
        //vert.addChild(createMenu());
 */