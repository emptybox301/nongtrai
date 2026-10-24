-- Cấu hình toàn bộ game Nông Trại
-- Sửa số liệu ở đây để cân bằng game.

local Config = {}

Config.StartCoins = 100
Config.RestockSeconds = 300 -- cửa hàng hạt giống làm mới mỗi 5 phút
Config.MaxEquippedPets = 3
Config.MaxPlayers = 5 -- mỗi server tối đa 5 người (5 nông trại)
Config.ExhibitSlots = 3 -- số bục của mỗi người trong Nhà Triển Lãm chung
Config.MaxPetTier = 5
Config.LikeCooldown = 300 -- giây, mỗi người chỉ thích 1 triển lãm 1 lần / 5 phút
Config.ExhibitIncomeInterval = 60 -- giây
Config.DataStoreName = "NongTraiNguHanh_v1"
Config.TutorialReward = 200 -- xu thưởng khi hoàn thành hướng dẫn

----------------------------------------------------------------
-- NGŨ HÀNH
----------------------------------------------------------------
Config.ElementOrder = { "Kim", "Moc", "Thuy", "Hoa", "Tho" }

Config.Elements = {
	Kim = {
		name = "Kim",
		color = Color3.fromRGB(225, 225, 235),
		petName = "Hổ Kim",
		buffBase = 0.05,
		buffText = "giá bán nông sản",
	},
	Moc = {
		name = "Mộc",
		color = Color3.fromRGB(70, 185, 75),
		petName = "Thỏ Lá",
		buffBase = 0.06,
		buffText = "tốc độ lớn của cây",
	},
	Thuy = {
		name = "Thủy",
		color = Color3.fromRGB(60, 135, 235),
		petName = "Rùa Nước",
		buffBase = 0.04,
		buffText = "cơ hội thu hoạch x2 & thủy sản lớn nhanh",
	},
	Hoa = {
		name = "Hỏa",
		color = Color3.fromRGB(235, 85, 45),
		petName = "Cáo Lửa",
		buffBase = 0.10,
		buffText = "may mắn ra nông sản đột biến",
	},
	Tho = {
		name = "Thổ",
		color = Color3.fromRGB(190, 140, 70),
		petName = "Chuột Đất",
		buffBase = 0.05,
		buffText = "cơ hội hoàn lại hạt / con giống / thức ăn",
	},
}

-- Tương sinh: A sinh B
Config.Sinh = { Moc = "Hoa", Hoa = "Tho", Tho = "Kim", Kim = "Thuy", Thuy = "Moc" }
-- Tương khắc: A khắc B
Config.Khac = { Moc = "Tho", Tho = "Thuy", Thuy = "Hoa", Hoa = "Kim", Kim = "Moc" }

Config.SynergyBonus = 0.25 -- pet hợp thể tương sinh mạnh thêm 25%
Config.KhacSuccessChance = 0.7 -- hợp thể tương khắc chỉ thành công 70%
Config.BuffCaps = { Thuy = 1.0, Tho = 0.9 }

Config.Tiers = {
	{ name = "Thường", mult = 1, color = Color3.fromRGB(200, 200, 200), exhibitValue = 5 },
	{ name = "Hiếm", mult = 2.2, color = Color3.fromRGB(80, 170, 255), exhibitValue = 15 },
	{ name = "Sử Thi", mult = 4, color = Color3.fromRGB(180, 90, 255), exhibitValue = 40 },
	{ name = "Huyền Thoại", mult = 6.5, color = Color3.fromRGB(255, 180, 40), exhibitValue = 100 },
	{ name = "Thần Thoại", mult = 10, color = Color3.fromRGB(255, 70, 110), exhibitValue = 250 },
}

----------------------------------------------------------------
-- HẠT GIỐNG
----------------------------------------------------------------
Config.SeedOrder = { "CaRot", "LuaMi", "CaChua", "Bap", "DuaHau", "BiNgo", "ThanhLong", "SenVang" }

