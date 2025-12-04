--[[
    BANANA CAT HUB V6 - FIX AUTO FARM & MOBILE SUPPORT
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- BIẾN TOÀN CỤC ĐỂ HIỂN THỊ TRẠNG THÁI
local CurrentStatus = "Đang chờ..." 

-- ==============================================================================
-- PHẦN 1: LOGIC AUTO FARM (MODULE)
-- ==============================================================================

local AutoFarm = {} 

local Settings = {
    FarmLevel = false,
    FarmNearest = false,
    SelectedWeapon = "Melee", 
    AutoFish = false,
    SelectedRod = "Fishing Rod",
    SelectedBait = "Basic Bait",
    FlySpeed = 300,        
    FarmDistance = 7 
}

-- --- HÀM 1: TỰ ĐỘNG TRANG BỊ VŨ KHÍ (FIX LỖI TÊN) ---
local function EquipWeapon()
    local Backpack = LocalPlayer:FindFirstChild("Backpack")
    local Char = LocalPlayer.Character
    if not Char or not Backpack then return nil end
    
    -- Nếu đang cầm đồ rồi thì trả về luôn
    local HeldTool = Char:FindFirstChildWhichIsA("Tool")
    if HeldTool then return HeldTool end
    
    -- Tìm vũ khí theo tên đã chọn
    local Tool = Backpack:FindFirstChild(Settings.SelectedWeapon)
    
    -- [FIX] Nếu chọn Melee mà không thấy, thử tìm "Combat"
    if not Tool and Settings.SelectedWeapon == "Melee" then
        Tool = Backpack:FindFirstChild("Combat")
    end
    
    -- [FIX] Nếu vẫn không thấy, lấy đại cây hàng đầu tiên
    if not Tool then
        Tool = Backpack:FindFirstChildWhichIsA("Tool")
    end
    
    -- Trang bị
    if Tool then
        Char.Humanoid:EquipTool(Tool)
        return Tool
    else
        CurrentStatus = "❌ Lỗi: Không tìm thấy Vũ khí!"
        return nil
    end
end

-- --- HÀM 2: ĐÁNH DẤU QUÁI ---
local function HighlightTarget(target)
    if not target then return end
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:FindFirstChild("FarmHighlight") then obj.FarmHighlight:Destroy() end
    end
    local hl = Instance.new("Highlight")
    hl.Name = "FarmHighlight"
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.Parent = target
end

-- --- HÀM 3: BAY MƯỢT ---
local function SmoothFly(targetCFrame)
    local Char = LocalPlayer.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return end
    
    local Root = Char.HumanoidRootPart
    local Distance = (Root.Position - targetCFrame.Position).Magnitude
    
    if Distance < 5 then
        Root.CFrame = targetCFrame
        Root.Velocity = Vector3.zero
        return
    end
    
    CurrentStatus = "✈️ Đang bay tới quái..."
    
    local Time = Distance / Settings.FlySpeed 
    local TweenInfo = TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local Tween = TweenService:Create(Root, TweenInfo, {CFrame = targetCFrame})
    
    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BodyVelocity.Parent = Root
    
    local Noclip = RunService.Stepped:Connect(function()
        for _, part in pairs(Char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
    
    Tween:Play()
    Tween.Completed:Wait()
    
    BodyVelocity:Destroy()
    Noclip:Disconnect()
end

-- --- HÀM 4: TÌM QUÁI ---
local function GetClosestEnemy()
    local Char = LocalPlayer.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return nil end
    local Root = Char.HumanoidRootPart
    
    local ClosestDist = math.huge
    local Target = nil
    
    -- Quét cả folder Enemies và Workspace
    local FoldersToScan = {workspace:FindFirstChild("Enemies"), workspace}
    
    for _, Folder in pairs(FoldersToScan) do
        if Folder then
            for _, enemy in pairs(Folder:GetChildren()) do
                if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") and enemy.Humanoid.Health > 0 then
                    if enemy.Name ~= LocalPlayer.Name then 
                        local Dist = (Root.Position - enemy.HumanoidRootPart.Position).Magnitude
                        if Dist < ClosestDist and Dist < 4000 then 
                            ClosestDist = Dist
                            Target = enemy
                        end
                    end
                end
            end
        end
    end
    return Target
end

-- --- VÒNG LẶP CHÍNH ---
task.spawn(function()
    while true do
        if Settings.FarmLevel then
            -- 1. Lấy vũ khí
            local Weapon = EquipWeapon()
            
            if Weapon then
                -- 2. Tìm quái
                local Enemy = GetClosestEnemy()
                if Enemy then
                    CurrentStatus = "⚔️ Tấn công: " .. Enemy.Name
                    HighlightTarget(Enemy)
                    
                    -- 3. Bay tới
                    local EnemyPos = Enemy.HumanoidRootPart.Position
                    local FarmPos = CFrame.new(EnemyPos + Vector3.new(0, Settings.FarmDistance, 0))
                    SmoothFly(FarmPos)
                    
                    -- 4. Đánh (Click chuột + Activate Tool)
                    if (LocalPlayer.Character.HumanoidRootPart.Position - EnemyPos).Magnitude < 10 then
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton1(Vector2.new(800, 600))
                        Weapon:Activate()
                    end
                else
                    CurrentStatus = "🔍 Đang tìm quái..."
                end
            else
                -- Đã có thông báo lỗi trong hàm EquipWeapon
            end
        else
            CurrentStatus = "💤 Đang chờ (Auto Farm OFF)"
        end
        task.wait()
    end
end)

-- Kết nối GUI
function AutoFarm.SetWeapon(val) Settings.SelectedWeapon = val end
function AutoFarm.ToggleLevel(state) Settings.FarmLevel = state end
function AutoFarm.ToggleNearest(state) Settings.FarmNearest = state end
function AutoFarm.SetRod(val) Settings.SelectedRod = val end
function AutoFarm.SetBait(val) Settings.SelectedBait = val end
function AutoFarm.ToggleAutoFish(state) Settings.AutoFish = state end


-- ==============================================================================
-- PHẦN 2: GIAO DIỆN GUI (MAIN GUI V6)
-- ==============================================================================

local THEME = {
    Background = Color3.fromRGB(18, 18, 18),
    Accent = Color3.fromRGB(255, 230, 0), 
    Text = Color3.fromRGB(240, 240, 240),
    ItemBack = Color3.fromRGB(35, 35, 35),
    SidebarBack = Color3.fromRGB(25, 25, 25),
    Font = Enum.Font.GothamBold
}

if PlayerGui:FindFirstChild("BananaCatHub_Final") then
    PlayerGui.BananaCatHub_Final:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BananaCatHub_Final"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
ToggleBtn.BackgroundColor3 = THEME.Accent
ToggleBtn.Text = "🍌"
ToggleBtn.TextSize = 30
ToggleBtn.Font = Enum.Font.FredokaOne
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleBtn).Thickness = 2

-- Kéo thả Toggle
local function MakeDraggable(obj)
    local dragging, dragInput, dragStart, startPos
    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = obj.Position
        end
    end)
    obj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    obj.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end 
    end)
end
MakeDraggable(ToggleBtn)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 320)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -160)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BackgroundTransparency = 0.1
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

