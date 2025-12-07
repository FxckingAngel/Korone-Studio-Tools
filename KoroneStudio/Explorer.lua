--[[
	Explorer App Module
	
	The main explorer interface
]]

-- Common Locals
local Main,Lib,Apps,Settings -- Main Containers
local Explorer, Properties, ScriptViewer, Notebook -- Major Apps
local API,RMD,env,service,plr,create,createSimple -- Main Locals


-- Korone Studio bridge: expose Dex Explorer to KS_Explorer.Toggle()
_G.KS_Explorer = _G.KS_Explorer or {}
function _G.KS_Explorer.Toggle()
	-- Use the Explorer app once initDeps has populated it
	if not Explorer or not Explorer.Window then
		warn("[KoroneStudio] Explorer app not ready yet")
		return
	end
	local win = Explorer.Window
	local isClosed = (win.Closed == nil and not win.Visible) or win.Closed
	if isClosed then
		-- Align on the right like Dex default; can tweak later
		win:Show({Align = "right", Pos = 1, Size = 0.5})
	else
		win:Close()
	end
end

local function initDeps(data)
	Main = data.Main
	Lib = data.Lib
	Apps = data.Apps
	Settings = data.Settings

	API = data.API
	RMD = data.RMD
	env = data.env
	service = data.service
	plr = data.plr
	create = data.create
	createSimple = data.createSimple
end

local function initAfterMain()
	Explorer = Apps.Explorer
	Properties = Apps.Properties
	ScriptViewer = Apps.ScriptViewer
	Notebook = Apps.Notebook
end

