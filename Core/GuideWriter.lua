--[[
Guidelime Vanilla
Author: Grommey

Description:
Guide Writer rework.
Display steps in a single frame with multiple lines, icon beside line, checkbox at right.
]]--
local GLV = LibStub("GuidelimeVanilla")

local CONFIG = {
    spacing = -4,
    lineHeight = 14,
    checkboxSize = 24,
    textOffset = 30,
    iconWidth = 13,
    totalWidth = 270,
    fontLineHeight = 13,
    ocSpacing = 6,
    lineSpacing = 4,
    iconYOffset = 0,
    backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = true,
        tileSize = 16,
        edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    },
    colors = {
        even = {0.2,0.2,0.2,0.8},
        odd = {0.1,0.1,0.1,0.8},
        active = {0.8,0.8,0.2,0.9}
    },
    titleFrame = GLV_MainLoadedGuideTitle
}

-- Reusable FontString for text measurement (prevents memory leak)
local measureFontString = nil

-- Debounce control for RefreshGuide
local refreshGuideScheduled = false

-- Track FontStrings for quest and XP progress updates
GLV.QuestProgressTrackers = {}
GLV.XPProgressTrackers = {}

-- Update XP progress display on tracked FontStrings (only on active step)
function GLV:UpdateXPProgressDisplay()
    if not GLV.CharacterTracker or not GLV.XPProgressTrackers then return end

    -- Get current active step
    local currentGuideId = GLV.Settings:GetOption({"Guide", "CurrentGuide"}) or "Unknown"
    local activeStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0

    for _, tracker in ipairs(GLV.XPProgressTrackers) do
        if tracker.fontString and tracker.experienceRequirement and tracker.originalText then
            -- Only show progress on the active step
            if tracker.stepIndex == activeStep then
                local progress, isDone = GLV.CharacterTracker:GetXPProgress(tracker.experienceRequirement)
                if progress then
                    local color = isDone and "|cFF00FF00" or "|cFFFFFF00"  -- Green if done, yellow otherwise
                    tracker.fontString:SetText(tracker.originalText .. " " .. color .. progress .. "|r")
                else
                    tracker.fontString:SetText(tracker.originalText)
                end
            else
                -- Not active step, show original text without progress
                tracker.fontString:SetText(tracker.originalText)
            end
        end
    end
end

-- Update quest progress display on tracked FontStrings (full objectives on new lines)
function GLV:UpdateQuestProgressDisplay()
    if not GLV.QuestTracker or not GLV.QuestProgressTrackers then return end

    for _, tracker in ipairs(GLV.QuestProgressTrackers) do
        if tracker.fontString and tracker.questId and tracker.originalText then
            local objectives, allComplete, numObjectives = GLV.QuestTracker:GetQuestProgress(tracker.questId)
            if objectives and numObjectives > 0 then
                local text = tracker.originalText .. "\n"
                for _, obj in ipairs(objectives) do
                    -- Determine color based on progress
                    local color = "|cFF00FF00"  -- Default green (completed)
                    if not obj.completed then
                        -- Extract current/total from text like "Red Burlap Bandana: 4/12"
                        local _, _, current, total = string.find(obj.text, "(%d+)/(%d+)")
                        if current and total then
                            local cur = tonumber(current)
                            local tot = tonumber(total)
                            local pct = (tot > 0) and (cur / tot) or 0
                            if pct == 0 then
                                color = "|cFFFF0000"  -- Red: 0%
                            elseif pct < 0.5 then
                                color = "|cFFFF8000"  -- Orange: 1-49%
                            else
                                color = "|cFFFFFF00"  -- Yellow: 50-99%
                            end
                        else
                            color = "|cFFFF0000"  -- Red if can't parse
                        end
                    end
                    text = text .. "\n" .. color .. "- " .. obj.text .. "|r"
                end
                tracker.fontString:SetText(text)

                -- Resize FontString and parent frame to fit new lines (+1 for blank line)
                local originalLineCount = tracker.originalLineCount or 1
                local totalLineCount = originalLineCount + numObjectives + 1
                local newHeight = totalLineCount * CONFIG.fontLineHeight
                local extraHeight = (numObjectives + 1) * CONFIG.fontLineHeight

                tracker.fontString:SetHeight(newHeight)

                -- Increase parent frame height
                if tracker.parentFrame then
                    local currentHeight = tracker.parentFrame:GetHeight()
                    if not tracker.addedHeight then
                        tracker.parentFrame:SetHeight(currentHeight + extraHeight)
                        tracker.addedHeight = extraHeight
                    end
                end
            else
                tracker.fontString:SetText(tracker.originalText)
                -- Reset height if no objectives
                if tracker.parentFrame and tracker.addedHeight then
                    local currentHeight = tracker.parentFrame:GetHeight()
                    tracker.parentFrame:SetHeight(currentHeight - tracker.addedHeight)
                    tracker.addedHeight = nil
                end
            end
        end
    end

    -- Update scroll area after resizing
    if GLV_MainScrollFrame then
        GLV_MainScrollFrame:UpdateScrollChildRect()
    end