local TitleBar = Instance.new("TextButton")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundTransparency = 1
TitleBar.Text = "   BANANA HUB 🍌"
TitleBar.TextColor3 = THEME.Accent
TitleBar.TextSize = 20
TitleBar.Font = Enum.Font.FredokaOne
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainFrame
MakeDraggable(MainFrame)

local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 30, 0, 30)
ResizeHandle.Position = UDim2.new(1, -30, 1, -30)
ResizeHandle.BackgroundColor3 = THEME.Accent
ResizeHandle.Text = "◢"
ResizeHandle.Parent = MainFrame
Instance.new("UICorner", ResizeHandle).CornerRadius = UDim.new(0, 4)

local isResizing, resizeStartSize, resizeMouseStart
ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true; resizeStartSize = MainFrame.AbsoluteSize; resizeMouseStart = Vector2.new(input.Position.X, input.Position.Y)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeMouseStart
        MainFrame.Size = UDim2.new(0, math.max(400, resizeStartSize.X + delta.X), 0, math.max(250, resizeStartSize.Y + delta.Y))
    end
end)
UserInputService.InputEnded:Connect(function(input) isResizing = false end)

-- Sidebar
local SidebarWidth = 120
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, SidebarWidth, 1, -50)
Sidebar.Position = UDim2.new(0, 10, 0, 45)
Sidebar.BackgroundColor3 = THEME.SidebarBack
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel = 0
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Parent = MainFrame
Instance.new("UIListLayout", Sidebar).Padding = UDim.new(0, 5)
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 5)

