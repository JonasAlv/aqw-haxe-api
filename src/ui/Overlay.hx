package ui;

#if flash
import flash.display.MovieClip;
import flash.display.SimpleButton;
import flash.display.Sprite;
import ui.option.Menu;

extern class Overlay extends MovieClip {
    public var showPanelBtn:SimpleButton;
    public var hidePanelBtn:SimpleButton;
    public var reportBugBtn:SimpleButton;
    public var updateBtn:SimpleButton;
    public var discordBtn:SimpleButton;
    public var contentMenu:Sprite;
    public var contentOptions:Sprite;
    public var notifications:Sprite;
    public var menus:Dynamic;

    public function selectMenu(menu:Menu):Void;
    public function gotoAndStop(frame:Dynamic, scene:String = null):Void;
}
#else
extern class Overlay {}
#end
