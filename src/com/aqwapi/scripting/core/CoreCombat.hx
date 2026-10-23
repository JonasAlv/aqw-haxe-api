package com.aqwapi.scripting.core;
import com.aqwapi.Api;

class CoreCombat {
    public var context:CoreContext;
    public var target:CoreTarget;
    public function new(context:CoreContext, target:CoreTarget) { this.context = context; this.target = target; }
    public function start(smart:Bool = true):Void if (Api.combat != null) Api.combat.start(smart);
    public function stop():Void if (Api.combat != null) Api.combat.stopCombat();
    public function attack(monster:Dynamic = null):Bool { if (monster != null && !target.lock(monster)) return false; if (target.current() == null && target.lockedName == null) return false; if (Api.combat != null) { Api.combat.startSmart(); return true; } return false; }
    public function useSkill(slot:Int):Bool return Api.combat != null && Api.combat.useSkill(slot);
    public function autoAttack():Void if (Api.combat != null) Api.combat.attack("*");
    public function approach():Void if (Api.combat != null) Api.combat.approachTarget();
    public function hunt(monster:Dynamic, item:Dynamic = null, quantity:Int = 1, mmid:Dynamic = null):Bool return Api.combat != null && Api.combat.hunt(monster, item, quantity, mmid);
    public function farmItem(monster:Dynamic, item:String, quantity:Int = 1, temp:Bool = false):Bool return Api.combat != null && Api.combat.farmItem(monster, item, quantity, temp);
    public function pauseOnAuras(auras:Dynamic):Void if (Api.combat != null) Api.combat.pauseOnAuras(auras);
    public function stopWhenBossShield(auraName:String):Void if (Api.combat != null) Api.combat.pauseOnAuras([auraName]);
    public function isRunning():Bool return Api.combat != null && Api.combat.isRunning();
}
