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

    // -------------------------------------------------------------------------
    // SERVER-LIMITED - floors imposed by AQW. Lowering these causes silent drops.
    // -------------------------------------------------------------------------

    /** Quest accept / complete / turn-in. 1000ms server cooldown + 100ms lag margin. */
    public static inline var QUEST_ACTION_MS:Float = 1100;

    /** Bank / unbank item transfers. Same 1000ms server floor plus margin. */
    public static inline var BANK_ACTION_MS:Float = 1100;

    /** Shop load request. */
    public static inline var SHOP_LOAD_MS:Float = 1500;

    /** Single buy or sell request. */
    public static inline var SHOP_BUY_MS:Float = 1000;

    /** Single sell request. */
    public static inline var SHOP_SELL_MS:Float = 1000;

    /** Map join / travel request. AQW server enforces a 5000ms cooldown on map transfers. */
    public static inline var MAP_JOIN_MS:Float = 5000;

    /** Map item pickup request. */
    public static inline var MAP_ITEM_MS:Float = 2000;

    /** Cell-to-cell jump inside a map. */
    public static inline var CELL_JUMP_MS:Float = 500;

    // -------------------------------------------------------------------------
    // TUNABLE - our own pacing, safe to adjust.
    // -------------------------------------------------------------------------

    /** Combat engine tick. Also the resolution of every time-based rule. */
    public static inline var COMBAT_TICK_MS:Float = 100;

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

    /** Throttle for one-off fallback and timeout-skip warnings. */
    public static inline var WARN_THROTTLE_MS:Float = 3000;

    // -------------------------------------------------------------------------
    // Polling and settle delays - how often we re-check, not how fast we may act.
    // -------------------------------------------------------------------------

    /** How often the enhancement UI state is polled. */
    public static inline var ENHANCE_POLL_MS:Float = 150;

    /** Bank/quest data settle wait after a bulk transfer, before reading the result. */
    public static inline var SETTLE_MS:Float = 600;

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
            bankAction: BANK_ACTION_MS,
            shopLoad: SHOP_LOAD_MS,
            buy: SHOP_BUY_MS,
            sell: SHOP_SELL_MS,
            mapJoin: MAP_JOIN_MS,
            mapItem: MAP_ITEM_MS,
            cellJump: CELL_JUMP_MS,

            combatTick: COMBAT_TICK_MS,
            minCastGap: MIN_CAST_GAP_MS,
            counterWindow: COUNTER_WINDOW_MS,
            counterArmDelay: COUNTER_ARM_DELAY_MS,
            tempIgnore: TEMP_IGNORE_MS,
            ccCheckCache: CC_CHECK_CACHE_MS,
            logDedupe: LOG_DEDUPE_MS,
            combatCooldownLog: COMBAT_COOLDOWN_LOG_MS,
            warnThrottle: WARN_THROTTLE_MS,

            enhancePoll: ENHANCE_POLL_MS,
            settle: SETTLE_MS,
            housePoll: HOUSE_POLL_MS,
            bankLoadPoll: BANK_LOAD_POLL_MS,
            questRefresh: QUEST_REFRESH_MS,
            equipTimeout: EQUIP_TIMEOUT_MS,
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