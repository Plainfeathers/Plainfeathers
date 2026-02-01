??local CONFIG = {
    ALLOWED_PLACE_ID = 13988110964,
    START_DELAY = 0.1,
    EXCLUDE_TARGET = "EVENTBOSSKraken",
    STATUS_NAME = "Slowdown",
    DELAY_AFTER_STATUS_LOST = 15,
    LOOP_INTERVAL_STATUS = 0.1,
    STACK_TIMES = 250,
    CHAIN_COOLDOWN = 0.8,
    MODELS_TO_DELETE = {
        {ParentPath = "ReplicatedStorage.Shared.Effects.Models", Name = "ShadowChain"},
        {ParentPath = "ReplicatedStorage.Shared.Effects.Models", Name = "DamageNumber"}
    },
    SKILL_EVENT_PATH_STATUS = "ReplicatedStorage.Shared.Combat.Skillsets.MageOfShadows.ShadowChains",
    SKILL_EVENT_PATH_ATTACK = "ReplicatedStorage.Shared.Combat.Attack",
    ATTACK_SKILLS = {
        {Name = "MageOfShadows", Interval = 0.55}, {Name = "MageOfShadowsBlast", Interval = 0.55},
        {Name = "MageOfShadowsCharged", Interval = 0.55}, {Name = "MageOfShadowsBlastCharged", Interval = 0.55},
        {Name = "BighShadowOrb0.55", Interval = 0.55}, {Name = "BighShadowOrb2", Interval = 0.55},
        {Name = "BighShadowOrb3", Interval = 0.55}, {Name = "MageOfShadowsDamageCircle", Interval = 0.55}
    },
    ATTACK_ARG_4 = 67,
    ATTACK_RETRY_DELAY = 0.1,
    ATTACK_MAX_RETRY = 999,
    ROTATE_LOOP_INTERVAL = 1,
    ROTATION_SPEED = 1,
    RADIUS = 30,
    EXCLUDE_FOLDERS = {"Checkpoints", "FallAreas", "DamageDroppers", "FallBricks", "Darts"},
    EXCLUDE_KEYWORDS = {"wall", "tree", "spike"},
    ALLOWED_CLASSES = {["Part"] = true, ["Model"] = true},
    AETHER_KING_PATH = "Mobs.AetherKing",
    TELEPORT_EVENT_PATH = "Shared.Teleport.StartRaid",
    TELEPORT_ARGS = {33, 1},
    TELEPORT_DELAY = 1,
    HEIGHT_OFFSET = 20
}
local Player = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local FlightConstraints = {}
_G.CombatSystemRunning = false
_G.StatusModuleRunning = false
_G.AttackModuleRunning = false
_G.RotateModuleRunning = false
_G.AetherKingDetected = false
_G.LastCycleAllHadSlowdown = false
_G.RotateCurrentTarget = nil
_G.HasDetectedTarget = false
_G.ChainLastFireTime = 0
local ModuleThreads = {}
local IsScriptInited = false
local MissionTimerTeleportConn = nil
local currentPlaceID = game.PlaceId
if currentPlaceID ~= CONFIG.ALLOWED_PLACE_ID then
    return
end
local function createFlightMode(rootPart)
    for _, constraint in pairs(FlightConstraints) do if constraint and constraint.Parent then constraint:Destroy() end end
    FlightConstraints = {}
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "CombatFlightVel"
    bodyVel.Velocity = Vector3.new(0, 0, 0)
    bodyVel.MaxForce = Vector3.new(0, 100000, 0)
    bodyVel.P = 500
    bodyVel.Parent = rootPart
    table.insert(FlightConstraints, bodyVel)
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "CombatFlightGyro"
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.MaxTorque = Vector3.new(0, 100000, 0)
    bodyGyro.P = 500
    bodyGyro.Parent = rootPart
    table.insert(FlightConstraints, bodyGyro)
