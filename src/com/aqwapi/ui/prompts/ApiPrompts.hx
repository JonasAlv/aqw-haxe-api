package com.aqwapi.ui.prompts;

#if flash
import com.aqwapi.AqwApi;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.ui.ApiNotificationManager;
import com.aqwapi.ui.Dropdown;
import com.aqwapi.utils.AqwSettings;
import com.aqwapi.utils.AqwUtils;
import flash.display.Sprite;
import flash.utils.Timer;

class ApiPrompts {
    private static var _lastQuests:String = "";
    private static var _lastCombat:String = "";

    public static function showQuestPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Quest IDs (comma separated):");

        var input = ApiPromptModal.createInput(260, 25, _lastQuests);
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var startBtn = ApiPromptModal.createButton("Start", 120, 30, function():Void {
            _lastQuests = input.text;
            var ids = _lastQuests.split(",");
            var validIds:Array<Int> = [];
            for (idStr in ids) {
                var qid = AqwUtils.parseInt(StringTools.trim(idStr), 0);
                if (qid > 0) validIds.push(qid);
            }
            if (validIds.length > 0 && AqwApi.quest != null) {
                AqwApi.quest.startAuto(validIds.join(","));
            }
            ApiPromptModal.close();
        }, false);
        startBtn.x = 20;
        startBtn.y = 80;
        dlg.addChild(startBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 80;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showCombatPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Skills (e.g. 1,2,3,4):");

        var input = ApiPromptModal.createInput(260, 25, _lastCombat);
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var startBtn = ApiPromptModal.createButton("Start", 120, 30, function():Void {
            _lastCombat = input.text;
            var seq = _lastCombat.split(",");
            var validSeq:Array<String> = [];
            for (s in seq) {
                var trimmed = StringTools.trim(s);
                if (trimmed.length > 0) validSeq.push(trimmed);
            }
            if (validSeq.length > 0 && AqwApi.combat != null) {
                AqwApi.combat.startCustom(validSeq.join(","));
            }
            ApiPromptModal.close();
        }, false);
        startBtn.x = 20;
        startBtn.y = 80;
        dlg.addChild(startBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 80;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showShopPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(300, 160, "Enter Shop ID:");

        var input = ApiPromptModal.createInput(260, 25, "");
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var loadBtn = ApiPromptModal.createButton("Load", 120, 30, function():Void {
            var shopId = AqwUtils.parseInt(StringTools.trim(input.text), 0);
            ApiPromptModal.close();
            if (shopId > 0 && AqwApi.shop != null) {
                AqwApi.shop.loadShop(shopId);
                ApiNotificationManager.notify("Loading Shop: " + shopId);
            }
        }, false);
        loadBtn.x = 20;
        loadBtn.y = 80;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 160;
        cancelBtn.y = 80;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showPastePrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(600, 400, "Paste Script Below");

        var input = ApiPromptModal.createInput(560, 300, "", true);
        input.x = 20;
        input.y = 40;
        dlg.addChild(input);

        var loadBtn = ApiPromptModal.createButton("Load Script", 120, 30, function():Void {
            var txt = input.text;
            ApiPromptModal.close();
            ScriptManager.SINGLETON.loadScript(txt);
            ApiNotificationManager.notify("Script loaded successfully!");
        }, false);
        loadBtn.x = 160;
        loadBtn.y = 350;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 120, 30, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 320;
        cancelBtn.y = 350;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showEnhancementPrompt(
        overlay:Dynamic,
        promptTitle:String,
        shops:Array<{ name:String, id:Int }>,
        requireForge:Bool = false
    ):Void {
        var dlg = ApiPromptModal.createDialog(340, 180, promptTitle);

        var shopNames:Array<String> = [];
        for (s in shops) shopNames.push(s.name);

        var selectedId:Int = shops.length > 0 ? shops[0].id : 0;
        var selectedName:String = shops.length > 0 ? shops[0].name : "";

        var ddShop = new Dropdown(260, 30, shopNames, function(sel:String):Void {
            selectedName = sel;
            for (s in shops) {
                if (s.name == sel) {
                    selectedId = s.id;
                    break;
                }
            }
        });
        ddShop.x = 40;
        ddShop.y = 55;
        dlg.addChild(ddShop);

        var loadBtn = ApiPromptModal.createButton("Load Shop", 120, 35, function():Void {
            ApiPromptModal.close();
            if (requireForge) {
                if (AqwApi.map != null && AqwApi.map.name != null && AqwApi.map.name.toLowerCase() != "forge") {
                    AqwApi.map.join("forge", "Enter", "Spawn");
                    ApiNotificationManager.notify("Joining forge map...");
                    haxe.Timer.delay(function():Void {
                        if (AqwApi.shop != null) AqwApi.shop.loadShop(selectedId);
                        ApiNotificationManager.notify("Loading Shop: " + selectedName);
                    }, 3500);
                    return;
                }
            }
            if (AqwApi.shop != null) AqwApi.shop.loadShop(selectedId);
            ApiNotificationManager.notify("Loading Shop: " + selectedName);
        }, true);
        loadBtn.x = 40;
        loadBtn.y = 120;
        dlg.addChild(loadBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 100, 35, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 180;
        cancelBtn.y = 120;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showSmartCombatPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(400, 250, "AutoCombat Setup");

        var lblClass = ApiPromptModal.createLabel("Class:", 60);
        lblClass.x = 20;
        lblClass.y = 50;
        dlg.addChild(lblClass);

        var lblMode = ApiPromptModal.createLabel("Mode:", 60);
        lblMode.x = 220;
        lblMode.y = 50;
        dlg.addChild(lblMode);

        var availableClasses = getAvailableClasses();
        var currentClass = getCurrentClass();

        var selectedClassStr = AqwSettings.getString("api_smart_class", currentClass != "" ? currentClass : availableClasses[0]);
        if (availableClasses.indexOf(selectedClassStr) == -1) {
            selectedClassStr = currentClass != "" ? currentClass : availableClasses[0];
        }

        var availableModes = CombatManager.getAvailableModes(selectedClassStr);
        var selectedModeStr = AqwSettings.getString("api_smart_mode", "Base");
        if (availableModes.indexOf(selectedModeStr) == -1) {
            selectedModeStr = availableModes.length > 0 ? availableModes[0] : "Base";
        }

        var ddMode:Dropdown = null;
        ddMode = new Dropdown(150, 25, availableModes, function(sel:String):Void {
            selectedModeStr = sel;
        });
        ddMode.x = 220;
        ddMode.y = 80;
        ddMode.selectedItem = selectedModeStr;

        var ddClass:Dropdown = null;
        ddClass = new Dropdown(180, 25, availableClasses, function(sel:String):Void {
            selectedClassStr = sel;
            var modes = CombatManager.getAvailableModes(selectedClassStr);
            ddMode.options = modes;
            if (modes.indexOf(selectedModeStr) == -1) {
                selectedModeStr = modes.length > 0 ? modes[0] : "Base";
            }
            ddMode.selectedItem = selectedModeStr;
        });
        ddClass.x = 20;
        ddClass.y = 80;
        ddClass.selectedItem = selectedClassStr;

        dlg.addChild(ddMode);
        dlg.addChild(ddClass);

        var saveBtn = ApiPromptModal.createButton("Save & Apply", 160, 35, function():Void {
            AqwSettings.setString("api_smart_class", selectedClassStr);
            AqwSettings.setString("api_smart_mode", selectedModeStr);
            if (selectedClassStr != "" && AqwApi.inventory != null) {
                AqwApi.inventory.equip(selectedClassStr);
            }
            if (AqwApi.combat != null) {
                AqwApi.combat.mode = selectedModeStr;
            }
            ApiNotificationManager.notify("Smart Combat Config: " + selectedClassStr + " [" + selectedModeStr + "]");
            ApiPromptModal.close();
        }, true);
        saveBtn.x = 30;
        saveBtn.y = 190;
        dlg.addChild(saveBtn);

        var cancelBtn = ApiPromptModal.createButton("Cancel", 140, 35, function():Void {
            ApiPromptModal.close();
        }, false);
        cancelBtn.x = 230;
        cancelBtn.y = 190;
        dlg.addChild(cancelBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    public static function showLoadoutsPrompt(overlay:Dynamic):Void {
        var dlg = ApiPromptModal.createDialog(420, 390, "Class Loadouts (For Scripts)");

        var availableClasses = getAvailableClasses();

        // 1. Farm
        setupLoadoutRow(dlg, "FARM Loadout:", 45, 70, availableClasses, "api_farm_class", "api_farm_mode", function(c:String, m:String):Void {
            CombatManager.farmClass = c;
            CombatManager.farmMode = m;
        });

        // 2. Solo
        setupLoadoutRow(dlg, "SOLO Loadout:", 110, 135, availableClasses, "api_solo_class", "api_solo_mode", function(c:String, m:String):Void {
            CombatManager.soloClass = c;
            CombatManager.soloMode = m;
        });

        // 3. Boss
        setupLoadoutRow(dlg, "BOSS Loadout:", 175, 200, availableClasses, "api_boss_class", "api_boss_mode", function(c:String, m:String):Void {
            CombatManager.bossClass = c;
            CombatManager.bossMode = m;
        });

        // 4. Dodge
        setupLoadoutRow(dlg, "DODGE Loadout:", 240, 265, availableClasses, "api_dodge_class", "api_dodge_mode", function(c:String, m:String):Void {
            CombatManager.dodgeClass = c;
            CombatManager.dodgeMode = m;
        });

        var doneBtn = ApiPromptModal.createButton("Done", 140, 35, function():Void {
            ApiPromptModal.close();
            ApiNotificationManager.notify("Class Loadouts Saved!");
        }, true);
        doneBtn.x = 140;
        doneBtn.y = 330;
        dlg.addChild(doneBtn);

        ApiPromptModal.show(overlay, dlg);
    }

    private static function setupLoadoutRow(
        dlg:Sprite,
        title:String,
        lblY:Float,
        ddY:Float,
        classes:Array<String>,
        classKey:String,
        modeKey:String,
        onUpdate:String->String->Void
    ):Void {
        var lbl = ApiPromptModal.createLabel(title, 150, 14, true);
        lbl.x = 20;
        lbl.y = lblY;
        dlg.addChild(lbl);

        var curClass = AqwSettings.getString(classKey, classes[0]);
        if (classes.indexOf(curClass) == -1) curClass = classes[0];
        var modes = CombatManager.getAvailableModes(curClass);
        var curMode = AqwSettings.getString(modeKey, modes[0]);
        if (modes.indexOf(curMode) == -1) curMode = modes[0];

        var ddMode:Dropdown = null;
        ddMode = new Dropdown(120, 25, modes, function(sel:String):Void {
            curMode = sel;
            AqwSettings.setString(modeKey, sel);
            onUpdate(curClass, curMode);
        });
        ddMode.x = 280;
        ddMode.y = ddY;

        var ddClass:Dropdown = null;
        ddClass = new Dropdown(240, 25, classes, function(sel:String):Void {
            curClass = sel;
            AqwSettings.setString(classKey, sel);
            var nm = CombatManager.getAvailableModes(curClass);
            ddMode.options = nm;
            curMode = nm[0];
            ddMode.selectedItem = curMode;
            AqwSettings.setString(modeKey, curMode);
            onUpdate(curClass, curMode);
        });
        ddClass.x = 20;
        ddClass.y = ddY;

        ddClass.selectedItem = curClass;
        ddMode.selectedItem = curMode;
        dlg.addChild(ddMode);
        dlg.addChild(ddClass);
    }

    private static function getAvailableClasses():Array<String> {
        var classes:Array<String> = [];
        if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null && AqwApi.game.world.myAvatar.items != null) {
            var items:Dynamic = AqwApi.game.world.myAvatar.items;
            for (item in (cast items : Array<Dynamic>)) {
                if (item != null && item.sES == "ar") {
                    classes.push(item.sName);
                }
            }
        }
        if (classes.length == 0) classes.push("No Classes Found");
        return classes;
    }

    private static function getCurrentClass():String {
        if (AqwApi.game != null && AqwApi.game.world != null && AqwApi.game.world.myAvatar != null && AqwApi.game.world.myAvatar.objData != null) {
            return Std.string(AqwApi.game.world.myAvatar.objData.strClassName);
        }
        return "";
    }
}
#else
class ApiPrompts {}
#end
