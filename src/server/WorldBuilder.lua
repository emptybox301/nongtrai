-- Dựng toàn bộ map bằng code: nền, đường, 5 quầy hàng, 5 nông trại (ruộng + ao),
-- và 1 Nhà Triển Lãm chung chia 5 khu.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local PLOT_POSITIONS = {
	Vector3.new(-90, 0, -80), Vector3.new(0, 0, -80), Vector3.new(90, 0, -80),
	Vector3.new(-90, 0, 80), Vector3.new(90, 0, 80),
}
local HALL_POSITION = Vector3.new(0, 0, 85)
local GRID_COLS, GRID_ROWS = 6, 4

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function surfaceText(target, face, text, textColor, bg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = target
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundColor3 = bg or Color3.fromRGB(60, 40, 25)
	lbl.BackgroundTransparency = bg and 0 or 1
	lbl.TextColor3 = textColor or Color3.new(1, 1, 1)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = text
	lbl.Parent = sg
	return lbl
end

local function makeNPC(parent, cf, shirt, name)
	local model = Instance.new("Model")
	model.Name = name
	local torso = part({ Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 3, 0), Color = shirt, Parent = model })
	part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(0, 4.8, 0), Color = Color3.fromRGB(255, 220, 180), Parent = model })
	part({ Name = "Hat", Size = Vector3.new(2.2, 0.4, 2.2), CFrame = cf * CFrame.new(0, 5.6, 0), Color = Color3.fromRGB(230, 200, 120), Parent = model })
	part({ Name = "Legs", Size = Vector3.new(2, 2, 1), CFrame = cf * CFrame.new(0, 1, 0), Color = Color3.fromRGB(60, 70, 110), Parent = model })
	model.PrimaryPart = torso
	model.Parent = parent
	return model
end

local function makePrompt(parent, actionText, objectText, hold)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function makeStall(parent, pos, title, color, panel, actionText)
	local folder = Instance.new("Model")
	folder.Name = panel -- tên cố định để hướng dẫn tìm được quầy
	local cf = CFrame.new(pos)
	part({ Name = "Floor", Size = Vector3.new(18, 1, 12), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks, Parent = folder })
	local counter = part({ Name = "Counter", Size = Vector3.new(14, 3.5, 2), CFrame = cf * CFrame.new(0, 2.75, 0), Color = Color3.fromRGB(120, 80, 45), Material = Enum.Material.Wood, Parent = folder })
	for _, x in ipairs({ -8, 8 }) do
		for _, z in ipairs({ -5, 5 }) do
			part({ Size = Vector3.new(1, 10, 1), CFrame = cf * CFrame.new(x, 6, z), Color = Color3.fromRGB(100, 70, 40), Material = Enum.Material.Wood, Parent = folder })
		end
	end
	part({ Name = "Roof", Size = Vector3.new(20, 1, 14), CFrame = cf * CFrame.new(0, 11.5, 0), Color = color, Material = Enum.Material.Fabric, Parent = folder })
	local sign = part({ Name = "Sign", Size = Vector3.new(14, 3, 0.5), CFrame = cf * CFrame.new(0, 13.5, 0), Color = Color3.fromRGB(60, 40, 25), Parent = folder })
	surfaceText(sign, Enum.NormalId.Front, title, Color3.new(1, 1, 1))
	surfaceText(sign, Enum.NormalId.Back, title, Color3.new(1, 1, 1))
	makeNPC(folder, cf * CFrame.new(0, 1, -2.5) * CFrame.Angles(0, math.pi, 0), color, "NPC")

	local prompt = makePrompt(counter, actionText, title)
	prompt.MaxActivationDistance = 14
	prompt:SetAttribute("Panel", panel)
	folder.Parent = parent
	return folder
end

