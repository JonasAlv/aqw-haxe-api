package com.aqwapi.managers;

import flash.utils.Timer;
import flash.events.TimerEvent;
import com.aqwapi.Api;
import com.aqwapi.Game;
import com.aqwapi.data.ItemDTO;
import com.aqwapi.modules.DefaultEnhancementsData;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiUtils;
import com.aqwapi.utils.ApiJson;
import com.aqwapi.utils.ApiStorage;

private typedef EnhanceTask = {
    var item:ItemDTO;
    var baseType:String;
    var special:String;
    var shopId:Int;
    var targetMap:String;
};

class EnhancementManager {
    private var _game:Game;
    private var _timer:Timer;
    private var _queue:Array<EnhanceTask> = [];
    private var _onCompleteCallback:Void->Void = null;
    private var _stepTimer:Float = 0;
    private var _shopWaitCount:Int = 0;
    private var _originMap:String = null;
    private var _originCell:String = null;
    private var _originPad:String = null;
    private var _cachedDb:Dynamic = null;

    public var isBusy(default, null):Bool = false;
    public var lastStatus(default, null):String = "Idle";

    // Quest Slot & Value mappings for 100% instant offline & online verification
    private static final FORGE_QUESTS:Map<String, { questId:Int, slot:Int, value:Int }> = [
        // Weapons
        "forge_weapon" => { questId: 8738, slot: 21, value: 27 },
        "lacerate" => { questId: 8739, slot: 10, value: 4 },
        "smite" => { questId: 8740, slot: 283, value: 31 },
        "valiance" => { questId: 8741, slot: 327, value: 11 },
        "arcanas_concerto" => { questId: 8742, slot: 454, value: 34 },
        "acheron" => { questId: 8820, slot: 412, value: 23 },
        "elysium" => { questId: 8821, slot: 400, value: 9 },
        "praxis" => { questId: 9171, slot: 278, value: 11 },
        "dauntless" => { questId: 9172, slot: 488, value: 22 },
        "ravenous" => { questId: 9560, slot: 544, value: 6 },

        // Capes
        "forge_cape" => { questId: 8758, slot: 25, value: 23 },
        "absolution" => { questId: 8743, slot: 468, value: 1 },
        "vainglory" => { questId: 8744, slot: 468, value: 2 },
        "avarice" => { questId: 8745, slot: 468, value: 3 },
        "penitence" => { questId: 8822, slot: 468, value: 4 },
        "lament" => { questId: 8823, slot: 468, value: 5 },

        // Helms
        "forge_helm" => { questId: 8828, slot: 472, value: 1 },
        "vim" => { questId: 8824, slot: 472, value: 2 },
        "examen" => { questId: 8825, slot: 472, value: 3 },
        "anima" => { questId: 8826, slot: 472, value: 4 },
        "pneuma" => { questId: 8827, slot: 472, value: 5 },
        "hearty" => { questId: 9466, slot: 530, value: 4 }
    ];

    public function new(gameReference:Game) {
        _game = gameReference;
        _timer = new Timer(150);
        _timer.addEventListener(TimerEvent.TIMER, onTimerTick);
    }

    // ==========================================
    // UNLOCK VERIFICATION
    // ==========================================

    public function isAweUnlocked():Bool {
        if (Api.quest != null) {
            if (Api.quest.getQuestValue(123) >= 5) return true;
            if (Api.quest.isCompleted(2937)) return true;
        }
        return false;
    }

    public function isForgeUnlocked(specialName:String):Bool {
        if (specialName == null || specialName == "" || specialName == "None") return true;
        var key = normalizeKey(specialName);
        if (key == "awe") return isAweUnlocked();
        if (key == "forge") {
            return isForgeUnlocked("forge_weapon") || isForgeUnlocked("forge_cape") || isForgeUnlocked("forge_helm");
        }
        if (FORGE_QUESTS.exists(key)) {
            var q = FORGE_QUESTS.get(key);
            if (Api.quest != null) {
                if (Api.quest.getQuestValue(q.slot) >= q.value) return true;
                if (Api.quest.isCompleted(q.questId)) return true;
            }
        }
        return false;
    }

    public function canEnhanceCape(special:String):Bool {
        if (special == null || special == "" || special == "None") return true;
        return isForgeUnlocked(special);
    }

