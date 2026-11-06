package funkin.backend.system;

import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawTrianglesItem;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.display3D.Context3DBlendTarget;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;

class FakeCamera extends FlxCamera {
	public static var instance:FakeCamera;

	public function new() {
		super();

		visible = false;
	}

	override function startTrianglesBatch(graphic:FlxGraphic, smoothing:Bool = false, isColored:Bool = false, ?blend:BlendMode, ?hasColorOffsets:Bool, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget):FlxDrawTrianglesItem { return null;}
	override function startQuadBatch(graphic:FlxGraphic, colored:Bool, hasColorOffsets:Bool = false, ?blend:BlendMode, smooth:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget) { return null;}
	override function clearDrawStack() {}
	override function render() {}

	public override function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget) {}
	public override function copyPixels(?frame:FlxFrame, ?pixels:BitmapData, ?sourceRect:Rectangle, destPoint:Point, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget) {}
	public override function drawTriangles(graphic:FlxGraphic, vertices:DrawData<Float>, indices:DrawData<Int>, uvtData:DrawData<Float>, ?colors:DrawData<Int>, ?position:FlxPoint, ?blend:BlendMode, repeat:Bool = false, smoothing:Bool = false, ?transform:ColorTransform, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget):Void {}

	public override function update(elapsed:Float) {}

	// override function set_zoom(Zoom:Float):Float return zoom = (Zoom == 0) ? FlxCamera.defaultZoom : Zoom;

	public override function setScale(X:Float, Y:Float):Void {}
}

class FakeCallCamera extends FakeCamera {
	public static var instance:FakeCallCamera;
	public var ignoreDraws:Bool = false;

	public dynamic function onDraw(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget) {
	}

	override function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false, ?shader:FlxShader, ?blendTarget:Context3DBlendTarget) {
		if (!ignoreDraws) onDraw(frame, pixels, matrix, transform, blend, smoothing, shader, blendTarget);
	}
}