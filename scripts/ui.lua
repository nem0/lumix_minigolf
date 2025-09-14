local m = {}

local world = nil

m.center = function(e)
	e.gui_rect.left_relative = 0.5
	e.gui_rect.right_relative = 0.5
	e.gui_rect.top_relative = 0.5
	e.gui_rect.bottom_relative = 0.5
end

m.setWorld = function(w)
	world = w
	world:createEntity()
end

m.canvas = function(def)
	local e = world:createEntity()
	e:createComponent("gui_canvas")
	e:createComponent("gui_rect")
	for k,v in pairs(def) do
		if k == "name" then
			e.name = v
		else
			v.parent = e 
		end
	end
	return e
end

local rect_properties = function(e, k,v)
	if k == "top_points" then
		e.gui_rect.top_points = v
		return true
	elseif k == "bottom_points" then
		e.gui_rect.bottom_points = v
		return true
	elseif k == "left_points" then
		e.gui_rect.left_points = v
		return true
	elseif k == "right_points" then
		e.gui_rect.right_points = v
		return true
	elseif type(v) == "function" then
		v(e)
		return true
	elseif k == "name" then
		e.name = v
		return true
	end
	return false
end

local text_properties = function(e, k, v)
	if k == "text" then
		e.gui_text.text = v
		return true
	elseif k == "font" then
		e.gui_text.font = v
		return true
	elseif k == "font_size" then
		e.gui_text.font_size = v
		return true
	elseif k == "valign" then
		e.gui_text.vertical_align = v
		return true
	elseif k == "halign" then
		e.gui_text.horizontal_align = v
		return true
	end
	return false
end

local function image_properties(e, k, v)
	if k == "sprite" then
		e.gui_image.sprite = v
		return true
	end
	return false
end

m.text = function(def)
	local e = world:createEntity()
	e:createComponent("gui_rect")
	e:createComponent("gui_text")
	for k,v in pairs(def) do
		if text_properties(e, k, v) then
		elseif rect_properties(e, k, v) then
		else
			v.parent = e 
		end
	end
	return e
end

m.button = function(def)
	local e = world:createEntity()
	e:createComponent("gui_rect")
	e:createComponent("gui_image")
	e:createComponent("gui_button")
	e:createComponent("gui_text")
	for k,v in pairs(def) do
		if k == "on_click" then
			e:createComponent("lua_script_inline");
			local env = LuaScript.getInlineEnvironment(e)
			env.onButtonClicked = v
		elseif text_properties(e, k, v) then
		elseif image_properties(e, k, v) then
		elseif rect_properties(e, k, v) then
		else
			v.parent = e 
		end
	end
	return e
end

m.image = function(def)
	local e = world:createEntity()
	e:createComponent("gui_rect")
	e:createComponent("gui_image")
	for k,v in pairs(def) do
		if k == "sprite" then
			e.gui_image.sprite = v
		elseif rect_properties(e, k, v) then
		else
			v.parent = e 
		end
	end
	return e
end

m.create = function()
end

return m
