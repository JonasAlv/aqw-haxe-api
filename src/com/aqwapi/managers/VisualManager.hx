package com.aqwapi.managers;

import flash.events.TimerEvent;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.utils.Timer;
import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.utils.ApiConfig;
import com.aqwapi.utils.ApiLogger;

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
    public var disableSkillAnims(default, set):Bool = false;
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
        disableSkillAnims = ApiConfig.getBool("api_disable_skill_anims", false);
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
        });
        _sweepTimer.start();
    }

    public inline function isActive():Bool {
        return lagKiller || hidePlayers || disableSkillAnims || disableMonsterAnims || disableWeaponAnims || disableGround || hideMonsters || cleanArena || suppressTargetGlow || cachePlayers || cacheMonsters;
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

    public function set_disableSkillAnims(v:Bool):Bool {
        disableSkillAnims = v;
        ApiConfig.setBool("api_disable_skill_anims", v);
        apply();
        return disableSkillAnims;
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
        var effDisSkills = lagKiller || disableSkillAnims;
        var effDisMonAnims = lagKiller || disableMonsterAnims;
        var effDisWepAnims = lagKiller || disableWeaponAnims;
        var effDisGround = lagKiller || disableGround;

        // 1. Update native AQLite Preferences
        try {
            if (g.litePreference != null && g.litePreference.data != null) {
                var d = g.litePreference.data;
                d.bHidePlayers = effHidePlayers;
                d.bDisSkillAnim = effDisSkills;
                d.bDisMonAnim = effDisMonAnims;
                d.bDisWepAnim = effDisWepAnims;
                d.bDisGround = effDisGround;
                d.bHideMons = hideMonsters;
                d.bCachePlayers = cachePlayers;

                if (d.dOptions != null) {
                    Reflect.setField(d.dOptions, "showNames", showNames);
                    Reflect.setField(d.dOptions, "showShadows", showShadows);
                }

                if (g.litePreference.flush != null) {
                    g.litePreference.flush();
                }
            }
        } catch (_:Dynamic) {}

        // 2. Suppress or restore native target color wash
        applyTargetGlow();

        // 3. Update live display list
        applyDisplayListOnly();
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
        var effDisSkills = lagKiller || disableSkillAnims;
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

    public function destroy():Void {
        if (_sweepTimer != null) {
            _sweepTimer.stop();
            _sweepTimer = null;
        }
    }
}
