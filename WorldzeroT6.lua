-- 我爱你＾3＾xiaocui
local ALLOWED_KEY = "私人脚本"  
if _G.mySecret ~= ALLOWED_KEY then
    warn("无权访问")
    return
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local targetPlaceId = 15121292578
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local sellItems = ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("Drops", 10):WaitForChild("SellItems", 10)

local missionObjects = nil
local waveExit = nil
local isTeleportLoopRunning = false

local function waitForObject(getObjectFunc, timeout)
    local start = tick()
    while tick() - start < timeout do
        local obj = getObjectFunc()
        if obj then return obj end
        task.wait(0.1)
    end
    warn("超时未找到对象")
    return nil
end

-- 修复：角色加载容错，避免初始加载失败导致后续变量为空
local character = waitForObject(function() return localPlayer.Character end, 20) or localPlayer.CharacterAdded:Wait()
local humanoidRootPart = waitForObject(function() return character:FindFirstChild("HumanoidRootPart") end, 20)
local humanoid = waitForObject(function() return character:FindFirstChild("Humanoid") end, 20)
local rootPart = humanoidRootPart

local function isTargetPlace()
    return game.PlaceId == targetPlaceId
end

local function processInventoryItems()
    if not isTargetPlace() then return end
    local inventory = waitForObject(function()
        return localPlayer.PlayerGui:FindFirstChild("Profile")
            and localPlayer.PlayerGui.Profile:FindFirstChild("Inventory")
            and localPlayer.PlayerGui.Profile.Inventory:FindFirstChild("Items")
    end, 10)
    if not inventory then return end

    for _, item in pairs(inventory:GetChildren()) do
        if item.Name == "W10T5Staff" then
            local perk3 = item:FindFirstChild("Perk3")
            local isRetained = false
            if perk3 and perk3.Value == "Vampiric" then
                local perkValue = perk3:FindFirstChild("PerkValue")
                if perkValue and perkValue.Value >= 0.15 then
                    isRetained = true
                end
            end
            if not isRetained then
                pcall(function() sellItems:InvokeServer({item}) end)
            end
        end
    end

    for _, item in pairs(inventory:GetChildren()) do
        if item.Name == "W10T5Armor" then
            local perk3 = item:FindFirstChild("Perk3")
            local isRetained = false
            if perk3 then
                local perkValue = perk3:FindFirstChild("PerkValue")
                if perkValue then
                    if (perk3.Value == "Glass" and perkValue.Value >= 1.0) or (perk3.Value == "Destruction" and perkValue.Value >= 0.5) then
                        isRetained = true
                    end
                end
            end
            if not isRetained then
                pcall(function() sellItems:InvokeServer({item}) end)
            end
        end
    end

    local t3t4Items = {"W10T3Staff", "W10T3Armor", "W10T4Staff", "W10T4Armor"}
    for _, itemName in ipairs(t3t4Items) do
        local item = inventory:FindFirstChild(itemName)
        if item then
            pcall(function() sellItems:InvokeServer({item}) end)
        end
    end
end

spawn(function()
    while true do
        if isTargetPlace() then
            pcall(processInventoryItems)
        end
        task.wait(1)
    end
end)

spawn(function()
    while wait() do 
        if not isTargetPlace() then continue end
        
        local function sellItem(itemName)
            local itemPath = waitForObject(function()
                return localPlayer.PlayerGui:FindFirstChild("Profile")
                    and localPlayer.PlayerGui.Profile.Inventory
                    and localPlayer.PlayerGui.Profile.Inventory.Items[itemName]
            end, 3)
            if itemPath then
                pcall(function() sellItems:InvokeServer({itemPath}) end)
            end
        end

        local coList = {
            coroutine.create(function() sellItem("W9T5Spear") end),
            coroutine.create(function() sellItem("W9T3Staff") end),
            coroutine.create(function() sellItem("W9T4Armor") end),
            coroutine.create(function() sellItem("W9T4Staff") end),
            coroutine.create(function() sellItem("W9T5Armor") end),
            coroutine.create(function() sellItem("W10T3Staff") end),
            coroutine.create(function() sellItem("W10T3Armor") end),
            coroutine.create(function() sellItem("W10T4Staff") end),
            coroutine.create(function() sellItem("W10T4Armor") end)
        }

        for _, co in ipairs(coList) do
            coroutine.resume(co)
        end
    end
end)

