-- Clauto-Complete: Inline LLM Tool for macOS
-- Invoke Claude from any app via hotkey, type a prompt, get response at cursor

local CLAUDE_PATH = "/Users/cadenmidkiff/.local/bin/claude"
local SYSTEM_PROMPT = "Be concise. No clarification needed. Response inserted at cursor."
local TIMEOUT_SECONDS = 60

-- State
local currentTask = nil
local screenshotPath = nil
local originalClipboard = nil
local chooser = nil

-- Cleanup function
local function cleanup()
    if screenshotPath and hs.fs.attributes(screenshotPath) then
        os.remove(screenshotPath)
        screenshotPath = nil
    end
end

-- Kill any running task
local function killCurrentTask()
    if currentTask and currentTask:isRunning() then
        currentTask:terminate()
        currentTask = nil
    end
end

-- Paste text at cursor using clipboard
local function pasteAtCursor(text)
    -- Save original clipboard
    originalClipboard = hs.pasteboard.getContents()

    -- Set response as clipboard content
    hs.pasteboard.setContents(text)

    -- Simulate Cmd+V
    hs.eventtap.keyStroke({"cmd"}, "v")

    -- Restore original clipboard after delay
    hs.timer.doAfter(0.5, function()
        if originalClipboard then
            hs.pasteboard.setContents(originalClipboard)
            originalClipboard = nil
        end
    end)
end

-- Show loading indicator
local function showLoading()
    hs.alert.show("Asking Claude...", 2)
end

-- Show error message
local function showError(message)
    hs.alert.show("Error: " .. message, 4)
end

-- Execute claude CLI asynchronously
local function executeClaude(prompt, withScreenshot)
    killCurrentTask()
    showLoading()

    local args = {"-p", prompt, "--system", SYSTEM_PROMPT}

    -- Add screenshot if captured
    if withScreenshot and screenshotPath then
        table.insert(args, screenshotPath)
    end

    local stdout = ""
    local stderr = ""

    currentTask = hs.task.new(CLAUDE_PATH, function(exitCode, stdOut, stdErr)
        -- Callback when task completes
        currentTask = nil
        cleanup()

        if exitCode == 0 then
            local response = stdOut:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
            if response ~= "" then
                pasteAtCursor(response)
            else
                showError("Empty response")
            end
        else
            -- Parse error message
            local errorMsg = stdErr or "Unknown error"
            if errorMsg:match("rate") or errorMsg:match("limit") then
                showError("Rate limited")
            elseif errorMsg:match("network") or errorMsg:match("connection") then
                showError("Network error")
            elseif errorMsg:match("auth") then
                showError("Authentication error")
            else
                showError("Claude failed: " .. exitCode)
            end
        end
    end, args)

    -- Set up streaming callbacks for stdout/stderr
    currentTask:setStreamingCallback(function(task, stdOut, stdErr)
        if stdOut then stdout = stdout .. stdOut end
        if stdErr then stderr = stderr .. stdErr end
        return true
    end)

    -- Start the task
    if not currentTask:start() then
        showError("Failed to start Claude")
        cleanup()
        return
    end

    -- Set timeout
    hs.timer.doAfter(TIMEOUT_SECONDS, function()
        if currentTask and currentTask:isRunning() then
            currentTask:terminate()
            currentTask = nil
            cleanup()
            showError("Timeout after " .. TIMEOUT_SECONDS .. "s")
        end
    end)
end

-- Handle chooser selection
local function onChooserChoice(choice)
    if choice == nil then
        -- User cancelled
        cleanup()
        return
    end

    local prompt = choice.text
    if prompt and prompt ~= "" then
        executeClaude(prompt, screenshotPath ~= nil)
    else
        cleanup()
    end
end

-- Handle query changes (for live input)
local function onChooserQuery(query)
    if query and query ~= "" then
        return {{
            text = query,
            subText = "Press Enter to send to Claude"
        }}
    end
    return {}
end

-- Create the chooser
local function createChooser()
    chooser = hs.chooser.new(onChooserChoice)
    chooser:queryChangedCallback(onChooserQuery)
    chooser:searchSubText(false)
    chooser:placeholderText("Ask Claude...")
    chooser:rows(1)
    return chooser
end

-- Show prompt popup
local function showPrompt(withScreenshot)
    -- Kill any existing task
    killCurrentTask()
    cleanup()

    -- Capture screenshot if requested
    if withScreenshot then
        local screen = hs.screen.mainScreen()
        screenshotPath = os.tmpname() .. ".png"
        screen:shotAsPNG(screenshotPath)
    end

    -- Create or reuse chooser
    if not chooser then
        chooser = createChooser()
    end

    -- Show the chooser
    chooser:query("")
    chooser:choices({})
    chooser:show()
end

-- Bind hotkeys
-- Ctrl+Space: Text-only prompt
hs.hotkey.bind({"ctrl"}, "space", function()
    showPrompt(false)
end)

-- Ctrl+Shift+Space: Prompt with screenshot
hs.hotkey.bind({"ctrl", "shift"}, "space", function()
    showPrompt(true)
end)

-- Notify that config is loaded
hs.alert.show("Clauto-Complete loaded", 2)
