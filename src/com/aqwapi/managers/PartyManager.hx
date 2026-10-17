package com.aqwapi.managers;

import com.aqwapi.Api;
import com.aqwapi.data.PartyMemberDTO;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.Game;

/**
 * PartyManager:
 * Provides clean access to AQW party information, member statistics,
 * party actions (invite, kick, leave, promote, summon, disband),
 * and instant party member targeting.
 */
class PartyManager {
    private var _game:Game;

    public function new(gameReference:Game) {
        _game = gameReference;
    }

    private inline function _g():Game {
        return (_game != null) ? _game : Api.game;
    }

    private inline function _world():Dynamic {
        var g = _g();
        return (g != null) ? g.world : null;
    }

    /**
     * True if the player is currently in a party.
     */
    public var inParty(get, never):Bool;
    public function get_inParty():Bool {
        var w = _world();
        if (w == null) return false;
        var pMembers:Dynamic = w.partyMembers;
        if (pMembers != null && untyped pMembers.length > 0) return true;
        var pid:Dynamic = w.partyID;
        return pid != null && pid > 0;
    }

    /**
     * True if the local player is the party leader.
     */
    public var isLeader(get, never):Bool;
    public function get_isLeader():Bool {
        if (!inParty) return false;
        var lead = leaderName;
        if (lead == "") return false;
        var myName = currentUsername;
        return lead.toLowerCase() == myName.toLowerCase();
    }

    /**
     * The username of the party leader.
     */
    public var leaderName(get, never):String;
    public function get_leaderName():String {
        var w = _world();
        return (w != null && w.partyOwner != null) ? Std.string(w.partyOwner) : "";
    }

    /**
     * The current party ID (-1 if not in a party).
     */
    public var partyId(get, never):Int;
    public function get_partyId():Int {
        var w = _world();
        return (w != null && w.partyID != null) ? Std.int(w.partyID) : -1;
    }

    /**
     * Local player's username.
     */
    public var currentUsername(get, never):String;
    public function get_currentUsername():String {
        var g = _g();
        if (g != null && g.sfc != null && g.sfc.myUserName != null) {
            return Std.string(g.sfc.myUserName);
        }
        return (Api.player != null) ? Api.player.username : "";
    }

    /**
     * List of usernames of other members in the party.
     */
    public var memberNames(get, never):Array<String>;
    public function get_memberNames():Array<String> {
        var result:Array<String> = [];
        var w = _world();
        if (w == null) return result;
        var pMembers:Dynamic = w.partyMembers;
        if (pMembers != null) {
            var len:Int = untyped pMembers.length;
            for (i in 0...len) {
                var unm:Dynamic = untyped pMembers[i];
                if (unm != null) result.push(Std.string(unm));
            }
        }
        return result;
    }

    /**
     * List of other party members as PartyMemberDTO objects (excluding self).
     */
    public var members(get, never):Array<PartyMemberDTO>;
    public function get_members():Array<PartyMemberDTO> {
        var list:Array<PartyMemberDTO> = [];
        var w = _world();
        if (w == null) return list;
        var names = memberNames;
        for (name in names) {
            var m = buildMemberDTO(name, false);
            if (m != null) list.push(m);
        }
        return list;
    }

    /**
     * List of all party members including self.
     */
    public var allMembers(get, never):Array<PartyMemberDTO>;
    public function get_allMembers():Array<PartyMemberDTO> {
        var list:Array<PartyMemberDTO> = [];
        var meName = currentUsername;
        if (meName != "") {
            var meDto = buildMemberDTO(meName, true);
            if (meDto != null) list.push(meDto);
        }
        for (m in members) {
            if (m.username.toLowerCase() != meName.toLowerCase()) {
                list.push(m);
            }
        }
        return list;
    }

    /**
     * Total member count (including self if in party).
     */
    public var memberCount(get, never):Int;
    public function get_memberCount():Int {
        return inParty ? (memberNames.length + 1) : 0;
    }

    /**
     * Finds a party member by username (case-insensitive).
     */
    public function getMember(username:String):Null<PartyMemberDTO> {
        if (username == null || username == "") return null;
        var lower = username.toLowerCase();
        for (m in allMembers) {
            if (m.username.toLowerCase() == lower) return m;
        }
        return null;
    }

    /**
     * Checks if a player is in the party.
     */
    public function isMember(username:String):Bool {
        if (username == null || username == "") return false;
        var lower = username.toLowerCase();
        if (lower == currentUsername.toLowerCase()) return inParty;
        for (n in memberNames) {
            if (n.toLowerCase() == lower) return true;
        }
        return false;
    }

    private static var _statCache:Map<String, Dynamic> = new Map();

