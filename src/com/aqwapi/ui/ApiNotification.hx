package com.aqwapi.ui;

#if flash
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.utils.Timer;

class ApiNotification extends Sprite {
    private static inline var DISMISS_DELAY:Float = 4000.0;
    private static inline var FADE_SPEED:Float = 0.07;
    private static inline var NOTIF_WIDTH:Float = 280.0;
    private static inline var NOTIF_HEIGHT:Float = 38.0;

    private var _messageTxt:TextField;
    private var _closeBtn:Sprite;
    private var _timer:Timer;
    private var _onDismiss:ApiNotification->Void;
    private var _fading:Bool = false;

    public var id:String;
    public var sticky:Bool;

    public function new(id:String, message:String, sticky:Bool = false) {
        super();
        this.id = id;
        this.sticky = sticky;

        // Dark Background
        this.graphics.beginFill(0x111111, 0.92);
        this.graphics.drawRect(0, 0, NOTIF_WIDTH, NOTIF_HEIGHT);
        this.graphics.endFill();

        // Blue accent bar on the left edge
        this.graphics.beginFill(0x4a9eff, 1);
        this.graphics.drawRect(0, 0, 4, NOTIF_HEIGHT);
        this.graphics.endFill();

        // Message text
        _messageTxt = new TextField();
        var fmt = new TextFormat("_sans", 12, 0xEEEEEE, true);
        fmt.align = TextFormatAlign.LEFT;
        _messageTxt.defaultTextFormat = fmt;
        _messageTxt.text = message != null ? message : "";
        _messageTxt.width = NOTIF_WIDTH - (sticky ? 16 : 36);
        _messageTxt.height = NOTIF_HEIGHT;
        _messageTxt.x = 10;
        _messageTxt.y = 0;
        _messageTxt.selectable = false;
        _messageTxt.mouseEnabled = false;
        this.addChild(_messageTxt);

        // Close button (vector drawn, no asset dependencies)
        if (!sticky) {
            _closeBtn = new Sprite();
            _closeBtn.buttonMode = true;
            _closeBtn.useHandCursor = true;

            drawCloseIcon(0x888888);

            _closeBtn.addEventListener(MouseEvent.CLICK, onCloseClick);
            _closeBtn.addEventListener(MouseEvent.MOUSE_OVER, onCloseBtnOver);
            _closeBtn.addEventListener(MouseEvent.MOUSE_OUT, onCloseBtnOut);
            this.addChild(_closeBtn);
        }

        this.addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
        this.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);

        if (!sticky) {
            _timer = new Timer(DISMISS_DELAY, 1);
            _timer.addEventListener(TimerEvent.TIMER, onDismissTimer);
            _timer.start();
        }

        this.alpha = 0;
        this.addEventListener(Event.ENTER_FRAME, onFadeIn);
    }

    private function drawCloseIcon(color:Int):Void {
        if (_closeBtn == null) return;
        _closeBtn.graphics.clear();
        var cx:Float = NOTIF_WIDTH - 16;
        var cy:Float = NOTIF_HEIGHT / 2;
        var r:Float = 5;
        _closeBtn.graphics.lineStyle(2, color, 1);
        _closeBtn.graphics.moveTo(cx - r, cy - r);
        _closeBtn.graphics.lineTo(cx + r, cy + r);
        _closeBtn.graphics.moveTo(cx + r, cy - r);
        _closeBtn.graphics.lineTo(cx - r, cy + r);

        // Invisible hit area for easier clicking
        _closeBtn.graphics.beginFill(0x000000, 0);
        _closeBtn.graphics.drawRect(cx - r - 4, cy - r - 4, (r + 4) * 2, (r + 4) * 2);
        _closeBtn.graphics.endFill();
    }

    public function setOnDismiss(fn:ApiNotification->Void):Void {
        _onDismiss = fn;
    }

    public function dismiss():Void {
        if (_fading) return;
        _fading = true;
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        this.addEventListener(Event.ENTER_FRAME, onFadeOut);
    }

    private function onMouseOver(e:MouseEvent):Void {
        if (_timer != null) _timer.stop();
    }

    private function onMouseOut(e:MouseEvent):Void {
        if (_timer != null) _timer.start();
    }

    private function onCloseBtnOver(e:MouseEvent):Void {
        drawCloseIcon(0xffffff);
    }

    private function onCloseBtnOut(e:MouseEvent):Void {
        drawCloseIcon(0x888888);
    }

    private function onCloseClick(e:MouseEvent):Void {
        e.stopPropagation();
        dismiss();
    }

    private function onDismissTimer(e:TimerEvent):Void {
        dismiss();
    }

    private function onFadeIn(e:Event):Void {
        this.alpha += FADE_SPEED * 2;
        if (this.alpha >= 1) {
            this.alpha = 1;
            this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        }
    }

    private function onFadeOut(e:Event):Void {
        this.alpha -= FADE_SPEED;
        if (this.alpha <= 0) {
            this.alpha = 0;
            this.removeEventListener(Event.ENTER_FRAME, onFadeOut);
            if (this.parent != null) this.parent.removeChild(this);
            if (_onDismiss != null) _onDismiss(this);
        }
    }

    public function destroy():Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        this.removeEventListener(Event.ENTER_FRAME, onFadeIn);
        this.removeEventListener(Event.ENTER_FRAME, onFadeOut);
        this.removeEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
        this.removeEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
        if (_closeBtn != null) {
            _closeBtn.removeEventListener(MouseEvent.CLICK, onCloseClick);
            _closeBtn.removeEventListener(MouseEvent.MOUSE_OVER, onCloseBtnOver);
            _closeBtn.removeEventListener(MouseEvent.MOUSE_OUT, onCloseBtnOut);
        }
        if (this.parent != null) this.parent.removeChild(this);
    }
}
#else
class ApiNotification {
    public var id:String;
    public var sticky:Bool;
    public function new(id:String, message:String, sticky:Bool = false) {
        this.id = id;
        this.sticky = sticky;
    }
    public function dismiss():Void {}
    public function destroy():Void {}
}
#end
