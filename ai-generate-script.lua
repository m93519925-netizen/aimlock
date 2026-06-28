-- ============================================================
-- Delta AI Executor - Tích hợp SimpleSpy + DarkDex + AI
-- ============================================================

-- ===== CẤU HÌNH =====
local AI_API_KEY = "sk-Bvd9rSR06Rtroz8NCvTKJA"  -- Thay bằng key thật
local AI_ENDPOINT = "https://llm.thesparkdaily.com/v1"
local AI_MODEL = "deepseek-v4-flash"
local MAX_TOKENS = 99999999999999999

-- ===== HÀM HTTP =====
local function http_request(url, method, headers, body)
    local request_func = syn and syn.request or (http and http.request) or request
    if not request_func then
        warn("Không tìm thấy HTTP request, dùng game:HttpGet thay thế")
        if game:HttpGet then
            if method == "GET" then
                return game:HttpGet(url, true)
            else
                return game:HttpGet(url, true) -- fallback
            end
        end
        error("Không có phương thức HTTP")
    end
    local response = request_func({
        Url = url,
        Method = method or "POST",
        Headers = headers or {},
        Body = body or ""
    })
    return response.Body
end

-- ===== KÍCH HOẠT SIMPLESPY & DARKDEX (bắt buộc) =====
local function load_tools()
    print("[AI] Đang kích hoạt SimpleSpy và DarkDex...")
    
    -- SimpleSpy
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/exxtremestuffs/SimpleSpySource/master/SimpleSpy.lua"))()
    end)
    if not success then
        warn("[AI] Lỗi SimpleSpy: " .. tostring(err))
    else
        print("[AI] SimpleSpy đã chạy.")
    end

    -- DarkDex V3
    success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Babyhamsta/RBLX_Scripts/main/Universal/BypassedDarkDexV3.lua", true))()
    end)
    if not success then
        warn("[AI] Lỗi DarkDex: " .. tostring(err))
    else
        print("[AI] DarkDex đã chạy.")
    end

    -- Đợi một chút để tool khởi tạo
    task.wait(1)
end

-- ===== THU THẬP DỮ LIỆU =====
local function collect_game_data()
    print("[AI] Bắt đầu thu thập dữ liệu game...")

    -- 1. Kích hoạt tool trước
    load_tools()

    -- 2. Lấy dữ liệu từ SimpleSpy (nếu có biến toàn cục)
    local spy_logs = getgenv().SimpleSpyData or {}
    -- Nếu SimpleSpy không lưu vào getgenv, thử các vị trí khác
    if not next(spy_logs) then
        spy_logs = _G.SimpleSpyData or {}
    end

    -- 3. Lấy dữ liệu từ Dex (nếu có biến toàn cục)
    local dex_data = getgenv().DexData or {}
    if not next(dex_data) then
        dex_data = _G.DexData or {}
    end

    -- 4. Lấy toàn bộ instances (nếu Dex đã mở, có thể lấy danh sách từ nó)
    local all_instances = getinstances and getinstances() or {}
    local instances_info = {}
    for i, inst in ipairs(all_instances) do
        if i > 3000 then break end
        table.insert(instances_info, {
            class = inst.ClassName,
            name = inst.Name,
            path = inst:GetFullName(),
            parent = inst.Parent and inst.Parent.Name
        })
    end

    -- 5. Lấy các remote từ SimpleSpy (nếu có)
    local remotes = {}
    if spy_logs and type(spy_logs) == "table" then
        for remote_name, calls in pairs(spy_logs) do
            remotes[remote_name] = #calls -- số lần gọi
        end
    end

    -- 6. Gom tất cả vào một bảng
    local data = {
        instances = instances_info,
        remotes = remotes,
        spy_logs = spy_logs,   -- chi tiết log
        dex_data = dex_data,
        timestamp = os.time()
    }

    print("[AI] Thu thập xong. Số instance: " .. #instances_info)
    return data
end

-- ===== NÉN JSON =====
local function serialize_data(data)
    return game:GetService("HttpService"):JSONEncode(data)
end

-- ===== GỬI LÊN AI =====
local function ask_ai_to_generate_script(game_data_json)
    print("[AI] Đang gửi dữ liệu lên AI...")

    local prompt = [[
Bạn là chuyên gia Lua/Roblox. Dựa trên dữ liệu game (bao gồm toàn bộ instance, remote đã được SimpleSpy ghi log, và dữ liệu từ Dex), hãy viết một script Lua hoàn chỉnh chạy trên executor Delta nhằm:
- Tự động hook tất cả RemoteEvent và RemoteFunction đã phát hiện.
- In ra console danh sách remote kèm tham số mẫu.
- Tạo một GUI hiển thị tần suất gọi remote.
- Tự động chặn/gửi lại remote theo ý muốn (ví dụ: farm).
- Sử dụng dữ liệu đã ghi nhận để tối ưu hóa.

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
        max_tokens = MAX_TOKENS,
        temperature = 0.2
    }
    local response = http_request(AI_ENDPOINT, "POST", headers, game:GetService("HttpService"):JSONEncode(body))
    if not response then error("[AI] Không có phản hồi") end

    local decoded = game:GetService("HttpService"):JSONDecode(response)
    if decoded and decoded.choices and decoded.choices[1] then
        return decoded.choices[1].message.content
    else
        error("[AI] Phản hồi không hợp lệ: " .. tostring(response))
    end
end

-- ===== THỰC THI SCRIPT NHẬN ĐƯỢC =====
local function execute_generated_script(script_text)
    print("[AI] Đang thực thi script do AI tạo...")
    local success, err = pcall(function()
        loadstring(script_text)()
    end)
    if not success then
        warn("[AI] Lỗi: " .. tostring(err))
        writefile("ai_script_error.lua", script_text)
    else
        print("[AI] Thực thi thành công!")
    end
end

-- ===== HÀM CHÍNH =====
local function main()
    print("========================================")
    print("  AI Executor + SimpleSpy + DarkDex")
    print("========================================")

    if AI_API_KEY == "sk-..." then
        error("Bạn chưa cấu hình API key.")
    end

    -- Thu thập
    local raw = collect_game_data()
    local json = serialize_data(raw)
    if #json > 100000 then json = json:sub(1, 100000) end

    -- Gửi AI
    local script_text = ask_ai_to_generate_script(json)

    -- Lưu và chạy
    if script_text and #script_text > 10 then
        writefile("ai_generated_final.lua", script_text)
        execute_generated_script(script_text)
    else
        error("Script rỗng")
    end
end

-- Chạy
pcall(main)