end
local Services = {}
local function initCoreServices()
    local requiredServices = {"ReplicatedStorage", "Workspace", "Players", "RunService"}
    for _, serviceName in ipairs(requiredServices) do
        local service = game:GetService(serviceName)
        if service then
            Services[serviceName] = service
        end
    end
    while not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") do
        task.wait(0.1)
    end
    Player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart")
        task.wait(1)
        if _G.CombatSystemRunning then 
            createFlightMode(char.HumanoidRootPart)
            char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
            _G.HasDetectedTarget = false
            _G.ChainLastFireTime = 0
        end
    end)
    IsScriptInited = true
end
initCoreServices()
local function findInstanceByPath(root, path, maxRetry)
    root = root or game
    maxRetry = maxRetry or 3
    local retry = 0
    while retry < maxRetry do
        local instance = root
        local success = true
        for _, name in ipairs(string.split(path, ".")) do
            instance = instance:FindFirstChild(name, true)
            if not instance then success = false; break end
        end
        if success then return instance end
        task.wait(0.2)
        retry += 1
    end
    return nil
end
local function deleteTargetModels()
    for _, cfg in ipairs(CONFIG.MODELS_TO_DELETE) do
        local parent = findInstanceByPath(game, cfg.ParentPath)
        if parent then
            local model = parent:FindFirstChild(cfg.Name)
            if model then 
                pcall(function() model:Destroy() end)
            end
        end
    end
end
local function getNearestTargetPos()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then
        return Vector3.new(0,0,0)
    end
    local myPos = Player.Character.HumanoidRootPart.Position
    local nearestPos = myPos
    local closestDist = math.huge
    local mobsFolder = Services.Workspace:FindFirstChild("Mobs", true)
    if not mobsFolder then return nearestPos end
    for _, mob in ipairs(mobsFolder:GetChildren()) do
        local collider = mob:FindFirstChild("Collider")
        local healthProps = mob:FindFirstChild("HealthProperties")
        if collider and collider:IsA("BasePart") and healthProps and mob.Name ~= CONFIG.EXCLUDE_TARGET then
            local currentHealth = healthProps:FindFirstChild("Health") and healthProps.Health.Value or 0
            if currentHealth > 0 then
                local mobPos = collider.Position
                local dist = (myPos - mobPos).Magnitude
                if dist < closestDist then closestDist = dist; nearestPos = mobPos end
            end
        end
    end
    return nearestPos
end
local function isChainOnCooldown()
    return os.clock() - _G.ChainLastFireTime < CONFIG.CHAIN_COOLDOWN
end
local function isExcludedFolder(name)
    for _, excludeName in ipairs(CONFIG.EXCLUDE_FOLDERS) do if name == excludeName then return true end end
    return false
end
local function hasTriggerInName(obj) return string.lower(obj.Name):find("trigger") ~= nil end
local function isExcludedByKeyword(obj)
    local lowerName = string.lower(obj.Name)
    for _, keyword in ipairs(CONFIG.EXCLUDE_KEYWORDS) do if lowerName:find(keyword) then return true end end
    return false
end
local function isAllowedClass(obj) return CONFIG.ALLOWED_CLASSES[obj.ClassName] == true end
local function teleportPlayerToMissionTimer()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    local HumanoidRootPart = Player.Character.HumanoidRootPart
    local MissionTimer = Services.Workspace:FindFirstChild("MissionObjects") 
        and Services.Workspace.MissionObjects:FindFirstChild("MissionStart") 
        and Services.Workspace.MissionObjects.MissionStart:FindFirstChild("MissionTimer")
    if MissionTimer then
        local targetCFrame
        if MissionTimer:IsA("BasePart") then
            targetCFrame = MissionTimer.CFrame
        else
            local mtRoot = MissionTimer:FindFirstChildOfClass("PrimaryPart") or MissionTimer:FindFirstChildOfClass("BasePart")
            if mtRoot and mtRoot:IsA("BasePart") then
                targetCFrame = mtRoot.CFrame
            end
        end
        if targetCFrame then
            HumanoidRootPart.CFrame = targetCFrame + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
        end
    end
