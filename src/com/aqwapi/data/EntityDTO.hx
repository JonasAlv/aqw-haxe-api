package com.aqwapi.data;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;

class EntityDTO {
    public var id:String = "";
    public var name:String = "";
    public var cell:String = "";
    public var hp:Int = 0;
    public var maxHp:Int = 0;
    public var mp:Int = 0;
    public var state:Int = 0;
    public var mapId:String = "";
    public var monsterId:String = "";
    public var raw:Dynamic;

    public var isMonster:Bool = false;
    public var isPlayer:Bool = false;
    public var isMyAvatar:Bool = false;
    public var race:String = "";
    public var guild:String = "";
    public var isAfk:Bool = false;
    public var level:Int = 1;

    public var pMC(get, never):Dynamic;
    @:getter(pMC)
    public function get_pMC_prop():Dynamic { return get_pMC(); }
    public function get_pMC():Dynamic {
        if (raw == null) return null;
        try {
            var mc:Dynamic = _sf(raw, "pMC");
            if (mc != null) return mc;
        } catch (_:Dynamic) {}
        return null;
    }

    public var isCurrentTarget(get, never):Bool;
    @:getter(isCurrentTarget)
    public function get_isCurrentTarget_prop():Bool { return get_isCurrentTarget(); }
    public function get_isCurrentTarget():Bool {
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.world != null && g.world.myAvatar != null) {
                var tgt:Dynamic = g.world.myAvatar.target;
                if (tgt == null) return false;
                return (tgt == this.raw);
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public var isHostilePvP(get, never):Bool;
    @:getter(isHostilePvP)
    public function get_isHostilePvP_prop():Bool { return get_isHostilePvP(); }
    public function get_isHostilePvP():Bool {
        if (this.isMonster) return true;
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.world != null && g.world.bPvP == true && g.world.myAvatar != null) {
                var myDl = _sf(g.world.myAvatar, "dataLeaf");
                var myTeam = (myDl != null) ? _sf(myDl, "pvpTeam") : null;
                var theirDl = _sf(this.raw, "dataLeaf");
                var theirTeam = (theirDl != null) ? _sf(theirDl, "pvpTeam") : null;
                if (myTeam != null && theirTeam != null && myTeam != theirTeam) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    public function select():Void {
        try {
            var g:Dynamic = Api.game;
            if (g != null && g.world != null && this.raw != null) {
                if (Reflect.isFunction(g.world.setTarget)) {
                    g.world.setTarget(this.raw);
                }
            }
        } catch (_:Dynamic) {}
    }

    public function hideNativeName():Void {
        var mc = this.pMC;
        if (mc == null) return;
        try {
            var pn = _sf(mc, "pname");
            if (pn != null && pn.visible == true) pn.visible = false;
        } catch (_:Dynamic) {}
        try {
            var hb = _sf(mc, "hpBar");
            if (hb != null && hb.visible == true) hb.visible = false;
        } catch (_:Dynamic) {}
    }

    public function showNativeName():Void {
        var mc = this.pMC;
        if (mc == null) return;
        try {
            var pn = _sf(mc, "pname");
            if (pn != null && pn.visible == false) pn.visible = true;
        } catch (_:Dynamic) {}
        try {
            var hb = _sf(mc, "hpBar");
            if (hb != null) {
                var g:Dynamic = Api.game;
                var show:Bool = (g != null && g.world != null && g.world.showHPBar == true);
                hb.visible = show;
            }
        } catch (_:Dynamic) {}
    }

    private static inline function _sf(obj:Dynamic, field:String):Dynamic {
        if (obj == null) return null;
        return Reflect.field(obj, field);
    }

    private static inline function _di(val:Dynamic, def:Int = 0):Int {
        return val != null ? Std.int(untyped val) : def;
    }

    private static inline function _ds(val:Dynamic, def:String = ""):String {
        return val != null ? Std.string(val) : def;
    }

    public var alive(get, never):Bool;
    @:getter(alive)
    public function get_alive_prop():Bool { return get_alive(); }
    public function get_alive():Bool {
        if (hp <= 0) return false;
        if (state == 0 && raw != null) {
            try {
                var dl:Dynamic = _sf(raw, "dataLeaf");
                if (dl != null) {
                    var st:Dynamic = _sf(dl, "intState");
                    if (st != null && _di(st) == 0) return false;
                }
            } catch (e:Dynamic) {}
        }
        return true;
    }

    public var isAlive(get, never):Bool;
    @:getter(isAlive)
    public function get_isAlive_prop():Bool { return get_alive(); }
    public function get_isAlive():Bool { return get_alive(); }

    public var hasGraphic(get, never):Bool;
    @:getter(hasGraphic)
    public function get_hasGraphic_prop():Bool { return get_hasGraphic(); }
    public function get_hasGraphic():Bool {
        if (raw == null) return false;
        try {
            var mc:Dynamic = _sf(raw, "pMC");
            return mc != null;
        } catch (e:Dynamic) { return false; }
    }

    public var x(get, never):Float;
    @:getter(x)
    public function get_x_prop():Float { return get_x(); }
    public function get_x():Float {
        if (raw == null) return 0.0;
        try {
            var mc:Dynamic = _sf(raw, "pMC");
            if (mc != null && mc.x != null) return ApiUtils.parseFloat(mc.x, 0.0);
            if (raw.x != null) return ApiUtils.parseFloat(raw.x, 0.0);
        } catch (_:Dynamic) {}
        return 0.0;
    }

    public var y(get, never):Float;
    @:getter(y)
    public function get_y_prop():Float { return get_y(); }
    public function get_y():Float {
        if (raw == null) return 0.0;
        try {
            var mc:Dynamic = _sf(raw, "pMC");
            if (mc != null && mc.y != null) return ApiUtils.parseFloat(mc.y, 0.0);
            if (raw.y != null) return ApiUtils.parseFloat(raw.y, 0.0);
        } catch (_:Dynamic) {}
        return 0.0;
    }

    public function new(rawData:Dynamic) {
        if (rawData == null) return;
        this.raw = rawData;

        var objData:Dynamic = null;
        var dataLeaf:Dynamic = null;
        var pMC:Dynamic = null;

        try { objData = _sf(rawData, "objData"); } catch(e:Dynamic) {}
        try { dataLeaf = _sf(rawData, "dataLeaf"); } catch(e:Dynamic) {}
        try { pMC = _sf(rawData, "pMC"); } catch(e:Dynamic) {}

        // Name resolution
        var n:Dynamic = null;
        if (objData != null) {
            var smn = _sf(objData, "strMonName");
            var sun = _sf(objData, "strUsername");
            n = (smn != null) ? smn : sun;
        }
        if (n == null && dataLeaf != null) {
            var smn = _sf(dataLeaf, "strMonName");
            var sun = _sf(dataLeaf, "strUsername");
            n = (smn != null) ? smn : sun;
        }
        if (n == null) {
            var smn = _sf(rawData, "strMonName");
            var sun = _sf(rawData, "strUsername");
            n = (smn != null) ? smn : sun;
        }
        this.name = _ds(n);

        // HP resolution
        var valHP:Dynamic = null;
        if (dataLeaf != null) valHP = _sf(dataLeaf, "intHP");
        if (valHP == null && objData != null) valHP = _sf(objData, "intHP");
        if (valHP == null) valHP = _sf(rawData, "intHP");
        if (valHP != null) this.hp = _di(valHP);

        // Max HP resolution
        var valMaxHP:Dynamic = null;
        if (dataLeaf != null) valMaxHP = _sf(dataLeaf, "intHPMax");
        if (valMaxHP == null && objData != null) valMaxHP = _sf(objData, "intHPMax");
        if (valMaxHP == null) valMaxHP = _sf(rawData, "intHPMax");
        if (valMaxHP != null) this.maxHp = _di(valMaxHP);

        // MP resolution
        var valMP:Dynamic = null;
        if (dataLeaf != null) valMP = _sf(dataLeaf, "intMP");
        if (valMP == null && objData != null) valMP = _sf(objData, "intMP");
        if (valMP == null) valMP = _sf(rawData, "intMP");
        if (valMP != null) this.mp = _di(valMP);

        // State resolution
        var valState:Dynamic = null;
        if (dataLeaf != null) valState = _sf(dataLeaf, "intState");
        if (valState == null && objData != null) valState = _sf(objData, "intState");
        if (valState == null) valState = _sf(rawData, "intState");
        if (valState != null) this.state = _di(valState);
        else this.state = (this.hp > 0) ? 1 : 0;

        // Cell resolution
        if (pMC != null) {
            var cl = _sf(pMC, "currentLabel");
            if (cl != null && Std.string(cl) != "") this.cell = Std.string(cl);
        }
        if (this.cell == "" && dataLeaf != null) {
            var sf = _sf(dataLeaf, "strFrame");
            if (sf != null && Std.string(sf) != "") this.cell = Std.string(sf);
        }
        if (this.cell == "" && objData != null) {
            var sf = _sf(objData, "strFrame");
            if (sf != null && Std.string(sf) != "") this.cell = Std.string(sf);
        }
        if (this.cell == "") {
            var sf = _sf(rawData, "strFrame");
            if (sf != null && Std.string(sf) != "") this.cell = Std.string(sf);
        }

        // MapID / MonID / ID resolution
        if (dataLeaf != null) {
            var mmid = _sf(dataLeaf, "MonMapID");
            var entID = _sf(dataLeaf, "entID");
            var mid = _sf(dataLeaf, "MonID");
            if (mmid != null) { this.id = Std.string(mmid); this.mapId = this.id; }
            else if (entID != null) this.id = Std.string(entID);
            if (mid != null) this.monsterId = Std.string(mid);
        } else if (objData != null) {
            var mmid = _sf(objData, "MonMapID");
            if (mmid != null) this.id = Std.string(mmid);
        }

        if (this.mapId == "" && objData != null) {
            var mmid = _sf(objData, "MonMapID");
            if (mmid != null) this.mapId = Std.string(mmid);
        }
        if (this.mapId == "") {
            var mmid = _sf(rawData, "MonMapID");
            if (mmid != null) this.mapId = Std.string(mmid);
        }

        if (this.monsterId == "" && objData != null) {
            var mid = _sf(objData, "MonID");
            if (mid != null) this.monsterId = Std.string(mid);
        }
        if (this.monsterId == "") {
            var mid = _sf(rawData, "MonID");
            if (mid != null) this.monsterId = Std.string(mid);
        }

        if (this.id == "") {
            if (this.mapId != "") this.id = this.mapId;
            else {
                var entID = _sf(rawData, "entID");
                if (entID != null) this.id = Std.string(entID);
            }
        }

        // 1. Classification (safe reflection, never using direct property access)
        var monCheck:Bool = false;
        if (pMC != null) {
            try {
                if (Reflect.hasField(pMC, "isMonster") && Reflect.field(pMC, "isMonster") == true) monCheck = true;
            } catch (_:Dynamic) {}
        }
        if (!monCheck && rawData != null) {
            try {
                if (Reflect.hasField(rawData, "isMonster") && Reflect.field(rawData, "isMonster") == true) monCheck = true;
            } catch (_:Dynamic) {}
        }
        if (!monCheck && (this.mapId != "" || this.monsterId != "")) {
            monCheck = true;
        }
        if (!monCheck && objData != null && _sf(objData, "MonMapID") != null) {
            monCheck = true;
        }
        this.isMonster = monCheck;
        this.isPlayer = !monCheck;

        // 2. Local avatar check
        if (rawData != null) {
            try {
                if (Reflect.hasField(rawData, "isMyAvatar") && Reflect.field(rawData, "isMyAvatar") == true) this.isMyAvatar = true;
            } catch (_:Dynamic) {}
        }

        // 3. Level
        var lvlVal:Dynamic = null;
        if (dataLeaf != null) lvlVal = _sf(dataLeaf, "intLevel");
        if (lvlVal == null && objData != null) lvlVal = _sf(objData, "intLevel");
        if (lvlVal != null) this.level = _di(lvlVal, 1);

        // 4. Monster Race
        if (this.isMonster) {
            var r:Dynamic = null;
            if (objData != null) r = _sf(objData, "sRace");
            if (r == null && dataLeaf != null) r = _sf(dataLeaf, "sRace");
            if (r != null) {
                var strR = _ds(r);
                if (strR != "" && strR != "None" && strR != "null") this.race = strR;
            } else if (pMC != null) {
                try {
                    var pn = _sf(pMC, "pname");
                    if (pn != null) {
                        var typ = _sf(pn, "typ");
                        if (typ != null && typ.text != null) {
                            var strTyp = _ds(typ.text);
                            if (strTyp.indexOf("None") == -1 && strTyp != "") {
                                strTyp = StringTools.replace(strTyp, "<", "");
                                strTyp = StringTools.replace(strTyp, ">", "");
                                this.race = StringTools.trim(strTyp);
                            }
                        }
                    }
                } catch (_:Dynamic) {}
            }
        }

        // 5. Player Guild & AFK
        if (this.isPlayer) {
            var gObj:Dynamic = null;
            if (objData != null) gObj = _sf(objData, "guild");
            if (gObj == null && dataLeaf != null) gObj = _sf(dataLeaf, "guild");
            if (gObj != null) {
                var gName = _sf(gObj, "Name");
                if (gName != null && _ds(gName) != "" && _ds(gName) != "null") this.guild = _ds(gName);
            } else if (pMC != null) {
                try {
                    var pn = _sf(pMC, "pname");
                    if (pn != null) {
                        var tg = _sf(pn, "tg");
                        if (tg != null && tg.text != null) {
                            var strTg = _ds(tg.text);
                            if (strTg != "" && strTg != "null") {
                                strTg = StringTools.replace(strTg, "<", "");
                                strTg = StringTools.replace(strTg, ">", "");
                                this.guild = StringTools.trim(strTg);
                            }
                        }
                    }
                } catch (_:Dynamic) {}
            }

            // AFK check
            try {
                var g:Dynamic = Api.game;
                if (g != null && g.world != null && g.world.uoTree != null && this.name != "") {
                    var uo = Reflect.field(g.world.uoTree, this.name.toLowerCase());
                    if (uo != null && uo.afk == true) this.isAfk = true;
                }
            } catch (_:Dynamic) {}
        }
    }

    public function getAura(auraName:String):Dynamic {
        if (auraName == null || raw == null) return null;
        var search:String = auraName.toLowerCase();

        var auraSources:Array<Dynamic> = [];
        var rawAuras = _sf(raw, "auras");
        if (rawAuras != null) auraSources.push(rawAuras);

        var dl = _sf(raw, "dataLeaf");
        if (dl != null) {
            var dlAuras = _sf(dl, "auras");
            if (dlAuras != null) auraSources.push(dlAuras);
        }

        var od = _sf(raw, "objData");
        if (od != null) {
            var odAuras = _sf(od, "auras");
            if (odAuras != null) auraSources.push(odAuras);
        }

        if (Api.game != null && Api.game.world != null) {
            var w:Dynamic = Api.game.world;
            if (this.mapId != "" && w.monTree != null) {
                try {
                    var mLeaf = Reflect.field(w.monTree, this.mapId);
                    if (mLeaf != null && mLeaf.auras != null) auraSources.push(mLeaf.auras);
                } catch (e:Dynamic) {}
            }
            if (this.name != "" && w.uoTree != null) {
                try {
                    var uLeaf = Reflect.field(w.uoTree, this.name.toLowerCase());
                    if (uLeaf != null && uLeaf.auras != null) auraSources.push(uLeaf.auras);
                } catch (e:Dynamic) {}
            }
            var pnmVal = _sf(raw, "pnm");
            if (pnmVal != null && Std.string(pnmVal) != "" && w.uoTree != null) {
                try {
                    var uLeaf = Reflect.field(w.uoTree, Std.string(pnmVal).toLowerCase());
                    if (uLeaf != null && uLeaf.auras != null) auraSources.push(uLeaf.auras);
                } catch (e:Dynamic) {}
            }
        }

        for (src in auraSources) {
            if (src == null) continue;
            if (Std.isOfType(src, Array)) {
                var arr:Array<Dynamic> = cast src;
                for (a in arr) {
                    if (a == null) continue;
                    var exp:Dynamic = _sf(a, "e");
                    if (exp != null && (Std.string(exp) == "1" || exp == true)) continue;
                    var an:String = "";
                    var nam = _sf(a, "nam");
                    var name = _sf(a, "name");
                    var sName = _sf(a, "sName");
                    var auraNameVal = _sf(a, "auraName");

                    if (nam != null) an = Std.string(nam);
                    else if (name != null) an = Std.string(name);
                    else if (sName != null) an = Std.string(sName);
                    else if (auraNameVal != null) an = Std.string(auraNameVal);

                    if (an.toLowerCase() == search) return a;
                }
            } else {
                for (f in Reflect.fields(src)) {
                    var a:Dynamic = _sf(src, f);
                    if (a == null) continue;
                    var exp:Dynamic = _sf(a, "e");
                    if (exp != null && (Std.string(exp) == "1" || exp == true)) continue;
                    var an:String = f;
                    var nam = _sf(a, "nam");
                    var name = _sf(a, "name");
                    var sName = _sf(a, "sName");
                    var auraNameVal = _sf(a, "auraName");

                    if (nam != null) an = Std.string(nam);
                    else if (name != null) an = Std.string(name);
                    else if (sName != null) an = Std.string(sName);
                    else if (auraNameVal != null) an = Std.string(auraNameVal);

                    if (an.toLowerCase() == search) return a;
                }
            }
        }
        return null;
    }

    public function hasAura(auraName:String):Bool {
        return getAura(auraName) != null;
    }

    public function getAuraStacks(auraName:String):Float {
        var a = getAura(auraName);
        if (a == null) return 0.0;
        var val = _sf(a, "val");
        if (val == null) return 1.0;
        return ApiUtils.parseFloat(val, 1.0);
    }

    public function getAuraDuration(auraName:String):Float {
        var a = getAura(auraName);
        if (a == null) return 0.0;
        var dur = _sf(a, "dur");
        return (dur != null) ? ApiUtils.parseFloat(dur, 0.0) : 0.0;
    }

    public function getAuraRemaining(auraName:String):Float {
        var a = getAura(auraName);
        if (a == null) return 0.0;
        var durVal = _sf(a, "dur");
        var dur:Float = (durVal != null) ? ApiUtils.parseFloat(durVal, 0.0) : 0.0;
        if (dur <= 0) return 0.0;
        var tsVal = _sf(a, "ts");
        var ts:Float = (tsVal != null) ? ApiUtils.parseFloat(tsVal, 0.0) : 0.0;
        if (ts <= 0) return dur;
        var tsMs:Float = (ts < 10000000000.0) ? (ts * 1000.0) : ts;
        var nowMs:Float = ApiTime.epochMs();
        var rem:Float = (tsMs + (dur * 1000.0) - nowMs) / 1000.0;
        return rem > 0 ? rem : 0.0;
    }
}
