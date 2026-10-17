package com.aqwapi.modules;

import com.aqwapi.managers.SkillManager;

/**
 * Facade delegating all user-skill storage and configuration calls to SkillManager.
 */
class UserSkillsManager {
    public static inline function ensureStorageInitialized():Void SkillManager.ensureStorageInitialized();
    public static inline function readUserSkillsObject():Dynamic return SkillManager.readUserSkillsObject();
    public static inline function sanitizeUserSkillsObject(data:Dynamic):Dynamic return SkillManager.sanitizeUserSkillsObject(data);
    public static inline function deleteFieldSafe(o:Dynamic, field:String):Bool return SkillManager.deleteFieldSafe(o, field);
    public static inline function readUserSkills():String return SkillManager.readUserSkills();
    public static inline function writeUserSkillsObject(data:Dynamic):Bool return SkillManager.writeUserSkillsObject(data);
    public static inline function writeUserSkills(content:String):Bool return SkillManager.writeUserSkills(content);
    public static inline function resolveClassName(className:String):String return SkillManager.resolveClassName(className);
    public static inline function getAllUserClasses():Array<String> return SkillManager.getAllUserClasses();
    public static inline function isUserMode(className:String, modeName:String):Bool return SkillManager.isUserMode(className, modeName);
    public static inline function getUserModesForClass(className:String):Array<String> return SkillManager.getUserModesForClass(className);
    public static inline function saveMode(className:String, modeName:String, skillUseMode:String, timeout:Int, combo:String, stopOnTargetAuras:String = null, resetComboOnTargetChange:Null<Bool> = null, autoAttack:Null<Bool> = null):Bool {
        return SkillManager.saveMode(className, modeName, skillUseMode, timeout, combo, stopOnTargetAuras, resetComboOnTargetChange, autoAttack);
    }
    public static inline function deleteMode(className:String, modeName:String):Bool return SkillManager.deleteMode(className, modeName);
    public static inline function getModeDetails(className:String, modeName:String):Dynamic return SkillManager.getModeDetails(className, modeName);
}
