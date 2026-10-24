-- NÔNG TRẠI NGŨ HÀNH - Giao diện người chơi (hỗ trợ cả điện thoại)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetUtil = require(Shared:WaitForChild("PetUtil"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataEvent = Remotes:WaitForChild("Data")
local NotifyEvent = Remotes:WaitForChild("Notify")
local Request = Remotes:WaitForChild("Request")

local fmt = PetUtil.formatNumber

local state = {
	data = nil,
	stock = {},
	restockAt = 0,
	selected = nil,
	plotIndex = nil,
	fuseA = nil,
	fuseB = nil,
}

----------------------------------------------------------------
-- TIỆN ÍCH GIAO DIỆN
----------------------------------------------------------------
local COLORS = {
	bg = Color3.fromRGB(35, 30, 45),
	panel = Color3.fromRGB(250, 243, 225),
	row = Color3.fromRGB(255, 252, 242),
	text = Color3.fromRGB(60, 45, 35),
	sub = Color3.fromRGB(120, 100, 85),
	green = Color3.fromRGB(80, 185, 90),
	blue = Color3.fromRGB(70, 140, 230),
	red = Color3.fromRGB(220, 75, 70),
	gold = Color3.fromRGB(240, 185, 50),
	gray = Color3.fromRGB(170, 165, 160),
	purple = Color3.fromRGB(150, 90, 230),
}

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function stroke(color, t)
	return new("UIStroke", { Color = color or Color3.fromRGB(90, 65, 45), Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.text
	if props.TextScaled == nil then
		props.TextScaled = false
	end
	props.TextSize = props.TextSize or 16
	return new("TextLabel", props)
end

local function button(props, onClick)
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextSize = props.TextSize or 16
	props.AutoButtonColor = true
	local b = new("TextButton", props, { corner(8) })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local gui = new("ScreenGui", {
	Name = "FarmUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

----------------------------------------------------------------
-- THÔNG BÁO
----------------------------------------------------------------
local toastHolder = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0.8, 0, 0, 200),
	Parent = gui,
}, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UISizeConstraint", { MaxSize = Vector2.new(460, 300) }),
})

local toastColors = { info = COLORS.blue, success = COLORS.green, error = COLORS.red, rare = COLORS.purple }
local toastOrder = 0
local function toast(text, kind)
	if not text or text == "" then
		return
	end
	toastOrder += 1
	local t = label({
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = true,
		TextSize = 15,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = toastColors[kind or "info"] or COLORS.blue,
		Size = UDim2.new(1, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = toastOrder,
		Parent = toastHolder,
	})
	corner(10).Parent = t
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = t })
	local children = toastHolder:GetChildren()
	local count = 0
	for _, c in ipairs(children) do
		if c:IsA("TextLabel") then
			count += 1
		end
	end
	if count > 4 then
		for _, c in ipairs(children) do
			if c:IsA("TextLabel") and c ~= t then
				c:Destroy()
				break
			end
		end
	end
	task.delay(3, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.45)
			t:Destroy()
		end
	end)
end

NotifyEvent.OnClientEvent:Connect(toast)

local function call(action, ...)
	local ok, success, msg = pcall(function(...)
		return Request:InvokeServer(action, ...)
	end, ...)
	if not ok then
		toast("Mất kết nối máy chủ", "error")
		return false
	end
	if msg then
		toast(msg, success and "success" or "error")
	end
	return success
end

----------------------------------------------------------------
-- HUD: TIỀN + NÚT BÊN
----------------------------------------------------------------
local coinLabel = label({
	Text = "💰 0",
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 225, 90),
	Font = Enum.Font.FredokaOne,
	BackgroundTransparency = 0.25,
	BackgroundColor3 = COLORS.bg,
	Position = UDim2.new(0, 10, 0, 10),
	Size = UDim2.fromOffset(150, 38),
	Parent = gui,
})
corner(10).Parent = coinLabel

