-- ============================================================
-- AI Executor + SimpleSpy + DarkDex (BẢN CÓ LOG RÕ RÀNG)
-- ============================================================

-- Tạo GUI để hiển thị log (nếu không có console)
local function create_log_gui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AILogGUI"
    screenGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 500, 0, 400)
    frame.Position = UDim2.new(0.5, -250, 0.5, -200)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.8
    frame.Parent = screenGui

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, -10)
    textBox.Position = UDim2.new(0, 5, 0, 5)
    textBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.Text = "Đang khởi động..."
    textBox.TextWrapped = true
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.TextYAlignment = Enum.TextYAlignment.Top
    textBox.ClearTextOnFocus = false
    textBox.Parent = frame

    return textBox
end

local logBox = create_log_gui()

local function log(msg)
    print(msg)
    if logBox then
        logBox.Text = logBox.Text .. "\n" .. tostring(msg)
    end
end

log("=== BẮT ĐẦU CHẠY AI EXECUTOR ===")

-- ===== CẤU HÌNH =====
local AI_API_KEY = "sk-..."  -- THAY THẬT VÀO ĐÂY
local AI_ENDPOINT = "https://api.openai.com/v1/chat/completions"
local AI_MODEL = "gpt-4-turbo"
local MAX_TOKENS = 4000

-- ===== KIỂM TRA MÔI TRƯỜNG =====
log("Đang kiểm tra executor...")
local hasHttp = type(syn) == "table" and type(syn.request) == "function"
if not hasHttp then
    hasHttp = type(http) == "table" and type(http.request) == "function"
end
if not hasHttp then
    hasHttp = type(request) == "function"
end
if not hasHttp then
    log("LƯU Ý: Không tìm thấy hàm HTTP (syn.request/http.request/request).")
    log("Script sẽ chỉ thu thập dữ liệu và in ra, không gửi được lên AI.")
end

local hasWritefile = type(writefile) == "function"
if not hasWritefile then
    log("LƯU Ý: writefile không khả dụng, sẽ không lưu được file.")
end

-- ===== HÀM HTTP (dùng được) =====
local function http_request(url, method, headers, body)
    if syn and syn.request then
        local resp = syn.request({
            Url = url,
            Method = method or "POST",
            Headers = headers or {},
            Body = body or ""
        })
        return resp.Body
    elseif http and http.request then
        local resp = http.request({
            Url = url,
            Method = method or "POST",
            Headers = headers or {},
            Body = body or ""
        })
        return resp.Body
    elseif request then
        local resp = request({
            Url = url,
            Method = method or "POST",
            Headers = headers or {},
            Body = body or ""
        })
        return resp.Body
    else
        -- fallback: dùng game:HttpGet (chỉ GET được, không POST)
        if method == "GET" then
            return game:HttpGet(url, true)
        else
            error("Không có HTTP POST, không thể gửi lên AI.")
        end
    end
end

-- ===== KÍCH HOẠT TOOL =====
local function load_tools()
    log("Đang tải SimpleSpy...")
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))()
    end)
    if success then
        log("✓ SimpleSpy đã được kích hoạt.")
    else
        log("✗ Lỗi SimpleSpy: " .. tostring(err))
    end

    log("Đang tải DarkDex V3...")
    success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua", true))()
    end)
    if success then
        log("✓ DarkDex đã được kích hoạt.")
    else
        log("✗ Lỗi DarkDex: " .. tostring(err))
    end

    task.wait(2)
end

