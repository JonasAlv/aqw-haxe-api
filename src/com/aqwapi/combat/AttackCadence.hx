package com.aqwapi.combat;

import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;

/**
 * Learns a monster's attack cadence from the server's own action-resolution packets and
 * exposes a prediction of when the next swing is due.
 *
 * Backed by an exponentially weighted moving average of the inter-arrival time, which is
 * what makes it survive a boss gaining haste or enrage mid-fight: each new sample drags the
 * estimate toward the new period instead of averaging over the whole fight like a fixed
 * window would.
 *
 *     mu    = a*x + (1 - a)*mu_prev
 *     sigma = a*(x - mu_prev)^2 + (1 - a)*sigma_prev
 *
 * NOTE on the variance term: it must be measured against the PREVIOUS mean, not the
 * just-updated one. The updated mean has already been pulled toward `x`, so measuring
 * against it systematically under-reports variance (by roughly (1-a)^2, i.e. ~0.49x at
 * a = 0.3) and would defeat the stability gate entirely.
 *
 * Prediction is only published once it is trustworthy: a minimum number of samples must have
 * been observed, and the coefficient of variation (sigma / mu) must sit under a threshold.
 * A boss that abruptly changes speed - a haste buff, an enrage, a phase transition - blows
 * the variance out, which makes `timeUntilNext` return null ("unknown") so callers fall back
 * to ordinary priority execution instead of committing a dodge weave to a stale rhythm.
 *
 * State is per-target: `reset()` must be called whenever the player switches targets.
 */
class AttackCadence {
    /** Decay factor for both the mean and the variance. */
    public static var alpha:Float = 0.3;

    /** Samples required before a prediction is published at all. */
    public static var minSamples:Int = 3;

    /**
     * Maximum tolerated coefficient of variation (sigma / mu) for a prediction to be
     * considered stable. Relative rather than an absolute sigma^2 threshold so the same
     * gate works for a 0.8s trash mob and a 12s boss phase.
     */
    public static var maxCoefficientOfVariation:Float = 0.25;

    /** Inter-arrival samples outside this range are discarded as non-representative
     *  (target switch, phase transition, long intermission). */
    public static var minDelta:Float = 100;
    public static var maxDelta:Float = 60000;

    private static var _mean:Float = 0;
    private static var _variance:Float = 0;
    private static var _samples:Int = 0;
    private static var _lastAttackAt:Float = 0;
    private static var _discarded:Int = 0;

    /**
     * Feeds one observed monster swing.
     *
     * @param attackAt monotonic timestamp of the resolution, from ApiTime.now()
     */
    public static function record(attackAt:Float):Void {
        if (attackAt <= 0) return;

        if (_lastAttackAt > 0) {
            var x:Float = attackAt - _lastAttackAt;
            if (x < minDelta || x > maxDelta) {
                // Phase transition, target swap or a long lull. Counting it would poison the
                // average for the rest of the fight, so drop it but keep the timeline going.
                _discarded++;
                _lastAttackAt = attackAt;
                return;
            }

            if (_samples == 0) {
                // Seed from the first real observation rather than letting a = 0.3 drag the
                // estimate up from zero, which would badly under-predict the first window.
                _mean = x;
                _variance = 0;
                _samples = 1;
            } else {
                var prevMean:Float = _mean;
                _mean = alpha * x + (1 - alpha) * prevMean;
                var delta:Float = x - prevMean;
                _variance = alpha * delta * delta + (1 - alpha) * _variance;
                _samples++;
            }
        }
        _lastAttackAt = attackAt;
    }

    /**
     * Milliseconds until the next swing is predicted, or null when unknown/unstable.
     *
     * A NEGATIVE result means the swing is overdue, which still satisfies a
     * `mobAtkIn:<ms>` rule - being late is a good reason to be ready, not a reason to stand
     * down.
     */
    public static function timeUntilNext(now:Float):Null<Float> {
        if (_samples < minSamples) return null;
        if (!isStable()) return null;
        if (_lastAttackAt <= 0) return null;
        var sinceLast:Float = now - _lastAttackAt;
        return _mean - sinceLast;
    }

    /** True when enough samples exist and the spread is tight enough to trust. */
    public static function isStable():Bool {
        if (_samples < minSamples) return false;
        if (_mean <= 0) return false;
        var sigma:Float = Math.sqrt(_variance);
        return (sigma / _mean) <= maxCoefficientOfVariation;
    }

    /** Mean inter-arrival time in ms, or 0 when not yet measurable. */
    public static function meanInterval():Float {
        return (_samples > 0) ? _mean : 0;
    }

    /** Standard deviation of the inter-arrival time in ms. */
    public static function deviation():Float {
        return (_samples > 0) ? Math.sqrt(_variance) : 0;
    }

    public static function sampleCount():Int {
        return _samples;
    }

    /** Human-readable state for diagnostics and the UI. */
    public static function describe():String {
        if (_samples == 0) return "no samples";
        if (!isStable()) {
            return "unstable (" + _samples + " samples, mean " + Std.string(Math.round(_mean))
                + "ms, cv " + Std.string(Math.round(cv() * 100)) + "%)";
        }
        return "stable (" + _samples + " samples, mean " + Std.string(Math.round(_mean))
            + "ms +/- " + Std.string(Math.round(deviation())) + ")";
    }

    private static function cv():Float {
        return (_mean > 0) ? Math.sqrt(_variance) / _mean : 1;
    }

    public static function reset():Void {
        _mean = 0;
        _variance = 0;
        _samples = 0;
        _lastAttackAt = 0;
        _discarded = 0;
        _unstableWarned = false;
    }

    /** One-shot warning the first time the gate suppresses a prediction, so a user staring
     *  at a skill that never fires can tell why. */
    public static function warnUnstableOnce():Void {
        if (_unstableWarned) return;
        if (_samples < minSamples) return;
        if (isStable()) return;
        _unstableWarned = true;
        ApiLogger.warn("Combat", "Attack cadence unstable (" + _samples + " samples, mean "
            + Std.string(Math.round(_mean)) + "ms, cv " + Std.string(Math.round(cv() * 100))
            + "% > " + Std.string(Math.round(maxCoefficientOfVariation * 100))
            + "%). Predictor disabled until it settles.");
    }

    private static var _unstableWarned:Bool = false;
}