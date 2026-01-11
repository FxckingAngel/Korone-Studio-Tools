--[[
	Client <-> Server Bridge Module
	
	Facilitates communication between client and server
	for command execution and data retrieval
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
	local Bridge = {}
	
	local remotes = {}
	local pendingRequests = {}
	local requestId = 0
	local outputConnections = {}
	
	Bridge.CreateRemote = function(name,remoteType)
		if remotes[name] then return remotes[name] end
		
		local folder = game:FindFirstChild("DEX_Bridge") or Instance.new("Folder",game)
		folder.Name = "DEX_Bridge"
		
		local remote
		if remoteType == "Function" then
			remote = Instance.new("RemoteFunction",folder)
		else
			remote = Instance.new("RemoteEvent",folder)
		end
		remote.Name = name
		
		remotes[name] = remote
		return remote
	end
	
	Bridge.ExecuteOnServer = function(code,...)
		local remote = Bridge.CreateRemote("ExecuteCode","Function")
		requestId = requestId + 1
		local id = requestId
		
		local s,result = pcall(function()
			return remote:InvokeServer({
				code = code,
				args = {...},
				requestId = id
			})
		end)
		
		return s, result
	end
	
	Bridge.GetServerData = function(dataType,...)
		local remote = Bridge.CreateRemote("GetData","Function")
		requestId = requestId + 1
		
		local s,result = pcall(function()
			return remote:InvokeServer({
				type = dataType,
				args = {...},
				requestId = requestId
			})
		end)
		
		return s, result
	end
	
	Bridge.SendCommand = function(cmd,...)
		local remote = Bridge.CreateRemote("Command","Event")
		local args = {...}
		
		pcall(function()
			remote:FireServer({
				command = cmd,
				args = args,
				timestamp = tick()
			})
		end)
	end
	
	Bridge.GetRemoteOutput = function()
		local remote = Bridge.CreateRemote("Output","Event")
		local output = {}
		local con
		
		-- Handle OnClientEvent properly
		if remote:IsA("RemoteEvent") then
			con = remote.OnClientEvent:Connect(function(message,level)
				output[#output+1] = {
					message = message,
					level = level or "log",
					timestamp = tick()
				}
			end)
		end
		
		return {
			GetMessages = function(self,levels)
				local result = {}
				for i = 1,#output do
					if not levels or levels[output[i].level] then
						result[#result+1] = output[i]
					end
				end
				return result
			end,
			Clear = function(self) table.clear(output) end,
			Disconnect = function(self) 
				if con then con:Disconnect() end
			end
		}
	end
	
	Bridge.ListPlayers = function()
		local s,players = Bridge.GetServerData("players")
		if s and players then
			return players
		end
		return {}
	end
	
	Bridge.GetPlayerData = function(userId)
		local s,data = Bridge.GetServerData("playerData",userId)
		if s and data then
			return data
		end
		return nil
	end
	
	Bridge.GetPlayerCharacter = function(userId)
		local s,charData = Bridge.GetServerData("characterData",userId)
		if s and charData then
			return charData
		end
		return nil
	end
	
	Bridge.GetHumanoidDescription = function(userId)
		local s,descData = Bridge.GetServerData("humanoidDescription",userId)
		if s and descData then
			-- Reconstruct HumanoidDescription from data
			local desc = Instance.new("HumanoidDescription")
			for key,val in pairs(descData) do
				pcall(function()
					desc[key] = val
				end)
			end
			return desc
		end
		return nil
	end
	
	Bridge.KickPlayer = function(userId,reason)
		Bridge.SendCommand("kickPlayer",userId,reason or "Kicked by DEX")
	end
	
	Bridge.BanPlayer = function(userId,reason)
		Bridge.SendCommand("banPlayer",userId,reason or "Banned by DEX")
	end
	
	Bridge.GetGameStats = function()
		local s,stats = Bridge.GetServerData("gameStats")
		if s and stats then
			return stats
		end
		return nil
	end
	
	Bridge.RestartServer = function()
		Bridge.SendCommand("restartServer")
	end
	
	Bridge.TeleportPlayer = function(userId,position)
		Bridge.SendCommand("teleportPlayer",userId,position)
	end
	
	Bridge.SetPlayerData = function(userId,key,value)
		Bridge.SendCommand("setPlayerData",userId,key,value)
	end
	
	return Bridge
end

if gethsfuncs then
	_G.moduleData = {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
else
	return {InitDeps = initDeps, InitAfterMain = initAfterMain, Main = main}
end
