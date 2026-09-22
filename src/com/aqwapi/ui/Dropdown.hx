package com.aqwapi.ui;

#if flash
import flash.display.Shape;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;

class Dropdown extends Sprite {
    private var _options:Array<String> = [];
    private var _selectedIndex:Int = 0;
    private var _listContainer:Sprite;
    private var _listMask:Shape;
    private var _listContent:Sprite;
    private var _btn:Sprite;
    private var _btnText:TextField;
    private var _isOpen:Bool = false;
    private var _onSelect:String->Void;
    private var _width:Float;
    private var _height:Float;

    public function new(width:Float, height:Float, options:Array<String>, onSelect:String->Void = null) {
        super();
        _width = width;
        _height = height;
        _options = options != null ? options : [];
        _onSelect = onSelect;

        _btn = new Sprite();
        _btn.graphics.beginFill(0x222222, 1);
        _btn.graphics.lineStyle(1, 0x444444);
        _btn.graphics.drawRoundRect(0, 0, width, height, 4, 4);
        _btn.graphics.endFill();
        _btn.buttonMode = true;
        addChild(_btn);

        _btnText = new TextField();
        _btnText.defaultTextFormat = new TextFormat("_sans", 12, 0xFFFFFF);
        _btnText.width = width - 10;
        _btnText.height = 20;
        _btnText.x = 5;
        _btnText.y = (height - 20) / 2;
        _btnText.mouseEnabled = false;
        _btn.addChild(_btnText);

        _listContainer = new Sprite();
        _listContainer.y = height + 2;
        _listContainer.visible = false;
        addChild(_listContainer);

        var maxItems:Int = 8;
        var listHeight:Float = Math.min(_options.length, maxItems) * height;

        var listBg = new Sprite();
        listBg.graphics.beginFill(0x111111, 0.98);
        listBg.graphics.lineStyle(1, 0x444444);
        listBg.graphics.drawRoundRect(0, 0, width, listHeight, 4, 4);
        listBg.graphics.endFill();
        _listContainer.addChild(listBg);

        _listMask = new Shape();
        _listMask.graphics.beginFill(0xFF0000);
        _listMask.graphics.drawRoundRect(0, 0, width, listHeight, 4, 4);
        _listMask.graphics.endFill();
        _listContainer.addChild(_listMask);

        _listContent = new Sprite();
        _listContent.mask = _listMask;
        _listContainer.addChild(_listContent);

        populateList(width, height);

        if (_options.length > 0) {
            _btnText.text = _options[0];
        }

        _btn.addEventListener(MouseEvent.CLICK, toggleList);

        _listContainer.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):Void {
            if (_listContent.height <= listHeight) return;
            var maxScroll:Float = listHeight - _listContent.height;
            _listContent.y += e.delta * 10;
            if (_listContent.y > 0) _listContent.y = 0;
            if (_listContent.y < maxScroll) _listContent.y = maxScroll;
        });
    }

    public var options(get, set):Array<String>;
    public function get_options():Array<String> { return _options; }
    public function set_options(newOptions:Array<String>):Array<String> {
        _options = newOptions != null ? newOptions : [];
        populateList(_width, _height);
        _listContent.y = 0;
        var maxItems:Int = 8;
        var listHeight:Float = Math.min(_options.length, maxItems) * _height;

        _listMask.graphics.clear();
        _listMask.graphics.beginFill(0xFF0000);
        _listMask.graphics.drawRoundRect(0, 0, _width, listHeight, 4, 4);
        _listMask.graphics.endFill();

        var listBg:Sprite = cast _listContainer.getChildAt(0);
        listBg.graphics.clear();
        listBg.graphics.beginFill(0x111111, 0.98);
        listBg.graphics.lineStyle(1, 0x444444);
        listBg.graphics.drawRoundRect(0, 0, _width, listHeight, 4, 4);
        listBg.graphics.endFill();

        if (_options.length > 0) {
            _selectedIndex = 0;
            _btnText.text = _options[0];
        } else {
            _btnText.text = "";
        }
        return _options;
    }

    public var selectedItem(get, set):String;
    public function get_selectedItem():String {
        if (_options.length == 0 || _selectedIndex < 0 || _selectedIndex >= _options.length) return "";
        return _options[_selectedIndex];
    }
    public function set_selectedItem(val:String):String {
        var idx = _options.indexOf(val);
        if (idx != -1) {
            _selectedIndex = idx;
            _btnText.text = val;
        }
        return val;
    }

    private function populateList(w:Float, h:Float):Void {
        while (_listContent.numChildren > 0) _listContent.removeChildAt(0);
        for (i in 0..._options.length) {
            var optBtn = new Sprite();
            optBtn.graphics.beginFill(0x000000, 0);
            optBtn.graphics.drawRect(0, 0, w, h);
            optBtn.graphics.endFill();
            optBtn.y = i * h;
            optBtn.buttonMode = true;

            var optTxt = new TextField();
            optTxt.defaultTextFormat = new TextFormat("_sans", 12, 0xAAAAAA);
            optTxt.text = _options[i];
            optTxt.width = w - 10;
            optTxt.height = 20;
            optTxt.x = 5;
            optTxt.y = (h - 20) / 2;
            optTxt.mouseEnabled = false;
            optBtn.addChild(optTxt);

            optBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):Void {
                var tg:Sprite = cast e.currentTarget;
                tg.graphics.clear();
                tg.graphics.beginFill(0x333333, 1);
                tg.graphics.drawRect(0, 0, w, h);
                tg.graphics.endFill();
                (cast(tg.getChildAt(0), TextField)).textColor = 0xFFFFFF;
            });
            optBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):Void {
                var tg:Sprite = cast e.currentTarget;
                tg.graphics.clear();
                tg.graphics.beginFill(0x000000, 0);
                tg.graphics.drawRect(0, 0, w, h);
                tg.graphics.endFill();
                (cast(tg.getChildAt(0), TextField)).textColor = 0xAAAAAA;
            });
            optBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
                var clickedTarget:Sprite = cast e.currentTarget;
                var clickIndex:Int = _listContent.getChildIndex(clickedTarget);
                _selectedIndex = clickIndex;
                _btnText.text = _options[clickIndex];
                toggleList(null);
                if (_onSelect != null) _onSelect(_options[clickIndex]);
            });
            _listContent.addChild(optBtn);
        }
    }

    private function toggleList(e:MouseEvent):Void {
        _isOpen = !_isOpen;
        _listContainer.visible = _isOpen;
        if (_isOpen && parent != null) {
            parent.setChildIndex(this, parent.numChildren - 1);
        }
    }
}
#else
class Dropdown {
    public function new(width:Float, height:Float, options:Array<String>, onSelect:String->Void = null) {}
    public var selectedItem:String = "";
}
#end
