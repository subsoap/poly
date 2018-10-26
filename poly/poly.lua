-- Should refactor to follow style guide https://github.com/kikito/middleclass/wiki/Naming-Conventions

-- don't ask me why some of this code is really retarded I am only porting it

local class = require("poly.middleclass")

-- We will require Orthographic and RenderCam using this to see if they are used in the project for rendering debug lines
local function prequire(m) 
	local ok, err = pcall(require, m) 
	if not ok then return nil, err end
	return err
end

local function dist(x1,y1,x2,y2) return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end


local orthographic = nil
local rendercam = nil -- todo later

local function init()
	if not orthographic then
		orthographic = prequire("orthographic.camera")
	end
	-- this works if ANY other script does require("orthographic.camera")
	-- due to the way Defold works with require and only including what's directly used
	-- although if it returns nil it's a good chance the project doesn't use Orthographic!
end

init()

local function filter_position(x, y, camera_id)
	-- maybe pass in actual vmath.vector3() here instead of raw x,y ?
	-- camera_id must be set when drawing
	if orthographic then -- force disable something is wrong?
		assert(camera_id, "Poly: You must set Orthographic camera_id when rendering!")
		-- if there are multiple cameras / split screen it will probably look weird
		-- probably no easy way to fix this without checking the screen view bounds?
		local world = vmath.vector3(x,y,0)
		local screen = orthographic.world_to_screen(camera_id, world)
		return screen.x, screen.y
	else
		return x, y
	end
end

local M = {}

---------------
-- PolyShape --
---------------

M.PolyShape = class("PolyShape")

function M.PolyShape:initialize()
	self.posx = 0
	self.posy = 0
	self.angle = 0
	self.width = 0
	self.height = 0
	self.collided = false
end

---------------
-- PolyPoint --
---------------

M.PolyPoint = class("PolyPoint", M.PolyShape)

function M.PolyPoint:initialize(x1, y1)
	M.PolyShape.initialize(self)
	self.rotatedx = 0
	self.rotatedy = 0
	self.posx = x1
	self.posy = y1
end

function M.PolyPoint:rotate_around(angle, cx, cy)
	local s = math.sin(angle)
	local c = math.cos(angle)
	
	local px = self.posx
	local py = self.posy
	
	local xnew = px * c - py * s
	local ynew = px * s + py * c
	
	self.rotatedx = xnew + cx
	self.rotatedy = ynew + cy
end

function M.PolyPoint:collide(shape2)
	-- todo line 26
	local result = false
	if shape2:isInstanceOf(M.Poly) then
		local p = shape2
		local angles = {}
		local backwards_angles = {}
		local angle_to_middle = {}
		local tolerance_angle = {}
		
		for i = 1, p.num_points do
			local t = vmath.vector3(p.points[i].rotatedx, p.points[i].rotatedy, 0)
			local t2 = vmath.vector3(p.points[p:next_point(i)].rotatedx, p.points[p:next_point(i)].rotatedy, 0)
			local t3 = vmath.vector3(t2.x - t.x, t2.y - t.y, 0)
			
			-- this is translation of original code
			-- but it should be refactored!
			local angle = math.atan2(-t3.y, t3.x)
			if angle < 0 then
				angle = angle + 360
			end
			
			angles[i] = angle

			local t22 = vmath.vector3(p.points[p:prev_point(i)].rotatedx, p.points[p:prev_point(i)].rotatedy, 0)
			local t33 = vmath.vector3(t22.x - t.x, t22.y - t.y, 0)

			local angle2 = math.atan2(-t33.y, t33.x)
			if angle2 < 0 then
				angle2 = angle2 + 360
			end

			backwards_angles[i] = angle2

			local t222 = vmath.vector3(self.posx, self.posy, 0)
			local t333 = vmath.vector3(t222.x - t.x, t222.y - t.y, 0)

			local angle3 = math.atan2(-t333.y, t333.x)
			if angle3 < 0 then
				angle3 = angle3 + 360
			end

			angle_to_middle[i] = angle3
			tolerance_angle[i] = math.abs(angles[i] - backwards_angles[i])
		end
		
		for i = 1, p.num_points do
			p.success[i] = false
		end

		result = true

		for i = 1, p.num_points do
			local t = vmath.vector3(p.points[i].rotatedx, p.points[i].rotatedy, 0)
			local t2 = vmath.vector3(self.rotatedx, self.rotatedy, 0)
			local t3 = vmath.vector3(t2.x - t.x, t2.y - t.y, 0)
			
			local direction = math.atan2(-t3.y, t3.x)
			if direction < 0 then
				direction = direction + 360
			end
			if (direction < angles[i] and direction > backwards_angles[i]) or (tolerance_angle[i]>179) then
				p.success[i] = true
			end
		end

		for i = 1, p.num_points do
		--	pprint(p.success[i])
			if p.success[i] == false then
				result = false
			end
		end
		
	end
	return result
