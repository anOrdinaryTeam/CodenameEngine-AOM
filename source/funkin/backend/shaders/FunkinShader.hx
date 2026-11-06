package funkin.backend.shaders;

import haxe.Exception;

import hscript.IHScriptCustomBehaviour;

import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameter;

import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.tile.FlxGraphicsShader;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxSignal.FlxTypedSignal;

/**
 * Codename Engine shader, built on ShadowEngineTeam's shader stack.
 *
 * `FlxRuntimeShader` (Shadow) handles `#pragma header` / `#pragma body` and the GLSL 3 / GLES 3
 * conversion, and OpenFL picks the GLSL version for the running context.
 * On top of that this class adds what Codename Engine shaders use:
 * loading from files, `#include` / `#import` (with `#pragma once`), uniform default values
 * (`uniform sampler2D tex = "image";`), code prefixes and HScript property access.
 */
@:access(openfl.display.Shader)
@:access(openfl.display.ShaderInput)
@:access(openfl.display.ShaderParameter)
class FunkinShader extends FlxRuntimeShader implements IHScriptCustomBehaviour {
	public var onGLUpdate:FlxTypedSignal<Void->Void> = new FlxTypedSignal<Void->Void>();

	// These not triggering shader resets is intended, or it'll cause lag spikes
	// It's recommended to use Flags
	public var shaderPrefix:String = Flags.FUNKIN_SHADER_CODE_PREFIX;
	public var fragmentPrefix:String = Flags.FUNKIN_SHADER_CODE_FRAGMENT_PREFIX;
	public var vertexPrefix:String = Flags.FUNKIN_SHADER_CODE_VERTEX_PREFIX;

	/**
	 * GLSL version asked for by the shader (from `#version` or the constructor).
	 * OpenFL compiles for the version of the running context, so this is informative.
	 */
	public var glslVer:String;

	@:noCompletion public var _fragmentFilePath:Null<String>;
	@:noCompletion public var _vertexFilePath:Null<String>;

	var __rawFragmentSource:Null<String>;
	var __rawVertexSource:Null<String>;
	var __uniformDefaults:Map<String, String> = [];

	public function new(?fragmentSource:String, ?vertexSource:String, ?version:String) {
		glslVer = version ?? Flags.DEFAULT_GLSL_VERSION;
		__rawFragmentSource = fragmentSource;
		__rawVertexSource = vertexSource;
		super(fragmentSource != null ? __prepareSource(fragmentSource, false) : null, vertexSource != null ? __prepareSource(vertexSource, true) : null);
	}

	public static function fromFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShader {
		return new FunkinShader().loadShaderFile(fragmentPath, vertexPath, version);
	}

	/**
	 * Resolves a shader file path, adding `.frag` / `.vert` if needed. Returns `null` if it doesn't exist.
	 */
	public static function _getPath(path:Null<String>, isVertex:Bool):Null<String> {
		if (path == null) return null;
		if (Assets.exists(path)) return path;

		final ext = isVertex ? ".vert" : ".frag";
		if (!path.endsWith(ext) && Assets.exists(path + ext)) return path + ext;

		return null;
	}

	public function loadShaderFile(fragmentPath:String, ?vertexPath:String, ?version:String):FunkinShader {
		if (vertexPath == null) {
			final idx = fragmentPath.lastIndexOf(".");
			if (idx == -1) vertexPath = fragmentPath;
			else vertexPath = fragmentPath.substr(0, idx);
		}

		var frag = _getPath(fragmentPath, false), vert = _getPath(vertexPath, true);
		if (frag == null) frag = _getPath(Paths.fragShader(fragmentPath), false);
		if (vert == null) vert = _getPath(Paths.vertShader(vertexPath), true);
		_fromFile(frag, vert, version);

		return this;
	}

	function _fromFile(fragmentPath:Null<String>, vertexPath:Null<String>, version:Null<String>):Void {
		if (version != null) glslVer = version;

		_fragmentFilePath = fragmentPath;
		_vertexFilePath = vertexPath;

		__rawFragmentSource = fragmentPath != null ? Assets.getText(fragmentPath) : null;
		__rawVertexSource = vertexPath != null ? Assets.getText(vertexPath) : null;

		__applySources();
	}

	function __applySources():Void {
		__uniformDefaults.clear();
		glFragmentSource = __processFragmentSource(__rawFragmentSource != null ? __prepareSource(__rawFragmentSource, false) : glFragmentSourceRaw);
		glVertexSource = __processVertexSource(__rawVertexSource != null ? __prepareSource(__rawVertexSource, true) : glVertexSourceRaw);
		__glSourceDirty = true;
	}

