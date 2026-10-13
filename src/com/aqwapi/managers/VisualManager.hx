package com.aqwapi.managers;

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.events.Event;
import flash.events.TimerEvent;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.utils.Timer;
import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;

/**
 * Native in-engine Visual & Performance Manager (Lag Killer).
 *
 * Utilizes AQW's internal AQLite preferences and Flash Display List controls
 * to stop heavy vector rasterization and particle rendering while keeping the
 * frame rate smooth and game simulation at full speed.
 */
class VisualManager {
    private var _game:Game;
    private var _sweepTimer:Timer;

    // Master toggle: forces hidePlayers, disableSkillAnims, and disableMonsterAnims
    public var lagKiller(default, set):Bool = false;

    // Granular toggles
    public var hidePlayers(default, set):Bool = false;

    // Spell animations mode: 0 = All Spells (Optimized), 1 = Self Only, 2 = Disabled
    public var skillAnimMode(default, set):Int = 0;

    // Backwards-compatible getter/setter for disableSkillAnims
    public var disableSkillAnims(get, set):Bool;

    // Fast FX: Strips expensive CPU blur/glow convolution filters & deduplicates overlapping spell clips
    public var optimizeSpellFX(default, set):Bool = true;

    // Dedicated toggle: Strips all blur/glow filters completely for extreme minimal performance
    public var disableSpellFilters(default, set):Bool = false;

    // Multi-target filtering: show friendly AoE buffs only on self (hide duplicates on party members)
    public var friendlySelfOnlyFX(default, set):Bool = false;

    // Multi-target filtering: show hostile AoE spells only on primary target (hide duplicates on side monsters)
    public var hostilePrimaryOnlyFX(default, set):Bool = false;

    // Concurrency limiter: Cap maximum active spell clips on screen (0 = Unlimited)
    public var maxConcurrentSpells(default, set):Int = 6;

    public var disableMonsterAnims(default, set):Bool = false;
    public var disableWeaponAnims(default, set):Bool = false;
    public var disableGround(default, set):Bool = false;
    public var hideMonsters(default, set):Bool = false;
    public var cleanArena(default, set):Bool = false;

    // Bitmap Caching (rasterizes vector models into GPU/blit bitmaps)
    public var cachePlayers(default, set):Bool = true;
    public var cacheMonsters(default, set):Bool = true;

    // Target glow suppression (disables native avtMCT/avtPCT color wash when units are targeted)
    public var suppressTargetGlow(default, set):Bool = true;

    // Display options when players are hidden
    public var showNames:Bool = true;
    public var showShadows:Bool = true;

    // Spell tracking state
    private var _hookedChars:Dynamic = null;

    public function new(gameRef:Game) {
        _game = gameRef;
        loadConfig();
        initTimer();
    }

    public function setGame(gameRef:Game):Void {
        _game = gameRef;
        apply();
    }

    private function loadConfig():Void {
        lagKiller = ApiConfig.getBool("api_lag_killer", false);
        hidePlayers = ApiConfig.getBool("api_hide_players", false);

        var oldDis = ApiConfig.getBool("api_disable_skill_anims", false);
        skillAnimMode = ApiConfig.getInt("api_skill_anim_mode", oldDis ? 2 : 0);
        optimizeSpellFX = ApiConfig.getBool("api_optimize_spell_fx", true);
        disableSpellFilters = ApiConfig.getBool("api_disable_spell_filters", false);
        friendlySelfOnlyFX = ApiConfig.getBool("api_friendly_self_only_fx", false);
        hostilePrimaryOnlyFX = ApiConfig.getBool("api_hostile_primary_only_fx", false);
        maxConcurrentSpells = ApiConfig.getInt("api_max_concurrent_spells", 0);

        disableMonsterAnims = ApiConfig.getBool("api_disable_mon_anims", false);
        disableWeaponAnims = ApiConfig.getBool("api_disable_wep_anims", false);
        disableGround = ApiConfig.getBool("api_disable_ground", false);
        hideMonsters = ApiConfig.getBool("api_hide_monsters", false);
        cleanArena = ApiConfig.getBool("api_clean_arena", false);
        cachePlayers = ApiConfig.getBool("api_cache_players", true);
        cacheMonsters = ApiConfig.getBool("api_cache_monsters", true);
        suppressTargetGlow = ApiConfig.getBool("api_suppress_target_glow", ApiConfig.getBool("api_frame_nameplates_enabled", true));
        showNames = ApiConfig.getBool("api_visual_show_names", true);
        showShadows = ApiConfig.getBool("api_visual_show_shadows", true);
    }