end
local function startPlayerTeleportToMissionTimer()
    if MissionTimerTeleportConn then MissionTimerTeleportConn:Disconnect() end
    MissionTimerTeleportConn = RunService.Heartbeat:Connect(function()
        teleportPlayerToMissionTimer()
    end)
end
local function stopPlayerTeleportToMissionTimer()
    if MissionTimerTeleportConn then
        MissionTimerTeleportConn:Disconnect()
        MissionTimerTeleportConn = nil
    end
end
local function rotateAroundTarget()
    if not Player.Character then return end
    local humanoidRootPart = Player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    local humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.PlatformStand = true end
    if humanoidRootPart:IsA("BasePart") then
        humanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(0, 0, 0)
    end
    local mobsFolder = Services.Workspace:FindFirstChild("Mobs")
    if not mobsFolder then return end
    if _G.RotateCurrentTarget then
        local healthProps = _G.RotateCurrentTarget:FindFirstChild("HealthProperties")
        local health = healthProps and healthProps:FindFirstChild("Health")
        if not health or health.Value <= 0 then
            _G.RotateCurrentTarget = nil
        end
    end
    if not _G.RotateCurrentTarget then
        local nearestMob = nil
        local nearestDist = math.huge
        local playerPos = humanoidRootPart.Position
        for _, mob in ipairs(mobsFolder:GetChildren()) do
            local healthProps = mob:FindFirstChild("HealthProperties")
            local health = healthProps and healthProps:FindFirstChild("Health")
            if not health or health.Value <= 0 then continue end
            local mobPart = mob:FindFirstChild("Collider") or mob:FindFirstChildOfClass("BasePart")
            if mobPart and mobPart:IsA("BasePart") then
                local dist = (mobPart.Position - playerPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestMob = mob
                end
            end
        end
        _G.RotateCurrentTarget = nearestMob
    end
    if _G.RotateCurrentTarget then
        local mobPart = _G.RotateCurrentTarget:FindFirstChild("Head") or _G.RotateCurrentTarget:FindFirstChild("Collider") or _G.RotateCurrentTarget:FindFirstChildOfClass("BasePart")
        if mobPart and mobPart:IsA("BasePart") then
            local targetPos = mobPart.Position + Vector3.new(0, 5 + CONFIG.HEIGHT_OFFSET, 0)
            local angle = tick() * CONFIG.ROTATION_SPEED * math.pi * 2
            local rotatedPos = Vector3.new(
                targetPos.X + math.cos(angle) * CONFIG.RADIUS,
                targetPos.Y,
                targetPos.Z + math.sin(angle) * CONFIG.RADIUS
            )
            local lookAtCFrame = CFrame.lookAt(rotatedPos, targetPos)
            humanoidRootPart.CFrame = lookAtCFrame
        end
    end
end
local function teleportTargets()
    if not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then return end
    local humanoidRootPart = Player.Character.HumanoidRootPart
    local playerCFrame = humanoidRootPart.CFrame
    local MissionObjects = Services.Workspace:FindFirstChild("MissionObjects")
    local WaveExit = MissionObjects and MissionObjects:FindFirstChild("WaveExit")
    if WaveExit and WaveExit:IsA("BasePart") then
        WaveExit.CFrame = playerCFrame
    end
    local MissionStart = MissionObjects and MissionObjects:FindFirstChild("MissionStart")
    if MissionStart then
        local msRoot = MissionStart:FindFirstChildOfClass("PrimaryPart") or MissionStart:FindFirstChildOfClass("BasePart")
        if msRoot and msRoot:IsA("BasePart") then
            msRoot.CFrame = playerCFrame
        elseif MissionStart:IsA("BasePart") then
            MissionStart.CFrame = playerCFrame
        end
    end
    local MissionStartCollider = MissionStart and MissionStart:FindFirstChild("Collider")
    if MissionStartCollider and MissionStartCollider:IsA("BasePart") then
        MissionStartCollider.CFrame = playerCFrame
    end
    local WaveStarter = MissionObjects and MissionObjects:FindFirstChild("WaveStarter")
    if WaveStarter and WaveStarter:IsA("BasePart") then
        WaveStarter.CFrame = playerCFrame
    end
    local targetCFrame = playerCFrame
    local coinsContainer = Services.Workspace:FindFirstChild("Coins")
    if coinsContainer then
        for _, coin in ipairs(coinsContainer:GetChildren()) do
            if coin and coin.Parent == coinsContainer then
                local targetObj = coin:IsA("BasePart") and coin or coin:FindFirstChildOfClass("BasePart")
                if targetObj and isAllowedClass(targetObj) and not isExcludedByKeyword(targetObj) then
                    targetObj.CanCollide = false; targetObj.CFrame = targetCFrame
                end
            end
        end
    end
    local lobbyTeleport = Services.Workspace:FindFirstChild("LobbyTeleport")
    if lobbyTeleport then
        local interaction = lobbyTeleport:FindFirstChild("Interaction")
        if interaction then
            local targetObj = interaction:IsA("BasePart") and interaction or interaction:FindFirstChildOfClass("BasePart")
            if targetObj and isAllowedClass(targetObj) and not isExcludedByKeyword(targetObj) then
                targetObj.CanCollide = false; targetObj.CFrame = targetCFrame
            end
        end
    end
    local bossGate = Services.Workspace:FindFirstChild("Boss_Gate")
    if bossGate then
        local interactions = bossGate:FindFirstChild("Interactions")
        if interactions then
            local bounds = interactions:FindFirstChild("Bounds")
            if bounds then
                local targetObj = bounds:IsA("BasePart") and bounds or bounds:FindFirstChildOfClass("BasePart")
                if targetObj and isAllowedClass(targetObj) and not isExcludedByKeyword(targetObj) then
                    targetObj.CanCollide = false; targetObj.CFrame = targetCFrame
                end
            end
        end
    end
    if MissionObjects then
        for _, child in ipairs(MissionObjects:GetChildren()) do
            if not isExcludedFolder(child.Name) and child ~= WaveExit and child ~= MissionStart and child ~= WaveStarter then
                for _, obj in ipairs(child:GetDescendants()) do
                    if isAllowedClass(obj) and not isExcludedByKeyword(obj) then
                        if obj:IsA("BasePart") then
                            obj.CanCollide = false; obj.CFrame = targetCFrame
                        elseif obj:IsA("Model") then
                            for _, part in ipairs(obj:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false; part.CFrame = targetCFrame
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    local mobBlockersFolder = Services.Workspace:FindFirstChild("MobBlockers")
    if mobBlockersFolder then
        for _, obj in ipairs(mobBlockersFolder:GetDescendants()) do
            if isAllowedClass(obj) and not isExcludedByKeyword(obj) then
                if obj:IsA("BasePart") then
                    obj.CanCollide = false; obj.CFrame = targetCFrame
                elseif obj:IsA("Model") then
                    for _, part in ipairs(obj:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false; part.CFrame = targetCFrame
                        end
                    end
                end
            end
        end
    end
    for _, obj in ipairs(Services.Workspace:GetDescendants()) do
        if hasTriggerInName(obj) and isAllowedClass(obj) and not isExcludedByKeyword(obj) then
            if obj:IsA("BasePart") then
                obj.CanCollide = false; obj.CFrame = targetCFrame
            elseif obj:IsA("Model") then
                for _, part in ipairs(obj:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false; part.CFrame = targetCFrame
                    end
                end
            end
        end
    end
end
local function runRotateTeleportCycle()
    _G.RotateModuleRunning = true
    while _G.CombatSystemRunning do
        task.wait(CONFIG.ROTATE_LOOP_INTERVAL)
        pcall(function()
            teleportTargets()
            rotateAroundTarget()
        end)
    end
    _G.RotateModuleRunning = false
end
local function runStatusDetectionCycle()
    _G.StatusModuleRunning = true
    local skillEvent = findInstanceByPath(game, CONFIG.SKILL_EVENT_PATH_STATUS, 5)
    if skillEvent and skillEvent:IsA("RemoteEvent") then
        while _G.CombatSystemRunning do
            task.wait(CONFIG.LOOP_INTERVAL_STATUS)
            pcall(function()
                local mobsFolder = Services.Workspace:FindFirstChild("Mobs", true)
                if not mobsFolder then 
                    _G.HasDetectedTarget = false
                    return 
                end
                local validTargets = {}
                for _, mob in ipairs(mobsFolder:GetChildren()) do
                    if mob and mob.Parent == mobsFolder and mob.Name ~= CONFIG.EXCLUDE_TARGET then
                        local healthProps = mob:FindFirstChild("HealthProperties")
                        local currentHealth = healthProps and healthProps:FindFirstChild("Health") and healthProps.Health.Value or 0
                        if currentHealth > 0 then table.insert(validTargets, mob) end
                    end
                end
                if #validTargets > 0 and not _G.HasDetectedTarget and not isChainOnCooldown() then
                    _G.HasDetectedTarget = true
                    _G.ChainLastFireTime = os.clock()
                    deleteTargetModels()
                    local skillArgs = {[1] = {}}
                    local idx = 1
                    for _, mob in ipairs(validTargets) do
                        for i = 1, CONFIG.STACK_TIMES do
                            skillArgs[1][idx] = mob; idx += 1
                        end
                    end
                    skillEvent:FireServer(unpack(skillArgs))
                    return
                end
                if #validTargets == 0 then
                    _G.HasDetectedTarget = false
                    _G.LastCycleAllHadSlowdown = false
                    return
                end
                local allHaveSlowdown = true
                for _, mob in ipairs(validTargets) do
                    local status = mob:FindFirstChild("Status")
                    if not (status and status:FindFirstChild(CONFIG.STATUS_NAME)) then
                        allHaveSlowdown = false; break
                    end
                end
                if not allHaveSlowdown and not isChainOnCooldown() then
                    if _G.LastCycleAllHadSlowdown then task.wait(CONFIG.DELAY_AFTER_STATUS_LOST) end
                    local finalTargets = {}
                    for _, mob in ipairs(validTargets) do
                        local healthProps = mob:FindFirstChild("HealthProperties")
                        local currentHealth = healthProps and healthProps:FindFirstChild("Health") and healthProps.Health.Value or 0
                        if currentHealth > 0 then table.insert(finalTargets, mob) end
                    end
                    if #finalTargets > 0 then
                        _G.ChainLastFireTime = os.clock()
                        deleteTargetModels()
                        local skillArgs = {[1] = {}}
                        local idx = 1
                        for _, mob in ipairs(finalTargets) do
                            for i = 1, CONFIG.STACK_TIMES do
                                skillArgs[1][idx] = mob; idx += 1
                            end
                        end
                        skillEvent:FireServer(unpack(skillArgs))
                    end
                end
                _G.LastCycleAllHadSlowdown = allHaveSlowdown
            end)
        end
    end
    _G.StatusModuleRunning = false
end
local function startMultiSkillAttack()
    local attackEvent = nil
    local retry = 0
    while not attackEvent and retry < CONFIG.ATTACK_MAX_RETRY and _G.CombatSystemRunning do
        attackEvent = findInstanceByPath(game, CONFIG.SKILL_EVENT_PATH_ATTACK, 1)
        if not attackEvent then
            task.wait(CONFIG.ATTACK_RETRY_DELAY)
            retry += 1
        end
    end
    if attackEvent and attackEvent:IsA("RemoteEvent") then
        _G.AttackModuleRunning = true
        task.spawn(function()
            local initTargetPos = getNearestTargetPos()
            local initArgs = {[1] = "MageOfShadowsBlast", [2] = initTargetPos, [4] = CONFIG.ATTACK_ARG_4}
            pcall(function()
                attackEvent:FireServer(unpack(initArgs))
            end)
        end)
        for _, skill in ipairs(CONFIG.ATTACK_SKILLS) do
            task.spawn(function()
                local lastFireTime = os.clock()
                while _G.CombatSystemRunning do
                    task.wait(0.01)
                    local currentTime = os.clock()
                    if currentTime - lastFireTime < skill.Interval then
                        continue
                    end
                    pcall(function()
                        local targetPos = getNearestTargetPos()
                        attackEvent:FireServer(skill.Name, targetPos, nil, CONFIG.ATTACK_ARG_4)
                        lastFireTime = currentTime
                    end)
                end
            end)
        end
        while _G.CombatSystemRunning do
            task.wait(5)
        end
        _G.AttackModuleRunning = false
    end
end
local function runAetherKingMonitor()
    while _G.CombatSystemRunning do
        task.wait(1)
        pcall(function()
            local aetherKing = findInstanceByPath(Services.Workspace, CONFIG.AETHER_KING_PATH, 1)
            if aetherKing and not _G.AetherKingDetected then
                _G.AetherKingDetected = true
                aetherKing.AncestryChanged:Connect(function(_, newParent)
                    if not newParent and _G.AetherKingDetected and _G.CombatSystemRunning then
                        task.wait(CONFIG.TELEPORT_DELAY)
                        local teleportEvent = findInstanceByPath(Services.ReplicatedStorage, CONFIG.TELEPORT_EVENT_PATH, 5)
                        if teleportEvent and teleportEvent:IsA("RemoteEvent") then
                            pcall(function()
                                teleportEvent:FireServer(unpack(CONFIG.TELEPORT_ARGS))
                            end)
                        end
                        _G.AetherKingDetected = false
                    end
                end)
            elseif not aetherKing and _G.AetherKingDetected then
                _G.AetherKingDetected = false
            end
        end)
    end
    _G.AetherKingDetected = false
end
local function startAllModules()
    if not _G.CombatSystemRunning and IsScriptInited then
        _G.CombatSystemRunning = true
        startPlayerTeleportToMissionTimer()
        _G.HasDetectedTarget = false
        _G.ChainLastFireTime = 0
        local humanoidRootPart = Player.Character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            createFlightMode(humanoidRootPart)
            humanoidRootPart.CFrame = humanoidRootPart.CFrame + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0)
        end
        table.insert(ModuleThreads, coroutine.create(runRotateTeleportCycle))
        table.insert(ModuleThreads, coroutine.create(startMultiSkillAttack))
        table.insert(ModuleThreads, coroutine.create(runAetherKingMonitor))
        table.insert(ModuleThreads, coroutine.create(runStatusDetectionCycle))
        for _, thread in pairs(ModuleThreads) do
            coroutine.resume(thread)
        end
    end
end
if IsScriptInited then
    if CONFIG.START_DELAY >= 1 then
        for i = CONFIG.START_DELAY, 1, -1 do
            task.wait(1)
        end
    else
        task.wait(CONFIG.START_DELAY)
    end
    startAllModules()
end
RunService.Heartbeat:Connect(function()
    if _G.CombatSystemRunning and IsScriptInited then
        if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoidRootPart = Player.Character.HumanoidRootPart
            if not humanoidRootPart:FindFirstChild("CombatFlightVel") or not humanoidRootPart:FindFirstChild("CombatFlightGyro") then
                createFlightMode(humanoidRootPart)
            end
        end
    end
end)
