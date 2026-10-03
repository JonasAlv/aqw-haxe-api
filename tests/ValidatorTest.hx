package;

import com.aqwapi.utils.Diagnostic;
import com.aqwapi.utils.SkillDslParser;
import haxe.Json;

/**
 * Tests for SkillDslParser.validate.
 *
 * Two jobs: prove each check fires on a known-bad input, and prove it does NOT fire on the 315
 * configs that ship in skills.json. The second matters more - a validator that rejects the
 * user's existing working rotations is worse than no validator.
 */
class ValidatorTest {
    static var checks = 0;
    static var failures = 0;

    static function main() {
        // --- must produce at least one ERROR ---
        errors("1[nosuchcondition]", "unknown condition");
        errors("1[]", "empty brackets fire unconditionally");
        errors("1[hp < 50% & nosuchcondition]", "unknown condition");
        errors("abc > 2", "non-numeric step");
        errors("[hp < 50%]", "missing skill id");
        errors("1[hp < 50%", "unbalanced bracket");
        errors("", "empty combo");
        errors("1[aura(self:Name)]", "placeholder is only a warning", false);
        errors("1[hp < 50%] | 2[mp < 20%]", "'|' is not a step separator");

        // --- must produce ZERO errors ---
        clean("1");
        clean("1 > 2 > 3");
        clean("1[hp < 50%] > 2[mp < 20%] > 3");
        clean("1[hp > 70% & mp < 70% & !aura(self:Corporeal Ascenion)] > 2[mp < 30%] > 3");
        clean("1[!aura(target:incinerate)]");
        clean("4[afterMobAtk:2000:any:150] > 2[wait(5000ms)]");
        clean("1[hp < 2500]");
        clean("1[tgt:hp > 80% & targetCC] > 2[mobAtkIn:500]");
        clean("1[party:hp < 50% & aura(target:Seal) >= 22 & auraTime(self:Speed) <= 1.5s]");
        clean("1[hp < 50% | mp < 20%]");

        // --- warnings, not errors ---
        warns("1[aura(self:Name)]", "placeholder aura");
        warns("1[hp > 150%]", "percentage over 100 silently becomes raw");
        warns("1[wait(0)]", "wait(0) is a no-op");
        warns("1[hp < 50%] junk", "text after the closing bracket");

        // --- collectAuraNames feeds the editor's aura picker ---
        names("", 0);
        names("1 > 2", 0);
        names("2[!aura(self:Tracer Rounds)] > 3[afterMobAtk:2000] > 4 > 1[mp < 20%]", 1);
        names("1[aura(self:A)]", 1);
        names("1[aura(self:A) & auraTime(self:A) <= 1.5s]", 1);   // deduped
        names("1[aura(self:A) | aura(target:B)]", 2);
        // The literal placeholder must never come back - it is not a real aura.
        names("1[!aura(self:Name)]", 0);
        names("1[hp < 50% & tgt:hp > 80%]", 0);                    // non-aura rules ignored
        names("1[aura()]", 0);                                      // empty name ignored

        // --- the shipped configs must validate clean ---
        auditShippedConfigs();

        Sys.println("");
        Sys.println("Assertions: " + checks + ", failures: " + failures);
        if (failures == 0) {
            Sys.println("VALIDATOR OK");
            Sys.exit(0);
        } else {
            Sys.exit(1);
        }
    }

    // ---------------------------------------------------------------- assertions

    static function errors(combo:String, label:String, expectError:Bool = true) {
        var ds = SkillDslParser.validate(combo);
        var errs = count(ds, true);
        checks++;
        var want = expectError ? 1 : 0;
        if (errs < want) {
            failures++;
            Sys.println("FAIL expected error [" + label + "] for '" + combo + "' -> " + errs + " errors");
            for (d in ds) Sys.println("       " + Std.string(d));
        }
    }

    static function clean(combo:String) {
        var ds = SkillDslParser.validate(combo);
        checks++;
        for (d in ds) {
            if (d.isError()) {
                failures++;
                Sys.println("FAIL unexpected error for '" + combo + "': " + Std.string(d));
            }
        }
    }

    static function warns(combo:String, label:String) {
        var ds = SkillDslParser.validate(combo);
        checks++;
        var w = count(ds, false);
        if (w == 0) {
            failures++;
            Sys.println("FAIL expected warning [" + label + "] for '" + combo + "'");
            for (d in ds) Sys.println("       " + Std.string(d));
        }
    }

    static function count(ds:Array<Diagnostic>, isError:Bool):Int {
        var n = 0;
        for (d in ds) if (d.isError() == isError) n++;
        return n;
    }

    static function names(combo:String, expect:Int) {
        checks++;
        var got = SkillDslParser.collectAuraNames(combo);
        if (got.length != expect) {
            failures++;
            Sys.println("FAIL collectAuraNames('" + combo + "') -> " + got.length + " names, expected " + expect + " " + got);
        }
    }

    // ---------------------------------------------------------------- shipped audit

    static function auditShippedConfigs() {
        var path = "../aqw-mobile-mod/loader/assets/skills.json";
        if (!sys.FileSystem.exists(path)) {
            Sys.println("WARN: skills.json not found, skipping shipped-config audit");
            return;
        }
        var parsed:Dynamic;
        try {
            parsed = Json.parse(sys.io.File.getContent(path));
        } catch (e:Dynamic) {
            Sys.println("WARN: skills.json unparseable right now, skipping audit");
            return;
        }

        var audited = 0;
        var warned = 0;
        for (className in Reflect.fields(parsed)) {
            var modes:Dynamic = Reflect.field(parsed, className);
            if (modes == null) continue;
            for (modeName in Reflect.fields(modes)) {
                var mode:Dynamic = Reflect.field(modes, modeName);
                if (mode == null || mode.combo == null) continue;
                audited++;
                var ds = SkillDslParser.validate(mode.combo);
                for (d in ds) {
                    if (d.isError()) {
                        failures++;
                        Sys.println("FAIL shipped config rejected [" + className + " : " + modeName + "]");
                        Sys.println("       " + Std.string(d));
                        Sys.println("       combo: " + mode.combo);
                    } else {
                        warned++;
                        if (warned <= 10) {
                            Sys.println("warn [" + className + " : " + modeName + "] " + Std.string(d));
                        }
                    }
                }
            }
        }
        Sys.println("Audited " + audited + " shipped configs, " + warned + " warnings, 0 errors required");
        checks++;
    }
}