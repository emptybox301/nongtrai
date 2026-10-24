-- NÔNG TRẠI NGŨ HÀNH - Server chính
-- Nông trại, cửa hàng, pet 5 hệ, hợp thể, nhà triển lãm

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PetUtil = require(Shared.PetUtil)
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Visuals = require(script.Parent.Visuals)

----------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local DataEvent = Instance.new("RemoteEvent")
DataEvent.Name = "Data"
DataEvent.Parent = remotes
local NotifyEvent = Instance.new("RemoteEvent")
NotifyEvent.Name = "Notify"
NotifyEvent.Parent = remotes
local Request = Instance.new("RemoteFunction")
Request.Name = "Request"
Request.Parent = remotes
remotes.Parent = ReplicatedStorage

----------------------------------------------------------------
-- TRẠNG THÁI
----------------------------------------------------------------
local plots, sections = WorldBuilder.build()
local petFolder = Instance.new("Folder")
petFolder.Name = "Pets"
petFolder.Parent = workspace

local playerPlot = {} -- [player] = plot
local selected = {} -- [player] = { kind, key }
local bought = {} -- [player] = { [seedKey/fishKey] = n }
local waveStock = {}
local restockAt = 0
local petModels = {} -- [player] = { model, ... }
local exhibitModels = {} -- [sectionIndex] = { model, ... }
local likeCooldown = {} -- ["liker:owner"] = os.time()

local function notify(player, text, kind)
	NotifyEvent:FireClient(player, text, kind or "info")
end

local function stockFor(player)
	local out = {}
	local b = bought[player] or {}
	for key, n in pairs(waveStock) do
		out[key] = math.max(0, n - (b[key] or 0))
	end
	return out
end

