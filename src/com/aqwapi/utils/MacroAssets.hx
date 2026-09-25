package com.aqwapi.utils;

#if macro
import haxe.macro.Expr;
import sys.io.File;
import sys.FileSystem;

class MacroAssets {
    public static function loadAsset(relPath:String):Expr {
        var candidates = [
            relPath,
            "../aqw-mobile-mod/loader/assets/" + relPath,
            "loader/assets/" + relPath,
            "/home/me/Music/haxe-workspace/aqw-mobile-mod/loader/assets/" + relPath
        ];
        for (c in candidates) {
            if (FileSystem.exists(c)) {
                var content = File.getContent(c);
                return macro $v{content};
            }
        }
        return macro $v{""};
    }
}
#end