end


--[[ UI CREATION FUNCTIONS ]]--

-- Create and set the guide title with level range information
local function createTitle(guide)
    GLV_MainLoadedGuideTitle:SetText(guide.name .. " (" .. guide.minLevel .. "-" .. guide.maxLevel .. ")")
end

-- Wrap text to fit within specified width and return wrapped text with line count and height
local function wrapText(inputText, maxWidth, font)
    local wrappedText = ""
    local lineCount = 0
    local segments = {}
    inputText = inputText or ""
    for segment in string.gfind(inputText, "([^\n]*)\n?") do
        if segment and segment ~= "" then table.insert(segments, segment) end
    end

    -- Reuse a single FontString for measurement to prevent memory leaks
    if not measureFontString then
        measureFontString = UIParent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalSmall")
        measureFontString:Hide()
    end
    local tempText = measureFontString

    for i, segment in ipairs(segments) do
        local currentLine = ""
        local words = {}
        for word in string.gfind(segment, "[%S]+") do table.insert(words, word) end
        for j, word in ipairs(words) do
            local testLine = currentLine == "" and word or currentLine.." "..word
            tempText:SetText(testLine)
            if tempText:GetStringWidth() <= maxWidth then
                currentLine = testLine
            else
                wrappedText = wrappedText..(wrappedText=="" and "" or "\n")..currentLine
                lineCount = lineCount + 1
                currentLine = word
            end
        end
        if currentLine ~= "" then
            wrappedText = wrappedText..(wrappedText=="" and "" or "\n")..currentLine
            lineCount = lineCount + 1
        end
        if i < safe_tablelen(segments) then
            wrappedText = wrappedText.."\n"
            lineCount = lineCount + 1
        end
    end
    local textHeight = tempText:GetHeight() * lineCount
    return wrappedText, lineCount, textHeight
end

-- Create checkbox for step completion with proper textures and positioning
local function createCheckbox(frame)
    local check = CreateFrame("CheckButton", frame:GetName().."Check", frame)
    check:SetWidth(CONFIG.checkboxSize)
    check:SetHeight(CONFIG.checkboxSize)
    check:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    local textures = {
        {method="SetNormalTexture", path="Interface\\Buttons\\UI-CheckBox-Up", layer="BACKGROUND"},
        {method="SetHighlightTexture", path="Interface\\Buttons\\UI-CheckBox-Highlight", layer="HIGHLIGHT"},
        {method="SetPushedTexture", path="Interface\\Buttons\\UI-CheckBox-Down", layer="ARTWORK"},
        {method="SetCheckedTexture", path="Interface\\Buttons\\UI-CheckBox-Check", layer="ARTWORK"}
    }
    for _, tex in ipairs(textures) do
        local t = check:CreateTexture(nil, tex.layer)
        t:SetTexture(tex.path)
        t:SetAllPoints(check)
        check[tex.method](check, t)
    end
    return check
end


--[[ ITEM INTERACTION FUNCTIONS ]]--

-- Find an item in bags by itemId and use it (WoW 1.12 compatible)
local function useItemById(itemId)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local link = GetContainerItemLink(bag, slot)
                if link and string.find(link, "item:"..itemId..":") then
                    UseContainerItem(bag, slot)
                    return true
                end
            end
        end
    end
    return false
end


--[[ STEP GROUPING FUNCTIONS ]]--

