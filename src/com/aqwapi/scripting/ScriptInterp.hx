package com.aqwapi.scripting;

import hscript.Interp;
import com.aqwapi.Api;

class ScriptInterp extends Interp {
    public function new() {
        super();
    }

    override function resolve(id:String):Dynamic {
        switch (id) {
            case "api", "bot", "Api", "Bot": return Api;
            case "player": return Api.player;
            case "stateHealth": return Api.stateHealth;
            case "combat": return Api.combat;
            case "map": return Api.map;
            case "quests": return Api.quest;
            case "inventory", "inv": return Api.inventory;
            case "bank": return Api.inventory;
            case "drop", "drops": return Api.drop;
            case "shop", "shops": return Api.shop;
            case "monster", "monsters": return Api.monster;
            case "enhancement", "enhancements": return Api.enhancement;
            case "skills": return Api.skills;
            case "aura", "auras": return Api.aura;
            case "party": return Api.party;
            case "blacklist": return Api.blacklist;
            case "script": return Api.script;
            case "core", "cores": return Api.core;
            case "coreContext": return Api.core != null ? Api.core.context : null;
            case "coreFarm": return Api.core != null ? Api.core.farm : null;
            case "coreCombat": return Api.core != null ? Api.core.combat : null;
            case "coreQuest": return Api.core != null ? Api.core.quest : null;
            case "coreStory": return Api.core != null ? Api.core.story : null;
            case "coreTravel": return Api.core != null ? Api.core.travel : null;
            case "coreTarget": return Api.core != null ? Api.core.target : null;
            case "coreRecovery": return Api.core != null ? Api.core.recovery : null;
            case "coreDrops": return Api.core != null ? Api.core.drops : null;
            case "coreInventory": return Api.core != null ? Api.core.inventory : null;
            case "coreShop": return Api.core != null ? Api.core.shop : null;
            case "coreLoadout": return Api.core != null ? Api.core.loadout : null;
            case "coreEnhancement": return Api.core != null ? Api.core.enhancement : null;
            case "coreDailies": return Api.core != null ? Api.core.dailies : null;
            case "coreBoss": return Api.core != null ? Api.core.boss : null;
            case "vhl": return Api.core != null ? Api.core.vhl : null;
            case "lr": return Api.core != null ? Api.core.lr : null;
            case "nsoD", "nsod": return Api.core != null ? Api.core.nsoD : null;
            case "blod": return Api.core != null ? Api.core.blod : null;
            case "awe": return Api.core != null ? Api.core.awe : null;
            case "forge": return Api.core != null ? Api.core.forge : null;
            case "ultras": return Api.core != null ? Api.core.ultras : null;
            case "events": return Api.dispatcher;
            case "ApiTime": return com.aqwapi.utils.ApiTime;
            case "ApiUtils": return com.aqwapi.utils.ApiUtils;
            case "ApiJson": return com.aqwapi.utils.ApiJson;
            case "ApiStorage": return com.aqwapi.utils.ApiStorage;
        }
        if (ScriptBindings.hasShortcut(id)) {
            return ScriptBindings.getShortcut(id);
        }
        return super.resolve(id);
    }

    /**
     * Identity test for the `api` / `bot` namespace.
     *
     * Left as `==` on purpose. Haxe 4 dropped `Std.refEq`, and the alternatives are worse: a
     * `SCRIPT_IDENTITY` marker on Api would make this depend on `Reflect.getProperty` returning
     * statics for a Class object, which cannot be verified without a Flash runtime and would break
     * every `api.something` access if it did not.
     */
    private static inline function isApiNamespace(o:Dynamic):Bool {
        return o != null && o == Api;
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) return null;
        if (isApiNamespace(o)) {
            // First check if it is a property or manager on Api (e.g. map, combat, player, cell, pad, isReady)
            var v:Dynamic = Reflect.getProperty(Api, f);
            if (v != null) return v;

            // Otherwise check registered shortcuts from ScriptBindings
            if (ScriptBindings.hasShortcut(f)) {
                return ScriptBindings.getShortcut(f);
            }
        }
        return super.get(o, f);
    }

    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
        if (o == null) return null;
        if (isApiNamespace(o) && ScriptBindings.hasShortcut(f)) {
            var fn:Dynamic = ScriptBindings.getShortcut(f);
            return call(null, fn, args);
        }
        return super.fcall(o, f, args);
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
        if (f == null) return null;
        return super.call(o, f, args);
    }

    /**
     * Applies the assignment form of the two drop-acceptance flags.
     *
     * `acceptAllDrops` and `acceptAcDrops` are bound as functions, so `acceptAllDrops()` already
     * works. Plain assignment would otherwise be silently dropped: `resolve()` returns the function
     * object on every read no matter what sits in `variables`, so `acceptAllDrops = true` would be a
     * no-op. `expr` is the one hook that reliably reaches an override here - hscript calls it as
     * `me.expr(...)`, so it dispatches dynamically, while `setVar` and `assign` are bound as method
     * values into `binops` and would not. Only the two binding names are accepted, so the assignment
     * form can no longer diverge from the call form as separate spellings.
     */
    override function expr(e:hscript.Expr):Dynamic {
        #if hscriptPos
        var exprDef = e.e;
        #else
        var exprDef = e;
        #end
        switch (exprDef) {
            case EBinop("=", e1, e2):
                #if hscriptPos
                var ed1 = e1.e;
                #else
                var ed1 = e1;
                #end
                switch (ed1) {
                    case EIdent(id):
                        if (id == "acceptAllDrops" || id == "acceptAcDrops") {
                            var v:Dynamic = expr(e2);
                            if (Api.drop != null) {
                                if (id == "acceptAllDrops") Api.drop.acceptAllDrops(v == true);
                                else Api.drop.acceptAcDrops(v == true);
                            }
                            return v;
                        }
                    default:
                }
            default:
        }
        return super.expr(e);
    }
}