	#if REGION /* Source preparation */
	static final __versionFinder:EReg = ~/^[ \t]*#version[ \t]+([^\r\n]+)\r?$/m;
	static final __includeFinder:EReg = ~/^[ \t]*#(?:include|import)[ \t]*(?:"([^"]+)"|'([^']+)'|<([^>]+)>)[^\r\n]*$/m;
	static final __pragmaOnceFinder:EReg = ~/^[ \t]*#pragma[ \t]+once[ \t]*\r?$/m;
	static final __uniformDefaultFinder:EReg = ~/\buniform[ \t]+((?:lowp[ \t]+|mediump[ \t]+|highp[ \t]+)?[A-Za-z0-9_]+)[ \t]+([A-Za-z0-9_]+)[ \t]*=[ \t]*([^;]+);/;

	function __prepareSource(source:String, isVertex:Bool):String {
		if (source == null) return null;

		if (__versionFinder.match(source)) {
			glslVer = StringTools.trim(__versionFinder.matched(1));
			source = __versionFinder.replace(source, "");
		}

		source = __resolveIncludes(source, isVertex, [], 0);

		// uniform defaults are not valid GLSL, keep the value and strip it
		while (__uniformDefaultFinder.match(source)) {
			__uniformDefaults.set(__uniformDefaultFinder.matched(2), StringTools.trim(__uniformDefaultFinder.matched(3)));
			source = __uniformDefaultFinder.matchedLeft() + 'uniform ${__uniformDefaultFinder.matched(1)} ${__uniformDefaultFinder.matched(2)};' + __uniformDefaultFinder.matchedRight();
		}

		final prefix = (shaderPrefix ?? "") + "\n" + ((isVertex ? vertexPrefix : fragmentPrefix) ?? "");
		return StringTools.trim(prefix).length > 0 ? prefix + "\n" + source : source;
	}

	function __resolveIncludes(source:String, isVertex:Bool, included:Array<String>, depth:Int):String {
		if (depth > 32) return source;

		var result = new StringBuf();
		var rest = source;
		while (__includeFinder.match(rest)) {
			result.add(__includeFinder.matchedLeft());
			final name = __includeFinder.matched(1) ?? __includeFinder.matched(2) ?? __includeFinder.matched(3);
			rest = __includeFinder.matchedRight();

			var include = __getIncludeSource(name, isVertex);
			if (include == null) {
				result.add('/*Unknown include $name*/');
				continue;
			}

			if (__pragmaOnceFinder.match(include)) {
				if (included.contains(name)) {
					result.add('/*#include $name (once)*/');
					continue;
				}
				include = __pragmaOnceFinder.replace(include, "");
			}
			included.push(name);

			result.add('/*#include $name*/\n');
			result.add(__resolveIncludes(include, isVertex, included, depth + 1));
		}
		result.add(rest);
		return result.toString();
	}

	function __getIncludeSource(include:String, fromVertex:Bool):Null<String> {
		final path = Paths.getPath('shaders/' + include);
		if (Assets.exists(path)) return Assets.getText(path);
		if (Assets.exists(include)) return Assets.getText(include);

		Logs.traceColored([
			Logs.logText('[Shader] ', RED),
			Logs.logText('Failed to import shader $include', RED),
		]);
		return null;
	}

	static final __numberFinder:EReg = ~/-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?/;

	function __applyUniformDefaults():Void {
		if (__data == null) return;

		for (name => assign in __uniformDefaults) {
			final field:Dynamic = Reflect.field(__data, name);
			if (field == null) continue;

			switch (__paramTypeOf(Type.getClass(field))) {
				case 1:
					if (field.value != null) continue;
					if (field.__isBool) {
						field.value = [for (v in assign.split(",")) StringTools.trim(v).indexOf("true") != -1];
					}
					else {
						var values:Array<Dynamic> = [], s = assign;
						while (__numberFinder.match(s)) {
							final n = __numberFinder.matched(0);
							values.push(field.__isInt ? Std.parseInt(n) : Std.parseFloat(n));
							s = __numberFinder.matchedRight();
						}
						if (values.length > 0) field.value = values;
					}
				case 2:
					if (field.input != null) continue;
					final bitmap = __getSamplerDefault(assign);
					if (bitmap != null) field.input = bitmap;
				default:
			}
		}
	}