local PageContainer = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, -(SidebarWidth + 20), 1, -55)
PageContainer.Position = UDim2.new(0, SidebarWidth + 15, 0, 45)
PageContainer.BackgroundTransparency = 1
PageContainer.Parent = MainFrame
local PageFolder = Instance.new("Folder", PageContainer)

local function CreateTab(name)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Text = name
    TabBtn.Size = UDim2.new(0, SidebarWidth - 10, 0, 35)
    TabBtn.BackgroundColor3 = THEME.ItemBack
    TabBtn.TextColor3 = THEME.Text
    TabBtn.Font = THEME.Font
    TabBtn.TextSize = 13
    TabBtn.Parent = Sidebar
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Parent = PageFolder
    Instance.new("UIListLayout", Page).Padding = UDim.new(0, 6)
    local Pad = Instance.new("UIPadding", Page)
    Pad.PaddingTop = UDim.new(0, 5); Pad.PaddingLeft = UDim.new(0, 5); Pad.PaddingBottom = UDim.new(0, 10)
    
    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(PageFolder:GetChildren()) do p.Visible = false end
        Page.Visible = true
        for _, btn in pairs(Sidebar:GetChildren()) do
            if btn:IsA("TextButton") then 
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.ItemBack, TextColor3 = THEME.Text}):Play()
            end
        end
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Accent, TextColor3 = Color3.new(0,0,0)}):Play()
    end)
    return Page
end

-- UI Components
local function CreateDropdown(parentPage, title, options, callback)
    local Dropdown = Instance.new("Frame")
    Dropdown.Size = UDim2.new(1, -5, 0, 35)
    Dropdown.BackgroundColor3 = THEME.ItemBack
    Dropdown.ClipsDescendants = true
    Dropdown.Parent = parentPage
    Instance.new("UICorner", Dropdown).CornerRadius = UDim.new(0, 6)
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = title
    TitleLabel.Size = UDim2.new(1, -30, 0, 35)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3 = THEME.Text
    TitleLabel.Font = THEME.Font
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Dropdown
    
    local OpenBtn = Instance.new("TextButton")
    OpenBtn.Size = UDim2.new(1, 0, 0, 35)
    OpenBtn.BackgroundTransparency = 1
    OpenBtn.Text = "▼"
    OpenBtn.TextColor3 = THEME.Text
    OpenBtn.Parent = Dropdown
    
    local OptionList = Instance.new("Frame")
    OptionList.Size = UDim2.new(1, 0, 0, 0)
    OptionList.Position = UDim2.new(0, 0, 0, 35)
    OptionList.BackgroundTransparency = 1
    OptionList.Parent = Dropdown
    Instance.new("UIListLayout", OptionList).SortOrder = Enum.SortOrder.LayoutOrder
    
    local isOpen = false
    OpenBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35 + (#options * 30))}):Play()
        else
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35)}):Play()
        end
    end)
    
    for _, opt in ipairs(options) do
        local OptBtn = Instance.new("TextButton")
        OptBtn.Text = opt
        OptBtn.Size = UDim2.new(1, 0, 0, 30)
        OptBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        OptBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        OptBtn.Parent = OptionList
        OptBtn.MouseButton1Click:Connect(function()
            TitleLabel.Text = title .. ": " .. opt
            callback(opt)
            isOpen = false
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35)}):Play()
        end)
    end
end

