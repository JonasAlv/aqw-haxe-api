package com.aqwapi.feedback;

import com.aqwapi.Api;
import com.aqwapi.events.ApiEvent;
import com.aqwapi.utils.ApiLogger;

/**
 * Backend policy for user-facing feedback. No Flash, no rendering - this decides *what* should be
 * shown and *when*, and announces it on `Api.dispatcher`. The UI subscribes and draws.
 *
 * ## Why this lives in the API
 *
 * Notification behaviour used to be split across two repos with no single place to read it: the
 * logger wrote to console/file/chat, and the card renderer in the UI privately owned the rules that
 * decide whether a card appears at all - the visible-card cap, the repeat-folding, which messages
 * merge, and the sticky registry. Those are decisions, not pixels, so they belong beside the rest of
 * the behaviour; only the drawing belongs in the UI.
 *
 * The split is now:
 *   ApiFeedback            policy: what to show, in what order, merging what, stickies, mirror config
 *   ui.ApiNotification*    rendering: sprites, timers, layout
 *
 * ## Event contract
 *
 * `ApiEvent.NOTIFICATION`        transient card  - data: `{ seq, repeat }`
 * `ApiEvent.STICKY_NOTIFICATION` persistent card  - data: `{ id, repeat }`
 * `ApiEvent.REMOVE_STICKY`       drop a sticky   - data: `{ id }`
 *
 * `repeat` is how many times the identical message has now been requested. The renderer folds repeats
 * into an `(xN)` counter instead of stacking duplicate cards, so the policy decides identity and the
 * pixels just draw the number.
 */
class ApiFeedback {

    /** Max auto-dismissing cards on screen at once. Oldest non-sticky is dropped first. */
    public static inline var MAX_VISIBLE:Int = 6;

    /** Repeated identical notifications within this window fold into one card. */
    public static inline var REPEAT_WINDOW_MS:Float = 2000;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    private static var _seq:Int = 0;

    /** Active sticky ids -> their message, so a repeat can fold and a re-send can update in place. */
    private static var _sticky:Map<String, String> = new Map<String, String>();

    /** Message -> { count, lastAt } for repeat folding of transient cards. */
    private static var _recent:Map<String, { count:Int, lastAt:Float }> = new Map<String, { count:Int, lastAt:Float }>();

    /**
     * When true, every logger line is announced as a notification request too.
     *
     * API-side on purpose: the API decides whether to volunteer its log stream to the presentation
     * layer, and the UI decides how to draw it. Off by default - a per-tick log line must not bury the
     * screen in cards.
     */
    public static var mirrorLogs:Bool = false;

    // -------------------------------------------------------------------------
    // Transient notifications
    // -------------------------------------------------------------------------

    /**
     * Requests a transient card and records it in the log.
     *
     * The log line is deliberate: cards are transient, so anything worth showing is also worth being
     * able to find in `api.log` afterwards. Use {@link card} for screen-only.
     */
    public static function notify(message:String):Void {
        ApiLogger.info("Notify", message);
        card(message);
    }

    /** Screen-only request; no log line. For high-frequency or purely visual cues. */
    public static function card(message:String):Void {
        if (message == null || message == "") return;
        _seq++;
        var repeat:Int = bumpRepeat(message);
        dispatch(ApiEvent.NOTIFICATION, message, { seq: _seq, repeat: repeat });
    }

    /** Logs at `level` and requests a card in one call. */
    public static function logToScreen(level:Int, tag:String, message:String):Void {
        // Haxe switch cases do not fall through and reject `break`, so this is an if-chain.
        if (level == ApiLogger.LEVEL_ERROR) ApiLogger.error(tag, message);
        else if (level == ApiLogger.LEVEL_WARN) ApiLogger.warn(tag, message);
        else if (level == ApiLogger.LEVEL_DEBUG) ApiLogger.diag(tag, message);
        else ApiLogger.info(tag, message);
        card(message);
    }