local function buildPlot(parent, index, origin)
	local cf = CFrame.lookAt(origin, Vector3.new(origin.X, 0, 0)) -- mặt trước (-Z) hướng ra đường chính
	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	part({ Name = "Base", Size = Vector3.new(56, 1, 78), CFrame = cf * CFrame.new(0, 0.5, 11), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Ground, Parent = model })
	part({ Name = "PondArea", Size = Vector3.new(56, 0.2, 18), CFrame = cf * CFrame.new(0, 1.1, 18), Color = Color3.fromRGB(110, 170, 80), Material = Enum.Material.Grass, Parent = model })
	-- viền gỗ
	for _, info in ipairs({
		{ Vector3.new(58, 1.5, 1), Vector3.new(0, 1.25, -28.5) },
		{ Vector3.new(58, 1.5, 1), Vector3.new(0, 1.25, 50.5) },
		{ Vector3.new(1, 1.5, 78), Vector3.new(-28.5, 1.25, 11) },
		{ Vector3.new(1, 1.5, 78), Vector3.new(28.5, 1.25, 11) },
	}) do
		part({ Size = info[1], CFrame = cf * CFrame.new(info[2]), Color = Color3.fromRGB(140, 95, 55), Material = Enum.Material.WoodPlanks, Parent = model })
	end

	-- biển tên nông trại
	local signPost = part({ Name = "OwnerSign", Size = Vector3.new(16, 4, 0.5), CFrame = cf * CFrame.new(0, 4, -30.5), Color = Color3.fromRGB(60, 40, 25), Parent = model })
	local ownerLabel = surfaceText(signPost, Enum.NormalId.Front, "Nông trại trống", Color3.fromRGB(255, 240, 200))
	surfaceText(signPost, Enum.NormalId.Back, "Nông trại", Color3.fromRGB(255, 240, 200))

	-- ô đất (phía trước)
	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model
	local tiles = {}
	for r = 1, GRID_ROWS do
		for c = 1, GRID_COLS do
			local idx = (r - 1) * GRID_COLS + c
			local tileModel = Instance.new("Model")
			tileModel.Name = "Tile" .. idx
			local soil = part({
				Name = "Soil",
				Size = Vector3.new(7, 1, 7),
				CFrame = cf * CFrame.new(-20 + (c - 1) * 8, 1.3, -24 + (r - 1) * 8),
				Color = Color3.fromRGB(85, 55, 30),
				Material = Enum.Material.Mud,
				Parent = tileModel,
			})
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 45
			click.Parent = tileModel
			tileModel.PrimaryPart = soil
			tileModel.Parent = tilesFolder
			tiles[idx] = { model = tileModel, soil = soil, click = click }
		end
	end

	-- AO NUÔI THỦY SẢN (phía sau)
	local pondsFolder = Instance.new("Folder")
	pondsFolder.Name = "Ponds"
	pondsFolder.Parent = model
	local ponds = {}
	local sign = part({ Name = "PondSign", Size = Vector3.new(14, 2.4, 0.4), CFrame = cf * CFrame.new(0, 3, 9.2), Color = Color3.fromRGB(40, 90, 140), Parent = model })
	surfaceText(sign, Enum.NormalId.Front, "🐟 Ao Nuôi Thủy Sản", Color3.new(1, 1, 1))
	for i = 1, Config.PondCount do
		local pondModel = Instance.new("Model")
		pondModel.Name = "Pond" .. i
		local pcf = cf * CFrame.new(-21 + (i - 1) * 14, 0, 19)
		local rim = part({ Name = "Rim", Size = Vector3.new(12.5, 1.6, 12), CFrame = pcf * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(150, 150, 140), Material = Enum.Material.Cobblestone, Parent = pondModel })
		local water = part({
			Name = "Water",
			Size = Vector3.new(10.5, 0.4, 10),
			CFrame = pcf * CFrame.new(0, 2.3, 0),
			Color = Color3.fromRGB(70, 150, 200),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			CanCollide = false,
			Parent = pondModel,
		})
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 45
		click.Parent = pondModel
		pondModel.PrimaryPart = rim
		pondModel.Parent = pondsFolder
		ponds[i] = { model = pondModel, water = water, rim = rim, click = click }
	end

	-- CHUỒNG GIA SÚC (phía sau ao)
	local barnFolder = Instance.new("Folder")
	barnFolder.Name = "Barn"
	barnFolder.Parent = model
	local wood = Color3.fromRGB(150, 95, 55)
	part({ Name = "BarnGround", Size = Vector3.new(56, 0.2, 20), CFrame = cf * CFrame.new(0, 1.1, 39.5), Color = Color3.fromRGB(170, 140, 90), Material = Enum.Material.Sand, Parent = barnFolder })
	local barnSign = part({ Name = "BarnSign", Size = Vector3.new(14, 2.4, 0.4), CFrame = cf * CFrame.new(0, 3, 28.6), Color = Color3.fromRGB(140, 60, 40), Parent = barnFolder })
	surfaceText(barnSign, Enum.NormalId.Front, "🐄 Chuồng Gia Súc", Color3.new(1, 1, 1))
	-- mái chuồng phía sau
	part({ Name = "BarnBack", Size = Vector3.new(44, 9, 1), CFrame = cf * CFrame.new(-6, 5.5, 49.5), Color = Color3.fromRGB(180, 50, 45), Material = Enum.Material.WoodPlanks, Parent = barnFolder })
	part({ Name = "BarnRoof", Size = Vector3.new(46, 0.8, 8), CFrame = cf * CFrame.new(-6, 10, 46) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(120, 40, 35), Material = Enum.Material.Slate, Parent = barnFolder })
	local pens = {}
	for i = 1, Config.PenCount do
		local pcf = cf * CFrame.new(-20 + (i - 1) * 14, 0, 40)
		local penModel = Instance.new("Model")
		penModel.Name = "Pen" .. i
		local floor = part({ Name = "Floor", Size = Vector3.new(13, 0.4, 16), CFrame = pcf * CFrame.new(0, 1.3, 0), Color = Color3.fromRGB(200, 170, 100), Material = Enum.Material.Sand, Parent = penModel })
		for _, info in ipairs({
			{ Vector3.new(13, 1.6, 0.4), Vector3.new(0, 2.3, -8) },
			{ Vector3.new(0.4, 1.6, 16), Vector3.new(-6.5, 2.3, 0) },
			{ Vector3.new(0.4, 1.6, 16), Vector3.new(6.5, 2.3, 0) },
		}) do
			part({ Name = "Fence", Size = info[1], CFrame = pcf * CFrame.new(info[2]), Color = wood, Material = Enum.Material.Wood, Parent = penModel })
		end
		part({ Name = "Trough", Size = Vector3.new(4, 0.8, 1.2), CFrame = pcf * CFrame.new(0, 1.9, 5.5), Color = Color3.fromRGB(110, 75, 40), Material = Enum.Material.Wood, Parent = penModel })
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 45
		click.Parent = penModel
		penModel.PrimaryPart = floor
		penModel.Parent = barnFolder
		pens[i] = { model = penModel, floor = floor, click = click }
	end
	-- Bàn chế tạo thức ăn
	local bench = part({ Name = "CraftBench", Size = Vector3.new(5, 3.4, 4), CFrame = cf * CFrame.new(23, 2.7, 40), Color = Color3.fromRGB(130, 85, 45), Material = Enum.Material.WoodPlanks, Parent = barnFolder })
	part({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 2.2, 2.2), CFrame = bench.CFrame * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Metal, Parent = barnFolder })
	local benchSign = part({ Name = "BenchSign", Size = Vector3.new(6, 1.6, 0.3), CFrame = cf * CFrame.new(23, 6, 42.2), Color = Color3.fromRGB(60, 40, 25), Parent = barnFolder })
	surfaceText(benchSign, Enum.NormalId.Front, "🍲 Chế Tạo Thức Ăn", Color3.fromRGB(255, 240, 200))
	local craftPrompt = makePrompt(bench, "Chế tạo thức ăn", "Bàn Chế Tạo")
	craftPrompt:SetAttribute("Panel", "Barn")

	model.Parent = parent

	return {
		index = index,
		cframe = cf,
		model = model,
		tiles = tiles,
		ponds = ponds,
		pens = pens,
		bench = bench,
		ownerLabel = ownerLabel,
		spawnCFrame = cf * CFrame.new(0, 4, -35) * CFrame.Angles(0, math.pi, 0),
		owner = nil,
	}
