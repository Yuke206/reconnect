-- auto_notify_disconnect.lua
-- Dùng trong executor (Fluxus / Synapse / ...)
-- Gửi text về webhook khi phát hiện disconnect (GuiService.ErrorMessageChanged)

local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer
local PLACE_ID = tostring(game.PlaceId or 0)
local JOB_ID = tostring(game.JobId or "")
local PLAYER_NAME = LOCAL_PLAYER and LOCAL_PLAYER.Name or "Unknown"

-- ======= CẤU HÌNH =======
local WEBHOOK_URL = "https://discord.com/api/webhooks/1428597330935808012/yIdgr2ZcuEX-Ru8226nThkwrgbNU0qiBGl2GayVF6yNbiwhpKiAkADLZzGOaMF0MR9ID" -- <-- THAY Ở ĐÂY
local DEBOUNCE_SECONDS = 30
local INCLUDE_GAME_INFO = true
-- ========================

local lastSent = 0

local function now_iso()
    local ok, dt = pcall(function() return DateTime.now():ToIsoDate() end)
    if ok and dt then return dt end
    return os.date("%Y-%m-%dT%H:%M:%S")
end

local function send_webhook(message_text)
    if not WEBHOOK_URL or WEBHOOK_URL == "" then
        warn("[AutoNotify] WEBHOOK_URL chưa được thiết lập.")
        return false, "no_webhook"
    end

    local cur = tick()
    if cur - lastSent < DEBOUNCE_SECONDS then
        warn("[AutoNotify] Debounce: bỏ qua gửi.")
        return false, "debounced"
    end

    if not HttpService or not HttpService.HttpEnabled then
        warn("[AutoNotify] HttpService chưa bật / không khả dụng.")
        return false, "http_disabled"
    end

    local payload = {
        content = message_text
    }

    local body = HttpService:JSONEncode(payload)

    local ok, err = pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
    end)

    if ok then
        lastSent = cur
        print("[AutoNotify] Đã gửi webhook.")
        return true
    else
        warn("[AutoNotify] Gửi webhook thất bại:", err)
        return false, err
    end
end

local function build_message(reason)
    local t = now_iso()
    local lines = {}
    table.insert(lines, ("[AutoDisconnect Notify] %s"):format(t))
    table.insert(lines, ("Reason: %s"):format(tostring(reason)))
    if INCLUDE_GAME_INFO then
        table.insert(lines, ("Player: %s"):format(PLAYER_NAME))
        table.insert(lines, ("PlaceId: %s"):format(PLACE_ID))
        if JOB_ID ~= "" then table.insert(lines, ("JobId: %s"):format(JOB_ID)) end
    end
    return table.concat(lines, "\n")
end

GuiService.ErrorMessageChanged:Connect(function(msg)
    if msg and msg ~= "" then
        local message = build_message(msg)
        task.spawn(function()
            local ok, err = send_webhook(message)
            if not ok then warn("[AutoNotify] Lỗi gửi:", err) end
        end)
    end
end)

-- Dự phòng: kiểm tra periodical nếu game not loaded
task.spawn(function()
    while true do
        task.wait(5)
        if not game:IsLoaded() then
            local message = build_message("Game not loaded / possible disconnect (periodic check)")
            send_webhook(message)
            task.wait(DEBOUNCE_SECONDS)
        end
    end
end)

print("[AutoNotify] Script khởi động.")