local function CreateToggle(parentPage, text, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, -5, 0, 35)
    ToggleFrame.BackgroundColor3 = THEME.ItemBack
    ToggleFrame.Parent = parentPage
    Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
    
    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Size = UDim2.new(1, -40, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = THEME.Text
    Label.Font = THEME.Font
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleFrame
    
    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.Parent = ToggleFrame
    
    local BoxOuter = Instance.new("Frame")
    BoxOuter.AnchorPoint = Vector2.new(1, 0.5)
    BoxOuter.Size = UDim2.new(0, 22, 0, 22)
    BoxOuter.Position = UDim2.new(1, -10, 0.5, 0)
    BoxOuter.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    BoxOuter.Parent = ToggleFrame
    Instance.new("UICorner", BoxOuter).CornerRadius = UDim.new(0, 4)
    local BoxInner = Instance.new("Frame")
    BoxInner.AnchorPoint = Vector2.new(0.5, 0.5)
    BoxInner.Size = UDim2.new(0, 14, 0, 14)
    BoxInner.Position = UDim2.new(0.5, 0, 0.5, 0)
    BoxInner.BackgroundColor3 = THEME.Accent
    BoxInner.BackgroundTransparency = 1
    BoxInner.Parent = BoxOuter
    Instance.new("UICorner", BoxInner).CornerRadius = UDim.new(0, 3)
    
    local isOn = false
    ClickBtn.MouseButton1Click:Connect(function()
        isOn = not isOn
        TweenService:Create(BoxInner, TweenInfo.new(0.2), {BackgroundTransparency = isOn and 0 or 1}):Play()
        Label.TextColor3 = isOn and THEME.Accent or THEME.Text
        callback(isOn)
    end)
end

local function CreateCenteredHeader(parentPage, text)
    local Header = Instance.new("TextLabel")
    Header.Text = text
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundTransparency = 1
    Header.TextColor3 = THEME.Accent
    Header.Font = Enum.Font.FredokaOne
    Header.TextSize = 20
    Header.Parent = parentPage
end

-- --- [MỚI] TẠO STATUS BAR HIỂN THỊ HÀNH ĐỘNG ---
local function CreateActionStatus(parentPage)
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Size = UDim2.new(1, -5, 0, 30)
    StatusFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    StatusFrame.Parent = parentPage
    Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 6)
    
    local Label = Instance.new("TextLabel")
    Label.Text = "Status: ..."
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = Color3.fromRGB(0, 255, 0) -- Màu xanh lá
    Label.Font = Enum.Font.GothamBold
    Label.TextSize = 13
    Label.Parent = StatusFrame
    
    -- Cập nhật liên tục
    task.spawn(function()
        while task.wait(0.2) do
            Label.Text = "Status: " .. CurrentStatus
        end
    end)
end

-- --- TẠO TAB ---
local Tab1 = CreateTab("Status")
local Tab2 = CreateTab("Auto Farm")
local Tab3 = CreateTab("Sea")
local Tab4 = CreateTab("Islands")
local Tab5 = CreateTab("Quest/Items")
local Tab6 = CreateTab("Fruit/Raid")
local Tab7 = CreateTab("Teleport")
local Tab8 = CreateTab("Visuals")
local Tab9 = CreateTab("Shop")
local Tab10 = CreateTab("PVP")
local Tab11 = CreateTab("Misc")

Tab1.Visible = true

-- NỘI DUNG TAB 2 (AUTO FARM)
-- [MỚI] Thêm dòng trạng thái để bạn biết script đang làm gì
CreateActionStatus(Tab2)

CreateDropdown(Tab2, "Select Tool", {"Melee", "Sword", "Fruit"}, function(val) AutoFarm.SetWeapon(val) end)
CreateCenteredHeader(Tab2, "AUTO FARM")
CreateToggle(Tab2, "Auto Farm Level", function(state) AutoFarm.ToggleLevel(state) end)
CreateToggle(Tab2, "Auto Farm Nearest", function(state) AutoFarm.ToggleNearest(state) end)
CreateCenteredHeader(Tab2, "( Fish )")
CreateDropdown(Tab2, "Choose a fishing rod", {"Fishing Rod", "Gold Rod"}, function(val) AutoFarm.SetRod(val) end)
CreateDropdown(Tab2, "Bait selection", {"Basic Bait", "Kelp Bait"}, function(val) AutoFarm.SetBait(val) end)
CreateToggle(Tab2, "Auto Fish (Anywhere)", function(state) AutoFarm.ToggleAutoFish(state) end)

