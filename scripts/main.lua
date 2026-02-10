local ui = require "scripts/ui"
local coro = require "scripts/coroutine"
local lmath = require "scripts/math"

ball_model = Lumix.Resource:newEmpty("model")
club_model = Lumix.Resource:newEmpty("model")
hole_marker = Lumix.Entity.NULL

local SENSITIVITY = 0.001
local MAX_IMPULSE = 3.0
local UP_IMPULSE_FACTOR = 0.0

local current_level = 1
local level_partition = 0
local ball = nil
local club = nil
local camera = nil
local yaw = 0
local swing_pitch = 0
local ui_enabled = false
local is_down = false
local impuluse_to_add = 0
local is_ball_moving = false
local game_time = 0
local strokes = 0
local hud_canvas = nil

local enableUI = function()
	ui_enabled = true
	this.world.gui:getSystem():enableCursor(true)
end

local disableUI = function()
	ui_enabled = false
	this.world.gui:getSystem():enableCursor(false)
end

function loadLevel(lvl)
	level_partition = this.world:createPartition(`level{current_level}`)
	this.world:setActivePartition(level_partition)
	this.world:load(`maps/level{current_level}.unv`, onLevelLoaded)
end

local addImpulse = function()
	local yaw_rad = yaw * SENSITIVITY
	local dirx = math.sin(yaw_rad)
	local dirz = math.cos(yaw_rad)

	local amplitude = math.min(impuluse_to_add, 1) * MAX_IMPULSE
	local ix = dirx * amplitude
	local iy = UP_IMPULSE_FACTOR * amplitude
	local iz = dirz * amplitude

	ball.jolt_body:addImpulse({ix, iy, iz})
end


local interpolateSwingPitch = function(start_val, end_val, length)
	local time = 0
	local impulsed = false
	while time < length do
		local rel = time / length
		local t
		if rel == 0 then
			t = 0
		elseif rel == 1 then
			t = 1
		else
			local c4 = (2 * math.pi) / 3
			t = 2 ^ (-10 * rel) * math.sin((rel * 10 - 0.75) * c4) + 1
		end
		if t > 0.99 and not impulsed then
			club.model_instance.enabled = false
			addImpulse()
			impulsed = true
		end
		swing_pitch = start_val + (end_val - start_val) * t
		td = coroutine.yield()
		time = time + td
	end
end

local mergeObjects = function(dst, src)
	for k, v in pairs(src) do
		if type(k) == "number" then
			table.insert(dst, v)
		else
			dst[k] = v
		end
	end
end

local ui_window = function(def)
	local merged = {
		sprite = "ui/Blue/Default/button_rectangle_border.spr",
		ui.center,
		left_points = -200,
		right_points = 200,
		top_points = -200,
		bottom_points = 200,
	}
	mergeObjects(merged, def)
	return ui.image(merged)
end

local ui_window_label = function(text)
	return ui.text {
		text = text,
		font = "engine/editor/fonts/notosans-bold.ttf",
		valign = 0,
		halign = 1,
		font_size = 30,
		top_points = 10,
	}
end

local level_text = nil
local strokes_text = nil
local time_text = nil
local power_background = nil
local power_foreground = nil