local function push(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local plot = playerPlot[player]
	DataEvent:FireClient(player, {
		data = data,
		stock = stockFor(player),
		restockAt = restockAt,
		selected = selected[player],
		plotIndex = plot and plot.index or nil,
	})
end

local function buffsOf(data)
	return PetUtil.totalBuffs(data)
end

----------------------------------------------------------------
-- CỬA HÀNG HẠT GIỐNG: LÀM MỚI
----------------------------------------------------------------
local function restock()
	for _, key in ipairs(Config.SeedOrder) do
		local s = Config.Seeds[key]
		if math.random() <= s.appear then
			waveStock[key] = math.random(s.stock[1], s.stock[2])
		else
			waveStock[key] = 0
		end
	end
	for _, key in ipairs(Config.FishOrder) do
		local f = Config.Fish[key]
		if math.random() <= f.appear then
			waveStock[key] = math.random(f.stock[1], f.stock[2])
		else
			waveStock[key] = 0
		end
	end
	waveStock.CaRot = math.max(waveStock.CaRot, 5)
	waveStock.CaRoPhi = math.max(waveStock.CaRoPhi, 3)
	bought = {}
	restockAt = os.time() + Config.RestockSeconds
	for _, p in ipairs(Players:GetPlayers()) do
		push(p)
		notify(p, "🌱🐟 Cửa hàng hạt giống & thủy sản vừa nhập hàng mới!", "info")
	end
end

----------------------------------------------------------------
-- NÔNG TRẠI
----------------------------------------------------------------
local function tileKey(idx)
	return "t" .. idx
end

local function progressOf(plant)
	return math.clamp((os.time() - plant.at) / plant.grow, 0, 1)
end

local function updateTileVisual(plot, idx, plant)
	local tile = plot.tiles[idx]
	if not tile.label then
		tile.label = Visuals.billboard(tile.soil, "", Color3.new(1, 1, 1), 4)
		tile.label.Parent.MaxDistance = 40
	end
	if not plant then
		if tile.visual then
			tile.visual.model:Destroy()
			tile.visual = nil
		end
		tile.label.Text = ""
		return
	end
	local prog = progressOf(plant)
	local stage = math.floor(prog * 10)
	if not tile.visual or tile.visual.stage ~= stage or tile.visual.seed ~= plant.seed then
		if tile.visual then
			tile.visual.model:Destroy()
		end
		local shownMut = prog >= 1 and plant.mut or nil
		local model = Visuals.makeCrop(plant.seed, shownMut, 0.3 + 0.7 * prog)
		local fruitSize = model.PrimaryPart.Size.Y
		local stemH = 0.6 + prog * 1.2
		Visuals.part({
			Name = "Stem",
			Size = Vector3.new(0.3, stemH, 0.3),
			Color = Color3.fromRGB(70, 150, 60),
			CFrame = CFrame.new(0, -fruitSize / 2 - stemH / 2 + 0.2, 0),
			Parent = model,
		})
		model:PivotTo(tile.soil.CFrame * CFrame.new(0, 0.5 + stemH + fruitSize / 2 - 0.2, 0))
		model.Parent = tile.model
		tile.visual = { model = model, stage = stage, seed = plant.seed }
	end
	if prog >= 1 then
		local name = PetUtil.cropName(plant.seed .. "|" .. (plant.mut or "Thuong"))
		tile.label.Text = "✨ " .. name .. " - Sẵn sàng!"
		tile.label.TextColor3 = Color3.fromRGB(255, 240, 120)
	else
		local remaining = plant.grow - (os.time() - plant.at)
		tile.label.Text = Config.Seeds[plant.seed].name .. " " .. PetUtil.formatTime(remaining) .. (plant.fert and " 🌿" or "")
		tile.label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local updatePondVisual -- khai báo trước, định nghĩa ở phần AO NUÔI
local updatePenVisual -- khai báo trước, định nghĩa ở phần CHUỒNG GIA SÚC

local function refreshPlot(plot)
	local data = plot.owner and DataService.get(plot.owner)
	for idx = 1, WorldBuilder.GRID_SIZE do
		updateTileVisual(plot, idx, data and data.plots[tileKey(idx)] or nil)
	end
	for idx = 1, Config.PondCount do
		updatePondVisual(plot, idx, data and data.ponds["p" .. idx] or nil)
	end
	for idx = 1, Config.PenCount do
		updatePenVisual(plot, idx, data and data.pens["b" .. idx] or nil)
	end
end

local function rollMutation(data, buffs)
	local luck = 1 + buffs.Hoa
	if data.luckUntil > os.time() then
		luck *= 2
	end
	for _, m in ipairs(Config.Mutations) do
		if math.random() < m.chance * luck then
			return m.key
		end
	end
	return nil
end

local function consumeSelected(player, data, kind, key)
	local bags = { seed = data.seeds, fry = data.fry, animal = data.animals, feed = data.feed }
	local bag = bags[kind] or data.gear
	bag[key] = (bag[key] or 0) - 1
	if bag[key] <= 0 then
		bag[key] = nil
		selected[player] = nil
	end
end

local function harvest(player, data, idx, plant)
	local buffs = buffsOf(data)
	local amount = plant.fert and 2 or 1
	local extra = {}
	if math.random() < buffs.Thuy then
		amount *= 2
		table.insert(extra, "💧 x2")
	end
	local key = plant.seed .. "|" .. (plant.mut or "Thuong")
	data.crops[key] = (data.crops[key] or 0) + amount
	if math.random() < buffs.Tho then
		data.seeds[plant.seed] = (data.seeds[plant.seed] or 0) + 1
		table.insert(extra, "🪨 hoàn hạt")
	end
	data.plots[tileKey(idx)] = nil
	local msg = string.format("Thu hoạch %d %s", amount, PetUtil.cropName(key))
	if #extra > 0 then
		msg ..= " (" .. table.concat(extra, ", ") .. ")"
	end
	notify(player, msg, plant.mut and "rare" or "success")
end

local function onTileClicked(player, plot, idx)
	if plot.owner ~= player then
		notify(player, "Đây không phải nông trại của bạn!", "error")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = tileKey(idx)
	local plant = data.plots[key]
	local sel = selected[player]

	if not plant then
		if sel and sel.kind == "seed" and (data.seeds[sel.key] or 0) > 0 then
			local seed = Config.Seeds[sel.key]
			local buffs = buffsOf(data)
			data.plots[key] = {
				seed = sel.key,
				at = os.time(),
				grow = math.max(5, math.floor(seed.grow / (1 + buffs.Moc))),
				mut = rollMutation(data, buffs),
				fert = false,
			}
			consumeSelected(player, data, "seed", sel.key)
		else
			notify(player, "Chọn hạt giống ở thanh bên dưới rồi chạm vào ô đất để trồng", "info")
			return
		end
	else
		local ready = progressOf(plant) >= 1
		if sel and sel.kind == "gear" and sel.key == "Xeng" then
			data.plots[key] = nil
			notify(player, "Đã nhổ bỏ cây", "info")
		elseif sel and sel.kind == "gear" and sel.key == "BinhTuoi" and not ready and (data.gear.BinhTuoi or 0) > 0 then
			local remaining = plant.grow - (os.time() - plant.at)
			plant.at -= math.ceil(remaining * 0.25)
			consumeSelected(player, data, "gear", "BinhTuoi")
			notify(player, "💧 Đã tưới cây!", "success")
		elseif sel and sel.kind == "gear" and sel.key == "PhanBon" and not plant.fert and (data.gear.PhanBon or 0) > 0 then
			plant.fert = true
			consumeSelected(player, data, "gear", "PhanBon")
			notify(player, "🌿 Đã bón phân: sản lượng x2!", "success")
		elseif ready then
			harvest(player, data, idx, plant)
		else
			notify(player, "Cây còn " .. PetUtil.formatTime(plant.grow - (os.time() - plant.at)) .. " nữa mới chín", "info")
			return
		end
	end
	updateTileVisual(plot, idx, data.plots[key])
	push(player)
end

for _, plot in ipairs(plots) do
	for idx, tile in ipairs(plot.tiles) do
		tile.click.MouseClick:Connect(function(player)
			onTileClicked(player, plot, idx)
		end)
	end
end

----------------------------------------------------------------
-- AO NUÔI THỦY SẢN
----------------------------------------------------------------
local function pondGrowTime(data, fishKey)
	local buffs = buffsOf(data)
	return math.max(5, math.floor(Config.Fish[fishKey].grow / (1 + buffs.Thuy)))
end

updatePondVisual = function(plot, idx, pond)
	local p = plot.ponds[idx]
	if not p.label then
		p.label = Visuals.billboard(p.rim, "", Color3.new(1, 1, 1), 4)
		p.label.Parent.MaxDistance = 45
	end
	if not pond then
		if p.visual then
			for _, m in ipairs(p.visual.models) do
				m:Destroy()
			end
			p.visual = nil
		end
		p.water.Color = Color3.fromRGB(70, 150, 200)
		p.label.Text = plot.owner and "Ao trống" or ""
		p.label.TextColor3 = Color3.fromRGB(200, 230, 255)
		return
	end
	local prog = progressOf(pond)
	local stage = math.floor(prog * 4)
	if not p.visual or p.visual.stage ~= stage or p.visual.fish ~= pond.fish then
		if p.visual then
			for _, m in ipairs(p.visual.models) do
				m:Destroy()
			end
		end
		local models = {}
		local shownMut = prog >= 1 and pond.mut or nil
		local count = 3
		for k = 1, count do
			local m = Visuals.makeFish(pond.fish, shownMut, 0.45 + 0.75 * prog)
			local angle = (k / count) * math.pi * 2
			m:PivotTo(p.water.CFrame * CFrame.new(math.cos(angle) * 2.6, 0.6, math.sin(angle) * 2.6) * CFrame.Angles(0, -angle, 0))
			m.Parent = p.model
			table.insert(models, m)
		end
		p.visual = { models = models, stage = stage, fish = pond.fish }
	end
	local info = Config.Fish[pond.fish]
	if prog >= 1 then
		p.water.Color = Color3.fromRGB(90, 200, 220)
		p.label.Text = "✨ " .. PetUtil.cropName(pond.fish .. "|" .. (pond.mut or "Thuong")) .. " - Thu hoạch!"
		p.label.TextColor3 = Color3.fromRGB(255, 240, 120)
	else
		p.water.Color = Color3.fromRGB(70, 150, 200)
		local remaining = pond.grow - (os.time() - pond.at)
		p.label.Text = info.name .. " " .. PetUtil.formatTime(remaining) .. ((pond.fed or 0) > 0 and (" 🍤x" .. pond.fed) or "")
		p.label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function harvestPond(player, data, idx, pond)
	local buffs = buffsOf(data)
	local info = Config.Fish[pond.fish]
	local amount = math.random(info.yield[1], info.yield[2]) + (pond.fed or 0)
	local extra = {}
	if math.random() < buffs.Thuy then
		amount *= 2
		table.insert(extra, "💧 x2")
	end
	local key = pond.fish .. "|" .. (pond.mut or "Thuong")
	data.crops[key] = (data.crops[key] or 0) + amount
	if math.random() < buffs.Tho then
		data.fry[pond.fish] = (data.fry[pond.fish] or 0) + 1
		table.insert(extra, "🪨 hoàn con giống")
	end
	data.ponds["p" .. idx] = nil
	local msg = string.format("Thu hoạch %d %s", amount, PetUtil.cropName(key))
	if #extra > 0 then
		msg ..= " (" .. table.concat(extra, ", ") .. ")"
	end
	notify(player, msg, pond.mut and "rare" or "success")
end

local function onPondClicked(player, plot, idx)
	if plot.owner ~= player then
		notify(player, "Đây không phải ao của bạn!", "error")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = "p" .. idx
	local pond = data.ponds[key]
	local sel = selected[player]
	if not pond then
		if sel and sel.kind == "fry" and (data.fry[sel.key] or 0) > 0 then
			data.ponds[key] = {
				fish = sel.key,
				at = os.time(),
				grow = pondGrowTime(data, sel.key),
				mut = rollMutation(data, buffsOf(data)),
				fed = 0,
			}
			consumeSelected(player, data, "fry", sel.key)
			notify(player, "🐟 Đã thả " .. Config.Fish[sel.key].name .. " xuống ao", "success")
		else
			notify(player, "Chọn con giống (mua ở quầy 🐟 Thủy Sản) rồi chạm vào ao để thả", "info")
			return
		end
	else
		local ready = progressOf(pond) >= 1
		if sel and sel.kind == "gear" and sel.key == "Xeng" then
			data.ponds[key] = nil
			notify(player, "Đã xả ao", "info")
		elseif sel and sel.kind == "gear" and sel.key == "ThucAnCa" and not ready and (data.gear.ThucAnCa or 0) > 0 then
			if (pond.fed or 0) >= 3 then
				notify(player, "Ao này đã cho ăn đủ 3 lần rồi", "error")
				return
			end
			local remaining = pond.grow - (os.time() - pond.at)
			pond.at -= math.ceil(remaining * 0.3)
			pond.fed = (pond.fed or 0) + 1
			consumeSelected(player, data, "gear", "ThucAnCa")
			notify(player, "🍤 Đã cho cá ăn! (+1 con khi thu hoạch)", "success")
		elseif ready then
			harvestPond(player, data, idx, pond)
		else
			notify(player, "Còn " .. PetUtil.formatTime(pond.grow - (os.time() - pond.at)) .. " nữa mới thu hoạch được", "info")
			return
		end
	end
	updatePondVisual(plot, idx, data.ponds[key])
	push(player)
end

for _, plot in ipairs(plots) do
	for idx, p in ipairs(plot.ponds) do
		p.click.MouseClick:Connect(function(player)
			onPondClicked(player, plot, idx)
		end)
	end
end

----------------------------------------------------------------
-- CHUỒNG GIA SÚC
-- pen = { animal = "Ga", at = thời điểm cho ăn (nil = đang đói), time, feed, mut }
----------------------------------------------------------------
local function penReady(pen)
	return pen.at ~= nil and os.time() - pen.at >= pen.time
end

updatePenVisual = function(plot, idx, pen)
	local p = plot.pens[idx]
	if not p.label then
		p.label = Visuals.billboard(p.floor, "", Color3.new(1, 1, 1), 6)
		p.label.Parent.MaxDistance = 45
	end
	if not pen then
		if p.visual then
			p.visual.model:Destroy()
			p.visual = nil
		end
		p.label.Text = plot.owner and "Chuồng trống" or ""
		p.label.TextColor3 = Color3.fromRGB(230, 220, 200)
		return
	end
	if not p.visual or p.visual.animal ~= pen.animal then
		if p.visual then
			p.visual.model:Destroy()
		end
		local m = Visuals.makeAnimal(pen.animal)
		local _, size = m:GetBoundingBox()
		m:PivotTo(p.floor.CFrame * CFrame.new(0, 0.2 + size.Y / 2, -1) * CFrame.Angles(0, math.rad(math.random(-40, 40)), 0))
		m.Parent = p.model
		p.visual = { model = m, animal = pen.animal }
	end
	local a = Config.Animals[pen.animal]
	local product = Config.Products[a.product]
	if pen.at == nil then
		p.label.Text = a.name .. " đói 🍽 cần " .. Config.Feeds[a.eats].name
		p.label.TextColor3 = Color3.fromRGB(255, 170, 120)
	elseif penReady(pen) then
		p.label.Text = "✨ " .. PetUtil.cropName(a.product .. "|" .. (pen.mut or "Thuong")) .. " - Thu nhặt!"
		p.label.TextColor3 = Color3.fromRGB(255, 240, 120)
	else
		p.label.Text = a.name .. " • " .. product.name .. " " .. PetUtil.formatTime(pen.time - (os.time() - pen.at))
		p.label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function findFeedFor(data, animalKey)
	for _, feedKey in ipairs(Config.FeedOrder) do
		if (data.feed[feedKey] or 0) > 0 and PetUtil.feedFits(feedKey, animalKey) then
			return feedKey
		end
	end
	return nil
end

local function feedPen(player, data, pen, feedKey)
	local buffs = buffsOf(data)
	data.feed[feedKey] -= 1
	if data.feed[feedKey] <= 0 then
		data.feed[feedKey] = nil
		local sel = selected[player]
		if sel and sel.kind == "feed" and sel.key == feedKey then
			selected[player] = nil
		end
	end
	if math.random() < buffs.Tho then
		data.feed[feedKey] = (data.feed[feedKey] or 0) + 1
		notify(player, "🪨 Pet hệ Thổ hoàn lại 1 " .. Config.Feeds[feedKey].name, "success")
	end
	local a = Config.Animals[pen.animal]
	pen.at = os.time()
	pen.time = math.max(5, math.floor(a.time / (1 + buffs.Moc * 0.5)))
	pen.feed = feedKey
	pen.mut = rollMutation(data, buffs)
	notify(player, "🍽 Đã cho " .. a.name .. " ăn " .. Config.Feeds[feedKey].name, "success")
end

local function collectPen(player, data, pen)
	local buffs = buffsOf(data)
	local a = Config.Animals[pen.animal]
	local feed = Config.Feeds[pen.feed or ""]
	local amount = math.random(a.yield[1], a.yield[2]) * ((feed and feed.mult) or 1)
	local extra = {}
	if math.random() < buffs.Thuy then
		amount *= 2
		table.insert(extra, "💧 x2")
	end
	local key = a.product .. "|" .. (pen.mut or "Thuong")
	data.crops[key] = (data.crops[key] or 0) + amount
	pen.at, pen.time, pen.feed, pen.mut = nil, nil, nil, nil
	local msg = string.format("Thu nhặt %d %s", amount, PetUtil.cropName(key))
	if #extra > 0 then
		msg ..= " (" .. table.concat(extra, ", ") .. ")"
	end
	notify(player, msg, key:find("Thuong") and "success" or "rare")
end

local function onPenClicked(player, plot, idx)
	if plot.owner ~= player then
		notify(player, "Đây không phải chuồng của bạn!", "error")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = "b" .. idx
	local pen = data.pens[key]
	local sel = selected[player]
	if not pen then
		if sel and sel.kind == "animal" and (data.animals[sel.key] or 0) > 0 then
			data.pens[key] = { animal = sel.key }
			consumeSelected(player, data, "animal", sel.key)
			notify(player, "🐾 Đã thả " .. Config.Animals[sel.key].name .. " vào chuồng", "success")
		else
			notify(player, "Mua gia súc ở quầy 🐄 Gia Súc, chọn ở thanh dưới rồi chạm vào chuồng trống", "info")
			return
		end
	elseif sel and sel.kind == "gear" and sel.key == "Xeng" then
		data.animals[pen.animal] = (data.animals[pen.animal] or 0) + 1
		data.pens[key] = nil
		notify(player, "Đã đưa " .. Config.Animals[pen.animal].name .. " về túi", "info")
	elseif pen.at ~= nil then
		if penReady(pen) then
			collectPen(player, data, pen)
		else
			notify(player, "Còn " .. PetUtil.formatTime(pen.time - (os.time() - pen.at)) .. " nữa mới thu nhặt được", "info")
			return
		end
	else
		local feedKey
		if sel and sel.kind == "feed" and (data.feed[sel.key] or 0) > 0 then
			if not PetUtil.feedFits(sel.key, pen.animal) then
				notify(player, Config.Animals[pen.animal].name .. " không ăn " .. Config.Feeds[sel.key].name, "error")
				return
			end
			feedKey = sel.key
		else
			feedKey = findFeedFor(data, pen.animal)
		end
		if not feedKey then
			local need = Config.Feeds[Config.Animals[pen.animal].eats]
			notify(player, "Hết thức ăn! Chế tạo " .. need.name .. " ở 🍲 Bàn Chế Tạo cạnh chuồng", "error")
			return
		end
		feedPen(player, data, pen, feedKey)
	end
	updatePenVisual(plot, idx, data.pens[key])
	push(player)
end

for _, plot in ipairs(plots) do
	for idx, p in ipairs(plot.pens) do
		p.click.MouseClick:Connect(function(player)
			onPenClicked(player, plot, idx)
		end)
	end
end

----------------------------------------------------------------
-- PET THEO NGƯỜI CHƠI
----------------------------------------------------------------
local function refreshPets(player)
	for _, m in ipairs(petModels[player] or {}) do
		m:Destroy()
	end
	petModels[player] = {}
	local data = DataService.get(player)
	if not data then
		return
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	for _, id in ipairs(data.equipped) do
		local pet = data.pets[id]
		if pet then
			local model = Visuals.makePet(pet, nil)
			if hrp then
				model:PivotTo(hrp.CFrame * CFrame.new(0, 2, 5))
			end
			model.Parent = petFolder
			table.insert(petModels[player], model)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	for player, list in pairs(petModels) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for i, model in ipairs(list) do
				local angle = (i - 2) * 0.9
				local offset = CFrame.new(math.sin(angle) * 5, 1 + math.sin(t * 3 + i) * 0.4, 4 + math.cos(angle) * 1.5)
				local target = hrp.CFrame * offset
				model:PivotTo(model:GetPivot():Lerp(target, math.min(1, dt * 6)))
			end
		end
	end
end)