print("Banana Cat Hub V6 Loaded!")    local Time = Distance / Settings.FlySpeed 
    local TweenInfo = TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local Tween = TweenService:Create(Root, TweenInfo, {CFrame = targetCFrame})
    
    local BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.Parent = Root
    
    local NoclipConnection = RunService.Stepped:Connect(function()
        for _, part in pairs(Char:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
    
    Tween:Play()
    Tween.Completed:Wait()
    
    BodyVelocity:Destroy()
    if NoclipConnection then NoclipConnection:Disconnect() end
end

-- --- HÀM TÌM QUÁI ---
local function GetClosestEnemy()
    local Char = LocalPlayer.Character
    if not Char or not Char:FindFirstChild("HumanoidRootPart") then return nil end
    
    local Root = Char.HumanoidRootPart
    local ClosestDist = math.huge
    local Target = nil
    
    -- Ưu tiên tìm trong thư mục Enemies của Blox Fruits
    local SearchFolder = workspace:FindFirstChild("Enemies") or workspace
    
    for _, enemy in pairs(SearchFolder:GetChildren()) do
        if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") and enemy.Humanoid.Health > 0 then
            if enemy.Name ~= LocalPlayer.Name then 
                local Dist = (Root.Position - enemy.HumanoidRootPart.Position).Magnitude
                if Dist < ClosestDist and Dist < 5000 then -- Quét 5000m
                    ClosestDist = Dist
                    Target = enemy
                end
            end
        end
    end
    return Target
end

-- --- HÀM TỰ ĐỘNG ĐÁNH ---
local function Attack()
    local Char = LocalPlayer.Character
    if not Char then return end
    
    -- Tự động bật Haki (nếu có)
    -- ... (Code bật Haki sau này thêm)

    local Tool = Char:FindFirstChildWhichIsA("Tool")
    if Tool then
        Tool:Activate() -- Kích hoạt chiêu
        -- Nếu dùng Executor xịn có thể dùng: VirtualUser:ClickButton1(Vector2.new(0,0))
    else
        -- Tự trang bị vũ khí từ Balo
        local Backpack = LocalPlayer:FindFirstChild("Backpack")
        if Backpack then
            -- Ưu tiên tìm vũ khí đã chọn
            local Weapon = Backpack:FindFirstChild(Settings.SelectedWeapon) or Backpack:FindFirstChildWhichIsA("Tool")
            if Weapon then 
                Char.Humanoid:EquipTool(Weapon) 
            end
        end
    end
end

-- --- VÒNG LẶP CHÍNH (LOGIC) ---
task.spawn(function()
    while true do
        local Char = LocalPlayer.Character
        
        if Settings.FarmLevel and Char and Char:FindFirstChild("HumanoidRootPart") then
            local Enemy = GetClosestEnemy()
            
            if Enemy then
                HighlightTarget(Enemy) -- Đánh dấu
                
                -- Tính vị trí đứng trên đầu
                local EnemyPos = Enemy.HumanoidRootPart.Position
                local FarmPos = CFrame.new(EnemyPos + Vector3.new(0, Settings.FarmDistance, 0))
                
                -- Bay đến và Đánh
                SmoothFly(FarmPos)
                Attack()
            end
        end

        if Settings.AutoFish then
            -- Logic câu cá sẽ điền sau
        end
        task.wait() 
    end
end)

-- Các hàm kết nối với GUI
function AutoFarm.SetWeapon(val) Settings.SelectedWeapon = val end
function AutoFarm.ToggleLevel(state) Settings.FarmLevel = state end
function AutoFarm.ToggleNearest(state) Settings.FarmNearest = state end
function AutoFarm.SetRod(val) Settings.SelectedRod = val end
function AutoFarm.SetBait(val) Settings.SelectedBait = val end
function AutoFarm.ToggleAutoFish(state) Settings.AutoFish = state end


-- ==============================================================================
-- PHẦN 2: GIAO DIỆN GUI (MAIN GUI)
-- ==============================================================================

-- 1. CẤU HÌNH THEME
local THEME = {
    Background = Color3.fromRGB(18, 18, 18),
    Accent = Color3.fromRGB(255, 230, 0), -- Màu vàng
    Text = Color3.fromRGB(240, 240, 240),
    ItemBack = Color3.fromRGB(35, 35, 35),
    SidebarBack = Color3.fromRGB(25, 25, 25),
    Font = Enum.Font.GothamBold
}

if PlayerGui:FindFirstChild("BananaCatHub_Final") then
    PlayerGui.BananaCatHub_Final:Destroy()
end

-- 2. TẠO SCREEN GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BananaCatHub_Final"
ScreenGui.Parent = PlayerGui
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Nút Icon Bật/Tắt
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
ToggleBtn.BackgroundColor3 = THEME.Accent
ToggleBtn.Text = "🍌"
ToggleBtn.TextSize = 30
ToggleBtn.Font = Enum.Font.FredokaOne
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleBtn).Thickness = 2

-- Hàm Kéo thả (Mobile Support)
local function MakeDraggable(obj)
    local dragging, dragInput, dragStart, startPos
    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = obj.Position
        end
    end)
    obj.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    obj.InputEnded:Connect(function(input) 
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end 
    end)
