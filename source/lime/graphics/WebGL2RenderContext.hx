package lime.graphics;

#if (lime_shadow && lime && !macro)
/**
	Compatibility alias for code written against Codename Engine's lime.

	Shadow's lime has no `WebGL2RenderContext`; its WebGL-style context (the
	`ArrayBufferView` overloads of `bufferData`, `texImage2D`, `uniform*v`, ...)
	is openfl's `OpenFLRenderContext`, which is also what `Context3D.gl` holds.
	Kept alongside `WebGLRenderContext` for scripts that name the WebGL 2 type.
**/
typedef WebGL2RenderContext = openfl.display3D.OpenFLRenderContext;
#end
