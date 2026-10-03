package com.aqwapi.utils;

/**
 * One problem found in a combo string.
 *
 * `severity` is "error" (the rule cannot work) or "warning" (it parses, but almost certainly
 * does not do what was intended). Only errors block a save.
 */
class Diagnostic {
    public static inline var ERROR:String = "error";
    public static inline var WARNING:String = "warning";

    public var severity:String;
    public var message:String;

    /** Zero-based index of the combo step this came from, or -1 for whole-string problems. */
    public var stepIndex:Int;

    /** The offending fragment of the combo, for highlighting. */
    public var token:String;

    public function new(severity:String, message:String, stepIndex:Int = -1, token:String = "") {
        this.severity = severity;
        this.message = message;
        this.stepIndex = stepIndex;
        this.token = token;
    }

    public function isError():Bool return severity == ERROR;

    public function toString():String {
        var where = (stepIndex >= 0) ? "step " + (stepIndex + 1) : "combo";
        return (isError() ? "ERROR" : "WARN") + " @ " + where + ": " + message
            + (token != "" ? "  [" + token + "]" : "");
    }
}