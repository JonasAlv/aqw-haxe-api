package com.aqwapi.modules;

#if macro
import sys.io.File;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class DefaultSkillsData {
    public static macro function getDefaultSkills():ExprOf<String> {
        var content = File.getContent("../aqw-mobile-mod/loader/assets/skills.txt");
        return Context.makeExpr(content, Context.currentPos());
    }

    public static macro function getDefaultUserSkills():ExprOf<String> {
        var content = File.getContent("../aqw-mobile-mod/loader/assets/userSkills.txt");
        return Context.makeExpr(content, Context.currentPos());
    }
}