    public function canEnhanceHelm(special:String):Bool {
        if (special == null || special == "" || special == "None") return true;
        return isForgeUnlocked(special);
    }

    public function canEnhanceWeapon(special:String):Bool {
        if (special == null || special == "" || special == "None") return true;
        var key = normalizeKey(special);
        if (isAweSpecial(key)) return isAweUnlocked();
        return isForgeUnlocked(special);
    }

    private function isAweSpecial(normalizedKey:String):Bool {
        return normalizedKey == "spiral_carve" || normalizedKey == "awe_blast" ||
               normalizedKey == "health_vamp" || normalizedKey == "mana_vamp" ||
               normalizedKey == "powerword_die";
    }

    // ==========================================
    // CURRENT EQUIPMENT INSPECTION
    // ==========================================

    public function getEquippedSlots():{ weapon:ItemDTO, armor:ItemDTO, helm:ItemDTO, cape:ItemDTO } {
        var res = { weapon: null, armor: null, helm: null, cape: null };
        if (Api.inventory == null) return res;
        var items = Api.inventory.getItems();
        for (item in items) {
            if (item == null || !item.isEquipped) continue;
            var es = (item.es != null) ? item.es.toLowerCase() : "";
            var st = (item.type != null) ? item.type.toLowerCase() : "";
            if (es == "weapon" || st == "sword" || st == "axe" || st == "dagger" || st == "gun" ||
                st == "bow" || st == "mace" || st == "gauntlet" || st == "polearm" || st == "staff" ||
                st == "wand" || st == "whip" || st == "handgun" || st == "rifle") {
                if (res.weapon == null) res.weapon = item;
            } else if (es == "ar" || es == "co" || st == "class" || st == "armor") {
                if (res.armor == null) res.armor = item;
            } else if (es == "he" || st == "helm") {
                if (res.helm == null) res.helm = item;
            } else if (es == "ba" || st == "cape") {
                if (res.cape == null) res.cape = item;
            }
        }
        return res;
    }

    public function currentClassEnh():String {
        var slots = getEquippedSlots();
        if (slots.armor != null) {
            var pat = slots.armor.enhPatternId;
            return patternIdToName(pat);
        }
        return "None";
    }

    public function currentCapeSpecial():String {
        var slots = getEquippedSlots();
        if (slots.cape != null) {
            var pat = slots.cape.enhPatternId;
            return capePatternIdToName(pat);
        }
        return "None";
    }

    public function currentHelmSpecial():String {
        var slots = getEquippedSlots();
        if (slots.helm != null) {
            var pat = slots.helm.enhPatternId;
            return helmPatternIdToName(pat);
        }
        return "None";
    }

    public function currentWeaponSpecial():String {
        var slots = getEquippedSlots();
        if (slots.weapon != null) {
            var proc = slots.weapon.procId;
            return weaponProcIdToName(proc);
        }
        return "None";
    }

    // ==========================================
    // SMART RECOMMENDATIONS (DATA-DRIVEN)
    // ==========================================

