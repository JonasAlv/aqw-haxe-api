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
    public var maxMp:Int = 0;
    public var shield:Int = 0;
    public var sp:Int = 0;
    public var maxSp:Int = 1000;
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
    public var targetUserIds:Array<String> = [];
    public var isTargetingMe:Bool = false;

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
                if (tgt == this.raw) return true;
                if (this.pMC != null && (tgt == this.pMC || tgt.pMC == this.pMC)) return true;
                if (this.raw != null && tgt.raw != null && tgt.raw == this.raw) return true;
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

    /**
     * Suppresses the native `pname` / `hpBar` without touching anything the game owns.
     * AvatarMC.scale()/MonsterMC.scale() own `y`, and hideNameSetup/toggleName/toggleHPBar own `visible`.
     * The game never writes `alpha` on either clip, so alpha is the only lossless hide/restore channel.
     */
    public function hideNativeName():Void {
        var mc = this.pMC;
        if (mc == null) return;
        try {
            var pn:Dynamic = _sf(mc, "pname");
            if (pn != null && pn.alpha != 0.0) pn.alpha = 0.0;
        } catch (_:Dynamic) {}
        try {
            var hb:Dynamic = _sf(mc, "hpBar");
            if (hb != null && hb.alpha != 0.0) hb.alpha = 0.0;
        } catch (_:Dynamic) {}
    }

    public function showNativeName():Void {
        var mc = this.pMC;
        if (mc == null) return;
        try {
            var pn:Dynamic = _sf(mc, "pname");
            if (pn != null) pn.alpha = 1.0;
        } catch (_:Dynamic) {}
        try {
            var hb:Dynamic = _sf(mc, "hpBar");
            if (hb != null) hb.alpha = 1.0;
        } catch (_:Dynamic) {}
    }

    private static inline function _sf(obj:Dynamic, field:String):Dynamic {
        return ApiUtils.safeField(obj, field);
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
        if (state == 0) return false;
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

        try { dataLeaf = untyped rawData.dataLeaf; } catch(e:Dynamic) {}
        if (dataLeaf == null) {
            try { dataLeaf = _sf(rawData, "dataLeaf"); } catch(e:Dynamic) {}
        }
        try { objData = untyped rawData.objData; } catch(e:Dynamic) {}
        if (objData == null) {
            try { objData = _sf(rawData, "objData"); } catch(e:Dynamic) {}
        }
        try { pMC = untyped rawData.pMC; } catch(e:Dynamic) {}
        if (pMC == null) {
            try { pMC = _sf(rawData, "pMC"); } catch(e:Dynamic) {}
        }

        // Check isMyAvatar
        try {
            if (untyped rawData.isMyAvatar == true) this.isMyAvatar = true;
        } catch (_:Dynamic) {}
        if (!this.isMyAvatar && Api.game != null && Api.game.world != null) {
            if (rawData == Api.game.world.myAvatar) this.isMyAvatar = true;
            if (pMC != null && Api.game.world.myAvatar != null && pMC == Api.game.world.myAvatar.pMC) this.isMyAvatar = true;
        }

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

        // Additional fallback for isMyAvatar by username
        if (!this.isMyAvatar && Api.player != null && Api.player.username != "") {
            var myName = Api.player.username.toLowerCase();
            if (this.name != "" && this.name.toLowerCase() == myName) this.isMyAvatar = true;
        }

        // 1. MapID / MonID / ID resolution
        var monMapVal:Dynamic = null;
        if (objData != null) monMapVal = _sf(objData, "MonMapID");
        if (monMapVal == null && dataLeaf != null) monMapVal = _sf(dataLeaf, "MonMapID");
        if (monMapVal == null && rawData != null) monMapVal = _sf(rawData, "MonMapID");

        if (monMapVal != null) {
            this.mapId = Std.string(monMapVal);
            this.id = this.mapId;
        }

        var monIdVal:Dynamic = null;
        if (objData != null) monIdVal = _sf(objData, "MonID");
        if (monIdVal == null && dataLeaf != null) monIdVal = _sf(dataLeaf, "MonID");
        if (monIdVal == null && rawData != null) monIdVal = _sf(rawData, "MonID");
        if (monIdVal != null) this.monsterId = Std.string(monIdVal);

        if (this.id == "") {
            var entID:Dynamic = null;
            if (dataLeaf != null) entID = _sf(dataLeaf, "entID");
            if (entID == null && objData != null) entID = _sf(objData, "entID");
            if (entID == null && rawData != null) entID = _sf(rawData, "entID");
            if (entID != null) this.id = Std.string(entID);
        }

        // 2. Classification (isMonster / isPlayer)
        var monCheck:Bool = false;
        var npcTyp:Dynamic = _sf(rawData, "npcType");
        if (npcTyp != null) {
            if (Std.string(npcTyp).toLowerCase() == "monster") monCheck = true;
            else if (Std.string(npcTyp).toLowerCase() == "player") monCheck = false;
        }
        if (!monCheck) {
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
            if (!monCheck && objData != null && (_sf(objData, "MonMapID") != null || _sf(objData, "strMonName") != null)) {
                monCheck = true;
            }
        }
        if (this.isMyAvatar) {
            monCheck = false;
        }
        this.isMonster = monCheck;
        this.isPlayer = !monCheck;

        // 3. Level
        var lvlVal:Dynamic = null;
        if (dataLeaf != null) lvlVal = _sf(dataLeaf, "intLevel");
        if (lvlVal == null && objData != null) lvlVal = _sf(objData, "intLevel");
        if (lvlVal == null) lvlVal = _sf(rawData, "intLevel");
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

        // 5. Monster targets resolution (dataLeaf.targets map in World.as:9300)
        if (dataLeaf != null && dataLeaf.targets != null) {
            try {
                var tgts:Dynamic = dataLeaf.targets;
                var myUname = (Api.player != null && Api.player.username != null) ? Api.player.username.toLowerCase() : "";
                var myUid:String = "";
                if (Api.game != null && Api.game.world != null && Api.game.world.myAvatar != null && Api.game.world.myAvatar.uid != null) {
                    myUid = Std.string(Api.game.world.myAvatar.uid);
                }
                var keys:Array<Dynamic> = untyped __keys__(tgts);
                for (k in keys) {
                    if (k == null) continue;
                    var ks = Std.string(k);
                    if (ks != "" && this.targetUserIds.indexOf(ks) == -1) {
                        this.targetUserIds.push(ks);
                    }
                    if ((myUname != "" && ks.toLowerCase() == myUname) || (myUid != "" && ks == myUid)) {
                        this.isTargetingMe = true;
                    }
                }
            } catch (_:Dynamic) {}
        }

        // 6. Cell resolution
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

        // 7. Player Guild & AFK
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

        // 8. Stats Resolution (HP, Max HP, MP, Max MP, Shield, SP, State)
        if (this.isMyAvatar && Api.player != null) {
            this.hp = Api.player.hp;
            this.maxHp = Api.player.maxHp;
            this.mp = Api.player.mp;
            this.maxMp = Api.player.maxMp;
            this.shield = Api.player.shield;
            this.sp = Api.player.sp;
            this.maxSp = Api.player.maxSp;
            this.state = Api.player.state;
        } else if (this.isMonster) {
            var valHP:Dynamic = null;
            var valMaxHP:Dynamic = null;
            var valMP:Dynamic = null;
            var valMaxMP:Dynamic = null;
            var valSG:Dynamic = null;
            var valSP:Dynamic = null;
            var valMaxSP:Dynamic = null;
            var valState:Dynamic = null;

            // 1. Live lookup in world.monTree (updated on combat packets)
            var monMapId:Dynamic = (this.mapId != "") ? this.mapId : ((objData != null) ? _sf(objData, "MonMapID") : null);
            if (monMapId == null && dataLeaf != null) monMapId = _sf(dataLeaf, "MonMapID");
            if (monMapId == null && rawData != null) monMapId = _sf(rawData, "MonMapID");

            if (monMapId != null && Api.game != null && Api.game.world != null && Api.game.world.monTree != null) {
                try {
                    var mTree:Dynamic = Api.game.world.monTree;
                    var strKey:String = Std.string(monMapId);
                    var intKey:Int = Std.parseInt(strKey);
                    var mLeaf:Dynamic = untyped mTree[intKey];
                    if (mLeaf == null) mLeaf = untyped mTree[strKey];
                    if (mLeaf == null) mLeaf = untyped mTree[monMapId];
                    if (mLeaf == null) mLeaf = Reflect.field(mTree, strKey);
                    if (mLeaf != null) {
                        if (valHP == null && mLeaf.intHP != null) valHP = mLeaf.intHP;
                        if (valMaxHP == null && mLeaf.intHPMax != null) valMaxHP = mLeaf.intHPMax;
                        if (valMP == null && mLeaf.intMP != null) valMP = mLeaf.intMP;
                        if (valMaxMP == null && mLeaf.intMPMax != null) valMaxMP = mLeaf.intMPMax;
                        if (valSG == null && mLeaf.intSG != null) valSG = mLeaf.intSG;
                        if (valSP == null && mLeaf.intSP != null) valSP = mLeaf.intSP;
                        if (valMaxSP == null && mLeaf.intSPMax != null) valMaxSP = mLeaf.intSPMax;
                        if (valState == null && mLeaf.intState != null) valState = mLeaf.intState;
                    }
                } catch (_:Dynamic) {}
            }

            // 3. Fallback to objData (updated via Game.as:5377 on monster damage)
            if (objData != null) {
                if (valHP == null && objData.intHP != null) valHP = objData.intHP;
                if (valMaxHP == null && objData.intHPMax != null) valMaxHP = objData.intHPMax;
                if (valMP == null && objData.intMP != null) valMP = objData.intMP;
                if (valMaxMP == null && objData.intMPMax != null) valMaxMP = objData.intMPMax;
                if (valSG == null && objData.intSG != null) valSG = objData.intSG;
                if (valState == null && objData.intState != null) valState = objData.intState;
            }

            // 4. Fallback to dataLeaf (m.dataLeaf in World.as:8197 points directly to monTree)
            if (dataLeaf != null) {
                if (valHP == null && dataLeaf.intHP != null) valHP = dataLeaf.intHP;
                if (valMaxHP == null && dataLeaf.intHPMax != null) valMaxHP = dataLeaf.intHPMax;
                if (valMP == null && dataLeaf.intMP != null) valMP = dataLeaf.intMP;
                if (valMaxMP == null && dataLeaf.intMPMax != null) valMaxMP = dataLeaf.intMPMax;
                if (valSG == null && dataLeaf.intSG != null) valSG = dataLeaf.intSG;
                if (valSP == null && dataLeaf.intSP != null) valSP = dataLeaf.intSP;
                if (valMaxSP == null && dataLeaf.intSPMax != null) valMaxSP = dataLeaf.intSPMax;
                if (valState == null && dataLeaf.intState != null) valState = dataLeaf.intState;
            }

            // 4. Fallback to rawData
            if (valHP == null) valHP = _sf(rawData, "intHP");
            if (valMaxHP == null) valMaxHP = _sf(rawData, "intHPMax");
            if (valMP == null) valMP = _sf(rawData, "intMP");
            if (valMaxMP == null) valMaxMP = _sf(rawData, "intMPMax");
            if (valState == null) valState = _sf(rawData, "intState");

            if (valState != null) {
                this.state = _di(valState);
            } else {
                this.state = 1;
            }

            if (valMaxHP != null) this.maxHp = _di(valMaxHP);
            if (valHP != null) {
                this.hp = _di(valHP);
            } else if (this.maxHp > 0) {
                this.hp = (this.state == 0) ? 0 : this.maxHp;
            }

            if (this.state == 0) {
                this.hp = 0;
            } else if (this.hp <= 0 && this.state > 0) {
                this.state = 0;
            }

            if (this.maxHp <= 0 && this.hp > 0) {
                this.maxHp = this.hp;
            }
            if (this.maxHp <= 0) {
                this.maxHp = 100;
            }

            if (valMP != null) this.mp = _di(valMP);
            if (valMaxMP != null) this.maxMp = _di(valMaxMP);
            if (valSG != null) this.shield = _di(valSG);
            if (valSP != null) this.sp = _di(valSP);
            if (valMaxSP != null) this.maxSp = _di(valMaxSP, 1000);
        } else {
            // Other players
            var valHP:Dynamic = null;
            var valMaxHP:Dynamic = null;
            var valMP:Dynamic = null;
            var valMaxMP:Dynamic = null;
            var valSG:Dynamic = null;
            var valSP:Dynamic = null;
            var valMaxSP:Dynamic = null;
            var valState:Dynamic = null;

            // 1. Live lookup in world.uoTree (highest priority - updated on combat packets)
            var uName:String = (this.name != "") ? this.name : _ds(_sf(rawData, "pnm"));
            if (uName == "" && objData != null) uName = _ds(_sf(objData, "strUsername"));
            if (uName != "" && Api.game != null && Api.game.world != null) {
                var w:Dynamic = Api.game.world;
                var uLeaf:Dynamic = null;
                var lower:String = uName.toLowerCase();
                try {
                    if (Reflect.isFunction(w.uoTreeLeaf)) {
                        uLeaf = w.uoTreeLeaf(lower);
                    }
                } catch (_:Dynamic) {}
                if (uLeaf == null && w.uoTree != null) {
                    try {
                        uLeaf = untyped w.uoTree[lower];
                        if (uLeaf == null) uLeaf = untyped w.uoTree[uName];
                        if (uLeaf == null) uLeaf = Reflect.field(w.uoTree, lower);
                        if (uLeaf == null) uLeaf = Reflect.field(w.uoTree, uName);
                    } catch (_:Dynamic) {}
                }
                if (uLeaf != null) {
                    if (uLeaf.intHP != null) valHP = uLeaf.intHP;
                    if (uLeaf.intHPMax != null) valMaxHP = uLeaf.intHPMax;
                    if (uLeaf.intMP != null) valMP = uLeaf.intMP;
                    if (uLeaf.intMPMax != null) valMaxMP = uLeaf.intMPMax;
                    if (uLeaf.intSG != null) valSG = uLeaf.intSG;
                    if (uLeaf.intSP != null) valSP = uLeaf.intSP;
                    if (uLeaf.intSPMax != null) valMaxSP = uLeaf.intSPMax;
                    if (uLeaf.intState != null) valState = uLeaf.intState;
                }
            }

            // 2. Fallback to objData (updated via uoTreeLeafSet on player damage)
            if (objData != null) {
                if (valHP == null && objData.intHP != null) valHP = objData.intHP;
                if (valMaxHP == null && objData.intHPMax != null) valMaxHP = objData.intHPMax;
                if (valMP == null && objData.intMP != null) valMP = objData.intMP;
                if (valMaxMP == null && objData.intMPMax != null) valMaxMP = objData.intMPMax;
                if (valSG == null && objData.intSG != null) valSG = objData.intSG;
                if (valState == null && objData.intState != null) valState = objData.intState;
            }

            // 3. Fallback to dataLeaf
            if (dataLeaf != null) {
                if (valHP == null && dataLeaf.intHP != null) valHP = dataLeaf.intHP;
                if (valMaxHP == null && dataLeaf.intHPMax != null) valMaxHP = dataLeaf.intHPMax;
                if (valMP == null && dataLeaf.intMP != null) valMP = dataLeaf.intMP;
                if (valMaxMP == null && dataLeaf.intMPMax != null) valMaxMP = dataLeaf.intMPMax;
                if (valSG == null && dataLeaf.intSG != null) valSG = dataLeaf.intSG;
                if (valSP == null && dataLeaf.intSP != null) valSP = dataLeaf.intSP;
                if (valMaxSP == null && dataLeaf.intSPMax != null) valMaxSP = dataLeaf.intSPMax;
                if (valState == null && dataLeaf.intState != null) valState = dataLeaf.intState;
            }

            // 4. Fallback to rawData
            if (valHP == null) valHP = _sf(rawData, "intHP");
            if (valMaxHP == null) valMaxHP = _sf(rawData, "intHPMax");
            if (valMP == null) valMP = _sf(rawData, "intMP");
            if (valMaxMP == null) valMaxMP = _sf(rawData, "intMPMax");
            if (valState == null) valState = _sf(rawData, "intState");

            if (valState != null) {
                this.state = _di(valState);
            } else {
                this.state = 1;
            }

            if (valMaxHP != null) this.maxHp = _di(valMaxHP);
            if (valHP != null) {
                this.hp = _di(valHP);
            } else if (this.maxHp > 0) {
                this.hp = (this.state == 0) ? 0 : this.maxHp;
            }

            if (this.state == 0) {
                this.hp = 0;
            } else if (this.hp <= 0 && this.state > 0) {
                this.state = 0;
            }

            if (this.maxHp <= 0 && this.hp > 0) {
                this.maxHp = this.hp;
            }
            if (this.maxHp <= 0) {
                this.maxHp = 100;
            }

            if (valMP != null) this.mp = _di(valMP);
            if (valMaxMP != null) this.maxMp = _di(valMaxMP);
            if (valSG != null) this.shield = _di(valSG);
            if (valSP != null) this.sp = _di(valSP);
            if (valMaxSP != null) this.maxSp = _di(valMaxSP, 1000);
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