end
MakeDraggable(ToggleBtn)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 550, 0, 320) -- Chỉnh nhỏ xíu cho vừa đt
MainFrame.Position = UDim2.new(0.5, -275, 0.5, -160)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BackgroundTransparency = 0.1
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

local TitleBar = Instance.new("TextButton")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundTransparency = 1
TitleBar.Text = "   BANANA HUB 🍌"
TitleBar.TextColor3 = THEME.Accent
TitleBar.TextSize = 20
TitleBar.Font = Enum.Font.FredokaOne
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainFrame
MakeDraggable(MainFrame)

-- Resize Handle
local ResizeHandle = Instance.new("TextButton")
ResizeHandle.Size = UDim2.new(0, 30, 0, 30) -- To hơn chút cho dễ bấm trên đt
ResizeHandle.Position = UDim2.new(1, -30, 1, -30)
ResizeHandle.BackgroundColor3 = THEME.Accent
ResizeHandle.Text = "◢"
ResizeHandle.Parent = MainFrame
Instance.new("UICorner", ResizeHandle).CornerRadius = UDim.new(0, 4)

local isResizing, resizeStartSize, resizeMouseStart
ResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isResizing = true; resizeStartSize = MainFrame.AbsoluteSize; resizeMouseStart = Vector2.new(input.Position.X, input.Position.Y)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeMouseStart
        MainFrame.Size = UDim2.new(0, math.max(400, resizeStartSize.X + delta.X), 0, math.max(250, resizeStartSize.Y + delta.Y))
    end
end)
UserInputService.InputEnded:Connect(function(input) isResizing = false end)

-- Cấu trúc Tab
local SidebarWidth = 120
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, SidebarWidth, 1, -50)
Sidebar.Position = UDim2.new(0, 10, 0, 45)
Sidebar.BackgroundColor3 = THEME.SidebarBack
Sidebar.BackgroundTransparency = 0.5
Sidebar.BorderSizePixel = 0
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Parent = MainFrame
Instance.new("UIListLayout", Sidebar).Padding = UDim.new(0, 5)
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 5)

local PageContainer = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, -(SidebarWidth + 20), 1, -55)
PageContainer.Position = UDim2.new(0, SidebarWidth + 15, 0, 45)
PageContainer.BackgroundTransparency = 1
PageContainer.Parent = MainFrame
local PageFolder = Instance.new("Folder", PageContainer)

local function CreateTab(name)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Text = name
    TabBtn.Size = UDim2.new(0, SidebarWidth - 10, 0, 35)
    TabBtn.BackgroundColor3 = THEME.ItemBack
    TabBtn.TextColor3 = THEME.Text
    TabBtn.Font = THEME.Font
    TabBtn.TextSize = 13
    TabBtn.Parent = Sidebar
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    local Page = Instance.new("ScrollingFrame")
    Page.Name = name
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.Parent = PageFolder
    Instance.new("UIListLayout", Page).Padding = UDim.new(0, 6)
    local Pad = Instance.new("UIPadding", Page)
    Pad.PaddingTop = UDim.new(0, 5); Pad.PaddingLeft = UDim.new(0, 5); Pad.PaddingBottom = UDim.new(0, 10)
    
    TabBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(PageFolder:GetChildren()) do p.Visible = false end
        Page.Visible = true
        for _, btn in pairs(Sidebar:GetChildren()) do
            if btn:IsA("TextButton") then 
                TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.ItemBack, TextColor3 = THEME.Text}):Play()
            end
        end
        TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Accent, TextColor3 = Color3.new(0,0,0)}):Play()
    end)
    return Page
end