-- Group steps: combine OC steps with main lines
local function groupSteps(guide, stepState, currentGuideId)
    if not guide or not guide.steps then
        return {}, {}, {}
    end
    
    local displaySteps = {}
    local originalIndexToDisplayIndex = {}
    local displayIndexToOriginalIndex = {}
    
    local i = 1
    while i <= safe_tablelen(guide.steps) do
        local stepFrameData = {lines={}, icon=nil, hasCheckbox=false, questTags={}, learnTags={}}
        
        -- Collect [OC] lines
        while i <= safe_tablelen(guide.steps) and guide.steps[i] and (guide.steps[i].emptyLine or guide.steps[i].complete_with_next) do
            table.insert(stepFrameData.lines, {
                text = guide.steps[i].text,
                isOC = guide.steps[i].emptyLine or guide.steps[i].complete_with_next,
                icon = guide.steps[i].icon,
                useItemId = guide.steps[i].useItemId,
                equipItemId = guide.steps[i].equipItemId,
                questId = guide.steps[i].questId,
                coords = guide.steps[i].coords,
                stepType = guide.steps[i].stepType,
                questTags = guide.steps[i].questTags,
                experienceRequirement = guide.steps[i].experienceRequirement,
                learnTags = guide.steps[i].learnTags,
                destination = guide.steps[i].destination,
            })
            if guide.steps[i].icon and not stepFrameData.icon then
                stepFrameData.icon = guide.steps[i].icon
            end
            if guide.steps[i].questTags then
                for _, tag in ipairs(guide.steps[i].questTags) do
                    table.insert(stepFrameData.questTags, tag)
                end
            end
            if guide.steps[i].experienceRequirement then
                stepFrameData.hasCheckbox = true
            end
            i = i + 1
        end
        
        -- Add main line
        if i <= safe_tablelen(guide.steps) and guide.steps[i] then
            table.insert(stepFrameData.lines, {
                text = guide.steps[i].text,
                isOC = guide.steps[i].emptyLine or guide.steps[i].complete_with_next,
                icon = guide.steps[i].icon,
                useItemId = guide.steps[i].useItemId,
                equipItemId = guide.steps[i].equipItemId,
                questId = guide.steps[i].questId,
                coords = guide.steps[i].coords,
                stepType = guide.steps[i].stepType,
                questTags = guide.steps[i].questTags,
                experienceRequirement = guide.steps[i].experienceRequirement,
                learnTags = guide.steps[i].learnTags,
                destination = guide.steps[i].destination,
            })
            
            stepFrameData.hasCheckbox = true
            
            if guide.steps[i].experienceRequirement then
                stepFrameData.hasCheckbox = true
            end
            if guide.steps[i].icon and not stepFrameData.icon then
                stepFrameData.icon = guide.steps[i].icon
            end
            if guide.steps[i].questTags then
                for _, tag in ipairs(guide.steps[i].questTags) do
                    table.insert(stepFrameData.questTags, tag)
                end
            end
            
            local displayIndex = safe_tablelen(displaySteps) + 1
            originalIndexToDisplayIndex[i] = displayIndex
            displayIndexToOriginalIndex[displayIndex] = i
            i = i + 1
        end
        table.insert(displaySteps, stepFrameData)
    end
    
    -- Handle next guide checkbox
    if guide.clickToNext and guide.next and safe_tablelen(displaySteps) > 0 then
        local lastStepIndex = safe_tablelen(displaySteps)
        displaySteps[lastStepIndex].hasCheckbox = true
    end
    
    return displaySteps, originalIndexToDisplayIndex, displayIndexToOriginalIndex
end

--[[ SCROLL MANAGEMENT FUNCTIONS ]]--

-- Calculate scroll position for a specific step
local function calculateScrollPosition(stepIndex, scrollChild, guideId, spacing)
    local targetScroll = 0
    for i = 1, stepIndex - 1 do
        local stepFrame = getglobal(scrollChild:GetName().."Step"..guideId.."_"..i)
        if stepFrame and stepFrame.GetHeight then
            targetScroll = targetScroll + stepFrame:GetHeight()
        end
    end
    
    if stepIndex > 1 then
        targetScroll = targetScroll + (math.abs(spacing) * (stepIndex - 1))
    end
    
    return math.max(0, targetScroll)