----------------------------------------------------------------
-- NHÀ TRIỂN LÃM
----------------------------------------------------------------
local function exhibitCount(data)
	local n = 0
	for i = 1, Config.ExhibitSlots do
		if data.exhibit["s" .. i] then
			n += 1
		end
	end
	return n
end

local function exhibitIncome(data)
	local total = 0
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		if item then
			if item.kind == "pet" and data.pets[item.id] then
				total += PetUtil.petExhibitValue(data.pets[item.id])
			elseif item.kind == "crop" then
				total += PetUtil.cropExhibitValue(item.key)
			end
		end
	end
	return total
end

local function isExhibited(data, petId)
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		if item and item.kind == "pet" and item.id == petId then
			return true
		end
	end
	return false
end

local exhibitFolder = Instance.new("Folder")
exhibitFolder.Name = "ExhibitItems"
exhibitFolder.Parent = workspace

-- Mỗi nông trại (plot.index) sở hữu 1 khu trong Nhà Triển Lãm chung
local function refreshExhibit(plot)
	local section = sections[plot.index]
	for _, m in ipairs(exhibitModels[plot.index] or {}) do
		m:Destroy()
	end
	exhibitModels[plot.index] = {}
	local owner = plot.owner
	local data = owner and DataService.get(owner)
	if not data then
		section.nameLabel.Text = "Khu " .. plot.index .. " • trống"
		section.likeLabel.Text = "❤ 0"
		return
	end
	section.nameLabel.Text = "Khu của " .. owner.DisplayName
	section.likeLabel.Text = "❤ " .. PetUtil.formatNumber(data.likes)
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		local model
		if item and item.kind == "pet" and data.pets[item.id] then
			model = Visuals.makePet(data.pets[item.id], nil)
		elseif item and item.kind == "crop" then
			local seedKey, mutKey = string.match(item.key, "^([^|]+)|(.+)$")
			if seedKey and PetUtil.produceInfo(seedKey) then
				model = Visuals.makeCrop(seedKey, mutKey, 1.4)
				Visuals.billboard(model.PrimaryPart, PetUtil.cropName(item.key), Color3.fromRGB(255, 240, 180), 2.5)
			end
		end
		if model then
			local ped = section.pedestals[i]
			model:PivotTo(ped.CFrame * CFrame.new(0, 1.5 + model.PrimaryPart.Size.Y / 2 + 0.3, 0))
			model.Parent = exhibitFolder
			table.insert(exhibitModels[plot.index], model)
		end
	end
