-- Clauto-Complete: Inline LLM Tool for macOS
-- Invoke Claude from any app via hotkey, type a prompt, get response at cursor

local CLAUDE_PATH = "/Users/cadenmidkiff/.local/bin/claude"
local SYSTEM_PROMPT = [[You help users write text that gets pasted at their cursor. You ARE them typing.

Put your response between <OUTPUT> tags. ONLY the content inside tags gets pasted.

Example - user asks "write a sick burn":
I'll write something sassy.
<OUTPUT>wow didn't know we were doing amateur hour today</OUTPUT>

The user only sees: wow didn't know we were doing amateur hour today]]
local AUTOCOMPLETE_PROMPT = [[Look at the user's screen. Find their cursor. Write what they should type next.

Put ONLY the text to paste between <OUTPUT> tags. You can think/reason outside the tags.

Example - user is in a chat replying to "wanna hang tomorrow?":
I can see they're in iMessage. I'll write a casual response.
<OUTPUT>yea im down, what time?</OUTPUT>

Example - user is coding and cursor is after "def ":
Looks like Python. They need a function name and params.
<OUTPUT>calculate_total(items, tax_rate):</OUTPUT>

RULES:
- ALWAYS include <OUTPUT> tags
- Best guess > no guess
- You ARE the user typing
- Content inside tags = what gets pasted]]
local TIMEOUT_SECONDS = 90

-- State
local currentTask = nil
local screenshotPath = nil
local originalClipboard = nil
local loadingAlert = nil

-- Cleanup function
local function cleanup()
    if screenshotPath then
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
    if loadingAlert then
        hs.alert.closeSpecific(loadingAlert)
        loadingAlert = nil
    end
end

-- Extract content between <OUTPUT> tags (case-insensitive)
local function extractOutput(text)
    -- Case-insensitive pattern for <output>...</output>
    local lower = text:lower()
    local startTag = lower:find("<output>")
    local endTag = lower:find("</output>")

    if startTag and endTag and endTag > startTag then
        -- Extract using positions from lowercase search, but from original text
        local content = text:sub(startTag + 8, endTag - 1)
        -- Trim whitespace
        return content:gsub("^%s*(.-)%s*$", "%1")
    end

    -- Fallback: return trimmed original if no tags found
    return text:gsub("^%s*(.-)%s*$", "%1")
end

-- Paste text at cursor using clipboard
local function pasteAtCursor(text)
    local extracted = extractOutput(text)
    originalClipboard = hs.pasteboard.getContents()
    hs.pasteboard.setContents(extracted)
    -- Small delay to let focus return to original app
    hs.timer.doAfter(0.05, function()
        hs.eventtap.keyStroke({"cmd"}, "v")
        hs.timer.doAfter(0.3, function()
            if originalClipboard then
                hs.pasteboard.setContents(originalClipboard)
                originalClipboard = nil
            end
        end)
    end)
end

-- Show/hide loading
local function showLoading(hasScreenshot)
    local msg = hasScreenshot and "Analyzing screenshot..." or "Asking Claude..."
    loadingAlert = hs.alert.show(msg, 999)
end

local function hideLoading()
    if loadingAlert then
        hs.alert.closeSpecific(loadingAlert)
        loadingAlert = nil
    end
end

-- Show error message
local function showError(message)
    hideLoading()
    hs.alert.show("Error: " .. message, 3)
end

-- Execute claude CLI
local function executeClaude(prompt, hasScreenshot)
    killCurrentTask()
    showLoading(hasScreenshot)

    local fullPrompt = prompt
    if hasScreenshot and screenshotPath then
        fullPrompt = "I've taken a screenshot of my screen. Read the image at " .. screenshotPath .. " and then: " .. prompt
    end

    local args = {
        "-p", fullPrompt,
        "--system-prompt", SYSTEM_PROMPT,
        "--allowedTools", "Read",
        "--model", "opus"
    }

    currentTask = hs.task.new(CLAUDE_PATH, function(exitCode, stdOut, stdErr)
        currentTask = nil
        hideLoading()
        cleanup()

        if exitCode == 0 then
            local response = stdOut:gsub("^%s*(.-)%s*$", "%1")
            if response ~= "" then
                pasteAtCursor(response)
            else
                showError("Empty response")
            end
        else
            local errorMsg = stdErr or ""
            if errorMsg:match("rate") or errorMsg:match("limit") then
                showError("Rate limited")
            elseif errorMsg:match("network") or errorMsg:match("connection") then
                showError("Network error")
            else
                showError("Failed (exit " .. exitCode .. ")")
            end
        end
    end, args)

    if not currentTask:start() then
        showError("Failed to start Claude")
        cleanup()
        return
    end

    hs.timer.doAfter(TIMEOUT_SECONDS, function()
        if currentTask and currentTask:isRunning() then
            currentTask:terminate()
            currentTask = nil
            cleanup()
            showError("Timeout")
        end
    end)
end

-- Capture screenshot of screen where mouse is located
local function captureScreenshot(callback)
    screenshotPath = "/tmp/clauto_" .. os.time() .. ".png"

    -- Get the screen where the mouse currently is
    local mouseScreen = hs.mouse.getCurrentScreen()
    local allScreens = hs.screen.allScreens()

    -- Find the display number (1-indexed for screencapture -D)
    local displayNum = 1
    for i, screen in ipairs(allScreens) do
        if screen:id() == mouseScreen:id() then
            displayNum = i
            break
        end
    end

    local task = hs.task.new("/usr/sbin/screencapture", function(exitCode, _, _)
        if exitCode == 0 then
            hs.alert.show("Screenshot captured (display " .. displayNum .. ")", 1)
            callback(true)
        else
            screenshotPath = nil
            showError("Screenshot failed")
            callback(false)
        end
    end, {"-x", "-D", tostring(displayNum), screenshotPath})
    task:start()
end

-- Chooser state
local chooser = nil
local currentCallback = nil
local hasScreenshotMode = false

-- Create Spotlight-style chooser
local function setupChooser()
    chooser = hs.chooser.new(function(choice)
        local query = chooser:query()
        local prompt = nil

        if choice and choice.text then
            prompt = choice.text
        elseif query and query ~= "" then
            prompt = query
        end

        if prompt and prompt ~= "" and currentCallback then
            currentCallback(prompt)
        else
            cleanup()
        end
        currentCallback = nil
    end)

    chooser:queryChangedCallback(function(query)
        if query and query ~= "" then
            chooser:choices({{
                text = query,
                subText = "↵ Send to Claude"
            }})
        else
            chooser:choices({})
        end
    end)

    chooser:searchSubText(false)
    chooser:bgDark(true)
    chooser:fgColor({hex = "#ffffff"})
    chooser:subTextColor({hex = "#888888"})
    chooser:rows(1)
    chooser:width(40)
end

-- Show Spotlight-style input
local function showChooser(hasScreenshot, callback)
    if not chooser then setupChooser() end

    currentCallback = callback
    hasScreenshotMode = hasScreenshot

    local placeholder = hasScreenshot and "What to do with screenshot..." or "Ask Claude..."
    chooser:placeholderText(placeholder)
    chooser:query("")
    chooser:choices({})
    chooser:show()
end

-- Main function
local function invokeClauder(withScreenshot)
    killCurrentTask()
    cleanup()

    if withScreenshot then
        captureScreenshot(function(success)
            if success then
                showChooser(true, function(prompt)
                    executeClaude(prompt, true)
                end)
            end
        end)
    else
        showChooser(false, function(prompt)
            executeClaude(prompt, false)
        end)
    end
end

-- True autocomplete - screenshot + auto-respond without prompt
local function autoComplete()
    killCurrentTask()
    cleanup()

    captureScreenshot(function(success)
        if not success then return end

        showLoading(true)

        local fullPrompt = "Look at my screen in the image at " .. screenshotPath .. " - find my cursor and write what I should type next."

        local args = {
            "-p", fullPrompt,
            "--system-prompt", AUTOCOMPLETE_PROMPT,
            "--allowedTools", "Read",
            "--model", "opus"
        }

        currentTask = hs.task.new(CLAUDE_PATH, function(exitCode, stdOut, stdErr)
            currentTask = nil
            hideLoading()
            cleanup()

            if exitCode == 0 then
                local response = stdOut:gsub("^%s*(.-)%s*$", "%1")
                if response ~= "" then
                    pasteAtCursor(response)
                else
                    showError("Empty response")
                end
            else
                showError("Failed (exit " .. exitCode .. ")")
            end
        end, args)

        if not currentTask:start() then
            showError("Failed to start Claude")
            cleanup()
        end

        hs.timer.doAfter(TIMEOUT_SECONDS, function()
            if currentTask and currentTask:isRunning() then
                currentTask:terminate()
                currentTask = nil
                cleanup()
                showError("Timeout")
            end
        end)
    end)
end

-- Bind hotkeys
-- Ctrl+Space: Text prompt only
hs.hotkey.bind({"ctrl"}, "space", function()
    invokeClauder(false)
end)

-- Ctrl+Shift+Space: Screenshot + prompt
hs.hotkey.bind({"ctrl", "shift"}, "space", function()
    invokeClauder(true)
end)

-- Ctrl+Option+Space: True autocomplete (screenshot, find cursor, respond automatically)
hs.hotkey.bind({"ctrl", "alt"}, "space", function()
    autoComplete()
end)

hs.alert.show("Clauto-Complete loaded", 2)
