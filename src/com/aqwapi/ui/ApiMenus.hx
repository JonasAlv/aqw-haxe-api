package com.aqwapi.ui;

#if flash
import com.aqwapi.AqwApi;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.ui.prompts.ApiPrompts;
import com.aqwapi.utils.AqwSettings;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.Vector;
import ui.Overlay;
import ui.option.Button;
import ui.option.Check;
import ui.option.Menu;
import ui.option.Option;

class ApiMenus {
    private static var _injected:Bool = false;
    private static var _overlay:Overlay;

    public static var anthonyMenus:Dynamic;
    public static var apiMenus:Vector<Menu>;
    public static var lastSelectedMenu:Menu = null;

    public static function inject(overlay:Overlay):Void {
        if (_injected) return;
        _injected = true;
        _overlay = overlay;

        var pocket:Dynamic = untyped __global__["Pocket"].SINGLETON;
        if (pocket == null && overlay.parent != null) {
            pocket = overlay.parent;
        }

        anthonyMenus = overlay.menus;

        // 1. Initialize notification HUD container
        var apiNotifs = new Sprite();
        overlay.addChild(apiNotifs);
        ApiNotificationManager.instance.init(apiNotifs);

        // 2. Restore Combat Manager state from persistent settings
        CombatManager.farmClass = AqwSettings.getString("api_farm_class", "");
        CombatManager.farmMode = AqwSettings.getString("api_farm_mode", "Base");
        CombatManager.soloClass = AqwSettings.getString("api_solo_class", "");
        CombatManager.soloMode = AqwSettings.getString("api_solo_mode", "Base");

        if (AqwApi.combat != null) {
            AqwApi.combat.infiniteRange = AqwSettings.getBool("api_infinite_range", false);
        }
        if (AqwApi.map != null) {
            AqwApi.map.autoDeathSpawn = AqwSettings.getBool("api_death_spawn", false);
            AqwApi.map.usePrivateRoom = AqwSettings.getBool("api_private_rooms", true);
        }

        // 3. Build Menu Tabs
        var scriptsMenu = buildScriptsMenu(pocket, overlay);
        var automationMenu = buildAutomationMenu(pocket, overlay);
        var enhancementMenu = buildEnhancementMenu(pocket, overlay);
        var settingsMenu = buildSettingsMenu(pocket, overlay);

        apiMenus = new Vector<Menu>();
        apiMenus.push(scriptsMenu);
        apiMenus.push(automationMenu);
        apiMenus.push(enhancementMenu);
        apiMenus.push(settingsMenu);

        // 4. Handle UI event delegation (Restore Anthony's menus when showPanelBtn is clicked)
        overlay.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (overlay.currentFrameLabel == "Init" && overlay.showPanelBtn != null) {
                var isShowPanelBtn:Bool = false;
                var curr:Dynamic = e.target;
                while (curr != null && curr != overlay) {
                    if (curr == overlay.showPanelBtn) {
                        isShowPanelBtn = true;
                        break;
                    }
                    curr = curr.parent;
                }
                if (isShowPanelBtn) {
                    overlay.menus = anthonyMenus;
                    lastSelectedMenu = null;
                }
            }
        }, true);

        // 5. Restore loot and AC settings
        var initialLootState = AqwSettings.getBool("api_accept_loot", false);
        if (AqwApi.drop != null) AqwApi.drop.acceptAll = initialLootState;
        var initialACState = AqwSettings.getBool("api_accept_ac_drops", false);
        if (AqwApi.drop != null) AqwApi.drop.acceptACs = initialACState;

        // 6. Create the floating red "Menu" icon button
        setupFloatingMenuButton(pocket, overlay);

        // 7. Track menu selection and frame hooks
        setupFrameHooks(pocket, overlay);
    }

    private static function buildScriptsMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        // Paste Script
        opts.push(new Button(null, "Paste Script", "Paste a raw text script.", "Paste", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showPastePrompt(overlay);
        }));

        // Desktop: File script loader
        #if air
        opts.push(new Button(null, "Load Script (File)", "Load a script from a text file.", "Load", function(o:Dynamic):Void {
            try {
                var fileCls:Dynamic = untyped __global__["flash.filesystem.File"];
                var fsCls:Dynamic = untyped __global__["flash.filesystem.FileStream"];
                var fmCls:Dynamic = untyped __global__["flash.filesystem.FileMode"];
                var ffCls:Dynamic = untyped __global__["flash.net.FileFilter"];

                var file = fileCls.desktopDirectory;
                file.addEventListener("select", function(ev:Dynamic):Void {
                    var stream = Type.createInstance(fsCls, []);
                    stream.open(file, fmCls.READ);
                    var txt:String = stream.readUTFBytes(stream.bytesAvailable);
                    stream.close();
                    ScriptManager.SINGLETON.loadScript(txt);
                    ApiNotificationManager.notify("Script loaded successfully!");
                });
                var filters = [Type.createInstance(ffCls, ["Script Files (*.txt, *.hscript, *.hx)", "*.txt;*.hscript;*.hx"])];
                file.browseForOpen("Select Script", filters);
            } catch (e:Dynamic) {}
        }));
        #end

        // Run Script Check
        var startScriptCheck = new Check(null, false, "Run Script", "Start or Stop the loaded script.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                ScriptManager.SINGLETON.reset();
                ScriptManager.SINGLETON.start();
            } else {
                ScriptManager.SINGLETON.stop();
            }
        });
        startScriptCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (startScriptCheck.state != ScriptManager.SINGLETON.isRunning) {
                startScriptCheck.state = ScriptManager.SINGLETON.isRunning;
                startScriptCheck.syncState();
            }
        });
        opts.push(startScriptCheck);

        // Chat Logger
        var chatLogCheck = new Check(null, com.aqwapi.utils.ApiLogger.printToChat, "Chat Logger", "Display bot and script logs in the in-game chat box.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            com.aqwapi.utils.ApiLogger.printToChat = c.state;
        });
        opts.push(chatLogCheck);

        // Class Loadouts
        var loadoutsBtn = new Button(null, "Class Loadouts", "Configure your default Farm, Solo, Boss and Dodge classes for script auto-swapping.", "Setup", function(o:Dynamic):Void {
            ApiPrompts.showLoadoutsPrompt(overlay);
        });
        opts.push(loadoutsBtn);

        return new Menu("Scripts", opts);
    }

    private static function buildAutomationMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        // AutoCombat Setup
        opts.push(new Button(null, "AutoCombat (Setup)", "Configure class and mode for smart combat.", "Setup", function(o:Dynamic):Void {
            ApiPrompts.showSmartCombatPrompt(overlay);
        }));

        // Smart Combat Check
        var smartCombatCheck = new Check(null, false, "AutoCombat (Smart)", "Start smart auto combat.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                var confClass = AqwSettings.getString("api_smart_class", "");
                var confMode = AqwSettings.getString("api_smart_mode", "Base");
                if (confClass != "" && AqwApi.inventory != null) {
                    AqwApi.inventory.equip(confClass);
                }
                if (AqwApi.combat != null) {
                    AqwApi.combat.mode = confMode;
                    AqwApi.combat.startSmart();
                }
            } else {
                if (AqwApi.combat != null) AqwApi.combat.stopAuto();
            }
        });
        smartCombatCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (AqwApi.combat != null && smartCombatCheck.state != AqwApi.combat.isSmartRunning) {
                smartCombatCheck.state = AqwApi.combat.isSmartRunning;
                smartCombatCheck.syncState();
            }
        });
        opts.push(smartCombatCheck);

        // Custom Combat Check
        var customCombatCheck = new Check(null, false, "AutoCombat (Custom)", "Start custom combat sequence.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                overlay.gotoAndStop("Init");
                ApiPrompts.showCombatPrompt(overlay);
            } else {
                if (AqwApi.combat != null) AqwApi.combat.stopAuto();
            }
        });
        customCombatCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (AqwApi.combat != null && customCombatCheck.state != AqwApi.combat.isCustomRunning) {
                customCombatCheck.state = AqwApi.combat.isCustomRunning;
                customCombatCheck.syncState();
            }
        });
        opts.push(customCombatCheck);

        // Auto Quest Check
        var autoQuestCheck = new Check(null, false, "Auto Quest", "Start accepting and completing quests.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                overlay.gotoAndStop("Init");
                ApiPrompts.showQuestPrompt(overlay);
            } else {
                if (AqwApi.quest != null) AqwApi.quest.stopAuto();
            }
        });
        autoQuestCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (AqwApi.quest != null && autoQuestCheck.state != AqwApi.quest.isAutoRunning) {
                autoQuestCheck.state = AqwApi.quest.isAutoRunning;
                autoQuestCheck.syncState();
            }
        });
        opts.push(autoQuestCheck);

        // Auto Leveling Check
        var autoLevelingCheck = new Check(null, false, "Auto Leveling", "Auto grind XP in shadowbattleon.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (c.state) {
                var script = "EQUIPCLASS farm\nLOADQUEST 9421,9422,9423\nJOIN shadowbattleon,Enter,Spawn\nAUTOQUEST 9421,9422,9423\nEQUIPCLASS farm\nCOMBAT smart\n";
                ScriptManager.SINGLETON.reset();
                ScriptManager.SINGLETON.loadScript(script);
                ScriptManager.SINGLETON.start();
            } else {
                ScriptManager.SINGLETON.stop();
            }
        });
        autoLevelingCheck.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            if (autoLevelingCheck.state != ScriptManager.SINGLETON.isRunning) {
                autoLevelingCheck.state = ScriptManager.SINGLETON.isRunning;
                autoLevelingCheck.syncState();
            }
        });
        opts.push(autoLevelingCheck);

        return new Menu("Automation", opts);
    }

    private static function buildEnhancementMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        var lvl50Shops = [
            { name: "Healer Enh", id: 762 },
            { name: "Lucky Enh", id: 763 },
            { name: "Spellbreaker Enh", id: 764 },
            { name: "Wizard Enh", id: 765 },
            { name: "Hybrid Enh", id: 766 },
            { name: "Thief Enh", id: 767 },
            { name: "Fighter Enh", id: 768 }
        ];
        var aweShops = [
            { name: "Fighter Awe", id: 635 },
            { name: "Wizard Awe", id: 636 },
            { name: "Thief Awe", id: 637 },
            { name: "Healer Awe", id: 638 },
            { name: "Lucky Awe", id: 639 },
            { name: "Hybrid Awe", id: 633 }
        ];
        var forgeShops = [
            { name: "Weapon Enh", id: 2142 },
            { name: "Cape Enh", id: 2143 },
            { name: "Helmet Enh", id: 2164 }
        ];

        opts.push(new Button(null, "Lvl 50+ Enhancements", "Load level 50+ normal enhancements.", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Lvl 50+ Enhancements", lvl50Shops, false);
        }));

        opts.push(new Button(null, "Awe Enhancements", "Load Awe enhancements.", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Awe Enhancements", aweShops, false);
        }));

        opts.push(new Button(null, "Forge Enhancements", "Load Forge enhancements (auto-joins /forge).", "Open", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showEnhancementPrompt(overlay, "Forge Enhancements", forgeShops, true);
        }));

        return new Menu("Enhancements", opts);
    }

    private static function buildSettingsMenu(pocket:Dynamic, overlay:Overlay):Menu {
        var opts = new Vector<Option>();

        // Load Shop
        opts.push(new Button(null, "Load Shop", "Load a shop by its ID.", "Load", function(o:Dynamic):Void {
            overlay.gotoAndStop("Init");
            ApiPrompts.showShopPrompt(overlay);
        }));

        // Toggle Bank
        opts.push(new Button(null, "Toggle Bank", "Open or close your bank.", "Toggle", function(o:Dynamic):Void {
            if (AqwApi.inventory != null) AqwApi.inventory.toggleBank();
        }));

        // Infinite Range
        opts.push(new Check("api_infinite_range", false, "Infinite Range", "Attack and use skills across the entire screen without range limits.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (AqwApi.combat != null) {
                AqwApi.combat.infiniteRange = c.state;
                if (c.state) AqwApi.combat.applyInfiniteRange();
            }
        }));

        // Death Spawn
        opts.push(new Check("api_death_spawn", false, "Death Spawn (Same Room)", "Automatically sets your respawn point to your current room so you never walk back on death.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (AqwApi.map != null) AqwApi.map.autoDeathSpawn = c.state;
        }));

        // Private Rooms
        opts.push(new Check("api_private_rooms", true, "Private Rooms", "Automatically join private rooms (e.g. map-100000). Uncheck to join public rooms.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (AqwApi.map != null) AqwApi.map.usePrivateRoom = c.state;
        }));

        // Accept All Loot
        opts.push(new Check("api_accept_loot", false, "Accept All Loot", "Automatically accept all dropped items.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (AqwApi.drop != null) AqwApi.drop.acceptAll = c.state;
        }));

        // Accept AC Drops
        opts.push(new Check("api_accept_ac_drops", false, "Accept AC Drops", "Automatically accept all AC-tagged (coin) drops.", true, function(o:Dynamic):Void {
            var c:Check = cast o;
            if (AqwApi.drop != null) AqwApi.drop.acceptACs = c.state;
        }));

        // SWF RAM Cache
        opts.push(new Check(AqwSettings.OPTION_SWF_CACHE, false, "SWF RAM Cache", "Caches loaded maps and classes to RAM to eliminate reloading. (Requires more RAM)", true, function(o:Dynamic):Void {
            try {
                pocket.config.option_swf_cache = (cast(o, Check)).state;
            } catch (e:Dynamic) {}
        }));

        return new Menu("Settings", opts);
    }

    private static function setupFloatingMenuButton(pocket:Dynamic, overlay:Overlay):Void {
        var icon = new Sprite();
        icon.graphics.beginFill(0x990000, 0.95);
        icon.graphics.lineStyle(1, 0x660000);
        icon.graphics.drawRoundRect(0, 0, 80, 35, 8, 8);
        icon.graphics.endFill();

        var txt = new TextField();
        var fmt = new TextFormat("_sans", 14, 0xFFFFFF, true);
        fmt.align = TextFormatAlign.CENTER;
        txt.defaultTextFormat = fmt;
        txt.text = "Menu";
        txt.width = 80;
        txt.y = 8;
        txt.selectable = false;
        txt.mouseEnabled = false;
        icon.addChild(txt);

        icon.x = 80;
        icon.y = 10;
        icon.buttonMode = true;

        var theStage:Dynamic = (pocket != null && pocket.stage != null) ? pocket.stage : overlay.stage;
        if (theStage != null) {
            theStage.addChild(icon);
        } else {
            overlay.addEventListener(Event.ADDED_TO_STAGE, function(ev:Event):Void {
                if (overlay.stage != null) {
                    overlay.stage.addChild(icon);
                }
            });
        }

        var isDragging:Bool = false;
        var hasDragged:Bool = false;
        var dragStartX:Float = 0;
        var dragStartY:Float = 0;

        icon.addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent):Void {
            isDragging = true;
            hasDragged = false;
            dragStartX = e.stageX - icon.x;
            dragStartY = e.stageY - icon.y;
        });

        if (theStage != null) {
            theStage.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent):Void {
                if (isDragging) {
                    hasDragged = true;
                    var nx:Float = e.stageX - dragStartX;
                    var ny:Float = e.stageY - dragStartY;
                    var sw:Float = theStage.stageWidth > 0 ? theStage.stageWidth : 960;
                    var sh:Float = theStage.stageHeight > 0 ? theStage.stageHeight : 500;
                    if (nx < 0) nx = 0;
                    if (ny < 0) ny = 0;
                    if (nx > sw - 80) nx = sw - 80;
                    if (ny > sh - 35) ny = sh - 35;
                    icon.x = nx;
                    icon.y = ny;
                }
            });
            theStage.addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent):Void {
                isDragging = false;
            });
        }

        icon.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (hasDragged) return;
            overlay.menus = apiMenus;
            overlay.gotoAndStop("Panel");
            if (lastSelectedMenu != null) {
                overlay.selectMenu(lastSelectedMenu);
            }
        });

        // Hide icon when panel is open
        overlay.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            var isPanelOpen:Bool = (overlay.currentFrameLabel == "Panel");
            icon.visible = !isPanelOpen;
        });
    }

    private static function setupFrameHooks(pocket:Dynamic, overlay:Overlay):Void {
        overlay.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void {
            if (overlay.currentFrameLabel == "Panel" && overlay.contentMenu != null) {
                var c:Dynamic = e.target;
                while (c != null && c != overlay.contentMenu && c != overlay) {
                    if (Std.isOfType(c, Menu)) {
                        lastSelectedMenu = cast c;
                        break;
                    }
                    c = c.parent;
                }
            }
        }, false);

        overlay.addEventListener(Event.ENTER_FRAME, function(e:Event):Void {
            // Cutscene skipping
            try {
                if (pocket.config.option_disable_cutscenes && pocket.game != null && pocket.game.world != null) {
                    var world = pocket.game.world;
                    if (world.mcExtSWF != null && world.mcExtSWF.numChildren > 0) {
                        var ext = world.mcExtSWF.getChildAt(0);
                        if (ext != null && Reflect.hasField(ext, "totalFrames")) {
                            ext.gotoAndPlay(Reflect.field(ext, "totalFrames") - 2);
                            if (Reflect.hasField(world, "showInterface")) {
                                world.showInterface();
                            }
                        }
                    }
                }
            } catch (err:Dynamic) {}

            // Infinite range & Death spawn tick
            var isScriptRunning = ScriptManager.SINGLETON.isRunning;
            var infiniteRangeActive = isScriptRunning || AqwSettings.getBool("api_infinite_range", false);
            var deathSpawnActive = isScriptRunning || AqwSettings.getBool("api_death_spawn", false);

            if (AqwApi.map != null) {
                AqwApi.map.autoDeathSpawn = deathSpawnActive;
                if (deathSpawnActive) {
                    AqwApi.map.checkAutoDeathSpawn();
                }
            }
            if (AqwApi.combat != null) {
                AqwApi.combat.infiniteRange = infiniteRangeActive;
                if (infiniteRangeActive) {
                    AqwApi.combat.applyInfiniteRange();
                }
            }

            // Hide Anthony's branding when API menu is open
            if (overlay.currentFrameLabel == "Panel") {
                for (i in 0...overlay.numChildren) {
                    var child = overlay.getChildAt(i);
                    try {
                        if (Reflect.hasField(child, "text") && Reflect.field(child, "text") == "Pocket") {
                            child.visible = false;
                        }
                    } catch (err:Dynamic) {}
                }

                var isApiMenu = (overlay.menus == apiMenus);
                if (overlay.updateBtn != null) overlay.updateBtn.visible = !isApiMenu;
                if (overlay.discordBtn != null) overlay.discordBtn.visible = !isApiMenu;
                if (overlay.reportBugBtn != null) overlay.reportBugBtn.visible = !isApiMenu;
            }
        });
    }
}
#else
class ApiMenus {
    public static function inject(overlay:Dynamic):Void {}
}
#end
