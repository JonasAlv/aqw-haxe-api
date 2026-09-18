package com.aqwapi.interfaces;

import com.aqwapi.data.EntityDTO;

interface IScriptPlayer {
    var state(get, never):Int;
    var hp(get, never):Int;
    var mp(get, never):Int;
    var maxHp(get, never):Int;
    var maxMp(get, never):Int;
    var gold(get, never):Int;
    var username(get, never):String;
    var isAlive(get, never):Bool;
    var isInCombat(get, never):Bool;
    var cell(get, never):String;
    var pad(get, never):String;
    var level(get, never):Int;
    var target(get, never):EntityDTO;
    function hasAura(auraName:String):Bool;
    function getAura(auraName:String):Dynamic;
}

