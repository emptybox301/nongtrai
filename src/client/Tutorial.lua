-- HƯỚNG DẪN TÂN THỦ
-- Khung chỉ dẫn từng bước + tia sáng chỉ đường tới đúng chỗ cần đến.
-- Bước có điều kiện sẽ tự chuyển khi người chơi làm xong.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local Tutorial = {}

local ctx -- { gui, request, getState }
local step = nil -- bước hiện tại (nil = chưa tải, 0 = đã xong)
local stepStart = {} -- số liệu lúc bắt đầu bước (để so sánh)
local ui: any = {}
local guide: any = {}

----------------------------------------------------------------
-- TÌM VỊ TRÍ TRONG MAP
----------------------------------------------------------------
local function world()
	return workspace:FindFirstChild("World")
end

local function findPath(...)
	local node = world()
	for _, name in ipairs({ ... }) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

local function myPlot()
	local s = ctx.getState()
	if not s.plotIndex then
		return nil
	end
	return findPath("Plots", "Plot" .. s.plotIndex)
end

local function plotPart(...)
	local plot = myPlot()
	local node = plot
	for _, name in ipairs({ ... }) do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function shopCounter(panelName)
	return findPath("Shops", panelName, "Counter")
end

local function firstKey(t)
	for k in pairs(t or {}) do
		return k
	end
	return nil
end

local function total(t)
	local n = 0
	for _, v in pairs(t or {}) do
		n += v
	end
	return n
end

----------------------------------------------------------------
-- CÁC BƯỚC
-- cond(data) trả về true khi bước đã hoàn thành; không có cond = bấm nút "Tiếp"
----------------------------------------------------------------
local STEPS = {
	{
		title = "🌾 Chào mừng đến Nông Trại!",
		text = "Đây là nông trại của riêng bạn: 24 ô đất để trồng cây và 4 ao để nuôi cá. Mình sẽ hướng dẫn bạn vài bước đầu tiên nhé!",
		button = "Bắt đầu",
		target = function()
			return plotPart("OwnerSign")
		end,
	},
	{
		title = "🌱 Trồng cây đầu tiên",
		text = "Bấm vào Cà Rốt ở thanh bên dưới màn hình, rồi chạm vào một ô đất nâu trong nông trại để gieo hạt.",
		target = function()
			return plotPart("Tiles", "Tile1", "Soil")
		end,
		cond = function(data)
			return next(data.plots) ~= nil or next(data.crops) ~= nil
		end,
	},
	{
		title = "⏳ Chờ cây lớn rồi thu hoạch",
		text = "Cây cần một lúc để lớn (xem đồng hồ trên đầu cây). Khi hiện \"Sẵn sàng!\" thì chạm vào cây để thu hoạch.",
		target = function(data)
			local key = firstKey(data.plots)
			local idx = key and string.match(key, "%d+") or "1"
			return plotPart("Tiles", "Tile" .. idx, "Soil")
		end,
		cond = function(data)
			return next(data.crops) ~= nil
		end,
	},
	{
		title = "💰 Bán nông sản",
		text = "Đi theo tia sáng tới quầy 💰 Bán Hàng trên đường chính, bấm nút tương tác rồi chọn \"Bán hết\".",
		target = function()
			return shopCounter("Sell")
		end,
		onStart = function(data)
			stepStart.coins = data.coins
		end,
		cond = function(data)
			return next(data.crops) == nil and data.coins > (stepStart.coins or math.huge)
		end,
	},
	{
		title = "🛒 Mua thêm hạt giống",
		text = "Tới quầy 🌱 Hạt Giống và mua thêm hạt. Hạt đắt hơn lớn lâu hơn nhưng bán được nhiều xu hơn. Cửa hàng nhập hàng mới mỗi 5 phút!",
		target = function()
			return shopCounter("SeedShop")
		end,
		onStart = function(data)
			stepStart.seeds = total(data.seeds)
		end,
		cond = function(data)
			return total(data.seeds) > (stepStart.seeds or math.huge)
		end,
	},
	{
		title = "🐟 Nuôi thủy sản",
		text = "Bạn được tặng 1 con Cá Rô Phi! Chọn nó ở thanh dưới rồi chạm vào một ao phía sau nông trại để thả. (Hết con giống thì mua ở quầy 🐟 Thủy Sản.)",
		target = function(data)
			if total(data.fry) == 0 then
				return shopCounter("FishShop")
			end
			return plotPart("Ponds", "Pond1", "Rim")
		end,
		cond = function(data)
			return next(data.ponds) ~= nil
		end,
	},
	{
		title = "🐾 Pet ngũ hành",
		text = "Ở quầy 🐾 Cửa Hàng Pet có 5 pet theo Kim, Mộc, Thủy, Hỏa, Thổ. Mỗi hệ cho một buff riêng. Mua Mảnh Hợp Thể ở quầy 🛠 Dụng Cụ để hợp thể 2 pet thành pet mạnh hơn (nút 🐾 Pet bên phải).",
		button = "Tiếp",
		target = function()
			return shopCounter("PetShop")
		end,
	},
	{
		title = "🏛 Nhà Triển Lãm Chung",
		text = "Mỗi người có 1 khu 3 bục trong nhà triển lãm ở giữa map. Trưng bày pet hoặc nông sản quý (nút 🏛 bên phải) để nhận xu mỗi phút, và ghé khu của bạn bè bấm ❤ nhé!",
		button = "Tiếp",
		target = function()
			return findPath("ExhibitionHall", "Banner")
		end,
	},
	{
		title = "🎉 Bạn đã sẵn sàng!",
		text = "Hoàn thành hướng dẫn, nhận thưởng 200 xu! Muốn xem lại thì bấm nút ❓ bên phải màn hình. Chúc bạn làm giàu vui vẻ!",
		button = "Nhận thưởng",
		finish = true,
	},
}
Tutorial.STEP_COUNT = #STEPS