end

for _, plot in ipairs(plots) do
	local section = sections[plot.index]
	section.likePrompt.Triggered:Connect(function(player)
		local owner = plot.owner
		if not owner then
			notify(player, "Khu trưng bày này chưa có chủ", "info")
			return
		end
		if owner == player then
			notify(player, "Đây là khu của bạn! Mời bạn bè đến thích nhé", "info")
			return
		end
		local ownerData = DataService.get(owner)
		local likerData = DataService.get(player)
		if not ownerData or not likerData then
			return
		end
		if exhibitCount(ownerData) == 0 then
			notify(player, "Triển lãm đang trống", "info")
			return
		end
		local key = player.UserId .. ":" .. owner.UserId
		local last = likeCooldown[key]
		if last and os.time() - last < Config.LikeCooldown then
			notify(player, "Bạn vừa thích rồi, quay lại sau " .. PetUtil.formatTime(Config.LikeCooldown - (os.time() - last)), "error")
			return
		end
		likeCooldown[key] = os.time()
		local reward = 50 + 10 * exhibitCount(ownerData)
		ownerData.likes += 1
		ownerData.coins += reward
		likerData.coins += 10
		notify(owner, "❤ " .. player.DisplayName .. " đã thích khu trưng bày của bạn! +" .. reward .. " xu", "rare")
		notify(player, "Bạn đã thích triển lãm của " .. owner.DisplayName .. " (+10 xu)", "success")
		section.likeLabel.Text = "❤ " .. PetUtil.formatNumber(ownerData.likes)
		push(owner)
		push(player)
	end)
