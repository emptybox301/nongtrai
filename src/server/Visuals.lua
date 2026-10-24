-- Tạo mô hình 3D cho pet và nông sản (dựng bằng Part, không cần asset)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local PetUtil = require(ReplicatedStorage.Shared.PetUtil)

local Visuals = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
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

local function billboard(adornee, text, color, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 60
	bb.Adornee = adornee
	bb.Parent = adornee
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0.3
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.Text = text
	lbl.Parent = bb
	return lbl
end

function Visuals.makePet(pet, ownerName)
	local model = Instance.new("Model")
	model.Name = "Pet"
	local main = Config.Elements[pet.els[1]].color
	local size = 1.6 + pet.tier * 0.35
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * size, Color = main, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(), Parent = model })
	-- tai
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Ear", Size = Vector3.new(size * 0.22, size * 0.45, size * 0.22), Color = main, CFrame = CFrame.new(side * size * 0.28, size * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.3), Parent = model })
		part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.18, Color = Color3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(side * size * 0.2, size * 0.1, -size * 0.45), Parent = model })
	end
	-- quả cầu nguyên tố quay quanh cho pet đa hệ
	for i = 2, #pet.els do
		local angle = (i - 2) / math.max(1, #pet.els - 1) * math.pi * 2
		part({
			Name = "Orb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * 0.3,
			Color = Config.Elements[pet.els[i]].color,
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(math.cos(angle) * size * 0.8, size * 0.35, math.sin(angle) * size * 0.8),
			Parent = model,
		})
	end
	if pet.tier >= 3 then
		local light = Instance.new("PointLight")
		light.Color = PetUtil.tierInfo(pet.tier).color
		light.Range = 6 + pet.tier
		light.Brightness = 1.5
		light.Parent = body
	end
	if pet.tier >= 4 or pet.syn then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(PetUtil.tierInfo(pet.tier).color)
		sparkle.Size = NumberSequence.new(0.3)
		sparkle.Rate = pet.tier * 2
		sparkle.Lifetime = NumberRange.new(0.8, 1.2)
		sparkle.Speed = NumberRange.new(0.5, 1)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = body
	end
	local title = PetUtil.petName(pet) .. " [" .. PetUtil.tierInfo(pet.tier).name .. "]"
	if ownerName then
		title = title .. "\n" .. ownerName
	end
	billboard(body, title, PetUtil.tierInfo(pet.tier).color, size * 0.5 + 1.2)
	model.PrimaryPart = body
	return model
end

local function mutationLook(baseColor, mutKey)
	local color, material, sizeMult = baseColor, Enum.Material.SmoothPlastic, 1
	for _, m in ipairs(Config.Mutations) do
		if m.key == mutKey then
			if m.color then
				color = m.color
				material = Enum.Material.Neon
			end
			if m.key == "KhongLo" then
				sizeMult = 1.6
			end
		end
	end
	return color, material, sizeMult
end

local function ovalPart(props, scale)
	local p = part(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale or Vector3.one
	mesh.Parent = p
	return p
end

-- Thủy sản: cá / tôm / cua dựng bằng Part
function Visuals.makeFish(fishKey, mutKey, scale)
	local fish = Config.Fish[fishKey]
	local color, material, sizeMult = mutationLook(fish.color, mutKey)
	local s = scale * sizeMult
	local model = Instance.new("Model")
	model.Name = "Fish"
	local body
	if fish.shape == "crab" then
		body = ovalPart({ Name = "Body", Size = Vector3.new(2.2, 0.9, 1.6) * s, Color = color, Material = material, CFrame = CFrame.new(), Parent = model })
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Claw", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8 * s, Color = color, Material = material, CFrame = CFrame.new(side * 1.3 * s, 0.1 * s, -0.9 * s), Parent = model })
			for k = -1, 1 do
				part({ Name = "Leg", Size = Vector3.new(0.9, 0.15, 0.15) * s, Color = color, Material = material, CFrame = CFrame.new(side * 1.2 * s, -0.2 * s, k * 0.45 * s) * CFrame.Angles(0, 0, side * 0.5), Parent = model })
			end
		end
	elseif fish.shape == "shrimp" then
		body = ovalPart({ Name = "Body", Size = Vector3.new(0.8, 0.8, 1.2) * s, Color = color, Material = material, CFrame = CFrame.new(), Parent = model })
		for k = 1, 3 do
			ovalPart({ Name = "Segment", Size = Vector3.new(0.7, 0.6, 0.6) * s * (1 - k * 0.15), Color = color, Material = material, CFrame = CFrame.new(0, -0.15 * k * s, (0.5 + 0.45 * k) * s), Parent = model })
		end
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Antenna", Size = Vector3.new(0.08, 0.08, 1.4) * s, Color = color, CFrame = CFrame.new(side * 0.2 * s, 0.25 * s, -1.1 * s) * CFrame.Angles(0.3, side * 0.3, 0), Parent = model })
		end
	else
		body = ovalPart({ Name = "Body", Size = Vector3.new(0.8, 1.2, 2.4) * s, Color = color, Material = material, CFrame = CFrame.new(), Parent = model })
		part({ Name = "Tail", Size = Vector3.new(0.15, 1.1, 0.8) * s, Color = color, Material = material, CFrame = CFrame.new(0, 0, 1.4 * s), Parent = model })
		if fishKey == "CaKoi" and material ~= Enum.Material.Neon then
			ovalPart({ Name = "Spot", Size = Vector3.new(0.85, 0.6, 0.9) * s, Color = Color3.fromRGB(235, 90, 40), CFrame = CFrame.new(0, 0.25 * s, -0.2 * s), Parent = model })
		end
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.22 * s, Color = Color3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(side * 0.33 * s, 0.15 * s, -0.8 * s), Parent = model })
		end
	end
	model.PrimaryPart = body
	return model
