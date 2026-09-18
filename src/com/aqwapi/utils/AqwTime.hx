package com.aqwapi.utils;

import flash.Lib;

class AqwTime {
    /**
     * Milliseconds elapsed since the application started.
     * Uses Flash's native getTimer() (zero allocations, monotonic, high precision).
     */
    public static inline function now():Float {
        return Lib.getTimer();
    }

    public static inline function getTimer():Int {
        return Lib.getTimer();
    }
}
