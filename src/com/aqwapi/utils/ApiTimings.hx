package com.aqwapi.utils;

/**
 * Single source of truth for every timing value in the API.
 *
 * Why this exists: AQW enforces server-side cooldowns on quest actions, buys, sells, map joins and
 * item pickups. Those values were previously spread across five files as a mix of named constants and
 * bare literals, and a bare `2000` in `MapManager` looked identical to a deliberate 2000. When a timer
 * was too short (server dropping actions) or too long (script feeling sluggish), there was no single
 * place to look and no way to be sure every copy agreed.
 *
 * Two categories, and the difference matters:
 *
 *   SERVER-LIMITED - do not lower these. The floor is AQW's own cooldown plus a lag margin. Lowering
 *                    one causes the server to silently discard the action, which looks like a logic
 *                    bug rather than a rate problem.
 *   TUNABLE       - our own pacing choices, safe to adjust.
 *
 * `describe()` renders the whole table for logging, so a value can be confirmed at runtime without
 * reading code.
 */
class ApiTimings {

    /** Extra client-side margin used after an AE cooldown to absorb normal player latency. */
    public static inline var NETWORK_LAG_MARGIN_MS:Float = 100;

    // -------------------------------------------------------------------------
    // SERVER-LIMITED - floors imposed by AQW. Lowering these causes silent drops.
    // -------------------------------------------------------------------------

    /** AE acceptQuest lock: 1000ms + the normal 100ms player-latency margin. */
    public static inline var QUEST_ACTION_MS:Float = 1000 + NETWORK_LAG_MARGIN_MS;

    /** AE tryQuestComplete lock: 1250ms + the normal 100ms player-latency margin. */
    public static inline var QUEST_COMPLETE_ACTION_MS:Float = 1250 + NETWORK_LAG_MARGIN_MS;

    /** Generic result-action deadline used by join/quest/action helpers. */
    public static inline var ACTION_RESULT_TIMEOUT_MS:Float = 10000;

    /** Generic result-action polling interval. */
    public static inline var ACTION_RESULT_POLL_MS:Float = 100;

    /** Maximum wait before a quest action is treated as unacknowledged. */
    public static inline var QUEST_ACK_TIMEOUT_MS:Float = ACTION_RESULT_TIMEOUT_MS;

    /** Poll interval while waiting for quest state to confirm an action. */
    public static inline var QUEST_ACK_POLL_MS:Float = ACTION_RESULT_POLL_MS;

    /** Bank / unbank pacing. AE has no client lock for these packets; keep the conservative 1000ms floor plus margin. */
    public static inline var BANK_ACTION_MS:Float = 1000 + NETWORK_LAG_MARGIN_MS;

    /** AE loadShop lock: 3000ms + latency margin. */
    public static inline var SHOP_LOAD_MS:Float = 3000 + NETWORK_LAG_MARGIN_MS;

    /** AE buyItem lock: 1000ms + latency margin. */
    public static inline var SHOP_BUY_MS:Float = 1000 + NETWORK_LAG_MARGIN_MS;

    /** AE sellItem lock: 1000ms + latency margin. */
    public static inline var SHOP_SELL_MS:Float = 1000 + NETWORK_LAG_MARGIN_MS;

    /** AQW map-transfer lock: 5000ms + latency margin. */
    public static inline var MAP_JOIN_MS:Float = 5000 + NETWORK_LAG_MARGIN_MS;

    /** AE getMapItem lock: 1000ms + latency margin. */
    public static inline var MAP_ITEM_MS:Float = 1000 + NETWORK_LAG_MARGIN_MS;

    /** AE movement retry timer: 500ms + latency margin. */
    public static inline var CELL_JUMP_MS:Float = 500 + NETWORK_LAG_MARGIN_MS;

    /** Native World.GCD fallback used when the live world does not expose GCD. */
    public static inline var NATIVE_GCD_MS:Float = 1500;

    /** Native combat cooldown used before a map transfer after combat ends. */
    public static inline var COMBAT_EXIT_SETTLE_MS:Float = 2000;