    /**
     * Builds a PartyMemberDTO from game structures (uoTree, Avatar, dataLeaf, native frame, cache).
     */
    public function buildMemberDTO(name:String, isSelf:Bool):PartyMemberDTO {
        var dto = new PartyMemberDTO();
        dto.username = (name != null) ? name : "";
        dto.isMe = isSelf;
        var lead = leaderName;
        dto.isLeader = (name != null && name != "" && lead != null && lead != "" && name.toLowerCase() == lead.toLowerCase());

        var w = _world();
        if (w == null) return dto;

        if (isSelf) {
            if (w.myAvatar != null && w.myAvatar.dataLeaf != null) {
                var leaf:Dynamic = w.myAvatar.dataLeaf;
                dto.hp = leaf.intHP != null ? Std.int(leaf.intHP) : 0;
                dto.maxHp = leaf.intHPMax != null ? Std.int(leaf.intHPMax) : 100;
                dto.mp = leaf.intMP != null ? Std.int(leaf.intMP) : 0;
                dto.maxMp = leaf.intMPMax != null ? Std.int(leaf.intMPMax) : 100;
                dto.level = leaf.intLevel != null ? Std.int(leaf.intLevel) : 1;
                dto.className = leaf.strClassName != null ? Std.string(leaf.strClassName) : "";
                dto.shield = leaf.intSG != null ? Std.int(leaf.intSG) : 0;
                dto.raw = leaf;
                dto.avatar = w.myAvatar;
                dto.inRange = true;
                dto.inCell = true;
            }
            return dto;
        }

        var lower = (name != null) ? name.toLowerCase() : "";

        // 1. Search uoTree (Dictionary) with multiple keys & method fallbacks
        var uoLeaf:Dynamic = null;
        try {
            if (w.uoTree != null) {
                uoLeaf = untyped w.uoTree[lower];
                if (uoLeaf == null) uoLeaf = untyped w.uoTree[name];
            }
            if (uoLeaf == null && Reflect.isFunction(w.uoTreeLeaf)) {
                uoLeaf = w.uoTreeLeaf(lower);
                if (uoLeaf == null) uoLeaf = w.uoTreeLeaf(name);
            }
        } catch (_:Dynamic) {}

        // 2. Search w.avatars (Array/Vector of Avatar in current room)
        var av:Dynamic = null;
        try {
            if (Reflect.isFunction(w.getAvatarByUserName)) {
                av = w.getAvatarByUserName(lower);
                if (av == null) av = w.getAvatarByUserName(name);
            }
            if (av == null && w.avatars != null) {
                var avList:Array<Dynamic> = cast w.avatars;
                for (a in avList) {
                    if (a != null && a.pnm != null && Std.string(a.pnm).toLowerCase() == lower) {
                        av = a;
                        break;
                    }
                }
            }
        } catch (_:Dynamic) {}

        // 3. Fallback: inspect native mcPartyFrame if present
        var nativeHp:Int = -1;
        var nativeMp:Int = -1;
        try {
            var g = _g();
            if (g != null && g.ui != null && g.ui.mcPartyFrame != null) {
                var pFrame:Dynamic = g.ui.mcPartyFrame;
                for (idx in 0...pFrame.numChildren) {
                    var child:Dynamic = pFrame.getChildAt(idx);
                    if (child != null && child.strName != null && child.strName.text != null) {
                        if (Std.string(child.strName.text).toLowerCase() == lower) {
                            if (child.HP != null && child.HP.visible && child.HP.strIntHP != null) {
                                var parsedHp = Std.parseInt(child.HP.strIntHP.text);
                                if (parsedHp != null) nativeHp = parsedHp;
                            }
                            if (child.MP != null && child.MP.visible && child.MP.strIntMP != null) {
                                var parsedMp = Std.parseInt(child.MP.strIntMP.text);
                                if (parsedMp != null) nativeMp = parsedMp;
                            }
                            break;
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        dto.avatar = av;
        dto.raw = (uoLeaf != null) ? uoLeaf : (av != null ? (av.dataLeaf != null ? av.dataLeaf : av.objData) : null);

        // In range if entity is found in room avatars, uoTree, or native party frame
        var inRange = (av != null || uoLeaf != null || nativeHp >= 0);
        dto.inRange = inRange;

        // Check cell status
        var inSameCell:Bool = false;
        if (av != null && av.pMC != null && av.dataLeaf != null && w.myAvatar != null && w.myAvatar.dataLeaf != null) {
            inSameCell = (av.dataLeaf.strFrame == w.myAvatar.dataLeaf.strFrame);
        } else if (av != null) {
            inSameCell = true;
        }
        dto.inCell = inSameCell;

        // Populate stats (priority: avatar dataLeaf -> uoLeaf -> objData)
        if (av != null && av.dataLeaf != null) {
            var leaf:Dynamic = av.dataLeaf;
            dto.hp = leaf.intHP != null ? Std.int(leaf.intHP) : 0;
            dto.maxHp = leaf.intHPMax != null ? Std.int(leaf.intHPMax) : 100;
            dto.mp = leaf.intMP != null ? Std.int(leaf.intMP) : 0;
            dto.maxMp = leaf.intMPMax != null ? Std.int(leaf.intMPMax) : 100;
            dto.level = leaf.intLevel != null ? Std.int(leaf.intLevel) : (av.objData != null ? Std.int(av.objData.intLevel) : 1);
            dto.className = leaf.strClassName != null ? Std.string(leaf.strClassName) : (av.objData != null ? Std.string(av.objData.strClassName) : "");
            dto.shield = leaf.intSG != null ? Std.int(leaf.intSG) : 0;
        } else if (uoLeaf != null) {
            dto.hp = uoLeaf.intHP != null ? Std.int(uoLeaf.intHP) : 0;
            dto.maxHp = uoLeaf.intHPMax != null ? Std.int(uoLeaf.intHPMax) : 100;
            dto.mp = uoLeaf.intMP != null ? Std.int(uoLeaf.intMP) : 0;
            dto.maxMp = uoLeaf.intMPMax != null ? Std.int(uoLeaf.intMPMax) : 100;
            dto.level = uoLeaf.intLevel != null ? Std.int(uoLeaf.intLevel) : 1;
            dto.className = uoLeaf.strClassName != null ? Std.string(uoLeaf.strClassName) : "";
            dto.shield = uoLeaf.intSG != null ? Std.int(uoLeaf.intSG) : 0;
        } else if (av != null && av.objData != null) {
            var obj:Dynamic = av.objData;
            dto.hp = obj.intHP != null ? Std.int(obj.intHP) : 0;
            dto.maxHp = obj.intHPMax != null ? Std.int(obj.intHPMax) : 100;
            dto.mp = obj.intMP != null ? Std.int(obj.intMP) : 0;
            dto.maxMp = obj.intMPMax != null ? Std.int(obj.intMPMax) : 100;
            dto.level = obj.intLevel != null ? Std.int(obj.intLevel) : 1;
            dto.className = obj.strClassName != null ? Std.string(obj.strClassName) : "";
            dto.shield = 0;
        }

        if (nativeHp >= 0 && dto.hp == 0) {
            dto.hp = nativeHp;
        }
        if (nativeMp >= 0 && dto.mp == 0) {
            dto.mp = nativeMp;
        }

        // Cache known stats so out-of-room members retain last known values
        if (dto.maxHp > 0 && inRange) {
            _statCache.set(lower, {
                hp: dto.hp,
                maxHp: dto.maxHp,
                mp: dto.mp,
                maxMp: dto.maxMp,
                level: dto.level,
                className: dto.className
            });
        } else if (!inRange && _statCache.exists(lower)) {
            var cached = _statCache.get(lower);
            dto.hp = cached.hp;
            dto.maxHp = cached.maxHp;
            dto.mp = cached.mp;
            dto.maxMp = cached.maxMp;
            dto.level = cached.level;
            dto.className = cached.className;
        }

        return dto;
    }

    /**
     * Targets a party member by username if they are in the current cell.
     */
    public function targetMember(username:String):Bool {
        if (username == null || username == "") return false;
        var w = _world();
        if (w == null) return false;
        try {
            if (Reflect.isFunction(w.getAvatarByUserName)) {
                var av:Dynamic = w.getAvatarByUserName(username.toLowerCase());
                if (av != null && av.pMC != null && av.dataLeaf != null && w.myAvatar != null && w.myAvatar.dataLeaf != null) {
                    if (av.dataLeaf.strFrame == w.myAvatar.dataLeaf.strFrame) {
                        w.setTarget(av);
                        return true;
                    }
                }
            }
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Invites a player to the party.
     */
    public function invite(username:String):Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partyInvite)) {
            w.partyInvite(username);
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["pi", username], "str", 1);
            }
        }
    }

    /**
     * Kicks a player from the party (requires party leader).
     */
    public function kick(username:String):Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partyKick)) {
            w.partyKick(username);
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["pk", username], "str", 1);
            }
        }
    }

    /**
     * Leaves the current party.
     */
    public function leave():Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partyLeave)) {
            w.partyLeave();
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["pl"], "str", 1);
            }
        }
    }

    /**
     * Disbands the party (requires party leader).
     */
    public function disband():Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partyDisband)) {
            w.partyDisband();
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["pc"], "str", 1);
            }
        }
    }

    /**
     * Promotes a member to party leader.
     */
    public function promote(username:String):Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partyPromote)) {
            w.partyPromote(username);
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["pp", username], "str", 1);
            }
        }
    }

    /**
     * Summons a party member to your location.
     */
    public function summon(username:String):Void {
        var w = _world();
        if (w != null && Reflect.isFunction(w.partySummon)) {
            w.partySummon(username);
        } else {
            var g = _g();
            if (g != null && g.sfc != null) {
                g.sfc.sendXtMessage("zm", "gp", ["ps", username], "str", 1);
            }
        }
    }
}
