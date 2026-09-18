package com.aqwapi.interfaces;

interface IScriptCombat {
    function attack(monsterName:String):Void;
    function approachTarget():Void;
    function cancelAutoAttack():Void;
    function cancelTarget():Void;
    function useSkill(index:Int):Bool;
    function canUseSkill(index:Int):Bool;
    function dropCombat():Void;
    function startSmart():Void;
    function startCustom(rotation:String):Void;
    function stopAuto():Void;
    function equipLoadout(type:String):Bool;
    var isAutoRunning(get, never):Bool;
    var isSmartRunning(get, never):Bool;
    var isCustomRunning(get, never):Bool;
    var mode(get, set):String;
    var farmClass(get, set):String;
    var farmMode(get, set):String;
    var soloClass(get, set):String;
    var soloMode(get, set):String;
    var bossClass(get, set):String;
    var bossMode(get, set):String;
    var dodgeClass(get, set):String;
    var dodgeMode(get, set):String;
}
