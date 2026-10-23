package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreRecovery {
    public var context:CoreContext;
    public function new(context:CoreContext) this.context = context;
    public function isAlive():Bool return Api.player != null && Api.player.isAlive;
    public function isHealthy(threshold:Float = 0.8):Bool return Api.player != null && Api.player.hpPercent >= threshold;
    public function rest():Void if (Api.player != null) Api.player.rest();
    public function ensureAlive():Bool { if (isAlive()) return true; if (Api.combat != null) Api.combat.stopCombat(); if (Api.map != null) { Api.map.autoDeathSpawn = true; Api.map.checkAutoDeathSpawn(); } return isAlive(); }
    public function maintain(hpThreshold:Float = 0.35, mpThreshold:Float = 0.2):Bool { if (!ensureAlive()) return false; if (Api.player != null && (Api.player.hpPercent < hpThreshold || (Api.player.maxMp > 0 && Api.player.mp / Api.player.maxMp < mpThreshold))) rest(); return true; }
    public function stopCombat():Void if (Api.combat != null) Api.combat.stopCombat();
}