    // -------------------------------------------------------------------------
    // Sticky notifications
    // -------------------------------------------------------------------------

    /**
     * Persistent state, e.g. "paused" or "script running". Re-sending the same id updates in place
     * rather than stacking.
     */
    public static function sticky(id:String, message:String):Void {
        if (id == null || id == "") id = "default_sticky";
        if (message == null) message = "";
        var changed:Bool = !_sticky.exists(id) || _sticky.get(id) != message;
        _sticky.set(id, message);
        if (changed) {
            _seq++;
            dispatch(ApiEvent.STICKY_NOTIFICATION, message, { id: id, repeat: 1 });
        }
    }

    public static function removeSticky(id:String):Void {
        if (id == null || id == "") id = "default_sticky";
        if (!_sticky.exists(id)) return;
        _sticky.remove(id);
        dispatch(ApiEvent.REMOVE_STICKY, "", { id: id });
    }

    public static function hasSticky(id:String):Bool {
        return id != null && _sticky.exists(id);
    }

    public static function stickyMessage(id:String):String {
        return (id != null && _sticky.exists(id)) ? _sticky.get(id) : null;
    }

    public static function stickyIds():Array<String> {
        var out:Array<String> = [];
        for (k in _sticky.keys()) out.push(k);
        return out;
    }

    /** Drops all sticky state and tells the UI to clear them. Called on shutdown / map change. */
    public static function clearSticky():Void {
        for (id in stickyIds()) removeSticky(id);
    }

    // -------------------------------------------------------------------------
    // Logger bridge
    // -------------------------------------------------------------------------

    /**
     * Called from `ApiLogger.write` - the single choke point every emitted line passes through.
     *
     * Gated here rather than in the UI so the API owns the policy, and so the default cost in the
     * logger is one boolean check rather than a listener walk.
     */
    public static function onLogLine(tag:String, level:Int, message:String):Void {
        if (!mirrorLogs) return;
        card("[" + tag + "] " + message);
    }

    // -------------------------------------------------------------------------
    // Introspection
    // -------------------------------------------------------------------------

    /** Everything that governs feedback behaviour, for a debug view or `feedbackConfig()`. */
    public static function config():Dynamic {
        return {
            maxVisible: MAX_VISIBLE,
            repeatWindowMs: REPEAT_WINDOW_MS,
            mirrorLogs: mirrorLogs,
            sticky: stickyIds(),
            stickyCount: stickyIds().length,
            logLevel: ApiLogger.level,
            diagnostics: ApiLogger.diagnostics,
            printToConsole: ApiLogger.printToConsole,
            printToFile: ApiLogger.printToFile,
            printToChat: ApiLogger.printToChat,
            chatMinLevel: ApiLogger.chatMinLevel
        };
    }

    // -------------------------------------------------------------------------
    // Internals
    // -------------------------------------------------------------------------

    /**
     * Fold policy: the same message inside `REPEAT_WINDOW_MS` keeps its identity and returns an
     * incremented count, so the renderer can show `(xN)` instead of a stack of identical cards.
     * Anything older restarts at 1.
     */
    private static function bumpRepeat(message:String):Int {
        var now:Float = com.aqwapi.utils.ApiTime.now();
        var entry = _recent.get(message);
        if (entry != null && (now - entry.lastAt) <= REPEAT_WINDOW_MS) {
            entry.count++;
            entry.lastAt = now;
            return entry.count;
        }
        _recent.set(message, { count: 1, lastAt: now });
        return 1;
    }

    private static function dispatch(type:String, message:String, data:Dynamic):Void {
        try {
            if (Api.dispatcher == null) return;
            Api.dispatcher.dispatchEvent(new ApiEvent(type, message, data));
        } catch (e:Dynamic) {
            // Never let a presentation concern break the caller that requested the notification.
            ApiLogger.warn("Feedback", "Dispatch failed for '" + type + "': " + Std.string(e));
        }
    }
}
