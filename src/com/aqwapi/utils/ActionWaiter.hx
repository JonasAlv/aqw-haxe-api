package com.aqwapi.utils;

import flash.events.TimerEvent;
import flash.utils.Timer;
import com.aqwapi.data.ActionResult;

/** Shared polling helper for backward-compatible, result-bearing action methods. */
class ActionWaiter {
    public static function run(operation:String, action:Void->Void, confirmed:Void->Bool,
        callback:ActionResult->Void, timeoutMs:Int = 10000, pollMs:Int = 100):Void {
        var started = ApiTime.now();
        var timer:Timer = null;
        var done = false;
        var poll:TimerEvent->Void = null;
        var finish = function(status:String, message:String):Void {
            if (done) return;
            done = true;
            if (timer != null) { timer.stop(); timer.removeEventListener(TimerEvent.TIMER, poll); timer = null; }
            if (callback != null) callback(new ActionResult(operation, status, message, ApiTime.now() - started));
        };
        poll = function(_:TimerEvent):Void {
            try {
                if (confirmed()) finish("success", "Confirmed by live client state.");
                else if (ApiTime.now() - started >= timeoutMs) finish("timeout", "Timed out waiting for client confirmation.");
            } catch (e:Dynamic) {
                finish("failed", Std.string(e));
            }
        };
        try { action(); } catch (e:Dynamic) { finish("failed", Std.string(e)); return; }
        poll(null);
        if (!done) {
            timer = new Timer(Std.int(Math.max(25, pollMs)));
            timer.addEventListener(TimerEvent.TIMER, poll, false, 0, true);
            timer.start();
        }
    }
}
