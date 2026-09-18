package com.aqwapi.interfaces;

interface IScriptQuest {
    function load(questId:Int):Void;
    function isInProgress(questId:Int):Bool;
    function accept(questId:Int):Void;
    function complete(questId:Int, itemId:Int = -1):Void;
    function isCompleted(questId:Int):Bool;

    function startAuto(questString:String):Void;
    function stopAuto():Void;
    var isAutoRunning(get, never):Bool;
}
