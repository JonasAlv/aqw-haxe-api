package ui.option;

#if flash
import flash.display.Sprite;
import flash.text.TextField;

extern class Option extends Sprite {
    public var nameTxt:TextField;
    public var infoTxt:TextField;
    public var key:String;
    public var onChange:Dynamic->Void;
    public var onFrameChange:Dynamic->Void;
    public var onOverlayStateChange:Dynamic->Void;

    public function new(
        key:String,
        name:String,
        info:String,
        visible:Bool = true,
        onChange:Dynamic->Void = null,
        onFrameChange:Dynamic->Void = null,
        onOverlayStateChange:Dynamic->Void = null
    );
}
#else
extern class Option {
    public var key:String;
}
#end