-- Hàm hỗ trợ UI (Dropdown, Toggle, Label...)
local function CreateDropdown(parentPage, title, options, callback)
    local Dropdown = Instance.new("Frame")
    Dropdown.Size = UDim2.new(1, -5, 0, 35)
    Dropdown.BackgroundColor3 = THEME.ItemBack
    Dropdown.ClipsDescendants = true
    Dropdown.Parent = parentPage
    Instance.new("UICorner", Dropdown).CornerRadius = UDim.new(0, 6)
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = title
    TitleLabel.Size = UDim2.new(1, -30, 0, 35)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3 = THEME.Text
    TitleLabel.Font = THEME.Font
    TitleLabel.TextSize = 14
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Dropdown
    
    local OpenBtn = Instance.new("TextButton")
    OpenBtn.Size = UDim2.new(1, 0, 0, 35)
    OpenBtn.BackgroundTransparency = 1
    OpenBtn.Text = "▼"
    OpenBtn.TextColor3 = THEME.Text
    OpenBtn.Parent = Dropdown
    
    local OptionList = Instance.new("Frame")
    OptionList.Size = UDim2.new(1, 0, 0, 0)
    OptionList.Position = UDim2.new(0, 0, 0, 35)
    OptionList.BackgroundTransparency = 1
    OptionList.Parent = Dropdown
    Instance.new("UIListLayout", OptionList).SortOrder = Enum.SortOrder.LayoutOrder
    
    local isOpen = false
    OpenBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35 + (#options * 30))}):Play()
        else
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35)}):Play()
        end
    end)
    
    for _, opt in ipairs(options) do
        local OptBtn = Instance.new("TextButton")
        OptBtn.Text = opt
        OptBtn.Size = UDim2.new(1, 0, 0, 30)
        OptBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        OptBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        OptBtn.Parent = OptionList
        OptBtn.MouseButton1Click:Connect(function()
            TitleLabel.Text = title .. ": " .. opt
            callback(opt)
            isOpen = false
            TweenService:Create(Dropdown, TweenInfo.new(0.3), {Size = UDim2.new(1, -5, 0, 35)}):Play()
        end)
    end
end

local function CreateToggle(parentPage, text, callback)
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, -5, 0, 35)
    ToggleFrame.BackgroundColor3 = THEME.ItemBack
    ToggleFrame.Parent = parentPage
    Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 6)
    
    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Size = UDim2.new(1, -40, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.TextColor3 = THEME.Text
    Label.Font = THEME.Font
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = ToggleFrame
    
    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    ClickBtn.Parent = ToggleFrame
    
    local BoxOuter = Instance.new("Frame")
    BoxOuter.AnchorPoint = Vector2.new(1, 0.5)
    BoxOuter.Size = UDim2.new(0, 22, 0, 22)
    BoxOuter.Position = UDim2.new(1, -10, 0.5, 0)
    BoxOuter.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    BoxOuter.Parent = ToggleFrame
    Instance.new("UICorner", BoxOuter).CornerRadius = UDim.new(0, 4)
    local BoxInner = Instance.new("Frame")
    BoxInner.AnchorPoint = Vector2.new(0.5, 0.5)
    BoxInner.Size = UDim2.new(0, 14, 0, 14)
    BoxInner.Position = UDim2.new(0.5, 0, 0.5, 0)
    BoxInner.BackgroundColor3 = THEME.Accent
    BoxInner.BackgroundTransparency = 1
    BoxInner.Parent = BoxOuter
    Instance.new("UICorner", BoxInner).CornerRadius = UDim.new(0, 3)
    
    local isOn = false
    ClickBtn.MouseButton1Click:Connect(function()
        isOn = not isOn
        TweenService:Create(BoxInner, TweenInfo.new(0.2), {BackgroundTransparency = isOn and 0 or 1}):Play()
        Label.TextColor3 = isOn and THEME.Accent or THEME.Text
        callback(isOn)
    end)
end

local function CreateCenteredHeader(parentPage, text)
    local Header = Instance.new("TextLabel")
    Header.Text = text
    Header.Size = UDim2.new(1, 0, 0, 30)
    Header.BackgroundTransparency = 1
    Header.TextColor3 = THEME.Accent
    Header.Font = Enum.Font.FredokaOne
    Header.TextSize = 20
    Header.Parent = parentPage
end

local function CreateStatusLabel(parentPage, title, defaultValue)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -5, 0, 35)
    Frame.BackgroundColor3 = THEME.ItemBack
    Frame.Parent = parentPage
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)
    local TitleLabel = Instance.new("TextLabel"); TitleLabel.Text = title; TitleLabel.Size = UDim2.new(0.4, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 10, 0, 0); TitleLabel.BackgroundTransparency = 1; TitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180); TitleLabel.Font = THEME.Font; TitleLabel.TextSize = 14; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.Parent = Frame
    local ValueLabel = Instance.new("TextLabel"); ValueLabel.Text = defaultValue; ValueLabel.Size = UDim2.new(0.6, -10, 1, 0); ValueLabel.Position = UDim2.new(1, -10, 0, 0); ValueLabel.AnchorPoint = Vector2.new(1, 0); ValueLabel.BackgroundTransparency = 1; ValueLabel.TextColor3 = THEME.Accent; ValueLabel.Font = Enum.Font.GothamBold; ValueLabel.TextSize = 14; ValueLabel.TextXAlignment = Enum.TextXAlignment.Right; ValueLabel.Parent = Frame
    return ValueLabel
