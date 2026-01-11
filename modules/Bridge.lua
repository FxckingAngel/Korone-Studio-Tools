--[[
	Client <-> Server Bridge Module
	
	Facilitates communication between client and server
	for command execution and data retrieval
]]

local Main, Lib, Apps, Settings
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
	local Bridge = {}
	
	local remotes = {}
	local pendingRequests = {}
	local requestId = 0
	local outputConnections = {}
	
	-- List of safe HumanoidDescription properties
	local HUMANOID_DESC_PROPERTIES = {
		-- Accessories
		"BackAccessory",
		"FaceAccessory", 
		"FrontAccessory",
		"HairAccessory",
		"HatAccessory",
		"NeckAccessory",
		"ShouldersAccessory",
		"WaistAccessory",
		
		-- Body parts
		"Face",
		"Head",
		"LeftArm",
		"LeftLeg",
		"RightArm",
		"RightLeg",
		"Torso",
		
		-- Clothing
		"GraphicTShirt",
		"Pants",
		"Shirt",
		
		-- Animations
		"ClimbAnimation",
		"FallAnimation",
		"IdleAnimation",
		"JumpAnimation",
		"MoodAnimation",
		"RunAnimation",
		"SwimAnimation",
		"WalkAnimation",
		
		-- Scales
		"BodyTypeScale",
		"DepthScale",
		"HeadScale",
		"HeightScale",
		"ProportionScale",
		"WidthScale"
	}
	
	-- Color properties that need special handling
	local HUMANOID_DESC_COLORS = {
		"HeadColor",
		"LeftArmColor",
		"LeftLegColor",
		"RightArmColor",
		"RightLegColor",
		"TorsoColor"
	}
	
	-- Helper function to convert table to Color3
	local function tableToColor3(t)
		if type(t) == "table" and t.R and t.G and t.B then
			return Color3.new(t.R, t.G, t.B)
		elseif typeof(t) == "Color3" then
			return t
		elseif typeof(t) == "BrickColor" then
			return t.Color
		end
		return nil
	end
	
	-- Helper function to convert Color3 to table
	local function color3ToTable(color)
		if typeof(color) == "Color3" then
			return {R = color.R, G = color.G, B = color.B}
		elseif typeof(color) == "BrickColor" then
			return {R = color.Color.R, G = color.Color.G, B = color.Color.B}
		end
		return nil
	end
	
	Bridge.CreateRemote = function(name, remoteType)
		if remotes[name] then return remotes[name] end
		
		local folder = game:FindFirstChild("DEX_Bridge")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "DEX_Bridge"
			folder.Parent = game
		end
		
		local remote
		if remoteType == "Function" then
			remote = Instance.new("RemoteFunction")
		else
			remote = Instance.new("RemoteEvent")
		end
		remote.Name = name
		remote.Parent = folder
		
		remotes[name] = remote
		return remote
	end
	
	Bridge.GetRemote = function(name)
		if remotes[name] then return remotes[name] end
		
		local folder = game:FindFirstChild("DEX_Bridge")
		if folder then
			local remote = folder:FindFirstChild(name)
			if remote then
				remotes[name] = remote
				return remote
			end
		end
		return nil
	end
	
	Bridge.ExecuteOnServer = function(code, ...)
		local remote = Bridge.CreateRemote("ExecuteCode", "Function")
		requestId = requestId + 1
		local id = requestId
		
		local s, result = pcall(function()
			return remote:InvokeServer({
				code = code,
				args = {...},
				requestId = id
			})
		end)
		
		if not s then
			warn("[Bridge] ExecuteOnServer failed:", result)
		end
		
		return s, result
	end
	
	Bridge.GetServerData = function(dataType, ...)
		local remote = Bridge.CreateRemote("GetData", "Function")
		requestId = requestId + 1
		
		local s, result = pcall(function()
			return remote:InvokeServer({
				type = dataType,
				args = {...},
				requestId = requestId
			})
		end)
		
		if not s then
			warn("[Bridge] GetServerData failed for type '" .. tostring(dataType) .. "':", result)
		end
		
		return s, result
	end
	
	Bridge.SendCommand = function(cmd, ...)
		local remote = Bridge.CreateRemote("Command", "Event")
		local args = {...}
		
		local s, err = pcall(function()
			remote:FireServer({
				command = cmd,
				args = args,
				timestamp = tick()
			})
		end)
		
		if not s then
			warn("[Bridge] SendCommand failed for '" .. tostring(cmd) .. "':", err)
		end
		
		return s
	end
	
	Bridge.GetRemoteOutput = function()
		local remote = Bridge.CreateRemote("Output", "Event")
		local output = {}
		local con
		
		if remote:IsA("RemoteEvent") then
			con = remote.OnClientEvent:Connect(function(message, level)
				table.insert(output, {
					message = message,
					level = level or "log",
					timestamp = tick()
				})
			end)
		end
		
		return {
			GetMessages = function(self, levels)
				local result = {}
				for i = 1, #output do
					if not levels or levels[output[i].level] then
						table.insert(result, output[i])
					end
				end
				return result
			end,
			
			GetLatest = function(self, count)
				count = count or 10
				local result = {}
				local startIdx = math.max(1, #output - count + 1)
				for i = startIdx, #output do
					table.insert(result, output[i])
				end
				return result
			end,
			
			Clear = function(self) 
				table.clear(output) 
			end,
			
			Disconnect = function(self) 
				if con then 
					con:Disconnect() 
					con = nil
				end
			end
		}
	end
	
	Bridge.ListPlayers = function()
		local s, players = Bridge.GetServerData("players")
		if s and players then
			return players
		end
		return {}
	end
	
	Bridge.GetPlayerData = function(userId)
		if not userId then
			warn("[Bridge] GetPlayerData: userId is required")
			return nil
		end
		
		local s, data = Bridge.GetServerData("playerData", userId)
		if s and data then
			return data
		end
		return nil
	end
	
	Bridge.GetPlayerCharacter = function(userId)
		if not userId then
			warn("[Bridge] GetPlayerCharacter: userId is required")
			return nil
		end
		
		local s, charData = Bridge.GetServerData("characterData", userId)
		if s and charData then
			return charData
		end
		return nil
	end
	
	Bridge.GetHumanoidDescription = function(userId)
		if not userId then
			warn("[Bridge] GetHumanoidDescription: userId is required")
			return nil
		end
		
		local s, descData = Bridge.GetServerData("humanoidDescription", userId)
		
		if not s then
			warn("[Bridge] GetHumanoidDescription: Request failed for userId", userId)
			return nil
		end
		
		if not descData then
			warn("[Bridge] GetHumanoidDescription: No data received for userId", userId)
			return nil
		end
		
		if type(descData) ~= "table" then
			warn("[Bridge] GetHumanoidDescription: Invalid data type received:", type(descData))
			return nil
		end
		
		-- Create new HumanoidDescription
		local desc = Instance.new("HumanoidDescription")
		local successCount = 0
		local failCount = 0
		
		-- Set basic properties
		for _, propName in ipairs(HUMANOID_DESC_PROPERTIES) do
			if descData[propName] ~= nil then
				local success, err = pcall(function()
					desc[propName] = descData[propName]
				end)
				
				if success then
					successCount = successCount + 1
				else
					failCount = failCount + 1
					warn("[Bridge] Failed to set HumanoidDescription." .. propName .. ":", err)
				end
			end
		end
		
		-- Set color properties (need conversion from table)
		for _, colorProp in ipairs(HUMANOID_DESC_COLORS) do
			if descData[colorProp] ~= nil then
				local success, err = pcall(function()
					local color = tableToColor3(descData[colorProp])
					if color then
						desc[colorProp] = color
					end
				end)
				
				if success then
					successCount = successCount + 1
				else
					failCount = failCount + 1
					warn("[Bridge] Failed to set HumanoidDescription." .. colorProp .. ":", err)
				end
			end
		end
		
		-- Handle EquippedEmotes (requires SetEquippedEmotes method)
		if descData.EquippedEmotes and type(descData.EquippedEmotes) == "table" then
			local success, err = pcall(function()
				if #descData.EquippedEmotes > 0 then
					desc:SetEquippedEmotes(descData.EquippedEmotes)
				end
			end)
			
			if not success then
				warn("[Bridge] Failed to set EquippedEmotes:", err)
			end
		end
		
		-- Handle Accessories (requires SetAccessories method)
		if descData.Accessories and type(descData.Accessories) == "table" then
			local success, err = pcall(function()
				if #descData.Accessories > 0 then
					desc:SetAccessories(descData.Accessories, false)
				end
			end)
			
			if not success then
				warn("[Bridge] Failed to set Accessories:", err)
			end
		end
		
		-- Handle LayeredClothing accessories
		if descData.LayeredAccessories and type(descData.LayeredAccessories) == "table" then
			local success, err = pcall(function()
				if #descData.LayeredAccessories > 0 then
					desc:SetAccessories(descData.LayeredAccessories, true)
				end
			end)
			
			if not success then
				warn("[Bridge] Failed to set LayeredAccessories:", err)
			end
		end
		
		return desc
	end
	
	-- Alternative method using Players service directly (client-side)
	Bridge.GetHumanoidDescriptionFromUserId = function(userId)
		if not userId then
			warn("[Bridge] GetHumanoidDescriptionFromUserId: userId is required")
			return nil
		end
		
		local Players = game:GetService("Players")
		
		local success, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)
		
		if success then
			return result
		else
			warn("[Bridge] GetHumanoidDescriptionFromUserId failed:", result)
			return nil
		end
	end
	
	-- Get HumanoidDescription from a character model
	Bridge.GetHumanoidDescriptionFromCharacter = function(character)
		if not character then
			warn("[Bridge] GetHumanoidDescriptionFromCharacter: character is required")
			return nil
		end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("[Bridge] GetHumanoidDescriptionFromCharacter: No Humanoid found")
			return nil
		end
		
		local success, result = pcall(function()
			return humanoid:GetAppliedDescription()
		end)
		
		if success then
			return result
		else
			warn("[Bridge] GetHumanoidDescriptionFromCharacter failed:", result)
			return nil
		end
	end
	
	-- Serialize HumanoidDescription to table (for sending to server)
	Bridge.SerializeHumanoidDescription = function(desc)
		if not desc or not desc:IsA("HumanoidDescription") then
			warn("[Bridge] SerializeHumanoidDescription: Invalid HumanoidDescription")
			return nil
		end
		
		local data = {}
		
		-- Serialize basic properties
		for _, propName in ipairs(HUMANOID_DESC_PROPERTIES) do
			local success, value = pcall(function()
				return desc[propName]
			end)
			
			if success and value ~= nil then
				data[propName] = value
			end
		end
		
		-- Serialize color properties
		for _, colorProp in ipairs(HUMANOID_DESC_COLORS) do
			local success, value = pcall(function()
				return desc[colorProp]
			end)
			
			if success and value then
				data[colorProp] = color3ToTable(value)
			end
		end
		
		-- Serialize EquippedEmotes
		local emoteSuccess, emotes = pcall(function()
			return desc:GetEquippedEmotes()
		end)
		
		if emoteSuccess and emotes then
			data.EquippedEmotes = emotes
		end
		
		-- Serialize Accessories
		local accessorySuccess, accessories = pcall(function()
			return desc:GetAccessories(false)
		end)
		
		if accessorySuccess and accessories then
			data.Accessories = accessories
		end
		
		-- Serialize LayeredClothing Accessories
		local layeredSuccess, layered = pcall(function()
			return desc:GetAccessories(true)
		end)
		
		if layeredSuccess and layered then
			data.LayeredAccessories = layered
		end
		
		return data
	end
	
	Bridge.KickPlayer = function(userId, reason)
		if not userId then
			warn("[Bridge] KickPlayer: userId is required")
			return false
		end
		return Bridge.SendCommand("kickPlayer", userId, reason or "Kicked by DEX")
	end
	
	Bridge.BanPlayer = function(userId, reason, duration)
		if not userId then
			warn("[Bridge] BanPlayer: userId is required")
			return false
		end
		return Bridge.SendCommand("banPlayer", userId, reason or "Banned by DEX", duration)
	end
	
	Bridge.GetGameStats = function()
		local s, stats = Bridge.GetServerData("gameStats")
		if s and stats then
			return stats
		end
		return nil
	end
	
	Bridge.RestartServer = function()
		return Bridge.SendCommand("restartServer")
	end
	
	Bridge.TeleportPlayer = function(userId, position)
		if not userId then
			warn("[Bridge] TeleportPlayer: userId is required")
			return false
		end
		
		if not position then
			warn("[Bridge] TeleportPlayer: position is required")
			return false
		end
		
		-- Convert Vector3 to table if needed
		local posData = position
		if typeof(position) == "Vector3" then
			posData = {X = position.X, Y = position.Y, Z = position.Z}
		elseif typeof(position) == "CFrame" then
			posData = {
				X = position.Position.X, 
				Y = position.Position.Y, 
				Z = position.Position.Z
			}
		end
		
		return Bridge.SendCommand("teleportPlayer", userId, posData)
	end
	
	Bridge.SetPlayerData = function(userId, key, value)
		if not userId then
			warn("[Bridge] SetPlayerData: userId is required")
			return false
		end
		
		if not key then
			warn("[Bridge] SetPlayerData: key is required")
			return false
		end
		
		return Bridge.SendCommand("setPlayerData", userId, key, value)
	end
	
	-- Cleanup function
	Bridge.Cleanup = function()
		for _, remote in pairs(remotes) do
			pcall(function()
				remote:Destroy()
			end)
		end
		table.clear(remotes)
		table.clear(pendingRequests)
		
		local folder = game:FindFirstChild("DEX_Bridge")
		if folder then
			pcall(function()
				folder:Destroy()
			end)
		end
	end
	
	return Bridge
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
