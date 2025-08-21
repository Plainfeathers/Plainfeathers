
pcall(function()
    local args = { [1] = 43 }
    local bossName = "BOSSKandrix"
    local disappearThreshold = 12
    local targetPlaceId = 15121292578

    local function getStartRaidEvent()
        return game:GetService("ReplicatedStorage"):FindFirstChild("Shared", true)
            and game:GetService("ReplicatedStorage").Shared:FindFirstChild("Teleport", true)
            and game:GetService("ReplicatedStorage").Shared.Teleport:FindFirstChild("StartRaid")
    end
    local startRaidEvent = getStartRaidEvent()

    if not startRaidEvent or not startRaidEvent:IsA("RemoteEvent") then
        warn("StartRaid event not found")
        return
    end

    local lastBossExistTime = 0
    local bossHasAppeared = false

    spawn(function()
        while true do
            local bossIsAlive = workspace:FindFirstChild("Mobs")
                and workspace.Mobs:FindFirstChild(bossName)
                and workspace.Mobs[bossName]:FindFirstChild("HealthProperties")
                and workspace.Mobs[bossName].HealthProperties:FindFirstChild("Health")
                and workspace.Mobs[bossName].HealthProperties.Health.Value > 0

            if bossIsAlive then
                lastBossExistTime = os.clock()
                bossHasAppeared = true
            end

            local currentTime = os.clock()
            if bossHasAppeared and currentTime - lastBossExistTime >= disappearThreshold then
                pcall(function()
                    startRaidEvent:FireServer(unpack(args))
                    print("BOSS appeared then disappeared, executing StartRaid")
                end)
                lastBossExistTime = currentTime
            end

            task.wait(0.1)
        end
    end)

    spawn(function()
        while true do
            if game.PlaceId ~= targetPlaceId then
                pcall(function()
                    startRaidEvent:FireServer(unpack(args))
                    print("Non-target place detected, triggering rejoin (Place ID: " .. game.PlaceId .. ")")
                end)
            end
            task.wait(5)
        end
    end)

    print("BOSS appearance-disappearance detection initiated (with non-target place rejoin)")
end)

local TARGET_PLACE_ID = 15121292578
local function isTargetPlace()
    return game.PlaceId == TARGET_PLACE_ID
end