local luckLabel = label({
	Text = "",
	TextSize = 14,
	TextColor3 = Color3.fromRGB(150, 255, 160),
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(0, 10, 0, 52),
	Size = UDim2.fromOffset(200, 20),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = gui,
})

local sideBar = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.42, 0),
	Size = UDim2.fromOffset(64, 290),
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

----------------------------------------------------------------
-- BẢNG (PANEL) DÙNG CHUNG
----------------------------------------------------------------
local panel = new("Frame", {
	Visible = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.78),
	BackgroundColor3 = COLORS.panel,
	Parent = gui,
}, {
	corner(16),
	stroke(Color3.fromRGB(110, 75, 45), 3),
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 480) }),
})

local panelTitle = label({
	Text = "",
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	Position = UDim2.new(0, 16, 0, 8),
	Size = UDim2.new(1, -70, 0, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

local panelInfo = label({
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = COLORS.sub,
	Position = UDim2.new(0, 16, 0, 40),
	Size = UDim2.new(1, -32, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = panel,
})

local content = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 10, 0, 64),
	Size = UDim2.new(1, -20, 1, -74),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	BorderSizePixel = 0,
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
})

local currentPanel = nil
local Renderers = {}

local function closePanel()
	currentPanel = nil
	panel.Visible = false
end

button({
	Text = "✕",
	TextSize = 20,
	BackgroundColor3 = COLORS.red,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 36),
	Parent = panel,
}, closePanel)

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function clearContent()
	for _, c in ipairs(content:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	order = 0
end

local function header(text)
	label({
		Text = text,
		Font = Enum.Font.FredokaOne,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(150, 90, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function note(text)
	label({
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = COLORS.sub,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

-- Một dòng: ô màu | tiêu đề + mô tả | các nút
-- buttons = { { text, color, onClick, disabled }, ... }
local function row(title, sub, swatch, buttons, titleColor)
	buttons = buttons or {}
	local btnWidth = 78
	local frame = new("Frame", {
		BackgroundColor3 = COLORS.row,
		Size = UDim2.new(1, 0, 0, 62),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = content,
	}, { corner(10), stroke(Color3.fromRGB(225, 205, 170), 1) })
	local sw = new("Frame", {
		BackgroundColor3 = swatch or COLORS.gray,
		Position = UDim2.new(0, 8, 0, 9),
		Size = UDim2.fromOffset(44, 44),
		Parent = frame,
	}, { corner(22), stroke(Color3.new(1, 1, 1), 2) })
	sw.Name = "Swatch"
	local textArea = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 60, 0, 6),
		Size = UDim2.new(1, -(68 + #buttons * (btnWidth + 6)), 0, 50),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, {
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
		new("UIPadding", { PaddingBottom = UDim.new(0, 6) }),
	})
	label({
		Text = title,
		TextSize = 16,
		Font = Enum.Font.FredokaOne,
		TextColor3 = titleColor or COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = textArea,
	})
	if sub and sub ~= "" then
		label({
			Text = sub,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.sub,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 14),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = textArea,
		})
	end
	for i, info in ipairs(buttons) do
		local disabled = info[4]
		button({
			Text = info[1],
			TextSize = 14,
			BackgroundColor3 = disabled and COLORS.gray or (info[2] or COLORS.green),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (i - 1) * (btnWidth + 6), 0.5, 0),
			Size = UDim2.fromOffset(btnWidth, 38),
			Parent = frame,
		}, function()
			if not disabled and info[3] then
				info[3]()
			end
		end)
	end
	return frame
end

local function render()
	if not currentPanel or not state.data then
		return
	end
	local scroll = content.CanvasPosition
	clearContent()
	Renderers[currentPanel]()
	task.defer(function()
		content.CanvasPosition = scroll
	end)
end

local function openPanel(name)
	if currentPanel == name then
		closePanel()
		return
	end
	currentPanel = name
	panel.Visible = true
	content.CanvasPosition = Vector2.zero
	render()
end

----------------------------------------------------------------
-- CÁC BẢNG
----------------------------------------------------------------
local function buffsText(pet)
	return table.concat(PetUtil.buffLines(PetUtil.getBuffs(pet)), "\n")
end

local function sortedPetIds(data)
	local ids = {}
	for id in pairs(data.pets) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local pa, pb = data.pets[a], data.pets[b]
		if pa.tier ~= pb.tier then
			return pa.tier > pb.tier
		end
		return #pa.els > #pb.els
	end)
	return ids
end

local function isExhibited(data, id)
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		if item and item.kind == "pet" and item.id == id then
			return true
		end
	end
	return false
end

local function sortedCropKeys(data)
	local keys = {}
	for key in pairs(data.crops) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return PetUtil.cropValue(a) > PetUtil.cropValue(b)
	end)
	return keys
end

local function cropColor(key)
	local seedKey, mutKey = string.match(key, "^([^|]+)|(.+)$")
	for _, m in ipairs(Config.Mutations) do
		if m.key == mutKey and m.color then
			return m.color
		end
	end
	local info = PetUtil.produceInfo(seedKey or "")
	return info and info.color or COLORS.gray
end

Renderers.FishShop = function()
	local data = state.data
	panelTitle.Text = "🐟 Cửa Hàng Thủy Sản"
	note("Mua con giống, chọn ở thanh dưới rồi chạm vào ao trong nông trại để thả. Mỗi ao cho nhiều con khi thu hoạch. Hàng mới mỗi " .. math.floor(Config.RestockSeconds / 60) .. " phút.")
	for _, key in ipairs(Config.FishOrder) do
		local f = Config.Fish[key]
		local stock = state.stock[key] or 0
		local sub = string.format(
			"Giá %s xu • Nuôi %s • Thu %d-%d con, %s xu/con\nCòn hàng: %d • Bạn có: %d",
			fmt(f.price), PetUtil.formatTime(f.grow), f.yield[1], f.yield[2], fmt(f.sell), stock, data.fry[key] or 0
		)
		row(f.name, sub, f.color, {
			{ "Mua", COLORS.green, function() call("BuyFry", key) end, stock <= 0 or data.coins < f.price },
		})
	end
	note("Mẹo: Thức Ăn Cá (quầy Dụng Cụ) rút ngắn thời gian nuôi và thêm 1 con mỗi lần cho ăn (tối đa 3). Pet hệ Thủy giúp thủy sản lớn nhanh hơn.")
end

Renderers.SeedShop = function()
	local data = state.data
	panelTitle.Text = "🌱 Cửa Hàng Hạt Giống"
	note("Hàng mới mỗi " .. math.floor(Config.RestockSeconds / 60) .. " phút. Hạt hiếm không phải lúc nào cũng có!")
	for _, key in ipairs(Config.SeedOrder) do
		local s = Config.Seeds[key]
		local stock = state.stock[key] or 0
		local sub = string.format("Giá %s xu • Lớn %s • Bán %s xu\nCòn hàng: %d • Bạn có: %d", fmt(s.price), PetUtil.formatTime(s.grow), fmt(s.sell), stock, data.seeds[key] or 0)
		row(s.name, sub, s.color, {
			{ "Mua", COLORS.green, function() call("BuySeed", key) end, stock <= 0 or data.coins < s.price },
		})
	end
end

Renderers.GearShop = function()
	local data = state.data
	panelTitle.Text = "🛠 Cửa Hàng Dụng Cụ"
	note("Dụng cụ chọn được (Bình tưới, Phân bón, Xẻng, Thức ăn cá) sẽ hiện ở thanh dưới màn hình.")
	for _, key in ipairs(Config.GearOrder) do
		local g = Config.Gear[key]
		local owned = data.gear[key] or 0
		local sub = string.format("%s\nGiá %s xu • Bạn có: %d", g.desc, fmt(g.price), owned)
		local disabled = data.coins < g.price or (g.reusable and owned > 0)
		row(g.name, sub, g.color, {
			{ "Mua", COLORS.green, function() call("BuyGear", key) end, disabled },
		})
	end
end

Renderers.PetShop = function()
	local data = state.data
	panelTitle.Text = "🐾 Cửa Hàng Pet"
	note("Pet cơ bản bậc Thường. Hợp thể 2 pet (cần Mảnh Hợp Thể) để lên bậc hoặc tạo pet đa hệ!")
	for _, e in ipairs(Config.ElementOrder) do
		local el = Config.Elements[e]
		local sub = string.format("Hệ %s • +%d%% %s\nGiá %s xu", el.name, math.floor(el.buffBase * 100 + 0.5), el.buffText, fmt(Config.BasicPetPrice))
		row(el.petName, sub, el.color, {
			{ "Mua", COLORS.green, function() call("BuyPet", e) end, data.coins < Config.BasicPetPrice },
		})
	end
	header("☯ Ngũ hành")
	note("Tương sinh: Mộc → Hỏa → Thổ → Kim → Thủy → Mộc. Hợp thể 2 pet tương sinh: pet mới mạnh thêm 25%.")
	note("Tương khắc: Mộc ✕ Thổ, Thổ ✕ Thủy, Thủy ✕ Hỏa, Hỏa ✕ Kim, Kim ✕ Mộc. Hợp thể tương khắc chỉ thành công 70%.")
end

Renderers.Sell = function()
	local data = state.data
	panelTitle.Text = "💰 Bán Nông Sản & Thủy Sản"
	local buffs = PetUtil.totalBuffs(data)
	local keys = sortedCropKeys(data)
	local total = 0
	for _, key in ipairs(keys) do
		total += math.floor(PetUtil.cropValue(key) * (1 + buffs.Kim)) * data.crops[key]
	end
	if buffs.Kim > 0 then
		note(string.format("Pet hệ Kim đang tăng giá bán +%d%%", math.floor(buffs.Kim * 100 + 0.5)))
	end
	row("Bán tất cả", "Tổng: " .. fmt(total) .. " xu", COLORS.gold, {
		{ "Bán hết", COLORS.gold, function() call("SellAll") end, #keys == 0 },
	})
	if #keys == 0 then
		note("Túi trống. Hãy trồng và thu hoạch nông sản!")
	end
	for _, key in ipairs(keys) do
		local each = math.floor(PetUtil.cropValue(key) * (1 + buffs.Kim))
		row(PetUtil.cropName(key) .. " x" .. data.crops[key], fmt(each) .. " xu / cái", cropColor(key), {
			{ "Bán", COLORS.green, function() call("SellCrop", key) end },
		})
	end
end

Renderers.Bag = function()
	local data = state.data
	panelTitle.Text = "🎒 Túi Đồ"
	local buffs = PetUtil.totalBuffs(data)
	header("Buff từ pet đang trang bị")
	local lines = PetUtil.buffLines(buffs)
	note(#lines > 0 and table.concat(lines, "\n") or "Chưa có buff. Hãy trang bị pet!")

	header("Dụng cụ")
	local any = false
	for _, key in ipairs(Config.GearOrder) do
		local n = data.gear[key] or 0
		if n > 0 then
			any = true
			local g = Config.Gear[key]
			local btns = {}
			if key == "BuaMayMan" then
				btns = { { "Dùng", COLORS.green, function() call("UseLuck") end } }
			end
			row(g.name .. " x" .. n, g.desc, g.color, btns)
		end
	end
	if not any then
		note("Chưa có dụng cụ.")
	end

	header("Hạt giống")
	any = false
	for _, key in ipairs(Config.SeedOrder) do
		local n = data.seeds[key] or 0
		if n > 0 then
			any = true
			row(Config.Seeds[key].name .. " x" .. n, "Chọn ở thanh dưới rồi chạm ô đất để trồng", Config.Seeds[key].color)
		end
	end
	if not any then
		note("Hết hạt giống. Mua thêm ở quầy Hạt Giống!")
	end

	header("Con giống thủy sản")
	any = false
	for _, key in ipairs(Config.FishOrder) do
		local n = (data.fry or {})[key] or 0
		if n > 0 then
			any = true
			row(Config.Fish[key].name .. " x" .. n, "Chọn ở thanh dưới rồi chạm vào ao để thả", Config.Fish[key].color)
		end
	end
	if not any then
		note("Chưa có con giống. Mua ở quầy 🐟 Thủy Sản!")
	end

	header("Nông sản & thủy sản")
	local keys = sortedCropKeys(data)
	for _, key in ipairs(keys) do
		row(PetUtil.cropName(key) .. " x" .. data.crops[key], "Giá gốc " .. fmt(PetUtil.cropValue(key)) .. " xu", cropColor(key))
	end
	if #keys == 0 then
		note("Chưa có nông sản.")
	end
end

Renderers.Pets = function()
	local data = state.data
	panelTitle.Text = "🐾 Pet Của Bạn"
	local ids = sortedPetIds(data)
	-- kiểm tra lựa chọn hợp thể còn hợp lệ
	if state.fuseA and not data.pets[state.fuseA] then
		state.fuseA = nil
	end
	if state.fuseB and not data.pets[state.fuseB] then
		state.fuseB = nil
	end

	header("⚗ Hợp thể pet")
	local a, b = data.pets[state.fuseA or ""], data.pets[state.fuseB or ""]
	local nameA = a and (PetUtil.petName(a) .. " [" .. PetUtil.tierInfo(a.tier).name .. "]") or "(trống)"
	local nameB = b and (PetUtil.petName(b) .. " [" .. PetUtil.tierInfo(b.tier).name .. "]") or "(trống)"
	local preview, reason = PetUtil.previewFusion(a, b)
	local shards = data.gear.ManhHopThe or 0
	local sub
	local canFuse = false
	if preview then
		local fake = { els = preview.els, tier = preview.tier, syn = preview.syn }
		local relation = preview.sinh and "☯ Tương sinh (+25%)" or (preview.khac and "⚠ Tương khắc (70% thành công)" or "Bình thường")
		sub = string.format(
			"→ %s [%s]\n%s\n%s\nCần %d Mảnh Hợp Thể (có %d) • %s",
			PetUtil.petName(fake),
			PetUtil.tierInfo(preview.tier).name,
			PetUtil.elementText(preview.els),
			buffsText(fake),
			preview.shardCost,
			shards,
			relation
		)
		canFuse = shards >= preview.shardCost
	else
		sub = (reason or "") .. " • Bấm \"Chọn\" ở 2 pet bên dưới. Mảnh hợp thể: " .. shards
	end
	local fuseRow = row(nameA .. "  +  " .. nameB, sub, preview and Config.Elements[preview.els[1]].color or COLORS.purple, {
		{ "Hợp thể", COLORS.purple, function()
			if call("Fuse", state.fuseA, state.fuseB) then
				state.fuseA, state.fuseB = nil, nil
				render()
			end
		end, not canFuse },
		{ "Bỏ chọn", COLORS.gray, function()
			state.fuseA, state.fuseB = nil, nil
			render()
		end },
	})
	fuseRow.BackgroundColor3 = Color3.fromRGB(245, 235, 255)
	note("Cùng hệ → lên 1 bậc. Khác hệ → pet đa hệ giữ bậc cao nhất. Gom đủ 5 hệ để có Ngũ Hành Thần Thú!")

	header(string.format("Danh sách pet (trang bị %d/%d)", #data.equipped, Config.MaxEquippedPets))
	if #ids == 0 then
		note("Bạn chưa có pet. Ghé Cửa Hàng Pet nhé!")
	end
	for _, id in ipairs(ids) do
		local pet = data.pets[id]
		local tier = PetUtil.tierInfo(pet.tier)
		local equipped = table.find(data.equipped, id) ~= nil
		local exhibited = isExhibited(data, id)
		local status = equipped and " ✅ Đang theo" or (exhibited and " 🏛 Trưng bày" or "")
		local title = PetUtil.petName(pet) .. " [" .. tier.name .. "]" .. (pet.syn and " ☯" or "") .. status
		local petSub = "Hệ: " .. PetUtil.elementText(pet.els) .. "\n" .. buffsText(pet)
		local picked = state.fuseA == id or state.fuseB == id
		local btns = {
			equipped and { "Gỡ", COLORS.red, function() call("Unequip", id) end }
				or { "Trang bị", COLORS.green, function() call("Equip", id) end, exhibited or #data.equipped >= Config.MaxEquippedPets },
			{ picked and "Đã chọn" or "Chọn", COLORS.purple, function()
				if picked then
					if state.fuseA == id then
						state.fuseA = nil
					else
						state.fuseB = nil
					end
				elseif not state.fuseA then
					state.fuseA = id
				elseif not state.fuseB then
					state.fuseB = id
				else
					state.fuseB = id
				end
				render()
			end, equipped or exhibited },
		}
		local r = row(title, petSub, Config.Elements[pet.els[1]].color, btns, tier.color:Lerp(Color3.new(0, 0, 0), 0.25))
		if picked then
			r.BackgroundColor3 = Color3.fromRGB(235, 220, 255)
		end
	end
end

Renderers.Exhibit = function()
	local data = state.data
	panelTitle.Text = "🏛 Khu Của Bạn - Nhà Triển Lãm Chung"
	local income = 0
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		if item and item.kind == "pet" and data.pets[item.id] then
			income += PetUtil.petExhibitValue(data.pets[item.id])
		elseif item and item.kind == "crop" then
			income += PetUtil.cropExhibitValue(item.key)
		end
	end
	note(string.format("Nhà triển lãm nằm ở giữa map, mỗi người có 1 khu %d bục (khu số %s). Thu nhập: +%s xu / phút • ❤ %s lượt thích. Người khác bấm Thích khu của bạn sẽ tặng xu!", Config.ExhibitSlots, tostring(state.plotIndex or "?"), fmt(income), fmt(data.likes)))

	header("Bục trưng bày")
	for i = 1, Config.ExhibitSlots do
		local item = data.exhibit["s" .. i]
		if item and item.kind == "pet" and data.pets[item.id] then
			local pet = data.pets[item.id]
			row("Bục " .. i .. ": " .. PetUtil.petName(pet) .. " [" .. PetUtil.tierInfo(pet.tier).name .. "]", "+" .. PetUtil.petExhibitValue(pet) .. " xu / phút", Config.Elements[pet.els[1]].color, {
				{ "Gỡ", COLORS.red, function() call("Unexhibit", i) end },
			})
		elseif item and item.kind == "crop" then
			row("Bục " .. i .. ": " .. PetUtil.cropName(item.key), "+" .. PetUtil.cropExhibitValue(item.key) .. " xu / phút", cropColor(item.key), {
				{ "Gỡ", COLORS.red, function() call("Unexhibit", i) end },
			})
		else
			row("Bục " .. i .. ": (trống)", "Chọn vật phẩm bên dưới để trưng bày", Color3.fromRGB(230, 220, 200))
		end
	end

	header("Pet có thể trưng bày")
	local anyPet = false
	for _, id in ipairs(sortedPetIds(data)) do
		local pet = data.pets[id]
		if not table.find(data.equipped, id) and not isExhibited(data, id) then
			anyPet = true
			row(PetUtil.petName(pet) .. " [" .. PetUtil.tierInfo(pet.tier).name .. "]", "+" .. PetUtil.petExhibitValue(pet) .. " xu / phút", Config.Elements[pet.els[1]].color, {
				{ "Trưng bày", COLORS.blue, function() call("Exhibit", "pet", id) end },
			})
		end
	end
	if not anyPet then
		note("Không có pet rảnh (gỡ trang bị pet để trưng bày).")
	end

	header("Nông sản có thể trưng bày")
	local keys = sortedCropKeys(data)
	for _, key in ipairs(keys) do
		row(PetUtil.cropName(key) .. " x" .. data.crops[key], "+" .. PetUtil.cropExhibitValue(key) .. " xu / phút", cropColor(key), {
			{ "Trưng bày", COLORS.blue, function() call("Exhibit", "crop", key) end },
		})
	end
	if #keys == 0 then
		note("Chưa có nông sản. Nông sản đột biến (Vàng, Cầu Vồng) cho thu nhập cao!")
	end
end

----------------------------------------------------------------
-- NÚT BÊN PHẢI
----------------------------------------------------------------
local function sideButton(text, color, panelName, layout)
	button({
		Text = text,
		TextSize = 13,
		TextWrapped = true,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(64, 64),
		LayoutOrder = layout,
		Parent = sideBar,
	}, function()
		openPanel(panelName)
	end)
end
sideButton("🐾\nPet", COLORS.purple, "Pets", 1)
sideButton("🎒\nTúi", COLORS.blue, "Bag", 2)
sideButton("🏛\nTriển lãm", COLORS.gold, "Exhibit", 3)

----------------------------------------------------------------
-- HƯỚNG DẪN TÂN THỦ
----------------------------------------------------------------
local Tutorial = require(script.Parent:WaitForChild("Tutorial"))
Tutorial.init({
	gui = gui,
	request = Request,
	getState = function()
		return state
	end,
})
button({
	Text = "❓\nHướng dẫn",
	TextSize = 12,
	TextWrapped = true,
	BackgroundColor3 = COLORS.green,
	Size = UDim2.fromOffset(64, 64),
	LayoutOrder = 4,
	Parent = sideBar,
}, function()
	closePanel()
	Tutorial.restart()
end)

----------------------------------------------------------------
-- THANH CÔNG CỤ (HOTBAR)
----------------------------------------------------------------
local hotbar = new("ScrollingFrame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0.56, 0, 0, 76),
	BackgroundColor3 = COLORS.bg,
	BackgroundTransparency = 0.3,
	ScrollingDirection = Enum.ScrollingDirection.X,
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	CanvasSize = UDim2.new(),
	ScrollBarThickness = 4,
	BorderSizePixel = 0,
	Parent = gui,
}, {
	corner(12),
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	new("UISizeConstraint", { MaxSize = Vector2.new(620, 76) }),
})

local hint = label({
	Text = "",
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -92),
	Size = UDim2.new(0.8, 0, 0, 18),
	Parent = gui,
})

local function renderHotbar()
	for _, c in ipairs(hotbar:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	local data = state.data
	if not data then
		return
	end
	local items = {}
	for _, key in ipairs(Config.SeedOrder) do
		if (data.seeds[key] or 0) > 0 then
			table.insert(items, { kind = "seed", key = key, name = Config.Seeds[key].name, count = data.seeds[key], color = Config.Seeds[key].color })
		end
	end
	for _, key in ipairs(Config.FishOrder) do
		if ((data.fry or {})[key] or 0) > 0 then
			table.insert(items, { kind = "fry", key = key, name = Config.Fish[key].name, count = data.fry[key], color = Config.Fish[key].color })
		end
	end
	for _, key in ipairs(Config.GearOrder) do
		local g = Config.Gear[key]
		if g.selectable and (data.gear[key] or 0) > 0 then
			table.insert(items, { kind = "gear", key = key, name = g.name, count = data.gear[key], color = g.color, reusable = g.reusable })
		end
	end
	for i, it in ipairs(items) do
		local isSel = state.selected and state.selected.kind == it.kind and state.selected.key == it.key
		local b = button({
			Text = "",
			BackgroundColor3 = isSel and Color3.fromRGB(255, 230, 120) or COLORS.panel,
			Size = UDim2.fromOffset(64, 64),
			LayoutOrder = i,
			Parent = hotbar,
		}, function()
			if isSel then
				call("Select", nil)
			else
				call("Select", it.kind, it.key)
			end
		end)
		new("Frame", { BackgroundColor3 = it.color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(24, 24), Parent = b }, { corner(12) })
		label({ Text = it.name, TextSize = 11, TextWrapped = true, Font = Enum.Font.GothamBold, Position = UDim2.new(0, 2, 0, 30), Size = UDim2.new(1, -4, 0, 22), Parent = b })
		if not it.reusable then
			label({ Text = "x" .. it.count, TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = COLORS.red, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(30, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
		end
		if isSel then
			stroke(COLORS.gold, 3).Parent = b
		end
	end
	if #items == 0 then
		hint.Text = "Hết hạt giống & con giống! Ghé quầy 🌱 Hạt Giống hoặc 🐟 Thủy Sản"
	elseif state.selected then
		local sel = state.selected
		local name
		if sel.kind == "seed" then
			name = Config.Seeds[sel.key].name
			hint.Text = "Đang cầm: " .. name .. " — chạm vào ô đất trong nông trại của bạn"
		elseif sel.kind == "fry" then
			name = Config.Fish[sel.key].name
			hint.Text = "Đang cầm: " .. name .. " — chạm vào ao trống để thả"
		else
			name = Config.Gear[sel.key].name
			hint.Text = "Đang cầm: " .. name .. " — chạm vào cây hoặc ao của bạn"
		end
	else
		hint.Text = "Chọn hạt/con giống bên dưới rồi chạm ô đất/ao • Chạm khi chín để thu hoạch"
	end
end

----------------------------------------------------------------
-- MỞ QUẦY HÀNG KHI KÍCH HOẠT PROXIMITYPROMPT
----------------------------------------------------------------
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local name = prompt:GetAttribute("Panel")
	if name and Renderers[name] then
		if currentPanel ~= name then
			openPanel(name)
		end
	end
end)

----------------------------------------------------------------
-- NHẬN DỮ LIỆU
----------------------------------------------------------------
DataEvent.OnClientEvent:Connect(function(payload)
	state.data = payload.data
	state.stock = payload.stock or {}
	state.restockAt = payload.restockAt or 0
	state.selected = payload.selected
	state.plotIndex = payload.plotIndex
	coinLabel.Text = "💰 " .. fmt(state.data.coins)
	renderHotbar()
	render()
	Tutorial.onData(state.data)
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local data = state.data
		if data then
			local luckLeft = (data.luckUntil or 0) - os.time()
			luckLabel.Text = luckLeft > 0 and ("🍀 May mắn x2: " .. PetUtil.formatTime(luckLeft)) or ""
			if currentPanel == "SeedShop" then
				panelInfo.Text = "⏱ Nhập hàng mới sau " .. PetUtil.formatTime(state.restockAt - os.time())
			elseif currentPanel then
				panelInfo.Text = "💰 " .. fmt(data.coins) .. " xu"
			end
		end
	end
end)

-- yêu cầu dữ liệu ban đầu
task.spawn(function()
	for _ = 1, 10 do
		if state.data then
			break
		end
		pcall(function()
			Request:InvokeServer("Hello")
		end)
		task.wait(2)
	end
end)

toast("Chào mừng đến Nông Trại Ngũ Hành! 🌾", "rare")