end

-- NHÀ TRIỂN LÃM CHUNG: 5 khu, mỗi khu thuộc về 1 nông trại
local function buildHall(parent, sectionCount)
	local hcf = CFrame.lookAt(HALL_POSITION, Vector3.new(HALL_POSITION.X, 0, 0))
	local house = Instance.new("Model")
	house.Name = "ExhibitionHall"
	local width, depth = 86, 32
	local wallColor = Color3.fromRGB(250, 245, 235)
	part({ Name = "Floor", Size = Vector3.new(width, 1, depth), CFrame = hcf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(235, 225, 205), Material = Enum.Material.Marble, Parent = house })
	part({ Name = "Carpet", Size = Vector3.new(width - 4, 0.1, 6), CFrame = hcf * CFrame.new(0, 1.05, -8), Color = Color3.fromRGB(170, 40, 50), Material = Enum.Material.Fabric, Parent = house })
	part({ Name = "BackWall", Size = Vector3.new(width, 16, 1), CFrame = hcf * CFrame.new(0, 9, depth / 2 - 0.5), Color = wallColor, Parent = house })
	part({ Name = "LeftWall", Size = Vector3.new(1, 16, depth), CFrame = hcf * CFrame.new(-width / 2 + 0.5, 9, 0), Color = wallColor, Parent = house })
	part({ Name = "RightWall", Size = Vector3.new(1, 16, depth), CFrame = hcf * CFrame.new(width / 2 - 0.5, 9, 0), Color = wallColor, Parent = house })
	part({ Name = "Roof", Size = Vector3.new(width + 3, 1, depth + 3), CFrame = hcf * CFrame.new(0, 17.5, 0), Color = Color3.fromRGB(170, 50, 50), Material = Enum.Material.Slate, Parent = house })
	for k = 0, 6 do
		local x = -width / 2 + 0.8 + k * (width - 1.6) / 6
		part({ Size = Vector3.new(1.6, 17, 1.6), CFrame = hcf * CFrame.new(x, 9, -depth / 2), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Marble, Parent = house })
	end
	local banner = part({ Name = "Banner", Size = Vector3.new(40, 3.5, 0.5), CFrame = hcf * CFrame.new(0, 15.2, -depth / 2 - 0.3), Color = Color3.fromRGB(170, 50, 50), Parent = house })
	surfaceText(banner, Enum.NormalId.Front, "🏛 Nhà Triển Lãm Chung", Color3.fromRGB(255, 230, 150))

	local sections = {}
	local secW = (width - 2) / sectionCount
	for i = 1, sectionCount do
		local sx = -width / 2 + 1 + secW * (i - 0.5)
		local scf = hcf * CFrame.new(sx, 0, 0)
		if i > 1 then
			part({ Name = "Divider", Size = Vector3.new(0.6, 5, 14), CFrame = hcf * CFrame.new(-width / 2 + 1 + secW * (i - 1), 3.5, 7), Color = Color3.fromRGB(200, 170, 90), Material = Enum.Material.Marble, Parent = house })
		end
		local nameBoard = part({ Name = "NameBoard" .. i, Size = Vector3.new(secW - 2, 3, 0.4), CFrame = scf * CFrame.new(0, 11, depth / 2 - 1.2), Color = Color3.fromRGB(60, 40, 25), Parent = house })
		local nameLabel = surfaceText(nameBoard, Enum.NormalId.Front, "Khu " .. i .. " • trống", Color3.fromRGB(255, 240, 200))
		local likeBoard = part({ Name = "LikeBoard" .. i, Size = Vector3.new(secW - 6, 1.6, 0.4), CFrame = scf * CFrame.new(0, 8.6, depth / 2 - 1.2), Color = Color3.fromRGB(60, 40, 25), Parent = house })
		local likeLabel = surfaceText(likeBoard, Enum.NormalId.Front, "❤ 0", Color3.fromRGB(255, 150, 170))
		local likeStand = part({ Name = "LikeStand" .. i, Size = Vector3.new(2, 3, 2), CFrame = scf * CFrame.new(0, 2.5, -4), Color = Color3.fromRGB(255, 150, 170), Material = Enum.Material.SmoothPlastic, Parent = house })
		local likePrompt = makePrompt(likeStand, "Thích khu này ❤", "Khu " .. i, 0.3)

		local pedestals = {}
		local pedCount = Config.ExhibitSlots
		for j = 1, pedCount do
			local px = (j - (pedCount + 1) / 2) * (secW / pedCount)
			local ped = part({
				Name = "Pedestal" .. i .. "_" .. j,
				Size = Vector3.new(4, 3, 4),
				CFrame = scf * CFrame.new(px, 2.5, 7),
				Color = Color3.fromRGB(215, 190, 120),
				Material = Enum.Material.Marble,
				Parent = house,
			})
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Top
			light.Brightness = 2
			light.Range = 10
			light.Parent = ped
			pedestals[j] = ped
		end
		sections[i] = { nameLabel = nameLabel, likeLabel = likeLabel, likePrompt = likePrompt, pedestals = pedestals }
	end
	house.Parent = parent
	return sections