if isTargetPlace() then
    spawn(function()
        local targetBossNames = {"BOSSKandrix", "MiniBossCrystalWeaver"}
        local processedBosses = {}
        local shadowChains = nil

        local function getShadowChainsEvent()
            if not shadowChains then
                shadowChains = game:GetService("ReplicatedStorage"):FindFirstChild("Shared", true)
                    and game:GetService("ReplicatedStorage").Shared:FindFirstChild("Combat", true)
                    and game:GetService("ReplicatedStorage").Shared.Combat:FindFirstChild("Skillsets", true)
                    and game:GetService("ReplicatedStorage").Shared.Combat.Skillsets:FindFirstChild("MageOfShadows", true)
                    and game:GetService("ReplicatedStorage").Shared.Combat.Skillsets.MageOfShadows:FindFirstChild("ShadowChains")
            end
            return shadowChains and shadowChains:IsA("RemoteEvent") and shadowChains or nil
        end

        pcall(function()
            local model = game:GetService("ReplicatedStorage").Shared.Effects.Models:FindFirstChild("ShadowChain")
            if model then
                model:Destroy()
                print("已删除模型：ShadowChain")
            end
        end)

        while true do
            if not getShadowChainsEvent() then
                task.wait(1)
                continue
            end

            local mobsFolder = workspace:FindFirstChild("Mobs")
            if not mobsFolder then
                task.wait(0.5)
                continue
            end

            local currentBosses = {}
            for _, child in ipairs(mobsFolder:GetChildren()) do
                if child:IsA("Model") and table.find(targetBossNames, child.Name) then
                    local health = child:FindFirstChild("HealthProperties")
                        and child.HealthProperties:FindFirstChild("Health")
                        and child.HealthProperties.Health.Value or 0
                    if health > 0 then
                        table.insert(currentBosses, child)
                    end
                end
            end

            local newBosses = {}
            for _, boss in ipairs(currentBosses) do
                if not table.find(processedBosses, boss) then
                    table.insert(newBosses, boss)
                    table.insert(processedBosses, boss)
                end
            end

            if #newBosses > 0 then
                local args = {[1] = {}}
                local index = 1
                local stackTimes = 200

                for _, boss in ipairs(newBosses) do
                    for i = 1, stackTimes do
                        args[1][index] = boss
                        index += 1
                    end
                end

                pcall(function()
                    getShadowChainsEvent():FireServer(unpack(args))
                    print("对新BOSS释放技能，数量：" .. #newBosses)
                end)
            end

            for i = #processedBosses, 1, -1 do
                local boss = processedBosses[i]
                if not boss or not boss:IsDescendantOf(workspace) then
                    table.remove(processedBosses, i)
                end
            end

            task.wait(0.2)
        end
    end)
end

pcall(function()
    local function getNearestTargetPos()
        local playerPos = game.Players.LocalPlayer.Character
            and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            and game.Players.LocalPlayer.Character.HumanoidRootPart.Position
            or Vector3.new(0, 5, 0)

        local mobsFolder = workspace:FindFirstChild("Mobs")
        if not mobsFolder then return playerPos end

        local nearestCrystalPos, crystalDist = nil, math.huge
        local nearestMobPos, mobDist = nil, math.huge

        for _, mob in ipairs(mobsFolder:GetChildren()) do
            local collider = mob:FindFirstChild("Collider")
            local healthProps = mob:FindFirstChild("HealthProperties")
            if not collider or not collider:IsA("BasePart") or not healthProps then continue end

            local health = healthProps:FindFirstChild("Health")
            local currentHealth = health and health.Value or 0
            if currentHealth <= 0 then continue end

            local dist = (playerPos - collider.Position).Magnitude
            if mob.Name == "Crystal" and dist < crystalDist then
                crystalDist, nearestCrystalPos = dist, collider.Position
            elseif dist < mobDist then
                mobDist, nearestMobPos = dist, collider.Position
            end
        end
        return nearestCrystalPos or nearestMobPos or playerPos
    end

    local attackEvent
    local function initAttackEvent()
        local success, result = pcall(function()
            return game:GetService("ReplicatedStorage"):FindFirstChild("Shared", true)
                :FindFirstChild("Combat", true)
                :FindFirstChild("Attack")
        end)
        return success and result and result:IsA("RemoteEvent") and result or nil
    end

    local retryCount = 0
    while not attackEvent and retryCount < 5 do
        attackEvent = initAttackEvent()
        retryCount += 1
        if not attackEvent then task.wait(1) end
    end
    if attackEvent and isTargetPlace() then
        local function spawnSkillLoop(skillName, interval)
            spawn(function()
                while true do
                    pcall(function()
                        attackEvent:FireServer(skillName, getNearestTargetPos(), nil, 66)
                    end)
                    task.wait(interval)
                end
            end)
        end

        local skills = {
            {"MageOfShadows", 0.35},
            {"MageOfShadowsBlast", 0.35},
            {"MageOfShadowsCharged", 0.35},
            {"MageOfShadowsBlastCharged", 0.35},
            {"BighShadowOrb1", 0.35},
            {"BighShadowOrb2", 0.35},
            {"BighShadowOrb3", 0.35},
            {"MageOfShadowsDamageCircle", 0.35},
            {"Ultimate", 2}
        }
        for _, skillData in ipairs(skills) do
            spawnSkillLoop(skillData[1], skillData[2])
        end
    end
end)

if isTargetPlace() then
    local generalInterval = 0.01
    local chestInterval = 0.1
    local waveInterval = 1
    local lastWaveSyncTime, lastChestSyncTime, lastMountCallTime = 0, 0, 0
    local mountCooldown = 5
    local isMobsActive = false
    local cachedGoldChests, cachedSilverChests = {}, {}

    local function initChestCache()
        local possibleContainers = {workspace, workspace:FindFirstChild("Chests"), workspace:FindFirstChild("MissionObjects")}
        for _, container in ipairs(possibleContainers) do
            if container then
                for _, child in ipairs(container:GetChildren()) do
                    if child.Name == "RaidChestGold" then
                        table.insert(cachedGoldChests, child)
                    elseif child.Name == "RaidChestSilver" then
                        table.insert(cachedSilverChests, child)
                    end
                end
            end
        end
    end

    local function checkMobsStatus()
        isMobsActive = workspace:FindFirstChild("Mobs") and #workspace.Mobs:GetChildren() > 0 or false
    end

    local function updateExistingChests(chestList, targetCFrame)
        for i = #chestList, 1, -1 do
            local chest = chestList[i]
            if not chest or not chest.Parent then
                table.remove(chestList, i)
                continue
            end
            local part = chest:IsA("BasePart") and chest or chest:FindFirstChildOfClass("BasePart")
            if part then
                part.CanCollide = false
                part.CFrame = targetCFrame
            end
        end
    end

    local function getSetMountedEvent()
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes", true)
        return remotes and remotes:FindFirstChild("SetMounted") or nil
    end

    local function executeMountLogic()
        local setMounted = getSetMountedEvent()
        if setMounted and setMounted:IsA("RemoteEvent") then
            pcall(function() setMounted:FireServer(true) end)
            task.spawn(function()
                task.wait(0.001)
                pcall(function() setMounted:FireServer(false) end)
            end)
        end
    end

    initChestCache()

    spawn(function()
        while task.wait(generalInterval) do
            local currentTime = tick()
            local player = game.Players.LocalPlayer
            if not player then continue end

            local character = player.Character
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then continue end
            local targetCFrame = humanoidRootPart.CFrame

            local coinsContainer = workspace:FindFirstChild("Coins")
            if coinsContainer then
                for _, coin in ipairs(coinsContainer:GetChildren()) do
                    local coinPart = coin:IsA("BasePart") and coin or coin:FindFirstChildOfClass("BasePart")
                    if coinPart then
                        coinPart.CanCollide = false
                        coinPart.CFrame = targetCFrame
                    end
                end
            end

            if currentTime - lastChestSyncTime >= chestInterval then
                updateExistingChests(cachedGoldChests, targetCFrame)
                updateExistingChests(cachedSilverChests, targetCFrame)
                lastChestSyncTime = currentTime
            end

            local missionObjects = workspace:FindFirstChild("MissionObjects")
            if missionObjects then
                local missionStart = missionObjects:FindFirstChild("MissionStart")
                if missionStart then
                    local startPart = missionStart:IsA("BasePart") and missionStart or missionStart:FindFirstChildOfClass("BasePart")
                    if startPart then
                        startPart.CanCollide = false
                        startPart.CFrame = targetCFrame
                    end
                end

                local bossDoorTrigger = missionObjects:FindFirstChild("BossDoorTrigger")
                if bossDoorTrigger then
                    local doorPart = bossDoorTrigger:IsA("BasePart") and bossDoorTrigger or bossDoorTrigger:FindFirstChildOfClass("BasePart")
                    if doorPart then
                        doorPart.CanCollide = false
                        doorPart.CFrame = targetCFrame
                    end
                end

                checkMobsStatus()
                if currentTime - lastWaveSyncTime >= waveInterval then
                    local waveExit = missionObjects:FindFirstChild("WaveExit")
                    if waveExit then
                        local exitPart = waveExit:IsA("BasePart") and waveExit or waveExit:FindFirstChildOfClass("BasePart")
                        if exitPart then
                            exitPart.CanCollide = false
                            exitPart.CFrame = targetCFrame
                        end
                        if currentTime - lastMountCallTime >= mountCooldown then
                            executeMountLogic()
                            lastMountCallTime = currentTime
                        end
                    else
                        if not isMobsActive then
                            local nextFloorTele = missionObjects:FindFirstChild("NextFloorTeleporter")
                            if nextFloorTele then
                                local telePart = nextFloorTele:IsA("BasePart") and nextFloorTele or nextFloorTele:FindFirstChildOfClass("BasePart")
                                if telePart then
                                    telePart.CanCollide = false
                                    telePart.CFrame = targetCFrame
                                end
                            end
                            local waveStarter = missionObjects:FindFirstChild("WaveStarter")
                            if waveStarter then
                                local wavePart = waveStarter:IsA("BasePart") and waveStarter or waveStarter:FindFirstChildOfClass("BasePart")
                                if wavePart then
                                    wavePart.CanCollide = false
                                    wavePart.CFrame = targetCFrame
                                end
                            end
                        end
                    end
                    lastWaveSyncTime = currentTime
                end
            end
        end
    end)
end

if isTargetPlace() then
    local chestSync = {interval = 0.7, targetCFrame = CFrame.new(0, 5, 0)}

    local function findAllChests(name)
        local results = {}
        local function search(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == name then table.insert(results, child) end
                search(child)
            end
        end
        search(workspace)
        return results
    end

    local function syncChest(chest, targetCFrame)
        if not chest or not chest.Parent then return false end
        local basePart = chest:FindFirstChild("ChestBase")
        local chestPart = basePart and (basePart:IsA("BasePart") and basePart or basePart:FindFirstChildOfClass("BasePart"))
            or (chest:IsA("BasePart") and chest or chest:FindFirstChildOfClass("BasePart"))
        if chestPart then
            chestPart.CanCollide = false
            chestPart.CFrame = targetCFrame
            return true
        end
        return false
    end

    local function syncAllGoldChests(targetCFrame)
        local goldChests = findAllChests("RaidChestGold")
        local successCount = 0
        for _, chest in ipairs(goldChests) do
            if syncChest(chest, targetCFrame) then successCount += 1 end
        end
        return successCount
    end

    local function syncAllSilverChests(targetCFrame)
        local silverChests = findAllChests("RaidChestSilver")
        local successCount = 0
        for _, chest in ipairs(silverChests) do
            if syncChest(chest, targetCFrame) then successCount += 1 end
        end
        return successCount
    end

    spawn(function()
        while task.wait(chestSync.interval) do
            local player = game.Players.LocalPlayer
if player and player.Character then
local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
if humanoidRootPart then chestSync.targetCFrame = humanoidRootPart.CFrame end
end
syncAllGoldChests(chestSync.targetCFrame)
syncAllSilverChests(chestSync.targetCFrame)
end
end)
end
 
if isTargetPlace() then
spawn(function()
while wait() do
pcall(function()
game:GetService("ReplicatedStorage").Shared.Missions.GetMissionPrize:InvokeServer()
end)
end
end)
end
 
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
 
local targetPlaceId = 15121292578
 
local textSphere = nil
local specialMesh = nil
 
local displayText = player.Name .. " 牛逼"
 
local function createSphere()
if textSphere then return end
 
textSphere = Instance.new("Part")
textSphere.Name = "PlayerIdSphere"
textSphere.Size = Vector3.new(20, 20, 20)
textSphere.Color = Color3.fromRGB(0, 0, 0)
textSphere.Material = Enum.Material.SmoothPlastic
textSphere.Anchored = false
textSphere.CanCollide = false
textSphere.Transparency = 0
textSphere.Parent = workspace
 
specialMesh = Instance.new("SpecialMesh")
specialMesh.MeshType = Enum.MeshType.Sphere
specialMesh.Scale = Vector3.new(1, 1, 1)
specialMesh.Parent = textSphere
 
local faces = {
Enum.NormalId.Top,
Enum.NormalId.Bottom,
Enum.NormalId.Front,
Enum.NormalId.Back,
Enum.NormalId.Left,
Enum.NormalId.Right
}
 
for _, face in ipairs(faces) do
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Adornee = textSphere
surfaceGui.Face = face
surfaceGui.Parent = textSphere
 
local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundTransparency = 1
frame.Parent = surfaceGui
 
for i = 1, 5 do
for j = 1, 5 do
local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0.2, 0, 0.2, 0)
textLabel.Position = UDim2.new((i - 1) * 0.2, 0, (j - 1) * 0.2, 0)
textLabel.BackgroundTransparency = 1
textLabel.Text = displayText
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextScaled = true
textLabel.Font = Enum.Font.SourceSansBold
textLabel.Parent = frame
end
end
end
end
 
local function destroySphere()
if textSphere then
textSphere:Destroy()
textSphere = nil
specialMesh = nil
end
end
 
local function onCharacterDied()
destroySphere()
end
 
local function onCharacterAdded(newCharacter)
character = newCharacter
rootPart = newCharacter:WaitForChild("HumanoidRootPart")
humanoid = newCharacter:WaitForChild("Humanoid")
humanoid.Died:Connect(onCharacterDied)
end
 
humanoid.Died:Connect(onCharacterDied)
player.CharacterAdded:Connect(onCharacterAdded)
 
game:GetService("RunService").Heartbeat:Connect(function()
if rootPart and humanoid and humanoid.Health > 0 then
local currentPlaceId = game.PlaceId
 
if currentPlaceId == targetPlaceId then
createSphere()
if textSphere then
textSphere.CFrame = rootPart.CFrame
end
else
destroySphere()
end
else
destroySphere()
end
end)
 
spawn(function()
while wait() do
local function sellItem(itemName)
local player = game:GetService("Players").LocalPlayer
local itemPath = player.PlayerGui.Profile.Inventory.Items[itemName]
game:GetService("ReplicatedStorage").Shared.Drops.SellItems:InvokeServer({itemPath})
end
 
local co7 = coroutine.create(function() sellItem("W10T3Staff") end)
local co8 = coroutine.create(function() sellItem("W10T3Armor") end)
local co9 = coroutine.create(function() sellItem("W10T4Staff") end)
local co10 = coroutine.create(function() sellItem("W10T4Armor") end)
 
coroutine.resume(co7)
coroutine.resume(co8)
coroutine.resume(co9)
coroutine.resume(co10)
end
end)
 
if isTargetPlace() then
local CONFIG = {
ENABLED = true,
CHECK_INTERVAL = 0.1,
DISTANCE_THRESHOLD = 1.5,
HEALTH_PATH = "HealthProperties.Health",
SAFE_TELEPORT = true
}
 
local currentTarget = nil
local playerRoot = nil
local isRunning = true
local character = nil
 
local function initPlayer()
local plr = game.Players.LocalPlayer
character = plr.Character or plr.CharacterAdded:Wait()
playerRoot = character:WaitForChild("HumanoidRootPart", 5)
 
plr.CharacterAdded:Connect(function(newChar)
character = newChar
playerRoot = newChar:WaitForChild("HumanoidRootPart")
currentTarget = nil
end)
end
 
local function safeTeleport(targetPos)
if not character or not playerRoot then return end
 
local humanoid = character:FindFirstChildOfClass("Humanoid")
if humanoid then
humanoid.PlatformStand = true
end
 
task.defer(function()
playerRoot.CFrame = CFrame.new(targetPos)
end)
 
task.wait(0.05)
if humanoid then
humanoid.PlatformStand = false
end
end
 
local function getTargetHealth(mob)
local pathParts = string.split(CONFIG.HEALTH_PATH, ".")
local current = mob
for _, part in ipairs(pathParts) do
current = current:FindFirstChild(part)
if not current then return 0 end
end
return (current:IsA("IntValue") or current:IsA("NumberValue")) and current.Value or 0
end
 
local function targetTeleportLoop()
while isRunning and CONFIG.ENABLED do
local crystalSubTargets = {}
local normalTargets = {}
local mobsFolder = workspace:FindFirstChild("Mobs")
 
if not mobsFolder then
currentTarget = nil
task.wait(CONFIG.CHECK_INTERVAL)
continue
end
 
for _, mob in ipairs(mobsFolder:GetChildren()) do
local health = getTargetHealth(mob)
if health <= 0 then continue end
 
if mob.Name == "Crystal" then
local subCrystal = mob:FindFirstChild("Crystal")
if subCrystal and subCrystal:IsA("BasePart") then
local collider = subCrystal
local distance = (collider.Position - playerRoot.Position).Magnitude
table.insert(crystalSubTargets, {
collider = collider,
distance = distance
})
end
end
 
local collider = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
if collider and collider:IsA("BasePart") then
local distance = (collider.Position - playerRoot.Position).Magnitude
table.insert(normalTargets, {
collider = collider,
distance = distance
})
end
end
 
local targetList = #crystalSubTargets > 0 and crystalSubTargets or normalTargets
 
if #targetList == 0 then
currentTarget = nil
task.wait(CONFIG.CHECK_INTERVAL)
continue
end
 
table.sort(targetList, function(a, b) return a.distance < b.distance end)
local nearest = targetList[1]
 
if nearest.distance > CONFIG.DISTANCE_THRESHOLD then
local targetPos = nearest.collider.Position
if CONFIG.SAFE_TELEPORT then
safeTeleport(targetPos)
else
playerRoot.CFrame = CFrame.new(targetPos)
end
currentTarget = nearest
end
 
task.wait(CONFIG.CHECK_INTERVAL)
end
end
 
local function init()
initPlayer()
task.spawn(targetTeleportLoop)
 
game:GetService("UserInputService").InputBegan:Connect(function(input)
if input.KeyCode == Enum.KeyCode.P then
isRunning = false
end
end)
end
 
init()
end
 
local replicatedStorage = game:GetService("ReplicatedStorage")
local sellItems = replicatedStorage.Shared.Drops.SellItems
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local inventory = localPlayer.PlayerGui.Profile.Inventory.Items
 
for _, item in pairs(inventory:GetChildren()) do
if item.Name == "W10T5Staff" then
if item and item.Perk3 then
if item.Perk3.Value == "Vampiric" and item.Perk3.PerkValue and item.Perk3.PerkValue.Value >= 0.15 then
print("W10T5Staff 保留（Vampiric值达标）")
else
sellItems:InvokeServer({item})
print("W10T5Staff 出售（Vampiric不达标或无此属性）")
end
else
sellItems:InvokeServer({item})
print("W10T5Staff 出售（物品或Perk3缺失）")
end
elseif item.Name == "W10T5Armor" then
if item and item.Perk3 then
local isSelfValid = item.Perk3.Value == "Self Destruct" and item.Perk3.PerkValue and item.Perk3.PerkValue.Value >= 0.5
local isGlassValid = item.Perk3.Value == "Glass" and item.Perk3.PerkValue and item.Perk3.PerkValue.Value >= 1.0
if isSelfValid or isGlassValid then
print("W10T5Armor 保留（Self Destruct/Glass值达标）")
else
sellItems:InvokeServer({item})
print("W10T5Armor 出售（属性不达标或无目标属性）")
end
else
sellItems:InvokeServer({item})
print("W10T5Armor 出售（物品或Perk3缺失）")
end
end
end
