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
local is_w_down = false
local is_s_down = false
local is_a_down = false
local is_d_down = false

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

local nextLevel = function()
	this.world:destroyPartition(level_partition)
	club = nil
	ball = nil
	current_level += 1
	loadLevel(current_level)
end


local levelFinished = function()
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
		return false
	end)
end

function update(td)
	if club == nil then return end

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
end

function onInputEvent(event : InputEvent)
	if ui_enabled then return end

	if event.type == "axis" and event.device.type == "mouse" then
		yaw += event.x
	end

	if event.type == "button" then 
		if event.device.type == "keyboard" then
			if event.key_id == string.byte("W") then
				is_w_down = event.down	
			end
			if event.key_id == string.byte("S") then
				is_s_down = event.down	
			end
			if event.key_id == string.byte("A") then
				is_a_down = event.down	
			end
			if event.key_id == string.byte("D") then
				is_d_down = event.down	
			end
		end
		if event.device.type == "mouse" and event.key_id == 0 then
			if event.down then
				is_down = true
				club.model_instance.enabled = true
			else
				is_down = false
				impuluse_to_add = swing_pitch
				coro.run(function()
					interpolateSwingPitch(swing_pitch, 0, 1.2)
					return false
				end)
			end
		end
	end
end