end

function M.PolyPoint:render(camera_id)
	-- todo line 89
	-- msg.post("@render:", "draw_line", { start_point = vmath.vector3(100, 100, 0), end_point = vmath.vector3(101, 101, 0), color = vmath.vector4(1, 1, 1, 1) } )
	local fx, fy = filter_position(self.posx, self.posy, camera_id)
	msg.post("@render:", "draw_line", { start_point = vmath.vector3(fx, fy, 0), end_point = vmath.vector3(fx + 1, fy + 1, 0), color = vmath.vector4(1, 1, 1, 1) } )
end

---------------
--    Poly   --
---------------

M.Poly = class("Poly", M.PolyShape)

function M.Poly:initialize(x, y, ps)
	M.PolyShape.initialize(self)
	self.posx = x
	self.posy = y
	self.angle = 0
	self.num_points = 0
	self.points = {}
	self.success = {}
	for i=1, ps do
		self.success[i] = false
	end
	self.point_index = 1
end

function M.Poly:AddPoint(p)
	self.points[self.point_index] = p
	self.point_index = self.point_index + 1
	self.num_points = self.num_points + 1
end

function M.Poly:SetPoints()
	for i = 1, self.num_points do
		self.points[i]:rotate_around(self.angle, self.posx, self.posy)
	end
end

function M.Poly:render(camera_id)
	--todo line 127
	--print(self.num_points)
	for i = 1, self.num_points do
		--local p = self.points[i]
		self.points[i]:rotate_around(self.angle, self.posx, self.posy)
		self.points[self:next_point(i)]:rotate_around(self.angle, self.posx, self.posy)
		if self.success[i] == true then
		end
		msg.post("@render:", "draw_line", { start_point = vmath.vector3(self.points[i].rotatedx, self.points[i].rotatedy, 0), end_point = vmath.vector3(self.points[self:next_point(i)].rotatedx, self.points[self:next_point(i)].rotatedy, 0), color = vmath.vector4(1, 1, 1, 1) } )
		--pprint(vmath.vector3(self.points[i].rotatedx, self.points[i].rotatedy, 0))
	end
	msg.post("@render:", "draw_line", { start_point = vmath.vector3(self.posx-2, self.posy, 0), end_point = vmath.vector3(self.posx+2, self.posy, 0), color = vmath.vector4(1, 1, 1, 1) } )
end

function M.Poly:SetWidth(w)
	self.width = w
end

function M.Poly:UpdatePos(x, y)
	self.posx = x
	self.posy = y
end

function M.Poly:SetAngle(angle)
	self.angle = angle
end

function M.Poly:next_point(index)
	if index < self.num_points then
		return index + 1
	else
		return 1
	end
end

function M.Poly:prev_point(index)
	if index > 1 then
		return index - 1
	else 
		return self.num_points
	end
end

function M.Poly:collide(shape2)
	--todo line 183
	for i = 1, self.num_points do
		self.points[i]:rotate_around(self.angle, self.posx, self.posy)
	end
	local hit_this = false
	if shape2:isInstanceOf(M.PolyCircle) then
		local circ = shape2
		for i = 1, self.num_points do
			if dist(circ.posx, circ.posy, self.points[i].rotatedx, self.points[i].rotatedy) <= circ.width then
				hit_this = true
			end
		end
	end
	if shape2:isInstanceOf(M.Poly) then
		for i = 1, self.num_points do
			if self.points[i]:collide(shape2) == true then
				hit_this = true
			end
		end
	end
	if dist(shape2.posx, shape2.posy, self.posx, self.posy) <= shape2.width then
		hit_this = true
	end
	return hit_this
end

---------------
-- PolyCircle--
---------------

M.PolyCircle = class("PolyCircle", M.PolyShape)

function M.PolyCircle:initialize(x, y, width)
	M.PolyShape.initialize(self)
	self.posx = x
	self.posy = y
	self.width = width
end

return M