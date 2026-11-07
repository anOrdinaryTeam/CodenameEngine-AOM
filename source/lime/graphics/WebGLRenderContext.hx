package lime.graphics;

#if (lime_shadow && lime && !macro)
/**
	Compatibility alias for code written against Codename Engine's lime.

	Shadow's lime has no `WebGLRenderContext`; its WebGL-style context (the
	`ArrayBufferView` overloads of `bufferData`, `texImage2D`, `uniform*v`, ...)
	is openfl's `OpenFLRenderContext`, which is also what `Context3D.gl` holds.
	foxlite types its shader `gl` field as `lime.graphics.WebGLRenderContext`.
**/
typedef WebGLRenderContext = openfl.display3D.OpenFLRenderContext;
#end
