package com.aqwapi.interfaces;

interface IScriptMap {
    function join(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Void;
    function jump(cell:String, pad:String = "Enter"):Void;
    function getMapItem(itemId:Int):Bool;
    function snapTo(target:Dynamic):Void;
    var isLoaded(get, never):Bool;
    var name(get, never):String;
}