-- ===== THU THẬP =====
local function collect_game_data()
    log("Bắt đầu thu thập dữ liệu game...")

    load_tools()

    -- Lấy dữ liệu từ SimpleSpy
    local spy_logs = getgenv().SimpleSpyData or _G.SimpleSpyData or {}
    log("SimpleSpy logs: " .. #spy_logs .. " mục")

    -- Lấy instance list
    local all_instances = getinstances and getinstances() or {}
    log("Tổng instances: " .. #all_instances)

    local instances_info = {}
    for i, inst in ipairs(all_instances) do
        if i > 2000 then break end
        table.insert(instances_info, {
            class = inst.ClassName,
            name = inst.Name,
            path = inst:GetFullName()
        })
    end

    -- Lấy remote đã ghi
    local remotes = {}
    if spy_logs and type(spy_logs) == "table" then
        for k, v in pairs(spy_logs) do
            remotes[k] = #v
        end
    end

    local data = {
        instances = instances_info,
        remotes = remotes,
        spy_logs = spy_logs,
        timestamp = os.time()
    }

    log("Thu thập xong. Số instance lấy: " .. #instances_info)
    return data
end

-- ===== CHUYỂN JSON =====
local function serialize_data(data)
    return game:GetService("HttpService"):JSONEncode(data)
end

-- ===== GỬI AI (nếu có key) =====
local function ask_ai_to_generate_script(game_data_json)
    if AI_API_KEY == "sk-..." then
        log("⚠️ CHƯA CÓ API KEY - Không gửi được lên AI.")
        log("Vui lòng thay AI_API_KEY bằng key thật.")
        return nil
    end

    log("Đang gửi dữ liệu lên AI... (có thể mất 15-30 giây)")

    local prompt = [[
Bạn là chuyên gia Lua/Roblox. Dựa trên dữ liệu game bên dưới, viết script Lua để hook remote và hiển thị thông tin.

Dữ liệu (JSON):
]] .. game_data_json

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. AI_API_KEY
    }
    local body = {
        model = AI_MODEL,
        messages = {
            { role = "system", content = "Chỉ trả về mã Lua." },
            { role = "user", content = prompt }
        },
        max_tokens = MAX_TOKENS,
        temperature = 0.3
    }

    local success, response = pcall(function()
        return http_request(AI_ENDPOINT, "POST", headers, game:GetService("HttpService"):JSONEncode(body))
    end)

    if not success then
        log("Lỗi HTTP: " .. tostring(response))
        return nil
    end

    if not response then
        log("Phản hồi rỗng từ AI.")
        return nil
    end

    local decoded = game:GetService("HttpService"):JSONDecode(response)
    if decoded and decoded.choices and decoded.choices[1] then
        local script_text = decoded.choices[1].message.content
        log("✓ Nhận được script từ AI (dài " .. #script_text .. " ký tự)")
        return script_text
    else
        log("Phản hồi AI không hợp lệ: " .. tostring(response):sub(1, 200))
        return nil
    end
end

-- ===== THỰC THI SCRIPT =====
local function execute_generated_script(script_text)
    if not script_text then return end
    log("Đang thực thi script do AI tạo...")
    local success, err = pcall(function()
        loadstring(script_text)()
    end)
    if success then
        log("✓ Script đã chạy thành công!")
    else
        log("✗ Lỗi khi chạy: " .. tostring(err))
    end
    -- Lưu file nếu có thể
    if hasWritefile then
        writefile("ai_script_output.lua", script_text)
        log("Đã lưu script vào ai_script_output.lua")
    end
end

-- ===== HÀM CHÍNH =====
local function main()
    log("=========================================")
    log("  AI Executor + SimpleSpy + DarkDex")
    log("  Phiên bản có log chi tiết")
    log("=========================================")

    -- Bước 1: Thu thập
    local raw_data = collect_game_data()

    -- Bước 2: JSON
    local json_data = serialize_data(raw_data)
    if #json_data > 80000 then
        json_data = json_data:sub(1, 80000)
        log("Dữ liệu bị cắt ngắn để tránh quá tải.")
    end

    -- Bước 3: Gửi AI
    local script_text = ask_ai_to_generate_script(json_data)

    -- Bước 4: Chạy thử
    if script_text and #script_text > 10 then
        execute_generated_script(script_text)
    else
        log("Không có script để chạy. Kiểm tra lại API key hoặc kết nối.")
    end

    log("=== KẾT THÚC ===")
end

-- Chạy với bảo vệ
local ok, err = pcall(main)
if not ok then
    log("LỖI CHÍNH: " .. tostring(err))
end
