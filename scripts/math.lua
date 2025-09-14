local m = {}

m.dot = function(a, b)
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

m.mulQuat = function(a, b)
	return {
		a[4] * b[1] + b[4] * a[1] + a[2] * b[3] - b[2] * a[3],
		a[4] * b[2] + b[4] * a[2] + a[3] * b[1] - b[3] * a[1],
		a[4] * b[3] + b[4] * a[3] + a[1] * b[2] - b[1] * a[2],
		a[4] * b[4] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3]
	}
end

m.makeQuatAxisAngle = function(axis, angle)
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

m.makeQuatFromYaw = function(yaw)
	local syaw = math.sin(yaw * 0.5)
	local cyaw = math.cos(yaw * 0.5)
	return {0, syaw, 0, cyaw }
end

m.makeQuatFromPitch = function(pitch)
	local spitch = math.sin(pitch * 0.5)
	local cpitch = math.cos(pitch * 0.5)
	return {-spitch, 0, 0, cpitch}
end

m.yawToDir = function(yaw)
	return {math.sin(yaw), 0, math.cos(yaw)}
end

m.mulVec3Num = function(v, f)
	return {v[1] * f, v[2] * f, v[3] * f}
end

m.addVec3 = function(a, b)
	return {a[1] + b[1], a[2] + b[2], a[3] + b[3]}
end

m.subVec3 = function(a, b)
	return {a[1] - b[1], a[2] - b[2], a[3] - b[3]}
end

m.mulVec3 = function(a, f)
	return {a[1] * f, a[2] * f, a[3] * f}
end

m.distSquared = function(a, b)
	local xd = a[1] - b[1]
	local yd = a[2] - b[2]
	local zd = a[3] - b[3]
	
	return xd * xd + yd * yd + zd * zd
end

m.distXZSquared = function(a, b)
	local xd = a[1] - b[1]
	local zd = a[3] - b[3]
	
	return xd * xd + zd * zd
end

m.distSquared = function(a, b)
	local xd = a[1] - b[1]
	local yd = a[2] - b[2]
	local zd = a[3] - b[3]
	
	return xd * xd + yd * yd + zd * zd
end

m.cross = function(a, b)
	return {a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1]}
end

m.transformVec3 = function(rot_quat, pos)
	local qvec = {rot_quat[1], rot_quat[2], rot_quat[3] }
	local uv = m.cross(qvec, pos)
	local uuv = m.cross(qvec, uv)
	uv = m.mulVec3(uv, 2.0 * rot_quat[4])
	uuv = m.mulVec3Num(uuv, 2.0)

	return m.addVec3(pos, m.addVec3(uv, uuv));
end

return m