end

task.spawn(function()
	while true do
		task.wait(Config.ExhibitIncomeInterval)
		for player, plot in pairs(playerPlot) do
			local data = DataService.get(player)
			if data and plot then
				local income = exhibitIncome(data)
				if income > 0 then
					data.coins += income
					notify(player, "🏛 Triển lãm mang về +" .. PetUtil.formatNumber(income) .. " xu", "success")
					push(player)
				end
			end
		end
	end
end)

----------------------------------------------------------------
-- XỬ LÝ YÊU CẦU TỪ CLIENT
----------------------------------------------------------------
local function isEquipped(data, id)
	return table.find(data.equipped, id) ~= nil
end

local Actions = {}

function Actions.Hello(player)
	push(player)
	return true
end

function Actions.Select(player, data, kind, key)
	if kind == nil then
		selected[player] = nil
		return true
	end
	if kind == "seed" and Config.Seeds[key] and (data.seeds[key] or 0) > 0 then
		selected[player] = { kind = "seed", key = key }
		return true
	elseif kind == "fry" and Config.Fish[key] and (data.fry[key] or 0) > 0 then
		selected[player] = { kind = "fry", key = key }
		return true
	elseif kind == "animal" and Config.Animals[key] and (data.animals[key] or 0) > 0 then
		selected[player] = { kind = "animal", key = key }
		return true
	elseif kind == "feed" and Config.Feeds[key] and (data.feed[key] or 0) > 0 then
		selected[player] = { kind = "feed", key = key }
		return true
	elseif kind == "gear" and Config.Gear[key] and Config.Gear[key].selectable and (data.gear[key] or 0) > 0 then
		selected[player] = { kind = "gear", key = key }
		return true
	end
	return false, "Không thể chọn vật phẩm này"