end

-- Scroll to specific step
local function scrollToStep(stepIndex, scrollChild, guideId, spacing)
    if stepIndex > 0 and GLV_MainScrollFrame then
        local targetScroll = calculateScrollPosition(stepIndex, scrollChild, guideId, spacing)
        local maxScroll = GLV_MainScrollFrame:GetVerticalScrollRange()
        if maxScroll and maxScroll > 0 then
            targetScroll = math.min(targetScroll, maxScroll)
        end
        GLV_MainScrollFrame:SetVerticalScroll(targetScroll)
    end
end

--[[ CHECKBOX LOGIC FUNCTIONS ]]--

-- Update step colors by rebuilding the UI (SetBackdropColor doesn't work after frame creation)
-- This function is kept for backwards compatibility with QuestTracker and TaxiTracker
local function updateStepColors(scrollChild, guideId, displaySteps, activeStepIndex)
    -- Just rebuild the UI - colors are set correctly during frame creation
    GLV:RefreshGuide()
end

-- Parse guide name content using the same logic as the parser
local function parseGuideNameContent(content)
    local lvlMin, lvlMax, guideName
    
    -- Pattern 1: "1-11 Dun Morogh" or "1-11 Dun Morogh"
    lvlMin, lvlMax, guideName = string.match(content, "(%d+)%s*%-%s*(%d+)%s*(.+)")
    
    -- Pattern 2: "1 11 Dun Morogh" (without dash)
    if not lvlMin then
        lvlMin, lvlMax, guideName = string.match(content, "(%d+)%s+(%d+)%s+(.+)")
    end
    
    -- Pattern 3: Just try to extract any numbers and text
    if not lvlMin then
        lvlMin, lvlMax, guideName = string.match(content, "(%d+)%s*[%-%s]%s*(%d+)%s*(.+)")
    end
    
    return lvlMin, lvlMax, guideName
end

-- Handle next guide loading
local function handleNextGuideLoad(guide, currentIndex, displaySteps)
    if guide.next and guide.clickToNext and currentIndex == safe_tablelen(displaySteps) then
        local nextGuideContent = guide.next
        
        -- Parse the next guide content using the same logic as the parser
        -- Format: "XX-XX Name" where XX-XX are levels and Name is the guide name
        local nextMinLevel, nextMaxLevel, nextGuideName = parseGuideNameContent(nextGuideContent)
        
        if not nextGuideName then
            return
        end
        
        -- Generate the expected guide ID using the same logic as the parser
        local expectedGuideId = "Unknown"
        if nextGuideName and nextGuideName ~= "" then
            expectedGuideId = string.gsub(nextGuideName, "%s+", "_")
            if nextMinLevel and nextMinLevel ~= "" then
                expectedGuideId = expectedGuideId .. "_" .. nextMinLevel
            end
            if nextMaxLevel and nextMaxLevel ~= "" then
                expectedGuideId = expectedGuideId .. "_" .. nextMaxLevel
            end
        end
        
        -- Look for exact match using the guide ID
        for groupName, groupGuides in pairs(GLV.loadedGuides) do
            if groupGuides then
                for guideId, guideData in pairs(groupGuides) do
                    if guideId == expectedGuideId then
                        GLV:LoadGuide(groupName, guideId)
                        return
                    end
                end
            end
        end
    end
end

-- Find the first unchecked step with checkbox
local function findFirstUncheckedStep(displaySteps, displayIndexToOriginalIndex, stepState)
    for i = 1, table.getn(displaySteps) do
        if displaySteps[i] and displaySteps[i].hasCheckbox then
            local orig = displayIndexToOriginalIndex[i]
            if orig and not stepState[orig] then
                return i
            end
        end
    end
    return 1 -- Fallback to first step
end

-- Calculate new active step based on checkbox state
local function calculateNewActiveStep(checked, currentIndex, currentActiveStep, displaySteps, displayIndexToOriginalIndex, stepState)
    if not checked then
        -- When unchecking, always recalculate to find first unchecked step
        return findFirstUncheckedStep(displaySteps, displayIndexToOriginalIndex, stepState)
    end
    
    -- When checking
    if currentIndex == currentActiveStep then
        -- Move to next unchecked step
        local totalSteps = table.getn(displaySteps)
        for i = currentIndex + 1, totalSteps do
            if displaySteps[i] and displaySteps[i].hasCheckbox then
                local orig = displayIndexToOriginalIndex[i]
                if orig and not stepState[orig] then
                    return i
                end
            end
        end
        return currentIndex -- Stay on current if no more unchecked
    end
    
    return currentActiveStep
end

--[[ MAIN GUIDE FUNCTIONS ]]--

-- Public: rebuild the guide UI using the current guide and main scroll child
-- Uses debounce to prevent multiple rapid refreshes
function GLV:RefreshGuide()
    -- Debounce: if refresh is already scheduled, skip
    if refreshGuideScheduled then
        return
    end

    local guide = GLV.CurrentGuide
    if not guide then return end
    local scrollChild = GLV_MainScrollFrameScrollChild
    if not scrollChild and GLV_MainScrollFrame and GLV_MainScrollFrame.GetScrollChild then
        scrollChild = GLV_MainScrollFrame:GetScrollChild()
    end
    if not scrollChild then return end

    -- Mark as scheduled to prevent multiple calls
    refreshGuideScheduled = true

    -- Use a small delay to batch multiple refresh requests
    GLV.Ace:ScheduleEvent("GLV_RefreshGuide", function()
        refreshGuideScheduled = false
        self:CreateGuideSteps(scrollChild, guide, guide.id)
    end, 0.1)
end

-- Create and display all guide steps in the UI with proper grouping and layout
function GLV:CreateGuideSteps(scrollChild, guide, guideId, callback)
    if not scrollChild or not scrollChild.GetNumChildren then 
        if callback then callback() end
        return 
    end
    if not guide or not guide.steps then 
        if callback then callback() end
        return 
    end

    -- Cleanup previous children
    local children = {scrollChild:GetChildren()}
    for i, child in pairs(children) do
        if child and type(child) == "table" then
            child:Hide()
            child:SetParent(nil)
        end
    end

    -- Clear progress trackers for new guide
    GLV.QuestProgressTrackers = {}
    GLV.XPProgressTrackers = {}

    local lastLine = nil
    local totalHeight = 0
    local currentGuideId = guideId or guide.id or "Unknown"
    local stepState = GLV.Settings:GetOption({"Guide","Guides", currentGuideId, "StepState"}) or {}
    
    -- expose current guide to other modules (e.g., quest tracker)
    GLV.CurrentGuide = guide
    
    -- Use extracted function to group steps
    local displaySteps, originalIndexToDisplayIndex, displayIndexToOriginalIndex = groupSteps(guide, stepState, currentGuideId)

    local currentStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
    GLV_MainLoadedGuideCounter:SetText("("..currentStep.."/"..safe_tablelen(displaySteps)..")")

    GLV.CurrentStepIndexMap = originalIndexToDisplayIndex
    GLV.CurrentDisplayStepsCount = safe_tablelen(displaySteps)
    GLV.CurrentDisplaySteps = displaySteps
    GLV.CurrentDisplayHasCheckbox = {}
    for di, st in ipairs(displaySteps) do
        GLV.CurrentDisplayHasCheckbox[di] = st.hasCheckbox and true or false
    end
    GLV.CurrentDisplayToOriginal = displayIndexToOriginalIndex

    -- Calculate activeStep BEFORE creating frames so we can set the right color
    local totalSteps = table.getn(displaySteps)
    local activeStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0

    if activeStep == 0 and totalSteps > 0 then
        -- Find first unchecked step
        for i2 = 1, totalSteps do
            if displaySteps[i2] and displaySteps[i2].hasCheckbox then
                local orig = displayIndexToOriginalIndex[i2]
                if orig and not stepState[orig] then
                    activeStep = i2
                    break
                end
            end
        end
        -- If all completed, use last step with checkbox
        if activeStep == 0 then
            for i2 = totalSteps, 1, -1 do
                if displaySteps[i2] and displaySteps[i2].hasCheckbox then
                    activeStep = i2
                    break
                end
            end
        end
        -- Final fallback
        if activeStep == 0 then
            activeStep = 1
        end
        GLV.Settings:SetOption(activeStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})
    end

    for idx, step in ipairs(displaySteps) do
        local frameName = scrollChild:GetName().."Step"..guideId.."_"..idx
        local frame = CreateFrame("Frame", frameName, scrollChild)

        -- Clean up old children if frame is being reused (FontStrings, textures, etc.)
        local regions = {frame:GetRegions()}
        for _, region in pairs(regions) do
            if region and region.Hide then
                region:Hide()
            end
        end
        local children = {frame:GetChildren()}
        for _, child in pairs(children) do
            if child and child.Hide then
                child:Hide()
                child:SetParent(nil)
            end
        end

        frame:Show()
        frame:SetWidth(CONFIG.totalWidth)
        frame:SetBackdrop(CONFIG.backdrop)
        if frame.EnableMouse then frame:EnableMouse(true) end

        -- Set color: YELLOW for active step, even/odd for others
        local color
        if idx == activeStep then
            color = CONFIG.colors.active
        else
            color = isEven(idx) and CONFIG.colors.even or CONFIG.colors.odd
        end
        frame:SetBackdropColor(unpack(color))

        local yOffset = -2
        local frameHeight = 0
        local lineStrings = {}

        for li, line in ipairs(step.lines) do
            local hasIcon = type(line.icon) == "string" and line.icon ~= "" and line.icon ~= nil
            local reservedIconWidth = CONFIG.iconWidth + 4
            local availableWidth = CONFIG.totalWidth - CONFIG.checkboxSize - 16 - reservedIconWidth

            local textFrame = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")

            local wrappedText, lineCount, textHeight = wrapText(line.text or "", availableWidth)
            textFrame:SetText(wrappedText)
            textFrame:SetJustifyH("LEFT")
            textFrame:SetJustifyV("TOP")
            textFrame:SetWidth(availableWidth)
            local usedHeight = (lineCount * CONFIG.fontLineHeight)
            textFrame:SetHeight(usedHeight)

            -- Track [QC] steps for progress display
            if line.stepType == "COMPLETE" and line.questId then
                table.insert(GLV.QuestProgressTrackers, {
                    fontString = textFrame,
                    parentFrame = frame,
                    questId = line.questId,
                    originalText = wrappedText,
                    originalLineCount = lineCount
                })
            end

            -- Track [XP] steps for progress display (only show on active step)
            if line.experienceRequirement then
                table.insert(GLV.XPProgressTrackers, {
                    fontString = textFrame,
                    experienceRequirement = line.experienceRequirement,
                    originalText = wrappedText,
                    stepIndex = idx
                })
            end

            local offsetX = reservedIconWidth

            if hasIcon then
                -- Create the clickable icon at scrollChild level to avoid any parent capturing issues
                local iconButton = CreateFrame("Button", nil, scrollChild)
                iconButton:SetWidth(CONFIG.iconWidth)
                iconButton:SetHeight(CONFIG.iconWidth)
                -- Position icon at consistent height relative to text
                local iconYOffset = CONFIG.iconYOffset
                iconButton:SetPoint("TOPRIGHT", textFrame, "TOPLEFT", -2, iconYOffset)
                iconButton:EnableMouse(true)
                if iconButton.RegisterForClicks then
                    iconButton:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
                end
                iconButton:SetFrameStrata("TOOLTIP")
                if iconButton.SetFrameLevel then
                    iconButton:SetFrameLevel(100)
                end
                iconButton:Show()
                if iconButton.Raise then iconButton:Raise() end
                if iconButton.Enable then iconButton:Enable() end

                local icon = iconButton:CreateTexture(nil, "OVERLAY")
                icon:SetAllPoints(iconButton)
                icon:SetTexture(line.icon)

                -- Optional: click action provided by parser
                if line.useItemId then
                    local itemIdForClick = line.useItemId
                    -- Handle item usage when icon is clicked, calls useItemById with the stored item ID
                    local function handleUse()
                        useItemById(itemIdForClick)
                    end
                    iconButton:SetScript("OnClick", handleUse)
                    iconButton:SetScript("OnMouseUp", handleUse)
                    if iconButton.SetHighlightTexture then
                        iconButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
                    end
                    if iconButton.SetHitRectInsets then
                        iconButton:SetHitRectInsets(-2, -2, -2, -2)
                    end
                    iconButton:SetScript("OnEnter", function()
                        GameTooltip:SetOwner(iconButton, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Use item")
                        GameTooltip:Show()
                    end)
                    iconButton:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                end
            end

            -- Position text with consistent offset for good alignment
            textFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 2 + offsetX, yOffset)
            table.insert(lineStrings, textFrame)
            yOffset = yOffset - (usedHeight + (line.isOC and CONFIG.ocSpacing or CONFIG.lineSpacing))
            frameHeight = frameHeight + (usedHeight + (line.isOC and CONFIG.ocSpacing or CONFIG.lineSpacing))
        end

        -- checkbox
        if step.hasCheckbox then
            local check = createCheckbox(frame)
            local origIndexForDisplay = displayIndexToOriginalIndex[idx]
            check:SetChecked(origIndexForDisplay and (stepState[origIndexForDisplay] == true) or false)
            local currentIndex = idx
            check:SetScript("OnClick", function()
                local checked = not not check:GetChecked()
                if not currentIndex then return end
                
                -- Update step state
                local origIdx = displayIndexToOriginalIndex[currentIndex]
                if origIdx then
                    stepState[origIdx] = checked
                end
                GLV.Settings:SetOption(stepState, {"Guide","Guides", currentGuideId, "StepState"})
                
                -- Handle next guide loading if needed
                if checked then
                    handleNextGuideLoad(guide, currentIndex, displaySteps)
                end
                
                -- Calculate new active step
                local currentActiveStep = GLV.Settings:GetOption({"Guide", "Guides", currentGuideId, "CurrentStep"}) or 0
                local newActiveStep = calculateNewActiveStep(checked, currentIndex, currentActiveStep, displaySteps, displayIndexToOriginalIndex, stepState)
                
                -- Update step if changed
                if newActiveStep ~= currentActiveStep then
                    GLV.Settings:SetOption(newActiveStep, {"Guide", "Guides", currentGuideId, "CurrentStep"})

                    -- Update Guide Navigation waypoint
                    if newActiveStep > 0 and GLV.GuideNavigation then
                        local activeStepData = displaySteps[newActiveStep]
                        if activeStepData then
                            GLV.GuideNavigation:OnStepChanged(activeStepData)
                        end
                    end
                end

                -- Rebuild UI to update highlight and scroll (RefreshGuide handles everything)
                GLV:RefreshGuide()
            end)
        end

        frame:SetHeight(frameHeight + 4)
        frame:SetPoint("TOPLEFT", lastLine or scrollChild, lastLine and "BOTTOMLEFT" or "TOPLEFT", 0, lastLine and CONFIG.spacing or 0)
        lastLine = frame
        totalHeight = totalHeight + frameHeight + math.abs(CONFIG.spacing)
    end

    scrollChild:SetHeight(math.max(1, totalHeight))

    -- activeStep already calculated before frame creation, just update counter
    GLV_MainLoadedGuideCounter:SetText("("..tostring(activeStep).."/"..tostring(totalSteps)..")")
    
    -- Set initial Guide Navigation waypoint
    if activeStep > 0 and GLV.GuideNavigation then
        local activeStepData = displaySteps[activeStep]
        if activeStepData then
            GLV.GuideNavigation:OnStepChanged(activeStepData)
        end
    end
    
    -- Scroll to show the active step at the top
    if activeStep > 0 then
        GLV.Ace:ScheduleEvent(function()
            if GLV_MainScrollFrame then
                GLV_MainScrollFrame:UpdateScrollChildRect()
            end
            scrollToStep(activeStep, scrollChild, guideId, CONFIG.spacing)
            -- Update progress displays
            GLV:UpdateQuestProgressDisplay()
            GLV:UpdateXPProgressDisplay()
        end, 0.1)
    else
        GLV.Ace:ScheduleEvent(function()
            if GLV_MainScrollFrame then
                GLV_MainScrollFrame:UpdateScrollChildRect()
                GLV_MainScrollFrame:SetVerticalScroll(0)
            end
            -- Update progress displays
            GLV:UpdateQuestProgressDisplay()
            GLV:UpdateXPProgressDisplay()
        end, 0.1)
    end
     
    createTitle(guide)

    if callback then callback() end
end

-- Expose updateStepColors globally for use by QuestTracker
GLV.updateStepColors = updateStepColors