    /** Smallest delay used when the combat/map settle time is nearly elapsed. */
    public static inline var COMBAT_EXIT_MIN_DELAY_MS:Float = 200;

    /** Debounce for loading the same quest definition repeatedly. */
    public static inline var QUEST_LOAD_DEDUPE_MS:Float = 1500;

    /** Default timeout for public quest result helpers. */
    public static inline var QUEST_RESULT_TIMEOUT_MS:Float = 15000;

    /** Minimum delay for a queued action timer to avoid a zero-delay spin. */
    public static inline var QUEUE_MIN_DELAY_MS:Float = 20;

    /** Lower bound for generic polling timers. */
    public static inline var MIN_POLL_INTERVAL_MS:Float = 25;

    /** Zero-delay scheduler hop used to wake combat without running recursively. */
    public static inline var IMMEDIATE_WAKE_MS:Float = 0;

    /** Timestamp sentinel for components that have not emitted their first event yet. */
    public static inline var UNSET_TIMESTAMP_MS:Float = -10000;

    /** Minimum caller-requested shop queue gap before it is clamped to the native floor. */
    public static inline var SHOP_QUEUE_MIN_OVERRIDE_MS:Float = 250;

    // -------------------------------------------------------------------------
    // TUNABLE - our own pacing, safe to adjust.
    // -------------------------------------------------------------------------

    /**
     * Combat watchdog. Combat is also woken by packet/state changes and cooldown deadlines;
     * this timer is only a safety net for missed events and time-based rules.
     */
    public static inline var COMBAT_WATCHDOG_MS:Float = 100;
    /** Compatibility alias for older callers. */
    public static inline var COMBAT_TICK_MS:Float = COMBAT_WATCHDOG_MS;

    /** HScript scheduler watchdog. Script callbacks are event-driven; this is only a safety net. */
    public static inline var SCRIPT_TICK_MS:Float = 100;

    /** Maximum number of queued script callbacks processed in one scheduler turn. */
    public static inline var SCRIPT_MAX_CALLBACKS_PER_TICK:Int = 16;

    /** Maximum number of deferred callbacks retained for the active script run. */
    public static inline var SCRIPT_CALLBACK_QUEUE_CAPACITY:Int = 256;

    /** Callback duration that is considered slow enough to diagnose. */
    public static inline var SCRIPT_CALLBACK_WARN_MS:Float = 50;

    /** Minimum interval between repeated slow-callback diagnostics. */
    public static inline var SCRIPT_CALLBACK_WARN_DEDUPE_MS:Float = 2000;

    /** Floor between two casts, shared by Auto Attack and the skill rotation. */
    public static inline var MIN_CAST_GAP_MS:Float = 200;

    /** Default reaction window for the `[counter]` rule when the rule gives no value. */
    public static inline var COUNTER_WINDOW_MS:Float = 1500;

    /**
     * How long after a cast before a window-less `[counter]` starts listening for attacks.
     *
     * A mob often swings in the same instant we cast the arm skill (a dodge buff, say). Reacting to
     * that instant spends the riposte before the buff has had time to resolve, so the good hit - the
     * one the dodge actually answered - is the one we never reply to. Ignoring attacks that land
     * within this window of our last cast makes the lock wait for the next swing instead.
     *
     * Mid-range of the 200-500ms suggested. A tick is 100ms, so 300ms lines up with the third tick
     * after the cast; below ~200ms it barely filters anything, above ~500ms it starts costing real
     * reaction time on genuinely well-timed hits.
     */
    public static inline var COUNTER_ARM_DELAY_MS:Float = 300;

    /**
     * How long a class-level mismatch is ignored before the engine falls back.
     * Large on purpose: it suppresses repeated fallback churn during a transient state.
     */
    public static inline var TEMP_IGNORE_MS:Float = 4000;

    /** Cache lifetime for the CC/immobilisation check. */
    public static inline var CC_CHECK_CACHE_MS:Float = 50;

    /** Identical log lines inside this window are collapsed. */
    public static inline var LOG_DEDUPE_MS:Float = 2000;

    /** Rate-limit log throttle for combat cooldown messages. */
    public static inline var COMBAT_COOLDOWN_LOG_MS:Float = 2000;

