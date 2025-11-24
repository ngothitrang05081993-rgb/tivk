--[[
    ============================================================
    DISCORD SPY TOOL - BLOX FRUITS LOGIC
    Target: CommF_
    Status: Active -> Discord Channel
    ============================================================
]]

-- /// CẤU HÌNH (Đã điền Webhook của bạn) ///
getgenv().WebhookURL = "[https://discord.com/api/webhooks/1442402770740056237/m-Zj4MRA-aIBqcqPLqNXf1hqPxiEAotYy4EdbaL-64RZ5Npg5IBXSlZ5zEktYO8-3dAN](https://discord.com/api/webhooks/1442402770740056237/m-Zj4MRA-aIBqcqPLqNXf1hqPxiEAotYy4EdbaL-64RZ5Npg5IBXSlZ5zEktYO8-3dAN)"

local Config = {
    MinBatch = 10,       -- Gom đủ 10 dòng code mới gửi 1 lần (để tránh lag và lỗi webhook)
    TimeOut = 5,         -- Hoặc cứ 5 giây gửi 1 lần
    Remote = "CommF_"    -- Chỉ bắt Remote này
}

-- KHỞI TẠO DỊCH VỤ
local HttpService = game:GetService("HttpService")
local RequestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

if not RequestFunc then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Lỗi Executor";
        Text = "Không hỗ trợ gửi HTTP Request!";
        Duration = 5;
    })
    return
end

local LogQueue = {}
local LastSend = tick()

-- HÀM GỬI VỀ DISCORD
local function Dispatch()
    if #LogQueue == 0 then return end
    
    -- Gom code lại thành khối văn bản
    local content = table.concat(LogQueue, "\n")
    LogQueue = {} -- Xóa hàng đợi
    LastSend = tick()

    -- Tạo cấu trúc tin nhắn Discord (Embed)
    local payload = {
        ["username"] = "Blox Fruit Spy",
        ["avatar_url"] = "[https://i.imgur.com/8QZqX4A.png](https://i.imgur.com/8QZqX4A.png)", -- Icon Blox Fruit (tùy chọn)
        ["embeds"] = {{
            ["title"] = "📡 Logic Captured",
            ["description"] = string.format("```lua\n%s\n```", content), -- Đóng gói vào Code Block
            ["color"] = 65280, -- Màu xanh lá cây (Green)
            ["footer"] = {
                ["text"] = "Captured at: " .. os.date("%H:%M:%S")
            }
        }}
    }

    -- Gửi Request
    pcall(function()
        RequestFunc({
            Url = getgenv().WebhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- HÀM ĐỊNH DẠNG CODE
local function Clean(v)
    if type(v) == "string" then return '"'..v..'"' 
    elseif type(v) == "Vector3" then return string.format("Vector3.new(%d, %d, %d)", v.X, v.Y, v.Z)
    elseif type(v) == "CFrame" then return string.format("CFrame.new(%s)", tostring(v.Position))
    elseif type(v) == "table" then return "{...}"
    else return tostring(v) end
end

-- HOOK LOGIC (BẮT DỮ LIỆU)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    if (method == "FireServer" or method == "InvokeServer") and self.Name == Config.Remote then
        local args = {...}
        local str = ""
        for i,v in ipairs(args) do 
            str = str .. Clean(v) .. (i<#args and ", " or "") 
        end
        
        -- Tạo dòng code hoàn chỉnh
        local codeLine = string.format("game.ReplicatedStorage.Remotes.CommF_:%s(%s)", method, str)
        table.insert(LogQueue, codeLine)

        -- Nếu gom đủ số lượng thì gửi ngay
        if #LogQueue >= Config.MinBatch then
            Dispatch()
        end
    end

    return oldNamecall(self, ...)
end))

-- VÒNG LẶP CHẠY NGẦM (Gửi những gì còn sót lại mỗi 5s)
task.spawn(function()
    while task.wait(1) do
        if tick() - LastSend >= Config.TimeOut then
            Dispatch()
        end
    end
end)

-- THÔNG BÁO THÀNH CÔNG
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "DISCORD SPY ON";
    Text = "Đã kết nối Webhook thành công!";
    Duration = 5;
})