local createHUD = function()
	hud_canvas = ui.canvas { name = "hud_canvas" }
	level_text = ui.text {
		text = "Level: " .. current_level,
		font = "engine/editor/fonts/notosans-bold.ttf",
		font_size = 72,
		valign = 0,
		halign = 0,
		left_points = 10,
		top_points = 10,
	}
	level_text.parent = hud_canvas
	strokes_text = ui.text {
		text = "Strokes: " .. strokes,
		font = "engine/editor/fonts/notosans-bold.ttf",
		font_size = 72,
		valign = 0,
		halign = 0,
		left_points = 10,
		top_points = 100,
	}
	strokes_text.parent = hud_canvas
	time_text = ui.text {
		text = "Time: 0.00",
		font = "engine/editor/fonts/notosans-bold.ttf",
		font_size = 72,
		valign = 0,
		halign = 0,
		left_points = 10,
		top_points = 190,
	}
	time_text.parent = hud_canvas
	power_background = ui.image {
		sprite = "ui/Blue/Default/button_rectangle_depth_flat.spr",
		left_relative = 0.5,
		left_points = -100,
		right_relative = 0.5,
		right_points = 100,
		bottom_relative = 1.0,
		bottom_points = 0,
		top_relative = 1.0,
		top_points = -30,
		name = "power_background"
	}
	power_background.parent = hud_canvas
	power_foreground = ui.image {
		--sprite = "ui/Blue/Default/button_rectangle_depth_flat.spr",
		left_relative = 0,
		right_relative = 0,
		bottom_relative = 0,
		top_relative = 1,
		name = "power_foreground"
	}
	power_foreground.parent = power_background
end

function start()
	loadLevel(1)
	ui.setWorld(this.world)
	canvas = ui.canvas {
		name = "gui canvas",
		ui_window {
			ui_window_label "Lunex Minigolf",
			
			ui.button {
				sprite = "ui/Blue/Default/button_rectangle_depth_gloss.spr",
				ui.center,
				left_points = -100,
				right_points = 100,
				top_points = -20,
				bottom_points = 20,
				text = "Start game",
				font = "engine/editor/fonts/notosans-bold.ttf",
				valign = 1,
				halign = 1,
				font_size = 30,
				on_click = function()
					canvas:destroy()
					ui_enabled = false
					this.world:getModule("gui"):getSystem():enableCursor(false)
				end
			}
		}
	}
	enableUI()
end

local gameFinished = function()
	ui.setWorld(this.world)
	canvas = ui.canvas {
		ui_window {
			ui_window_label "Game Complete!",
			
			ui.button {
				sprite = "ui/Blue/Default/button_rectangle_depth_gloss.spr",
				ui.center,
				left_points = -100,
				right_points = 100,
				top_points = -20,
				bottom_points = 20,
				text = "Play Again",
				font = "engine/editor/fonts/notosans-bold.ttf",
				valign = 1,
				halign = 1,
				font_size = 30,
				on_click = function()
					if hud_canvas then hud_canvas:destroy() end
					this.world:destroyPartition(level_partition)
					club = nil
					ball = nil
					current_level = 1
					strokes = 0
					game_time = 0
					loadLevel(1)
					canvas:destroy()
					disableUI()
				end
			}
		}
	}
	enableUI()
end

local nextLevel = function()
	if hud_canvas then hud_canvas:destroy() end
	this.world:destroyPartition(level_partition)
	club = nil
	ball = nil
	current_level += 1
	strokes = 0
	game_time = 0
	loadLevel(current_level)
end


local levelFinished = function()
	if current_level >= 4 then
		gameFinished()
		return
	end
	
	ui.setWorld(this.world)
	canvas = ui.canvas {
		ui_window {
			ui_window_label "Lunex Minigolf",
			
			ui.button {
				sprite = "ui/Blue/Default/button_rectangle_depth_gloss.spr",
				ui.center,
				left_points = -100,
				right_points = 100,
				top_points = -20,
				bottom_points = 20,
				text = "Next level",
				font = "engine/editor/fonts/notosans-bold.ttf",
				valign = 1,
				halign = 1,
				font_size = 30,
				on_click = function()
					nextLevel()
				end
			}
		}
	}
	enableUI()
end