----------------------------------------------------------------
-- GIAO DIỆN
----------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function buildUI()
	local card = new("Frame", {
		Name = "TutorialCard",
		Visible = false,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 10, 0, 78),
		Size = UDim2.new(0.42, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(255, 248, 225),
		ZIndex = 20,
	}, ctx.gui)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
	new("UIStroke", { Color = Color3.fromRGB(240, 180, 50), Thickness = 3 }, card)
	new("UISizeConstraint", { MaxSize = Vector2.new(380, 400), MinSize = Vector2.new(250, 0) }, card)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, card)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, card)

	local function text(props, order)
		props.BackgroundTransparency = 1
		props.Size = UDim2.new(1, 0, 0, 0)
		props.AutomaticSize = Enum.AutomaticSize.Y
		props.TextWrapped = true
		props.TextXAlignment = Enum.TextXAlignment.Left
		props.LayoutOrder = order
		props.ZIndex = 21
		return new("TextLabel", props, card)
	end
	ui.progress = text({ Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(190, 130, 30), Text = "" }, 1)
	ui.title = text({ Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = Color3.fromRGB(70, 50, 35), Text = "" }, 2)
	ui.body = text({ Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = Color3.fromRGB(90, 70, 55), Text = "" }, 3)

	local bar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 4, ZIndex = 21 }, card)
	local function btn(textValue, color, pos, anchor, size)
		local b = new("TextButton", {
			Text = textValue,
			Font = Enum.Font.FredokaOne,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = color,
			AnchorPoint = anchor,
			Position = pos,
			Size = size,
			ZIndex = 22,
		}, bar)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		return b
	end
	ui.next = btn("Tiếp", Color3.fromRGB(80, 185, 90), UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5), UDim2.fromOffset(110, 32))
	ui.skip = btn("Bỏ qua", Color3.fromRGB(170, 160, 150), UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5), UDim2.fromOffset(80, 28))
	ui.skip.TextSize = 12
	ui.waiting = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = "Làm theo hướng dẫn để tiếp tục...",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(80, 160, 90),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(1, -90, 1, 0),
		ZIndex = 22,
	}, bar)
	ui.card = card

	ui.next.Activated:Connect(function()
		local info = step and STEPS[step]
		if info and info.button then
			Tutorial.advance()
		end
	end)
	ui.skip.Activated:Connect(function()
		Tutorial.finish(false)
	end)

	-- tia sáng chỉ đường + mũi tên trên mục tiêu
	local folder = new("Folder", { Name = "TutorialGuide" }, workspace)
	guide.target = new("Attachment", { Name = "TutorialTarget" }, workspace.Terrain)
	guide.beam = new("Beam", {
		Attachment1 = guide.target,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80)),
		LightEmission = 1,
		Width0 = 0.5,
		Width1 = 0.5,
		FaceCamera = true,
		Segments = 20,
		CurveSize0 = 0,
		Transparency = NumberSequence.new(0.2),
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3,
		TextureSpeed = 2,
		Enabled = false,
	}, folder)
	guide.marker = new("BillboardGui", {
		Adornee = guide.target,
		Size = UDim2.fromOffset(70, 70),
		AlwaysOnTop = true,
		StudsOffset = Vector3.new(0, 6, 0),
		Enabled = false,
	}, folder)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "⬇",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 80),
		TextStrokeTransparency = 0,
	}, guide.marker)
	TweenService:Create(guide.marker, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		StudsOffset = Vector3.new(0, 8, 0),
	}):Play()
