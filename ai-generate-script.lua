-- ============================================================
-- AI Executor + SimpleSpy + DarkDex (FIX JSON ERROR)
-- ============================================================

-- Tạo GUI hiển thị log
local function create_log_gui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AILogGUI"
    screenGui.Parent = game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 550, 0, 450)
    frame.Position = UDim2.new(0.5, -275, 0.5, -225)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.85
    frame.Parent = screenGui

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, -10)
    textBox.Position = UDim2.new(0, 5, 0, 5)
    textBox.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.Text = "Khởi động..."
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

log("=== AI EXECUTOR (FIX JSON) ===")

-- ===== CẤU HÌNH API (lấy từ bạn) =====
local AI_API_KEY = "sk-Bvd9rSR06Rtroz8NCvTKJA"
local AI_ENDPOINT = "https://llm.thesparkdaily.com/v1/chat/completions"
local AI_MODEL = "deepseek-v4-flash"
local MAX_TOKENS = 9999999999999999999999  -- con số lớn, nhưng thực tế API sẽ giới hạn

-- ===== HÀM HTTP (tương thích đa executor) =====
local function http_request(url, method, headers, body)
    if syn and syn.request then
        local resp = syn.request({Url=url, Method=method, Headers=headers, Body=body})
        return resp.Body
    elseif http and http.request then
        local resp = http.request({Url=url, Method=method, Headers=headers, Body=body})
        return resp.Body
    elseif request then
        local resp = request({Url=url, Method=method, Headers=headers, Body=body})
        return resp.Body
    else
        -- fallback GET
        if method == "GET" then return game:HttpGet(url, true) end
        error("Không có HTTP POST")
    end
end

-- ===== DỌN SẠCH DỮ LIỆU ĐỂ ENCODE JSON =====
local function clean_data_for_json(data, max_depth)
    max_depth = max_depth or 5
    local seen = {}
    local function clean(val, depth)
        if depth > max_depth then return "[...]" end
        local t = type(val)
        if t == "string" then return val
        elseif t == "number" then return val
        elseif t == "boolean" then return val
        elseif t == "nil" then return nil
        elseif t == "function" then return "[function]"
        elseif t == "userdata" then return "[userdata]"
        elseif t == "thread" then return "[thread]"
        elseif t == "table" then
            if seen[val] then return "[circular]" end
            seen[val] = true
            local cleaned = {}
            for k, v in pairs(val) do
                local clean_k = clean(k, depth+1)
                local clean_v = clean(v, depth+1)
                if clean_k ~= nil and clean_v ~= nil then
                    cleaned[clean_k] = clean_v
                end
            end
            seen[val] = nil
            return cleaned
        else
            return tostring(val)
        end
    end
    return clean(data, 1)
end

-- ===== KÍCH HOẠT TOOL =====
local function load_tools()
    log("Đang tải SimpleSpy...")
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))()
    end)
    if success then log("✓ SimpleSpy đã được kích hoạt.") else log("✗ Lỗi SimpleSpy: "..tostring(err)) end

    log("Đang tải DarkDex V3...")
    success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua", true))()
    end)
    if success then log("✓ DarkDex đã được kích hoạt.") else log("✗ Lỗi DarkDex: "..tostring(err)) end

    task.wait(1.5)
end

-- ===== THU THẬP DỮ LIỆU =====
local function collect_game_data()
    log("Bắt đầu thu thập dữ liệu game...")
    load_tools()

    -- Lấy log từ SimpleSpy (nếu có)
    local spy_logs = getgenv().SimpleSpyData or _G.SimpleSpyData or {}
    log("SimpleSpy logs: " .. (type(spy_logs)=="table" and #spy_logs or 0) .. " mục")

    -- Lấy tất cả instances (giới hạn)
    local all_instances = getinstances and getinstances() or {}
    log("Tổng instances: " .. #all_instances)

    local instances_info = {}
    local count = 0
    for i, inst in ipairs(all_instances) do
        if count >= 2000 then break end
        -- Chỉ lấy những instance có tên hoặc class quan trọng (lọc bớt)
        local name = inst.Name or ""
        local class = inst.ClassName or ""
        if name ~= "" or class ~= "" then
            table.insert(instances_info, {
                class = class,
                name = name,
                path = inst:GetFullName and inst:GetFullName() or ""
            })
            count = count + 1
        end
    end

    -- Lấy remote đã ghi (nếu có)
    local remotes = {}
    if type(spy_logs) == "table" then
        for k, v in pairs(spy_logs) do
            if type(k) == "string" and type(v) == "table" then
                remotes[k] = #v
            end
        end
    end

    local raw_data = {
        instances = instances_info,
        remotes = remotes,
        spy_logs = spy_logs,   -- có thể chứa function, sẽ được dọn sạch sau
        timestamp = os.time()
    }

    log("Thu thập xong. Số instance lấy: " .. #instances_info)
    return raw_data
end

-- ===== CHUYỂN ĐỔI JSON (với làm sạch) =====
local function serialize_data(data)
    local cleaned = clean_data_for_json(data, 6)   -- độ sâu 6
    local json = game:GetService("HttpService"):JSONEncode(cleaned)
    -- Giới hạn kích thước để tránh quá tải API
    if #json > 80000 then
        json = json:sub(1, 80000)
        log("Dữ liệu bị cắt ngắn (80k ký tự)")
    end
    return json
end

-- ===== GỬI LÊN AI =====
local function ask_ai_to_generate_script(game_data_json)
    log("Đang gửi lên AI: " .. AI_ENDPOINT)
    log("Model: " .. AI_MODEL)

    local prompt = [[
Bạn là chuyên gia Lua/Roblox. Dựa trên dữ liệu game (instance, remote, log từ SimpleSpy), viết một script Lua hoàn chỉnh để hook remote, hiển thị thông tin và có thể farm. Trả về nguyên mã Lua, không giải thích.

Dữ liệu (JSON):
]] .. game_data_json

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. AI_API_KEY
    }
    local body = {
        model = AI_MODEL,
        messages = {
            { role = "system", content = "Bạn là chuyên gia Lua, chỉ trả về mã." },
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

    if not response or response == "" then
        log("Phản hồi rỗng từ AI.")
        return nil
    end

    local decoded = game:GetService("HttpService"):JSONDecode(response)
    if decoded and decoded.choices and decoded.choices[1] then
        local script_text = decoded.choices[1].message.content
        log("✓ Nhận script từ AI (" .. #script_text .. " ký tự)")
        return script_text
    else
        log("Phản hồi không hợp lệ: " .. tostring(response):sub(1, 200))
        return nil
    end
end

-- ===== THỰC THI =====
local function execute_generated_script(script_text)
    if not script_text then return end
    log("Đang thực thi script AI...")
    local success, err = pcall(function()
        loadstring(script_text)()
    end)
    if success then
        log("✓ Script đã chạy thành công!")
    else
        log("✗ Lỗi: " .. tostring(err))
    end
    if writefile then
        writefile("ai_script_generated.lua", script_text)
        log("Đã lưu script vào ai_script_generated.lua")
    end
end

-- ===== HÀM CHÍNH =====
local function main()
    log("=====================================")
    log("  AI Executor + SimpleSpy + DarkDex")
    log("  Đã sửa lỗi JSON")
    log("=====================================")

    local raw = collect_game_data()
    local json = serialize_data(raw)
    log("Kích thước JSON: " .. #json .. " bytes")

    local script_text = ask_ai_to_generate_script(json)
    execute_generated_script(script_text)

    log("=== KẾT THÚC ===")
end

pcall(main)