end

function Actions.BuyAnimal(player, data, key)
	local a = Config.Animals[key]
	if not a then
		return false, "Con vật không tồn tại"
	end
	if data.coins < a.price then
		return false, "Không đủ xu"
	end
	data.coins -= a.price
	data.animals[key] = (data.animals[key] or 0) + 1
	return true, "Đã mua " .. a.name .. "! Chọn ở thanh dưới rồi chạm vào chuồng để thả"
end

-- Chế tạo thức ăn: dùng nông sản / thủy sản (ưu tiên loại rẻ nhất, không đột biến)
function Actions.Craft(player, data, feedKey, times)
	local feed = Config.Feeds[feedKey]
	if not feed then
		return false, "Công thức không tồn tại"
	end
	local inputs = PetUtil.recipeInputs(feed)
	local maxTimes = math.huge
	for _, input in ipairs(inputs) do
		maxTimes = math.min(maxTimes, math.floor(PetUtil.countBase(data.crops, input.key) / input.amount))
	end
	times = math.clamp(math.floor(tonumber(times) or 1), 1, 100)
	times = math.min(times, maxTimes)
	if times <= 0 then
		return false, "Không đủ nguyên liệu"
	end
	for _, input in ipairs(inputs) do
		local need = input.amount * times
		local variants = {}
		for key in pairs(data.crops) do
			if string.match(key, "^([^|]+)") == input.key then
				table.insert(variants, key)
			end
		end
		table.sort(variants, function(a, b)
			return PetUtil.cropValue(a) < PetUtil.cropValue(b)
		end)
		for _, key in ipairs(variants) do
			local take = math.min(need, data.crops[key])
			data.crops[key] -= take
			if data.crops[key] <= 0 then
				data.crops[key] = nil
			end
			need -= take
			if need <= 0 then
				break
			end
		end
	end
	local made = feed.output * times
	data.feed[feedKey] = (data.feed[feedKey] or 0) + made
	return true, "🍲 Chế tạo được " .. made .. " " .. feed.name
end

function Actions.BuyFry(player, data, key)
	local fish = Config.Fish[key]
	if not fish then
		return false, "Con giống không tồn tại"
	end
	if (stockFor(player)[key] or 0) <= 0 then
		return false, "Hết hàng! Đợi lần nhập hàng sau"
	end
	if data.coins < fish.price then
		return false, "Không đủ xu"
	end
	data.coins -= fish.price
	data.fry[key] = (data.fry[key] or 0) + 1
	bought[player] = bought[player] or {}
	bought[player][key] = (bought[player][key] or 0) + 1
	return true, "Đã mua 1 con giống " .. fish.name
end

function Actions.BuySeed(player, data, key)
	local seed = Config.Seeds[key]
	if not seed then
		return false, "Hạt không tồn tại"
	end
	if (stockFor(player)[key] or 0) <= 0 then
		return false, "Hết hàng! Đợi lần nhập hàng sau"
	end
	if data.coins < seed.price then
		return false, "Không đủ xu"
	end
	data.coins -= seed.price
	data.seeds[key] = (data.seeds[key] or 0) + 1
	bought[player] = bought[player] or {}
	bought[player][key] = (bought[player][key] or 0) + 1
	return true, "Đã mua 1 hạt " .. seed.name
