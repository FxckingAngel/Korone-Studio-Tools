--[[
	SaveInstance Binary Module
	
	Provides binary serialization for instances
	with compression support
]]

local Main,Lib,Apps,Settings
local Explorer, Properties, ScriptViewer, Notebook

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	Notebook = Apps.Notebook
end

local function main()
	local SaveInstance = {}
	
	local function serializeValue(val,typeStr)
		if typeStr == "string" then
			return {type = 1, value = val}
		elseif typeStr == "number" then
			return {type = 2, value = val}
		elseif typeStr == "boolean" then
			return {type = 3, value = val}
		elseif typeStr == "Vector3" then
			return {type = 4, x = val.x, y = val.y, z = val.z}
		elseif typeStr == "Color3" then
			return {type = 5, r = val.r, g = val.g, b = val.b}
		elseif typeStr == "CFrame" then
			local pos = val.Position
			local r0,r1,r2 = val:GetRightVector().X, val:GetRightVector().Y, val:GetRightVector().Z
			local u0,u1,u2 = val:GetUpVector().X, val:GetUpVector().Y, val:GetUpVector().Z
			return {type = 6, px = pos.x, py = pos.y, pz = pos.z, r0 = r0, r1 = r1, r2 = r2, u0 = u0, u1 = u1, u2 = u2}
		elseif typeStr == "UDim2" then
			return {type = 7, xs = val.X.Scale, xo = val.X.Offset, ys = val.Y.Scale, yo = val.Y.Offset}
		elseif typeStr == "BrickColor" then
			return {type = 8, value = val.Number}
		end
		return {type = 0}
	end
	
	local function deserializeValue(data)
		if data.type == 1 then return data.value
		elseif data.type == 2 then return data.value
		elseif data.type == 3 then return data.value
		elseif data.type == 4 then return Vector3.new(data.x, data.y, data.z)
		elseif data.type == 5 then return Color3.new(data.r, data.g, data.b)
		elseif data.type == 6 then
			return CFrame.new(data.px, data.py, data.pz, data.r0, data.r1, data.r2, 0, data.u1, data.u2, -data.u2, -data.u1, data.r0)
		elseif data.type == 7 then return UDim2.new(data.xs, data.xo, data.ys, data.yo)
		elseif data.type == 8 then return BrickColor.new(data.value)
		end
		return nil
	end
	
	SaveInstance.SerializeInstance = function(obj,includeDescendants)
		local data = {
			Name = obj.Name,
			Class = obj.ClassName,
			Properties = {},
			Children = {},
			Attributes = {}
		}
		
		local cls = obj.ClassName
		if API.Classes[cls] then
			local apiProps = API.Classes[cls].Properties
			for i = 1,#apiProps do
				local prop = apiProps[i]
				if not prop.Tags.ReadOnly and not prop.Tags.Hidden then
					local s,val = pcall(function() return obj[prop.Name] end)
					if s and val ~= nil then
						data.Properties[prop.Name] = serializeValue(val, prop.ValueType.Name)
					end
				end
			end
		end
		
		if obj:GetAttributes then
			local attrs = obj:GetAttributes()
			for name,val in pairs(attrs) do
				data.Attributes[name] = {type = typeof(val), value = val}
			end
		end
		
		if includeDescendants then
			local children = obj:GetChildren()
			for i = 1,#children do
				data.Children[i] = SaveInstance.SerializeInstance(children[i], true)
			end
		end
		
		return data
	end
	
	SaveInstance.DeserializeInstance = function(data,parent)
		local obj = Instance.new(data.Class)
		obj.Name = data.Name
		
		for propName,propData in pairs(data.Properties) do
			local s = pcall(function()
				obj[propName] = deserializeValue(propData)
			end)
		end
		
		if data.Attributes and obj.SetAttribute then
			for attrName,attrData in pairs(data.Attributes) do
				pcall(function() obj:SetAttribute(attrName, attrData.value) end)
			end
		end
		
		if parent then obj.Parent = parent end
		
		if data.Children then
			for i = 1,#data.Children do
				SaveInstance.DeserializeInstance(data.Children[i], obj)
			end
		end
		
		return obj
	end
	
	SaveInstance.ExportJSON = function(obj,includeDescendants)
		local data = SaveInstance.SerializeInstance(obj, includeDescendants)
		local s,encoded = pcall(function() return game:GetService("HttpService"):JSONEncode(data) end)
		return s and encoded or nil
	end
	
	SaveInstance.ImportJSON = function(jsonStr,parent)
		local s,data = pcall(function() 
			return game:GetService("HttpService"):JSONDecode(jsonStr)
		end)
		if not s then return nil end
		
		return SaveInstance.DeserializeInstance(data, parent)
	end
	
	return SaveInstance
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