end

-- Gia súc: gà / vịt / cừu / bò dựng bằng Part
function Visuals.makeAnimal(animalKey)
	local a = Config.Animals[animalKey]
	local model = Instance.new("Model")
	model.Name = "Animal"
	local body
	local dark = Color3.fromRGB(60, 45, 35)
	if a.shape == "bird" then
		body = ovalPart({ Name = "Body", Size = Vector3.new(1.6, 1.5, 2), Color = a.color, CFrame = CFrame.new(), Parent = model })
		part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = a.color, CFrame = CFrame.new(0, 0.9, -0.8), Parent = model })
		part({ Name = "Beak", Size = Vector3.new(0.35, 0.2, 0.45), Color = Color3.fromRGB(255, 160, 40), CFrame = CFrame.new(0, 0.85, -1.35), Parent = model })
		if animalKey == "Ga" then
			part({ Name = "Comb", Size = Vector3.new(0.15, 0.4, 0.5), Color = Color3.fromRGB(220, 40, 40), CFrame = CFrame.new(0, 1.45, -0.8), Parent = model })
		end
		for _, side in ipairs({ -1, 1 }) do
			part({ Name = "Leg", Size = Vector3.new(0.15, 0.7, 0.15), Color = Color3.fromRGB(255, 160, 40), CFrame = CFrame.new(side * 0.35, -0.95, 0), Parent = model })
		end
	else
		local isSheep = a.shape == "sheep"
		local bodySize = isSheep and Vector3.new(2.4, 2, 3.2) or Vector3.new(2.6, 2.2, 4.2)
		if isSheep then
			body = ovalPart({ Name = "Body", Size = bodySize, Color = a.color, Material = Enum.Material.Fabric, CFrame = CFrame.new(), Parent = model })
		else
			body = part({ Name = "Body", Size = bodySize, Color = a.color, CFrame = CFrame.new(), Parent = model })
			for _, sp in ipairs({ Vector3.new(0.5, 0.4, 0.6), Vector3.new(-0.6, -0.1, -0.9), Vector3.new(0.2, 0.3, -1.4) }) do
				part({ Name = "Spot", Size = Vector3.new(bodySize.X + 0.05, 0.9, 1), Color = Color3.fromRGB(35, 30, 30), CFrame = CFrame.new(0, sp.Y, sp.Z), Parent = model })
			end
		end
		local headColor = isSheep and dark or a.color
		part({ Name = "Head", Size = Vector3.new(1.3, 1.3, 1.4), Color = headColor, CFrame = CFrame.new(0, bodySize.Y * 0.35, -bodySize.Z / 2 - 0.5), Parent = model })
		if not isSheep then
			part({ Name = "Nose", Size = Vector3.new(1.1, 0.6, 0.3), Color = Color3.fromRGB(240, 170, 170), CFrame = CFrame.new(0, bodySize.Y * 0.2, -bodySize.Z / 2 - 1.3), Parent = model })
			for _, side in ipairs({ -1, 1 }) do
				part({ Name = "Horn", Size = Vector3.new(0.2, 0.6, 0.2), Color = Color3.fromRGB(230, 220, 190), CFrame = CFrame.new(side * 0.45, bodySize.Y * 0.35 + 0.9, -bodySize.Z / 2 - 0.4), Parent = model })
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				part({ Name = "Leg", Size = Vector3.new(0.45, 1.4, 0.45), Color = isSheep and dark or a.color, CFrame = CFrame.new(sx * bodySize.X * 0.3, -bodySize.Y / 2 - 0.5, sz * bodySize.Z * 0.32), Parent = model })
			end
		end
	end
	Visuals.billboard(body, a.name, Color3.new(1, 1, 1), 2.2)
	model.PrimaryPart = body
	return model