function onLevelLoaded()
	coro.run(function()
		while LumixAPI.hasFilesystemWork() do
			coroutine.yield()
		end

		if current_level > 1 then
			ui_enabled = false
			this.world:getModule("gui"):getSystem():enableCursor(false)
			canvas:destroy()
			disableUI()
		end

		camera = this.world:findEntityByName(Lumix.Entity.NULL, "camera")
		local start_point = this.world:findEntityByName(Lumix.Entity.NULL, "start_point")
		if start_point == nil then
			LumixAPI.logError("start point not found")
		end
		hole_marker = this.world:findEntityByName(Lumix.Entity.NULL, "hole_marker")
		if hole_marker == nil then
			LumixAPI.logError("hole marker not found1")
		end
		ball = this.world:createEntityEx {
			position = start_point.position,
			jolt_body = {
				dynamic_type = 2,
				layer = 1,
				linear_damping = 0.75,
				angular_damping = 0.75,
				friction = 0.5
			},
			jolt_sphere = { radius = 0.035 },
			model_instance = { source = "models/ball_blue.fbx" },
		}
		ball.jolt_body:init()
		club = this.world:createEntityEx {
			position = start_point.position,
			model_instance = { source = "models/club_blue.fbx", enabled = false }
		}
		this.world:setActivePartition(0)
		createHUD()
		return false
	end)
end

function update(td)
	if club == nil then return end

	game_time = game_time + td

	is_ball_moving = ball.jolt_body.active

	local dist_sq = lmath.distSquared(ball.position, hole_marker.position)
	--ImGui.Text(`dist eq {dist_sq} <? {0.06 * 0.06}`)
	if not ui_enabled and not is_ball_moving and dist_sq < 0.06 * 0.06 then
		levelFinished()
	end

	local yaw_rad = yaw * SENSITIVITY
	local dirx = math.sin(yaw_rad)
	local dirz = math.cos(yaw_rad)
	local bp = ball.position
	local yaw_quat = lmath.makeQuatFromYaw(yaw_rad + 3.14159265 * 0.5)

	if not is_ball_moving then
		-- club position
	
		local offset = 0.1
	
		local cx = bp[1] - dirx * offset
		local cy = bp[2] + 0.85
		local cz = bp[3] - dirz * offset
		club.position = {cx, cy, cz}
	
		-- club rotation
		local swing_axis = {-dirz, 0, dirx} -- axis perpendicular to forward (dirx,0,dirz) and up (0,1,0)
		local swing_quat = lmath.makeQuatAxisAngle(swing_axis, -swing_pitch)
		club.rotation = lmath.mulQuat(swing_quat, yaw_quat)

		-- show club when possible to play
		if not ui_enabled then
			club.model_instance.enabled = true
		end
	end

	if is_ball_moving then
		club.model_instance.enabled = false
	end

	if is_down and not is_ball_moving then
		swing_pitch += td * 0.3
		if swing_pitch > 1 then swing_pitch = 1 end
	end

	local camera_quat = lmath.makeQuatFromYaw(yaw_rad + math.pi)
	local cam_pitch_axis = {dirz, 0, -dirx}
	local cam_pitch_quat = lmath.makeQuatAxisAngle(cam_pitch_axis, 0.5)
	camera_quat = lmath.mulQuat(cam_pitch_quat, camera_quat)

	camera.position = {
		bp[1] - dirx * 2,
		bp[2] + 1,
		bp[3] - dirz * 2
	}
	camera.rotation = camera_quat

	if level_text then level_text.gui_text.text = "Level: " .. current_level end
	if strokes_text then strokes_text.gui_text.text = "Strokes: " .. strokes end
	if time_text then time_text.gui_text.text = string.format("Time: %.2f", game_time) end
	if power_foreground then power_foreground.gui_rect.right_points = 200 * swing_pitch end
end

function onInputEvent(event : InputEvent)
	if ui_enabled then return end

	if event.type == "axis" and event.device.type == "mouse" then
		yaw += event.x
	end

	if event.type == "button" then 
		if event.device.type == "mouse" and event.key_id == 0 then
			if event.down then
				is_down = true
			else
				is_down = false
				impuluse_to_add = swing_pitch
				strokes = strokes + 1
				coro.run(function()
					interpolateSwingPitch(swing_pitch, 0, 1.2)
					return false
				end)
			end
		end
	end
end