    /** How long a rotation waits on a resource-blocked skill before advancing. */
    public static inline var COMBAT_RESOURCE_WAIT_TIMEOUT_MS:Float = 10000;

    /** Maximum time a custom rotation step may remain blocked before advancing. */
    public static inline var COMBAT_SEQUENCE_STEP_TIMEOUT_MS:Float = 8000;

    /** Throttle for one-off fallback and timeout-skip warnings. */
    public static inline var WARN_THROTTLE_MS:Float = 3000;

    /** Combat aggro refresh interval. */
    public static inline var AGGRO_REFRESH_MS:Float = 1200;

    /** Consumable action debounce used by the public potion helper. */
    public static inline var CONSUMABLE_ACTION_GAP_MS:Float = 1500;

    /** Small reaction delay after a Vigil warning to account for client/server timing. */
    public static inline var VIGIL_GUARD_DELAY_MS:Float = 1000;
    /** Re-press slot 6 while waiting for the server to confirm the Vigil aura. */
    public static inline var VIGIL_GUARD_RETRY_MS:Float = 200;
    /** Maximum time to wait for the Vigil aura after a server warning before failing safe. */
    public static inline var VIGIL_GUARD_TIMEOUT_MS:Float = 5000;

    /** Minimum auto-potion interval when no explicit interval is supplied. */
    public static inline var AUTO_POTION_DEFAULT_INTERVAL_MS:Float = 15000;

    /** Minimum interval accepted for an automatic potion rotation. */
    public static inline var AUTO_POTION_MIN_INTERVAL_MS:Float = 2000;

    /** Extra consumable acknowledgement gap used by the automatic potion guard. */
    public static inline var AUTO_POTION_ACTION_GAP_MS:Float = 2500;

    /** Auto-provoke refresh interval. */
    public static inline var AUTO_PROVOKE_REFRESH_MS:Float = 800;

    /** Aura cleanup timer exposed by the API/UI. */
    public static inline var AURA_CLEAN_INTERVAL_MS:Float = 5000;

    /** Cache lifetime for resolving the currently equipped class. */
    public static inline var CLASS_CACHE_MS:Float = 1000;

    /** Default timeout for a normal skill/DSL step, matching the native GCD. */
    public static inline var SKILL_STEP_TIMEOUT_MS:Float = NATIVE_GCD_MS;

    /** State cache staleness threshold used by StateHealth. */
    public static inline var STATE_STALE_TIMEOUT_MS:Float = 30000;

    /** Drop request de-duplication window. */
    public static inline var DROP_REQUEST_DEDUPE_MS:Float = 1500;

    /** Default aura hand-off grace window. */
    public static inline var AURA_HANDOFF_GRACE_MS:Float = 300;

    /** Minimum taunt cooldown for Scroll of Enrage/native taunt action. */
    public static inline var TAUNT_COOLDOWN_MS:Float = 5500;

    /** Default timed taunt interval for presets. */
    public static inline var TAUNT_DEFAULT_INTERVAL_MS:Float = 6000;

    /** Faster timed taunt interval used by the Speaker preset. */
    public static inline var TAUNT_SPEAKER_INTERVAL_MS:Float = 5800;

    // -------------------------------------------------------------------------
    // Polling and settle delays - how often we re-check, not how fast we may act.
    // -------------------------------------------------------------------------

    /** How often the enhancement UI state is polled. */
    public static inline var ENHANCE_POLL_MS:Float = 150;

    /** Minimum gap between enhancement packets sent to the AQW server. */
    /** Forge enhancement uses AE's buyItem lock: 1000ms + latency margin. */
    public static inline var ENHANCEMENT_ACTION_GAP_MS:Float = SHOP_BUY_MS;

    /** Maximum time to wait for AE to apply an enhancement to the live inventory item. */
    public static inline var ENHANCEMENT_ACK_TIMEOUT_MS:Float = 6000;

    /** AQW's enforced five-second map lock plus the shared 100ms latency margin. */
    public static inline var ENHANCEMENT_MAP_JOIN_COOLDOWN_MS:Float = MAP_JOIN_MS;

