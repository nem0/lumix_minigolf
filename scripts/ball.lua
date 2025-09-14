club = Lumix.Entity.NULL
hole_marker = Lumix.Entity.NULL
local finished = false
local is_down = false
local co = require "scripts/coroutine"
local lmath = require "scripts/math"

local SENSITIVITY = 0.001
local MAX_IMPULSE = 1.5
local UP_IMPULSE_FACTOR = 0.0
local yaw = 0
local is_ball_moving = false
local swing_pitch = 0
local impuluse_to_add = 0

function start()
end

local function addImpulse()
	if this.jolt_body then
		local yaw_rad = yaw * SENSITIVITY
		local dirx = math.sin(yaw_rad)
		local dirz = math.cos(yaw_rad)

		local amplitude = math.min(impuluse_to_add, 1) * MAX_IMPULSE
		local ix = dirx * amplitude
		local iy = UP_IMPULSE_FACTOR * amplitude
		local iz = dirz * amplitude

		this.jolt_body:addImpulse({ix, iy, iz})
	end
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
			addImpulse()
			impulsed = true
		end
		swing_pitch = start_val + (end_val - start_val) * t
		td = coroutine.yield()
		time = time + td
	end
end

function makeQuat(axis, angle)
	local x, y, z = axis[1], axis[2], axis[3]
	local len = math.sqrt(x * x + y * y + z * z)
	if len < 1e-8 then
		return {0, 0, 0, 1}
	end
	local inv = 1 / len
	x, y, z = x * inv, y * inv, z * inv
	local half = angle * 0.5
	local s = math.sin(half)
	local c = math.cos(half)
	return {x * s, y * s, z * s, c}
end

function update(td)
	if not finished and not is_ball_moving and lmath.distSquared(this.position, hole_marker.position) < 0.02 * 0.02 then
		levelFinished()
		finished = true
		return
	end
	
	if is_down and not is_ball_moving then
		swing_pitch += td * 1.5
	end

	local body = this.jolt_body
	if body then
		is_ball_moving = body.active
	end

	local yaw_rad = yaw * SENSITIVITY
	if club ~= Lumix.Entity.NULL and not is_ball_moving then

		local dirx = math.sin(yaw_rad)
		local dirz = math.cos(yaw_rad)

		local offset = 0.1

		local bp = this.position
		local cx = bp[1] - dirx * offset
		local cy = bp[2] + 0.85
		local cz = bp[3] - dirz * offset
		club.position = {cx, cy, cz}
		
	end
	local dirx = math.sin(yaw_rad)
	local dirz = math.cos(yaw_rad)
	local swing_axis = {-dirz, 0, dirx} -- axis perpendicular to forward (dirx,0,dirz) and up (0,1,0)
	local swing_quat = makeQuat(swing_axis, -swing_pitch)
	local yaw_quat = lmath.makeQuatFromYaw(yaw_rad + 3.14159265 * 0.5)
	club.rotation = lmath.mulQuat(swing_quat, yaw_quat)
end


function onInputEvent(event : InputEvent)
	if _G.ui_enabled then return end

	if event.type == "axis" and event.device.type == "mouse" then
		yaw += event.x
	end

	if event.type == "button" and event.device.type == "mouse" and event.key_id == 0 then
		if event.down then
			is_down = true
		else
			is_down = false
			impuluse_to_add = swing_pitch
			co.run(function()
				interpolateSwingPitch(swing_pitch, 0, 1.2)
				return false
			end)
		end
	end
end






