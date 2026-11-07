package funkin.backend.assets;

import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.AssetLibrary;
import lime.utils.Bytes;

using StringTools;

/**
 * A mod packed inside the app (like `mods/AOM-Revival` in the APK or iOS bundle),
 * the mods counterpart of `PackedAssetLibrary`. It wraps the embedded library and
 * maps `assets/<file>` to `<basePath>/<file>`, so a bundled mod loads like a mods
 * folder without being copied out of the app.
 */
class PackedModFolderLibrary extends AssetLibrary implements IModsAssetLibrary {
	public var basePath:String;
	public var modName:String;
	public var libName:String;
	public var prefix = 'assets/';

	var source:AssetLibrary;
	var fileIndex:Map<String, Array<String>>;
	var folderIndex:Map<String, Array<String>>;

	/**
	 * @param source The embedded library holding the packed files.
	 * @param basePath Folder of the mod in the package, like `mods/AOM-Revival` (a leading `./` is dropped).
	 */
	public function new(source:AssetLibrary, basePath:String, libName:String, ?modName:String) {
		this.source = source;
		this.basePath = normalize(basePath);
		this.libName = libName;
		this.modName = modName == null ? libName : modName;
		super();
	}

	function toString():String {
		return '(PackedModFolderLibrary: $modName)';
	}

	/**
	 * Whether `source` packs files under `folder` (like `./mods/AOM-Revival`).
	 */
	public static function isPacked(source:AssetLibrary, folder:String):Bool {
		if (source == null) return false;
		final start = normalize(folder) + "/";
		for (id in source.list(null)) if (id.startsWith(start)) return true;
		return false;
	}

	/**
	 * `path` as a packed asset id: no leading `./`, no trailing `/`.
	 */
	public static function normalize(path:String):String {
		if (path == null) return "";
		while (path.startsWith("./")) path = path.substr(2);
		while (path.endsWith("/")) path = path.substr(0, path.length - 1);
		return path;
	}

	#if MOD_SUPPORT
	public var _parsedAsset:String = null;

	public override function exists(id:String, type:String):Bool {
		if (!__parseAsset(id)) return false;
		return source.exists(getAssetPath(), type);
	}

	public override function getPath(id:String):String {
		if (!__parseAsset(id)) return null;
		return source.getPath(getAssetPath());
	}

	public override function getAudioBuffer(id:String):AudioBuffer {
		if (!__parseAsset(id)) return null;
		return source.getAudioBuffer(getAssetPath());
	}

	public override function getAudioBufferStream(id:String):AudioBuffer {
		if (!__parseAsset(id)) return null;
		return source.getAudioBufferStream(getAssetPath());
	}

	public override function getBytes(id:String):Bytes {
		if (!__parseAsset(id)) return null;
		return source.getBytes(getAssetPath());
	}

	public override function getFont(id:String):Font {
		if (!__parseAsset(id)) return null;
		final font = source.getFont(getAssetPath());
		return font != null ? ModsFolder.registerFont(font) : null;
	}

	public override function getImage(id:String):Image {
		if (!__parseAsset(id)) return null;
		return source.getImage(getAssetPath());
	}

	public override function getText(id:String):String {
		if (!__parseAsset(id)) return null;
		return source.getText(getAssetPath());
	}

	public override function list(type:String):Array<String> {
		final start = basePath + "/";
		return [for (id in source.list(type)) if (id.startsWith(start)) prefix + id.substr(start.length)];
	}

	public function getFiles(folder:String):Array<String>
		return __getFiles(folder, false);

	public function getFolders(folder:String):Array<String>
		return __getFiles(folder, true);

	function __getFiles(folder:String, folders:Bool):Array<String> {
		if (fileIndex == null) buildIndex();
		if (!folder.endsWith("/")) folder += "/";
		var index = folders ? folderIndex : fileIndex;
		var entries = index.get(folder);
		return entries != null ? entries.copy() : [];
	}

	function buildIndex() {
		fileIndex = [];
		folderIndex = [];
		// indexed by the ids this library serves (assets/...)
		for (id in list(null)) {
			var start = 0;
			var slash = id.indexOf("/");
			while (slash != -1) {
				var parent = id.substr(0, start);
				var name = id.substring(start, slash);
				var entries = folderIndex.get(parent);
				if (entries == null) folderIndex.set(parent, entries = []);
				if (!entries.contains(name)) entries.push(name);
				start = slash + 1;
				slash = id.indexOf("/", start);
			}
			var parent = id.substr(0, start);
			var entries = fileIndex.get(parent);
			if (entries == null) fileIndex.set(parent, entries = []);
			entries.push(id.substr(start));
		}
	}

	private function getAssetPath():String
		return '$basePath/$_parsedAsset';

	private function __isCacheValid(cache:Map<String, Dynamic>, asset:String, isLocal:Bool = false):Bool {
		if (!isLocal) asset = '$libName:$asset';
		return cache.exists(asset) && cache[asset] != null;
	}

	private function __parseAsset(asset:String):Bool {
		if (!asset.startsWith(prefix)) return false;
		_parsedAsset = asset.substr(prefix.length);
		if (ModsFolder.useLibFile) {
			var file = new haxe.io.Path(_parsedAsset);
			if (file.file.startsWith("LIB_")) {
				var library = file.file.substr(4);
				if (library != modName) return false;

				_parsedAsset = file.dir + "." + file.ext;
			}
		}
		return true;
	}
	#end
}