pcall(function()
    local args = {[1] = 43}
    local bossName = "BOSSKandrix"
    local disappearThreshold = 16
    local startRaidEvent = waitForObject(function()
        return ReplicatedStorage:FindFirstChild("Shared", true)
            and ReplicatedStorage.Shared:FindFirstChild("Teleport", true)
            and ReplicatedStorage.Shared.Teleport:FindFirstChild("StartRaid")
    end, 10)

    if not startRaidEvent or not startRaidEvent:IsA("RemoteEvent") then
        warn("StartRaid event not found")
        return
    end

    local lastBossExistTime = 0
    local bossHasAppeared = false

    spawn(function()
        while true do
            if not isTargetPlace() then 
                task.wait(0.5)
                continue 
            end
            
            pcall(function()
                local bossIsAlive = Workspace:FindFirstChild("Mobs")
                    and Workspace.Mobs:FindFirstChild(bossName)
                    and Workspace.Mobs[bossName]:FindFirstChild("HealthProperties")
                    and Workspace.Mobs[bossName].HealthProperties:FindFirstChild("Health")
                    and Workspace.Mobs[bossName].HealthProperties.Health.Value > 0

                if bossIsAlive then
                    lastBossExistTime = os.clock()
                    bossHasAppeared = true
                end

                local currentTime = os.clock()
                if bossHasAppeared and currentTime - lastBossExistTime >= disappearThreshold then
                    pcall(function() startRaidEvent:FireServer(unpack(args)) end)
                    lastBossExistTime = currentTime
                    bossHasAppeared = false
                end
                task.wait(0.1)
            end)
            task.wait(0.1)
        end
    end)

    spawn(function()
        while true do
            if not isTargetPlace() then
                pcall(function() startRaidEvent:FireServer(unpack(args)) end)
            end
            task.wait(5)
        end
    end)

    local noTargetThreshold = 30
    local lastHasTargetTime = os.clock()
    spawn(function()
        while true do
            if not isTargetPlace() then
                task.wait(1)
                continue
            end

            pcall(function()
                local hasTarget = nil
                if _G.character and rootPart then
                    local mobsFolder = Workspace:FindFirstChild("Mobs")
                    if mobsFolder then
                        for _, mob in ipairs(mobsFolder:GetChildren()) do
                            local collider = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
                            local healthProps = mob:FindFirstChild("HealthProperties")
                            if collider and collider:IsA("BasePart") and healthProps then
                                local health = healthProps:FindFirstChild("Health")
                                local currentHealth = health and health.Value or 0
                                if currentHealth > 0 then
                                    hasTarget = true
                                    break
                                end
                            end
                        end
                    end
                end

                if hasTarget then
                    lastHasTargetTime = os.clock()
                else
                    local currentTime = os.clock()
                    if currentTime - lastHasTargetTime >= noTargetThreshold then
                        pcall(function() startRaidEvent:FireServer(unpack(args)) end)
                        lastHasTargetTime = currentTime
                    end
                end
            end)
            task.wait(1)
        end
    end)
end)

