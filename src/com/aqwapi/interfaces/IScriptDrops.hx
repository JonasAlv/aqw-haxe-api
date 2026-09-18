package com.aqwapi.interfaces;

interface IScriptDrops {
    var pendingDrops:Array<Dynamic>;
    var targetDrops:Array<Dynamic>;
    var rejectAll:Bool;
    var acceptAll:Bool;
    var acceptACs:Bool;

    function start():Void;
    function stop():Void;

    function addPendingDrop(item:Dynamic):Void;
    function removePendingDrop(index:Int):Void;
    function acceptPendingDrops(itemNames:Array<Dynamic>):Int;
    function getDrop(itemName:String):Void;
    function isTargetDrop(item:Dynamic):Bool;
}

