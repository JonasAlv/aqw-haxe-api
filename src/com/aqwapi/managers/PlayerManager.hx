package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.data.ItemDTO;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.Game;
import flash.utils.Timer;
import flash.events.TimerEvent;

class PlayerManager {

    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    private function _avatar():Dynamic {
        var g = _g();
        return (g != null && g.world != null) ? g.world.myAvatar : null;
    }

    private function _uoLeaf():Dynamic {
        var g = _g();
        if (g == null || g.world == null) return null;
        var w:Dynamic = g.world;

        // 1. world.myLeaf() method if available (built into native World.as)
        try {
            if (Reflect.isFunction(w.myLeaf)) {
                var ml = w.myLeaf();
                if (ml != null) return ml;
            }
        } catch (_:Dynamic) {}

        // 2. world.uoTree dictionary lookup
        if (w.uoTree != null) {
            var a = _avatar();
            if (a != null && a.pnm != null) {
                var pnmStr:String = Std.string(a.pnm).toLowerCase();
                try {
                    var leaf = untyped w.uoTree[pnmStr];
                    if (leaf != null) return leaf;
                } catch (_:Dynamic) {}
            }
            if (g.sfc != null && g.sfc.myUserName != null) {
                var unameStr:String = Std.string(g.sfc.myUserName).toLowerCase();
                try {
                    var leaf = untyped w.uoTree[unameStr];
                    if (leaf != null) return leaf;
                } catch (_:Dynamic) {}
            }
            if (a != null && a.objData != null && a.objData.strUsername != null) {
                var unameStr:String = Std.string(a.objData.strUsername).toLowerCase();
                try {
                    var leaf = untyped w.uoTree[unameStr];
                    if (leaf != null) return leaf;
                } catch (_:Dynamic) {}
            }
        }

        // 3. world.uoTreeLeaf(userName) method if available
        try {
            if (Reflect.isFunction(w.uoTreeLeaf) && g.sfc != null && g.sfc.myUserName != null) {
                var leaf = w.uoTreeLeaf(Std.string(g.sfc.myUserName).toLowerCase());
                if (leaf != null) return leaf;
            }
        } catch (_:Dynamic) {}

        return null;
    }

    private inline function _di(val:Dynamic, def:Int = 0):Int {
        return val != null ? Std.int(untyped val) : def;
    }

    private inline function _ds(val:Dynamic, def:String = ""):String {
        return val != null ? Std.string(val) : def;
    }

