-- stage-editor.lua
--
-- An annoyingly opinionated stage editor
-- for Friday Night Funkin' Psych Engine.
-- authored by strangejune, copyright MIT License
--
-- How to use:
-- `events.bound` contains the current keyboard bindings.
-- If you're ever confused on what a key does,
-- press and hold the "help" key (default F1) and press a key
-- to get a description of its function.
--
-- Objects are listed in a table, in order, below.
-- You can select different objects with the relevant keys.
-- All operations on an object will be performed on the
-- currently selected object, so keep in mind which object
-- is selected at all times - it is printed at the top
-- of the screen.
--
-- Notes:
-- Characters might not animate in editor mode if there
-- is no chart to play.
--
-- I wanted to split much of this, like the events part,
-- into its own library, but this seems impossible.
-- The getGlobalFromScript function is broken,
-- and wouldn't help much anyway.
--
-- TODO:
-- - A UI framework
-- - Saving and loading



-- Dictates behaviors of editor functions.
editor = false

-- This huge, unwieldy table is the backbone of the input system.
-- This set of functions is rather agnostic to the rest of this
-- script, and it is designed to be simple to configure.
-- So, in theory, you could rip this table for your own
-- Psych Engine script. You won't need much more than the generic
-- functions that it uses and the bit in `onUpdate` that updates
-- the table.
--
-- I don't expect anyone to actually do that, but as long as you're
-- within the license, you are totally free to do so.
local events = {
	-- Index of keys pressed.
	_keys_pressed = {},
	-- Index of events pressed.
	_events_pressed = {},
	-- The cache of keys to check for updates.
	-- This is not expected to need to change!
	_keys_cache = false,
	-- All of the bound keys.
	-- [1] is the event name,
	-- [2] is an argument for the event,
	-- [3] is the keys that this event is bound to.
	-- The event name should be unique, but can be any string.
	-- The argument can be any type, including a table.
	-- The event can be bound to any keys, and a key can be bound to multiple events.
	-- Change this if you want to change the default bindings!
	-- Find a list of keys you can bind here:
	-- https://api.haxeflixel.com/flixel/input/keyboard/FlxKeyList.html
	bound = {
		{ "pause"                  , nil, { "ESCAPE"    } },
		{ "help"                   , nil, { "F1"        } },
		{ "save"                   , nil, { "F10"       } },
		{ "toggle antialiasing"    , nil, { "BACKSLASH" } },
		{ "select previous object" , nil, { "Q"         } },
		{ "select next object"     , nil, { "E"         } },
		{ "camera step X"          , 50 , { "J"         } },
		{ "camera step X"          , -50, { "L"         } },
		{ "camera step Y"          , 50 , { "I"         } },
		{ "camera step Y"          , -50, { "K"         } },
		{ "reset camera X"         , nil, { "SEMICOLON" } },
		{ "reset camera Y"         , nil, { "SEMICOLON" } },
		{ "object step X"          , -50, { "A"         } },
		{ "object step X"          , 50 , { "D"         } },
		{ "object step Y"          , -50, { "W"         } },
		{ "object step Y"          , 50 , { "S"         } },
		{ "speed modifier"         , 0.1, { "Z"         } },
		{ "speed modifier"         , 0.5, { "X"         } },
		{ "speed modifier"         , 2  , { "C"         } },
		{ "speed modifier"         , 5  , { "V"         } },
		{ "speed modifier"         , 10 , { "B"         } }
	},
	-- Regenerates the keys cache.
	generate_key_bindings = function (self)
		self._keys_cache = {}
		for _, event_details in pairs(self.bound) do
			for _, key in pairs(event_details[3]) do
				self._keys_cache[#self._keys_cache + 1] = key
			end
		end
	end,
	-- Returns the keys cache.
	-- The cache will be generated if it hasn't been already.
	key_bindings = function (self)
		if self._keys_cache == false then self:generate_key_bindings() end
		return self._keys_cache
	end,
	-- Returns all events associated with `key`.
	events_by_key = function (self, key)
		local associated_events = {}

		for _, event_details in pairs(self.bound) do
			for _, event_bind in pairs(event_details[3]) do
				if key == event_bind then
					associated_events[#associated_events + 1] = {event_details[1], event_details[2]}
					-- Avoid adding the same event multiple times
					-- if it happens to be bound to the same key more than once.
					break
				end
			end
		end

		return associated_events
	end,
	-- Returns a string describing the event.
	describe_event = function (self, event_details)
		local status, desc = pcall(self._event_description[event_details[1]], event_details[1], event_details[2])
		-- Handle a missing description or a description that otherwise isn't a string.
		if not status or not type(desc) == "string" then
			return "Missing description for event '" .. event_details[1] .. "'"
		else
			return desc
		end
	end,
	-- Table containing all event descriptions.
	_event_description = {
		["pause"] = function () return "Quit the editor" end,
		["help"] = function () return "Get help modifier" end,
		["save"] = function () return "Save the working stage state" end,
		["load"] = function () return "Load the working stage state" end,
		["toggle antialiasing"] = function () return "Toggle antialiasing" end,
		["force antialiasing"] = function (event_name, attr)
			if not type(attr) == "boolean" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Set object antialiasing to " .. attr
			end
		end,
		["select previous object"] = function () return "Select previous object" end,
		["select next object"] = function () return "Select next object" end,
		["select nth object"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Select object at index '" .. attr .. "'"
			end
		end,
		["camera step X"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Move camera on the X axis by " .. attr
			end
		end,
		["camera step Y"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Move camera on the Y axis by " .. attr
			end
		end,
		["reset camera X"] = function () return "Reset the camera's X axis to " .. tostring(default_camera_x) end,
		["reset camera Y"] = function () return "Reset the camera's Y axis to " .. tostring(default_camera_x) end,
		["object step X"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Move object on the X axis by " .. attr
			end
		end,
		["object step Y"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Move object on the Y axis by " .. attr
			end
		end,
		["speed modifier"] = function (event_name, attr)
			if not type(attr) == "number" then
				return "Malformed event '" .. event_name .. "' (wrong attribute type '" .. type(attr) .. "')"
			else
				return "Modify inc/dec speed by " .. attr .. "x"
			end
		end
	},
	-- Returns the `key` pressed state. Should be true or false.
	key_pressed = function (self, key)
		return self._keys_pressed[key]
	end,
	-- Returns (true, attr) if `event_name` is pressed, false otherwise.
	pressed = function (self, event_name)
		local pressed_state = false
		local pressed_attr = nil
		for _, binding in pairs(self.bound) do
			if binding[1] == event_name then
				for _, key in pairs(binding[3]) do
					if self:key_pressed(key) then
						pressed_state = true
						pressed_attr = binding[2]
					end
				end
			end
		end
		return pressed_state, pressed_attr
	end,
	-- Returns (true, attr) if `event_name` was "recently pressed," false otherwise.
	-- "Recently pressed" probably means "within the last frame" but it isn't explicit.
	recently_pressed = function (self, event_name)
		local pressed_state = false
		local pressed_attr = nil
		for _, binding in pairs(self.bound) do
			if binding[1] == event_name then
				for _, key in pairs(binding[3]) do
					if keyboardJustPressed(key) then
						pressed_state = true
						pressed_attr = binding[2]
					end
				end
			end
		end
		return pressed_state, pressed_attr
	end,
	-- Update the key pressed state.
	-- If it has changed, run the appropriate function.
	update = function (self, key, new_state_r)
		-- Make sure we aren't accidentally keeping things that aren't booleans.
		local new_state = false
		if new_state_r then new_state = true end

		if not new_state == self._keys_pressed[key] then
			self:update_silent(key, new_state)
			for _, event_details in pairs(self:events_by_key(key)) do
				if new_state then
					event_pressed(event_details)
				else
					event_released(event_details)
				end
			end
		end
	end,
	-- Update the key pressed state.
	update_silent = function (self, key, new_state)
		self._keys_pressed[key] = new_state
	end
}

-- Length in seconds of the pause key buffer.
-- You have to double tap pause to exit, this
-- defines the length of time that two presses
-- count as a double tap.
pause_buffer_length = 0.5

-- Mouse bindings!
-- The only bindable mouse buttons are "left", "right", and "middle".

-- The mouse button that moves objects.
mouse_move = "left"
-- The mouse button that scales objects.
mouse_scale = "right"
-- The mouse button that changes objects' scroll factors.
mouse_scroll_factor = "middle"

local mouse_binding_table = {
	{["button"] = "mouse_move", ["action"] = "position_by_cursor", ["last x"] = "last_move_x", ["last y"] = "last_move_y", ["last object x"] = "last_move_object_x", ["last object y"] = "last_move_object_y", ["current object x"] = "get_x_position", ["current object y"] = "get_y_position", ["help"] = "Move the current object based on cursor movement"},
	{["button"] = "mouse_scale", ["action"] = "scale_by_cursor", ["last x"] = "last_scale_x", ["last y"] = "last_scale_y", ["last object x"] = "last_scale_object_x", ["last object y"] = "last_scale_object_y", ["current object x"] = "get_x_scale", ["current object y"] = "get_y_scale", ["help"] = "Scale the current object based on cursor movement"},
	{["button"] = "mouse_scroll_factor", ["action"] = "scroll_factor_by_cursor", ["last x"] = "last_scroll_factor_x", ["last y"] = "last_scroll_factor_y", ["last object x"] = "last_scroll_factor_object_x", ["last object y"] = "last_scroll_factor_object_y", ["current object x"] = "get_x_scroll_factor", ["current object y"] = "get_y_scroll_factor", ["help"] = "Change the current object's scroll factor based on cursor movement"}
}

-- Create a new object.
-- This only takes one argument, `tag_name`,
-- because you are meant to use the constructor syntax.
--
-- Changes will not be applied until 'finalized',
-- which happens automatically the first time you try
-- to make the object in-game.
function new_object (tag_name)
	local object = {
		_tag = tag_name,
		_image = "",
		_x_position = 0,
		_y_position = 0,
		_x_scroll_factor = 1,
		_y_scroll_factor = 1,
		_x_scale = 1,
		_y_scale = 1,
		_antialiasing = true,
		_animated = false,
		_fps = nil,
		_character_overlap = false,
		_finalized = false,
		tag = function (self) return self._tag end,
		get_image = function (self) return self._image end,
		get_x_position = function (self) return self._x_position end,
		get_y_position = function (self) return self._y_position end,
		get_x_scroll_factor = function (self) return self._x_scroll_factor end,
		get_y_scroll_factor = function (self) return self._y_scroll_factor end,
		get_x_scale = function (self) return self._x_scale end,
		get_y_scale = function (self) return self._y_scale end,
		-- Returns the *pixel width* of the object.
		get_width = function (self)
			return getProperty(self:tag() .. ".width")
		end,
		-- Returns the *pixel height* of the object.
		get_height = function (self)
			return getProperty(self:tag() .. ".height")
		end,
		get_antialiasing = function (self) return self._antialiasing end,
		get_animated = function (self) return self._animated end,
		get_fps = function (self) return self._fps end,
		get_character_overlap = function (self) return self._character_overlap end,
		get_finalized = function (self) return self._finalized end,
		set_image = function (self, value)
			self._image = value
			if self._finalized then make_all_objects() end
			return self
		end,
		set_x_position = function (self, value, custom_tween_duration)
			self._x_position = value
			if self._finalized then
				doTweenX("move " .. self:tag() .. " x", self:tag(), value, custom_tween_duration or tween_duration, tween_easing)
			end
			return self
		end,
		set_y_position = function (self, value, custom_tween_duration)
			self._y_position = value
			if self:get_finalized() then
				doTweenY("move " .. self:tag() .. " y", self:tag(), value, custom_tween_duration or tween_duration, tween_easing)
			end
			return self
		end,
		set_x_scroll_factor = function (self, value)
			self._x_scroll_factor = value
			if self:get_finalized() then
				setScrollFactor(self:tag(), value, self:get_y_scroll_factor())
			end
			return self
		end,
		set_y_scroll_factor = function (self, value)
			self._y_scroll_factor = value
			if self:get_finalized() then
				setScrollFactor(self:tag(), self:get_x_scroll_factor(), value)
			end
			return self
		end,
		set_x_scale = function (self, value, custom_tween_duration)
			self._x_scale = value
			if self:get_finalized() then
				doTweenX("scale " .. self:tag() .. " X", self:tag() .. ".scale", value, custom_tween_duration or tween_duration, tween_easing)
			end
			return self
		end,
		set_y_scale = function (self, value, custom_tween_duration)
			self._y_scale = value
			if self:get_finalized() then
				--scaleObject(self:tag(), self:get_y_scale(), value)
				doTweenY("scale " .. self:tag() .. " Y", self:tag() .. ".scale", value, custom_tween_duration or tween_duration, tween_easing)
			end
			return self
		end,
		set_antialiasing = function (self, value)
			self._antialiasing = value
			if self:get_finalized() then
				setProperty(self:tag() .. ".antialiasing", value)
				debugPrint("Antialiasing: " .. tostring(value))
			end
			return self
		end,
		set_fps = function (self, value)
			self._fps = value
			if self:get_finalized() then
				make_all_objects()
				debugPrint("Object FPS: " .. tostring(value))
			end
			return self
		end,
		set_animated = function (self, value)
			self._animated = value
			if self:get_finalized() then
				make_all_objects()
				debugPrint("Animation: " .. tostring(value))
			end
			return self
		end,
		set_character_overlap = function (self, value)
			self._character_overlap = value
			if self:get_finalized() then
				make_all_objects()
				debugPrint("Overlaps characters: " .. tostring(value))
			end
			return self
		end,
		set_finalized = function (self, value)
			self._finalized = value
			return self
		end,
		make_outline = function (self) draw_outline(self) end,
		make_object = function (self)
			if self:get_animated() then
				makeAnimatedLuaSprite(self:tag(), self:get_image(), self:get_x_position(), self:get_y_position())
				addAnimationByPrefix(self:tag(), self:get_animated(), self:get_animated(), self:get_fps(), true)
			else
				makeLuaSprite(self:tag(), self:get_image(), self:get_x_position(), self:get_y_position())
			end

			scaleObject(self:tag(), self:get_x_scale(), self:get_y_scale())
			setScrollFactor(self:tag(), self:get_x_scroll_factor(), self:get_y_scroll_factor())
			setProperty(self:tag() .. ".antialiasing", self:get_antialiasing())

			addLuaSprite(self:tag(), self:get_character_overlap())

			if self:get_animated() then
				playAnim(self:tag(), self:get_animated(), true)
			end

			if editor then
				-- Now make the outline
				self:make_outline()
			end

			self:set_finalized(true)
		end
	}

	return object
end

-- Create a new "object" that represents a character.
-- They're two separate things in the FNF engine. Yeah.
--
-- `tag_name` will be the vanity name, while
-- `character_name` will be the actual internal character name.
function new_character (tag_name, character_name)
	--debugPrint(character_name .. "Group.scale.x: " .. getProperty(character_name .. "Group.scale.x"))
	return {
		_character_name = character_name,
		_tag_name = tag_name,
		-- Changing the character position directly
		-- causes weird things for some reason.
		-- We need to change the characterGroup
		-- position instead.
		_x_position = getCharacterX(character_name),
		_y_position = getCharacterY(character_name),
		_x_scale = 1.0,
		_y_scale = 1.0,
		_antialiasing = getProperty(character_name .. "Group.antialiasing"),
		tag = function (self) return self._tag_name end,
		get_image = function (self) getProperty(self._character_name .. ".imageFile") end,
		get_x_position = function (self) return self._x_position end,
		get_y_position = function (self) return self._y_position end,
		get_x_scroll_factor = function (self) return 1 end,
		get_y_scroll_factor = function (self) return 1 end,
		get_x_scale = function (self) return self._x_scale end,
		get_y_scale = function (self) return self._y_scale end,
		get_antialiasing = function (self) return self._antialiasing end,
		get_fps = function (self) error("can't get fps of " .. self:tag()) end,
		get_character_overlap = function (self) return true end,
		get_finalized = function (self) return true end,
		set_image = function (self) error("can't set image name of " .. self:tag()) end,
		set_x_position = function (self, value, custom_tween_duration)
			self._x_position = value
			doTweenX("move " .. self:tag() .. " x", self._character_name .. "Group", value, custom_tween_duration or tween_duration, tween_easing)
			return self
		end,
		set_y_position = function (self, value, custom_tween_duration)
			self._y_position = value
			doTweenY("move " .. self:tag() .. " y", self._character_name .. "Group", value, custom_tween_duration or tween_duration, tween_easing)
			return self
		end,
		set_x_scroll_factor = function (self) error("can't set x scroll factor of " .. self:tag()) end,
		set_y_scroll_factor = function (self) error("can't set y scroll factor of " .. self:tag()) end,
		set_x_scale = function (self, value, custom_tween_duration)
			self._x_scale = value
			doTweenX("scale " .. self:tag() .. " x", self._character_name .. "Group.scale", value, custom_tween_duration or tween_duration, tween_easing)
			if self._character_name == "boyfriend" then
				setPropertyFromClass("GameOverSubstate", "boyfriend.scale.x", value)
			end
			return self
		end,
		set_y_scale = function (self, value, custom_tween_duration)
			self._y_scale = value
			doTweenY("scale " .. self:tag() .. " y", self._character_name .. "Group.scale", value, custom_tween_duration or tween_duration, tween_easing)
			if self._character_name == "boyfriend" then
				setPropertyFromClass("GameOverSubstate", "boyfriend.scale.y", value)
			end
			return self
		end,
		-- Realistically you shouldn't be forcing character antialiasing.
		-- If you don't have a very good reason but do anyway, I WILL find you.
		set_antialiasing = function (self, value)
			self._antialiasing = value
			setProperty(self._character_name .. ".antialiasing", value)
			if self._character_name == "boyfriend" then
				setPropertyFromClass("GameOverSubstate", "boyfriend.antialiasing", value)
			end
			return self
		end,
		set_fps = function (self) error("can't set fps of " .. self:tag()) end,
		set_character_overlap = function (self) error("can't set character overlap for " .. self:tag()) end,
		set_finalized = function (self) error("can't change finalized status for " .. self:tag()) end,
		-- Special function to change player 1's death sprite.
		_death = function (self)
			if self._character_name == "boyfriend" then
				local is_ok, output = pcall(getProperty, "health")
				if is_ok and output == 0 then
					debugPrint("You Died!")
					--setProperty("boyfriend.scale.x", self:get_x_scale())
					--setProperty("boyfriend.scale.y", self:get_y_scale())
					--try(setPropertyFromClass, "GameOverSubstate", "boyfriend.antialiasing", self:get_antialiasing())
					return true
				else return false end
			else
				return false
			end
		end,
		make_object = function (self) return nil end -- Nothing to do.
	}
end

-- Default text scale.
text_scale = 1.5

-- Default camera location.
default_camera_x, default_camera_y = 0, 0

-- Current camera location.
current_camera_x, current_camera_y = 0, 0

-- The game camera.
camera_game = "camGame"

-- The HUD camera.
camera_hud = "camOther"

-- The dummy camera.
camera_dummy = "camHUD"

-- Index of the current object in the `objects` table.
current_object = 1

-- Used for tween durations.
-- This value can't be equal to zero. You can, however, make it 'practically' zero.
tween_duration = 0.5

-- Used for tween durations that should be instant regardless,
-- like mouse movements.
tween_duration_instant = 0.0000001

-- Curve used for tween easing.
-- Values other than "linear" might appear weirdly,
-- because of how existing tweens replace each other.
tween_easing = "linear"

function onCreate ()
	try(on_create_dummy)
end
function on_create_dummy ()
	-- The file to save to/load from.
	working_file, working_absolute = getPropertyFromClass("Paths", "currentModDirectory") .. "/stages/stage-editor/" .. songName, false
	if editor then
		debugPrint("Current file is " .. working_file)
	end
	--working_file, working_absolute = "/tmp/school-sd", true

	-- Force editor mode to enabled if the difficulty is "Editor".
	if getPropertyFromClass("CoolUtil", "difficulties["..difficulty.."]") == "Editor" then
		editor = true
	end

	-- Populate the currently pressed key states with false values.
	-- Without this we might get a bunch of key release events at once,
	-- which would be bad maybe.
	--
	-- It just seems like good practice.
	--
	-- I could work around the need for this at all, by changing
	-- the index function in the metatable.
	-- But I'm too lazy to do that.
	for _, key in pairs(events:key_bindings()) do
		try(events.update_silent, events, key, false)
	end

	if editor then
		last_cursor_state = getPropertyFromClass("flixel.FlxG", "mouse.visible")
		-- Enable the mouse cursor.
		try(setPropertyFromClass, "flixel.FlxG", "mouse.visible", true)
	end
	--[[

	local ok1, ok2, ok3

	-- Why is boyfriend called "boyfriend" but girlfriend is called "gf"??
	ok1, player1 = try(new_character, "player1", "boyfriend")
	ok2, player2 = try(new_character, "player2", "dad")
	ok3, girlfriend = try(new_character, "girlfriend", "gf")
	objects = {}

	-- All objects.
	if ok2 then
		objects[#objects + 1] = player2
	end
	if ok1 then
		objects[#objects + 1] = player1
	end
	if ok3 then
		objects[#objects + 1] = girlfriend
	end

	objects[#objects + 1] = new_object("background"):set_image("school-sky-sd"):set_x_position(-300):set_y_position(0):set_x_scroll_factor(0.05):set_y_scroll_factor(0.05):set_x_scale(7):set_y_scale(7):set_antialiasing(false)
	objects[#objects + 1] = new_object("street"):set_image("school-street-sd"):set_x_position(-300):set_y_position(-100):set_x_scroll_factor(1):set_y_scroll_factor(0.96):set_x_scale(7):set_y_scale(7):set_antialiasing(false)
	objects[#objects + 1] = new_object("school"):set_image("school-sd"):set_x_position(-300):set_y_position(-100):set_x_scroll_factor(0.8):set_y_scroll_factor(0.9):set_x_scale(7):set_y_scale(7):set_antialiasing(false)
	objects[#objects + 1] = new_object("trees-background"):set_image("school-trees-background-sd"):set_x_position(-60):set_y_position(140):set_x_scroll_factor(1):set_y_scroll_factor(0.9):set_x_scale(5):set_y_scale(5):set_antialiasing(false)
	objects[#objects + 1] = new_object("petals"):set_image("school-petals-sd"):set_x_position(50):set_y_position(-300):set_x_scroll_factor(1):set_y_scroll_factor(0.91):set_x_scale(7):set_y_scale(7):set_animated("fall"):set_fps(24):set_antialiasing(false)
	objects[#objects + 1] = new_object("trees-foreground"):set_image("school-trees-foreground-sd"):set_x_position(-550):set_y_position(-700):set_x_scroll_factor(1):set_y_scroll_factor(0.95):set_x_scale(5):set_y_scale(5):set_animated("idle"):set_fps(12):set_antialiasing(false)
	objects[#objects + 1] = new_object("freaks"):set_image("school-background-freaks-sd"):set_x_position(-270):set_y_position(100):set_x_scroll_factor(1):set_y_scroll_factor(0.93):set_x_scale(7):set_y_scale(7):set_animated("dissuaded"):set_fps(24):set_antialiasing(false)
	]]--

	local is_ok
	local is_ok, exists = try(checkFileExists, working_file, working_absolute)
	if not is_ok then
		debugPrint(string.format("There was an error accessing the file '%s'. Verify you have permission to read this file.", working_file))
	elseif not exists then
		debugPrint(string.format("The file '%s' does not seem to exist.", working_file))
	end
	is_ok, objects = try(load_state, working_file)
	if not is_ok then
		debugPrint(string.format("There was an error loading the file '%s'.", working_file))
		objects = {}
		objects[#objects + 1] = new_character("girlfriend", "gf")
		objects[#objects + 1] = new_character("player1", "boyfriend")
		objects[#objects + 1] = new_character("player2", "dad")
	end

	for _, object in pairs(objects) do
		if object:tag() == "player1" then
			player1 = object
		elseif object:tag() == "player2" then
			player2 = object
		elseif object:tag() == "girlfriend" then
			girlfriend = object
		end
	end

	try(make_all_objects)
end

function onDestroy ()
	-- Revert the mouse cursor visibility.
	setPropertyFromClass("flixel.FlxG", "mouse.visible", last_cursor_state)
end

function onStartCountdown ()
	-- Yes, this is supposed to be negative.
	-- Why? Who knows. I just work here.
	default_camera_x, default_camera_y = -getProperty("camFollowPos.x"), -getProperty("camFollowPos.y")
	current_camera_x, current_camera_y = default_camera_x, default_camera_y
	if editor then
		-- Make the UI invisible.

		-- The tag (the first parameter) has to be unique,
		-- or it will replace the existing tween.
		doTweenAlpha(8, "scoreTxt", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(9, "botplayTxt", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(10, "healthBar", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(11, "healthBarBG", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(12, "iconP1", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(13, "iconP2", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(14, "doof", 0, tween_duration_instant, tween_easing)
		setProperty("cameraSpeed", 0)
		return Function_Stop
	end
end

function onCountdownTick (count)
	if count == 1 then
		-- Yes, this is supposed to be negative.
		-- Why? Who knows. I just work here.
		default_camera_x, default_camera_y = -getProperty("camFollowPos.x"), -getProperty("camFollowPos.y")
		current_camera_x, current_camera_y = default_camera_x, default_camera_y
	elseif count == 4 then
		if editor then
			-- Make the UI invisible.
			for index = -1,7 do
				-- Receptors index annoyingly starts at 0.
				-- I know it's annoying that Lua indexes start at 1, but at least be consistent.. please?
				noteTweenAlpha(index, index, 0, tween_duration_instant, tween_easing)
			end

			-- The tag (the first parameter) has to be unique,
			-- or it will replace the existing tween.
			doTweenAlpha(8, "scoreTxt", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(9, "botplayTxt", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(10, "healthBar", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(11, "healthBarBG", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(12, "iconP1", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(13, "iconP2", 0, tween_duration_instant, tween_easing)
			doTweenAlpha(14, "doof", 0, tween_duration_instant, tween_easing)
			setProperty("cameraSpeed", 0)
			-- The time bar has a unique fade in tween that makes it annoying to hide.
			runTimer("post fade time bar hide", 0.55, 1)
		end
	end
end

function onUpdate ()
	try(on_update_dummy)
end
function on_update_dummy ()
	if editor then
		-- Force the characters to dance.
		-- There is a long-standing FNF bug(?) which makes characters not animate
		-- after there are no more notes in the chart to play.
		-- This hack tries to work around that.
		playAnim(player1._character_name, "idle", false, false, 0)
		playAnim(player2._character_name, "idle", false, false, 0)
		playAnim(girlfriend._character_name, "idle", false, false, 0)

		-- Try not to lose in the editor...
		-- pcall because this raises an exception on game over.
		pcall(setProperty, "health", 1000)
	end

	-- Update the events status.
	-- This happens regardless of the editor stauts.
	local bindings = events:key_bindings()
	for _, key in pairs(bindings) do
		local status = getPropertyFromClass("flixel.FlxG", "keys.pressed." .. key)

		try(events.update, events, key, status)
	end

	if editor then
		try(editor_mouse_input)

		try(draw_ui)
	end
end

function onGameOver ()
	-- Forcibly stop editor mode
	editor = false

	try(player1._death, player1)
	return Function_Continue
end

function onTimerCompleted (tag)
	if tag == "post fade time bar hide" then
		doTweenAlpha(15, "timeBar", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(16, "timeBarBG", 0, tween_duration_instant, tween_easing)
		doTweenAlpha(17, "timeTxt", 0, tween_duration_instant, tween_easing)
	elseif tag == "clear pause_buffer" then
		pause_buffer = nil
	end
end

-- Special characters used by the de/serializer

-- Separator for key and value.
_serial_kv_separator = "="
-- Separator for key/value pairs.
_serial_separator = ";"
-- Separator for objects.
_serial_object_separator = "\n"
-- Escape character.
_serial_escape = "\\"
-- Unique type indicators.
_serial_types = { ["string"] = "s", ["number"] = "n", ["boolean"] = "b", ["nil"] = "x" }

-- Serializes a string.
function serialize_string (text)
	local text = tostring(text)
	local text = text:gsub(_serial_separator, _serial_escape .. _serial_separator)
	local text = text:gsub(_serial_object_separator, _serial_escape .. _serial_object_separator)
	return text
end

-- Serializes a key and value pair into a string.
function serialize_kv (k, v)
	local key = serialize_string(k)
	local type_is
	if _serial_types[type(v)] then
		type_is = _serial_types[type(v)]
	else
		type_is = "?"
	end
	local value = serialize_string(v)

	local serialized = key .. _serial_kv_separator .. type_is
	if type_is == _serial_types["string"] or type_is == _serial_types["number"] or type_is == _serial_types["boolean"] then
		serialized = serialized .. value
	end
	serialized = serialized .. _serial_separator

	return serialized
end

-- Exports a single object to a serialized string.
function serialize_object (object)
	local output = serialize_kv("tag", object:tag())
	local is_ok, image = pcall(object.get_image, object)
	if is_ok then
		output = output .. serialize_kv("image", image)
	end
	output = output .. serialize_kv("x position", object:get_x_position())
	output = output .. serialize_kv("y position", object:get_y_position())
	local is_ok, x_scroll_factor = pcall(object.get_x_scroll_factor, object)
	if is_ok and x_scroll_factor ~= 1 then
		output = output .. serialize_kv("x scroll factor", x_scroll_factor)
	end
	local is_ok, y_scroll_factor = pcall(object.get_y_scroll_factor, object)
	if is_ok and y_scroll_factor ~= 1 then
		output = output .. serialize_kv("y scroll factor", y_scroll_factor)
	end
	local x_scale = object:get_x_scale()
	if x_scale ~= 1 then
		-- This is a hack.
		output = output .. serialize_kv("x scale", x_scale)
	end
	local y_scale = object:get_y_scale()
	if y_scale ~= 1 then
		output = output .. serialize_kv("y scale", y_scale)
	end
	output = output .. serialize_kv("antialiasing", object:get_antialiasing())
	local is_ok, animated = pcall(object.get_animated, object)
	if is_ok then
		output = output .. serialize_kv("animated", animated)
	end
	local is_ok, fps = pcall(object.get_fps, object)
	if is_ok then
		output = output .. serialize_kv("fps", fps)
	end
	local is_ok, character_overlap = pcall(object.get_character_overlap, object)
	if is_ok then
		output = output .. serialize_kv("character overlap", character_overlap)
	end

	return output
end

-- Exports the current objects states into a serialized string.
function serialize_all ()
	local output = ""
	for _, object in ipairs(objects) do
		output = output .. serialize_object(object)
		output = output .. _serial_object_separator
	end
	return output
end

-- Deserializes a string value into type `t`.
function deserialize_into_type (value, t)
	if t == _serial_types["string"] then
		return tostring(value)
	elseif t == _serial_types["number"] then
		return tonumber(value)
	elseif t == _serial_types["boolean"] then
		if value == "true" or value == "1" then
			return true
		else
			return false
		end
	else
		return nil
	end
end

-- Deserializes a string into a table of objects.
-- This is a super basic lexer, but it's also really generic.
-- It basically just deserializes a table of strings from a string.
-- Feel free to reuse this code if you want. Though, if you want
-- something more complicated, there are tons of Lua serializers
-- out there that you could use.
function deserialize_string (input)
	local deserialized = {}

	local current_object = {}

	local key = ""
	local assigning_value = false
	local type_is = nil
	local value = ""
	local escape = false

	for character in input:gmatch(".") do
		if type_is == nil and assigning_value then
			-- The first character is a type hint.
			local hinted = index_by_value(_serial_types, character)
			if hinted then
				type_is = character
			else
				-- The type wasn't understood.
				type_is = _serial_types["nil"]
			end
		elseif not escape and character == _serial_kv_separator then
			assigning_value = true
		elseif not escape and character == _serial_separator then
			current_object[key] = deserialize_into_type(value, type_is)
			key, value = "", ""
			type_is = nil
			assigning_value = false
		elseif not escape and character == _serial_object_separator then
			if not key == "" then
				current_object[key] = deserialize_into_type(value, type_is)
			end
			deserialized[#deserialized + 1] = current_object
			current_object = {}
			key, value = "", ""
			type_is = nil
			assigning_value = false
		elseif not escape and character == _serial_escape then
			escape = true
		else
			if assigning_value then
				value = value .. character
			else
				key = key .. character
			end

			escape = false
		end
	end

	return deserialized
end

-- Deserializes an object from the input table.
function build_object (input)
	local object
	if input["tag"] == "girlfriend" then
		object = new_character("girlfriend", "gf")
	elseif input["tag"] == "player1" then
		object = new_character("player1", "boyfriend")
	elseif input["tag"] == "player2" then
		object = new_character("player2", "dad")
	else
		object = new_object(input["tag"])
	end

	for key, value in pairs(input) do
		if key == "image" and type(value) == "string" then
			pcall(object.set_image, object, value)
		elseif key == "x position" and type(value) == "number" then
			pcall(object.set_x_position, object, value)
		elseif key == "y position" and type(value) == "number" then
			pcall(object.set_y_position, object, value)
		elseif key == "x scale" and type(value) == "number" then
			pcall(object.set_x_scale, object, value)
		elseif key == "y scale" and type(value) == "number" then
			pcall(object.set_y_scale, object, value)
		elseif key == "x scroll factor" and type(value) == "number" then
			pcall(object.set_x_scroll_factor, object, value)
		elseif key == "y scroll factor" and type(value) == "number" then
			pcall(object.set_y_scroll_factor, object, value)
		elseif key == "antialiasing" and type(value) == "boolean" then
			pcall(object.set_antialiasing, object, value)
		elseif key == "animated" and type(value) == "string" then
			pcall(object.set_animated, object, value)
		elseif key == "fps" and type(value) == "number" then
			pcall(object.set_fps, object, value)
		elseif key == "character overlap" and type(value) == "boolean" then
			pcall(object.set_character_overlap, object, value)
		end
	end

	return object
end

-- Deserializes an object from the input string.
function deserialize_object_from_string (input)
	local deserialized = deserialize_string(input)
	return build_object(deserialized)
end

-- Load a serialized stage state from a file.
-- Returns the objects.
function load_state (path)
	local serialized = getTextFromFile(path)

	local tables = deserialize_string(serialized)

	local objects = {}

	for index = 1, #tables do
		objects[#objects + 1] = build_object(tables[index])
		pcall(objects[#objects].set_finalized, objects[#objects], true)
	end

	return objects
end

-- This function handles an event being pressed.
-- `event_details[1] is the event name, while
-- `event_details[2] is the event argument.
-- 
-- To make it very easy to reuse, I have split the editor relevant
-- things into its own function. You can look at it (and the
-- events table) for examples on how to interact with the events
-- table.
function event_pressed (event_details)
	local event_name = event_details[1]
	local event_attr = event_details[2]

	if editor then
		try(editor_input, event_details)
	end
end

function editor_mouse_input ()
	if events:recently_pressed("pause") then
		if pause_buffer then
			endSong()
		else
			pause_buffer = true
			runTimer("clear pause_buffer", pause_buffer_length, 1)
			if pause_buffer_length < 1 then
				debugPrint("Press pause again to quit. (" .. pause_buffer_length * 1000 .. " milliseconds)")
			else
				debugPrint("Press pause again to quit. (" .. pause_buffer_length .. " seconds)")
			end
		end
	end
	local help = events:pressed("help")

	for _, mouse_binding in pairs(mouse_binding_table) do
		if mousePressed(_G[mouse_binding["button"]]) and not help then
			-- Set these values if they aren't already, which will be the first frame.
			if not _G[mouse_binding["last x"]] then _G[mouse_binding["last x"]] = getMouseX(camera_dummy) end
			if not _G[mouse_binding["last y"]] then _G[mouse_binding["last y"]] = getMouseY(camera_dummy) end
			_G[mouse_binding["last object x"]] = objects[current_object][mouse_binding["current object x"]](objects[current_object])
			_G[mouse_binding["last object y"]] = objects[current_object][mouse_binding["current object y"]](objects[current_object])
			try(_G[mouse_binding["action"]])
			_G[mouse_binding["last x"]] = getMouseX(camera_dummy)
			_G[mouse_binding["last y"]] = getMouseY(camera_dummy)
		elseif mouseClicked(_G[mouse_binding["button"]]) and help then
			debugPrint("Help: " .. mouse_binding["help"])
		elseif mouseReleased(_G[mouse_binding["button"]]) then
			_G[mouse_binding["last x"]], _G[mouse_binding["last y"]], _G[mouse_binding["last object x"]], _G[mouse_binding["last object y"]] = nil, nil, nil, nil
		end
		
	end

	--[[
	if mousePressed(mouse_move) and not help then
		if mouseClicked(mouse_move) then last_move_x, last_move_y, last_move_object_x, last_move_object_y = getMouseX(camera_dummy), getMouseY(camera_dummy), objects[current_object]:get_x_position(), objects[current_object]:get_y_position() end
		try(position_by_cursor)
	elseif mouseClicked(mouse_move) and help then
		debugPrint("Help: move the current object based on cursor movement")
	elseif mouseReleased(mouse_move) then
		last_move_x, last_move_y, last_move_object_x, last_move_object_y = nil, nil, nil, nil
	end

	if mousePressed(mouse_scale) and not help then
		if mouseClicked(mouse_scale) then last_scale_x, last_scale_y, last_scale_object_x, last_scale_object_y = getMouseX(camera_dummy), getMouseY(camera_dummy), objects[current_object]:get_x_scale(), objects[current_object]:get_y_scale() end
		try(scale_by_cursor)
	elseif mouseClicked(mouse_scale) and help then
		debugPrint("Help: scale the current object based on cursor movement")
	elseif mouseReleased(mouse_scale) then
		last_scale_x, last_scale_y, last_scale_object_x, last_scale_object_y = nil, nil, nil, nil
	end

	if mousePressed(mouse_scroll_factor) and not help then
		if mouseClicked(mouse_scroll_factor) then last_scroll_factor_x, last_scroll_factor_y, last_scroll_factor_object_x, last_scroll_factor_object_y = getMouseX(camera_dummy), getMouseY(camera_dummy), objects[current_object]:get_x_scroll_factor(), objects[current_object]:get_y_scroll_factor() end
		try(scroll_factor_by_cursor)
	elseif mouseClicked(mouse_scroll_factor) and help then
		debugPrint("Help: change the current object's scroll factor based on cursor movement")
	elseif mouseReleased(mouse_scroll_factor) then
		last_scroll_factor_x, last_scroll_factor_y, last_scroll_factor_object_x, last_scroll_factor_object_y = nil, nil, nil, nil
	end]]--
end

-- This handles all editor input, and as such shouldn't be run
-- outside of editor mode.
function editor_input (event_details)
	local event_name = event_details[1]
	local event_attr = event_details[2]

	-- Do not respond to inputs normally if the "help" event is held.
	if events:pressed("help") then
		debugPrint("Help: " .. events:describe_event(event_details))
	else	
		if event_name == "save" then
			debugPrint(string.format("Saving to '%s'", working_file))
			local is_ok, serialized = try(serialize_all)
			if is_ok then
				local is_ok = try(saveFile, working_file, serialized, working_absolute)
				if is_ok then
					debugPrint(string.format("Saved to '%s' without error", working_file))
				end
			end
		elseif event_name == "select next object" then
			if current_object == #objects then
				current_object = 1
			else
				current_object = current_object + 1
			end
			select_object(current_object)
		elseif event_name == "select previous object" then
			if current_object == 1 then
				current_object = #objects
			else
				current_object = current_object - 1
			end
			select_object(current_object)
		elseif event_name == "toggle antialiasing" then
			local is_ok, aa = try(objects[current_object].get_antialiasing, objects[current_object])
			if is_ok then
				try(objects[current_object].set_antialiasing, objects[current_object], not aa)
			end
		elseif event_name == "camera step X" then
			local x = get_camera_x() + event_attr * get_speed_modifier()
			try(move_camera_x, x)
		elseif event_name == "camera step Y" then
			local y = get_camera_y() + event_attr * get_speed_modifier()
			try(move_camera_y, y)
		elseif event_name == "reset camera X" then
			--try(move_camera_x, default_camera_x)
			try(move_camera_x, default_camera_x)
		elseif event_name == "reset camera Y" then
			try(move_camera_y, default_camera_y)
		elseif event_name == "object step X" then
			local is_ok, x = try(objects[current_object].get_x_position, objects[current_object])
			if is_ok and type(x) == "number" then
				try(objects[current_object].set_x_position, objects[current_object], x + event_attr * get_speed_modifier())
			else
				log_error(string.format("X is wrong type '%s'", type(x)))
			end
		elseif event_name == "object step Y" then
			local is_ok, y = try(objects[current_object].get_y_position, objects[current_object])
			if is_ok and type(y) == "number" then
				try(objects[current_object].set_y_position, objects[current_object], y + event_attr * get_speed_modifier())
			else
				log_error(string.format("Y is wrong type '%s'", type(y)))
			end
		end
	end
end

-- Shamelessly borrowed from
-- https://stackoverflow.com/questions/38282234/returning-the-index-of-a-value-in-a-lua-table
function index_by_value (array, value)
	for k, v in pairs(array) do
		if v == value then
			return k
		end
	end
end

-- Run a function. Log and continue if it returns an error.
function try (func, ...)
	local is_ok, output = pcall(func, ...)
	if not is_ok then log_error(output) end
	return is_ok, output
end

-- Print an error.
function log_error (message)
	debugPrint("Error: " .. message)
end

-- Draw the display.
function draw_ui ()
	if editor then
		show_object()
		show_object_meta()
	end
end

function show_value (tag, text, x, y, centered, scale, ...)
	if editor then
		local scale = scale or text_scale
		local centered = centered or false

		makeLuaText(tag, string.format(text, ...), 0, x, y)
		setObjectCamera(tag, camera_hud)
		scaleObject(tag, scale, scale)
		if centered then screenCenter(tag, centered) end
		addLuaText(tag)
	end
end

function show_object_meta ()
	if editor then
		local line_height = 16
		local text_bottom = 716

		local animation_is_ok, animation_output = pcall(objects[current_object].get_animated, objects[current_object])
		if not animation_is_ok then animation_output = "N/A" end
		local antialiasing_is_ok, antialiasing_output = pcall(objects[current_object].get_antialiasing, objects[current_object])
		if not antialiasing_is_ok then antialiasing_output = "N/A" end
		local fps_is_ok, fps_output = pcall(objects[current_object].get_fps, objects[current_object])
		if not fps_is_ok then fps_output = "N/A" end
		if fps_output == nil then fps_output = "N/A" end
		for index, details in ipairs(
		{
			{["tag"] = "object fps", ["text"] = "Animation FPS: %s", tostring(fps_output)},
			{["tag"] = "object animation", ["text"] = "Animation: %s", tostring(animation_output)},
			{["tag"] = "object antialiasing", ["text"] = "Antialiasing: %s", tostring(antialiasing_output)},
			{["tag"] = "object scroll factor", ["text"] = "X scroll factor: %.3f, Y scroll factor: %.3f", objects[current_object]:get_x_scroll_factor(), objects[current_object]:get_y_scroll_factor()},
			{["tag"] = "object scale", ["text"] = "X scale: %.3f, Y scale: %.3f", objects[current_object]:get_x_scale(), objects[current_object]:get_y_scale()},
			{["tag"] = "object pos", ["text"] = "X: %4.3f, Y: %4.3f", objects[current_object]:get_x_position(), objects[current_object]:get_y_position()},
			{["tag"] = "object meta", ["text"] = "Object information"}
		}) do
			local tag = tostring(details["tag"])
			details["tag"] = nil
			local text = tostring(details["text"])
			details["text"] = nil
			show_value(tag, text, 0, text_bottom - text_scale * line_height * index, false, text_scale, unpack(details))
		end
	end
end

-- Show the current object's tag name.
function show_object ()
	local tag = "__object name"
	makeLuaText(tag, "Current object: " .. objects[current_object]:tag(), 0, 0, 0)
	setObjectCamera(tag, camera_hud)
	scaleObject(tag, text_scale, text_scale)
	screenCenter(tag, "x")
	addLuaText(tag)
end

function event_released (event_details)
	-- TODO?
end

-- Make all objects from the `objects` table.
function make_all_objects ()
	for index = 1, #objects do
		objects[index]:make_object()
	end
end

-- Draw an outline surrounding the object.
--
-- I was never very good at math.
-- Hopefully I do this right.
function draw_outline (object, color)
	if editor then
		local tag = object:tag()
		local x = object:get_x_position()
		local y = object:get_y_position()
		local w = object:get_width()
		local h = object:get_height()
		local color = color or "FFFFFF"
		local scale_factor = 1
		local scale
		if w > h then scale = h else scale = w end
		local max_scale = 50
		if scale > max_scale then scale = max_scale end
		local short_size = scale * 0.1
		local long_size = scale * 0.4
		local outline_tag = tag .. " outline"

		local cross_x_tag = outline_tag .. " cross x"
		addLuaSprite(cross_x_tag, nil, x + w / 2, y + h / 2)
		makeGraphic(cross_x_tag, scale * scale_factor, scale * scale_factor, color)
		addLuaSprite(cross_x_tag, true)

		local cross_y_tag = outline_tag .. " cross y"
		addLuaSprite(cross_y_tag, nil, x + w / 2, y + h / 2)
		makeGraphic(cross_y_tag, scale * scale_factor, scale * scale_factor, color)
		addLuaSprite(cross_y_tag, true)
		--debugPrint(string.format("x: %d y: %d size: %d", x, y, scale * scale_factor))
	end
end

-- Return the speed modifier currently pressed.
-- If multiple are pressed, only the first one found is respected.
function get_speed_modifier ()
	local state, modifier = events:pressed("speed modifier")
	if state then
		return modifier
	else
		return 1.0
	end
end

function scale_camera (value, custom_tween_duration)
	doTweenZoom("camera", camera_game, value, custom_tween_duration or tween_duration, tween_easing)
	doTweenZoom("camera", camera_dummy, value, custom_tween_duration or tween_duration, tween_easing)
end

-- Returns the camera's X position.
function get_camera_x ()
	return current_camera_x
end

-- Returns the camera's Y position.
function get_camera_y ()
	return current_camera_y
end

-- Moves the camera to the specified X position.
function move_camera_x (value, custom_tween_duration)
	current_camera_x = value
	setProperty("camFollowPos.x", -value)
	doTweenX("camera X", camera_dummy, value, tween_duration_instant, tween_easing)
	debugPrint("Camera X: " .. value)
end

-- Moves the camera to the specified X position.
function move_camera_y (value, custom_tween_duration)
	current_camera_y = value
	setProperty("camFollowPos.y", -value)
	doTweenY("camera Y", camera_dummy, value, tween_duration_instant, tween_easing)
	debugPrint("Camera Y: " .. value)
end

-- Change the object position based on the cursor.
function position_by_cursor ()
	local x_difference = getMouseX(camera_dummy) - last_move_x
	local y_difference = getMouseY(camera_dummy) - last_move_y
	objects[current_object]:set_x_position(last_move_object_x + x_difference * get_speed_modifier(), tween_duration_instant)
	objects[current_object]:set_y_position(last_move_object_y + y_difference * get_speed_modifier(), tween_duration_instant)
end

-- Change the object scale based on the cursor.
function scale_by_cursor ()
	local x_difference = getMouseX(camera_dummy) - last_scale_x
	local y_difference = getMouseY(camera_dummy) - last_scale_y
	objects[current_object]:set_x_scale(last_scale_object_x + (x_difference * get_speed_modifier()) * 0.01, tween_duration_instant)
	objects[current_object]:set_y_scale(last_scale_object_y + (y_difference * get_speed_modifier()) * 0.01, tween_duration_instant)
end

-- Change the object scroll factor based on the cursor.
function scroll_factor_by_cursor ()
	local x_difference = getMouseX(camera_dummy) - last_scroll_factor_x
	local y_difference = getMouseY(camera_dummy) - last_scroll_factor_y
	objects[current_object]:set_x_scroll_factor(last_scroll_factor_object_x + (x_difference * get_speed_modifier()) * 0.01, tween_duration_instant)
	objects[current_object]:set_y_scroll_factor(last_scroll_factor_object_y + (y_difference * get_speed_modifier()) * 0.01, tween_duration_instant)
end

function select_object (index)
	current_object = index
end