Config.Seeds = {
	CaRot = { name = "Cà Rốt", price = 10, grow = 20, sell = 18, color = Color3.fromRGB(255, 140, 30), appear = 1.0, stock = { 10, 20 } },
	LuaMi = { name = "Lúa Mì", price = 25, grow = 40, sell = 45, color = Color3.fromRGB(235, 205, 90), appear = 1.0, stock = { 8, 15 } },
	CaChua = { name = "Cà Chua", price = 60, grow = 60, sell = 110, color = Color3.fromRGB(230, 50, 50), appear = 0.9, stock = { 5, 12 } },
	Bap = { name = "Bắp", price = 150, grow = 90, sell = 280, color = Color3.fromRGB(255, 220, 60), appear = 0.8, stock = { 4, 10 } },
	DuaHau = { name = "Dưa Hấu", price = 400, grow = 150, sell = 750, color = Color3.fromRGB(60, 160, 60), appear = 0.6, stock = { 3, 6 } },
	BiNgo = { name = "Bí Ngô", price = 1000, grow = 240, sell = 1900, color = Color3.fromRGB(240, 120, 20), appear = 0.45, stock = { 2, 5 } },
	ThanhLong = { name = "Thanh Long", price = 2500, grow = 360, sell = 4800, color = Color3.fromRGB(235, 60, 140), appear = 0.3, stock = { 1, 3 } },
	SenVang = { name = "Sen Vàng", price = 8000, grow = 600, sell = 16000, color = Color3.fromRGB(255, 200, 40), appear = 0.15, stock = { 1, 2 } },
}

-- Đột biến nông sản (xét theo thứ tự, hiếm nhất trước)
Config.Mutations = {
	{ key = "CauVong", name = "Cầu Vồng", chance = 0.003, mult = 15, color = Color3.fromRGB(200, 90, 255) },
	{ key = "Vang", name = "Vàng", chance = 0.015, mult = 5, color = Color3.fromRGB(255, 215, 0) },
	{ key = "KhongLo", name = "Khổng Lồ", chance = 0.06, mult = 2 },
}

----------------------------------------------------------------
-- THỦY SẢN (con giống thả vào ao, mỗi ao cho nhiều con khi thu hoạch)
----------------------------------------------------------------
Config.PondCount = 4
Config.FishOrder = { "CaRoPhi", "TomCang", "CaChep", "Cua", "CaKoi", "CaRongVang" }

Config.Fish = {
	CaRoPhi = { name = "Cá Rô Phi", price = 40, grow = 60, sell = 25, yield = { 2, 4 }, color = Color3.fromRGB(150, 160, 170), appear = 1.0, stock = { 6, 12 }, shape = "fish" },
	TomCang = { name = "Tôm Càng", price = 120, grow = 120, sell = 60, yield = { 3, 5 }, color = Color3.fromRGB(240, 120, 90), appear = 0.9, stock = { 4, 8 }, shape = "shrimp" },
	CaChep = { name = "Cá Chép", price = 350, grow = 200, sell = 220, yield = { 2, 3 }, color = Color3.fromRGB(230, 170, 60), appear = 0.75, stock = { 3, 6 }, shape = "fish" },
	Cua = { name = "Cua", price = 900, grow = 300, sell = 420, yield = { 2, 4 }, color = Color3.fromRGB(200, 70, 50), appear = 0.55, stock = { 2, 4 }, shape = "crab" },
	CaKoi = { name = "Cá Koi", price = 3000, grow = 480, sell = 2600, yield = { 1, 3 }, color = Color3.fromRGB(250, 250, 250), appear = 0.3, stock = { 1, 3 }, shape = "fish" },
	CaRongVang = { name = "Cá Rồng Vàng", price = 10000, grow = 720, sell = 9000, yield = { 1, 2 }, color = Color3.fromRGB(255, 190, 40), appear = 0.12, stock = { 1, 1 }, shape = "fish" },
}

----------------------------------------------------------------
-- CHUỒNG GIA SÚC
-- Gia súc mua 1 lần, nuôi mãi. Mỗi lần cho ăn = 1 lượt sản xuất.
----------------------------------------------------------------
Config.PenCount = 3
Config.AnimalOrder = { "Ga", "Vit", "Cuu", "Bo" }

