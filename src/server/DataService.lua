-- Lưu / tải dữ liệu người chơi bằng DataStore
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
local profiles = {} -- [player] = data
local canSave = {} -- [player] = bool

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] Không mở được DataStore:", result)
	end
end

local function defaultData()
	return {
		coins = Config.StartCoins,
		seeds = { CaRot = 3 },
		gear = {},
		crops = {},
		pets = {},
		equipped = {},
		exhibit = {},
		plots = {},
		fry = { CaRoPhi = 1 }, -- con giống thủy sản
		ponds = {}, -- trạng thái ao nuôi
		likes = 0,
		nextPetId = 1,
		luckUntil = 0,
		tutorial = 1, -- bước hướng dẫn đang làm (0 = đã xong)
		tutorialRewarded = false,
	}
end

local function reconcile(data)
	local def = defaultData()
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

function DataService.load(player)
	local data, ok = nil, false
	if store then
		for _ = 1, 3 do
			local success, result = pcall(function()
				return store:GetAsync("Player_" .. player.UserId)
			end)
			if success then
				ok = true
				data = result
				break
			end
			task.wait(1)
		end
	end
	if type(data) ~= "table" then
		data = defaultData()
	end
	profiles[player] = reconcile(data)
	canSave[player] = ok
	return profiles[player], ok
end

function DataService.get(player)
	return profiles[player]
end

function DataService.save(player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	local success, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, data)
	end)
	if not success then
		warn("[DataService] Lưu thất bại cho", player.Name, err)
	end
end

function DataService.release(player)
	DataService.save(player)
	profiles[player] = nil
	canSave[player] = nil
end

function DataService.all()
	return profiles
end

-- tự lưu mỗi 2 phút
task.spawn(function()
	while true do
		task.wait(120)
		for player in pairs(profiles) do
			task.spawn(DataService.save, player)
		end
	end
end)

game:BindToClose(function()
	for player in pairs(profiles) do
		DataService.save(player)
	end
end)

return DataService
