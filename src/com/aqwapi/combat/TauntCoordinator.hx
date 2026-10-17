package com.aqwapi.combat;

import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiLogger;

/**
 * Ultra Boss Taunt Coordinator.
 *
 * Coordinates taunting (Scroll of Enrage or class taunt skills) during AQW Ultra Boss
 * encounters (Ultra Warden, Ultra Tyndarius, Champion Dage, Ultra Speaker, etc.).
 *
 * Supports:
 * - Aura-triggered taunts (e.g. boss gains X stacks of an aura)
 * - Partner taunt hand-off (taunt when partner's Focus/Taunt aura on boss expires)
 * - Timed rotation loops (taunt every X milliseconds)
 * - Pre-configured presets for popular Ultra Bosses
 * - Optional Party Chat announcement for team sync
 */
class TauntCoordinator {
    private var _game:Game;

    public var enabled:Bool = false;
    public var bossName:String = null;
    public var triggerAura:String = null;
    public var triggerStacks:Int = 1;
    public var partnerTauntAura:String = "Focus";
    public var tauntIntervalMs:Float = 0;
    public var announceParty:Bool = false;
    public var announceMessage:String = "Taunted!";

    private var _lastTauntTime:Float = 0;
    private var _hadPartnerTaunt:Bool = false;
    private var _minTauntCooldownMs:Float = 5500; // Scroll of Enrage / Taunt cooldown margin

    public function new(gameRef:Game) {
        _game = gameRef;
    }

    /**
     * Configures the coordinator using a built-in Ultra Boss preset.
     */
    public function configurePreset(preset:String, ?customAnnounce:Bool):Void {
        var p = (preset != null) ? preset.toLowerCase() : "";
        enabled = true;
        announceParty = (customAnnounce != null) ? customAnnounce : false;

        switch (p) {
            case "warden", "ultra warden":
                bossName = "Ultra Warden";
                triggerAura = "Savage";
                triggerStacks = 1;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 0;
                announceMessage = "Taunted Ultra Warden!";

            case "tyndarius", "ultra tyndarius":
                bossName = "Ultra Tyndarius";
                triggerAura = null;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 6000;
                announceMessage = "Taunted Ultra Tyndarius!";

            case "dage", "champion dage":
                bossName = "Champion Dage";
                triggerAura = "Noxious Decay";
                triggerStacks = 1;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 0;
                announceMessage = "Taunted Champion Dage!";

            case "engineer", "ultra engineer":
                bossName = "Defense Drone";
                triggerAura = null;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 6000;
                announceMessage = "Taunted Drone!";

            case "speaker", "malgor", "ultra speaker":
                bossName = "The Speaker";
                triggerAura = "The Truth";
                triggerStacks = 1;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 5800;
                announceMessage = "Taunted The Speaker!";

            case "loop", "rotation", "interval":
                bossName = null;
                triggerAura = null;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 6000;
                announceMessage = "Taunted!";

            default:
                bossName = (preset != null && preset != "") ? preset : null;
                triggerAura = null;
                partnerTauntAura = "Focus";
                tauntIntervalMs = 6000;
                announceMessage = "Taunted " + (bossName != null ? bossName : "Boss") + "!";
        }

        prepareTauntItem();
        ApiLogger.info("Taunt", "Configured taunt preset: " + preset + " (Boss: " + bossName + ", Interval: " + tauntIntervalMs + "ms)");
    }

    /**
     * Custom configuration for any encounter.
     */
    public function configureCustom(?targetBoss:String, ?triggerAuraName:String, stacks:Int = 1, intervalMs:Float = 0, ?partnerAura:String = "Focus", ?partyChatMsg:String):Void {
        enabled = true;
        bossName = targetBoss;
        triggerAura = triggerAuraName;
        triggerStacks = stacks > 0 ? stacks : 1;
        tauntIntervalMs = intervalMs;
        partnerTauntAura = (partnerAura != null && partnerAura != "") ? partnerAura : "Focus";
        if (partyChatMsg != null && partyChatMsg != "") {
            announceParty = true;
            announceMessage = partyChatMsg;
        }

        prepareTauntItem();
        ApiLogger.info("Taunt", "Configured custom taunt (Boss: " + bossName + ", Trigger: " + triggerAura + ", Stacks: " + triggerStacks + ")");
    }