Config.Animals = {
	Ga = { name = "Gà", price = 500, product = "TrungGa", time = 90, yield = { 2, 3 }, eats = "ThucAnHat", color = Color3.fromRGB(250, 250, 245), shape = "bird" },
	Vit = { name = "Vịt", price = 1500, product = "TrungVit", time = 150, yield = { 2, 3 }, eats = "ThucAnHat", color = Color3.fromRGB(250, 220, 90), shape = "bird" },
	Cuu = { name = "Cừu", price = 4500, product = "LongCuu", time = 300, yield = { 1, 3 }, eats = "CoKhoTron", color = Color3.fromRGB(240, 240, 235), shape = "sheep" },
	Bo = { name = "Bò", price = 12000, product = "SuaBo", time = 420, yield = { 1, 2 }, eats = "CoKhoTron", color = Color3.fromRGB(245, 245, 245), shape = "cow" },
}

-- Sản phẩm gia súc (bán ở quầy Bán Hàng như nông sản)
Config.ProductOrder = { "TrungGa", "TrungVit", "LongCuu", "SuaBo" }
Config.Products = {
	TrungGa = { name = "Trứng Gà", sell = 90, color = Color3.fromRGB(245, 225, 190) },
	TrungVit = { name = "Trứng Vịt", sell = 200, color = Color3.fromRGB(200, 230, 225) },
	LongCuu = { name = "Lông Cừu", sell = 900, color = Color3.fromRGB(250, 250, 250) },
	SuaBo = { name = "Sữa Bò", sell = 2600, color = Color3.fromRGB(255, 255, 255) },
}

-- THỨC ĂN TỰ CHẾ TẠO tại Bàn Chế Tạo trong chuồng.
-- inputs: { [mã nông sản / thủy sản] = số lượng } (đột biến nào cũng dùng được, ưu tiên loại thường)
Config.FeedOrder = { "ThucAnHat", "CoKhoTron", "ThucAnCaoCap" }
Config.Feeds = {
	ThucAnHat = {
		name = "Thức Ăn Hạt",
		desc = "Cho Gà, Vịt",
		inputs = { LuaMi = 3, CaRot = 2 },
		output = 2,
		color = Color3.fromRGB(220, 190, 110),
	},
	CoKhoTron = {
		name = "Cỏ Khô Trộn",
		desc = "Cho Cừu, Bò",
		inputs = { LuaMi = 3, Bap = 2 },
		output = 2,
		color = Color3.fromRGB(170, 190, 80),
	},
	ThucAnCaoCap = {
		name = "Thức Ăn Cao Cấp",
		desc = "Cho mọi con vật, sản phẩm x2",
		inputs = { BiNgo = 1, CaChua = 2, CaRoPhi = 2 },
		output = 1,
		any = true,
		mult = 2,
		color = Color3.fromRGB(230, 120, 200),
	},
}

----------------------------------------------------------------
-- CỬA HÀNG DỤNG CỤ (GEAR)
----------------------------------------------------------------
Config.GearOrder = { "ManhHopThe", "BinhTuoi", "PhanBon", "Xeng", "ThucAnCa", "BuaMayMan" }

Config.Gear = {
	ManhHopThe = { name = "Mảnh Hợp Thể", price = 300, desc = "Nguyên liệu để hợp thể 2 pet", selectable = false, color = Color3.fromRGB(170, 100, 255) },
	BinhTuoi = { name = "Bình Tưới", price = 50, desc = "Chạm vào cây: giảm 25% thời gian còn lại", selectable = true, color = Color3.fromRGB(80, 170, 255) },
	PhanBon = { name = "Phân Bón", price = 150, desc = "Chạm vào cây: thu hoạch x2 sản lượng", selectable = true, color = Color3.fromRGB(130, 90, 50) },
	Xeng = { name = "Xẻng", price = 100, desc = "Dùng mãi mãi. Chạm cây để nhổ, chạm ao để xả ao, chạm chuồng để đưa con vật về túi", selectable = true, reusable = true, color = Color3.fromRGB(150, 150, 160) },
	ThucAnCa = { name = "Thức Ăn Cá", price = 80, desc = "Chạm vào ao: giảm 30% thời gian, +1 con khi thu hoạch", selectable = true, color = Color3.fromRGB(220, 180, 110) },
	BuaMayMan = { name = "Bùa May Mắn", price = 800, desc = "Dùng trong Túi: x2 may mắn đột biến trong 10 phút", selectable = false, color = Color3.fromRGB(80, 220, 120) },
}
Config.LuckCharmSeconds = 600

----------------------------------------------------------------
-- CỬA HÀNG PET
----------------------------------------------------------------
Config.BasicPetPrice = 1500

return Config
