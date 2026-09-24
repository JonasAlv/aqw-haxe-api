package com.aqwapi.modules;

#if macro
import sys.io.File;
import sys.FileSystem;
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class DefaultSkillsData {
    #if macro
    private static function readAsset(fileName:String):String {
        var paths = [
            "../aqw-mobile-mod/loader/assets/" + fileName,
            "../aqw-mobile/loader/assets/" + fileName,
            "loader/assets/" + fileName,
            "assets/" + fileName
        ];
        for (p in paths) {
            if (FileSystem.exists(p)) {
                return File.getContent(p);
            }
        }
        return "";
    }
    #end

    public static macro function getDefaultSkills():ExprOf<String> {
        var content = readAsset("skills.txt");
        return Context.makeExpr(content, Context.currentPos());
    }

    public static macro function getDefaultUserSkills():ExprOf<String> {
        var content = readAsset("userSkills.txt");
        return Context.makeExpr(content, Context.currentPos());
    }
}

