import com.aqwapi.data.ActionResult;
import com.aqwapi.utils.SkillDslParser;

/** Small runtime-independent checks for parser diagnostics and action result semantics. */
class RegressionChecks {
    static function assertTrue(value:Bool, message:String):Void {
        if (!value) throw message;
    }

    static function main():Void {
        var valid = SkillDslParser.parseSequence("1 > 2[hp < 50% & !aura(self:Buff)] > aa");
        assertTrue(valid.length == 3, "valid rotation should preserve all skills");
        assertTrue(SkillDslParser.lastErrors.length == 0, "valid rotation should have no diagnostics");

        SkillDslParser.parseSequence("1 > 7 > 3");
        assertTrue(SkillDslParser.lastErrors.length > 0, "invalid skill slot should be reported");
        assertTrue(SkillDslParser.lastErrors[0].indexOf("combo token 2") >= 0,
            "invalid skill diagnostic should identify token position");

        SkillDslParser.parse("[Mage : Base]\ncombo = 1 > 2\nwat = 3");
        assertTrue(SkillDslParser.lastErrors.length == 1, "unknown DSL setting should be reported");
        assertTrue(SkillDslParser.lastErrors[0].indexOf("line 3") >= 0,
            "DSL diagnostic should identify source line");

        var ok = new ActionResult("move", "success", "confirmed", 125);
        var timeout = new ActionResult("move", "timeout", "timed out", 8000);
        assertTrue(ok.success && !timeout.success, "action result success must follow status");
        Sys.println("API regression checks passed.");
    }
}
