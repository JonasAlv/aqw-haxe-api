package com.aqwapi.utils;

#if macro
import haxe.macro.Expr;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;

class MacroAssets {
    private static function getAssetDirs():Array<String> {
        return ["assets", "../aqw-haxe-api/assets", "aqw-haxe-api/assets"];
    }

    public static function loadAsset(relPath:String):Expr {
        for (dir in getAssetDirs()) {
            var p = Path.join([dir, relPath]);
            if (FileSystem.exists(p) && !FileSystem.isDirectory(p)) {
                return macro $v{File.getContent(p)};
            }
        }
        if (FileSystem.exists(relPath) && !FileSystem.isDirectory(relPath)) {
            return macro $v{File.getContent(relPath)};
        }
        return macro $v{""};
    }

    public static function loadScriptsMap():Expr {
        var pairs:Array<Expr> = [];
        var seen:Map<String, Bool> = new Map();

        for (baseDir in getAssetDirs()) {
            var scriptsDir = Path.join([baseDir, "scripts"]);
            if (!FileSystem.exists(scriptsDir) || !FileSystem.isDirectory(scriptsDir)) continue;

            var scan:String->String->Void = null;
            scan = function(curDir:String, prefix:String):Void {
                var names = FileSystem.readDirectory(curDir);
                names.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
                for (name in names) {
                    var full = Path.join([curDir, name]);
                    if (FileSystem.isDirectory(full)) {
                        scan(full, prefix + name + "/");
                    } else if (StringTools.endsWith(name.toLowerCase(), ".hxs")) {
                        var scriptName = prefix + name.substring(0, name.length - 4);
                        if (!seen.exists(scriptName)) {
                            seen.set(scriptName, true);
                            var content = File.getContent(full);
                            pairs.push(macro $v{scriptName} => $v{content});
                        }
                    }
                }
            };
            scan(scriptsDir, "");
        }

        if (pairs.length == 0) {
            return macro new Map<String, String>();
        }
        return macro ($a{pairs} : Map<String, String>);
    }
}
#end
