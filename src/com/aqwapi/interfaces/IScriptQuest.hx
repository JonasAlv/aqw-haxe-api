package com.aqwapi.interfaces;

interface IScriptQuest {
    function load(questId:Int):Void;
    function loadMultiple(questIds:Array<Int>):Void;
    function isLoaded(questId:Int):Bool;
    function showQuests(questIds:String):Void;
    function isInProgress(questId:Int):Bool;
    function accept(questId:Int):Void;
    function complete(questId:Int, itemId:Int = -1):Void;
    function isCompleted(questId:Int):Bool;
    function isComplete(questId:Int):Bool;
    function isAccepted(questId:Int):Bool;
    function isAvailable(questId:Int):Bool;

    function startAuto(questString:String):Void;

    function stopAuto():Void;
    var isAutoRunning(get, never):Bool;
}
