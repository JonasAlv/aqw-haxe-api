package;

/**
 * Duck-typed stand-in for `com.aqwapi.managers.AuraManager`.
 *
 * Mirrors the real resolver's shape - look the aura up on `self` or `target`, skip expired
 * entries, take the largest matching value - so the aura rules are exercised against the same
 * entity fixtures the target fixtures already provide. Keeping `auraTarget` as a genuinely
 * discriminating axis is the point: `aura(self:X)` and `aura(target:X)` must resolve to different
 * stacks or the test proves nothing.
 */
class MockAura {
    public function new() {}

    public function getStacks(name:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Float {
        var maxVal = 0.0;
        for (a in resolve(name, target, avatar, targetObj)) {
            var val:Float = (a.val != null) ? a.val : 1.0;
            if (val > maxVal) maxVal = val;
        }
        return maxVal;
    }

    public function getRemaining(name:String, target:String = "player", ?world:Dynamic, ?avatar:Dynamic, ?targetObj:Dynamic):Float {
        var maxRemaining = 0.0;
        for (a in resolve(name, target, avatar, targetObj)) {
            var dur:Float = (a.dur != null) ? a.dur : 0.0;
            if (dur <= 0) continue;
            // ts == 0 means "no timestamp recorded"; the real manager treats that as
            // "the full duration remains". Anything else is reduced by elapsed time, which the
            // fixture keeps at zero so results stay deterministic.
            if (dur > maxRemaining) maxRemaining = dur;
        }
        return maxRemaining > 0 ? maxRemaining : 0.0;
    }

    function resolve(name:String, target:String, ?avatar:Dynamic, ?targetObj:Dynamic):Array<Dynamic> {
        var out:Array<Dynamic> = [];
        if (name == null || name == "") return out;
        var entity:Dynamic = null;
        if (target != null && target.toLowerCase() == "target") entity = targetObj;
        else entity = avatar;
        if (entity == null) return out;
        var auras:Dynamic = null;
        try {
            if (entity.dataLeaf != null) auras = entity.dataLeaf.auras;
        } catch (_:Dynamic) {}
        if (auras == null) return out;
        if (Std.isOfType(auras, Array)) {
            for (a in (cast auras : Array<Dynamic>)) collect(out, a, name);
        } else {
            for (k in Reflect.fields(auras)) collect(out, Reflect.field(auras, k), name);
        }
        return out;
    }

    static function collect(out:Array<Dynamic>, aura:Dynamic, search:String):Void {
        if (aura == null) return;
        if (aura.e == 1 || aura.e == "1" || aura.e == true) return;
        var name:String = (aura.nam != null) ? Std.string(aura.nam) : ((aura.name != null) ? Std.string(aura.name) : "");
        if (name == "" || norm(name) != norm(search)) return;
        out.push(aura);
    }

    /** Matches the real manager's whitespace-insensitive, case-insensitive normalisation. */
    static function norm(s:String):String {
        return StringTools.replace(s.toLowerCase(), " ", "");
    }
}