    public var state(get, never):Int;
    @:getter(state)
    public function get_state_prop():Int { return get_state(); }
    public function get_state():Int {
        var u = _uoLeaf();
        if (u != null && u.intState != null) return _di(u.intState);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intState != null) return _di(a.objData.intState);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intState != null) return _di(a.dataLeaf.intState);
        return 0;
    }

    public var hp(get, never):Int;
    @:getter(hp)
    public function get_hp_prop():Int { return get_hp(); }
    public function get_hp():Int {
        var u = _uoLeaf();
        if (u != null && u.intHP != null) return _di(u.intHP);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intHP != null) return _di(a.objData.intHP);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intHP != null) return _di(a.dataLeaf.intHP);
        return 0;
    }

    public var maxHp(get, never):Int;
    @:getter(maxHp)
    public function get_maxHp_prop():Int { return get_maxHp(); }
    public function get_maxHp():Int {
        var u = _uoLeaf();
        if (u != null && u.intHPMax != null) return _di(u.intHPMax);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intHPMax != null) return _di(a.objData.intHPMax);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intHPMax != null) return _di(a.dataLeaf.intHPMax);
        return 0;
    }

    public var hpPercent(get, never):Float;
    @:getter(hpPercent)
    public function get_hpPercent_prop():Float { return get_hpPercent(); }
    public function get_hpPercent():Float {
        var m = maxHp;
        return m > 0 ? (hp / m) * 100.0 : 0.0;
    }

    public var mp(get, never):Int;
    @:getter(mp)
    public function get_mp_prop():Int { return get_mp(); }
    public function get_mp():Int {
        var u = _uoLeaf();
        if (u != null && u.intMP != null) return _di(u.intMP);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intMP != null) return _di(a.objData.intMP);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intMP != null) return _di(a.dataLeaf.intMP);
        return 0;
    }

    public var maxMp(get, never):Int;
    @:getter(maxMp)
    public function get_maxMp_prop():Int { return get_maxMp(); }
    public function get_maxMp():Int {
        var u = _uoLeaf();
        if (u != null && u.intMPMax != null) return _di(u.intMPMax);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intMPMax != null) return _di(a.objData.intMPMax);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intMPMax != null) return _di(a.dataLeaf.intMPMax);
        return 100;
    }

    public var shield(get, never):Int;
    @:getter(shield)
    public function get_shield_prop():Int { return get_shield(); }
    public function get_shield():Int {
        var u = _uoLeaf();
        if (u != null && u.intSG != null) return _di(u.intSG);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intSG != null) return _di(a.objData.intSG);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intSG != null) return _di(a.dataLeaf.intSG);
        return 0;
    }

    public var sp(get, never):Int;
    @:getter(sp)
    public function get_sp_prop():Int { return get_sp(); }
    public function get_sp():Int {
        var u = _uoLeaf();
        if (u != null && u.intSP != null) return _di(u.intSP);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intSP != null) return _di(a.objData.intSP);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intSP != null) return _di(a.dataLeaf.intSP);
        return 0;
    }

    public var maxSp(get, never):Int;
    @:getter(maxSp)
    public function get_maxSp_prop():Int { return get_maxSp(); }
    public function get_maxSp():Int {
        var u = _uoLeaf();
        if (u != null && u.intSPMax != null) return _di(u.intSPMax);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intSPMax != null) return _di(a.objData.intSPMax);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intSPMax != null) return _di(a.dataLeaf.intSPMax, 1000);
        return 1000;
    }

    public var hasTonic(get, never):Bool;
    @:getter(hasTonic)
    public function get_hasTonic_prop():Bool { return get_hasTonic(); }
    public function get_hasTonic():Bool {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.Tonic != null) {
            var s = _ds(a.objData.Tonic);
            return s != "" && s != "null" && s != "0";
        }
        return false;
    }

    public var hasElixir(get, never):Bool;
    @:getter(hasElixir)
    public function get_hasElixir_prop():Bool { return get_hasElixir(); }
    public function get_hasElixir():Bool {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.Elixir != null) {
            var s = _ds(a.objData.Elixir);
            return s != "" && s != "null" && s != "0";
        }
        return false;
    }

    public var gold(get, never):Int;
    @:getter(gold)
    public function get_gold_prop():Int { return get_gold(); }
    public function get_gold():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intGold != null) return _di(a.objData.intGold);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intGold != null) return _di(a.dataLeaf.intGold);
        return 0;
    }

    public var username(get, never):String;
    @:getter(username)
    public function get_username_prop():String { return get_username(); }
    public function get_username():String {
        var a = _avatar();
        if (a != null) {
            if (a.pnm != null && Std.string(a.pnm) != "") return _ds(a.pnm);
            if (a.objData != null && a.objData.strUsername != null) return _ds(a.objData.strUsername);
            if (a.dataLeaf != null && a.dataLeaf.strUsername != null) return _ds(a.dataLeaf.strUsername);
        }
        var g = _g();
        if (g != null && g.sfc != null && g.sfc.myUserName != null) return _ds(g.sfc.myUserName);
        return "";
    }

    public var isAlive(get, never):Bool;
    @:getter(isAlive)
    public function get_isAlive_prop():Bool { return get_isAlive(); }
    public function get_isAlive():Bool {
        return hp > 0 && (state > 0 || state == -1);
    }

    public var isInCombat(get, never):Bool;
    @:getter(isInCombat)
    public function get_isInCombat_prop():Bool { return get_isInCombat(); }
    public function get_isInCombat():Bool {
        if (state >= 2) return true;
        var a = _avatar();
        if (a == null) return false;
        var u = _uoLeaf();
        if (u != null && _di(u.intState) >= 2) return true;
        if (a.dataLeaf != null && _di(a.dataLeaf.intState) >= 2) return true;
        try {
            if (u != null && Reflect.field(u, "intCombatOn") == 1) return true;
            if (a.dataLeaf != null && Reflect.field(a.dataLeaf, "intCombatOn") == 1) return true;
            if (Reflect.field(a, "intCombatOn") == 1) return true;
        } catch (_:Dynamic) {}
        return false;
    }

    public var cell(get, never):String;
    @:getter(cell)
    public function get_cell_prop():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strFrame) : ""; }
    public function get_cell():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strFrame) : ""; }

    public var pad(get, never):String;
    @:getter(pad)
    public function get_pad_prop():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strPad) : ""; }
    public function get_pad():String { var g = _g(); return (g != null && g.world != null) ? _ds(g.world.strPad) : ""; }

    public var level(get, never):Int;
    @:getter(level)
    public function get_level_prop():Int { return get_level(); }
    public function get_level():Int {
        var u = _uoLeaf();
        if (u != null && u.intLevel != null) return _di(u.intLevel);
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intLevel != null) return _di(a.objData.intLevel);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intLevel != null) return _di(a.dataLeaf.intLevel);
        return 1;
    }

    public var target(get, never):EntityDTO;
    @:getter(target)
    public function get_target_prop():EntityDTO {
        var a = _avatar();
        if (a != null && a.target != null) return new EntityDTO(a.target);
        return null;
    }
    public function get_target():EntityDTO {
        var a = _avatar();
        if (a != null && a.target != null) return new EntityDTO(a.target);
        return null;
    }

    public var hasTarget(get, never):Bool;
    @:getter(hasTarget)
    public function get_hasTarget_prop():Bool { return get_hasTarget(); }
    public function get_hasTarget():Bool {
        var a = _avatar();
        return (a != null && a.target != null);
    }

    public var targetName(get, never):String;
    @:getter(targetName)
    public function get_targetName_prop():String { return get_targetName(); }
    public function get_targetName():String {
        var t = target;
        return (t != null) ? t.name : "";
    }

    public function getAura(auraName:String):Dynamic {
        var a = _avatar();
        if (a == null) return null;
        var ent = new EntityDTO(a);
        return ent.getAura(auraName);
    }

    public function hasAura(auraName:String):Bool {
        return getAura(auraName) != null;
    }

    public function getAuraStacks(auraName:String):Float {
        var a = _avatar();
        if (a == null) return 0.0;
        var ent = new EntityDTO(a);
        return ent.getAuraStacks(auraName);
    }

    public function getAuraDuration(auraName:String):Float {
        var a = _avatar();
        if (a == null) return 0.0;
        var ent = new EntityDTO(a);
        return ent.getAuraDuration(auraName);
    }

    public function getAuraRemaining(auraName:String):Float {
        var a = _avatar();
        if (a == null) return 0.0;
        var ent = new EntityDTO(a);
        return ent.getAuraRemaining(auraName);
    }

    public function setSpawnPoint(cell:String = null, pad:String = null):Void {
        var g = _g();
        if (g != null && g.world != null && Reflect.hasField(g.world, "setSpawnPoint")) {
            var c = (cell != null && cell != "") ? cell : (g.world.strFrame != null ? Std.string(g.world.strFrame) : "Enter");
            var p = (pad != null && pad != "") ? pad : (g.world.strPad != null ? Std.string(g.world.strPad) : "Spawn");
            try { g.world.setSpawnPoint(c, p); } catch (e:Dynamic) {}
        }
    }

    public var className(get, never):String;
    @:getter(className)
    public function get_className_prop():String { return get_className(); }
    public function get_className():String {
        var a = _avatar();
        if (a != null) {
            if (a.objData != null && a.objData.strClassName != null) {
                var c:String = Std.string(a.objData.strClassName);
                if (c != "" && c != "null") return c;
            }
            if (a.items != null && Std.isOfType(a.items, Array)) {
                var arr:Array<Dynamic> = cast a.items;
                for (it in arr) {
                    if (it != null && (it.bEquip == 1 || it.bEquip == "1" || it.bEquip == true)) {
                        if (it.sES == "ar" || it.sType == "Class") {
                            if (it.sName != null) {
                                var s:String = Std.string(it.sName);
                                if (s != "" && s != "null") return s;
                            }
                        }
                    }
                }
            }
        }
        return "";
    }

    public var coins(get, never):Int;
    @:getter(coins)
    public function get_coins_prop():Int { return get_coins(); }
    public function get_coins():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intCoins != null) return _di(a.objData.intCoins);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intCoins != null) return _di(a.dataLeaf.intCoins);
        return 0;
    }

    public var ac(get, never):Int;
    @:getter(ac)
    public function get_ac_prop():Int { return get_coins(); }
    public inline function get_ac():Int { return get_coins(); }

    public var xp(get, never):Int;
    @:getter(xp)
    public function get_xp_prop():Int { return get_xp(); }
    public function get_xp():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intExp != null) return _di(a.objData.intExp);
        if (a != null && a.dataLeaf != null && a.dataLeaf.intExp != null) return _di(a.dataLeaf.intExp);
        return 0;
    }

    public var maxXp(get, never):Int;
    @:getter(maxXp)
    public function get_maxXp_prop():Int { return get_maxXp(); }
    public function get_maxXp():Int {
        var a = _avatar();
        if (a != null && a.objData != null && a.objData.intExpToLevel != null) return _di(a.objData.intExpToLevel);
        return 0;
    }

    public var isMember(get, never):Bool;
    @:getter(isMember)
    public function get_isMember_prop():Bool { return get_isMember(); }
    public function get_isMember():Bool {
        var a = _avatar();
        if (a != null) {
            if (a.isUpgraded != null) {
                try { return a.isUpgraded() == true; } catch (_:Dynamic) {}
            }
            if (a.objData != null && a.objData.iUpgDays != null) return _di(a.objData.iUpgDays) > 0;
        }
        return false;
    }

    public var x(get, never):Float;
    @:getter(x)
    public function get_x_prop():Float { return get_x(); }
    public function get_x():Float {
        var a = _avatar();
        return (a != null && a.pMC != null) ? a.pMC.x : 0.0;
    }

    public var y(get, never):Float;
    @:getter(y)
    public function get_y_prop():Float { return get_y(); }
    public function get_y():Float {
        var a = _avatar();
        return (a != null && a.pMC != null) ? a.pMC.y : 0.0;
    }

    public function rest():Void {
        var g = _g();
        if (g != null && g.world != null) {
            try {
                if (Reflect.hasField(g.world, "rest")) Reflect.callMethod(g.world, Reflect.field(g.world, "rest"), []);
                else if (Reflect.hasField(g.world, "sendRestRequest")) Reflect.callMethod(g.world, Reflect.field(g.world, "sendRestRequest"), []);
            } catch (_:Dynamic) {}
        }
    }

    public var isResting(get, never):Bool;
    @:getter(isResting)
    public function get_isResting_prop():Bool { return get_isResting(); }
    public function get_isResting():Bool {
        var a = _avatar();
        if (a != null && a.pMC != null) {
            try {
                if (Reflect.hasField(a.pMC, "isResting")) return Reflect.field(a.pMC, "isResting") == true;
                if (Reflect.hasField(a.pMC, "mcChar") && a.pMC.mcChar != null) {
                    var curLabel:String = Reflect.field(a.pMC.mcChar, "currentLabel");
                    if (curLabel != null && curLabel.toLowerCase().indexOf("rest") != -1) return true;
                }
            } catch (_:Dynamic) {}
        }
        return false;
    }

    public function getFactionRank(factionName:String):Int {
        var targetLower = StringTools.trim(factionName).toLowerCase();
        var a = _avatar();
        var list:Dynamic = null;
        if (a != null) {
            if (a.factions != null) list = a.factions;
            else if (a.objData != null && a.objData.factions != null) list = a.objData.factions;
            else if (a.dataLeaf != null && a.dataLeaf.factions != null) list = a.dataLeaf.factions;
        }
        if (list == null) {
            var g = _g();
            if (g != null && g.world != null && g.world.factions != null) list = g.world.factions;
        }
        if (list == null) return 0;

        var len:Int = 0;
        try { len = untyped list.length; } catch (_:Dynamic) { return 0; }
        for (i in 0...len) {
            var f = untyped list[i];
            if (f != null && f.sName != null) {
                var sName:String = Std.string(f.sName).toLowerCase();
                if (sName == targetLower) {
                    var r:Int = _di(f.iRank);
                    if (r <= 0 && f.iRep != null) {
                        var rep:Int = _di(f.iRep);
                        if (rep >= 302500) return 10;
                        if (rep >= 202500) return 9;
                        if (rep >= 129600) return 8;
                        if (rep >= 78400) return 7;
                        if (rep >= 44100) return 6;
                        if (rep >= 22500) return 5;
                        if (rep >= 10000) return 4;
                        if (rep >= 3600) return 3;
                        if (rep >= 900) return 2;
                        if (rep > 0) return 1;
                    }
                    return r;
                }
            }
        }
        return 0;
    }

    public function getFactionRep(factionName:String):Int {
        var targetLower = StringTools.trim(factionName).toLowerCase();
        var a = _avatar();
        var list:Dynamic = null;
        if (a != null) {
            if (a.factions != null) list = a.factions;
            else if (a.objData != null && a.objData.factions != null) list = a.objData.factions;
            else if (a.dataLeaf != null && a.dataLeaf.factions != null) list = a.dataLeaf.factions;
        }
        if (list == null) {
            var g = _g();
            if (g != null && g.world != null && g.world.factions != null) list = g.world.factions;
        }
        if (list == null) return 0;

        var len:Int = 0;
        try { len = untyped list.length; } catch (_:Dynamic) { return 0; }
        for (i in 0...len) {
            var f = untyped list[i];
            if (f != null && f.sName != null) {
                var sName:String = Std.string(f.sName).toLowerCase();
                if (sName == targetLower) {
                    return _di(f.iRep);
                }
            }
        }
        return 0;
    }

    // -------------------------------------------------------------------------
    // Server Boost Management (Gold, Class Points, Rep, XP)
    // -------------------------------------------------------------------------

    private var _boostTimer:Timer = null;
    private var _autoBoostGold:Bool = false;
    private var _autoBoostCp:Bool = false;
    private var _autoBoostRep:Bool = false;
    private var _autoBoostXp:Bool = false;

    private function _getBoostField(boostType:String):String {
        var t = (boostType != null) ? boostType.toLowerCase() : "";
        if (t == "gold" || t == "g") return "iBoostG";
        if (t == "cp" || t == "class" || t == "classpoints") return "iBoostCP";
        if (t == "rep" || t == "reputation") return "iBoostRep";
        if (t == "xp" || t == "exp" || t == "experience") return "iBoostXP";
        return "";
    }

    public function getBoostRemaining(boostType:String):Int {
        var a = _avatar();
        if (a == null || a.objData == null) return 0;
        var f = _getBoostField(boostType);
        if (f == "") return 0;
        var val = Reflect.field(a.objData, f);
        if (val != null) return ApiUtils.parseInt(val, 0);
        // Fallback for reputation which is sometimes iBoostR in server responses
        if (f == "iBoostRep") {
            var valR = Reflect.field(a.objData, "iBoostR");
            if (valR != null) return ApiUtils.parseInt(valR, 0);
        }
        return 0;
    }

    public function isBoostActive(boostType:String):Bool {
        return getBoostRemaining(boostType) > 0;
    }

    public function useBoost(itemNameOrId:Dynamic):Bool {
        var g = _g();
        if (g == null || g.sfc == null || g.world == null) return false;
        var idInt:Int = 0;
        if (Std.isOfType(itemNameOrId, Int)) {
            idInt = cast itemNameOrId;
        } else {
            var str = Std.string(itemNameOrId);
            idInt = ApiUtils.parseInt(str, 0);
            if (idInt <= 0 && Api.inventory != null) {
                var itm:Dynamic = Api.inventory.findItem(str);
                if (itm != null && itm.id != null) idInt = Std.int(itm.id);
            }
        }
        if (idInt <= 0) return false;
        g.sfc.sendString("%xt%zm%serverUseItem%-1%+%" + idInt + "%");
        return true;
    }

    public function findBoostItem(boostType:String):ItemDTO {
        if (Api.inventory == null) return null;
        var t = (boostType != null) ? boostType.toLowerCase() : "";
        var keyword = switch (t) {
            case "gold", "g": "gold";
            case "cp", "class", "classpoints": "class";
            case "rep", "reputation": "rep";
            case "xp", "exp", "experience": "xp";
            default: "";
        };
        if (keyword == "") return null;

        var invItems = Api.inventory.getItems();
        for (item in invItems) {
            if (item == null) continue;
            var isServerUse = (item.es == "ServerUse" || item.type == "ServerUse");
            if (isServerUse && item.name != null && item.name.toLowerCase().indexOf(keyword) != -1) {
                return item;
            }
        }
        return null;
    }

    public function checkAutoBoosts():Void {
        if (!_autoBoostGold && !_autoBoostCp && !_autoBoostRep && !_autoBoostXp) return;
        var g = _g();
        if (g == null || g.world == null || g.world.myAvatar == null) return;

        var tryBoost = function(boostType:String, enabled:Bool) {
            if (!enabled) return;
            if (isBoostActive(boostType)) return;
            var item = findBoostItem(boostType);
            if (item != null && item.itemId > 0) {
                useBoost(item.itemId);
            }
        };

        tryBoost("gold", _autoBoostGold);
        tryBoost("cp", _autoBoostCp);
        tryBoost("rep", _autoBoostRep);
        tryBoost("xp", _autoBoostXp);
    }

    public function setAutoBoost(boostType:String, enabled:Bool = true):Void {
        var t = (boostType != null) ? boostType.toLowerCase() : "";
        switch (t) {
            case "gold", "g": _autoBoostGold = enabled;
            case "cp", "class", "classpoints": _autoBoostCp = enabled;
            case "rep", "reputation": _autoBoostRep = enabled;
            case "xp", "exp", "experience": _autoBoostXp = enabled;
            case "all", "*":
                _autoBoostGold = enabled;
                _autoBoostCp = enabled;
                _autoBoostRep = enabled;
                _autoBoostXp = enabled;
        }
        if (_autoBoostGold || _autoBoostCp || _autoBoostRep || _autoBoostXp) {
            if (_boostTimer == null) {
                _boostTimer = new Timer(15000);
                _boostTimer.addEventListener(TimerEvent.TIMER, function(_) checkAutoBoosts());
                _boostTimer.start();
            }
            checkAutoBoosts();
        } else {
            if (_boostTimer != null) {
                _boostTimer.stop();
                _boostTimer = null;
            }
        }
    }

    public function getPlayersOnScreen():Array<EntityDTO> {
        var result:Array<EntityDTO> = [];
        var g = _g();
        if (g == null || g.world == null) return result;
        var world:Dynamic = g.world;

        // 1. Local player (myAvatar)
        if (world.myAvatar != null) {
            var myMc:Dynamic = null;
            try { myMc = Reflect.field(world.myAvatar, "pMC"); } catch (_:Dynamic) {}
            if (myMc != null && myMc.stage != null) {
                result.push(new EntityDTO(world.myAvatar));
            }
        }

        // 2. Other players in world.avatars (Dictionary)
        if (world.avatars != null) {
            var raw:Dynamic = world.avatars;
            var myAv = world.myAvatar;
            try {
                var keys:Array<Dynamic> = untyped __keys__(raw);
                for (k in keys) {
                    var av:Dynamic = untyped raw[k];
                    if (av == null || av == myAv) continue;
                    var mc:Dynamic = null;
                    try { mc = Reflect.field(av, "pMC"); } catch (_:Dynamic) {}
                    if (mc != null && mc.stage != null) {
                        result.push(new EntityDTO(av));
                    }
                }
            } catch (_:Dynamic) {}
        }
        return result;
    }

    public function getPlayersInRoom():Array<EntityDTO> {
        var result:Array<EntityDTO> = [];
        var g = _g();
        if (g == null || g.world == null) return result;
        var world:Dynamic = g.world;

        if (world.myAvatar != null) {
            result.push(new EntityDTO(world.myAvatar));
        }

        if (world.avatars != null) {
            var raw:Dynamic = world.avatars;
            var myAv = world.myAvatar;
            try {
                var keys:Array<Dynamic> = untyped __keys__(raw);
                for (k in keys) {
                    var av:Dynamic = untyped raw[k];
                    if (av == null || av == myAv) continue;
                    result.push(new EntityDTO(av));
                }
            } catch (_:Dynamic) {}
        }
        return result;
    }
}
