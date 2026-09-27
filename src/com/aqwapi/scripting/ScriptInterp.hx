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
            case "quest": return Api.quest;
            case "inventory": return Api.inventory;
            case "drop": return Api.drop;
            case "shop": return Api.shop;
            case "monster": return Api.monster;
            case "events": return Api.dispatcher;
        }
        return super.resolve(id);
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) return null;
        return super.get(o, f);
    }

    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
        if (o == null) return null;
        return super.fcall(o, f, args);
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
        if (f == null) return null;
        return super.call(o, f, args);
    }
}
