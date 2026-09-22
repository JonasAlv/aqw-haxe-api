package ui.option;

#if flash
import flash.display.SimpleButton;
import flash.text.TextField;

extern class Button extends Option {
    public var button:SimpleButton;
    public var buttonTxt:TextField;

    public function new(
        key:String,
        name:String,
        info:String,
        buttonLabel:String,
        onChange:Dynamic->Void = null,
        onFrameChange:Dynamic->Void = null,
        onOverlayStateChange:Dynamic->Void = null
    );
}
#else
extern class Button extends Option {}
#end
