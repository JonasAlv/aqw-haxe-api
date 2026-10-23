package com.aqwapi.scripting;

import com.aqwapi.utils.ApiStorage;

/** Expands small, explicit HScript library includes before hscript parses a program. */
class ScriptPreprocessor {
    private static inline var MAX_INCLUDE_DEPTH:Int = 16;

    public static function expand(source:String, sourceName:String = "<script>"):String {
        if (source == null) return "";
        return expandSource(source, normalize(sourceName), new Map<String, Bool>(), new Map<String, Bool>(), 0);
    }

    private static function expandSource(source:String, sourceName:String, stack:Map<String, Bool>, seen:Map<String, Bool>, depth:Int):String {
        if (depth > MAX_INCLUDE_DEPTH) throw "HScript include depth exceeded (maximum " + MAX_INCLUDE_DEPTH + ")";

        var key = sourceName.toLowerCase();
        if (stack.exists(key)) throw "Circular HScript include: " + sourceName;
        stack.set(key, true);
        seen.set(key, true);

        var output:Array<String> = [];
        for (line in source.split("\n")) {
            var includePath = parseInclude(line);
            if (includePath == null) {
                output.push(line);
                continue;
            }

            var normalized = normalize(includePath);
            var includeKey = normalized.toLowerCase();
            if (stack.exists(includeKey)) throw "Circular HScript include: " + normalized;
            if (seen.exists(includeKey)) continue;
            var included = ApiStorage.readScript(normalized);
            if (included == null || StringTools.trim(included) == "") {
                throw "Included HScript library was not found: " + normalized;
            }

            output.push("// begin include " + normalized);
            output.push(expandSource(included, normalized, stack, seen, depth + 1));
            output.push("// end include " + normalized);
        }

        stack.remove(key);
        return output.join("\n");
    }

    private static function parseInclude(line:String):String {
        var text = StringTools.trim(line);
        var prefix:String = null;
        if (StringTools.startsWith(text, "#include")) prefix = "#include";
        else if (StringTools.startsWith(text, "// @include")) prefix = "// @include";
        if (prefix == null) return null;

        var rest = StringTools.trim(text.substring(prefix.length));
        if (rest == "") return null;
        if ((rest.charAt(0) == "\"" && rest.charAt(rest.length - 1) == "\"")
            || (rest.charAt(0) == "'" && rest.charAt(rest.length - 1) == "'")) {
            rest = rest.substring(1, rest.length - 1);
        }
        return rest;
    }

    private static function normalize(path:String):String {
        var value = StringTools.trim(path == null ? "" : path);
        value = StringTools.replace(value, "\\", "/");
        while (StringTools.startsWith(value, "/")) value = value.substring(1);
        if (StringTools.startsWith(value, "assets/scripts/")) value = value.substring(15);
        if (StringTools.startsWith(value, "scripts/")) value = value.substring(8);
        if (StringTools.endsWith(value.toLowerCase(), ".hxs")) value = value.substring(0, value.length - 4);
        return value + ".hxs";
    }
}
