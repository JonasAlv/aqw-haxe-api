package com.aqwapi.scripting.core;
import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;

/** Shared policy and observability surface for every orchestration core. */
class CoreContext {
    public var stopped:Bool = false;
    public var privateRooms:Bool = true;
    public var privateRoomNumber:Int = 100000;
    public var autoRecover:Bool = true;
    public var autoBoost:Bool = false;
    public var actionTimeoutMs:Int = 15000;
    public var retryLimit:Int = 3;
    public function new() {}
    public function isReady():Bool return Api.game != null && Api.game.world != null && Api.player != null;
    public function isStopped():Bool return stopped || (Api.script != null && !Api.script.isRunning);
    public function now():Float return ApiTime.now();
    public function stop(reason:String = ""):Void { stopped = true; if (Api.combat != null) Api.combat.stopCombat(); if (reason != "") ApiLogger.info("Core", "Stopped: " + reason); }
    public function resume():Void stopped = false;
    public function log(message:String):Void ApiLogger.info("Core", message);
    public function warn(message:String):Void ApiLogger.warn("Core", message);
    public function error(message:String):Void ApiLogger.error("Core", message);
    public function snapshot():Dynamic return { ready: isReady(), stopped: isStopped(), map: Api.map != null ? Api.map.name : "", cell: Api.player != null ? Api.player.cell : "", hp: Api.player != null ? Api.player.hp : 0, hpMax: Api.player != null ? Api.player.maxHp : 0, combat: Api.player != null && Api.player.isInCombat };
}