end

-- Sản phẩm gia súc (trứng, lông, sữa) cho nhà triển lãm
function Visuals.makeProduct(productKey, mutKey, scale)
	local info = Config.Products[productKey]
	local color, material, sizeMult = mutationLook(info.color, mutKey)
	local s = scale * sizeMult
	local model = Instance.new("Model")
	model.Name = "Product"
	local body
	if productKey == "SuaBo" then
		body = part({ Name = "Bottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 1, 1) * s, Color = color, Material = material, CFrame = CFrame.Angles(0, 0, math.rad(90)), Parent = model })
		part({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.6, 0.6) * s, Color = Color3.fromRGB(60, 120, 220), CFrame = CFrame.new(0, 1.05 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = model })
	elseif productKey == "LongCuu" then
		body = ovalPart({ Name = "Wool", Size = Vector3.new(1.8, 1.2, 1.6) * s, Color = color, Material = Enum.Material.Fabric, CFrame = CFrame.new(), Parent = model })
	else
		body = ovalPart({ Name = "Egg", Size = Vector3.new(0.9, 1.2, 0.9) * s, Color = color, Material = material, CFrame = CFrame.new(), Parent = model })
	end
	model.PrimaryPart = body
	return model
end

-- Nông sản (dùng cho cây trên ruộng và vật trưng bày). Tự chuyển sang mô hình cá / sản phẩm gia súc.
function Visuals.makeCrop(seedKey, mutKey, scale)
	if Config.Fish[seedKey] then
		return Visuals.makeFish(seedKey, mutKey, scale)
	end
	if Config.Products[seedKey] then
		return Visuals.makeProduct(seedKey, mutKey, scale)
	end
	local seed = Config.Seeds[seedKey]
	local model = Instance.new("Model")
	model.Name = "Crop"
	local color, material, sizeMult = mutationLook(seed.color, mutKey)
	local s = 1.6 * scale * sizeMult
	local fruit = part({ Name = "Fruit", Shape = Enum.PartType.Ball, Size = Vector3.one * s, Color = color, Material = material, CFrame = CFrame.new(), Parent = model })
	part({ Name = "Leaf", Size = Vector3.new(s * 0.2, s * 0.5, s * 0.2), Color = Color3.fromRGB(60, 160, 60), CFrame = CFrame.new(0, s * 0.6, 0), Parent = model })
	model.PrimaryPart = fruit
	return model
end

Visuals.billboard = billboard
Visuals.part = part

return Visuals
