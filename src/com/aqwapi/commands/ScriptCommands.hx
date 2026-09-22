package com.aqwapi.commands;

import com.aqwapi.AqwApi;
import com.aqwapi.data.EntityDTO;
import com.aqwapi.modules.ScriptManager;
import com.aqwapi.modules.CombatManager;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.AqwTime;

class ScriptCommands {
    private static inline function _parseInt(v:Dynamic, def:Int = 0):Int {
        return com.aqwapi.utils.AqwUtils.parseInt(v, def);
    }

		
    public static function execute(cmd:Dynamic, manager:ScriptManager):Void {
        var action:String = Std.string(cmd.action).toUpperCase();
        switch (action) {
			case "JOIN": cmd_join(cmd, manager);
			case "RELOAD": cmd_reload(cmd, manager);
			case "LOADQUEST": cmd_loadquest(cmd, manager);
			case "GETMAPITEM": cmd_getmapitem(cmd, manager);
			case "ACCEPT": cmd_accept(cmd, manager);
			case "COMPLETE": cmd_complete(cmd, manager);
			case "EQUIP": cmd_equip(cmd, manager);
			case "EQUIPCLASS": cmd_equipclass(cmd, manager);
			case "BANK": cmd_bank(cmd, manager);
			case "UNBANK": cmd_unbank(cmd, manager);
			case "KILL": cmd_kill(cmd, manager);
			case "DELAY": cmd_delay(cmd, manager);
			case "GETDROP": cmd_getdrop(cmd, manager);
			case "DUMP_DROPS": cmd_dump_drops(cmd, manager);
			case "TEST_DROP": cmd_test_drop(cmd, manager);
			case "LOG": cmd_log(cmd, manager);
			case "COMBAT": cmd_combat(cmd, manager);
			case "AUTOQUEST": cmd_autoquest(cmd, manager);
			case "LABEL": cmd_label(cmd, manager);
			case "GOTO": cmd_goto(cmd, manager);
			case "IFHAS": cmd_ifhas(cmd, manager);
			case "IFNOTHAS": cmd_ifnothas(cmd, manager);
			case "IFRANK": cmd_ifrank(cmd, manager);
			case "IFNOTRANK": cmd_ifnotrank(cmd, manager);
			case "IFQUEST": cmd_ifquest(cmd, manager);
			case "IFNOTQUEST": cmd_ifnotquest(cmd, manager);
			case "SKIPCUTSCENE": cmd_skipcutscene(cmd, manager);
			case "IFGOLD": cmd_ifgold(cmd, manager);
			case "IFLEVEL": cmd_iflevel(cmd, manager);
			case "WAITFOR": cmd_waitfor(cmd, manager);
			case "LOADSHOP": cmd_loadshop(cmd, manager);
			case "BUY": cmd_buy(cmd, manager);
			case "SELL": cmd_sell(cmd, manager);
			case "JUMP": cmd_jump(cmd, manager);
			case "MAPDUMP": cmd_mapdump(cmd, manager);
			case "JUMPTOMMID": cmd_jumptommid(cmd, manager);
			case "JUMPTOMOB": cmd_jumptomob(cmd, manager);
			case "LOADBANK": cmd_loadbank(cmd, manager);
			case "MANUAL_UNBANK": cmd_manual_unbank(cmd, manager);
			case "MANUAL_BANK": cmd_manual_bank(cmd, manager);
            default:
                ApiLogger.warn("Command", "Unknown command: " + cmd.action);
                manager.currentIndex++;
        }
    }


	public static function cmd_join(cmd:Dynamic, manager:ScriptManager):Void {
		var now:Float = AqwTime.now();
		if (cmd.args.length < 1) {
			manager.currentIndex++;
			return;
		}

		var mapName:String = Std.string(cmd.args[0]);
		var cell:String = cmd.args.length >= 2 ? Std.string(cmd.args[1]) : "Enter";
		var pad:String = cmd.args.length >= 3 ? Std.string(cmd.args[2]) : "Spawn";
		var targetMapClean:String = mapName.split("-")[0].toLowerCase();
		var curMapClean:String = AqwApi.map.name.toLowerCase();

		// If already in target map and loaded, just jump cell
		if (curMapClean == targetMapClean && AqwApi.map.isLoaded) {
			AqwApi.map.jump(cell, pad);
			cmd.joinTimer = null;
			manager.currentIndex++;
			return;
		}

		// First tick: send join request
		if (cmd.joinTimer == null) {
			cmd.joinTimer = now;
			manager.statusText = "Joining " + mapName + "...";
			AqwApi.map.join(mapName, cell, pad);
			return;
		}

		// Subsequent ticks: check if arrived and loaded
		if (curMapClean == targetMapClean && AqwApi.map.isLoaded) {
			AqwApi.map.jump(cell, pad);
			cmd.joinTimer = null;
			manager.currentIndex++;
			return;
		}

		// Safety timeout: 7000ms
		if (now - cmd.joinTimer > 7000) {
			ApiLogger.warn("Map", "Join " + mapName + " timed out! Continuing...");
			cmd.joinTimer = null;
			manager.currentIndex++;
			return;
		}

		manager.statusText = "Waiting for " + mapName + " to load...";
		return;
	}

