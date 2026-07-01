package hscript;

class Config {
	// Runs support for custom classes in these
	public static final ALLOWED_CUSTOM_CLASSES = [
		#if !DOCUMENTATION
		"flixel",

		"funkin",
		#if MODCHARTING_FEATURES
		"modchart.engine",
		"modchart.backend.standalone",
		#end
		#end
	];

	// Runs support for abstract support in these
	public static final ALLOWED_ABSTRACT_AND_ENUM = [
		#if !DOCUMENTATION
		"flixel",
		"openfl",

		"haxe.xml",
		"haxe.CallStack",
		"funkin",
		#end
	];

	// Runs support for typedef support in these
	public static final ALLOWED_TYPEDEFS = [
		#if !DOCUMENTATION
		"flixel",
		"flixel.addons",
		"openfl",
		#end
	];

	// Incase any of your files fail
	// These are the module names
	public static final DISALLOW_CUSTOM_CLASSES = [

	];

	public static final DISALLOW_ABSTRACT_AND_ENUM = [
		"funkin.backend.scripting.events.sprite.PlayAnimContext", // Error: expected member name or ';' after declaration specifiers, Due to define macro from math.h
	];

	public static final DISALLOW_TYPEDEFS = [
		"haxe", // by default
	];
}