pcall(function()
    local attackEvent
    local function initAttackEvent()
        local success, result = pcall(function()
            return ReplicatedStorage:FindFirstChild("Shared", true)
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

    local function hasAliveTarget()
        if not _G.character or not rootPart then return nil end
        local mobsFolder = Workspace:FindFirstChild("Mobs")
        if not mobsFolder then return nil end

        for _, mob in ipairs(mobsFolder:GetChildren()) do
            local collider = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
            local healthProps = mob:FindFirstChild("HealthProperties")
            if not collider or not collider:IsA("BasePart") or not healthProps then continue end

            local health = healthProps:FindFirstChild("Health")
            local currentHealth = health and health.Value or 0
            if currentHealth > 0 then
                return true
            end
        end
        return nil
    end

    local function getNearestTargetPos()
        if not rootPart then return Vector3.new(0,0,0) end -- 修复：避免rootPart为空导致报错
        local playerPos = rootPart.Position
        local mobsFolder = Workspace:FindFirstChild("Mobs")
        if not mobsFolder then return playerPos end

        local nearestCrystalPos, crystalDist = nil, math.huge
        local nearestMobPos, mobDist = nil, math.huge

        for _, mob in ipairs(mobsFolder:GetChildren()) do
            local collider = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
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

    if attackEvent and isTargetPlace() then
        local function spawnSkillLoop(skillName, interval)
            spawn(function()
                while true do
                    if not isTargetPlace() or not hasAliveTarget() then
                        task.wait(0.5)
                        continue 
                    end
                    pcall(function()
                        attackEvent:FireServer(skillName, getNearestTargetPos(), nil, 66)
                    end)
                    task.wait(interval)
                end
            end)
        end

        local skills = {
            {"MageOfShadows", 0.7},
            {"MageOfShadowsBlast", 0.7},
            {"MageOfShadowsCharged", 0.7},
            {"MageOfShadowsBlastCharged", 0.7},
            {"BighShadowOrb1", 0.7},
            {"BighShadowOrb2", 0.7},
            {"BighShadowOrb3", 0.7},
            {"MageOfShadowsDamageCircle", 0.7},
            {"Ultimate", 4}
        }
        for _, skillData in ipairs(skills) do
            spawnSkillLoop(skillData[1], skillData[2])
        end
    end
end)

if isTargetPlace() then
    local loopInterval = 0.1
    spawn(function()
        while task.wait(loopInterval) do
            local player = game.Players.LocalPlayer
            if not player then continue end

            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then
                warn("未找到HumanoidRootPart，跳过本次循环")
                continue
            end
            local targetCFrame = humanoidRootPart.CFrame

            local coinsContainer = Workspace:FindFirstChild("Coins")
            if coinsContainer then
                for _, coin in ipairs(coinsContainer:GetChildren()) do
                    if coin and coin.Parent == coinsContainer then
                        local coinPart = coin:IsA("BasePart") and coin or coin:FindFirstChildOfClass("BasePart")
                        if coinPart then
                            coinPart.CanCollide = false
                            coinPart.CFrame = targetCFrame
                        end
                    end
                end
            end

            local goldChest = Workspace:FindFirstChild("RaidChestGold")
            if goldChest then
                local goldBase = goldChest:FindFirstChild("ChestBase")
                if goldBase then
                    local goldPart = goldBase:IsA("BasePart") and goldBase or goldBase:FindFirstChildOfClass("BasePart")
                    if goldPart then
                        goldPart.CanCollide = false
                        goldPart.CFrame = targetCFrame
                    end
                else
                    local goldPart = goldChest:IsA("BasePart") and goldChest or goldChest:FindFirstChildOfClass("BasePart")
                    if goldPart then
                        goldPart.CanCollide = false
                        goldPart.CFrame = targetCFrame
                    end
                end
            end

            local silverChest = Workspace:FindFirstChild("RaidChestSilver")
            if silverChest then
                local silverBase = silverChest:FindFirstChild("ChestBase")
                if silverBase then
                    local silverPart = silverBase:IsA("BasePart") and silverBase or silverBase:FindFirstChildOfClass("BasePart")
                    if silverPart then
                        silverPart.CanCollide = false
                        silverPart.CFrame = targetCFrame
                    end
                else
                    local silverPart = silverChest:IsA("BasePart") and silverChest or silverChest:FindFirstChildOfClass("BasePart")
                    if silverPart then
                        silverPart.CanCollide = false
                        silverPart.CFrame = targetCFrame
                    end
                end
            end
        end
    end)
end

if isTargetPlace() then
    local generalInterval = 0.01
    local waveInterval = 1
    local lastWaveSyncTime = 0
    local isMobsActive = false

    local function checkMobsStatus()
        isMobsActive = Workspace:FindFirstChild("Mobs") and #Workspace.Mobs:GetChildren() > 0 or false
    end

    local function getSetMountedEvent()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes", true)
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

    spawn(function()
        while true do
            executeMountLogic()
            task.wait(5)
        end
    end)

    local function getCharacterParts()
        local character = waitForObject(function() return localPlayer.Character end, 20)
        if not character then return nil end
        local humanoidRootPart = waitForObject(function() return character:FindFirstChild("HumanoidRootPart") end, 20)
        return humanoidRootPart
    end

    local function executeTeleportSequence()
        local humanoidRootPart = getCharacterParts()
        if not humanoidRootPart then return false end

        if not waveExit or not waveExit.Parent then return false end
        humanoidRootPart.CFrame = waveExit.CFrame
        task.wait(1)

        local nextFloorTeleporter = missionObjects:FindFirstChild("NextFloorTeleporter")
if nextFloorTeleporter and nextFloorTeleporter.Parent then
humanoidRootPart.CFrame = nextFloorTeleporter.CFrame
end
task.wait(0.5)
 
local waveStarter = missionObjects:FindFirstChild("WaveStarter")
if waveStarter and waveStarter.Parent then
humanoidRootPart.CFrame = waveStarter.CFrame
end
return true
end
 
-- 修复：将startTeleportLoop函数移出executeTeleportSequence，解决嵌套未闭合问题
local function startTeleportLoop()
missionObjects = waitForObject(function() return Workspace:FindFirstChild("MissionObjects") end, 30)
if not missionObjects then return end
 
missionObjects.ChildAdded:Connect(function(child)
if child.Name == "WaveExit" then
waveExit = child
isTeleportLoopRunning = true
task.spawn(function()
while isTeleportLoopRunning and waveExit and waveExit.Parent do
local loopContinue = executeTeleportSequence()
if not loopContinue then break end
task.wait(0.5)
end
isTeleportLoopRunning = false
end)
end
end)
 
missionObjects.ChildRemoved:Connect(function(child)
if child.Name == "WaveExit" then
waveExit = nil
isTeleportLoopRunning = false
end
end)
end
startTeleportLoop()
 
spawn(function()
while wait(generalInterval) do
pcall(function()
local currentTime = tick()
local player = localPlayer
if not player then return end
 
local character = player.Character
local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
if not humanoidRootPart then return end
local targetCFrame = humanoidRootPart.CFrame
 
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
end
end
lastWaveSyncTime = currentTime
end)
end
end)
end
 
if isTargetPlace() then
spawn(function()
while true do
pcall(function()
local getPrizeEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Missions", true)
and ReplicatedStorage.Shared.Missions:FindFirstChild("GetMissionPrize")
if getPrizeEvent and getPrizeEvent:IsA("RemoteFunction") then
getPrizeEvent:InvokeServer()
end
end)
task.wait(1)
end
end)
end
 
local textSphere = nil
local specialMesh = nil
local displayText = localPlayer.Name .. " 牛逼"
 
local function createSphere()
if textSphere or not isTargetPlace() then return end
local success = pcall(function()
textSphere = Instance.new("Part")
textSphere.Name = "PlayerIdSphere"
textSphere.Size = Vector3.new(20, 20, 20)
textSphere.Color = Color3.fromRGB(0, 0, 0)
textSphere.Material = Enum.Material.SmoothPlastic
textSphere.Anchored = false
textSphere.CanCollide = false
textSphere.Transparency = 0
textSphere.Parent = Workspace
 
specialMesh = Instance.new("SpecialMesh")
specialMesh.MeshType = Enum.MeshType.Sphere
specialMesh.Scale = Vector3.new(1, 1, 1)
specialMesh.Parent = textSphere
 
local faces = {Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}
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
end)
if not success then
textSphere = nil
specialMesh = nil
task.wait(1)
createSphere()
end
end
 
local function destroySphere()
if textSphere then
pcall(function() textSphere:Destroy() end)
textSphere = nil
specialMesh = nil
end
end
 
local function onCharacterDied()
destroySphere()
end
 
local function onCharacterAdded(newCharacter)
_G.character = newCharacter
rootPart = waitForObject(function() return newCharacter:FindFirstChild("HumanoidRootPart") end, 5)
humanoid = waitForObject(function() return newCharacter:FindFirstChild("Humanoid") end, 5)
if humanoid then
humanoid.Died:Connect(onCharacterDied)
end
task.wait(0.1)
if isTargetPlace() and rootPart and humanoid and humanoid.Health > 0 then
createSphere()
end
end
 
if humanoid then
humanoid.Died:Connect(onCharacterDied)
end
localPlayer.CharacterAdded:Connect(onCharacterAdded)
 
RunService.Heartbeat:Connect(function()
if not rootPart or not rootPart.Parent or not humanoid or humanoid.Health <= 0 or not isTargetPlace() then
destroySphere()
return
end
if isTargetPlace() then
createSphere()
if textSphere and textSphere.Parent ~= Workspace then
textSphere.Parent = Workspace
end
if textSphere then
textSphere.CFrame = rootPart.CFrame
end
else
destroySphere()
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
 
local function initPlayer()
local plr = localPlayer
_G.character = plr.Character or plr.CharacterAdded:Wait()
playerRoot = waitForObject(function() return _G.character:FindFirstChild("HumanoidRootPart") end, 5)
plr.CharacterAdded:Connect(function(newChar)
_G.character = newChar
playerRoot = waitForObject(function() return newChar:FindFirstChild("HumanoidRootPart") end, 5)
currentTarget = nil
end)
end
 
local function safeTeleport(targetPos)
if not _G.character or not playerRoot then return end
local humanoid = _G.character:FindFirstChildOfClass("Humanoid")
if humanoid then humanoid.PlatformStand = true end
task.defer(function() playerRoot.CFrame = CFrame.new(targetPos) end)
task.wait(0.05)
if humanoid then humanoid.PlatformStand = false end
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
while isRunning and CONFIG.ENABLED and isTargetPlace() do
pcall(function()
if not playerRoot then
task.wait(CONFIG.CHECK_INTERVAL)
return
end
 
local crystalSubTargets = {}
local normalTargets = {}
local mobsFolder = Workspace:FindFirstChild("Mobs")
if not mobsFolder then
currentTarget = nil
task.wait(CONFIG.CHECK_INTERVAL)
return
end
 
for _, mob in ipairs(mobsFolder:GetChildren()) do
local health = getTargetHealth(mob)
if health <= 0 then continue end
 
if mob.Name == "Crystal" then
local subCrystal = mob:FindFirstChild("Crystal")
if subCrystal and subCrystal:IsA("BasePart") then
local distance = (subCrystal.Position - playerRoot.Position).Magnitude
table.insert(crystalSubTargets, {collider = subCrystal, distance = distance})
end
end
 
local collider = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
if collider and collider:IsA("BasePart") then
local distance = (collider.Position - playerRoot.Position).Magnitude
table.insert(normalTargets, {collider = collider, distance = distance})
end
end
 
local targetList = #crystalSubTargets > 0 and crystalSubTargets or normalTargets
if #targetList == 0 then
currentTarget = nil
task.wait(CONFIG.CHECK_INTERVAL)
return
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
end)
task.wait(0.1)
end
end
 
local function init()
initPlayer()
task.spawn(targetTeleportLoop)
UserInputService.InputBegan:Connect(function(input)
if input.KeyCode == Enum.KeyCode.P then
isRunning = not isRunning
end
end)
end
 
init()
end
 
if isTargetPlace() then
local camera = Workspace.Camera
if camera then
camera.ChildAdded:Connect(function(child)
pcall(function() child:Destroy() end)
end)
for _, existingChild in pairs(camera:GetChildren()) do
pcall(function() existingChild:Destroy() end)
end
end
end
 
local function fireShadowChainLogic()
local function clearShadowChainModel()
local shadowChainModel = waitForObject(function()
return ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Effects", true)
and ReplicatedStorage.Shared.Effects:FindFirstChild("Models", true)
and ReplicatedStorage.Shared.Effects.Models:FindFirstChild("ShadowChain")
end, 8)
if shadowChainModel then
pcall(function() shadowChainModel:Destroy() end)
end
end
 
local function getShadowChainsRemote()
return waitForObject(function()
local combatShared = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Combat", true)
local mageSkillset = combatShared and combatShared:FindFirstChild("Skillsets", true)
and combatShared.Skillsets:FindFirstChild("MageOfShadows", true)
return mageSkillset and mageSkillset:FindFirstChild("ShadowChains") or nil
end, 10)
end
 
local function getAliveTargets()
local targets = {}
local mobsFolder = Workspace:FindFirstChild("Mobs")
if not mobsFolder then return targets end
 
for _, mobModel in ipairs(mobsFolder:GetChildren()) do
if mobModel:IsA("Model") then
local healthProp = mobModel:FindFirstChild("HealthProperties")
local healthValue = healthProp and healthProp:FindFirstChild("Health")
if healthValue and (healthValue:IsA("IntValue") or healthValue:IsA("NumberValue")) and healthValue.Value > 0 then
table.insert(targets, mobModel)
end
end
end
return targets
end
 
local function startChainFireLoop()
local shadowChainsRemote = getShadowChainsRemote()
if not shadowChainsRemote or not shadowChainsRemote:IsA("RemoteEvent") then
return
end
 
while true do
if not isTargetPlace() then
task.wait(2)
continue
end
 
pcall(function()
local aliveTargets = getAliveTargets()
if #aliveTargets == 0 then
task.wait(1)
return
end
 
local chainArgs = {[1] = {}}
local targetIndex = 1
local stackPerTarget = 150
 
for _, target in ipairs(aliveTargets) do
for i = 1, stackPerTarget do
chainArgs[1][targetIndex] = target
targetIndex += 1
end
end
 
shadowChainsRemote:FireServer(unpack(chainArgs))
task.wait(5)
end)
task.wait(1)
end
end
 
clearShadowChainModel()
task.spawn(startChainFireLoop)
end
 
if isTargetPlace() then
fireShadowChainLogic()
end
 
local function getInventoryItems()
local playerGui = localPlayer:WaitForChild("PlayerGui", 15)
if not playerGui then warn("PlayerGui加载超时") return nil end
local profile = playerGui:WaitForChild("Profile", 10)
if not profile then warn("Profile UI未找到") return nil end
local inventory = profile:WaitForChild("Inventory", 10)
if not inventory then warn("Inventory未找到") return nil end
return inventory:WaitForChild("Items", 10)
end
 
local buyEggEvent = nil
local hasExecutedDoubleBuy = false
local lastIsEmpty = false
local buyDelay = 0.3
 
local function initBuyEggEvent()
buyEggEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Pets", true)
and ReplicatedStorage.Shared.Pets:FindFirstChild("BuyEgg", true)
if not buyEggEvent or not buyEggEvent:IsA("RemoteEvent") then
warn("BuyEgg事件未找到或类型错误！")
buyEggEvent = nil
return false
end
return true
end
 
local function isStarEggEmpty()
local inventoryItems = getInventoryItems()
if not inventoryItems then return true end
local starEgg = inventoryItems:FindFirstChild("StarEgg")
if not starEgg then return true end
local eggCount = starEgg:FindFirstChild("Count")
local countVal = eggCount and (eggCount:IsA("NumberValue") or eggCount:IsA("IntValue")) and eggCount.Value or 1
return countVal <= 0
end
 
local function executeDoubleBuy()
if not buyEggEvent then return end
local success1 = pcall(function() buyEggEvent:FireServer("StarEgg", "Gold") end)
task.wait(buyDelay)
local success2 = pcall(function() buyEggEvent:FireServer("StarEgg", "Gold") end)
hasExecutedDoubleBuy = true
end
 
local function buyEggLoop()
while not initBuyEggEvent() do
warn("BuyEgg初始化失败，5秒后重试")
task.wait(5)
end
local resetTimer = 0
while true do
local currentIsEmpty = isStarEggEmpty()
resetTimer = resetTimer + 0.05
if currentIsEmpty and not hasExecutedDoubleBuy then
if currentIsEmpty ~= lastIsEmpty or (currentIsEmpty and resetTimer >= 1) then
executeDoubleBuy()
resetTimer = 0
end
end
if not currentIsEmpty and hasExecutedDoubleBuy then
hasExecutedDoubleBuy = false
end
lastIsEmpty = currentIsEmpty
task.wait(0.05)
end
end
spawn(buyEggLoop)
 
local function checkAndExecuteHatch()
local inventoryItems = getInventoryItems()
local starEgg = inventoryItems and inventoryItems:FindFirstChild("StarEgg")
local playerEquips = ReplicatedStorage:FindFirstChild("PlayerEquips")
local playerPetSlot = playerEquips and playerEquips:FindFirstChild(localPlayer.Name)
and playerEquips[localPlayer.Name]:FindFirstChild("Pet")
local targetPetSlot = playerPetSlot or (ReplicatedStorage:FindFirstChild("PlayerEquips")
and ReplicatedStorage.PlayerEquips:FindFirstChild("choooooose6")
and ReplicatedStorage.PlayerEquips.choooooose6:FindFirstChild("Pet"))
local equipEvent = ReplicatedStorage:FindFirstChild("Shared")
and ReplicatedStorage.Shared:FindFirstChild("Inventory")
and ReplicatedStorage.Shared.Inventory:FindFirstChild("EquipItem")
local hatchEvent = ReplicatedStorage:FindFirstChild("Shared")
and ReplicatedStorage.Shared:FindFirstChild("Pets")
and ReplicatedStorage.Shared.Pets:FindFirstChild("Hatch")
if not (starEgg and targetPetSlot and equipEvent and hatchEvent) then return end
if not Workspace:FindFirstChild("HatchEffect") then
local equipSuccess = pcall(function() equipEvent:FireServer(starEgg, targetPetSlot) end)
if not equipSuccess then pcall(function() equipEvent:FireServer(starEgg, targetPetSlot) end) end
task.wait(0.1)
pcall(function() hatchEvent:FireServer(Vector3.new(318.65887451171875, 66.26661682128906, -1602.2010498046875)) end)
end
end
spawn(function()
while true do
checkAndExecuteHatch()
task.wait(6)
end
end)
 
local targetPetNames = {"BoarwolfPet", "FoxPet", "OwlPet"}
local function checkAndSellAllTargetPets()
local inventoryItems = getInventoryItems()
if not (sellItems and inventoryItems and sellItems:IsA("RemoteFunction")) then return end
local allTargetPets = {}
for _, item in ipairs(inventoryItems:GetChildren()) do
for _, targetName in ipairs(targetPetNames) do
if item.Name == targetName then
table.insert(allTargetPets, item)
break
end
end
end
if #allTargetPets == 0 then return end
for idx, petItem in ipairs(allTargetPets) do
if not petItem:IsDescendantOf(inventoryItems) then continue end
local petName = petItem.Name
local petPerk3 = petItem:FindFirstChild("Perk3")
if not petPerk3 then
pcall(function() sellItems:InvokeServer({petItem}) end)
continue
end
if petPerk3.Value ~= "Vampiric" then
pcall(function() sellItems:InvokeServer({petItem}) end)
continue
end
local perkValue = petPerk3:FindFirstChild("PerkValue")
if not perkValue or not (perkValue:IsA("NumberValue") or perkValue:IsA("IntValue")) then
pcall(function() sellItems:InvokeServer({petItem}) end)
continue
end
local vampVal = perkValue.Value
if vampVal < 0.05 then
pcall(function() sellItems:InvokeServer({petItem}) end)
end
end
end
spawn(function()
while true do
checkAndSellAllTargetPets()
task.wait(0.5)
end
end)
 
local function handlePlayerRespawn()
local function onCharacterLoad(newChar)
_G.character = newChar
rootPart = waitForObject(function() return newChar:FindFirstChild("HumanoidRootPart") end, 10)
humanoid = waitForObject(function() return newChar:FindFirstChild("Humanoid") end, 10)
if humanoid then
humanoid.Died:Connect(onCharacterDied)
end
if isTargetPlace() and rootPart then
task.wait(0.5)
local missionStart = Workspace:FindFirstChild("MissionObjects") and Workspace.MissionObjects:FindFirstChild("MissionStart")
local startPart = missionStart and (missionStart:IsA("BasePart") or missionStart:FindFirstChildOfClass("BasePart"))
if startPart then
rootPart.CFrame = startPart.CFrame
end
createSphere()
end
end
localPlayer.CharacterAdded:Connect(onCharacterLoad)
if localPlayer.Character then
onCharacterLoad(localPlayer.Character)
end
end
handlePlayerRespawn()
 
local function autoCollectLoot()
while true do
if not isTargetPlace() or not rootPart then
task.wait(0.5)
continue
end
pcall(function()
local lootFolders = {Workspace:FindFirstChild("Loot"), Workspace:FindFirstChild("Drops")}
for _, folder in ipairs(lootFolders) do
if not folder then continue end
for _, loot in ipairs(folder:GetChildren()) do
local lootPart = loot:IsA("BasePart") or loot:FindFirstChildOfClass("BasePart")
if lootPart then
lootPart.CanCollide = false
lootPart.CFrame = rootPart.CFrame * CFrame.new(0, 1, 0)
end
end
end
end)
task.wait(0.2)
end
end
spawn(autoCollectLoot)
 
local function autoAcceptQuest()
local acceptQuestEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Quests", true)
and ReplicatedStorage.Shared.Quests:FindFirstChild("AcceptQuest")
if not (acceptQuestEvent and acceptQuestEvent:IsA("RemoteEvent")) then return end
spawn(function()
while true do
if not isTargetPlace() then
task.wait(3)
continue
end
pcall(function()
local questGivers = Workspace:FindFirstChild("NPCs") and Workspace.NPCs:GetChildren()
if not questGivers then return end
for _, npc in ipairs(questGivers) do
if npc:FindFirstChild("QuestData") then
acceptQuestEvent:FireServer(npc.Name)
end
end
end)
task.wait(10)
end
end)
end
autoAcceptQuest()
 
local function autoCompleteQuest()
local completeQuestEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Quests", true)
and ReplicatedStorage.Shared.Quests:FindFirstChild("CompleteQuest")
if not (completeQuestEvent and completeQuestEvent:IsA("RemoteEvent")) then return end
spawn(function()
while true do
if not isTargetPlace() then
task.wait(5)
continue
end
pcall(function()
completeQuestEvent:FireServer()
end)
task.wait(8)
end
end)
end
autoCompleteQuest()
 
local function autoRepairEquipment()
local repairEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Inventory", true)
and ReplicatedStorage.Shared.Inventory:FindFirstChild("RepairEquipment")
if not (repairEvent and repairEvent:IsA("RemoteFunction")) then return end
spawn(function()
while true do
if not isTargetPlace() then
task.wait(60)
continue
end
pcall(function()
local inventoryItems = getInventoryItems()
if not inventoryItems then return end
local equipItems = {"W10T5Staff", "W10T5Armor"}
for _, itemName in ipairs(equipItems) do
local item = inventoryItems:FindFirstChild(itemName)
if item then
local durability = item:FindFirstChild("Durability")
local maxDurability = item:FindFirstChild("MaxDurability")
if durability and maxDurability then
local durVal = durability.Value
local maxDurVal = maxDurability.Value
if durVal < maxDurVal * 0.3 then
repairEvent:InvokeServer(item)
end
end
end
end
end)
task.wait(30)
end
end)
end
autoRepairEquipment()
 
local function autoUsePotion()
local useItemEvent = ReplicatedStorage:FindFirstChild("Shared", true)
and ReplicatedStorage.Shared:FindFirstChild("Inventory", true)
and ReplicatedStorage.Shared.Inventory:FindFirstChild("UseItem")
if not (useItemEvent and useItemEvent:IsA("RemoteEvent")) then return end
spawn(function()
while true do
if not isTargetPlace() or not humanoid then
task.wait(1)
continue
end
pcall(function()
local healthPercent = humanoid.Health / humanoid.MaxHealth
local inventoryItems = getInventoryItems()
if not inventoryItems then return end
if healthPercent < 0.5 then
local healthPotion = inventoryItems:FindFirstChild("HealthPotion")
if healthPotion then
useItemEvent:FireServer(healthPotion)
end
end
local mana = humanoid:FindFirstChild("Mana")
local maxMana = humanoid:FindFirstChild("MaxMana")
if mana and maxMana then
local manaPercent = mana.Value / maxMana.Value
if manaPercent < 0.3 then
local manaPotion = inventoryItems:FindFirstChild("ManaPotion")
if manaPotion then
useItemEvent:FireServer(manaPotion)
end
end
end
end)
task.wait(2)
end
end)
end
autoUsePotion()
 
local function resetWaveExitState()
while true do
if not isTargetPlace() then
task.wait(2)
continue
end
pcall(function()
local missionObjects = Workspace:FindFirstChild("MissionObjects")
if not missionObjects then return end
local waveExit = missionObjects:FindFirstChild("WaveExit")
if not waveExit then return end
local exitPart = waveExit:IsA("BasePart") and waveExit or waveExit:FindFirstChildOfClass("BasePart")
if exitPart then
exitPart.CanCollide = true
local originalCFrame = exitPart:FindFirstChild("OriginalCFrame")
if originalCFrame and originalCFrame:IsA("CFrameValue") then
exitPart.CFrame = originalCFrame.Value
end
end
end)
task.wait(10)
end
end
spawn(resetWaveExitState)
 
local function initWaveExitOriginalPos()
if not isTargetPlace() then return end
pcall(function()
local missionObjects = Workspace:FindFirstChild("MissionObjects")
if not missionObjects then return end
local waveExit = missionObjects:FindFirstChild("WaveExit")
if not waveExit then return end
local exitPart = waveExit:IsA("BasePart") and waveExit or waveExit:FindFirstChildOfClass("BasePart")
if exitPart and not exitPart:FindFirstChild("OriginalCFrame") then
local cframeVal = Instance.new("CFrameValue")
cframeVal.Name = "OriginalCFrame"
cframeVal.Value = exitPart.CFrame
cframeVal.Parent = exitPart
end
end)
end
initWaveExitOriginalPos()
localPlayer.CharacterAdded:Connect(initWaveExitOriginalPos)
 