end

function WorldBuilder.build()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	local sand = Color3.fromRGB(210, 190, 150)
	part({ Name = "Ground", Size = Vector3.new(420, 2, 400), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(100, 175, 70), Material = Enum.Material.Grass, Parent = world })
	part({ Name = "Road", Size = Vector3.new(300, 0.2, 24), CFrame = CFrame.new(0, 0.1, 0), Color = sand, Material = Enum.Material.Sand, Parent = world })
	for _, pos in ipairs(PLOT_POSITIONS) do
		local zMid = pos.Z > 0 and 32 or -32
		part({ Size = Vector3.new(10, 0.2, 40), CFrame = CFrame.new(pos.X, 0.1, zMid), Color = sand, Material = Enum.Material.Sand, Parent = world })
	end
	part({ Size = Vector3.new(12, 0.2, 58), CFrame = CFrame.new(0, 0.1, 41), Color = sand, Material = Enum.Material.Sand, Parent = world })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 230, 150)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	local shops = Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = world
	makeStall(shops, Vector3.new(-125, 0, 0), "🐾 Cửa Hàng Pet", Color3.fromRGB(230, 120, 60), "PetShop", "Mua pet")
	makeStall(shops, Vector3.new(-60, 0, 0), "🛠 Dụng Cụ", Color3.fromRGB(80, 140, 230), "GearShop", "Mua dụng cụ")
	makeStall(shops, Vector3.new(-25, 0, 0), "🌱 Hạt Giống", Color3.fromRGB(80, 180, 80), "SeedShop", "Mua hạt giống")
	makeStall(shops, Vector3.new(25, 0, 0), "🐟 Thủy Sản", Color3.fromRGB(40, 150, 200), "FishShop", "Mua con giống")
	makeStall(shops, Vector3.new(60, 0, 0), "💰 Bán Hàng", Color3.fromRGB(230, 190, 50), "Sell", "Bán nông sản, thủy sản")
	makeStall(shops, Vector3.new(125, 0, 0), "🐄 Gia Súc", Color3.fromRGB(180, 70, 50), "AnimalShop", "Mua gia súc")

	-- cây trang trí (tránh nông trại, nhà triển lãm và đường)
	local function blocked(x, z)
		if math.abs(z) < 16 then
			return true
		end
		for _, pos in ipairs(PLOT_POSITIONS) do
			if math.abs(x - pos.X) < 36 and math.abs(z - pos.Z) < 62 and math.sign(z) == math.sign(pos.Z) then
				return true
			end
			if math.abs(x - pos.X) < 9 and math.abs(z) < 56 then
				return true
			end
		end
		return math.abs(x - HALL_POSITION.X) < 52 and z > 10
	end
	local rng = Random.new(42)
	for _ = 1, 50 do
		local x = rng:NextNumber(-200, 200)
		local z = rng:NextNumber(-170, 170)
		if not blocked(x, z) then
			part({ Name = "Trunk", Size = Vector3.new(1.5, 8, 1.5), CFrame = CFrame.new(x, 4, z), Color = Color3.fromRGB(110, 75, 40), Material = Enum.Material.Wood, Parent = world })
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(x, 10, z), Color = Color3.fromRGB(60, 140, 60), Material = Enum.Material.Grass, Parent = world })
		end
	end

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	local plots = {}
	for i, pos in ipairs(PLOT_POSITIONS) do
		plots[i] = buildPlot(plotsFolder, i, pos)
	end
	local sections = buildHall(world, #PLOT_POSITIONS)
	return plots, sections
end

WorldBuilder.GRID_SIZE = GRID_COLS * GRID_ROWS

return WorldBuilder
