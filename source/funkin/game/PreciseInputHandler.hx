package funkin.game;

import flixel.input.actions.FlxActionInput.FlxInputDevice;
import flixel.input.keyboard.FlxKey;
import funkin.backend.system.Conductor;
import funkin.backend.system.Controls;
import funkin.backend.utils.ControlsUtil;
import haxe.Int64;
import lime.app.Application;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;

typedef PreciseInputEvent = {
	/** Strum direction the key maps to. **/
	var dir:Int;
	/** true for press, false for release. **/
	var press:Bool;
	/** Song position captured the moment the key event fired. **/
	var songPos:Float;
}

/**
 * Event-driven keyboard input for a strumline (inspired by VSCam).
 *
 * Key events are captured straight from the lime window instead of being
 * polled once per frame, and each press is stamped with the song position
 * at the moment it fired, so judging is not quantized to frame boundaries,
 * press order is preserved, and no press can be merged or dropped.
 *
 * Gamepad input is unaffected and keeps going through the polled path.
 */
class PreciseInputHandler {
	/** Pending events, oldest first. Consumed by `StrumLine.updateInput`. **/
	public var queue:Array<PreciseInputEvent> = [];
	public var enabled:Bool = true;

	var binds:Array<Array<FlxKey>> = [];
	var held:Array<Bool> = [];

	public function new(controls:Controls, keyCount:Int) {
		rebind(controls, keyCount);
		Application.current.window.onKeyDownPrecise.add(onKeyDown);
		Application.current.window.onKeyUpPrecise.add(onKeyUp);
	}

	/** Refreshes the key binds from the given controls (call after rebinding keys). **/
	public function rebind(controls:Controls, keyCount:Int) {
		binds = [];
		held = [];
		for (i in 0...keyCount) {
			var name = keyCount != 4 ? '${keyCount}k$i' : (switch(i) {
				case 0: "note-left";
				case 1: "note-down";
				case 2: "note-up";
				default: "note-right";
			});
			var keys:Array<FlxKey> = [];
			var action = ControlsUtil.getControl(controls, name);
			if (action != null) for (input in action.inputs)
				if (input.device == FlxInputDevice.KEYBOARD && !keys.contains(input.inputID))
					keys.push(input.inputID);
			binds.push(keys);
			held.push(false);
		}
	}

	inline static function convertKey(code:KeyCode):Int {
		@:privateAccess
		return openfl.ui.Keyboard.__convertKeyCode(code);
	}

	function getDir(code:KeyCode):Int {
		var key:FlxKey = convertKey(code);
		for (i => keys in binds)
			if (keys.contains(key)) return i;
		return -1;
	}

	inline function inputBlocked():Bool
		return !enabled || (FlxG.state != null && FlxG.state.subState != null && !FlxG.state.persistentUpdate);

	// SDL3 key event timestamp in nanoseconds (same clock as System.getTimer,
	// which is SDL_GetTicksNS in ms), converted to ms. 0 when the native side
	// has no timestamp support, which Conductor treats as "now".
	inline static function eventStamp(timestamp:Int64):Float {
		var low:Float = timestamp.low;
		if (low < 0) low += 4294967296.0;
		return (timestamp.high * 4294967296.0 + low) / 1e6;
	}

	function onKeyDown(code:KeyCode, _:KeyModifier, timestamp:Int64) {
		if (inputBlocked()) return;
		var dir = getDir(code);
		if (dir == -1 || held[dir]) return; // held guard also filters OS key repeat
		held[dir] = true;
		queue.push({dir: dir, press: true, songPos: Conductor.getEventSongPosition(eventStamp(timestamp))});
	}

	function onKeyUp(code:KeyCode, _:KeyModifier, timestamp:Int64) {
		var dir = getDir(code);
		if (dir == -1) return;
		held[dir] = false;
		if (!inputBlocked())
			queue.push({dir: dir, press: false, songPos: Conductor.getEventSongPosition(eventStamp(timestamp))});
	}

	/** Returns the queued events (oldest first) and clears the queue. **/
	public function flush():Array<PreciseInputEvent> {
		var q = queue;
		queue = [];
		return q;
	}

	public function dispose() {
		Application.current.window.onKeyDownPrecise.remove(onKeyDown);
		Application.current.window.onKeyUpPrecise.remove(onKeyUp);
		queue = [];
		enabled = false;
	}
}