    public function getRecommendation(?className:String):{ type:String, cape:String, helm:String, weapon:String } {
        var targetClass:String = (className != null && className != "") ? className : (Api.player != null ? Api.player.className : "");
        if (targetClass == null || targetClass == "") {
            return { type: "Lucky", cape: "None", helm: "None", weapon: isAweUnlocked() ? "Spiral Carve" : "None" };
        }
        var cNorm = StringTools.trim(targetClass.toLowerCase());

        // 1. Check user overrides in storage
        var db = getEnhancementsDatabase();
        var entry:Dynamic = null;
        if (db != null) {
            if (Reflect.hasField(db, cNorm)) {
                entry = Reflect.field(db, cNorm);
            } else {
                for (f in Reflect.fields(db)) {
                    if (f.toLowerCase() == cNorm || cNorm.indexOf(f.toLowerCase()) != -1) {
                        entry = Reflect.field(db, f);
                        break;
                    }
                }
            }
        }

        if (entry != null) {
            var bType:String = (entry.type != null) ? Std.string(entry.type) : "Lucky";

            // 1. Try Forge preset
            if (entry.forge != null) {
                var fObj = entry.forge;
                var reqs:Array<Dynamic> = (fObj.required != null && Std.isOfType(fObj.required, Array)) ? cast fObj.required : [];
                var allReqsMet:Bool = true;
                for (r in reqs) {
                    var rStr = Std.string(r);
                    if (!isForgeUnlocked(rStr)) {
                        allReqsMet = false;
                        break;
                    }
                }

                if (allReqsMet) {
                    var chosenCape:String = "None";
                    var capesRaw:Dynamic = (fObj.capes != null) ? fObj.capes : fObj.cape;
                    if (Std.isOfType(capesRaw, String)) {
                        var cs = Std.string(capesRaw);
                        if (canEnhanceCape(cs)) chosenCape = cs;
                    } else if (capesRaw != null && Std.isOfType(capesRaw, Array)) {
                        for (c in (cast capesRaw : Array<Dynamic>)) {
                            var cs = Std.string(c);
                            if (canEnhanceCape(cs)) { chosenCape = cs; break; }
                        }
                    }

                    var chosenHelm:String = "None";
                    var helmsRaw:Dynamic = (fObj.helms != null) ? fObj.helms : fObj.helm;
                    if (Std.isOfType(helmsRaw, String)) {
                        var hs = Std.string(helmsRaw);
                        if (canEnhanceHelm(hs)) chosenHelm = hs;
                    } else if (helmsRaw != null && Std.isOfType(helmsRaw, Array)) {
                        for (h in (cast helmsRaw : Array<Dynamic>)) {
                            var hs = Std.string(h);
                            if (canEnhanceHelm(hs)) { chosenHelm = hs; break; }
                        }
                    }

                    var chosenWeapon:String = "None";
                    var wepsRaw:Dynamic = (fObj.weapons != null) ? fObj.weapons : fObj.weapon;
                    if (Std.isOfType(wepsRaw, String)) {
                        var ws = Std.string(wepsRaw);
                        if (canEnhanceWeapon(ws)) chosenWeapon = ws;
                    } else if (wepsRaw != null && Std.isOfType(wepsRaw, Array)) {
                        for (w in (cast wepsRaw : Array<Dynamic>)) {
                            var ws = Std.string(w);
                            if (canEnhanceWeapon(ws)) { chosenWeapon = ws; break; }
                        }
                    }

                    return { type: bType, cape: chosenCape, helm: chosenHelm, weapon: chosenWeapon };
                }
            }

            // 2. Try Awe preset
            if (isAweUnlocked() && entry.awe != null) {
                var aweWep:String = null;
                if (Std.isOfType(entry.awe, String)) {
                    aweWep = Std.string(entry.awe);
                } else if (Reflect.isObject(entry.awe) && entry.awe.weapon != null) {
                    aweWep = Std.string(entry.awe.weapon);
                }
                if (aweWep != null && aweWep != "" && aweWep != "None") {
                    return { type: bType, cape: "None", helm: "None", weapon: aweWep };
                }
            }

            // 3. Base Type Fallback
            return { type: bType, cape: "None", helm: "None", weapon: "None" };
        }

        // Generic fallback for unlisted class
        var aweWep = isAweUnlocked() ? "Spiral Carve" : "None";
        return { type: "Lucky", cape: "None", helm: "None", weapon: aweWep };
    }