	function __getSamplerDefault(assign:String):Null<BitmapData> {
		var p = assign.charAt(0);
		if ((p == "'" || p == '"') && assign.charAt(assign.length - 1) == p) assign = assign.substring(1, assign.length - 1);

		final path = Paths.image(assign);
		if (FlxG.assets.exists(path)) {
			final graphic = FlxG.bitmap.add(path);
			if (graphic != null) return graphic.bitmap;
		}
		return null;
	}
	#end

	#if REGION /* Shader hooks */
	override function __init():Void {
		super.__init();
		__applyUniformDefaults();
	}

	override function __updateGL():Void {
		onGLUpdate.dispatch();
		super.__updateGL();
	}

	override function __processGLData(source:String, storageType:String):Void {
		if (onProcessGLData != null) onProcessGLData.dispatch(source, storageType);
		if (__cancelNextProcessGLData) {
			__cancelNextProcessGLData = false;
			return;
		}
		super.__processGLData(source, storageType);
	}
	#end

	#if REGION /* IHScriptCustomBehaviour */
	// 0 = other, 1 = ShaderParameter, 2 = ShaderInput
	#if cpp
	static final __paramTypeCache:haxe.ds.ObjectMap<Dynamic, Int> = new haxe.ds.ObjectMap();
	#else
	static final __paramTypeCache:Map<String, Int> = [];
	#end

	static function __paramTypeOf(?cls:Class<Dynamic>):Int {
		if (cls == null) return 0;

		#if !cpp
		final name = Type.getClassName(cls);
		#end

		var paramType = __paramTypeCache.get(#if cpp cls #else name #end);
		if (paramType == null) {
			#if cpp
			final name = Type.getClassName(cls);
			#end
			__paramTypeCache.set(#if cpp cls #else name #end,
				paramType = name.startsWith("openfl.display.ShaderParameter") ? 1 : (name.startsWith("openfl.display.ShaderInput") ? 2 : 0));
		}

		return paramType;
	}

	static final __classFieldCache:Map<String, Map<String, Bool>> = [];

	function __thisHasField(name:String):Bool {
		final cls = Type.getClass(this);
		final key = Type.getClassName(cls);
		var fields = __classFieldCache.get(key);
		if (fields == null) __classFieldCache.set(key, fields = [for (f in Type.getInstanceFields(cls)) f => true]);
		return fields.exists(name);
	}

	inline function __instanceHasField(name:String):Bool
		return __thisHasField(name);

	public function hget(name:String):Dynamic {
		if (__thisHasField(name) || __instanceHasField('get_$name')) return Reflect.getProperty(this, name);

		final field:Dynamic = Reflect.field(data, name);
		if (field == null) return null;

		switch (__paramTypeOf(Type.getClass(field)))
		{
			case 1: return (field.__length > 1) ? field.value : (field.value != null ? field.value[0] : null);
			case 2: return field.input;
			default: return field;
		}
	}

	public function hset(name:String, val:Dynamic):Dynamic {
		final setFuncName = 'set_$name';
		if (__instanceHasField(setFuncName)) {
			return Reflect.callMethod(this, Reflect.field(this, setFuncName), [val]);
		}
		else if (__thisHasField(name)) {
			Reflect.setProperty(this, name, val);
			return val;
		}

		final shaderData = data;
		final field:Dynamic = Reflect.field(shaderData, name);
		if (field == null) {
			Reflect.setField(shaderData, name, val);
			return val;
		}

		final isNotNull = val != null;

		switch (__paramTypeOf(Type.getClass(field))) {
			case 1:
				if (field.__length > 1) {
					if (isNotNull && !(val is Array)) {
						throw new ShaderTypeException(name, Type.getClass(val), Array);
						return null;
					}
					return field.value = val;
				}
				else {
					// that means we wait for a single number, instead of an array
					if (field.__isInt && isNotNull && !(val is Int)) {
						throw new ShaderTypeException(name, Type.getClass(val), 'Int');
						return null;
					} else
					if (field.__isBool && isNotNull && !(val is Bool)) {
						throw new ShaderTypeException(name, Type.getClass(val), 'Bool');
						return null;
					} else
					if (field.__isFloat && isNotNull && !(val is Float)) {
						throw new ShaderTypeException(name, Type.getClass(val), 'Float');
						return null;
					}
					return field.value = isNotNull ? [val] : null;
				}

			case 2:
				// shader input!!
				var bitmap:BitmapData;
				if (!isNotNull) bitmap = null;
				else if (val is BitmapData) bitmap = val;
				else if (val is FlxGraphic) bitmap = val.bitmap;
				else {
					throw new ShaderTypeException(name, Type.getClass(val), BitmapData);
					return null;
				}
				field.input = bitmap;
				return val;

			default:
				Reflect.setField(shaderData, name, val);
				return val;
		}
	}
	#end

	override function toString():String {
		final name = _fragmentFilePath ?? _vertexFilePath;
		return name != null ? 'FunkinShader($name)' : 'FunkinShader';
	}

	#if REGION /* Backward Compatibility */
	private static var FRAGMENT_SHADER = 0;
	private static var VERTEX_SHADER = 1;

	public var fileName(get, set):String;
	inline function get_fileName():String return _fragmentFilePath ?? _vertexFilePath ?? "FunkinShader";
	inline function set_fileName(v:String):String return _fragmentFilePath = _vertexFilePath = v;

	public var fragFileName(get, set):String;
	inline function get_fragFileName():String return _fragmentFilePath ?? "FunkinShader";
	inline function set_fragFileName(v:String):String return _fragmentFilePath = v;

	public var vertFileName(get, set):String;
	inline function get_vertFileName():String return _vertexFilePath ?? "FunkinShader";
	inline function set_vertFileName(v:String):String return _vertexFilePath = v;

	public var glRawFragmentSource(get, set):String;
	inline function get_glRawFragmentSource():String return __rawFragmentSource;
	function set_glRawFragmentSource(v:String):String {
		__rawFragmentSource = v;
		__applySources();
		return v;
	}

	public var glRawVertexSource(get, set):String;
	inline function get_glRawVertexSource():String return __rawVertexSource;
	function set_glRawVertexSource(v:String):String {
		__rawVertexSource = v;
		__applySources();
		return v;
	}

	function thisHasField(v:String):Bool return __thisHasField(v);

	function registerParameter(name:String, type:String, isUniform:Bool) {
		if (data == null) return;
		final storage = isUniform ? "uniform" : "attribute";
		__processGLData('$storage $type $name;', storage);
	}

	var __cancelNextProcessGLData:Bool = false;
	public var onProcessGLData:FlxTypedSignal<(String, String)->Void> = new FlxTypedSignal<(String, String)->Void>();
	#end
}

class ShaderTypeException extends Exception {
	var has:Class<Dynamic>;
	var want:Class<Dynamic>;
	var name:String;

