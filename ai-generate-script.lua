-- ============================================================
-- TEST API AI - KHÔNG TÍCH HỢP GAME
-- ============================================================

-- Tạo GUI log
local function create_log_gui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TestAPIGUI"
    screenGui.Parent = game:GetService("CoreGui") or gethui()

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 600, 0, 400)
    frame.Position = UDim2.new(0.5, -300, 0.5, -200)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    frame.BackgroundTransparency = 0.9
    frame.Parent = screenGui

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, -10)
    textBox.Position = UDim2.new(0, 5, 0, 5)
    textBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.Text = "Đang khởi động test..."
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

log("=== TEST API AI ===")

-- Cấu hình
local API_KEY = "sk-Bvd9rSR06Rtroz8NCvTKJA"
local ENDPOINT = "https://llm.thesparkdaily.com/v1/chat/completions"
local MODEL = "deepseek-v4-flash"

-- Hàm HTTP (thử các phương thức)
local function http_post(url, headers, body)
    -- Thử syn.request
    if syn and syn.request then
        log("Dùng syn.request")
        local resp = syn.request({
            Url = url,
            Method = "POST",
            Headers = headers,
            Body = body
        })
        return resp.Body, resp.StatusCode
    end
    -- Thử http.request
    if http and http.request then
        log("Dùng http.request")
        local resp = http.request({
            Url = url,
            Method = "POST",
            Headers = headers,
            Body = body
        })
        return resp.Body, resp.StatusCode
    end
    -- Thử request toàn cục
    if request then
        log("Dùng request")
        local resp = request({
            Url = url,
            Method = "POST",
            Headers = headers,
            Body = body
        })
        return resp.Body, resp.StatusCode
    end
    -- Không có POST → báo lỗi
    return nil, nil
end

-- Gửi một câu hỏi đơn giản để test
local function test_api()
    log("Gửi yêu cầu đến: " .. ENDPOINT)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. API_KEY
    }
    local body_data = {
        model = MODEL,
        messages = {
            { role = "user", content = "Nói 'Xin chào' bằng tiếng Việt." }
        },
        max_tokens = 50,
        temperature = 0.7
    }
    local body_json = game:GetService("HttpService"):JSONEncode(body_data)
    log("Body JSON: " .. body_json:sub(1, 100) .. "...")

    local success, response, status = pcall(http_post, ENDPOINT, headers, body_json)
    if not success then
        log("LỖI khi gọi HTTP: " .. tostring(response))
        return
    end

    log("Status code: " .. tostring(status or "không có"))
    log("Phản hồi thô (độ dài " .. tostring(#(response or "")) .. "):")
    log(response or "(rỗng)")

    -- Thử parse JSON
    if response and response ~= "" then
        local decoded = game:GetService("HttpService"):JSONDecode(response)
        if decoded and decoded.choices then
            log("✓ Parse thành công!")
            log("Nội dung: " .. tostring(decoded.choices[1].message.content))
        else
            log("✗ Không parse được hoặc thiếu trường 'choices'")
            log("Dữ liệu nhận: " .. tostring(decoded))
        end
    else
        log("Không có phản hồi để parse.")
    end
end

-- Chạy test
pcall(test_api)
log("=== KẾT THÚC TEST ===")
