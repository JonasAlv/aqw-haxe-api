package com.aqwapi.combat;

import com.aqwapi.utils.ApiUtils;

/**
 * Pure readers over the client's entity tree.
 *
 * Deliberately free of any `com.aqwapi.Api` / `AuraManager` dependency so the rule layer can be
 * compiled and exercised off-Flash. Everything here is a read of a `Dynamic` snapshot - no
 * mutation, no allocation, no client coupling beyond field names.
 */
class EntityProbe {

    public static function getPlayerStats(world:Dynamic, avatar:Dynamic):Dynamic {
        try {
            if (world.uoTreeLeaf != null && avatar.pnm != null) return world.uoTreeLeaf(avatar.pnm);
        } catch (_:Dynamic) {}
        return null;
    }

    /**
     * Reads a stat, preferring the avatar's own dataLeaf and falling back to the stats tree.
     * Returns 0 for an unknown stat name.
     */
    public static function getStat(pStats:Dynamic, avatar:Dynamic, stat:String):Float {
        var dl:Dynamic = (avatar != null) ? avatar.dataLeaf : null;
        switch (stat) {
            case "HP":    return (dl != null && dl.intHP != null) ? dl.intHP : ((pStats != null && pStats.intHP != null) ? pStats.intHP : 0);
            case "MaxHP": return (dl != null && dl.intHPMax != null && dl.intHPMax > 0) ? dl.intHPMax : ((pStats != null && pStats.intHPMax != null && pStats.intHPMax > 0) ? pStats.intHPMax : 100);
            case "MP":    return (dl != null && dl.intMP != null) ? dl.intMP : ((pStats != null && pStats.intMP != null) ? pStats.intMP : 0);
            case "MaxMP": return (dl != null && dl.intMPMax != null && dl.intMPMax > 0) ? dl.intMPMax : ((pStats != null && pStats.intMPMax != null && pStats.intMPMax > 0) ? pStats.intMPMax : 100);
        }
        return 0;
    }

    /**
     * Reads target HP off dataLeaf, then objData. Returns false when neither carries an intHP,
     * which is the legacy "no usable target HP" result.
     */
    public static function targetHp(ctx:SignalContext):Bool {
        var target = ctx.target;
        if (target == null) return false;
        var dl:Dynamic = null;
        try {
            dl = target.dataLeaf;
        } catch (_:Dynamic) {}
        if (dl != null && dl.intHP != null) {
            ctx.targetHpValue = parse(dl.intHP);
            ctx.targetHpMax = (dl.intHPMax != null && dl.intHPMax > 0) ? parse(dl.intHPMax) : 100;
            return true;
        }
        var od:Dynamic = null;
        try {
            od = target.objData;
        } catch (_:Dynamic) {}
        if (od != null && od.intHP != null) {
            ctx.targetHpValue = parse(od.intHP);
            ctx.targetHpMax = (od.intHPMax != null && od.intHPMax > 0) ? parse(od.intHPMax) : 100;
            return true;
        }
        return false;
    }

    /**
     * True when the given entity is hard crowd-controlled.
     *
     * Reads aura CATEGORIES via the client's own `auraCatOf`, which normalises the server-sent
     * `aura.cat` field. The five literals below are the complete set the client itself compares
     * against when deciding whether an action is blocked.
     */
    public static function hasHardCc(entity:Dynamic, world:Dynamic):Bool {
        if (entity == null || world == null || world.auraCatOf == null) return false;
        var auras:Dynamic = null;
        try {
            if (entity.dataLeaf != null) auras = entity.dataLeaf.auras;
        } catch (_:Dynamic) {}
        if (auras == null) return false;
        try {
            if (Std.isOfType(auras, Array)) {
                for (aura in (cast auras : Array<Dynamic>)) {
                    if (hasCcCategory(aura, world)) return true;
                }
            } else {
                for (k in Reflect.fields(auras)) {
                    if (hasCcCategory(Reflect.field(auras, k), world)) return true;
                }
            }
        } catch (_:Dynamic) {}
        return false;
    }

    static function hasCcCategory(aura:Dynamic, world:Dynamic):Bool {
        if (aura == null) return false;
        try {
            var cat:String = world.auraCatOf(aura);
            if (cat == null || cat == "") return false;
            cat = cat.toLowerCase();
            return cat == "stun" || cat == "stone" || cat == "paralyze" || cat == "disable" || cat == "disabled";
        } catch (_:Dynamic) {}
        return false;
    }

    /** MonMapID of the current target, from dataLeaf then objData. Null when unavailable. */
    public static function targetMMID(target:Dynamic):String {
        if (target == null) return null;
        try {
            if (target.dataLeaf != null && target.dataLeaf.MonMapID != null) return Std.string(target.dataLeaf.MonMapID);
            if (target.objData != null && target.objData.MonMapID != null) return Std.string(target.objData.MonMapID);
        } catch (_:Dynamic) {}
        return null;
    }

    static inline function parse(v:Dynamic):Float return ApiUtils.parseFloat(v, 0);
}