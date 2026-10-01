package com.aqwapi.combat;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiUtils;

class SkillCaster {
    public static inline var SR_FIRED:Int    = 0;  // Fired successfully
    public static inline var SR_TIMING:Int   = 1;  // TimingBlocked: GCD or per-skill CD not ready
    public static inline var SR_RESOURCE:Int = 2;  // ResourceBlocked: not enough MP/HP, dead, or skill not found

    /**
     * Checks if the game's native GCD is active.
     */
    public static function isGcdActive(world:Dynamic):Bool {
        if (world == null) return false;
        try {
            if (world.GCD != null && world.GCD.running) return true;
        } catch (_:Dynamic) {}
        try {
            if (world.gcdTimer != null && world.gcdTimer.running) return true;
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Resolves the Action object for a given skill slot (0 = Auto Attack, 1..5 = Skills).
     */
    public static function getSkillAction(idx:Int):Dynamic {
        if (Api.game != null && Api.game.world != null) {
            var world:Dynamic = Api.game.world;
            // 1. Native actionMap
            try {
                if (world.actionMap != null && world.actionMap[idx] != null && world.getActionByRef != null) {
                    var act:Dynamic = world.getActionByRef(Std.string(world.actionMap[idx]));
                    if (act != null) return act;
                }
            } catch (_:Dynamic) {}
            // 2. Ref convention fallback ("aa" for 0, "a1".."a5" for 1..5)
            try {
                if (world.getActionByRef != null) {
                    var ref:String = (idx == 0) ? "aa" : ("a" + idx);
                    var act:Dynamic = world.getActionByRef(ref);
                    if (act != null) return act;
                }
            } catch (_:Dynamic) {}
            // 3. Active actions array fallback
            if (world.actions != null && world.actions.active != null) {
                try {
                    var actList:Array<Dynamic> = cast world.actions.active;
                    if (idx >= 0 && idx < actList.length) {
                        var act:Dynamic = actList[idx];
                        if (act != null) return act;
                    }
                } catch (_:Dynamic) {}
            }
        }
        var icon:Dynamic = getIcon(idx);
        if (icon != null && icon.actObj != null) return icon.actObj;
        return null;
    }

    public static function getIcon(idx:Int):Dynamic {
        if (Api.game == null || Api.game.ui == null || Api.game.ui.mcInterface == null || Api.game.ui.mcInterface.actBar == null) return null;
        var childName:String = (idx == 0) ? "i1" : ("i" + (idx + 1));
        return Api.game.ui.mcInterface.actBar.getChildByName(childName);
    }

    /**
     * Checks if skill `idx` can currently fire (not resource blocked or on CD).
     * Non-mutating check without executing world.testAction.
     */
    public static function canFireSkill(idx:Int):Bool {
        if (Api.game == null || Api.game.world == null || Api.game.world.myAvatar == null) return false;
        var world:Dynamic = Api.game.world;
        var avatar:Dynamic = Api.game.world.myAvatar;

        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return false;

        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return false;

        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (_:Dynamic) {}
        if (!timingReady) return false;

        var rawMp:Int = actObj.mp != null ? ApiUtils.parseInt(actObj.mp, 0) : 0;
        if (rawMp > 0 && dl != null) {
            var cmc:Float = 1.0;
            if (dl.sta != null && Reflect.field(dl.sta, "$cmc") != null) {
                cmc = ApiUtils.parseFloat(Reflect.field(dl.sta, "$cmc"), 1.0);
            }
            var effectiveMpCost:Int = Math.round(rawMp * cmc);
            var curMp:Int = (dl.intMP != null) ? Std.int(dl.intMP) : 0;
            if (curMp < effectiveMpCost) return false;
        }

        return true;
    }

    /**
     * Executes skill `idx` against the current target, applying all safety and resource guards.
     */
    public static function fireSkill(world:Dynamic, avatar:Dynamic, idx:Int):Int {
        // 1. Resolve action object
        var actObj:Dynamic = getSkillAction(idx);
        if (actObj == null || actObj.isOK == false) return SR_RESOURCE;

        // 2. Player must be alive
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return SR_RESOURCE;

        // 3. Timing guard — GCD + per-skill CD
        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (_:Dynamic) {}
        if (!timingReady) return SR_TIMING;

        // 4. Crowd control guard (stun, stone, paralyze, disable)
        if (dl != null && dl.auras != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast dl.auras;
                for (aura in auras) {
                    var cat:String = world.auraCatOf(aura);
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        return SR_TIMING;
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 5. Resource guard (MP cost scaled by class multiplier sta.$cmc)
        var rawMp:Int = actObj.mp != null ? ApiUtils.parseInt(actObj.mp, 0) : 0;
        if (rawMp > 0) {
            var curDl:Dynamic = (dl != null) ? dl : ((world != null && world.rootClass != null && world.rootClass.sfc != null && world.uoTreeLeaf != null) ? world.uoTreeLeaf(world.rootClass.sfc.myUserName) : null);
            if (curDl != null) {
                var cmc:Float = 1.0;
                if (curDl.sta != null) {
                    var rawCmc:Dynamic = Reflect.field(curDl.sta, "$cmc");
                    if (rawCmc != null) cmc = ApiUtils.parseFloat(rawCmc, 1.0);
                }
                var effectiveMpCost:Int = Math.round(rawMp * cmc);
                var curMp:Int = (curDl.intMP != null) ? Std.int(curDl.intMP) : 0;
                if (curMp < effectiveMpCost) return SR_RESOURCE;
            }
        }

        // 6. Infinite range check
        if (Api.combat != null && Api.combat.infiniteRange) {
            actObj.range = 20000;
        }

        // 7. Fire
        try {
            if (world != null && world.testAction != null) {
                world.testAction(actObj);
            }
        } catch (_:Dynamic) {
            return SR_RESOURCE;
        }
        return SR_FIRED;
    }

    /**
     * Directly fires Auto Attack (skill 0) whenever off cooldown.
     * Auto Attack is completely independent of GCD and skill rotations.
     * Hitting with Auto Attack regenerates mana, preventing classes from going OOM.
     */
    public static function fireAutoAttack(world:Dynamic, avatar:Dynamic):Bool {
        if (world == null) return false;
        var actObj:Dynamic = getSkillAction(0);
        if (actObj == null || actObj.isOK == false) {
            if (world.getAutoAttack != null) {
                try { actObj = world.getAutoAttack(); } catch (_:Dynamic) {}
            }
        }
        if (actObj == null) return false;

        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        if (dl != null && dl.intState == 0) return false;

        var timingReady:Bool = false;
        try { timingReady = (world.actionTimeCheck(actObj) == true); } catch (_:Dynamic) {}
        if (!timingReady) return false;

        if (dl != null && dl.auras != null && world.auraCatOf != null) {
            try {
                var auras:Array<Dynamic> = cast dl.auras;
                for (aura in auras) {
                    var cat:String = world.auraCatOf(aura);
                    if (cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled") {
                        return false;
                    }
                }
            } catch (_:Dynamic) {}
        }

        if (Api.combat != null && Api.combat.infiniteRange) {
            actObj.range = 20000;
        }

        try {
            if (world.testAction != null) {
                world.testAction(actObj);
                return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }
}