end

function Actions.BuyGear(player, data, key)
	local gear = Config.Gear[key]
	if not gear then
		return false, "Vật phẩm không tồn tại"
	end
	if gear.reusable and (data.gear[key] or 0) > 0 then
		return false, "Bạn đã có " .. gear.name .. " rồi"
	end
	if data.coins < gear.price then
		return false, "Không đủ xu"
	end
	data.coins -= gear.price
	data.gear[key] = (data.gear[key] or 0) + 1
	return true, "Đã mua " .. gear.name
end

local function newPet(data, els, tier, syn)
	local id = "p" .. data.nextPetId
	data.nextPetId += 1
	data.pets[id] = { id = id, els = els, tier = tier, syn = syn or false }
	return data.pets[id]
end

function Actions.BuyPet(player, data, element)
	if not Config.Elements[element] then
		return false, "Pet không tồn tại"
	end
	if data.coins < Config.BasicPetPrice then
		return false, "Không đủ xu"
	end
	data.coins -= Config.BasicPetPrice
	local pet = newPet(data, { element }, 1, false)
	if #data.equipped < Config.MaxEquippedPets then
		table.insert(data.equipped, pet.id)
		refreshPets(player)
	end
	return true, "Đã mua " .. PetUtil.petName(pet) .. "!"
end

local function sellPrice(data, key)
	return math.floor(PetUtil.cropValue(key) * (1 + buffsOf(data).Kim))
end

function Actions.SellCrop(player, data, key)
	local n = data.crops[key] or 0
	if n <= 0 then
		return false, "Không có nông sản này"
	end
	local total = sellPrice(data, key) * n
	data.crops[key] = nil
	data.coins += total
	return true, "Bán được " .. PetUtil.formatNumber(total) .. " xu"
end

function Actions.SellAll(player, data)
	local total = 0
	for key, n in pairs(data.crops) do
		total += sellPrice(data, key) * n
	end
	if total <= 0 then
		return false, "Túi không có nông sản"
	end
	data.crops = {}
	data.coins += total
	return true, "Bán tất cả được " .. PetUtil.formatNumber(total) .. " xu"
end

function Actions.Equip(player, data, id)
	if not data.pets[id] then
		return false, "Pet không tồn tại"
	end
	if isEquipped(data, id) then
		return false, "Pet đã được trang bị"
	end
	if isExhibited(data, id) then
		return false, "Pet đang được trưng bày"
	end
	if #data.equipped >= Config.MaxEquippedPets then
		return false, "Chỉ trang bị tối đa " .. Config.MaxEquippedPets .. " pet"
	end
	table.insert(data.equipped, id)
	refreshPets(player)
	return true
end

function Actions.Unequip(player, data, id)
	local i = table.find(data.equipped, id)
	if not i then
		return false
	end
	table.remove(data.equipped, i)
	refreshPets(player)
	return true
end

function Actions.Fuse(player, data, idA, idB)
	local a, b = data.pets[idA], data.pets[idB]
	if not a or not b or idA == idB then
		return false, "Chọn 2 pet khác nhau"
	end
	for _, id in ipairs({ idA, idB }) do
		if isEquipped(data, id) or isExhibited(data, id) then
			return false, "Hãy gỡ pet khỏi trang bị / triển lãm trước khi hợp thể"
		end
	end
	local result, reason = PetUtil.previewFusion(a, b)
	if not result then
		return false, reason
	end
	if (data.gear.ManhHopThe or 0) < result.shardCost then
		return false, "Cần " .. result.shardCost .. " Mảnh Hợp Thể (mua ở Cửa hàng Dụng cụ)"
	end
	data.gear.ManhHopThe -= result.shardCost
	if data.gear.ManhHopThe <= 0 then
		data.gear.ManhHopThe = nil
	end
	if math.random() > result.chance then
		return false, "💥 Tương khắc! Hợp thể thất bại, mất " .. result.shardCost .. " mảnh (pet vẫn còn)"
	end
	data.pets[idA] = nil
	data.pets[idB] = nil
	local pet = newPet(data, result.els, result.tier, result.syn)
	notify(player, "✨ Hợp thể thành công: " .. PetUtil.petName(pet) .. " [" .. PetUtil.tierInfo(pet.tier).name .. "]", "rare")
	return true
end

function Actions.Exhibit(player, data, kind, idOrKey)
	local slot
	for i = 1, Config.ExhibitSlots do
		if not data.exhibit["s" .. i] then
			slot = "s" .. i
			break
		end
	end
	if not slot then
		return false, "Nhà triển lãm đã đầy"
	end
	if kind == "pet" then
		if not data.pets[idOrKey] then
			return false, "Pet không tồn tại"
		end
		if isEquipped(data, idOrKey) or isExhibited(data, idOrKey) then
			return false, "Pet đang được dùng"
		end
		data.exhibit[slot] = { kind = "pet", id = idOrKey }
	elseif kind == "crop" then
		if (data.crops[idOrKey] or 0) <= 0 then
			return false, "Không có nông sản này"
		end
		data.crops[idOrKey] -= 1
		if data.crops[idOrKey] <= 0 then
			data.crops[idOrKey] = nil
		end
		data.exhibit[slot] = { kind = "crop", key = idOrKey }
	else
		return false
	end
	local plot = playerPlot[player]
	if plot then
		refreshExhibit(plot)
	end
	return true, "Đã đưa vào nhà triển lãm"
