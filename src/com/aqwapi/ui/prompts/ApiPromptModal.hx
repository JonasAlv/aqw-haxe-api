package com.aqwapi.ui.prompts;

#if flash
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

class ApiPromptModal {
    private static var _currentContainer:Sprite;

    public static function createDialog(w:Float, h:Float, titleText:String):Sprite {
        close();

        var container = new Sprite();
        container.graphics.beginFill(0x121212, 0.95);
        container.graphics.lineStyle(1, 0x2A2A2A);
        container.graphics.drawRoundRect(0, 0, w, h, 8, 8);
        container.graphics.endFill();

        container.x = (960 - w) / 2;
        container.y = (500 - h) / 2;

        var title = new TextField();
        var fmt = new TextFormat("_sans", 16, 0xE0E0E0, true);
        fmt.align = TextFormatAlign.CENTER;
        title.defaultTextFormat = fmt;
        title.text = titleText;
        title.width = w;
        title.y = 10;
        title.selectable = false;
        title.mouseEnabled = false;
        container.addChild(title);

        _currentContainer = container;
        return container;
    }

    public static function createButton(
        label:String,
        w:Float,
        h:Float,
        onClick:Void->Void,
        isPrimary:Bool = false
    ):Sprite {
        var btn = new Sprite();
        var bg = isPrimary ? 0x990000 : 0x1E1E1E;
        var border = isPrimary ? 0xCC0000 : 0x3A3A3A;
        var hoverBg = isPrimary ? 0xBB0000 : 0x333333;
        var hoverBorder = isPrimary ? 0xFF0000 : 0x555555;
        var textColor = isPrimary ? 0xFFFFFF : 0xCCCCCC;

        btn.graphics.beginFill(bg, 1);
        btn.graphics.lineStyle(1, border);
        btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
        btn.graphics.endFill();
        btn.buttonMode = true;

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 12, textColor, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = label;
        txt.width = w;
        txt.y = (h - 20) / 2;
        txt.selectable = false;
        txt.mouseEnabled = false;
        btn.addChild(txt);

        btn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(hoverBg, 1);
            btn.graphics.lineStyle(1, hoverBorder);
            btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
            btn.graphics.endFill();
            txt.textColor = 0xFFFFFF;
        });

        btn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
            btn.graphics.clear();
            btn.graphics.beginFill(bg, 1);
            btn.graphics.lineStyle(1, border);
            btn.graphics.drawRoundRect(0, 0, w, h, 5, 5);
            btn.graphics.endFill();
            txt.textColor = textColor;
        });

        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (onClick != null) onClick();
        });

        return btn;
    }

    public static function createInput(
        w:Float,
        h:Float,
        initialText:String = "",
        multiline:Bool = false
    ):TextField {
        var input = new TextField();
        input.type = TextFieldType.INPUT;
        input.multiline = multiline;
        input.wordWrap = multiline;
        input.defaultTextFormat = new TextFormat("_sans", multiline ? 12 : 14, 0xFFFFFF);
        input.border = true;
        input.borderColor = 0x555555;
        input.background = true;
        input.backgroundColor = 0x222222;
        input.width = w;
        input.height = h;
        input.text = initialText != null ? initialText : "";
        return input;
    }

    public static function createLabel(text:String, w:Float, size:Int = 14, isBold:Bool = false):TextField {
        var lbl = new TextField();
        lbl.defaultTextFormat = new TextFormat("_sans", size, 0xCCCCCC, isBold);
        lbl.text = text;
        lbl.width = w;
        lbl.selectable = false;
        return lbl;
    }

    public static function close():Void {
        if (_currentContainer != null && _currentContainer.parent != null) {
            _currentContainer.parent.removeChild(_currentContainer);
        }
        _currentContainer = null;
    }

    public static function show(overlay:Dynamic, container:Sprite):Void {
        if (overlay != null) {
            overlay.addChild(container);
        }
    }
}
#else
class ApiPromptModal {
    public static function close():Void {}
}
#end