    public function disable():Void {
        enabled = false;
        _hadPartnerTaunt = false;
        ApiLogger.info("Taunt", "Taunt coordinator disabled.");
    }

    /**
     * Automatically equips Scroll of Enrage if owned and not already in slot 5.
     */
    public function prepareTauntItem():Void {
        if (Api.inventory != null) {
            if (Api.inventory.hasItem("Scroll of Enrage")) {
                Api.inventory.equipUsable("Scroll of Enrage");
            }
        }
    }

    /**
     * Checks conditions and fires taunt if triggered. Called on every combat engine tick.
     */
    public function checkTauntTick(now:Float):Bool {
        if (!enabled) return false;
        if (now - _lastTauntTime < _minTauntCooldownMs) return false;

        // If a specific boss is configured, ensure it is in the cell or targeted
        if (bossName != null && bossName != "") {
            var hasTarget = (Api.player != null && Api.player.hasTarget);
            var curTargetName = (Api.player != null && Api.player.targetName != null) ? Api.player.targetName.toLowerCase() : "";
            var bLower = bossName.toLowerCase();

            // If not currently targeting the boss, try to target it
            if (!hasTarget || curTargetName.indexOf(bLower) == -1) {
                if (Api.monster != null) {
                    var bEnt = Api.monster.findByName(bossName, false);
                    if (bEnt != null && bEnt.alive && bEnt.hp > 0) {
                        Api.combat.attack(bossName);
                    }
                }
            }
        }

        // Trigger condition 1: Boss gained specific trigger aura at/above stack threshold
        if (triggerAura != null && triggerAura != "" && Api.aura != null) {
            var currentStacks = Api.aura.getStacks(triggerAura, "target");
            if (currentStacks >= triggerStacks) {
                ApiLogger.debug("Taunt", "Trigger aura matched: " + triggerAura + " (Stacks: " + currentStacks + "/" + triggerStacks + ")");
                return fireTaunt(now);
            }
        }

        // Trigger condition 2: Partner's taunt / focus aura on target just expired (Hand-off)
        if (partnerTauntAura != null && partnerTauntAura != "" && Api.aura != null) {
            var partnerRem = Api.aura.getRemaining(partnerTauntAura, "target");
            if (partnerRem > 0.3) {
                _hadPartnerTaunt = true;
            } else if (_hadPartnerTaunt && partnerRem <= 0.3) {
                _hadPartnerTaunt = false;
                ApiLogger.debug("Taunt", "Partner taunt aura expired (" + partnerTauntAura + "). Executing hand-off!");
                return fireTaunt(now);
            }
        }

        // Trigger condition 3: Interval timer elapsed
        if (tauntIntervalMs > 0 && (now - _lastTauntTime >= tauntIntervalMs)) {
            return fireTaunt(now);
        }

        return false;
    }

    /**
     * Executes the taunt action (Scroll of Enrage in slot 5 or class taunt skill).
     */
    public function fireTaunt(now:Float = 0):Bool {
        if (now == 0) now = ApiTime.now();
        if (now - _lastTauntTime < _minTauntCooldownMs) return false;

        _lastTauntTime = now;
        _hadPartnerTaunt = false;

        // 1. Try casting slot 5 (Scroll of Enrage / consumable slot)
        var castSuccess = false;
        try {
            castSuccess = com.aqwapi.modules.CombatEngine.tryFireSkillPublic(5);
        } catch (_:Dynamic) {}

        // Fallback: If slot 5 failed, ensure Scroll of Enrage is equipped
        if (!castSuccess) {
            prepareTauntItem();
            try {
                castSuccess = com.aqwapi.modules.CombatEngine.tryFireSkillPublic(5);
            } catch (_:Dynamic) {}
        }

        ApiLogger.info("Taunt", "Fired Taunt" + (bossName != null ? (" on " + bossName) : "") + " (Success: " + castSuccess + ")");

        // Optional Party Chat Announcement
        if (announceParty && announceMessage != null && announceMessage != "") {
            sendPartyChat(announceMessage);
        }

        return castSuccess;
    }

    private function sendPartyChat(msg:String):Void {
        if (_game == null || _game.sfc == null || msg == null || msg == "") return;
        try {
            _game.sfc.sendString("%xt%zm%message%1%" + msg + "%party%");
        } catch (_:Dynamic) {}
    }
}
