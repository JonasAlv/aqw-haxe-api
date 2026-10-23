package com.aqwapi.scripting.core;
import com.aqwapi.scripting.content.CoreVHL;
import com.aqwapi.scripting.content.CoreLR;
import com.aqwapi.scripting.content.CoreNSoD;
import com.aqwapi.scripting.content.CoreBLoD;
import com.aqwapi.scripting.content.CoreAwe;
import com.aqwapi.scripting.content.CoreForge;
import com.aqwapi.scripting.content.CoreUltras;

/** Composition root: cores orchestrate managers, they do not replace them. */
class CoreApi {
    public var context:CoreContext; public var wait:CoreWait; public var events:CoreEvents; public var recovery:CoreRecovery; public var travel:CoreTravel; public var target:CoreTarget; public var combat:CoreCombat; public var hunt:CoreHunt; public var drops:CoreDrops; public var inventory:CoreInventory; public var shop:CoreShop; public var merge:CoreMerge; public var loadout:CoreLoadout; public var enhancement:CoreEnhancement; public var quest:CoreQuest; public var story:CoreStory; public var farm:CoreFarm; public var dailies:CoreDailies; public var progression:CoreProgression; public var boost:CoreBoost; public var party:CoreParty; public var boss:CoreBoss;
    public var vhl:CoreVHL; public var lr:CoreLR; public var nsoD:CoreNSoD; public var blod:CoreBLoD; public var awe:CoreAwe; public var forge:CoreForge; public var ultras:CoreUltras;
    public function new() {
        context = new CoreContext(); wait = new CoreWait(); events = new CoreEvents(); recovery = new CoreRecovery(context); travel = new CoreTravel(context); target = new CoreTarget(); combat = new CoreCombat(context, target); hunt = new CoreHunt(combat, travel, recovery); drops = new CoreDrops(); inventory = new CoreInventory(); shop = new CoreShop(); merge = new CoreMerge(travel, shop, inventory); loadout = new CoreLoadout(); enhancement = new CoreEnhancement(); quest = new CoreQuest(); story = new CoreStory(quest, hunt); farm = new CoreFarm(hunt, drops, recovery); dailies = new CoreDailies(quest, farm); progression = new CoreProgression(quest, hunt); boost = new CoreBoost(); party = new CoreParty(); boss = new CoreBoss(combat, target); vhl = new CoreVHL(); lr = new CoreLR(); nsoD = new CoreNSoD(); blod = new CoreBLoD(); awe = new CoreAwe(); forge = new CoreForge(); ultras = new CoreUltras();
    }
}