    private function getEnhancementsDatabase():Dynamic {
        if (_cachedDb != null) return _cachedDb;
        try {
            // First load default embedded database
            var rawJson = DefaultEnhancementsData.getDefaultEnhancements();
            if (rawJson != null && rawJson.length > 2) {
                _cachedDb = ApiJson.parse(rawJson);
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Enhancement", "Failed to parse default enhancements database: " + Std.string(e));
        }

        try {
            // Merge user overrides if existing in storage
            var uRaw = ApiStorage.readText("userEnhancements.json");
            if (uRaw != null && uRaw.length > 2) {
                var uDb = ApiJson.parse(uRaw);
                if (_cachedDb == null) _cachedDb = {};
                for (k in Reflect.fields(uDb)) {
                    Reflect.setField(_cachedDb, k.toLowerCase(), Reflect.field(uDb, k));
                }
            }
        } catch (_:Dynamic) {}

        return _cachedDb;
    }

    public function reloadDatabase():Void {
        _cachedDb = null;
        getEnhancementsDatabase();
    }

    // ==========================================
    // PUBLIC ENHANCEMENT COMMANDS
    // ==========================================

    public function smartEnhance(?className:Dynamic, ?force:Dynamic, ?onComplete:Dynamic):Void {
        var cName:String = null;
        var f:Bool = false;
        var cb:Void->Void = null;

        if (Reflect.isFunction(className)) {
            cb = className;
        } else if (Reflect.isFunction(force)) {
            cName = (className != null) ? Std.string(className) : null;
            cb = force;
        } else {
            cName = (className != null) ? Std.string(className) : null;
            f = (force == true || force == 1 || force == "true");
            if (Reflect.isFunction(onComplete)) cb = onComplete;
        }

        var targetClass:String = (cName != null && cName != "") ? cName : (Api.player != null ? Api.player.className : "");
        if (targetClass == null || targetClass == "") {
            ApiLogger.warn("Enhancement", "smartEnhance: No class name specified and player has no equipped class.");
            if (cb != null) cb();
            return;
        }

        // 1. Safety: if in combat, stop and drop combat
        if (Api.player != null && Api.player.isInCombat) {
            if (Api.combat != null) Api.combat.stopCombat();
        }

        // 2. Equip class if not already equipped
        var currentEqClass = (Api.player != null) ? Api.player.className : "";
        if (currentEqClass.toLowerCase() != targetClass.toLowerCase()) {
            if (Api.inventory != null && Api.inventory.hasItem(targetClass)) {
                Api.inventory.equip(targetClass);
            }
        }

        // 3. Resolve recommended enhancements
        var rec = getRecommendation(targetClass);
        ApiLogger.info("Enhancement", "SmartEnhance for '" + targetClass + "': Type=" + rec.type +
            ", Cape=" + rec.cape + ", Helm=" + rec.helm + ", Weapon=" + rec.weapon);

        enhanceEquipped(rec.type, rec.cape, rec.helm, rec.weapon, cb);
    }

    public function enhanceEquipped(?baseType:Dynamic, ?capeSpecial:Dynamic, ?helmSpecial:Dynamic, ?weaponSpecial:Dynamic, ?onComplete:Dynamic):Void {
        if (isBusy) {
            ApiLogger.warn("Enhancement", "EnhancementManager is currently busy with another queue.");
            return;
        }

        var t:String = (baseType != null && !Reflect.isFunction(baseType)) ? Std.string(baseType) : "Lucky";
        var cSpec:String = (capeSpecial != null && !Reflect.isFunction(capeSpecial)) ? Std.string(capeSpecial) : "None";
        var hSpec:String = (helmSpecial != null && !Reflect.isFunction(helmSpecial)) ? Std.string(helmSpecial) : "None";
        var wSpec:String = (weaponSpecial != null && !Reflect.isFunction(weaponSpecial)) ? Std.string(weaponSpecial) : "None";
        var cb:Void->Void = null;
        if (Reflect.isFunction(onComplete)) cb = onComplete;
        else if (Reflect.isFunction(weaponSpecial)) cb = weaponSpecial;
        else if (Reflect.isFunction(helmSpecial)) cb = helmSpecial;
        else if (Reflect.isFunction(capeSpecial)) cb = capeSpecial;
        else if (Reflect.isFunction(baseType)) cb = baseType;

        var slots = getEquippedSlots();
        var tasks:Array<EnhanceTask> = [];

        // Weapon
        if (slots.weapon != null) {
            var w = (wSpec != "" && wSpec != "None") ? wSpec : "None";
            if (!isAlreadyEnhanced(slots.weapon, t, w)) {
                var wShopId = getWeaponShopId(t, w);
                var wMap = (wShopId == 2142) ? "forge" : null;
                tasks.push({ item: slots.weapon, baseType: t, special: w, shopId: wShopId, targetMap: wMap });
            }
        }

        // Armor
        if (slots.armor != null) {
            if (!isAlreadyEnhanced(slots.armor, t, "None")) {
                var aShopId = getBaseShopId(t);
                tasks.push({ item: slots.armor, baseType: t, special: "None", shopId: aShopId, targetMap: null });
            }
        }

        // Helm
        if (slots.helm != null) {
            var h = (hSpec != "" && hSpec != "None") ? hSpec : "None";
            if (!isAlreadyEnhanced(slots.helm, t, h)) {
                var hShopId = (h != "None") ? 2164 : getBaseShopId(t);
                var hMap = (hShopId == 2164) ? "forge" : null;
                tasks.push({ item: slots.helm, baseType: t, special: h, shopId: hShopId, targetMap: hMap });
            }
        }

        // Cape
        if (slots.cape != null) {
            var c = (cSpec != "" && cSpec != "None") ? cSpec : "None";
            if (!isAlreadyEnhanced(slots.cape, t, c)) {
                var cShopId = (c != "None") ? 2143 : getBaseShopId(t);
                var cMap = (cShopId == 2143) ? "forge" : null;
                tasks.push({ item: slots.cape, baseType: t, special: c, shopId: cShopId, targetMap: cMap });
            }
        }

        if (tasks.length == 0) {
            ApiLogger.info("Enhancement", "All equipped items already have optimal enhancements at current level!");
            if (cb != null) cb();
            return;
        }

        startQueue(tasks, cb);
    }

    public function enhanceItem(itemOrName:Dynamic, baseType:String, ?capeSpecial:String, ?helmSpecial:String, ?weaponSpecial:String, ?onComplete:Void->Void):Void {
        if (isBusy) {
            ApiLogger.warn("Enhancement", "EnhancementManager is currently busy with another queue.");
            return;
        }

        var targetItem:ItemDTO = null;
        if (Std.isOfType(itemOrName, ItemDTO)) {
            targetItem = cast itemOrName;
        } else {
            var query = Std.string(itemOrName).toLowerCase();
            if (Api.inventory != null) {
                var items = Api.inventory.getItems();
                for (it in items) {
                    if (it != null && (it.name.toLowerCase() == query || Std.string(it.itemId) == query)) {
                        targetItem = it;
                        break;
                    }
                }
            }
        }

        if (targetItem == null) {
            ApiLogger.warn("Enhancement", "enhanceItem: Item '" + Std.string(itemOrName) + "' not found in inventory.");
            if (onComplete != null) onComplete();
            return;
        }

        var slot = getItemSlot(targetItem);
        var spec = "None";
        var shopId = getBaseShopId(baseType);
        var tMap:String = null;

        if (slot == "Weapon") {
            spec = (weaponSpecial != null && weaponSpecial != "" && weaponSpecial != "None") ? weaponSpecial : "None";
            shopId = getWeaponShopId(baseType, spec);
            if (shopId == 2142) tMap = "forge";
        } else if (slot == "ba") {
            spec = (capeSpecial != null && capeSpecial != "" && capeSpecial != "None") ? capeSpecial : "None";
            if (spec != "None") { shopId = 2143; tMap = "forge"; }
        } else if (slot == "he") {
            spec = (helmSpecial != null && helmSpecial != "" && helmSpecial != "None") ? helmSpecial : "None";
            if (spec != "None") { shopId = 2164; tMap = "forge"; }
        }

        if (isAlreadyEnhanced(targetItem, baseType, spec)) {
            ApiLogger.info("Enhancement", "Item '" + targetItem.name + "' is already optimally enhanced!");
            if (onComplete != null) onComplete();
            return;
        }

        var tasks:Array<EnhanceTask> = [{
            item: targetItem,
            baseType: baseType,
            special: spec,
            shopId: shopId,
            targetMap: tMap
        }];

        startQueue(tasks, onComplete);
    }

    // ==========================================
    // QUEUE RUNNER & NETWORK ENHANCE
    // ==========================================

    private function startQueue(tasks:Array<EnhanceTask>, ?onComplete:Void->Void):Void {
        _queue = tasks;
        _onCompleteCallback = onComplete;
        _stepTimer = 0;
        _shopWaitCount = 0;
        isBusy = true;
        lastStatus = "Starting...";

        // Remember origin map to return if forge was joined
        if (Api.map != null && Api.map.name != null && Api.map.name.toLowerCase() != "forge") {
            _originMap = Api.map.name;
            _originCell = (Api.player != null) ? Api.player.cell : "Enter";
            _originPad = (Api.player != null) ? Api.player.pad : "Spawn";
        } else {
            _originMap = null;
        }

        ApiLogger.info("Enhancement", "Beginning enhancement queue (" + _queue.length + " items)...");
        _timer.start();
    }

    private function onTimerTick(e:TimerEvent):Void {
        if (!isBusy) {
            _timer.stop();
            return;
        }

        var now = ApiTime.now();
        if (now < _stepTimer) return;

        if (_queue.length == 0) {
            finishQueue();
            return;
        }

        var currentTask = _queue[0];

        // 1. Check Map requirement (Forge map for Forge shops)
        if (currentTask.targetMap != null && currentTask.targetMap != "") {
            var curMap = (Api.map != null && Api.map.name != null) ? Api.map.name.toLowerCase() : "";
            if (curMap != currentTask.targetMap.toLowerCase()) {
                lastStatus = "Joining " + currentTask.targetMap + "...";
                if (Api.map != null) Api.map.join(currentTask.targetMap + "-100000", "Enter", "Spawn");
                _stepTimer = now + 1500;
                return;
            }
        }

        // 2. Check Shop loaded
        if (!Api.shop.isShopLoaded || Api.shop.loadedShopId != currentTask.shopId) {
            lastStatus = "Loading shop " + currentTask.shopId + "...";
            if (_shopWaitCount == 0 || _shopWaitCount % 12 == 0) {
                Api.shop.loadShop(currentTask.shopId);
            }
            _shopWaitCount++;
            if (_shopWaitCount > 40) {
                ApiLogger.warn("Enhancement", "Shop " + currentTask.shopId + " failed to load in time. Skipping task.");
                _queue.shift();
                _shopWaitCount = 0;
                _stepTimer = now + 500;
            }
            return;
        }

        _shopWaitCount = 0;

        // 3. Find Best Enhancement Item in Shop
        var shopItems = getLoadedShopItems();
        if (shopItems == null || shopItems.length == 0) {
            ApiLogger.warn("Enhancement", "Shop " + currentTask.shopId + " contains no items. Skipping.");
            _queue.shift();
            return;
        }

        var playerLvl = (Api.player != null) ? Api.player.level : 100;
        var isMember = (Api.player != null) ? Api.player.isMember : false;
        var slot = getItemSlot(currentTask.item);
        var targetSpecial = currentTask.special;

        var candidates:Array<Dynamic> = [];
        for (si in shopItems) {
            if (si == null || si.sName == null) continue;
            var sLvl:Int = (si.iLvl != null) ? Std.int(si.iLvl) : 1;
            if (sLvl > playerLvl) continue;

            var isUpg:Bool = (si.bUpg == 1 || si.bUpg == "1" || si.bUpg == true);
            if (isUpg && !isMember) continue;

            var sNameL = normalizeKey(Std.string(si.sName));

            if (targetSpecial != null && targetSpecial != "" && targetSpecial != "None") {
                var specNorm = normalizeKey(targetSpecial);
                if (sNameL.indexOf(specNorm) != -1) {
                    candidates.push(si);
                }
            } else {
                if (slot == "ar" || slot == "co") {
                    if (sNameL.indexOf("armor") != -1 || sNameL.indexOf("class") != -1) candidates.push(si);
                } else if (slot == "he") {
                    if (sNameL.indexOf("helm") != -1 || sNameL.indexOf("hood") != -1) candidates.push(si);
                } else if (slot == "ba") {
                    if (sNameL.indexOf("cape") != -1 || sNameL.indexOf("back") != -1) candidates.push(si);
                } else if (slot == "Weapon") {
                    if (sNameL.indexOf("weapon") != -1 || sNameL.indexOf("blade") != -1) candidates.push(si);
                }
            }
        }

        if (candidates.length == 0) {
            ApiLogger.warn("Enhancement", "No matching enhancement item found in shop " + currentTask.shopId + " for " + currentTask.item.name);
            _queue.shift();
            return;
        }

        // Sort descending by Level, then Upgrade flag
        candidates.sort(function(a:Dynamic, b:Dynamic):Int {
            var aLvl:Int = (a.iLvl != null) ? Std.int(a.iLvl) : 1;
            var bLvl:Int = (b.iLvl != null) ? Std.int(b.iLvl) : 1;
            if (aLvl != bLvl) return bLvl - aLvl;
            var aUpg:Int = (a.bUpg == 1 || a.bUpg == true) ? 1 : 0;
            var bUpg:Int = (b.bUpg == 1 || b.bUpg == true) ? 1 : 0;
            return bUpg - aUpg;
        });

        var bestEnh = candidates[0];

        // 4. Send Packet
        var roomId:Dynamic = (_game != null && _game.world != null && _game.world.curRoom != null) ? _game.world.curRoom : 1;
        if (_game != null && _game.sfc != null) {
            _game.sfc.sendString("%xt%zm%enhanceItemShop%" + roomId + "%" + currentTask.item.itemId + "%" + bestEnh.ItemID + "%" + currentTask.shopId + "%");
            ApiLogger.info("Enhancement", "Enhanced [" + currentTask.item.name + "] with [" + bestEnh.sName + "] (Lvl " + bestEnh.iLvl + ")");
        }

        _queue.shift();
        _stepTimer = now + 700; // 700ms cooldown between item enhancements
    }

    private function finishQueue():Void {
        isBusy = false;
        _timer.stop();
        lastStatus = "Done";

        // Return to origin map if we moved away to forge
        if (_originMap != null && Api.map != null && Api.map.name != null && Api.map.name.toLowerCase() == "forge") {
            var oMap = _originMap;
            var oCell = (_originCell != null) ? _originCell : "Enter";
            var oPad = (_originPad != null) ? _originPad : "Spawn";
            _originMap = null;
            Api.map.join(oMap, oCell, oPad);
        }

        ApiLogger.info("Enhancement", "Enhancement queue completed successfully!");
        if (_onCompleteCallback != null) {
            var cb = _onCompleteCallback;
            _onCompleteCallback = null;
            try { cb(); } catch (_:Dynamic) {}
        }
    }

    private function getLoadedShopItems():Array<Dynamic> {
        if (_game == null) return [];
        try {
            if (_game.world != null && _game.world.shopinfo != null && _game.world.shopinfo.items != null) {
                return cast _game.world.shopinfo.items;
            }
            if (_game.ui != null && _game.ui.mcPopup != null) {
                var mcShop = _game.ui.mcPopup.getChildByName("mcShop");
                if (mcShop != null && mcShop.shopinfo != null && mcShop.shopinfo.items != null) {
                    return cast mcShop.shopinfo.items;
                }
            }
        } catch (_:Dynamic) {}
        return [];
    }

    // ==========================================
    // CHECKERS & CONVERTERS
    // ==========================================

    public function isAlreadyEnhanced(item:ItemDTO, baseType:String, special:String):Bool {
        if (item == null) return false;
        var playerLvl = (Api.player != null) ? Api.player.level : 100;
        var itemLvl = item.enhLevel;
        if (itemLvl < playerLvl) return false;

        var patternId = item.enhPatternId;
        var procId = item.procId;
        var targetBasePattern = getBasePatternId(baseType);
        var slot = getItemSlot(item);

        if (slot == "ba") {
            if (special != null && special != "" && special != "None") {
                return patternId == getCapePatternId(special);
            }
            return patternId == targetBasePattern;
        } else if (slot == "he") {
            if (special != null && special != "" && special != "None") {
                return patternId == getHelmPatternId(special);
            }
            return patternId == targetBasePattern;
        } else if (slot == "Weapon") {
            if (special != null && special != "" && special != "None") {
                var targetProc = getWeaponProcId(special);
                if (targetProc >= 2 && targetProc <= 6) {
                    return patternId == targetBasePattern && procId == targetProc;
                } else if (targetProc == 1 || targetProc >= 7) {
                    return (patternId == 10 || patternId == targetBasePattern) && procId == targetProc;
                }
            } else {
                return patternId == targetBasePattern && procId == 0;
            }
        } else if (slot == "ar" || slot == "co") {
            return patternId == targetBasePattern;
        }
        return false;
    }

    public function getItemSlot(item:ItemDTO):String {
        if (item == null) return "";
        if (item.es != null && item.es != "") return item.es;
        var st = (item.type != null) ? item.type.toLowerCase() : "";
        if (st == "class" || st == "armor") return "ar";
        if (st == "helm") return "he";
        if (st == "cape") return "ba";
        return "Weapon";
    }

    public function getBaseShopId(baseType:String):Int {
        var lvl = (Api.player != null) ? Api.player.level : 100;
        var b = normalizeKey(baseType);
        if (lvl >= 50) {
            if (b == "fighter") return 768;
            if (b == "thief") return 767;
            if (b == "hybrid") return 766;
            if (b == "wizard") return 765;
            if (b == "healer") return 762;
            if (b == "spellbreaker") return 764;
            return 763; // Lucky default
        } else {
            if (b == "fighter") return 141;
            if (b == "thief") return 142;
            if (b == "hybrid") return 143;
            if (b == "wizard") return 144;
            if (b == "healer") return 145;
            if (b == "spellbreaker") return 146;
            return 147; // Lucky default
        }
    }

    public function getWeaponShopId(baseType:String, special:String):Int {
        if (special == null || special == "" || special == "None") {
            return getBaseShopId(baseType);
        }
        var specNorm = normalizeKey(special);
        if (isAweSpecial(specNorm)) {
            var b = normalizeKey(baseType);
            if (b == "fighter") return 635;
            if (b == "thief") return 637;
            if (b == "hybrid") return 633;
            if (b == "wizard" || b == "spellbreaker") return 636;
            if (b == "healer") return 638;
            return 639; // Lucky default
        }
        return 2142; // Forge Weapon shop
    }

    public function getBasePatternId(baseType:String):Int {
        var b = normalizeKey(baseType);
        if (b == "fighter") return 2;
        if (b == "thief") return 3;
        if (b == "hybrid") return 5;
        if (b == "wizard") return 6;
        if (b == "healer") return 7;
        if (b == "spellbreaker") return 8;
        return 9; // Lucky
    }

    public function getCapePatternId(special:String):Int {
        var s = normalizeKey(special);
        if (s == "forge") return 10;
        if (s == "absolution") return 11;
        if (s == "avarice") return 12;
        if (s == "vainglory") return 24;
        if (s == "penitence") return 29;
        if (s == "lament") return 30;
        return 0;
    }

    public function getHelmPatternId(special:String):Int {
        var s = normalizeKey(special);
        if (s == "forge") return 10;
        if (s == "vim") return 25;
        if (s == "examen") return 26;
        if (s == "pneuma") return 27;
        if (s == "anima") return 28;
        if (s == "hearty") return 32;
        return 0;
    }

    public function getWeaponProcId(special:String):Int {
        var s = normalizeKey(special);
        if (s == "forge") return 1;
        if (s == "spiral_carve") return 2;
        if (s == "awe_blast") return 3;
        if (s == "health_vamp") return 4;
        if (s == "mana_vamp") return 5;
        if (s == "powerword_die") return 6;
        if (s == "lacerate") return 7;
        if (s == "smite") return 8;
        if (s == "valiance") return 9;
        if (s == "arcanas_concerto" || s == "arcanasconcerto") return 10;
        if (s == "acheron") return 11;
        if (s == "elysium") return 12;
        if (s == "praxis") return 13;
        if (s == "dauntless") return 14;
        if (s == "ravenous") return 15;
        return 0;
    }

    public function patternIdToName(patternId:Int):String {
        return switch (patternId) {
            case 2: "Fighter";
            case 3: "Thief";
            case 5: "Hybrid";
            case 6: "Wizard";
            case 7: "Healer";
            case 8: "SpellBreaker";
            case 9: "Lucky";
            case 10: "Forge";
            default: "None";
        };
    }

    public function capePatternIdToName(patternId:Int):String {
        return switch (patternId) {
            case 10: "Forge";
            case 11: "Absolution";
            case 12: "Avarice";
            case 24: "Vainglory";
            case 29: "Penitence";
            case 30: "Lament";
            default: patternIdToName(patternId);
        };
    }

    public function helmPatternIdToName(patternId:Int):String {
        return switch (patternId) {
            case 10: "Forge";
            case 25: "Vim";
            case 26: "Examen";
            case 27: "Pneuma";
            case 28: "Anima";
            case 32: "Hearty";
            default: patternIdToName(patternId);
        };
    }

    public function weaponProcIdToName(procId:Int):String {
        return switch (procId) {
            case 1: "Forge";
            case 2: "Spiral Carve";
            case 3: "Awe Blast";
            case 4: "Health Vamp";
            case 5: "Mana Vamp";
            case 6: "Powerword Die";
            case 7: "Lacerate";
            case 8: "Smite";
            case 9: "Valiance";
            case 10: "Arcana's Concerto";
            case 11: "Acheron";
            case 12: "Elysium";
            case 13: "Praxis";
            case 14: "Dauntless";
            case 15: "Ravenous";
            default: "None";
        };
    }

    public static function normalizeKey(s:String):String {
        if (s == null) return "";
        var k = s.toLowerCase();
        k = StringTools.replace(k, " ", "_");
        k = StringTools.replace(k, "'", "");
        k = StringTools.replace(k, "-", "_");
        return k;
    }
}
