-- Hàm dùng chung cho pet 5 hệ (server và client đều dùng)
local Config = require(script.Parent.Config)

local PetUtil = {}

local orderIndex = {}
for i, e in ipairs(Config.ElementOrder) do
	orderIndex[e] = i
end

function PetUtil.sortElements(list)
	local seen, out = {}, {}
	for _, e in ipairs(list) do
		if Config.Elements[e] and not seen[e] then
			seen[e] = true
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		return orderIndex[a] < orderIndex[b]
	end)
	return out
end

function PetUtil.sameElements(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

function PetUtil.elementText(els)
	local names = {}
	for _, e in ipairs(els) do
		table.insert(names, Config.Elements[e].name)
	end
	return table.concat(names, " - ")
end

function PetUtil.petName(pet)
	local els = pet.els
	if #els == 5 then
		return "Thần Thú Ngũ Sắc"
	elseif #els == 1 then
		return Config.Elements[els[1]].petName
	end
	return "Linh Thú " .. PetUtil.elementText(els)
end

function PetUtil.tierInfo(tier)
	return Config.Tiers[math.clamp(tier, 1, #Config.Tiers)]
end

-- Buff của 1 pet: { Kim = 0.05, Moc = ..., } (số thập phân, 0.1 = 10%)
function PetUtil.getBuffs(pet)
	local buffs = {}
	local n = #pet.els
	local damp = 1 - 0.1 * (n - 1)
	local mult = PetUtil.tierInfo(pet.tier).mult * damp
	if pet.syn then
		mult *= (1 + Config.SynergyBonus)
	end
	for _, e in ipairs(pet.els) do
		buffs[e] = Config.Elements[e].buffBase * mult
	end
	return buffs
end

-- Tổng buff của các pet đang trang bị
function PetUtil.totalBuffs(data)
	local total = { Kim = 0, Moc = 0, Thuy = 0, Hoa = 0, Tho = 0 }
	if not data then
		return total
	end
	for _, id in ipairs(data.equipped or {}) do
		local pet = data.pets[id]
		if pet then
			for e, v in pairs(PetUtil.getBuffs(pet)) do
				total[e] += v
			end
		end
	end
	for e, cap in pairs(Config.BuffCaps) do
		total[e] = math.min(total[e], cap)
	end
	return total
end

function PetUtil.buffLines(buffs)
	local lines = {}
	for _, e in ipairs(Config.ElementOrder) do
		local v = buffs[e]
		if v and v > 0 then
			table.insert(lines, string.format("%s: +%d%% %s", Config.Elements[e].name, math.floor(v * 100 + 0.5), Config.Elements[e].buffText))
		end
	end
	return lines
end

-- Quan hệ tương sinh / tương khắc giữa 2 nhóm hệ
function PetUtil.relation(elsA, elsB)
	local sinh, khac = false, false
	for _, a in ipairs(elsA) do
		for _, b in ipairs(elsB) do
			if a ~= b then
				if Config.Sinh[a] == b or Config.Sinh[b] == a then
					sinh = true
				end
				if Config.Khac[a] == b or Config.Khac[b] == a then
					khac = true
				end
			end
		end
	end
	return sinh, khac
end

-- Xem trước kết quả hợp thể. Trả về nil, lý do nếu không được.
function PetUtil.previewFusion(a, b)
	if not a or not b then
		return nil, "Chọn đủ 2 pet"
	end
	local merged = {}
	for _, e in ipairs(a.els) do
		table.insert(merged, e)
	end
	for _, e in ipairs(b.els) do
		table.insert(merged, e)
	end
	local els = PetUtil.sortElements(merged)
	local tier
	if PetUtil.sameElements(a.els, b.els) then
		tier = math.max(a.tier, b.tier) + 1
		if tier > Config.MaxPetTier then
			return nil, "Pet đã đạt bậc tối đa"
		end
	else
		tier = math.max(a.tier, b.tier)
	end
	local sinh, khac = PetUtil.relation(a.els, b.els)
	local syn = sinh or (a.syn == true and b.syn == true)
	local result = {
		els = els,
		tier = tier,
		syn = syn,
		shardCost = tier + (#els - 1),
		chance = khac and Config.KhacSuccessChance or 1,
		sinh = sinh,
		khac = khac,
	}
	return result
end

function PetUtil.petExhibitValue(pet)
	return PetUtil.tierInfo(pet.tier).exhibitValue * #pet.els
end

-- Nông sản / thủy sản dùng chung khóa "Loai|DotBien"
function PetUtil.produceInfo(key)
	return Config.Seeds[key] or Config.Fish[key] or Config.Products[key], Config.Fish[key] ~= nil
end

-- Đếm tổng số nông sản / thủy sản cùng loại (mọi đột biến)
function PetUtil.countBase(crops, baseKey)
	local n = 0
	for key, amount in pairs(crops or {}) do
		if string.match(key, "^([^|]+)") == baseKey then
			n += amount
		end
	end
	return n
end

-- Danh sách nguyên liệu của công thức theo thứ tự cố định
function PetUtil.recipeInputs(feed)
	local list = {}
	for key, amount in pairs(feed.inputs) do
		table.insert(list, { key = key, amount = amount })
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	return list
end

function PetUtil.feedFits(feedKey, animalKey)
	local feed = Config.Feeds[feedKey]
	local animal = Config.Animals[animalKey]
	return feed ~= nil and animal ~= nil and (feed.any == true or animal.eats == feedKey)
end

function PetUtil.isFish(cropKey)
	local base = string.match(cropKey, "^([^|]+)")
	return base ~= nil and Config.Fish[base] ~= nil
end

function PetUtil.cropValue(cropKey)
	local baseKey, mutKey = string.match(cropKey, "^([^|]+)|(.+)$")
	local info = PetUtil.produceInfo(baseKey or "")
	if not info then
		return 0
	end
	local mult = 1
	for _, m in ipairs(Config.Mutations) do
		if m.key == mutKey then
			mult = m.mult
		end
	end
	return info.sell * mult
end

function PetUtil.cropName(cropKey)
	local baseKey, mutKey = string.match(cropKey, "^([^|]+)|(.+)$")
	local info = PetUtil.produceInfo(baseKey or "")
	if not info then
		return cropKey
	end
	for _, m in ipairs(Config.Mutations) do
		if m.key == mutKey then
			return info.name .. " (" .. m.name .. ")"
		end
	end
	return info.name
end

function PetUtil.cropExhibitValue(cropKey)
	return math.floor(PetUtil.cropValue(cropKey) / 40) + 1
end

function PetUtil.formatNumber(n)
	n = math.floor(n)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return (n < 0 and "-" or "") .. out
end

function PetUtil.formatTime(sec)
	sec = math.max(0, math.floor(sec))
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%d:%02d", m, s)
end

return PetUtil