end

function Actions.Unexhibit(player, data, slotIndex)
	local slot = "s" .. tostring(slotIndex)
	local item = data.exhibit[slot]
	if not item then
		return false
	end
	if item.kind == "crop" then
		data.crops[item.key] = (data.crops[item.key] or 0) + 1
	end
	data.exhibit[slot] = nil
	local plot = playerPlot[player]
	if plot then
		refreshExhibit(plot)
	end
	return true, "Đã gỡ khỏi triển lãm"
end

function Actions.SetTutorial(player, data, n, completed)
	if type(n) ~= "number" then
		return false
	end
	n = math.clamp(math.floor(n), 0, 50)
	data.tutorial = n
	if n == 0 and completed == true and not data.tutorialRewarded then
		data.tutorialRewarded = true
		data.coins += Config.TutorialReward
		notify(player, "🎉 Hoàn thành hướng dẫn! +" .. Config.TutorialReward .. " xu", "rare")
	end
	return true
end

function Actions.UseLuck(player, data)
	if (data.gear.BuaMayMan or 0) <= 0 then
		return false, "Bạn không có Bùa May Mắn"
	end
	data.gear.BuaMayMan -= 1
	if data.gear.BuaMayMan <= 0 then
		data.gear.BuaMayMan = nil
	end
	data.luckUntil = math.max(data.luckUntil, os.time()) + Config.LuckCharmSeconds
	return true, "🍀 May mắn x2 trong " .. math.floor(Config.LuckCharmSeconds / 60) .. " phút!"
end

local lastRequest = {}
Request.OnServerInvoke = function(player, action, ...)
	if type(action) ~= "string" or not Actions[action] then
		return false, "Yêu cầu không hợp lệ"
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.08 then
		return false, "Thao tác quá nhanh"
	end
	lastRequest[player] = now
	if action == "Hello" then
		return Actions.Hello(player)
	end
	local data = DataService.get(player)
	if not data then
		return false, "Dữ liệu chưa sẵn sàng"
	end
	local ok, a, b = pcall(Actions[action], player, data, ...)
	if not ok then
		warn("[Request]", action, a)
		return false, "Lỗi máy chủ"
	end
	push(player)
	return a, b
end

----------------------------------------------------------------
-- VÀO / RỜI GAME
----------------------------------------------------------------
-- Giữ chỗ 1 nông trại trống ngay khi vào (trước khi tải dữ liệu)
local function reservePlot(player)
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			playerPlot[player] = plot
			return plot
		end
	end
	return nil
end

local function activatePlot(player, plot)
	plot.ownerLabel.Text = "🌾 Nông trại của " .. player.DisplayName
	refreshPlot(plot)
	refreshExhibit(plot)
end

-- Chuyển dữ liệu cũ sang phiên bản mới (triển lãm 6 bục riêng → 3 bục trong nhà chung)
local function migrateData(data)
	for i = Config.ExhibitSlots + 1, 10 do
		local item = data.exhibit["s" .. i]
		if item then
			if item.kind == "crop" then
				data.crops[item.key] = (data.crops[item.key] or 0) + 1
			end
			data.exhibit["s" .. i] = nil
		end
	end
end

local function onCharacter(player, char)
	local plot = playerPlot[player]
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if plot and hrp then
		task.wait(0.1)
		char:PivotTo(plot.spawnCFrame)
	end
	refreshPets(player)
end

Players.PlayerAdded:Connect(function(player)
	local plot = reservePlot(player)
	if not plot or #Players:GetPlayers() > Config.MaxPlayers then
		if plot then
			plot.owner = nil
			playerPlot[player] = nil
		end
		player:Kick("Server đã đủ " .. Config.MaxPlayers .. " người chơi. Hãy vào server khác nhé!")
		return
	end
	local data, ok = DataService.load(player)
	if not player.Parent then
		DataService.release(player)
		return
	end
	migrateData(data)
	if not ok then
		task.delay(5, function()
			if player.Parent then
				notify(player, "⚠ Không tải được dữ liệu lưu. Tiến trình lần này sẽ KHÔNG được lưu (trong Studio hãy bật API Services).", "error")
			end
		end)
	end
	activatePlot(player, plot)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	push(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = playerPlot[player]
	for _, m in ipairs(petModels[player] or {}) do
		m:Destroy()
	end
	petModels[player] = nil
	selected[player] = nil
	bought[player] = nil
	lastRequest[player] = nil
	DataService.release(player)
	if plot then
		plot.owner = nil
		playerPlot[player] = nil
		plot.ownerLabel.Text = "Nông trại trống"
		refreshPlot(plot)
		refreshExhibit(plot)
	end
end)

----------------------------------------------------------------
-- VÒNG LẶP CHÍNH
----------------------------------------------------------------
restock()
task.spawn(function()
	while true do
		task.wait(1)
		if os.time() >= restockAt then
			restock()
		end
		for _, plot in ipairs(plots) do
			if plot.owner then
				refreshPlot(plot)
			end
		end
	end
end)

print("[Nông Trại] Server đã sẵn sàng!")