local function main()
	local Explorer = {}
	local nodes,tree,listEntries,explorerOrders,searchResults,specResults = {},{},{},{},{},{}
	local expanded
	local entryTemplate,treeFrame,toolBar,descendantAddedCon,descendantRemovingCon,itemChangedCon
	local ffa = game.FindFirstAncestorWhichIsA
	local getDescendants = game.GetDescendants
	local getTextSize = service.TextService.GetTextSize
	local updateDebounce,refreshDebounce = false,false
	local nilNode = {Obj = Instance.new("Folder")}
	local idCounter = 0
	local scrollV,scrollH,selection,clipboard
	local renameBox,renamingNode,searchFunc
	local sortingEnabled,autoUpdateSearch
	local table,math = table,math
	local nilMap,nilCons = {},{}
	local connectSignal = game.DescendantAdded.Connect
	local addObject,removeObject,moveObject = nil,nil,nil

	addObject = function(root)
		if nodes[root] then return end

		local isNil = false
		local rootParObj = ffa(root,"Instance")
		local par = nodes[rootParObj]

		-- Nil Handling
		if not par then
			if nilMap[root] then
				nilCons[root] = nilCons[root] or {
					connectSignal(root.ChildAdded,addObject),
					connectSignal(root.AncestryChanged,moveObject),
				}
				par = nilNode
				isNil = true
			else
				return
			end
		elseif nilMap[rootParObj] or par == nilNode then
			nilMap[root] = true
			nilCons[root] = nilCons[root] or {
				connectSignal(root.ChildAdded,addObject),
				connectSignal(root.AncestryChanged,moveObject),
			}
			isNil = true
		end

		local newNode = {Obj = root, Parent = par}
		nodes[root] = newNode

		-- Automatic sorting if expanded
		if sortingEnabled and expanded[par] and par.Sorted then
			local left,right = 1,#par
			local floor = math.floor
			local sorter = Explorer.NodeSorter
			local pos = (right == 0 and 1)

			if not pos then
				while true do
					if left >= right then
						if sorter(newNode,par[left]) then
							pos = left
						else
							pos = left+1
						end
						break
					end

					local mid = floor((left+right)/2)
					if sorter(newNode,par[mid]) then
						right = mid-1
					else
						left = mid+1
					end
				end
			end

			table.insert(par,pos,newNode)
		else
			par[#par+1] = newNode
			par.Sorted = nil
		end

		local insts = getDescendants(root)
		for i = 1,#insts do
			local obj = insts[i]
			if nodes[obj] then continue end -- Deferred
			
			local par = nodes[ffa(obj,"Instance")]
			if not par then continue end
			local newNode = {Obj = obj, Parent = par}
			nodes[obj] = newNode
			par[#par+1] = newNode

			-- Nil Handling
			if isNil then
				nilMap[obj] = true
				nilCons[obj] = nilCons[obj] or {
					connectSignal(obj.ChildAdded,addObject),
					connectSignal(obj.AncestryChanged,moveObject),
				}
			end
		end

		if searchFunc and autoUpdateSearch then
			searchFunc({newNode})
		end

		if not updateDebounce and Explorer.IsNodeVisible(par) then
			if expanded[par] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	removeObject = function(root)
		local node = nodes[root]
		if not node then return end

		-- Nil Handling
		if nilMap[node.Obj] then
			moveObject(node.Obj)
			return
		end

		local par = node.Parent
		if par then
			par.HasDel = true
		end

		local function recur(root)
			for i = 1,#root do
				local node = root[i]
				if not node.Del then
					nodes[node.Obj] = nil
					if #node > 0 then recur(node) end
				end
			end
		end
		recur(node)
		node.Del = true
		nodes[root] = nil

		if par and not updateDebounce and Explorer.IsNodeVisible(par) then
			if expanded[par] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	moveObject = function(obj)
		local node = nodes[obj]
		if not node then return end

		local oldPar = node.Parent
		local newPar = nodes[ffa(obj,"Instance")]
		if oldPar == newPar then return end

		-- Nil Handling
		if not newPar then
			if nilMap[obj] then
				newPar = nilNode
			else
				return
			end
		elseif nilMap[newPar.Obj] or newPar == nilNode then
			nilMap[obj] = true
			nilCons[obj] = nilCons[obj] or {
				connectSignal(obj.ChildAdded,addObject),
				connectSignal(obj.AncestryChanged,moveObject),
			}
		end

		if oldPar then
			local parPos = table.find(oldPar,node)
			if parPos then table.remove(oldPar,parPos) end
		end

		node.Id = nil
		node.Parent = newPar

		if sortingEnabled and expanded[newPar] and newPar.Sorted then
			local left,right = 1,#newPar
			local floor = math.floor
			local sorter = Explorer.NodeSorter
			local pos = (right == 0 and 1)

			if not pos then
				while true do
					if left >= right then
						if sorter(node,newPar[left]) then
							pos = left
						else
							pos = left+1
						end
						break
					end

					local mid = floor((left+right)/2)
					if sorter(node,newPar[mid]) then
						right = mid-1
					else
						left = mid+1
					end
				end
			end

			table.insert(newPar,pos,node)
		else
			newPar[#newPar+1] = node
			newPar.Sorted = nil
		end

		if searchFunc and searchResults[node] then
			local currentNode = node.Parent
			while currentNode and (not searchResults[currentNode] or expanded[currentNode] == 0) do
				expanded[currentNode] = true
				searchResults[currentNode] = true
				currentNode = currentNode.Parent
			end
		end

		if not updateDebounce and (Explorer.IsNodeVisible(newPar) or Explorer.IsNodeVisible(oldPar)) then
			if expanded[newPar] or expanded[oldPar] then
				Explorer.PerformUpdate()
			elseif not refreshDebounce then
				Explorer.PerformRefresh()
			end
		end
	end

	Explorer.ViewWidth = 0
	Explorer.Index = 0
	Explorer.EntryIndent = 20
	Explorer.FreeWidth = 32
	Explorer.GuiElems = {}

	Explorer.InitRenameBox = function()
		renameBox = create({{1,"TextBox",{BackgroundColor3=Color3.new(0.17647059261799,0.17647059261799,0.17647059261799),BorderColor3=Color3.new(0.062745101749897,0.51764708757401,1),BorderMode=2,ClearTextOnFocus=false,Font=3,Name="RenameBox",PlaceholderColor3=Color3.new(0.69803923368454,0.69803923368454,0.69803923368454),Position=UDim2.new(0,26,0,2),Size=UDim2.new(0,200,0,16),Text="",TextColor3=Color3.new(1,1,1),TextSize=14,TextXAlignment=0,Visible=false,ZIndex=2}}})

		renameBox.Parent = Explorer.Window.GuiElems.Content.List

		renameBox.FocusLost:Connect(function()
			if not renamingNode then return end

			pcall(function() renamingNode.Obj.Name = renameBox.Text end)
			renamingNode = nil
			Explorer.Refresh()
		end)

		renameBox.Focused:Connect(function()
			renameBox.SelectionStart = 1
			renameBox.CursorPosition = #renameBox.Text + 1
		end)
	end

	Explorer.SetRenamingNode = function(node)
		renamingNode = node
		renameBox.Text = tostring(node.Obj)
		renameBox:CaptureFocus()
		Explorer.Refresh()
	end

	Explorer.SetSortingEnabled = function(val)
		sortingEnabled = val
		Settings.Explorer.Sorting = val
	end

	Explorer.UpdateView = function()
		local maxNodes = math.ceil(treeFrame.AbsoluteSize.Y / 20)
		local maxX = treeFrame.AbsoluteSize.X
		local totalWidth = Explorer.ViewWidth + Explorer.FreeWidth

		scrollV.VisibleSpace = maxNodes
		scrollV.TotalSpace = #tree + 1
		scrollH.VisibleSpace = maxX
		scrollH.TotalSpace = totalWidth

		scrollV.Gui.Visible = #tree + 1 > maxNodes
		scrollH.Gui.Visible = totalWidth > maxX

		local oldSize = treeFrame.Size
		treeFrame.Size = UDim2.new(1,(scrollV.Gui.Visible and -16 or 0),1,(scrollH.Gui.Visible and -39 or -23))
		if oldSize ~= treeFrame.Size then
			Explorer.UpdateView()
		else
			scrollV:Update()
			scrollH:Update()

			renameBox.Size = UDim2.new(0,maxX-100,0,16)

			if scrollV.Gui.Visible and scrollH.Gui.Visible then
				scrollV.Gui.Size = UDim2.new(0,16,1,-39)
				scrollH.Gui.Size = UDim2.new(1,-16,0,16)
				Explorer.Window.GuiElems.Content.ScrollCorner.Visible = true
			else
				scrollV.Gui.Size = UDim2.new(0,16,1,-23)
				scrollH.Gui.Size = UDim2.new(1,0,0,16)
				Explorer.Window.GuiElems.Content.ScrollCorner.Visible = false
			end

			Explorer.Index = scrollV.Index
		end
	end

	Explorer.NodeSorter = function(a,b)
		if a.Del or b.Del then return false end -- Ghost node

		local aClass = a.Class
		local bClass = b.Class
		if not aClass then aClass = a.Obj.ClassName a.Class = aClass end
		if not bClass then bClass = b.Obj.ClassName b.Class = bClass end

		local aOrder = explorerOrders[aClass]
		local bOrder = explorerOrders[bClass]
		if not aOrder then aOrder = RMD.Classes[aClass] and tonumber(RMD.Classes[aClass].ExplorerOrder) or 9999 explorerOrders[aClass] = aOrder end
		if not bOrder then bOrder = RMD.Classes[bClass] and tonumber(RMD.Classes[bClass].ExplorerOrder) or 9999 explorerOrders[bClass] = bOrder end

		if aOrder ~= bOrder then
			return aOrder < bOrder
		else
			local aName,bName = tostring(a.Obj),tostring(b.Obj)
			if aName ~= bName then
				return aName < bName
			elseif aClass ~= bClass then
				return aClass < bClass
			else
				local aId = a.Id if not aId then aId = idCounter idCounter = (idCounter+0.001)%999999999 a.Id = aId end
				local bId = b.Id if not bId then bId = idCounter idCounter = (idCounter+0.001)%999999999 b.Id = bId end
				return aId < bId
			end
		end
	end

	Explorer.Update = function()
		table.clear(tree)
		local maxNameWidth,maxDepth,count = 0,1,1
		local nameCache = {}
		local font = Enum.Font.SourceSans
		local size = Vector2.new(math.huge,20)
		local useNameWidth = Settings.Explorer.UseNameWidth
		local tSort = table.sort
		local sortFunc = Explorer.NodeSorter
		local isSearching = (expanded == Explorer.SearchExpanded)
		local textServ = service.TextService

		local function recur(root,depth)
			if depth > maxDepth then maxDepth = depth end
			depth = depth + 1
			if sortingEnabled and not root.Sorted then
				tSort(root,sortFunc)
				root.Sorted = true
			end
			for i = 1,#root do
				local n = root[i]

				if (isSearching and not searchResults[n]) or n.Del then continue end

				if useNameWidth then
					local nameWidth = n.NameWidth
					if not nameWidth then
						local objName = tostring(n.Obj)
						nameWidth = nameCache[objName]
						if not nameWidth then
							nameWidth = getTextSize(textServ,objName,14,font,size).X
							nameCache[objName] = nameWidth
						end
						n.NameWidth = nameWidth
					end
					if nameWidth > maxNameWidth then
						maxNameWidth = nameWidth
					end
				end

				tree[count] = n
				count = count + 1
				if expanded[n] and #n > 0 then
					recur(n,depth)
				end
			end
		end

		recur(nodes[game],1)

		-- Nil Instances
		if env.getnilinstances then
			if not (isSearching and not searchResults[nilNode]) then
				tree[count] = nilNode
				count = count + 1
				if expanded[nilNode] then
					recur(nilNode,2)
				end
			end
		end

		Explorer.MaxNameWidth = maxNameWidth
		Explorer.MaxDepth = maxDepth
		Explorer.ViewWidth = useNameWidth and Explorer.EntryIndent*maxDepth + maxNameWidth + 26 or Explorer.EntryIndent*maxDepth + 226
		Explorer.UpdateView()
	end

	Explorer.StartDrag = function(offX,offY)
		if Explorer.Dragging then return end
		Explorer.Dragging = true

		local dragTree = treeFrame:Clone()
		dragTree:ClearAllChildren()

		for i,v in pairs(listEntries) do
			local node = tree[i + Explorer.Index]
			if node and selection.Map[node] then
				local clone = v:Clone()
				clone.Active = false
				clone.Indent.Expand.Visible = false
				clone.Parent = dragTree
			end
		end

		local newGui = Instance.new("ScreenGui")
		newGui.DisplayOrder = Main.DisplayOrders.Menu
		dragTree.Parent = newGui
		Lib.ShowGui(newGui)

		local dragOutline = create({
			{1,"Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,Name="DragSelect",Size=UDim2.new(1,0,1,0),}},
			{2,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Size=UDim2.new(1,0,0,1),ZIndex=2,}},
			{3,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),ZIndex=2,}},
			{4,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Size=UDim2.new(0,1,1,0),ZIndex=2,}},
			{5,"Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Name="Line",Parent={1},Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0),ZIndex=2,}},
		})
		dragOutline.Parent = treeFrame


		local mouse = Main.Mouse or service.Players.LocalPlayer:GetMouse()
		local function move()
			local posX = mouse.X - offX
			local posY = mouse.Y - offY
			dragTree.Position = UDim2.new(0,posX,0,posY)

			for i = 1,#listEntries do
				local entry = listEntries[i]
				if Lib.CheckMouseInGui(entry) then
					dragOutline.Position = UDim2.new(0,entry.Indent.Position.X.Offset-scrollH.Index,0,entry.Position.Y.Offset)
					dragOutline.Size = UDim2.new(0,entry.Size.X.Offset-entry.Indent.Position.X.Offset,0,20)
					dragOutline.Visible = true
					return
				end
			end
			dragOutline.Visible = false
		end
		move()

		local input = service.UserInputService
		local mouseEvent,releaseEvent

		mouseEvent = input.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				move()
			end
		end)

		releaseEvent = input.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				releaseEvent:Disconnect()
				mouseEvent:Disconnect()
				newGui:Destroy()
				dragOutline:Destroy()
				Explorer.Dragging = false

				for i = 1,#listEntries do
					if Lib.CheckMouseInGui(listEntries[i]) then
						local node = tree[i + Explorer.Index]
						if node then
							if selection.Map[node] then return end
							local newPar = node.Obj
							local sList = selection.List
							for i = 1,#sList do
								local n = sList[i]
								pcall(function() n.Obj.Parent = newPar end)
							end
							Explorer.ViewNode(sList[1])
						end
						break
					end
				end
			end
		end)
	end

	Explorer.NewListEntry = function(index)
		local newEntry = entryTemplate:Clone()
		newEntry.Position = UDim2.new(0,0,0,20*(index-1))

		local isRenaming = false

		newEntry.InputBegan:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or selection.Map[node] or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			newEntry.Indent.BackgroundColor3 = Settings.Theme.Button
			newEntry.Indent.BorderSizePixel = 0
			newEntry.Indent.BackgroundTransparency = 0
		end)

		newEntry.InputEnded:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or selection.Map[node] or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			newEntry.Indent.BackgroundTransparency = 1
		end)

		newEntry.MouseButton1Down:Connect(function()

		end)

		newEntry.MouseButton1Up:Connect(function()

		end)

		newEntry.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local releaseEvent,mouseEvent

				local mouse = Main.Mouse or plr:GetMouse()
				local startX = mouse.X
				local startY = mouse.Y

				local listOffsetX = startX - treeFrame.AbsolutePosition.X
				local listOffsetY = startY - treeFrame.AbsolutePosition.Y

				releaseEvent = game:GetService("UserInputService").InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						releaseEvent:Disconnect()
						mouseEvent:Disconnect()
					end
				end)

				mouseEvent = game:GetService("UserInputService").InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement then
						local deltaX = mouse.X - startX
						local deltaY = mouse.Y - startY
						local dist = math.sqrt(deltaX^2 + deltaY^2)

						if dist > 5 then
							releaseEvent:Disconnect()
							mouseEvent:Disconnect()
							isRenaming = false
							Explorer.StartDrag(listOffsetX,listOffsetY)
						end
					end
				end)
			end
		end)

		newEntry.MouseButton2Down:Connect(function()

		end)

		newEntry.Indent.Expand.InputBegan:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse_Over" or "Expand_Over")
		end)

		newEntry.Indent.Expand.InputEnded:Connect(function(input)
			local node = tree[index + Explorer.Index]
			if not node or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

			Explorer.MiscIcons:DisplayByKey(newEntry.Indent.Expand.Icon, expanded[node] and "Collapse" or "Expand")
		end)

		newEntry.Indent.Expand.MouseButton1Down:Connect(function()
			local node = tree[index + Explorer.Index]
			if not node or #node == 0 then return end

			expanded[node] = not expanded[node]
			Explorer.Update()
			Explorer.Refresh()
		end)

		newEntry.Parent = treeFrame
		return newEntry
	end

	Explorer.Refresh = function()
		local maxNodes = math.max(math.ceil((treeFrame.AbsoluteSize.Y) / 20),0)	
		local renameNodeVisible = false
		local isa = game.IsA

		for i = 1,maxNodes do
			local entry = listEntries[i]
			if not listEntries[i] then entry = Explorer.NewListEntry(i) listEntries[i] = entry Explorer.ClickSystem:Add(entry) end

			local node = tree[i + Explorer.Index]
			if node then
				local obj = node.Obj
				local depth = Explorer.EntryIndent*Explorer.NodeDepth(node)

				entry.Visible = true
				entry.Position = UDim2.new(0,-scrollH.Index,0,entry.Position.Y.Offset)
				entry.Size = UDim2.new(0,Explorer.ViewWidth,0,20)
				entry.Indent.EntryName.Text = tostring(node.Obj)
				entry.Indent.Position = UDim2.new(0,depth,0,0)
				entry.Indent.Size = UDim2.new(1,-depth,1,0)

				entry.Indent.EntryName.TextTruncate = (Settings.Explorer.UseNameWidth and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd)

				if (isa(obj,"LocalScript") or isa(obj,"Script")) and obj.Disabled then
					Explorer.MiscIcons:DisplayByKey(entry.Indent.Icon, isa(obj,"LocalScript") and "LocalScript_Disabled" or "Script_Disabled")
				else
					local rmdEntry = RMD.Classes[obj.ClassName]
					Explorer.ClassIcons:Display(entry.Indent.Icon, rmdEntry and rmdEntry.ExplorerImageIndex or 0)
				end

				if selection.Map[node] then
					entry.Indent.BackgroundColor3 = Settings.Theme.ListSelection
					entry.Indent.BorderSizePixel = 0
					entry.Indent.BackgroundTransparency = 0
				else
					if Lib.CheckMouseInGui(entry) then
						entry.Indent.BackgroundColor3 = Settings.Theme.Button
					else
						entry.Indent.BackgroundTransparency = 1
					end
				end

				if node == renamingNode then
					renameNodeVisible = true
					renameBox.Position = UDim2.new(0,depth+25-scrollH.Index,0,entry.Position.Y.Offset+2)
					renameBox.Visible = true
				end

				if #node > 0 and expanded[node] ~= 0 then
					if Lib.CheckMouseInGui(entry.Indent.Expand) then
						Explorer.MiscIcons:DisplayByKey(entry.Indent.Expand.Icon, expanded[node] and 
