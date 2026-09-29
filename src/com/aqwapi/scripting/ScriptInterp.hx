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
            case "combat": return Api.combat;
            case "map": return Api.map;
            case "quest", "quests": return Api.quest;
            case "inventory": return Api.inventory;
            case "drop", "drops": return Api.drop;
            case "shop", "shops": return Api.shop;
            case "monster", "monsters": return Api.monster;
            case "enhancement", "enhancements": return Api.enhancement;
            case "skills": return Api.skills;
            case "aura": return Api.aura;
            case "script": return Api.script;
            case "events": return Api.dispatcher;
            case "ApiTime": return com.aqwapi.utils.ApiTime;
            case "ApiUtils": return com.aqwapi.utils.ApiUtils;
            case "ApiJson": return com.aqwapi.utils.ApiJson;
            case "ApiStorage": return com.aqwapi.utils.ApiStorage;
            case "acceptACs", "acceptACDrops": return (Api.drop != null) ? Api.drop.acceptACs : false;
        }
        if (ScriptBindings.hasShortcut(id)) {
            return ScriptBindings.getShortcut(id);
        }
        return super.resolve(id);
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) return null;
        if (o == Api) {
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
        if (o == Api && ScriptBindings.hasShortcut(f)) {
            var fn:Dynamic = ScriptBindings.getShortcut(f);
            return call(null, fn, args);
        }
        return super.fcall(o, f, args);
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
        if (f == null) return null;
        return super.call(o, f, args);
    }

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
                        if (id == "acceptACs" || id == "acceptACDrops") {
                            var v:Dynamic = expr(e2);
                            if (Api.drop != null) Api.drop.acceptACs = (v == true);
                            variables.set(id, v);
                            return v;
                        }
                    default:
                }
            default:
        }
        return super.expr(e);
    }
}