end
local function FormatNumber(n) return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "") end

-- --- TẠO 11 TAB ---
local Tab1 = CreateTab("Status")
local Tab2 = CreateTab("Auto Farm")
local Tab3 = CreateTab("Sea")
local Tab4 = CreateTab("Islands")
local Tab5 = CreateTab("Quest/Items")
local Tab6 = CreateTab("Fruit/Raid")
local Tab7 = CreateTab("Teleport")
local Tab8 = CreateTab("Visuals")
local Tab9 = CreateTab("Shop")
local Tab10 = CreateTab("PVP")
local Tab11 = CreateTab("Misc")

Tab1.Visible = true

-- NỘI DUNG TAB 1
CreateCenteredHeader(Tab1, "TRẠNG THÁI")
local TimeLabel = CreateStatusLabel(Tab1, "Thời gian :", "00:00:00")
local BeliLabel = CreateStatusLabel(Tab1, "Beli :", "Loading...")
local FragLabel = CreateStatusLabel(Tab1, "Điểm tím :", "Loading...")
local BountyLabel = CreateStatusLabel(Tab1, "Tiền thưởng :", "Loading...")
local FruitLabel = CreateStatusLabel(Tab1, "Trái ác quỷ :", "Loading...")

task.spawn(function()
    local StartTime = tick()
    while task.wait(1) do
        local elapsed = tick() - StartTime
        local h = math.floor(elapsed / 3600); local m = math.floor((elapsed % 3600) / 60); local s = math.floor(elapsed % 60)
        TimeLabel.Text = string.format("%02d:%02d:%02d", h, m, s)
        if LocalPlayer:FindFirstChild("Data") then
            if LocalPlayer.Data:FindFirstChild("Beli") then BeliLabel.Text = FormatNumber(LocalPlayer.Data.Beli.Value) .. "$" end
            if LocalPlayer.Data:FindFirstChild("Fragments") then FragLabel.Text = FormatNumber(LocalPlayer.Data.Fragments.Value) .. " ƒ" end
            if LocalPlayer.Data:FindFirstChild("DevilFruit") then FruitLabel.Text = tostring(LocalPlayer.Data.DevilFruit.Value) else FruitLabel.Text = "Không có" end
        end
        if LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Bounty") then BountyLabel.Text = FormatNumber(LocalPlayer.leaderstats.Bounty.Value) end
    end
end)

-- NỘI DUNG TAB 2
CreateDropdown(Tab2, "Select Tool", {"Melee", "Sword", "Fruit"}, function(val) AutoFarm.SetWeapon(val) end)
CreateCenteredHeader(Tab2, "AUTO FARM")
CreateToggle(Tab2, "Auto Farm Level", function(state) AutoFarm.ToggleLevel(state) end)
CreateToggle(Tab2, "Auto Farm Nearest", function(state) AutoFarm.ToggleNearest(state) end)
CreateCenteredHeader(Tab2, "( Fish )")
CreateDropdown(Tab2, "Choose a fishing rod", {"Fishing Rod", "Gold Rod", "Shack Rod", "Shell Rod", "Treasure Rod"}, function(val) AutoFarm.SetRod(val) end)
CreateDropdown(Tab2, "Bait selection", {"Basic Bait", "Kelp Bait", "Good Bait", "Abyssal Bait", "Frozen Bait", "Epic Bait", "Carnivore Bait"}, function(val) AutoFarm.SetBait(val) end)
CreateToggle(Tab2, "Auto Fish (Anywhere)", function(state) AutoFarm.ToggleAutoFish(state) end)

print("Banana Cat Hub Loaded!")