	public function new(name:String, has:Class<Dynamic>, want:Dynamic) {
		this.has = has;
		this.want = want;
		this.name = name;
		super('ShaderTypeException - Tried to set the shader uniform "${name}" as a ${Type.getClassName(has)}, but the shader uniform is a ${Std.string(want)}.');
	}
}

#if REGION /* Backward Compatibility */
class ShaderTemplates {
	static var __template:FlxGraphicsShader;

	static function __getTemplate():FlxGraphicsShader {
		if (__template == null) __template = new FlxGraphicsShader();
		return __template;
	}

	public static var vertHeader(get, never):String;
	static function get_vertHeader():String return __getTemplate().glVertexHeaderRaw;

	public static var vertBody(get, never):String;
	static function get_vertBody():String return __getTemplate().glVertexBodyRaw;

	public static var fragHeader(get, never):String;
	static function get_fragHeader():String return __getTemplate().glFragmentHeaderRaw;

	public static var fragBody(get, never):String;
	static function get_fragBody():String return __getTemplate().glFragmentBodyRaw;

	public static final vertBackCompatVarList:Array<EReg> = [
		~/attribute float alpha/,
		~/attribute vec4 colorMultiplier/,
		~/attribute vec4 colorOffset/,
		~/uniform bool hasColorTransform/
	];

	public static final vertHeaderBackCompat:String = "attribute float openfl_Alpha;
attribute vec4 openfl_ColorMultiplier;
attribute vec4 openfl_ColorOffset;
attribute vec4 openfl_Position;
attribute vec2 openfl_TextureCoord;

varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;

uniform mat4 openfl_Matrix;
uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;";

	public static final vertBodyBackCompat:String = "openfl_Alphav = openfl_Alpha;
openfl_TextureCoordv = openfl_TextureCoord;

if(openfl_HasColorTransform) {
	openfl_ColorMultiplierv = openfl_ColorMultiplier;
	openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
}

gl_Position = openfl_Matrix * openfl_Position;";
}
#end