		public static function cmd_reload(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
					manager.statusText = "Reloading Zone...";
					AqwApi.combat.dropCombat();
					manager.waitTimer = now + 1000;
					manager.currentIndex++;
					return;
		}

		public static function cmd_loadquest(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var qids:Array<Dynamic> = [];
							for (i in 0...Std.int(cmd.args.length)) {
								qids.push(_parseInt(cmd.args[i]));
							}
							manager.statusText = "Loading Quests: " + qids.join(",");
							if (com.aqwapi.AqwApi.game != null && com.aqwapi.AqwApi.game.world != null && com.aqwapi.AqwApi.game.world.getQuests != null) {
								com.aqwapi.AqwApi.game.world.getQuests(qids);
							}
							manager.waitTimer = now + 1500; // In a full implementation, wait for QUEST_UPDATED event
							manager.currentIndex++;
						}
						return;

		}

		public static function cmd_getmapitem(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						// GETMAPITEM <itemID>, <qty>
						// Sends getMapItem packet qty times with 1.5s between each
						// Used for map item quests (no combat required)
						if (cmd.args.length >= 1 && com.aqwapi.AqwApi.game != null && com.aqwapi.AqwApi.game.sfc != null) {
							var mapItemID:Int = _parseInt(cmd.args[0]);
							var mapItemQty:Int = cmd.args.length >= 2 ? _parseInt(cmd.args[1]) : 1;
							if (cmd.gmiCount == null) cmd.gmiCount = 0;
							if (cmd.gmiCount < mapItemQty) {
								AqwApi.map.getMapItem(mapItemID);
								cmd.gmiCount++;
								manager.statusText = "GetMapItem " + mapItemID + " (" + cmd.gmiCount + "/" + mapItemQty + ")";
								manager.waitTimer = now + 1500;
							} else {
								manager.currentIndex++;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_accept(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
			
			if (cmd.args.length >= 1) {
				qid = _parseInt(cmd.args[0]);
				manager.statusText = "Accepting Quest " + qid;
				
				var inProgress:Bool = false;
				if (world.isQuestInProgress != null && world.isQuestInProgress(qid)) {
					inProgress = true;
				}
				
				if (!inProgress) {
					if (cmd.acceptTimer == null) {
						// First time
						cmd.acceptTimer = now;
						AqwApi.quest.accept(qid);
						return; // Wait for next tick
					} else if (now - cmd.acceptTimer < 3000) {
						// Still waiting for server
						return;
					} else {
						// Timeout - failed to accept (probably one-time/daily done)
						ApiLogger.warn("Quest", "Quest " + qid + " failed to accept! Skipping...");
						
						var completeIdx:Int = -1;
						for (i in (manager.currentIndex + 1)...manager.commands.length) {
							var futureCmd:Dynamic = manager.commands[i];
							if (futureCmd.action == "COMPLETE" && futureCmd.args.length >= 1 && _parseInt(futureCmd.args[0]) == qid) {
								completeIdx = i;
								break;
							}
						}
						
						if (completeIdx != -1) {
							manager.currentIndex = completeIdx + 1; // Skip past the complete
						} else {
							manager.currentIndex++;
						}
						
						cmd.acceptTimer = null;
						return;
					}
				}
				
				// Reached here means inProgress is true
				cmd.acceptTimer = null;
				manager.currentIndex++;
			}
		}
		public static function cmd_complete(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var cqid:Int = _parseInt(cmd.args[0]);
							manager.statusText = "Completing Quest " + cqid;
							AqwApi.quest.complete(cqid);
							// Mark in our local tracker so IFQUEST knows it was attempted
							manager.completedThisSession[cqid] = true;
							manager.waitTimer = now + 2000;
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_equip(cmd:Dynamic, manager:ScriptManager):Void {
			var now:Float = AqwTime.now();
			if (cmd.args.length < 1) {
				manager.currentIndex++;
				return;
			}

			var equipName:String = cmd.args.join(", ").toLowerCase();

			// If already equipped, advance immediately!
			if (AqwApi.inventory.isEquipped(equipName)) {
				cmd.equipTimer = null;
				cmd.waitInFlight = null;
				manager.currentIndex++;
				return;
			}

			// First tick: verify item presence in inventory, then trigger equip
			if (cmd.equipTimer == null) {
				if (!AqwApi.inventory.hasItem(equipName)) {
					// Wait up to 2000ms if item was just bought / in flight
					if (cmd.waitInFlight == null) cmd.waitInFlight = now;
					if (now - cmd.waitInFlight < 2000) {
						manager.statusText = "Waiting for " + equipName + " in inventory...";
						return;
					}
					ApiLogger.warn("Inventory", "Cannot equip '" + equipName + "': item not in inventory!");
					cmd.waitInFlight = null;
					manager.currentIndex++;
					return;
				}

				cmd.equipTimer = now;
				cmd.waitInFlight = null;
				manager.statusText = "Equipping: " + equipName;
				AqwApi.inventory.equip(equipName);
				return;
			}

			// Subsequent ticks: check if equipped
			if (AqwApi.inventory.isEquipped(equipName)) {
				cmd.equipTimer = null;
				manager.currentIndex++;
				return;
			}

			// Timeout after 3000ms
			if (now - cmd.equipTimer >= 3000) {
				ApiLogger.warn("Inventory", "Equip '" + equipName + "' timed out! Continuing...");
				cmd.equipTimer = null;
				manager.currentIndex++;
			}
		}

		public static function cmd_equipclass(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
			if (cmd.args.length >= 1) {
				var lType:String = cmd.args[0].toLowerCase();
				manager.statusText = "Equipping Loadout: " + lType;
				AqwApi.combat.dropCombat();
				AqwApi.combat.equipLoadout(lType);
				manager.waitTimer = now + 3000;
				manager.currentIndex++;
			} else {
				ApiLogger.warn("Command", "Invalid EQUIPCLASS command syntax. Use Farm, Solo, Boss, or Dodge.");
				manager.currentIndex++;
			}
			return;
		}

		public static function cmd_bank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var bankName:String = cmd.args.join(", ").toLowerCase();
							manager.statusText = "Banking: " + bankName;
							AqwApi.inventory.bank(bankName);
							manager.waitTimer = now + 1500;
							manager.currentIndex++;
						}
						return;
						


		}

		public static function cmd_unbank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var unbankName:String = cmd.args.join(", ").toLowerCase();
							manager.statusText = "Unbanking: " + unbankName;
							AqwApi.inventory.unbank(unbankName);
							manager.waitTimer = now + 1500;
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_kill(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
					if (cmd.args.length >= 3) {
						var monster:String = cmd.args[0];
						var itemName:String = cmd.args[1];
						var qty:Int = _parseInt(cmd.args[2]);
						var mmid:String = (cmd.args.length >= 4) ? cmd.args[3] : null;
						
						manager.statusText = "Hunting " + monster + " for " + itemName + " (" + qty + ")";
							var currentQty:Int = AqwApi.inventory.getQuestQuantity(itemName);
							
							var targetDrops:Array<Dynamic> = itemName.toLowerCase().split("|");
							AqwApi.drop.targetDrops = targetDrops;
							
							if (cmd.lastQty != currentQty) {
								cmd.lastQty = currentQty;
								com.aqwapi.AqwApi.dispatcher.dispatchEvent(new ApiEvent(
									ApiEvent.STICKY_NOTIFICATION, 
									"Farming " + monster + " for " + itemName + " " + currentQty + "/" + qty, 
									{ id: "farming_status" }
								));
							}
							
							if (currentQty >= qty) {
								// Done - stop combat and advance
								com.aqwapi.AqwApi.dispatcher.dispatchEvent(new ApiEvent(
									ApiEvent.REMOVE_STICKY, 
									"", 
									{ id: "farming_status" }
								));
								AqwApi.drop.targetDrops = [];
								if (CombatManager.IS_ON) CombatManager.stop();
								manager.currentIndex++;
							} else {
								// Still need items - show progress
							
							// Auto-pickup if the items we are farming dropped as real (non-temp) items
							// Supports multiple items separated by '|' (e.g., "Bone Dust|Undead Essence")
							AqwApi.drop.acceptPendingDrops(targetDrops);

								if (cmd.lockedCell == null) {
									var initialTarget:EntityDTO = mmid != null ? AqwApi.monster.findByMapId(mmid, true) : AqwApi.monster.findByName(monster, true);
									ApiLogger.debug("Command", "Alive lookup for " + monster + ": " + (initialTarget != null ? initialTarget.cell : "null"));
									if (initialTarget == null) {
										initialTarget = mmid != null ? AqwApi.monster.findByMapId(mmid, false) : AqwApi.monster.findByName(monster, false);
										ApiLogger.debug("Command", "Dead/Unknown lookup for " + monster + ": " + (initialTarget != null ? initialTarget.cell : "null"));
									}
									if (initialTarget != null) {
										cmd.lockedCell = initialTarget.cell;
										cmd.lockedMMID = initialTarget.mapId;
									}
								}
																var foundMMID:String = cmd.lockedMMID != null ? cmd.lockedMMID : mmid;
									var monCell:String = cmd.lockedCell;
									ApiLogger.debug("Command", "monCell locked to: " + monCell);
									
									var target:EntityDTO = foundMMID != null ? AqwApi.monster.findByMapId(foundMMID, false) : AqwApi.monster.findByName(monster, false);
									var approachMon:Dynamic = target != null ? target.raw : null;
								
								if (monCell != null && world.strFrame != monCell && cmd.pendingTeleport == null) {
									// Cross-cell: jump first.
									AqwApi.map.jump(monCell, "Enter");
									cmd.pendingTeleport = monCell;
								cmd.teleportTimer = now + 1000; // Give the game a full second to load the cell
								manager.waitTimer = now + 1000;
							}
							
							if (cmd.pendingTeleport != null) {
								if (world.strFrame == cmd.pendingTeleport && now >= cmd.teleportTimer) {
									// Arrived and cell has fully loaded! Snap and start combat
																		CombatManager.start(true, true);
																		CombatManager.targetName = monster;
																		CombatManager.lockedMMID = (foundMMID != null) ? foundMMID : mmid;
									
									var cellMons:Dynamic = (world.getMonstersByCell != null) ? world.getMonstersByCell(world.strFrame) : world.monsters;
									for (cm in (cast cellMons : Array<Dynamic>)) {
										if (cm == null || cm.pMC == null) continue;
										var cmName:String = (cm.objData && cm.objData.strMonName) ? Std.string(cm.objData.strMonName).toLowerCase() : null;
										var cmMMID:String = null;
										if (cm.dataLeaf && cm.dataLeaf.MonMapID) cmMMID = Std.string(cm.dataLeaf.MonMapID);
										else if (cm.objData && cm.objData.MonMapID) cmMMID = Std.string(cm.objData.MonMapID);
										var cmMatch:Bool = CombatManager.lockedMMID != null ? (cmMMID == CombatManager.lockedMMID) : (monster == "*" || (cmName != null && cmName.indexOf(monster.toLowerCase()) != -1));
										if (cmMatch) {
											AqwApi.map.snapTo(cm);
											break;
										}
									}
									cmd.pendingTeleport = null;
									manager.waitTimer = now + 1000;
								} else {
									// Waiting for cell load and timer...
									manager.waitTimer = now;
								}
							} else if (!CombatManager.IS_ON && world.strFrame == monCell) {
								// We are in the correct cell (or couldn't find the cell yet). Start combat!
																CombatManager.start(true, true);
																CombatManager.targetName = monster;
																CombatManager.lockedMMID = (foundMMID != null) ? foundMMID : mmid;
								
								// Snap directly onto the mob
								AqwApi.map.snapTo(approachMon);
								manager.waitTimer = now + 1000;
							} else if (cmd.pendingTeleport == null && manager.waitTimer <= now) {
								manager.waitTimer = now + 1000;
							}
						}
						} else {
							ApiLogger.warn("Command", "Invalid KILL syntax. Use: KILL Monster Name, Item Name, Quantity");
							manager.statusText = "KILL Syntax Error";
							manager.currentIndex++;
						}
						return;
						
		}


		public static function cmd_delay(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length > 0) {
							var ms:Int = _parseInt(cmd.args[0]);
							manager.waitTimer = now + ms;
							manager.statusText = "Waiting " + ms + "ms...";
						}
						manager.currentIndex++;
						return;
						

						
		}

		public static function cmd_getdrop(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
							if (cmd.args.length > 0 && world != null) {
								var dropTarget:String = cmd.args[0].toLowerCase();

								var di:Int = (cast AqwApi.drop.pendingDrops : Array<Dynamic>).length - 1;
								while (di >= 0) {
									var pDrop:Dynamic = AqwApi.drop.pendingDrops[di];
									if (dropTarget == "all" || Std.string(pDrop.sName).toLowerCase() == dropTarget) {
										AqwApi.transport.sendExtensionCommand("getDrop", [pDrop.ItemID]);
										AqwApi.drop.pendingDrops.splice(di, 1);
									}
									di--;
								}
							}
							manager.currentIndex++;
							return;
		}

		public static function cmd_dump_drops(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (world != null) {
							var found:Bool = false;
							if (world.items != null) {
								for (i in 0...Std.int(world.items.length)) {
									var itemObj:Dynamic = world.items[i];
									if (itemObj != null && itemObj.sName != null) {
										var sName:String = itemObj.sName.toLowerCase();
										if (sName.indexOf("essence") != -1 || sName.indexOf("bone") != -1) {
// 											 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "world.items HAS: " + itemObj.sName + " ID: " + itemObj.ItemID, "SERVER", "", 0);
											found = true;
										}
									}
								}
							}
							if (!found) {
// 								 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "Not found in world.items either!", "SERVER", "", 0);
							}
						}
						manager.currentIndex++;
						return;
		}

		public static function cmd_test_drop(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (world != null) {
							var found:Bool = false;
							if (world.dropStack != null) {
								for (i in 0...Std.int(world.dropStack.length)) {
									var dropObj:Dynamic = world.dropStack[i];
// 									 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "DROP: " + dropObj.sName + " ID: " + dropObj.ItemID, "SERVER", "", 0);
									found = true;
								}
							}
							if (com.aqwapi.AqwApi.game.ui != null && com.aqwapi.AqwApi.game.ui.dropStack != null) {
								for (j in 0...Std.int(com.aqwapi.AqwApi.game.ui.dropStack.length)) {
									var uDrop:Dynamic = com.aqwapi.AqwApi.game.ui.dropStack[j];
// 									 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "UIDROP: " + uDrop.sName + " ID: " + uDrop.ItemID, "SERVER", "", 0);
									found = true;
								}
							}
							if (!found) {
// 								 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "NO DROPS FOUND IN dropStack or ui.dropStack", "SERVER", "", 0);
							}
						}
						manager.currentIndex++;
						return;
		}

		public static function cmd_log(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length > 0) {
							var msg:String = cmd.args.join(",");
							ApiLogger.info("Script", msg);
							com.aqwapi.AqwApi.dispatcher.dispatchEvent(new ApiEvent(ApiEvent.NOTIFICATION, msg));
							manager.statusText = msg;
						}
						manager.currentIndex++;
						return;
						
		}

		public static function cmd_combat(cmd:Dynamic, manager:ScriptManager):Void {
			if (cmd.args != null && (cast cmd.args : Array<Dynamic>).length >= 1) {
				var firstArg:String = StringTools.trim(Std.string(cmd.args[0])).toLowerCase();
				if (firstArg == "stop") {
					CombatManager.stop();
					manager.statusText = "Combat stopped";
					ApiLogger.info("Combat", "Combat stopped");
				} else if (firstArg == "smart") {
					CombatManager.start(true, false);
					manager.statusText = "Combat: Smart";
					ApiLogger.info("Combat", "Combat: Smart");
				} else if (firstArg.indexOf("custom") == 0) {
					var rotInts:Array<Int> = [];
					var rotParts:Array<String> = [];
					var afterCustom:String = StringTools.trim(firstArg.substr(6));
					if (afterCustom.length > 0) {
						rotParts.push(afterCustom);
					}
					var argsArr:Array<Dynamic> = cast cmd.args;
					for (i in 1...argsArr.length) {
						var aStr:String = StringTools.trim(Std.string(argsArr[i]));
						if (aStr.length > 0) rotParts.push(aStr);
					}

					for (p in rotParts) {
						if (p.indexOf(",") != -1) {
							var sub = p.split(",");
							for (s in sub) {
								var v = _parseInt(StringTools.trim(s));
								if (v > 0) rotInts.push(v);
							}
						} else if (p.length > 1 && _parseInt(p) > 9) {
							for (ci in 0...p.length) {
								var cv = _parseInt(p.charAt(ci));
								if (cv > 0) rotInts.push(cv);
							}
						} else {
							var v = _parseInt(p);
							if (v > 0) rotInts.push(v);
						}
					}

					if (rotInts.length > 0) {
						CombatManager.setCustomRotation(rotInts);
					}
					CombatManager.start(false, false);
					manager.statusText = rotInts.length > 0 ? "Combat: Custom [" + rotInts.join("-") + "]" : "Combat: Custom";
					ApiLogger.info("Combat", manager.statusText);
				}
				manager.currentIndex++;
			} else {
				manager.currentIndex++;
			}
			return;
		}

		public static function cmd_autoquest(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							if (cmd.args[0].toLowerCase() == "stop") {
								AqwApi.quest.stopAuto();
								manager.statusText = "AutoQuest stopped";
							} else {
								var qStr:String = cmd.args.join(",");
								AqwApi.quest.startAuto(qStr);
								manager.statusText = "Background QuestManager: " + qStr;
							}
							manager.currentIndex++;
						}
						return;
		}

		public static function cmd_label(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						manager.currentIndex++;
						return;
						
		}

		public static function cmd_goto(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var labelName:String = cmd.args[0].toLowerCase();
							if (Reflect.hasField(manager.labels, labelName)) {
								manager.currentIndex = Std.int(Reflect.field(manager.labels, labelName));
							} else {
								manager.currentIndex++;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_ifhas(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var targetItemName2:String = cmd.args[0].toLowerCase();
							var targetQty:Int = 1;
							if (cmd.args.length >= 2) {
								targetQty = _parseInt(cmd.args[1]);
							}
							
							var itemQty:Int = manager.getItemCount(targetItemName2);
							
							var hasCondition:Bool = (itemQty >= targetQty);
							var isMet:Bool = (cmd.action == "IFHAS") ? hasCondition : !hasCondition;
							
							if (isMet) {
								// Condition met, proceed to next line
								manager.currentIndex++;
							} else {
								// Condition not met, skip the next line
								manager.currentIndex += 2;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_ifnothas(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var targetItemName2:String = cmd.args[0].toLowerCase();
							var targetQty:Int = 1;
							if (cmd.args.length >= 2) {
								targetQty = _parseInt(cmd.args[1]);
							}
							
							var itemQty:Int = manager.getItemCount(targetItemName2);
							
							var hasCondition:Bool = (itemQty >= targetQty);
							var isMet:Bool = (cmd.action == "IFHAS") ? hasCondition : !hasCondition;
							
							if (isMet) {
								// Condition met, proceed to next line
								manager.currentIndex++;
							} else {
								// Condition not met, skip the next line
								manager.currentIndex += 2;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_ifrank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 2) {
							var factionName:String = cmd.args[0].toLowerCase();
							var targetRank:Int = _parseInt(cmd.args[1]);
							
							var currentRank:Int = 1;
							if (world.myAvatar != null && world.myAvatar.factions != null) {
								for (fi in 0...Std.int(world.myAvatar.factions.length)) {
									var fac:Dynamic = world.myAvatar.factions[fi];
									if (fac != null && fac.sName != null && fac.sName.toLowerCase() == factionName) {
										currentRank = _parseInt(fac.iRank);
										break;
									}
								}
							}
							
							if (currentRank < targetRank) {
								manager.currentIndex += 2;
								return;
							}
						}
						manager.currentIndex++;
						return;
						
		}

		public static function cmd_ifnotrank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 2) {
							var factionNameNot:String = cmd.args[0].toLowerCase();
							var targetRankNot:Int = _parseInt(cmd.args[1]);
							
							var currentRankNot:Int = 1;
							if (world.myAvatar != null && world.myAvatar.factions != null) {
								for (fin in 0...Std.int(world.myAvatar.factions.length)) {
									var facNot:Dynamic = world.myAvatar.factions[fin];
									if (facNot != null && facNot.sName != null && facNot.sName.toLowerCase() == factionNameNot) {
										currentRankNot = _parseInt(facNot.iRank);
										break;
									}
								}
							}
							
							if (currentRankNot >= targetRankNot) {
								manager.currentIndex += 2;
								return;
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_ifquest(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
					if (cmd.args.length >= 1) {
						qid = _parseInt(cmd.args[0]);
						var qslot:Int = -1;
						var qval:Int = -1;
						
						var isCompleted:Bool = false;
						
						if (world != null && world.questTree != null && world.questTree[qid] != null) {
							qslot = world.questTree[qid].Slot;
							qval = world.questTree[qid].Value;
						}
						
						// Method 1: Local session tracking - set by COMPLETE when server confirms
						// This is the most reliable since WE control when we mark it done
						if (manager.completedThisSession[qid] == true) {
							isCompleted = true;
						}
						
						// Method 2: Slot-based check (server sends on login, updates on completion)
						// NOTE: We intentionally do NOT check questTree[id].bComplete because
						// the game client sets bComplete optimistically BEFORE server confirms,
						// causing false positives (bot skips to locked quests).
						if (!isCompleted && qslot >= 0) {
							try {
								if (world.getQuestValue != null) {
									var slotVal:Dynamic = world.getQuestValue(qslot);
									if (slotVal != null && Std.int(slotVal) >= qval) {
										isCompleted = true;
									}
								}
							} catch (e2:Dynamic) {}
							
							// Method 3: alternate slot storage
							try {
								if (!isCompleted && world.questSlots != null && world.questSlots[qslot] != null) {
									if (Std.int(world.questSlots[qslot]) >= qval) {
										isCompleted = true;
									}
								}
							} catch (e3:Dynamic) {}
						}
							// Method 4: Permanent story quest completion (sField + iIndex bitmask)
							if (!isCompleted && world != null && world.questTree != null && world.questTree[qid] != null) {
								var qData:Dynamic = world.questTree[qid];
								if (qData.sField != null && qData.iIndex >= 0) {
									try {
										if (world.getAchievement != null) {
											var ach:Int = world.getAchievement(qData.sField, qData.iIndex);
											if (ach != 0) {
												isCompleted = true;
											}
										}
									} catch (e4:Dynamic) {}
								}
							}
							
						if (isCompleted) {
							ApiLogger.info("Quest", "Quest " + qid + " is already completed! Skipping...");
						}
						
						if (!isCompleted) {
							manager.currentIndex += 2;
							return;
						}
					}
					manager.currentIndex++;
					return;

		}

		public static function cmd_ifnotquest(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var qidNot:Int = _parseInt(cmd.args[0]);
							var qslotNot:Int = -1;
							var qvalNot:Int = -1;
							
							var isCompletedNot:Bool = false;
							if (qslotNot >= 0 && world.getQuestValue != null) {
								isCompletedNot = (world.getQuestValue(qslotNot) >= qvalNot);
							}
							
							if (isCompletedNot) {
								manager.currentIndex += 2;
								return;
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_skipcutscene(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (world != null && world.mcExtSWF != null && world.mcExtSWF.numChildren > 0) {
							var ext:Dynamic = world.mcExtSWF.getChildAt(0);
							if (ext != null && ext.totalFrames != null && ext.gotoAndPlay != null) {
								var tf:Int = ext.totalFrames;
								var cf:Int = ext.currentFrame;
								if (tf > 2 && cf < tf - 2) {
									ext.gotoAndPlay(tf - 2);
								}
							} else {
								while (world.mcExtSWF.numChildren > 0) {
									world.mcExtSWF.removeChildAt(0);
								}
								if (world.showInterface != null) {
									world.showInterface();
								}
							}
						}
						manager.currentIndex++;
						return;

		}
		public static function cmd_ifgold(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var targetGold:Int = _parseInt(cmd.args[0]);
							var currentGold:Int = 0;
							if (world.myAvatar != null && world.myAvatar.objData != null) {
								currentGold = _parseInt(world.myAvatar.objData.intGold);
							}
							if (currentGold < targetGold) {
								manager.currentIndex += 2;
								return;
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_iflevel(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							var targetLevel:Int = _parseInt(cmd.args[0]);
							var currentLevel:Int = 1;
							if (world.myAvatar != null && world.myAvatar.objData != null) {
								currentLevel = _parseInt(world.myAvatar.objData.intLevel);
							}
							if (currentLevel < targetLevel) {
								manager.currentIndex += 2;
								return;
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_waitfor(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length > 0) {
							var waitTarget:String = cmd.args[0].toLowerCase();
							var foundDrop:Bool = false;
							
							for (pi in 0...Std.int(AqwApi.drop.pendingDrops.length)) {
								var waitDrop:Dynamic = AqwApi.drop.pendingDrops[pi];
								if (waitDrop.sName.toLowerCase() == waitTarget) {
									foundDrop = true;
									break;
								}
							}
							
							if (foundDrop) {
								manager.currentIndex++;
							} else {
								manager.statusText = "Waiting for drop: " + cmd.args[0];
								manager.waitTimer = now + 500;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						


		}

		public static function cmd_loadshop(cmd:Dynamic, manager:ScriptManager):Void {
			var now:Float = AqwTime.now();
			if (cmd.args.length < 1) {
				manager.currentIndex++;
				return;
			}

			var shopId:Int = _parseInt(cmd.args[0]);

			// Already loaded with this shop ID? Advance immediately!
			if (AqwApi.shop.isShopLoaded && AqwApi.shop.loadedShopId == shopId) {
				cmd.loadTimer = null;
				manager.currentIndex++;
				return;
			}

			// First tick: send the load request
			if (cmd.loadTimer == null) {
				cmd.loadTimer = now;
				manager.statusText = "Loading Shop " + shopId + "...";
				AqwApi.shop.loadShop(shopId);
				return;
			}

			// Subsequent ticks: check if loaded
			if (AqwApi.shop.isShopLoaded && AqwApi.shop.loadedShopId == shopId) {
				cmd.loadTimer = null;
				manager.currentIndex++;
				return;
			}

			// Timeout after 5000ms
			if (now - cmd.loadTimer >= 5000) {
				ApiLogger.warn("Shop", "Shop " + shopId + " load timed out! Continuing...");
				cmd.loadTimer = null;
				manager.currentIndex++;
			}
		}

		public static function cmd_buy(cmd:Dynamic, manager:ScriptManager):Void {
			var now:Float = AqwTime.now();
			if (cmd.args.length < 1) {
				manager.currentIndex++;
				return;
			}

			var itemName:String = cmd.args[0];
			var buyQty:Int = (cmd.args.length >= 2) ? _parseInt(cmd.args[1], 1) : 1;

			// First tick: verify shop is ready, record initial quantity, send buy request
			if (cmd.buyTimer == null) {
				if (!AqwApi.shop.isShopLoaded) {
					// If shop not loaded yet, wait up to 2000ms
					if (cmd.waitShopTimer == null) cmd.waitShopTimer = now;
					if (now - cmd.waitShopTimer < 2000) {
						manager.statusText = "Waiting for shop before buying " + itemName + "...";
						return;
					}
				}

				cmd.buyTimer = now;
				cmd.waitShopTimer = null;
				cmd.initialQty = AqwApi.inventory.getQuantity(itemName);
				manager.statusText = "Buying " + itemName + " (x" + buyQty + ")...";
				AqwApi.shop.buyItem(itemName, buyQty);
				return;
			}

			// Subsequent ticks: check if item arrived in inventory
			var currentQty:Int = AqwApi.inventory.getQuantity(itemName);
			if (currentQty > cmd.initialQty) {
				cmd.buyTimer = null;
				cmd.waitShopTimer = null;
				cmd.initialQty = null;
				manager.currentIndex++;
				return;
			}

			// Timeout after 4000ms
			if (now - cmd.buyTimer >= 4000) {
				ApiLogger.warn("Shop", "Buy '" + itemName + "' timed out or already owned! Continuing...");
				cmd.buyTimer = null;
				cmd.waitShopTimer = null;
				cmd.initialQty = null;
				manager.currentIndex++;
			}
		}

		public static function cmd_sell(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
							AqwApi.shop.sellItem(cmd.args.join(" "));
							manager.waitTimer = now + 2000;
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_jump(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 2 && world != null && world.moveToCell != null) {
							world.moveToCell(cmd.args[0], cmd.args[1]);
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_mapdump(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						// Print all monsters on the map with name, MMID, and cell to chat
						if (world != null && world.monsters != null && com.aqwapi.AqwApi.game.chatF != null) {
// 							 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "[MAPDUMP] map=" + world.strMapName + " cell=" + world.strFrame, "API", "", 0);
							for (dumpMon in (cast world.monsters : Array<Dynamic>)) {
								if (dumpMon == null) continue;
								var dumpName:String = "?";
								var dumpMMID:String = "?";
								var dumpCell:String = "?";
								if (dumpMon.objData != null && dumpMon.objData.strMonName != null) dumpName = Std.string(dumpMon.objData.strMonName);
								if (dumpMon.dataLeaf != null && dumpMon.dataLeaf.MonMapID != null) dumpMMID = Std.string(dumpMon.dataLeaf.MonMapID);
								else if (dumpMon.objData != null && dumpMon.objData.MonMapID != null) dumpMMID = Std.string(dumpMon.objData.MonMapID);
																if (dumpMon.strFrame != null) dumpCell = Std.string(dumpMon.strFrame);
// 								 com.aqwapi.AqwApi.game.chatF.pushMsg ("server", "  MON name=" + dumpName + " mmid=" + dumpMMID + " cell=" + dumpCell, "API", "", 0);
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_jumptommid(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1 && world != null && world.monsters != null) {
							var targetMMID:String = cmd.args[0];
							var foundFrame:String = null;
							for (hm in (cast world.monsters : Array<Dynamic>)) {
								if (hm != null) {
									var tmpMMID:String = null;
									if (hm.dataLeaf != null && hm.dataLeaf.MonMapID != null) {
										tmpMMID = Std.string(hm.dataLeaf.MonMapID);
									} else if (hm.objData != null && hm.objData.MonMapID != null) {
										tmpMMID = Std.string(hm.objData.MonMapID);
									}
									if (tmpMMID == targetMMID) {
										if (hm.pMC != null && hm.pMC.strFrame != null) {
											foundFrame = hm.pMC.strFrame;
										} else if (hm.strFrame != null) {
											foundFrame = hm.strFrame;
										} else if (hm.objData != null && hm.objData.strFrame != null) {
											foundFrame = hm.objData.strFrame;
										}
										break;
									}
								}
							}
							if (foundFrame != null && world != null && world.moveToCell != null) {
								world.moveToCell(foundFrame, "Enter");
							} else {
								manager.statusText = "MMID " + targetMMID + " not found!";
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_jumptomob(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						// Jump to the cell of a named monster: JUMPTOMOB Chaos Sp-Eye
						if (cmd.args.length >= 1) {
							var mobTarget:EntityDTO = AqwApi.monster.findByName(cmd.args[0], true);
							if (mobTarget == null) mobTarget = AqwApi.monster.findByName(cmd.args[0], false);
							
							if (mobTarget != null && mobTarget.cell != null) {
								AqwApi.map.jump(mobTarget.cell, "Enter");
							} else {
								manager.statusText = "Mob '" + cmd.args[0] + "' not found on map!";
							}
						}
						manager.currentIndex++;
						return;

		}

		public static function cmd_loadbank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.requested == null) {
							cmd.requested = true;
							if (world != null) {
								if (world.loadBank != null) {
									world.loadBank();
								} else if (world.sfc != null) {
									com.aqwapi.AqwApi.game.sfc.sendString("%xt%zm%loadBank%" + world.curRoom + "%All%");
								}
							}
							manager.waitTimer = now + 1000;
						} else {
							if (world != null && ((world.bankinfo != null && world.bankinfo.items != null) || world.bankTree != null)) {
								manager.currentIndex++;
							} else {
								manager.statusText = "Waiting for bank to load...";
								manager.waitTimer = now + 1000;
							}
						}
						return;
						
		}

		public static function cmd_manual_unbank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
														var actionIsBank:Bool = (cmd.action == "MANUAL_BANK");
							var targetItemName:String = cmd.args[0].toLowerCase();
							
							var hasInInv:Bool = false;
							if (world.invTree != null) {
								for (m_ik in Reflect.fields(world.invTree)) {
									var m_iObj:Dynamic = Reflect.field(world.invTree, m_ik);
									if (m_iObj != null && m_iObj.sName != null && m_iObj.sName.toLowerCase() == targetItemName) {
										hasInInv = true;
										break;
									}
								}
							}
							
							var isSatisfied:Bool = actionIsBank ? !hasInInv : hasInInv;
							
							if (isSatisfied) {
									manager.currentIndex++;
								} else {
								if (cmd.requested == null) {
									cmd.requested = true;
									if (world != null && world.toggleBank != null) {
										world.toggleBank();
									}
									if (com.aqwapi.AqwApi.game != null) {
										}
								}
								manager.statusText = "MANUAL ACTION: Please " + (actionIsBank ? "BANK" : "UNBANK") + " " + cmd.args[0];
								manager.waitTimer = now + 1000;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}

		public static function cmd_manual_bank(cmd:Dynamic, manager:ScriptManager):Void {
			var world:Dynamic = com.aqwapi.AqwApi.game.world;
			var now:Float = AqwTime.now();
			var qid:Int;
						if (cmd.args.length >= 1) {
														var actionIsBank:Bool = (cmd.action == "MANUAL_BANK");
							var targetItemName:String = cmd.args[0].toLowerCase();
							
							var hasInInv:Bool = false;
							if (world.invTree != null) {
								for (m_ik in Reflect.fields(world.invTree)) {
									var m_iObj:Dynamic = Reflect.field(world.invTree, m_ik);
									if (m_iObj != null && m_iObj.sName != null && m_iObj.sName.toLowerCase() == targetItemName) {
										hasInInv = true;
										break;
									}
								}
							}
							
							var isSatisfied:Bool = actionIsBank ? !hasInInv : hasInInv;
							
							if (isSatisfied) {
									manager.currentIndex++;
								} else {
								if (cmd.requested == null) {
									cmd.requested = true;
									if (world != null && world.toggleBank != null) {
										world.toggleBank();
									}
									if (com.aqwapi.AqwApi.game != null) {
										}
								}
								manager.statusText = "MANUAL ACTION: Please " + (actionIsBank ? "BANK" : "UNBANK") + " " + cmd.args[0];
								manager.waitTimer = now + 1000;
							}
						} else {
							manager.currentIndex++;
						}
						return;
						
		}


	}