end

local function attachToCharacter()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (not guide.from or guide.from.Parent ~= hrp) then
		guide.from = new("Attachment", { Name = "TutorialFrom", Position = Vector3.new(0, -1, 0) }, hrp)
		guide.beam.Attachment0 = guide.from
	end
	return hrp
end

local function updateGuide()
	local s = ctx.getState()
	local info = step and step > 0 and STEPS[step]
	local targetPart = info and info.target and s.data and info.target(s.data)
	if not targetPart or not targetPart:IsA("BasePart") then
		guide.beam.Enabled = false
		guide.marker.Enabled = false
		return
	end
	guide.target.WorldPosition = targetPart.Position + Vector3.new(0, targetPart.Size.Y / 2 + 0.5, 0)
	guide.marker.Enabled = true
	local hrp = attachToCharacter()
	local close = hrp and (hrp.Position - targetPart.Position).Magnitude < 12
	guide.beam.Enabled = hrp ~= nil and not close
end

local function render()
	if not step or step == 0 then
		ui.card.Visible = false
		updateGuide()
		return
	end
	local info = STEPS[step]
	ui.card.Visible = true
	ui.progress.Text = string.format("HƯỚNG DẪN %d/%d", step, #STEPS)
	ui.title.Text = info.title
	ui.body.Text = info.text
	ui.next.Visible = info.button ~= nil
	ui.next.Text = info.button or ""
	ui.waiting.Visible = info.button == nil
	ui.skip.Visible = not info.finish
	updateGuide()
end

local function enterStep(n)
	step = n
	stepStart = {}
	local s = ctx.getState()
	local info = STEPS[n]
	if info and info.onStart and s.data then
		info.onStart(s.data)
	end
	render()
	-- bước đã đạt sẵn (vd. người chơi cũ) thì chuyển luôn
	if info and info.cond and s.data and info.cond(s.data) then
		task.defer(Tutorial.advance)
	end
end

-- lưu bước lên server (gộp nhiều lần lưu liên tiếp thành 1 lần gửi)
local pendingSave = nil
local pendingCompleted = false
local function save(n, completed)
	pendingSave = n
	pendingCompleted = completed == true
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
function Tutorial.advance()
	if not step or step == 0 then
		return
	end
	local info = STEPS[step]
	if info.finish then
		Tutorial.finish(true)
		return
	end
	local n = step + 1
	save(n)
	enterStep(n)
end

function Tutorial.finish(completed)
	step = 0
	save(0, completed)
	render()
end

function Tutorial.restart()
	save(1)
	enterStep(1)
end

-- gọi mỗi khi nhận dữ liệu mới từ server
function Tutorial.onData(data)
	if step == nil then
		local saved = tonumber(data.tutorial) or 0
		if saved > #STEPS then
			saved = 0
		end
		enterStep(saved)
		return
	end
	local info = step > 0 and STEPS[step]
	if info and info.cond and info.cond(data) then
		Tutorial.advance()
	else
		render()
	end
end

function Tutorial.init(options)
	ctx = options
	buildUI()
	task.spawn(function()
		while true do
			task.wait(0.5)
			if pendingSave ~= nil then
				local n, completed = pendingSave, pendingCompleted
				pendingSave = nil
				local ok, success = pcall(function()
					return ctx.request:InvokeServer("SetTutorial", n, completed)
				end)
				if not ok or not success then
					if pendingSave == nil then
						pendingSave = n -- thử lại lần sau
					end
				end
			end
			if step and step > 0 then
				updateGuide()
			end
		end
	end)
end

return Tutorial