    /** Retry interval while waiting for the enhancement workflow's map-transfer cooldown. */
    public static inline var ENHANCEMENT_MAP_COOLDOWN_RETRY_MS:Float = 400;

    /** Initial wait after sending an enhancement workflow map-join request. */
    public static inline var ENHANCEMENT_MAP_JOIN_SETTLE_MS:Float = 1500;

    /** Poll interval while waiting for the enhancement workflow map to finish loading. */
    public static inline var ENHANCEMENT_MAP_LOAD_POLL_MS:Float = 300;

    /** Maximum elapsed time allowed for an enhancement workflow map to finish loading. */
    public static inline var ENHANCEMENT_MAP_LOAD_TIMEOUT_MS:Float = 15000;

    /** Delay between shop-load requests while the enhancement workflow waits for shop data. */
    public static inline var ENHANCEMENT_SHOP_REQUEST_RETRY_MS:Float = SHOP_LOAD_MS;

    /** Maximum elapsed time allowed for an enhancement shop to load. */
    public static inline var ENHANCEMENT_SHOP_LOAD_TIMEOUT_MS:Float = 6000;

    /** Delay before continuing after an enhancement task is skipped for shop failure. */
    public static inline var ENHANCEMENT_SHOP_SKIP_DELAY_MS:Float = 600;

    /** Bank/quest data settle wait after a bulk transfer, before reading the result. */
    public static inline var SETTLE_MS:Float = 600;

    /** Pause used after a native map/combat transition before scripts retry state reads. */
    public static inline var MAP_ACTION_PAUSE_MS:Float = 600;

    /** Script pause after a map transfer request while AE settles combat/map state. */
    public static inline var MAP_TRANSFER_SCRIPT_PAUSE_MS:Float = 2000;

    /** Small delay used when restoring the player's coordinates after a corrective jump. */
    public static inline var MAP_COORDINATE_RESTORE_MS:Float = 50;

    /** Jump-result wait deadline. */
    public static inline var MAP_JUMP_TIMEOUT_MS:Float = 8000;

    /** Poll interval for jump-result confirmation. */
    public static inline var MAP_JUMP_POLL_MS:Float = 100;

    /** Join-with-result deadline and polling interval. */
    public static inline var MAP_JOIN_RESULT_TIMEOUT_MS:Float = 30000;
    public static inline var MAP_JOIN_RESULT_POLL_MS:Float = 150;

    /** Zone callbacks wait for AE's map loader/avatar state to become usable. */
    public static inline var ZONE_READY_POLL_MS:Float = 150;
    public static inline var ZONE_READY_TIMEOUT_MS:Float = 15000;

    /** Native moveToCell retry pause plus latency margin. */
    public static inline var CELL_JUMP_PAUSE_MS:Float = 600;

    /** Local collision-correction polling interval and attempt count. */
    public static inline var MAP_CORRECTION_POLL_MS:Float = 50;
    public static inline var MAP_CORRECTION_ATTEMPTS:Int = 40;

    /** Inventory restore settle delay. */
    public static inline var INVENTORY_RESTORE_SETTLE_MS:Float = 350;

    /** Maximum wait for a bank payload after requesting it. */
    public static inline var BANK_LOAD_TIMEOUT_MS:Float = 8000;

    /** Maximum wait while joining the private house before banking. */
    public static inline var HOUSE_JOIN_TIMEOUT_MS:Float = 15000;

    /** Auto-boost refresh interval. */
    public static inline var BOOST_REFRESH_MS:Float = 15000;

    /** Action-feed diagnostic summary interval. */
    public static inline var ACTION_FEED_SUMMARY_MS:Float = 15000;

    /** House item poll interval. */
    public static inline var HOUSE_POLL_MS:Float = 500;

    /** Bank load poll interval while waiting for the bank payload. */
    public static inline var BANK_LOAD_POLL_MS:Float = 300;

    /** Quest refresh timer interval. */
    public static inline var QUEST_REFRESH_MS:Float = 800;

