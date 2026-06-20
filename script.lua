local PS = game:GetService("Players")
local P = PS.LocalPlayer
local RS = game:GetService("RunService")
local RS2 = game:GetService("ReplicatedStorage")
local WS = workspace

local GE = RS2:WaitForChild("GrabEvents", 10)
local SNO = GE:WaitForChild("SetNetworkOwner")

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Lib = loadstring(game:HttpGet(repo .. "Library.lua"))()
local TM = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SM = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local W = Lib:CreateWindow({
    Title = "Kick",
    Icon = "skull",
    Footer = "Kick Tool",
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tab = W:AddTab("Kick", "skull")
local Box = Tab:AddLeftGroupbox("Kick Player", "skull")

-- ═══════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════
local function safeWait(t)
    local s = tick()
    repeat RS.Heartbeat:Wait() until tick() - s >= t
end

local function getBlobParts()
    local c = P.Character
    local hm = c and c:FindFirstChild("Humanoid")
    local se = hm and hm.SeatPart
    if not se or not se.Parent or se.Parent.Name ~= "CreatureBlobman" then return nil end
    local bl = se.Parent
    local br = bl:FindFirstChild("HumanoidRootPart") or bl.PrimaryPart
    local so = bl:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not so then return nil end
    local cg = so:FindFirstChild("CreatureGrab")
    local cd = so:FindFirstChild("CreatureDrop")
    local rd = bl:FindFirstChild("RightDetector")
    local rw = rd and (rd:FindFirstChild("RightWeld") or rd:FindFirstChildWhichIsA("Weld"))
    if not (cg and cd and rd and rw and br) then return nil end
    return { br = br, cg = cg, cd = cd }
end

local function spawnAndSit()
    local c = P.Character or P.CharacterAdded:Wait()
    local hm = c:WaitForChild("Humanoid", 5)
    local h = c:WaitForChild("HumanoidRootPart", 5)
    if not hm or not h then return false end
    if hm.SeatPart and hm.SeatPart.Parent and hm.SeatPart.Parent.Name == "CreatureBlobman" then return true end
    pcall(function()
        RS2.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", h.CFrame, Vector3.zero)
    end)
    safeWait(0.8)
    local folder = WS:FindFirstChild(P.Name .. "SpawnedInToys") or WS:WaitForChild(P.Name .. "SpawnedInToys", 8)
    if not folder then return false end
    local blob = folder:FindFirstChild("CreatureBlobman") or folder:WaitForChild("CreatureBlobman", 8)
    if not blob then return false end
    local seat = blob:FindFirstChildWhichIsA("VehicleSeat", true)
    if not seat then return false end
    local t = tick()
    repeat
        h.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
        h.Velocity = Vector3.zero
        seat:Sit(hm)
        RS.Heartbeat:Wait()
    until hm.SeatPart == seat or tick() - t > 5
    return hm.SeatPart == seat
end

-- ═══════════════════════════════════
-- PLAYER LIST
-- ═══════════════════════════════════
local function getPlayerNames()
    local list = {}
    for _, pl in ipairs(PS:GetPlayers()) do
        if pl ~= P then
            table.insert(list, pl.Name)
        end
    end
    return list
end

-- ═══════════════════════════════════
-- UI
-- ═══════════════════════════════════
local kicking = false
local selectedTarget = nil

Box:AddDropdown("KickTarget", {
    Text = "Select Player",
    Values = getPlayerNames(),
    Default = 1,
    Searchable = true,
    Callback = function(v)
        selectedTarget = PS:FindFirstChild(v)
    end
})

Box:AddButton({
    Text = "🔄 Refresh List",
    Func = function()
        Lib.Options.KickTarget:SetValues(getPlayerNames())
        Lib:Notify({ Title = "Kick", Description = "Player list refreshed", Time = 2 })
    end
})

Box:AddButton({
    Text = "⚡ KICK",
    Func = function()
        if kicking then
            Lib:Notify({ Title = "Kick", Description = "Already kicking!", Time = 2 })
            return
        end
        if not selectedTarget or not selectedTarget.Parent then
            Lib:Notify({ Title = "Kick", Description = "Select a player first!", Time = 3 })
            return
        end

        kicking = true
        Lib:Notify({ Title = "Kick", Description = "Kicking " .. selectedTarget.Name .. "...", Time = 3 })

        task.spawn(function()
            local ok = spawnAndSit()
            if not ok then
                Lib:Notify({ Title = "Kick", Description = "Failed to sit in blobman!", Time = 3 })
                kicking = false
                return
            end
            safeWait(0.3)

            while kicking do
                local char = selectedTarget and selectedTarget.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if not hrp or not hum or hum.Health <= 0 or not selectedTarget.Parent then
                    kicking = false
                    Lib:Notify({ Title = "Kick", Description = "Target left or died", Time = 3 })
                    break
                end

                local bp = getBlobParts()
                if not bp then kicking = false break end

                -- ТП блобмена к цели
                pcall(function() SNO:FireServer(bp.br) end)
                bp.br.CFrame = hrp.CFrame * CFrame.new(0, 0, 2)
                bp.br.Velocity = Vector3.zero

                -- Максимально быстрые хваты
                for i = 1, 8 do
                    pcall(function() SNO:FireServer(hrp) end)
                    pcall(function() bp.cg:FireServer(hrp) end)
                    pcall(function() bp.cd:FireServer() end)
                end

                RS.Heartbeat:Wait()
            end

            kicking = false
        end)
    end
})

Box:AddButton({
    Text = "⏹ STOP",
    Func = function()
        kicking = false
        Lib:Notify({ Title = "Kick", Description = "Stopped", Time = 2 })
    end
})

TM:SetLibrary(Lib)
SM:SetLibrary(Lib)
SM:SetFolder("KickTool")

local UITab = W:AddTab("UI", "settings")
local UILeft = UITab:AddLeftGroupbox("Theme", "palette")
local UIRight = UITab:AddRightGroupbox("Save", "save")
TM:BuildMenu(UILeft)
SM:BuildMenu(UIRight)
