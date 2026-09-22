package ui.option;

#if flash
import flash.display.Sprite;

extern class Check extends Option {
    public var state:Bool;
    public var checkMark:Sprite;
    public var checkBackground:Sprite;

    public function new(
        key:String,
        defaultValue:Bool,
        name:String,
        info:String,
        visible:Bool,
        onChange:Dynamic->Void = null,
        onFrameChange:Dynamic->Void = null,
        onOverlayStateChange:Dynamic->Void = null
    );

    public function syncState():Void;
    public function onToggle(e:Dynamic = null):Void;
}
#else
extern class Check extends Option {
    public var state:Bool;
}
#end