    /**
     * Throttle on the bulk quest-data load request.
     *
     * Deliberately 1000, not QUEST_ACTION_MS (1100). This gates loading quest *data*, a different
     * request from accepting or completing a quest, and it was 1000 before these values were
     * centralised. Kept at 1000 so the refactor changes no behaviour - if it should match the action
     * cooldown, that is a decision to make deliberately here, not a side effect of tidying up.
     */
    public static inline var QUEST_DATA_LOAD_MS:Float = 1000;

    /** Equip-swap timeout: how long to wait for the avatar to finish swapping before giving up. */
    public static inline var EQUIP_TIMEOUT_MS:Float = 2500;

    /** Poll interval used to confirm that the requested item reached equipped state. */
    public static inline var EQUIP_ACK_POLL_MS:Float = 100;

    // -------------------------------------------------------------------------
    // Introspection
    // -------------------------------------------------------------------------

    /**
     * Every value in one object. The scripting `rateLimit()` binding returns exactly this, so scripts
     * read the same numbers the engine enforces instead of a second copy that can drift.
     */
    public static function all():Dynamic {
        return {
            questAction: QUEST_ACTION_MS,
            questCompleteAction: QUEST_COMPLETE_ACTION_MS,
            networkLagMargin: NETWORK_LAG_MARGIN_MS,
            actionResultTimeout: ACTION_RESULT_TIMEOUT_MS,
            actionResultPoll: ACTION_RESULT_POLL_MS,
            questAckTimeout: QUEST_ACK_TIMEOUT_MS,
            questAckPoll: QUEST_ACK_POLL_MS,
            bankAction: BANK_ACTION_MS,
            shopLoad: SHOP_LOAD_MS,
            buy: SHOP_BUY_MS,
            sell: SHOP_SELL_MS,
            mapJoin: MAP_JOIN_MS,
            mapItem: MAP_ITEM_MS,
            cellJump: CELL_JUMP_MS,
            nativeGcd: NATIVE_GCD_MS,
            combatExitSettle: COMBAT_EXIT_SETTLE_MS,
            combatExitMinDelay: COMBAT_EXIT_MIN_DELAY_MS,
            questLoadDedupe: QUEST_LOAD_DEDUPE_MS,
            questResultTimeout: QUEST_RESULT_TIMEOUT_MS,
            queueMinDelay: QUEUE_MIN_DELAY_MS,
            minPollInterval: MIN_POLL_INTERVAL_MS,
            immediateWake: IMMEDIATE_WAKE_MS,
            unsetTimestamp: UNSET_TIMESTAMP_MS,
            shopQueueMinOverride: SHOP_QUEUE_MIN_OVERRIDE_MS,

            combatWatchdog: COMBAT_WATCHDOG_MS,
            combatTick: COMBAT_TICK_MS,
            scriptTick: SCRIPT_TICK_MS,
            scriptMaxCallbacksPerTick: SCRIPT_MAX_CALLBACKS_PER_TICK,
            scriptCallbackQueueCapacity: SCRIPT_CALLBACK_QUEUE_CAPACITY,
            scriptCallbackWarn: SCRIPT_CALLBACK_WARN_MS,
            scriptCallbackWarnDedupe: SCRIPT_CALLBACK_WARN_DEDUPE_MS,
            minCastGap: MIN_CAST_GAP_MS,
            counterWindow: COUNTER_WINDOW_MS,
            counterArmDelay: COUNTER_ARM_DELAY_MS,
            tempIgnore: TEMP_IGNORE_MS,
            ccCheckCache: CC_CHECK_CACHE_MS,
            logDedupe: LOG_DEDUPE_MS,
            combatCooldownLog: COMBAT_COOLDOWN_LOG_MS,
            warnThrottle: WARN_THROTTLE_MS,
            combatResourceWaitTimeout: COMBAT_RESOURCE_WAIT_TIMEOUT_MS,
            combatSequenceStepTimeout: COMBAT_SEQUENCE_STEP_TIMEOUT_MS,
            aggroRefresh: AGGRO_REFRESH_MS,
            consumableActionGap: CONSUMABLE_ACTION_GAP_MS,
            autoPotionDefaultInterval: AUTO_POTION_DEFAULT_INTERVAL_MS,
            autoPotionMinInterval: AUTO_POTION_MIN_INTERVAL_MS,
            autoPotionActionGap: AUTO_POTION_ACTION_GAP_MS,
            autoProvokeRefresh: AUTO_PROVOKE_REFRESH_MS,
            auraCleanInterval: AURA_CLEAN_INTERVAL_MS,
            classCache: CLASS_CACHE_MS,
            skillStepTimeout: SKILL_STEP_TIMEOUT_MS,
            stateStaleTimeout: STATE_STALE_TIMEOUT_MS,
            dropRequestDedupe: DROP_REQUEST_DEDUPE_MS,
            auraHandoffGrace: AURA_HANDOFF_GRACE_MS,
            tauntCooldown: TAUNT_COOLDOWN_MS,
            tauntDefaultInterval: TAUNT_DEFAULT_INTERVAL_MS,
            tauntSpeakerInterval: TAUNT_SPEAKER_INTERVAL_MS,

            enhancePoll: ENHANCE_POLL_MS,
            enhancementActionGap: ENHANCEMENT_ACTION_GAP_MS,
            enhancementAckTimeout: ENHANCEMENT_ACK_TIMEOUT_MS,
            enhancementMapJoinCooldown: ENHANCEMENT_MAP_JOIN_COOLDOWN_MS,
            enhancementMapCooldownRetry: ENHANCEMENT_MAP_COOLDOWN_RETRY_MS,
            enhancementMapJoinSettle: ENHANCEMENT_MAP_JOIN_SETTLE_MS,
            enhancementMapLoadPoll: ENHANCEMENT_MAP_LOAD_POLL_MS,
            enhancementMapLoadTimeout: ENHANCEMENT_MAP_LOAD_TIMEOUT_MS,
            enhancementShopRequestRetry: ENHANCEMENT_SHOP_REQUEST_RETRY_MS,
            enhancementShopLoadTimeout: ENHANCEMENT_SHOP_LOAD_TIMEOUT_MS,
            enhancementShopSkipDelay: ENHANCEMENT_SHOP_SKIP_DELAY_MS,
            settle: SETTLE_MS,
            mapActionPause: MAP_ACTION_PAUSE_MS,
            mapTransferScriptPause: MAP_TRANSFER_SCRIPT_PAUSE_MS,
            mapCoordinateRestore: MAP_COORDINATE_RESTORE_MS,
            mapJumpTimeout: MAP_JUMP_TIMEOUT_MS,
            mapJumpPoll: MAP_JUMP_POLL_MS,
            mapJoinResultTimeout: MAP_JOIN_RESULT_TIMEOUT_MS,
            mapJoinResultPoll: MAP_JOIN_RESULT_POLL_MS,
            zoneReadyPoll: ZONE_READY_POLL_MS,
            zoneReadyTimeout: ZONE_READY_TIMEOUT_MS,
            cellJumpPause: CELL_JUMP_PAUSE_MS,
            mapCorrectionPoll: MAP_CORRECTION_POLL_MS,
            mapCorrectionAttempts: MAP_CORRECTION_ATTEMPTS,
            inventoryRestoreSettle: INVENTORY_RESTORE_SETTLE_MS,
            bankLoadTimeout: BANK_LOAD_TIMEOUT_MS,
            houseJoinTimeout: HOUSE_JOIN_TIMEOUT_MS,
            boostRefresh: BOOST_REFRESH_MS,
            actionFeedSummary: ACTION_FEED_SUMMARY_MS,
            housePoll: HOUSE_POLL_MS,
            bankLoadPoll: BANK_LOAD_POLL_MS,
            questRefresh: QUEST_REFRESH_MS,
            equipTimeout: EQUIP_TIMEOUT_MS,
            equipAckPoll: EQUIP_ACK_POLL_MS,
            questDataLoad: QUEST_DATA_LOAD_MS
        };
    }

    /** One-line-per-value dump, for logging the effective configuration. */
    public static function describe():String {
        var a:Dynamic = all();
        var parts:Array<String> = [];
        for (k in Reflect.fields(a)) parts.push(k + "=" + Std.string(Reflect.field(a, k)));
        return "ApiTimings: " + parts.join(", ");
    }
}
