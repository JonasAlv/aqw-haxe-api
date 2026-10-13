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
import com.aqwapi.events.GameEvent;
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

    // Hide Player Accessories & Equipment
    public var hidePlayerCapes(default, set):Bool = false;
    public var hidePlayerHelms(default, set):Bool = false;
    public var hidePlayerWeapons(default, set):Bool = false;

    // Show Equipped Class Outfit Only (strip costume / cosmetic overrides)
    public var showClassOutfitOnly(default, set):Bool = false;

    // Zero-Delay Instant Animation Freezing
    public var freezeAllAnimations(default, set):Bool = false;

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
        hidePlayerCapes = ApiConfig.getBool("api_hide_player_capes", false);
        hidePlayerHelms = ApiConfig.getBool("api_hide_player_helms", false);
        hidePlayerWeapons = ApiConfig.getBool("api_hide_player_weapons", false);
        showClassOutfitOnly = ApiConfig.getBool("api_show_class_outfit_only", false);
        freezeAllAnimations = ApiConfig.getBool("api_freeze_all_animations", false);

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

        try {
            Api.dispatcher.addEventListener(GameEvent.ZONE_ENTERED, onZoneEntered);
        } catch (_:Dynamic) {}
    }

    private function onZoneEntered(e:Event):Void {
        if (isActive()) {
            apply();
        }
    }

    public inline function isActive():Bool {
        return lagKiller || hidePlayers || (skillAnimMode != 0) || optimizeSpellFX || disableSpellFilters || friendlySelfOnlyFX || hostilePrimaryOnlyFX || disableMonsterAnims || disableWeaponAnims || disableGround || hideMonsters || cleanArena || suppressTargetGlow || cachePlayers || cacheMonsters || hidePlayerCapes || hidePlayerHelms || hidePlayerWeapons || showClassOutfitOnly || freezeAllAnimations;
    }

    public function set_hidePlayerCapes(v:Bool):Bool {
        hidePlayerCapes = v;
        ApiConfig.setBool("api_hide_player_capes", v);
        apply();
        return hidePlayerCapes;
    }

    public function set_hidePlayerHelms(v:Bool):Bool {
        hidePlayerHelms = v;
        ApiConfig.setBool("api_hide_player_helms", v);
        apply();
        return hidePlayerHelms;
    }

    public function set_hidePlayerWeapons(v:Bool):Bool {
        hidePlayerWeapons = v;
        ApiConfig.setBool("api_hide_player_weapons", v);
        apply();
        return hidePlayerWeapons;
    }

    public function set_showClassOutfitOnly(v:Bool):Bool {
        showClassOutfitOnly = v;
        ApiConfig.setBool("api_show_class_outfit_only", v);
        apply();
        return showClassOutfitOnly;
    }

    public function set_freezeAllAnimations(v:Bool):Bool {
        freezeAllAnimations = v;
        ApiConfig.setBool("api_freeze_all_animations", v);
        apply();
        return freezeAllAnimations;
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
        ensureCharsHook();
        return optimizeSpellFX;
    }

    public function set_disableSpellFilters(v:Bool):Bool {
        disableSpellFilters = v;
        ApiConfig.setBool("api_disable_spell_filters", v);
        ensureCharsHook();
        return disableSpellFilters;
    }

    public function set_friendlySelfOnlyFX(v:Bool):Bool {
        friendlySelfOnlyFX = v;
        ApiConfig.setBool("api_friendly_self_only_fx", v);
        ensureCharsHook();
        return friendlySelfOnlyFX;
    }

    public function set_hostilePrimaryOnlyFX(v:Bool):Bool {
        hostilePrimaryOnlyFX = v;
        ApiConfig.setBool("api_hostile_primary_only_fx", v);
        ensureCharsHook();
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

        // Native hideAllCapes setting in World
        try {
            if (g.world != null) {
                g.world.hideAllCapes = (hidePlayerCapes || lagKiller);
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

        var effDisSkills = lagKiller || (skillAnimMode == 2);

        // A. Player Avatars (self and other players)
        try {
            var avList:Array<Dynamic> = getAllAvatars(world);
            for (av in avList) {
                applyAvatarVisual(av);
            }
        } catch (_:Dynamic) {}

        // B. Monsters
        try {
            var monList:Array<Dynamic> = getAllMonsters(world);
            for (m in monList) {
                applyMonsterVisual(m);
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

    /**
     * Instantly configures an avatar's visual appearance (capes, helmets, weapons, class transmog, caching, freezing).
     * Intercepts avatars with zero delay on entry or equipment attachment.
     */
    public function applyAvatarVisual(avOrChild:Dynamic):Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null || avOrChild == null) return;
        var world:Dynamic = g.world;
        var myAv:Dynamic = world.myAvatar;

        var av:Dynamic = null;
        var pMC:Dynamic = null;

        if (Reflect.hasField(avOrChild, "pMC")) {
            av = avOrChild;
            pMC = av.pMC;
        } else if (Reflect.hasField(avOrChild, "pAV")) {
            pMC = avOrChild;
            av = pMC.pAV;
        } else if (Reflect.hasField(avOrChild, "mcChar")) {
            pMC = avOrChild;
            av = (pMC.pAV != null) ? pMC.pAV : null;
        }

        if (pMC == null) return;
        var isMe:Bool = (av != null && myAv != null && av == myAv) || (myAv != null && pMC == myAv.pMC);
        var effHidePlayers = lagKiller || hidePlayers;

        if (pMC.mcChar != null) {
            if (!isMe) {
                pMC.mcChar.visible = !effHidePlayers;

                // 1. Hide Player Capes
                if (hidePlayerCapes || lagKiller) {
                    if (pMC.mcChar.cape != null) pMC.mcChar.cape.visible = false;
                } else if (pMC.mcChar.cape != null) {
                    var showC:Bool = (av != null && av.dataLeaf != null && Reflect.hasField(av.dataLeaf, "showCloak")) ? (av.dataLeaf.showCloak == true) : true;
                    pMC.mcChar.cape.visible = showC;
                }

                // 2. Hide Player Helmets & restore default hairstyle
                if (hidePlayerHelms || lagKiller) {
                    if (pMC.mcChar.head != null && pMC.mcChar.head.helm != null) {
                        pMC.mcChar.head.helm.visible = false;
                    }
                    if (pMC.mcChar.head != null && pMC.mcChar.head.hair != null) {
                        pMC.mcChar.head.hair.visible = true;
                    }
                    if (pMC.mcChar.backhair != null) {
                        pMC.mcChar.backhair.visible = (pMC.bBackHair == true);
                    }
                } else if (pMC.mcChar.head != null) {
                    var showH:Bool = (av != null && av.dataLeaf != null && Reflect.hasField(av.dataLeaf, "showHelm")) ? (av.dataLeaf.showHelm == true) : true;
                    if (pMC.mcChar.head.helm != null) pMC.mcChar.head.helm.visible = showH;
                    if (pMC.mcChar.head.hair != null) pMC.mcChar.head.hair.visible = !showH;
                    if (pMC.mcChar.backhair != null) pMC.mcChar.backhair.visible = (!showH && pMC.bBackHair == true);
                }

                // 3. Hide Player Weapons
                if (hidePlayerWeapons || lagKiller) {
                    if (pMC.mcChar.weapon != null) pMC.mcChar.weapon.visible = false;
                    if (pMC.mcChar.weaponOff != null) pMC.mcChar.weaponOff.visible = false;
                    if (pMC.mcChar.weaponFist != null) pMC.mcChar.weaponFist.visible = false;
                    if (pMC.mcChar.weaponFistOff != null) pMC.mcChar.weaponFistOff.visible = false;
                    if (pMC.mcChar.shield != null) pMC.mcChar.shield.visible = false;
                } else {
                    // Shield is an unused placeholder in mcChar FLA that renders a gray circle - keep it hidden!
                    if (pMC.mcChar.shield != null) pMC.mcChar.shield.visible = false;

                    var isDual:Bool = false;
                    var isGauntlet:Bool = false;
                    try {
                        if (av != null && Reflect.hasField(av, "getItemByEquipSlot")) {
                            var wItem:Dynamic = av.getItemByEquipSlot("Weapon");
                            if (wItem != null) {
                                if (wItem.sType == "Dagger") isDual = true;
                                if (wItem.sType == "Gauntlet") isGauntlet = true;
                            }
                        }
                    } catch (_:Dynamic) {}

                    if (pMC.mcChar.weapon != null) pMC.mcChar.weapon.visible = !isGauntlet;
                    if (pMC.mcChar.weaponOff != null) pMC.mcChar.weaponOff.visible = isDual;
                    if (pMC.mcChar.weaponFist != null) pMC.mcChar.weaponFist.visible = isGauntlet;
                    if (pMC.mcChar.weaponFistOff != null) pMC.mcChar.weaponFistOff.visible = isGauntlet;
                }

                // 4. Show Class Outfit Only (strips cosmetic costume transmog)
                if (showClassOutfitOnly) {
                    if (av != null && av.objData != null && av.objData.eqp != null) {
                        var eqp:Dynamic = av.objData.eqp;
                        if (eqp.co != null) {
                            eqp._savedCo = eqp.co;
                            eqp.co = null;
                            if (eqp.ar != null && pMC.loadArmorPieces != null) {
                                try {
                                    if (pMC.loadClass != null) pMC.loadClass(eqp.ar.sFile, eqp.ar.sLink);
                                    pMC.loadArmorPieces(eqp.ar.sLink);
                                } catch (_:Dynamic) {}
                            }
                        }
                    }
                } else {
                    if (av != null && av.objData != null && av.objData.eqp != null) {
                        var eqp:Dynamic = av.objData.eqp;
                        if (eqp._savedCo != null) {
                            eqp.co = eqp._savedCo;
                            eqp._savedCo = null;
                            if (pMC.loadArmorPieces != null) {
                                try {
                                    if (pMC.loadArmor != null) pMC.loadArmor(eqp.co.sFile, eqp.co.sLink);
                                    pMC.loadArmorPieces(eqp.co.sLink);
                                } catch (_:Dynamic) {}
                            }
                        }
                    }
                }
            }

            // 5. Bitmap Caching (both self and other players)
            if (pMC.mcChar.cacheAsBitmap != cachePlayers) {
                pMC.mcChar.cacheAsBitmap = cachePlayers;
                try {
                    pMC.mcChar.cacheAsBitmapMatrix = cachePlayers ? new Matrix() : null;
                } catch (_:Dynamic) {}
            }

            // 6. Freeze Animations (Zero Delay)
            if (freezeAllAnimations || lagKiller) {
                if (g.movieClipStopAll != null) {
                    try { g.movieClipStopAll(pMC.mcChar); } catch (_:Dynamic) {}
                } else if (pMC.mcChar.stop != null) {
                    try { pMC.mcChar.stop(); } catch (_:Dynamic) {}
                }
                if (pMC.mcChar.weapon != null) {
                    if (g.movieClipStopAll != null) try { g.movieClipStopAll(pMC.mcChar.weapon); } catch (_:Dynamic) {}
                    stripFilters(pMC.mcChar.weapon);
                }
                if (pMC.mcChar.weaponOff != null) {
                    if (g.movieClipStopAll != null) try { g.movieClipStopAll(pMC.mcChar.weaponOff); } catch (_:Dynamic) {}
                    stripFilters(pMC.mcChar.weaponOff);
                }
                hookFreezeTimeline(pMC);
            } else {
                unhookFreezeTimeline(pMC);
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

        hookEquipmentAdded(pMC);
    }

    /**
     * Instantly configures a monster's visual appearance (caching, freezing, visibility) with zero delay.
     */
    public function applyMonsterVisual(mOrChild:Dynamic):Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null || mOrChild == null) return;
        var pMC:Dynamic = (Reflect.hasField(mOrChild, "pMC")) ? mOrChild.pMC : mOrChild;
        if (pMC == null || pMC.mcChar == null) return;

        var effDisMonAnims = lagKiller || disableMonsterAnims || freezeAllAnimations;

        if (effDisMonAnims) {
            if (g.movieClipStopAll != null) {
                try { g.movieClipStopAll(pMC.mcChar); } catch (_:Dynamic) {}
            } else if (pMC.mcChar.stop != null) {
                try { pMC.mcChar.stop(); } catch (_:Dynamic) {}
            }
            hookFreezeTimeline(pMC);
        } else {
            unhookFreezeTimeline(pMC);
        }

        if (hideMonsters) {
            pMC.mcChar.visible = false;
        } else if (!hideMonsters && !pMC.mcChar.visible) {
            pMC.mcChar.visible = true;
        }

        if (pMC.mcChar.cacheAsBitmap != cacheMonsters) {
            pMC.mcChar.cacheAsBitmap = cacheMonsters;
            try {
                pMC.mcChar.cacheAsBitmapMatrix = cacheMonsters ? new Matrix() : null;
            } catch (_:Dynamic) {}
        }

        hookEquipmentAdded(pMC);
    }

    private function hookFreezeTimeline(pMC:Dynamic):Void {
        if (pMC == null || pMC.mcChar == null) return;
        var mc:Dynamic = pMC.mcChar;
        try {
            if (Reflect.field(mc, "_freezeHooked") == true) return;
            Reflect.setField(mc, "_freezeHooked", true);
            mc.addEventListener(Event.ENTER_FRAME, onCharFreezeFrame, false, 0, true);
        } catch (_:Dynamic) {}
    }

    private function unhookFreezeTimeline(pMC:Dynamic):Void {
        if (pMC == null || pMC.mcChar == null) return;
        var mc:Dynamic = pMC.mcChar;
        try {
            if (Reflect.field(mc, "_freezeHooked") != true) return;
            Reflect.setField(mc, "_freezeHooked", false);
            mc.removeEventListener(Event.ENTER_FRAME, onCharFreezeFrame);
        } catch (_:Dynamic) {}
    }

    private function onCharFreezeFrame(e:Event):Void {
        if (!(freezeAllAnimations || lagKiller || disableMonsterAnims)) return;
        var mc:Dynamic = e.currentTarget;
        if (mc == null) return;
        try {
            if (mc.currentFrame != 1) {
                mc.gotoAndStop(1);
            } else {
                mc.stop();
            }
        } catch (_:Dynamic) {}
    }

    private function hookEquipmentAdded(pMC:Dynamic):Void {
        if (pMC == null) return;
        try {
            if (Reflect.field(pMC, "_equipHooked") == true) return;
            Reflect.setField(pMC, "_equipHooked", true);
            pMC.addEventListener(Event.ADDED, onEquipmentAdded, false, 0, true);
        } catch (_:Dynamic) {}
    }

    private function onEquipmentAdded(e:Event):Void {
        var target:Dynamic = e.target;
        var current:Dynamic = e.currentTarget;
        if (target == null || current == null || target == current) return;

        try {
            if (Reflect.hasField(current, "mcChar") || Reflect.hasField(current, "pAV")) {
                applyAvatarVisual(current);
            } else if (isMonsterTarget(current) || (current.hasOwnProperty("isMonster") && current.isMonster == true)) {
                applyMonsterVisual(current);
            }
        } catch (_:Dynamic) {}
    }

    private function ensureCharsHook():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        if (g == null || g.world == null || g.world.CHARS == null) return;
        var chars:Dynamic = g.world.CHARS;

        if (chars != _hookedChars) {
            if (_hookedChars != null) {
                try {
                    _hookedChars.removeEventListener(Event.ADDED, onCharAdded);
                    _hookedChars.removeEventListener(Event.ENTER_FRAME, onPendingEnterFrame);
                } catch (_:Dynamic) {}
            }
            _hookedChars = chars;
        }

        try {
            _hookedChars.addEventListener(Event.ADDED, onCharAdded, false, 0, false);
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

        // 1. Monster check
        if (isMonsterTarget(child) || (child.hasOwnProperty("isMonster") && child.isMonster == true)) {
            applyMonsterVisual(child);
            return;
        }

        // 2. Avatar check
        if (Reflect.hasField(child, "mcChar") || Reflect.hasField(child, "pAV") || Reflect.hasField(child, "pname")) {
            applyAvatarVisual(child);
            return;
        }

        // 3. Spell Clip check
        if (isSpellClip(child)) {
            handleSpellAdded(child);
            return;
        }
    }

    /**
     * Safely retrieves all player avatars from world without throwing Dictionary coercion errors.
     */
    public static function getAllAvatars(world:Dynamic):Array<Dynamic> {
        var list:Array<Dynamic> = [];
        if (world == null) return list;

        if (world.avatars != null) {
            var raw:Dynamic = world.avatars;
            try {
                for (k in Reflect.fields(raw)) {
                    var av:Dynamic = Reflect.field(raw, k);
                    if (av != null && list.indexOf(av) == -1) {
                        list.push(av);
                    }
                }
            } catch (_:Dynamic) {}
        }

        if (world.myAvatar != null && list.indexOf(world.myAvatar) == -1) {
            list.push(world.myAvatar);
        }

        return list;
    }

    /**
     * Safely retrieves all monsters from world without throwing Vector coercion errors.
     */
    public static function getAllMonsters(world:Dynamic):Array<Dynamic> {
        var list:Array<Dynamic> = [];
        if (world == null || world.monsters == null) return list;
        var raw:Dynamic = world.monsters;

        try {
            var len:Int = Reflect.hasField(raw, "length") ? Reflect.field(raw, "length") : 0;
            if (len > 0) {
                for (i in 0...len) {
                    var m:Dynamic = raw[i];
                    if (m != null && list.indexOf(m) == -1) {
                        list.push(m);
                    }
                }
            }
        } catch (_:Dynamic) {}

        if (list.length == 0) {
            try {
                for (k in Reflect.fields(raw)) {
                    var m:Dynamic = Reflect.field(raw, k);
                    if (m != null && list.indexOf(m) == -1) {
                        list.push(m);
                    }
                }
            } catch (_:Dynamic) {}
        }

        return list;
    }

    public static function isSpellClip(child:Dynamic):Bool {
        if (child == null) return false;
        try {
            // Avatars and monsters have mcChar / pAV / pname
            if (Reflect.hasField(child, "mcChar") || Reflect.hasField(child, "pAV") || Reflect.hasField(child, "pname")) {
                return false;
            }
            if (child.hasOwnProperty("isMonster") && child.isMonster == true) return false;
            if (child.hasOwnProperty("isPet") && child.isPet == true) return false;
            if (child.hasOwnProperty("isProp") && child.isProp == true) return false;
            if (child.hasOwnProperty("isHouseItem") && child.isHouseItem == true) return false;

            var name:String = child.name;
            if (name != null) {
                if (name.indexOf("pet_") == 0) return false;
                if (name.indexOf("shadow") != -1) return false;
                if (name.indexOf("pad") != -1) return false;
            }

            var qName:String = untyped __global__["flash.utils.getQualifiedClassName"](child);
            if (qName != null) {
                if (qName == "AvatarMC" || qName == "MonsterMC" || qName == "PetMC") return false;
            }
            return true;
        } catch (_:Dynamic) {}
        return false;
    }

    public static function isMonsterTarget(tMC:Dynamic):Bool {
        if (tMC == null) return false;
        try {
            if (tMC.hasOwnProperty("isMonster") && tMC.isMonster == true) return true;
            if (tMC.pAV != null) {
                if (tMC.pAV.hasOwnProperty("npcType") && tMC.pAV.npcType == "monster") return true;
                if (tMC.pAV.hasOwnProperty("isMonster") && tMC.pAV.isMonster == true) return true;
            }
        } catch (_:Dynamic) {}
        return false;
    }

    private var _pendingSpells:Array<Dynamic> = [];
    private var _processPendingScheduled:Bool = false;

    private function scheduleProcessPending():Void {
        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world != null && world.stage != null) {
            try {
                world.stage.addEventListener(Event.RENDER, onStageRender, false, 0, false);
                world.stage.invalidate();
            } catch (_:Dynamic) {}
        }
        if (_hookedChars != null) {
            try {
                _hookedChars.addEventListener(Event.ENTER_FRAME, onPendingEnterFrame, false, 0, false);
            } catch (_:Dynamic) {}
        }
        if (_processPendingScheduled) return;
        _processPendingScheduled = true;
        try {
            untyped __global__["flash.utils.setTimeout"](processPendingSpells, 1);
        } catch (_:Dynamic) {
            ApiTime.delay(1, processPendingSpells);
        }
    }

    private function onStageRender(e:Event):Void {
        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world != null && world.stage != null) {
            try {
                world.stage.removeEventListener(Event.RENDER, onStageRender);
            } catch (_:Dynamic) {}
        }
        if (_pendingSpells.length > 0) {
            processPendingSpells();
        }
    }

    private function onPendingEnterFrame(e:Event):Void {
        if (_hookedChars != null) {
            try {
                _hookedChars.removeEventListener(Event.ENTER_FRAME, onPendingEnterFrame);
            } catch (_:Dynamic) {}
        }
        if (_pendingSpells.length > 0) {
            processPendingSpells();
        }
    }

    private function processPendingSpells():Void {
        _processPendingScheduled = false;
        if (_pendingSpells.length == 0) return;

        var spells = _pendingSpells;
        _pendingSpells = [];

        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world == null || world.myAvatar == null) {
            for (s in spells) {
                if (s.parent != null) {
                    s.visible = true;
                    s.alpha = 1.0;
                    applySpellFilters(cast s);
                }
            }
            return;
        }

        var myAv:Dynamic = world.myAvatar;
        var myTargetMC:Dynamic = (myAv.target != null) ? myAv.target.pMC : null;

        // Group pending spells by spell identifier (strl or class name)
        var groups:Map<String, Array<Dynamic>> = new Map();
        for (s in spells) {
            if (s == null || s.parent == null) continue;
            var key:String = (s.strl != null && s.strl != "") ? Std.string(s.strl) : untyped __global__["flash.utils.getQualifiedClassName"](s);
            if (key == null || key == "") key = "unknown";
            if (!groups.exists(key)) {
                groups.set(key, []);
            }
            groups.get(key).push(s);
        }

        for (key in groups.keys()) {
            var group:Array<Dynamic> = groups.get(key);
            if (group == null || group.length == 0) continue;

            // Determine if the group targets monsters (hostile) or players (friendly)
            var hasMonster:Bool = false;
            for (s in group) {
                if (isMonsterTarget(s.tMC)) {
                    hasMonster = true;
                    break;
                }
            }

            var isHostile:Bool = hasMonster;
            var isFriendly:Bool = !hasMonster;

            // In PvP maps, teammates are friendly and opponent players are hostile
            if (world.bPvP == true && !hasMonster) {
                try {
                    for (s in group) {
                        if (s.tMC != null && s.tMC.pAV != null && myAv.dataLeaf != null && s.tMC.pAV.dataLeaf != null) {
                            var myTeam = myAv.dataLeaf.pvpTeam;
                            var targetTeam = s.tMC.pAV.dataLeaf.pvpTeam;
                            if (myTeam != null && targetTeam != null && myTeam > -1 && targetTeam > -1) {
                                if (myTeam != targetTeam) {
                                    isHostile = true;
                                    isFriendly = false;
                                    break;
                                }
                            }
                        }
                    }
                } catch (_:Dynamic) {}
            }

            // 1. Hostile spells handling
            if (isHostile) {
                if (hostilePrimaryOnlyFX && group.length > 1) {
                    // Multi-target hostile attack -> show ONLY on primary target!
                    var primarySpell:Dynamic = null;
                    if (myTargetMC != null) {
                        for (s in group) {
                            if (s.tMC == myTargetMC) {
                                primarySpell = s;
                                break;
                            }
                        }
                    }
                    if (primarySpell == null) {
                        primarySpell = group[0];
                    }

                    for (s in group) {
                        if (s == primarySpell) {
                            s.visible = true;
                            s.alpha = 1.0;
                            applySpellFilters(cast s);
                        } else {
                            suppressSpell(s);
                        }
                    }
                } else {
                    for (s in group) {
                        s.visible = true;
                        s.alpha = 1.0;
                        applySpellFilters(cast s);
                    }
                }
            }
            // 2. Targets are players (!hasMonster): Could be a player buff OR a Monster Attack / Ultra Boss Mechanic!
            else {
                // Check if ANY player in the room is casting this spell
                var playerCaster:Dynamic = null;
                var iAmCasting:Bool = false;

                try {
                    if (myAv.pMC != null) {
                        if (myAv.pMC.spFX != null && myAv.pMC.spFX.strl == key) {
                            iAmCasting = true;
                            playerCaster = myAv;
                        } else if (myAv.pMC.nextSpFX != null && myAv.pMC.nextSpFX.strl == key) {
                            iAmCasting = true;
                            playerCaster = myAv;
                        } else if (myAv.pMC.spellDur > 0) {
                            var char = myAv.pMC.mcChar;
                            if (char != null) {
                                var lbl:String = char.currentLabel;
                                if (lbl == "Cast" || lbl == "Spell" || lbl == "Attack1" || lbl == "Attack2" || lbl == "Thrash") {
                                    iAmCasting = true;
                                    playerCaster = myAv;
                                }
                            }
                        }
                    }
                } catch (_:Dynamic) {}

                if (!iAmCasting) {
                    var avList = getAllAvatars(world);
                    for (av in avList) {
                        if (av == null || av == myAv || av.pMC == null) continue;
                        try {
                            var pMC = av.pMC;
                            if (pMC.spFX != null && pMC.spFX.strl == key) {
                                playerCaster = av;
                                break;
                            } else if (pMC.nextSpFX != null && pMC.nextSpFX.strl == key) {
                                playerCaster = av;
                                break;
                            } else if (pMC.spellDur > 0) {
                                var char = pMC.mcChar;
                                if (char != null) {
                                    var lbl:String = char.currentLabel;
                                    if (lbl == "Cast" || lbl == "Spell" || lbl == "Attack1" || lbl == "Attack2" || lbl == "Thrash") {
                                        playerCaster = av;
                                        break;
                                    }
                                }
                            }
                        } catch (_:Dynamic) {}
                    }
                }

                var isMonsterSpell:Bool = (playerCaster == null);

                // If it is a MONSTER SPELL / ULTRA BOSS MECHANIC:
                // NEVER suppress it! All targeted players must see the mechanic clearly!
                // But STILL apply 1x quality and filter stripping to eliminate Ultra lag!
                if (isMonsterSpell) {
                    for (s in group) {
                        s.visible = true;
                        s.alpha = 1.0;
                        applySpellFilters(cast s);
                    }
                }
                // If it is a friendly player party buff:
                else {
                    if (friendlySelfOnlyFX && group.length > 1) {
                        var casterSpell:Dynamic = null;
                        if (iAmCasting) {
                            for (s in group) {
                                if (s.tMC == myAv.pMC || (s.tMC != null && s.tMC.pAV == myAv)) {
                                    casterSpell = s;
                                    break;
                                }
                            }
                        } else {
                            for (s in group) {
                                if (s.tMC != null && s.tMC.pAV == playerCaster) {
                                    casterSpell = s;
                                    break;
                                }
                            }
                        }

                        if (casterSpell == null) {
                            for (s in group) {
                                if (s.tMC != myAv.pMC) {
                                    casterSpell = s;
                                    break;
                                }
                            }
                            if (casterSpell == null) {
                                casterSpell = group[0];
                            }
                        }

                        for (s in group) {
                            if (s == casterSpell) {
                                s.visible = true;
                                s.alpha = 1.0;
                                applySpellFilters(cast s);
                            } else {
                                suppressSpell(s);
                            }
                        }
                    } else {
                        for (s in group) {
                            s.visible = true;
                            s.alpha = 1.0;
                            applySpellFilters(cast s);
                        }
                    }
                }
            }
        }
    }

    private function suppressSpell(spell:Dynamic):Void {
        try {
            spell.visible = false;
            spell.alpha = 0.0;
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
            spell.visible = false;
            spell.alpha = 0.0;
            _pendingSpells.push(spell);
            scheduleProcessPending();
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
        try {
            Api.dispatcher.removeEventListener(GameEvent.ZONE_ENTERED, onZoneEntered);
        } catch (_:Dynamic) {}
        var g:Game = (_game != null) ? _game : Api.game;
        var world:Dynamic = (g != null) ? g.world : null;
        if (world != null && world.stage != null) {
            try {
                world.stage.removeEventListener(Event.RENDER, onStageRender);
            } catch (_:Dynamic) {}
        }
        if (_hookedChars != null) {
            try {
                _hookedChars.removeEventListener(Event.ADDED, onCharAdded);
                _hookedChars.removeEventListener(Event.ENTER_FRAME, onPendingEnterFrame);
            } catch (_:Dynamic) {}
            _hookedChars = null;
        }
    }
}