    private function initTimer():Void {
        if (_sweepTimer != null) {
            _sweepTimer.stop();
            _sweepTimer = null;
        }
        // Runs every 1200ms to maintain state for newly spawned/entering players & mobs
        _sweepTimer = new Timer(1200);
        _sweepTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent) {
            if (isActive()) {
                applyDisplayListOnly();
            }
            ensureCharsHook();
        });
        _sweepTimer.start();
    }

    public inline function isActive():Bool {
        return lagKiller || hidePlayers || (skillAnimMode != 0) || optimizeSpellFX || disableSpellFilters || friendlySelfOnlyFX || hostilePrimaryOnlyFX || disableMonsterAnims || disableWeaponAnims || disableGround || hideMonsters || cleanArena || suppressTargetGlow || cachePlayers || cacheMonsters;
    }

    public function set_suppressTargetGlow(v:Bool):Bool {
        suppressTargetGlow = v;
        ApiConfig.setBool("api_suppress_target_glow", v);
        applyTargetGlow();
        return suppressTargetGlow;
    }

    /**
     * Suppresses or restores native AQW target color wash.
     * When enabled, zeroes out world.avtMCT and world.avtPCT so targeting units
     * no longer washes them out with bright additive colors.
     */
    public function applyTargetGlow():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null) return;
        var world:Dynamic = g.world;

        try {
            if (suppressTargetGlow) {
                world.avtMCT = new ColorTransform(0, 0, 0, 0, 0, 0, 0, 0);
                world.avtPCT = new ColorTransform(0, 0, 0, 0, 0, 0, 0, 0);
                if (world.myAvatar != null && world.myAvatar.target != null && world.myAvatar.target.pMC != null) {
                    var pMC:Dynamic = world.myAvatar.target.pMC;
                    if (pMC.totalTransform != null) {
                        pMC.totalTransform.redOffset = 0;
                        pMC.totalTransform.greenOffset = 0;
                        pMC.totalTransform.blueOffset = 0;
                    }
                    if (pMC.clampedTransform != null) {
                        pMC.clampedTransform.redOffset = 0;
                        pMC.clampedTransform.greenOffset = 0;
                        pMC.clampedTransform.blueOffset = 0;
                    }
                    if (pMC.transform != null) {
                        pMC.transform.colorTransform = new ColorTransform();
                    }
                }
            } else {
                world.avtMCT = new ColorTransform(0, 0, 0, 0, 30, 0, 0, 0);
                world.avtPCT = new ColorTransform(0, 0, 0, 0, 40, 40, 70, 0);
                if (world.myAvatar != null && world.myAvatar.target != null && world.myAvatar.target.pMC != null) {
                    var tgt:Dynamic = world.myAvatar.target;
                    var ct:Dynamic = (tgt.isMonster == true) ? world.avtMCT : world.avtPCT;
                    if (tgt.pMC.modulateColor != null) {
                        tgt.pMC.modulateColor(ct, "+");
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    public function set_lagKiller(v:Bool):Bool {
        lagKiller = v;
        ApiConfig.setBool("api_lag_killer", v);
        apply();
        ApiLogger.info("Visual", "Lag Killer: " + (v ? "Enabled" : "Disabled"));
        return lagKiller;
    }

    public function set_hidePlayers(v:Bool):Bool {
        hidePlayers = v;
        ApiConfig.setBool("api_hide_players", v);
        apply();
        return hidePlayers;
    }

    private inline function get_disableSkillAnims():Bool return (skillAnimMode == 2);
    private function set_disableSkillAnims(v:Bool):Bool {
        skillAnimMode = v ? 2 : 0;
        return v;
    }

    public function set_skillAnimMode(v:Int):Int {
        skillAnimMode = v;
        ApiConfig.setInt("api_skill_anim_mode", v);
        ApiConfig.setBool("api_disable_skill_anims", v == 2);
        apply();
        return skillAnimMode;
    }

    public function set_optimizeSpellFX(v:Bool):Bool {
        optimizeSpellFX = v;
        ApiConfig.setBool("api_optimize_spell_fx", v);
        return optimizeSpellFX;
    }

    public function set_disableSpellFilters(v:Bool):Bool {
        disableSpellFilters = v;
        ApiConfig.setBool("api_disable_spell_filters", v);
        return disableSpellFilters;
    }

    public function set_friendlySelfOnlyFX(v:Bool):Bool {
        friendlySelfOnlyFX = v;
        ApiConfig.setBool("api_friendly_self_only_fx", v);
        return friendlySelfOnlyFX;
    }

    public function set_hostilePrimaryOnlyFX(v:Bool):Bool {
        hostilePrimaryOnlyFX = v;
        ApiConfig.setBool("api_hostile_primary_only_fx", v);
        return hostilePrimaryOnlyFX;
    }

    public inline function needsTargetFilter():Bool {
        return friendlySelfOnlyFX || hostilePrimaryOnlyFX;
    }

    public function set_maxConcurrentSpells(v:Int):Int {
        maxConcurrentSpells = v;
        ApiConfig.setInt("api_max_concurrent_spells", v);
        return maxConcurrentSpells;
    }

    public function cycleSkillAnimMode():Int {
        skillAnimMode = (skillAnimMode + 1) % 3;
        return skillAnimMode;
    }

    public function cycleMaxConcurrentSpells():Int {
        var presets = [4, 6, 8, 12, 0];
        var idx = presets.indexOf(maxConcurrentSpells);
        if (idx == -1) idx = 1; // default 6
        var nextIdx = (idx + 1) % presets.length;
        maxConcurrentSpells = presets[nextIdx];
        return maxConcurrentSpells;
    }

    public function getSkillAnimModeLabel():String {
        return switch (skillAnimMode) {
            case 0: "All Spells";
            case 1: "Self Only";
            case 2: "Disabled";
            default: "All Spells";
        };
    }

    public function getMaxConcurrentSpellsLabel():String {
        return switch (maxConcurrentSpells) {
            case 0: "Unlimited";
            default: maxConcurrentSpells + " Spells";
        };
    }

    public function set_disableMonsterAnims(v:Bool):Bool {
        disableMonsterAnims = v;
        ApiConfig.setBool("api_disable_mon_anims", v);
        apply();
        return disableMonsterAnims;
    }

    public function set_disableWeaponAnims(v:Bool):Bool {
        disableWeaponAnims = v;
        ApiConfig.setBool("api_disable_wep_anims", v);
        apply();
        return disableWeaponAnims;
    }

    public function set_disableGround(v:Bool):Bool {
        disableGround = v;
        ApiConfig.setBool("api_disable_ground", v);
        apply();
        return disableGround;
    }

    public function set_hideMonsters(v:Bool):Bool {
        hideMonsters = v;
        ApiConfig.setBool("api_hide_monsters", v);
        apply();
        return hideMonsters;
    }

    public function set_cachePlayers(v:Bool):Bool {
        cachePlayers = v;
        ApiConfig.setBool("api_cache_players", v);
        apply();
        return cachePlayers;
    }

    public function set_cacheMonsters(v:Bool):Bool {
        cacheMonsters = v;
        ApiConfig.setBool("api_cache_monsters", v);
        apply();
        return cacheMonsters;
    }

    public function set_cleanArena(v:Bool):Bool {
        cleanArena = v;
        ApiConfig.setBool("api_clean_arena", v);
        apply();
        return cleanArena;
    }

    /**
     * Applies native AQLite preference flags and updates existing display MovieClips.
     */
    public function apply():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null) return;

        var effHidePlayers = lagKiller || hidePlayers;
        var effDisSkills = lagKiller || (skillAnimMode == 2);
        var effAnimSelf = (skillAnimMode == 1);
        var effDisMonAnims = lagKiller || disableMonsterAnims;
        var effDisWepAnims = lagKiller || disableWeaponAnims;
        var effDisGround = lagKiller || disableGround;

        // 1. Update native AQLite Preferences
        try {
            if (g.litePreference != null && g.litePreference.data != null) {
                var d = g.litePreference.data;
                d.bHidePlayers = effHidePlayers;
                d.bDisSkillAnim = effDisSkills || effAnimSelf;
                d.bDisMonAnim = effDisMonAnims;
                d.bDisWepAnim = effDisWepAnims;
                d.bDisGround = effDisGround;
                d.bHideMons = hideMonsters;
                d.bCachePlayers = cachePlayers;

                if (d.dOptions == null) {
                    d.dOptions = {};
                }
                Reflect.setField(d.dOptions, "showNames", showNames);
                Reflect.setField(d.dOptions, "showShadows", showShadows);
                Reflect.setField(d.dOptions, "animSelf", effAnimSelf);

                if (g.litePreference.flush != null) {
                    g.litePreference.flush();
                }
            }
        } catch (_:Dynamic) {}

        // 2. Suppress or restore native target color wash
        applyTargetGlow();

        // 3. Update live display list
        applyDisplayListOnly();

        // 4. Ensure world.CHARS listener is hooked
        ensureCharsHook();
    }

    /**
     * Fast sweep over display list to hide/restore MovieClips without rewriting disk prefs.
     */
    public function applyDisplayListOnly():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null) return;
        var world:Dynamic = g.world;

        // Target Glow Check (re-apply if World reinitialized on room/map change)
        if (suppressTargetGlow) {
            try {
                if (world.avtMCT != null && (world.avtMCT.redOffset != 0 || world.avtPCT.blueOffset != 0)) {
                    applyTargetGlow();
                }
            } catch (_:Dynamic) {}
        }

        var effHidePlayers = lagKiller || hidePlayers;
        var effDisSkills = lagKiller || (skillAnimMode == 2);
        var effDisMonAnims = lagKiller || disableMonsterAnims;

        // A. Player Avatars (self and other players)
        try {
            if (world.avatars != null) {
                var avList:Array<Dynamic> = cast world.avatars;
                var myAv = world.myAvatar;
                for (av in avList) {
                    if (av == null || av.pMC == null) continue;
                    var pMC:Dynamic = av.pMC;
                    var isMe:Bool = (av == myAv);

                    if (pMC.mcChar != null) {
                        if (!isMe) {
                            pMC.mcChar.visible = !effHidePlayers;
                        }
                        // Bitmap Caching on avatar vector graphics
                        if (pMC.mcChar.cacheAsBitmap != cachePlayers) {
                            pMC.mcChar.cacheAsBitmap = cachePlayers;
                            try {
                                pMC.mcChar.cacheAsBitmapMatrix = cachePlayers ? new Matrix() : null;
                            } catch (_:Dynamic) {}
                        }
                    }

                    if (!isMe) {
                        if (pMC.shadow != null) {
                            pMC.shadow.visible = (!effHidePlayers) || showShadows;
                        }
                        if (pMC.pname != null) {
                            pMC.pname.visible = (!effHidePlayers) || showNames;
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        // B. Monsters
        try {
            if (world.monsters != null) {
                var monList:Array<Dynamic> = cast world.monsters;
                for (m in monList) {
                    if (m == null || m.pMC == null) continue;
                    var pMC:Dynamic = m.pMC;
                    if (effDisMonAnims && g.movieClipStopAll != null && pMC.mcChar != null) {
                        try { g.movieClipStopAll(pMC.mcChar); } catch (_:Dynamic) {}
                    }
                    if (pMC.mcChar != null) {
                        if (hideMonsters) {
                            pMC.mcChar.visible = false;
                        } else if (!hideMonsters && !pMC.mcChar.visible) {
                            pMC.mcChar.visible = true;
                        }
                        // Bitmap Caching on monster vector graphics
                        if (pMC.mcChar.cacheAsBitmap != cacheMonsters) {
                            pMC.mcChar.cacheAsBitmap = cacheMonsters;
                            try {
                                pMC.mcChar.cacheAsBitmapMatrix = cacheMonsters ? new Matrix() : null;
                            } catch (_:Dynamic) {}
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}

        // C. Skill FX Queue
        if (effDisSkills) {
            try {
                if (world.clearSpFXQueue != null) world.clearSpFXQueue();
            } catch (_:Dynamic) {}
        }

        // D. Clean Arena / Map Background
        try {
            if (world.map != null) {
                world.map.visible = !cleanArena;
            }
        } catch (_:Dynamic) {}
    }

    private function ensureCharsHook():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null || g.world.CHARS == null) return;
        var chars:Dynamic = g.world.CHARS;

        if (chars == _hookedChars) return;

        if (_hookedChars != null) {
            try {
                _hookedChars.removeEventListener(Event.ADDED, onCharAdded);
            } catch (_:Dynamic) {}
        }

        _hookedChars = chars;
        try {
            _hookedChars.addEventListener(Event.ADDED, onCharAdded, false, 0, true);
        } catch (_:Dynamic) {}
    }

    private function onCharAdded(e:Event):Void {
        var child:Dynamic = e.target;
        if (child == null || child == _hookedChars) return;

        try {
            if (child.parent != _hookedChars) return;
        } catch (_:Dynamic) {
            return;
        }

        if (!isSpellClip(child)) return;

        // Tag caster and multi-target status synchronously while castSpellFX is active
        tagSpellCaster(child);

        handleSpellAdded(child);
    }

    /**
     * Resolves and tags the current active caster and multi-target status onto the spell clip.
     * Executes synchronously during castSpellFX while cAvt.pMC.spFX is populated.
     */
    private function tagSpellCaster(spell:Dynamic):Void {
        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world == null) return;

        var casterAvt:Dynamic = null;
        var isMulti:Bool = false;

        // Check player avatars in room
        if (world.avatars != null) {
            var avList:Array<Dynamic> = cast world.avatars;
            for (av in avList) {
                if (av != null && av.pMC != null && av.pMC.spFX != null) {
                    var s:Dynamic = av.pMC.spFX;
                    if (s.strl != null && s.strl != "") {
                        casterAvt = av;
                        if (s.avts != null && s.avts.length > 1) {
                            isMulti = true;
                        }
                        break;
                    }
                }
            }
        }

        // Fallback: check monster avatars
        if (casterAvt == null && world.monsters != null) {
            var monList:Array<Dynamic> = cast world.monsters;
            for (m in monList) {
                if (m != null && m.pMC != null && m.pMC.spFX != null) {
                    var s:Dynamic = m.pMC.spFX;
                    if (s.strl != null && s.strl != "") {
                        casterAvt = m;
                        if (s.avts != null && s.avts.length > 1) {
                            isMulti = true;
                        }
                        break;
                    }
                }
            }
        }

        try {
            Reflect.setField(spell, "_caster", casterAvt);
            Reflect.setField(spell, "_isMulti", isMulti);
        } catch (_:Dynamic) {}
    }

    public static function isSpellClip(child:Dynamic):Bool {
        if (child == null) return false;
        try {
            // Avatars and monsters have mcChar / pAV / pname
            if (Reflect.hasField(child, "mcChar") || Reflect.hasField(child, "pAV") || Reflect.hasField(child, "pname")) {
                return false;
            }
            if (Reflect.field(child, "isHouseItem") == true) return false;

            // Spell indicators
            if (Reflect.hasField(child, "fxDeadline")) return true;
            if (Reflect.field(child, "isSpell") == true) return true;
            if (Reflect.field(child, "strl") != null) return true;

            var qName:String = untyped __global__["flash.utils.getQualifiedClassName"](child);
            if (qName != null) {
                if (qName.indexOf("sp_") == 0 || qName.indexOf("sp") == 0 || qName.indexOf("lit1") == 0 || qName.indexOf("Spell") != -1) {
                    return true;
                }
            }
        } catch (_:Dynamic) {}
        return false;
    }

    /**
     * Determines whether this spell instance should be suppressed based on user toggles.
     */
    private function shouldSuppressTarget(spell:Dynamic):Bool {
        var tMC:Dynamic = spell.tMC;
        if (tMC == null) return false; // Don't suppress non-targeted / ambient effects

        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world == null) return false;
        var myAv:Dynamic = world.myAvatar;
        if (myAv == null) return false;

        var isMulti:Bool = (Reflect.field(spell, "_isMulti") == true);

        var isMonster:Bool = (tMC.isMonster == true) || (tMC.pAV != null && tMC.pAV.isMonster == true);
        var isHostile:Bool = isMonster;
        var isFriendly:Bool = !isMonster;

        // In PvP maps, teammates are friendly and opponent players are hostile
        if (world.bPvP == true && !isMonster && tMC.pAV != null && myAv.dataLeaf != null && tMC.pAV.dataLeaf != null) {
            var myTeam = myAv.dataLeaf.pvpTeam;
            var targetTeam = tMC.pAV.dataLeaf.pvpTeam;
            if (myTeam != null && targetTeam != null && myTeam > -1 && targetTeam > -1) {
                if (myTeam == targetTeam) {
                    isFriendly = true;
                    isHostile = false;
                } else {
                    isFriendly = false;
                    isHostile = true;
                }
            }
        }

        // 1. Friendly AoE: Caster Only
        // Multi-target friendly buffs play only on whoever cast them:
        // for myself if I cast, or for themselves if someone else cast!
        if (friendlySelfOnlyFX && isFriendly) {
            if (isMulti) {
                var caster:Dynamic = Reflect.field(spell, "_caster");
                if (caster != null && caster.pMC != null) {
                    // Only show on the caster; suppress duplicate visuals on other allies
                    if (tMC != caster.pMC) {
                        return true;
                    }
                } else {
                    // Fallback if caster could not be resolved: show only on myself
                    var isMe:Bool = (myAv.pMC != null && tMC == myAv.pMC) || (tMC.pAV != null && (tMC.pAV.isMyAvatar == true || tMC.pAV == myAv));
                    if (!isMe) {
                        return true;
                    }
                }
            }
        }

        // 2. Hostile AoE: Primary Target Only
        // Multi-target hostile attack animations play only on the primary target
        if (hostilePrimaryOnlyFX && isHostile) {
            if (isMulti) {
                var primMC:Dynamic = (myAv.target != null) ? myAv.target.pMC : null;
                if (primMC != null && tMC != primMC) {
                    return true;
                }
            }
        }

        return false;
    }

    private function suppressSpell(spell:Dynamic):Void {
        try {
            spell.visible = false;
            try { spell.removeEventListener(Event.ADDED, onSpellChildAdded); } catch (_:Dynamic) {}
            if (Reflect.hasField(spell, "stop")) spell.stop();
            if (Reflect.hasField(spell, "killSpell")) spell.killSpell();
            if (spell.parent != null) spell.parent.removeChild(spell);
        } catch (_:Dynamic) {}
    }

    public function applySpellFilters(clip:DisplayObject):Void {
        if (clip == null) return;
        if (disableSpellFilters) {
            stripFilters(clip);
        } else if (optimizeSpellFX) {
            optimizeFilters(clip);
        }
    }

    public static function stripFilters(clip:DisplayObject):Void {
        if (clip == null) return;
        try {
            if (clip.filters != null && clip.filters.length > 0) {
                clip.filters = [];
            }
        } catch (_:Dynamic) {}

        if (Std.isOfType(clip, DisplayObjectContainer)) {
            var container:DisplayObjectContainer = cast clip;
            try {
                var count = container.numChildren;
                for (i in 0...count) {
                    var child = container.getChildAt(i);
                    if (child != null) {
                        stripFilters(child);
                    }
                }
            } catch (_:Dynamic) {}
        }
    }

    private function handleSpellAdded(spell:Dynamic):Void {
        var effAnimMode = lagKiller ? 2 : skillAnimMode;

        // Mode 2: Disabled -> suppress all spells immediately
        if (effAnimMode == 2) {
            suppressSpell(spell);
            return;
        }

        if (needsTargetFilter()) {
            if (spell.tMC != null) {
                if (shouldSuppressTarget(spell)) {
                    suppressSpell(spell);
                    return;
                }
                applySpellFilters(cast spell);
            } else {
                // Target is assigned immediately after addChild in World.castSpellFX
                // Keep hidden until target check resolves to prevent 1-frame flashes
                spell.visible = false;
                var checked:Bool = false;
                var enterHandler:Dynamic = null;
                var checkTarget = function():Void {
                    if (checked) return;
                    checked = true;
                    if (enterHandler != null) {
                        try { spell.removeEventListener(Event.ENTER_FRAME, enterHandler); } catch (_:Dynamic) {}
                    }
                    if (spell.parent == null) return;
                    if (shouldSuppressTarget(spell)) {
                        suppressSpell(spell);
                    } else {
                        spell.visible = true;
                        applySpellFilters(cast spell);
                    }
                };

                enterHandler = function(e:Event):Void {
                    checkTarget();
                };
                try {
                    spell.addEventListener(Event.ENTER_FRAME, enterHandler, false, 0, true);
                } catch (_:Dynamic) {}

                try {
                    untyped __global__["flash.utils.setTimeout"](checkTarget, 1);
                } catch (_:Dynamic) {
                    ApiTime.delay(1, checkTarget);
                }
            }
        } else {
            applySpellFilters(cast spell);
        }

        // Catch any sub-children added on later timeline keyframes
        try {
            spell.addEventListener(Event.ADDED, onSpellChildAdded, false, 0, true);
        } catch (_:Dynamic) {}
    }

    private function onSpellChildAdded(e:Event):Void {
        var sub:Dynamic = e.target;
        if (sub != null && sub != e.currentTarget && Std.isOfType(sub, DisplayObject)) {
            applySpellFilters(cast sub);
        }
    }

    /**
     * Recursively optimizes spell filters to 1x pass (BitmapFilterQuality.LOW)
     * and clamps large blur radii while preserving colors, alphas, tints, and glows.
     */
    public static function optimizeFilters(clip:DisplayObject):Void {
        if (clip == null) return;
        try {
            var filters:Array<Dynamic> = clip.filters;
            if (filters != null && filters.length > 0) {
                var changed:Bool = false;
                for (i in 0...filters.length) {
                    var f:Dynamic = filters[i];
                    if (f == null) continue;

                    // Lower filter quality to 1x (BitmapFilterQuality.LOW)
                    if (Reflect.hasField(f, "quality")) {
                        var q:Int = Reflect.field(f, "quality");
                        if (q > 1) {
                            Reflect.setField(f, "quality", 1);
                            changed = true;
                        }
                    }

                    // Clamp blur radius to prevent expensive 16px+ convolution kernels
                    if (Reflect.hasField(f, "blurX")) {
                        var bx:Float = Reflect.field(f, "blurX");
                        if (bx > 6.0) {
                            Reflect.setField(f, "blurX", 6.0);
                            changed = true;
                        }
                    }
                    if (Reflect.hasField(f, "blurY")) {
                        var by:Float = Reflect.field(f, "blurY");
                        if (by > 6.0) {
                            Reflect.setField(f, "blurY", 6.0);
                            changed = true;
                        }
                    }
                }
                if (changed) {
                    clip.filters = cast filters;
                }
            }
        } catch (_:Dynamic) {}

        if (Std.isOfType(clip, DisplayObjectContainer)) {
            var container:DisplayObjectContainer = cast clip;
            try {
                var count = container.numChildren;
                for (i in 0...count) {
                    var child = container.getChildAt(i);
                    if (child != null) {
                        optimizeFilters(child);
                    }
                }
            } catch (_:Dynamic) {}
        }
    }

    public function destroy():Void {
        if (_sweepTimer != null) {
            _sweepTimer.stop();
            _sweepTimer = null;
        }
        if (_hookedChars != null) {
            try {
                _hookedChars.removeEventListener(Event.ADDED, onCharAdded);
            } catch (_:Dynamic) {}
            _hookedChars = null;
        }
    }
}
