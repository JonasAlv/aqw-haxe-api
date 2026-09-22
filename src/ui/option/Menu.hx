package ui.option;

#if flash
import flash.display.Sprite;
import flash.display.SimpleButton;
import flash.text.TextField;

extern class Toggle extends Option {
    public function new(
        key:String,
        name:String,
        info:String,
        options:Array<String>,
        defaultOption:String = null,
        onChange:Dynamic->Void = null,
        onFrameChange:Dynamic->Void = null,
        onOverlayStateChange:Dynamic->Void = null
    );
}

extern class Divide extends Option {
    public function new();
}

extern class Menu extends Sprite {
    public var button:SimpleButton;
    public var buttonTxt:TextField;
    public var options:Dynamic;

    public function new(buttonLabel:String, options:Dynamic);
}
#else
extern class Toggle extends Option {}
extern class Divide extends Option {}
extern class Menu {}
#end
