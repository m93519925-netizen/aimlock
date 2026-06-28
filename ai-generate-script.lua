-- ============================================================
-- AI Executor + SimpleSpy + DarkDex
-- Phiên bản sửa lỗi JSON + API mới
-- ============================================================

-- Tạo GUI để hiển thị log
local function create_log_gui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AILogGUI"
    screenGui.Parent = game:GetService("CoreGui") or gethui()

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 600, 0, 500)
    frame.Position = UDim2.new(0.5, -300, 0.5, -250)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.85
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
local AI_API_KEY = "sk-Bvd9rSR06Rtroz8NCvTKJA"  -- THAY THẬT VÀO ĐÂY
local AI_ENDPOINT = "https://llm.thesparkdaily.com/v1/chat/completions"
local AI_MODEL = "deepseek-v4-flash"
local MAX_TOKENS = 9999999999999999999999  -- giới hạn thực tế sẽ được API xử lý

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
    log("LƯU Ý: Không tìm thấy hàm HTTP. Chỉ thu thập dữ liệu.")
end

local hasWritefile = type(writefile) == "function"
if not hasWritefile then
    log("LƯU Ý: writefile không khả dụng.")
end

-- ===== HÀM HTTP =====
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
        if method == "GET" then
            return game:HttpGet(url, true)
        else
            error("Không có HTTP POST.")
        end
    end
end

-- ===== HÀM LÀM SẠCH DỮ LIỆU ĐỂ JSON HÓA =====
local function sanitize_for_json(value, seen)
    if seen == nil then seen = {} end
    if value == nil then return nil end

    local t = type(value)
    if t == "string" or t == "number" or t == "boolean" then
        -- Kiểm tra number có phải NaN hoặc Infinity không
        if t == "number" and (value ~= value or value == math.huge or value == -math.huge) then
            return "0"  -- thay bằng chuỗi để tránh lỗi
        end
        return value
    elseif t == "table" then
        if seen[value] then
            return "[CircularRef]"
        end
        seen[value] = true
        local new_table = {}
        for k, v in pairs(value) do
            local safe_key = sanitize_for_json(k, seen)
            local safe_val = sanitize_for_json(v, seen)
            if safe_key ~= nil and safe_val ~= nil then
                new_table[safe_key] = safe_val
            end
        end
        return new_table
    elseif t == "function" then
        return "[Function]"
    elseif t == "userdata" then
        return "[UserData]"
    else
        return tostring(value)
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

-- ===== THU THẬP DỮ LIỆU =====
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
    local count = 0
    for _, inst in ipairs(all_instances) do
        if count >= 2000 then break end
        count = count + 1
        local info = {
            class = inst.ClassName,
            name = inst.Name,
            path = inst:GetFullName()
        }
        table.insert(instances_info, info)
    end

    -- Lấy remote đã ghi
    local remotes = {}
    if type(spy_logs) == "table" then
        for k, v in pairs(spy_logs) do
            if type(v) == "table" then
                remotes[tostring(k)] = #v
            end
        end
    end

    local data = {
        instances = instances_info,
        remotes = remotes,
        timestamp = os.time()
    }

    log("Thu thập xong. Số instance lấy: " .. count)
    return data
end

-- ===== CHUYỂN JSON CÓ LÀM SẠCH =====
local function serialize_data(data)
    local cleaned = sanitize_for_json(data)
    if cleaned == nil then
        error("Dữ liệu sau làm sạch rỗng.")
    end
    return game:GetService("HttpService"):JSONEncode(cleaned)
end

-- ===== GỬI AI =====
local function ask_ai_to_generate_script(game_data_json)
    log("Đang gửi dữ liệu lên AI (endpoint: " .. AI_ENDPOINT .. ")...")

    local prompt = [[
Bạn là chuyên gia Lua/Roblox. Dựa trên dữ liệu game dưới đây (danh sách instance và remote đã phát hiện), hãy viết một script Lua hoàn chỉnh để:
- Hook tất cả RemoteEvent và RemoteFunction.
- In ra console và GUI danh sách remote kèm tham số.
- Tự động chặn hoặc gửi lại remote theo nhu cầu.

Chỉ trả về mã Lua, không giải thích. Mã có chú thích.

Dữ liệu (JSON):
]] .. game_data_json

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. AI_API_KEY
    }
    local body = {
        model = AI_MODEL,
        messages = {
            { role = "system", content = "Bạn là chuyên gia Lua, chỉ trả về mã hợp lệ." },
            { role = "user", content = prompt }
        },
        max_tokens = 4000,  -- giới hạn thực tế
        temperature = 0.2
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
        log("Phản hồi AI không hợp lệ: " .. tostring(response):sub(1, 300))
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
    if hasWritefile then
        writefile("ai_script_output.lua", script_text)
        log("Đã lưu script vào ai_script_output.lua")
    end
end

-- ===== HÀM CHÍNH =====
local function main()
    log("=========================================")
    log("  AI Executor + SimpleSpy + DarkDex")
    log("  Phiên bản sửa lỗi JSON")
    log("=========================================")

    local raw_data = collect_game_data()
    local json_data = serialize_data(raw_data)
    log("Dữ liệu JSON dài: " .. #json_data .. " ký tự")

    if #json_data > 80000 then
        json_data = json_data:sub(1, 80000)
        log("Dữ liệu bị cắt ngắn.")
    end

    local script_text = ask_ai_to_generate_script(json_data)

    if script_text and #script_text > 10 then
        execute_generated_script(script_text)
    else
        log("Không có script để chạy.")
    end

    log("=== KẾT THÚC ===")
end

local ok, err = pcall(main)
if not ok then
    log("LỖI CHÍNH: " .. tostring(err))
end
