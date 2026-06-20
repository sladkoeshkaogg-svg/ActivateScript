local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Obsidian UI
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Kick Menu",
    Footer = "Kick Menu",
    ShowCustomCursor = true,
})

local Tab = Window:AddTab("Main", "zap")
local Group = Tab:AddLeftGroupbox("Kick")

-- Helpers
local function getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, p.DisplayName .. " (" .. p.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromSelection(sel)
    if not sel then return nil end
    local name = sel:match("%((.-)%)")
    return name and Players:FindFirstChild(name)
end

local selectedTarget = nil
local kickActive = false
local kickConn = nil

-- Dropdown
Group:AddDropdown("TargetDropdown", {
    Values = getPlayerList(),
    Default = 1,
    Multi = false,
    Text = "Select Target",
    Callback = function(v)
        selectedTarget = getPlayerFromSelection(v)
    end
})

-- Refresh
Group:AddButton({
    Text = "Refresh List",
    Func = function()
        Library.Options.TargetDropdown:SetValues(getPlayerList())
        Library.Options.TargetDropdown:SetValue(nil)
        selectedTarget = nil
    end
})

-- Auto Sit Blobman
local function spawnBlobman()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    pcall(function()
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(
            "CreatureBlobman",
            hrp.CFrame * CFrame.new(0, 5, 5),
            Vector3.zero
        )
    end)
end

local function sitOnBlobman()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum.SeatPart and hum.SeatPart.Parent.Name == "CreatureBlobman" then return end

    -- Ищем блобмена
    local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local blob = folder and folder:FindFirstChild("CreatureBlobman")

    -- Если нет - спавним
    if not blob then
        spawnBlobman()
        task.wait(1)
        folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        blob = folder and folder:FindFirstChild("CreatureBlobman")
    end

    if not blob then return end

    local seat = blob:FindFirstChildWhichIsA("VehicleSeat", true)
        or blob:FindFirstChildWhichIsA("Seat", true)
    if not seat then return end

    -- Телепорт к сиденью и садимся
    local t = tick()
    repeat
        hrp.CFrame = seat.CFrame * CFrame.new(0, 1.5, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        pcall(function() seat:Sit(hum) end)
        RunService.Heartbeat:Wait()
    until hum.SeatPart == seat or tick() - t > 3
end

-- Автоматический сид при старте кика
local autoSitConn = nil

local function startAutoSit()
    if autoSitConn then autoSitConn:Disconnect() end
    autoSitConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and (not hum.SeatPart or hum.SeatPart.Parent.Name ~= "CreatureBlobman") then
            task.spawn(sitOnBlobman)
        end
    end)
end

local function stopAutoSit()
    if autoSitConn then
        autoSitConn:Disconnect()
        autoSitConn = nil
    end
end

-- KICK (без анчора, быстрый, через blob)
local function startKick()
    task.spawn(function()
        local GE = ReplicatedStorage:WaitForChild("GrabEvents")
        local throttle = 0

        kickConn = RunService.Heartbeat:Connect(function()
            if not kickActive then return end

            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            local myRoot = char and char:FindFirstChild("HumanoidRootPart")

            -- Проверяем что сидим на блобе
            if not seat or seat.Parent.Name ~= "CreatureBlobman" then return end
            if not myRoot then return end

            local blob = seat.Parent
            local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
            local CD = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
            local RDet = blob:FindFirstChild("RightDetector")
            local LDet = blob:FindFirstChild("LeftDetector")
            local RWeld = RDet and (RDet:FindFirstChild("RightWeld") or RDet:FindFirstChildWhichIsA("Weld"))
            local LWeld = LDet and (LDet:FindFirstChild("LeftWeld") or LDet:FindFirstChildWhichIsA("Weld"))

            if not (CG and CD and RDet and LDet and blobRoot) then return end

            local target = selectedTarget
            if not target or not target.Parent then return end

            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

            if not (tRoot and tHum and tHum.Health > 0) then return end

            -- Throttle
            if tick() - throttle < 0.03 then return end
            throttle = tick()

            -- Стабилизация цели (БЕЗ анчора)
            tRoot.AssemblyLinearVelocity = Vector3.zero
            tRoot.AssemblyAngularVelocity = Vector3.zero

            -- Быстрый dual grab/drop
            pcall(function()
                -- Правая рука
                CG:FireServer(RDet, tRoot, RWeld)
                task.wait(0.02)
                local rw = RDet:FindFirstChild("RightWeld") or RDet:FindFirstChildWhichIsA("Weld")
                if rw then CD:FireServer(rw) end

                -- Левая рука
                CG:FireServer(LDet, tRoot, LWeld)
                task.wait(0.02)
                local lw = LDet:FindFirstChild("LeftWeld") or LDet:FindFirstChildWhichIsA("Weld")
                if lw then CD:FireServer(lw) end

                -- Дабл
                CG:FireServer(RDet, tRoot, RWeld)
                CG:FireServer(LDet, tRoot, LWeld)
                task.wait(0.02)
                rw = RDet:FindFirstChild("RightWeld") or RDet:FindFirstChildWhichIsA("Weld")
                lw = LDet:FindFirstChild("LeftWeld") or LDet:FindFirstChildWhichIsA("Weld")
                if rw then CD:FireServer(rw) end
                if lw then CD:FireServer(lw) end

                -- GrabEvents
                GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                task.wait(0.02)
                GE.DestroyGrabLine:FireServer(tRoot)
            end)
        end)
    end)
end

local function stopKick()
    if kickConn then
        kickConn:Disconnect()
        kickConn = nil
    end
end

-- Main Toggle
Group:AddToggle("KickToggle", {
    Text = "Kick (Blob + Fast)",
    Default = false,
    Callback = function(on)
        kickActive = on
        if on then
            if not selectedTarget then
                Library:Notify({
                    Title = "Error",
                    Description = "Select a target first!",
                    Time = 3
                })
                Library.Toggles.KickToggle:SetValue(false)
                return
            end
            -- Сначала садимся на блоба
            task.spawn(function()
                sitOnBlobman()
                task.wait(0.5)
                startAutoSit()
                startKick()
            end)
        else
            stopKick()
            stopAutoSit()
        end
    end
})

-- UI Settings
local UITab = Window:AddTab("UI Settings", "settings")
local MenuGroup = UITab:AddLeftGroupbox("Menu")

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind"
})

Library.ToggleKeybind = Library.Options.MenuKeybind
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("KickMenu")
SaveManager:SetFolder("KickMenu/Configs")
ThemeManager:ApplyToTab(UITab)
