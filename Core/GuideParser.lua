--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Guide Parser.
This file is used to extract every steps in the guide and format it
]]--
local GLV = LibStub("GuidelimeVanilla")

local Parser = {}

local codes = {
    N   = "NAME",
    NX  = "NEXT_GUIDE",
    D   = "DESCRIPTION",
    O   = "OPTIONAL",
    OC  = "OPTIONAL_COMPLETE_WITH_NEXT",
    GA  = "GUIDE_APPLIES",
    Q   = "QUEST",
    QA  = "ACCEPT",
    QC  = "COMPLETE",
    QT  = "TURNIN",
    QS  = "SKIP",
    G   = "GOTO",
    L   = "LOCATION",
    XP  = "EXPERIENCE",
    CI  = "COLLECT_ITEM",
    TAR = "TARGET_ID",
    A   = "APPLIES",
    LE  = "LEARN",
    SP  = "SPELL",
    R   = "REPAIR",
    V   = "VENDOR",
    H   = "HEARTHSTONE",
    S   = "BIND_HEARTHSTONE",
}
local reverseCodes = {}
for k, v in pairs(codes) do reverseCodes[v] = k end

function Parser:getSuperTag(tag)
	if tag == "ACCEPT" then return "QUEST" end
	if tag == "TURNIN" then return "QUEST" end
	if tag == "COMPLETE" then return "QUEST" end
	return tag
end

-- Parse les différents formats d'exigences d'expérience
function Parser:ParseExperienceRequirement(xpString)
    if not xpString or xpString == "" then
        return nil
    end
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Parsing XP string: '" .. xpString .. "'")
    end
    
    -- Extraire seulement la partie numérique au début de la chaîne
    -- [XP3] ou [XP4-290 Grind text] ou [XP3.5 Some text]
    local numericPart, textPart = string.match(xpString, "^([%d%.%-]+)(.*)")
    if not numericPart then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime Parser]|r No numeric part found in: '" .. xpString .. "'")
        end
        return nil
    end
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Extracted numeric part: '" .. numericPart .. "'")
    end
    
    -- [XP3] -> Atteindre le niveau 3
    local simpleLevel = string.match(numericPart, "^(%d+)$")
    if simpleLevel then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Parsed as simple level: " .. simpleLevel)
        end
        return {
            targetLevel = tonumber(simpleLevel),
            targetPercent = 100,
            type = "level",
            text = textPart
        }
    end
    
    -- [XP3-100] -> Il manque 100 XP pour le niveau 3
    local levelMinus, xpMinus = string.match(numericPart, "^(%d+)%-(%d+)$")
    if levelMinus and xpMinus then
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Parsed as level minus: Level " .. levelMinus .. " minus " .. xpMinus .. " XP")
        end
        return {
            targetLevel = tonumber(levelMinus),
            xpMinus = tonumber(xpMinus),
            type = "level_minus",
            text = textPart
        }
    end
    
    -- [XP3.5] -> Niveau 3 avec 50% d'XP ou [XP2.925] -> Niveau 2 avec 92.5% d'XP
    local levelFloat = tonumber(numericPart)
    if levelFloat then
        local level = math.floor(levelFloat)
        local decimal = levelFloat - level
        
        -- Gérer les cas comme XP5.10 (qui devrait être 10%, pas 1%)
        local percent
        if string.find(numericPart, "%.%d%d$") then
            -- Si on a exactement 2 chiffres après le point (ex: 5.10), les traiter comme des pourcentages directs
            percent = decimal * 100
        else
            -- Sinon, conversion normale (ex: 5.5 = 50%)
            percent = decimal * 100
        end
        
        if GLV.Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Parsed as level percent: Level " .. level .. " (" .. percent .. "%) from '" .. numericPart .. "'")
        end
        
        return {
            targetLevel = level,
            targetPercent = percent,
            type = "level_percent",
            text = textPart
        }
    end
    
    if GLV.Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[GuideLime Parser]|r Failed to parse numeric part: '" .. numericPart .. "'")
    end
    return nil
end

function Parser:parseGuide(guide, group)
    local parsedGuide = {}
    
    parsedGuide.steps = {}
    parsedGuide.group = group

    local isFirstLine = true

    for line in string.gfind(guide .. "\n", "([^\n]*)\n") do
        local parsedLine = {}

        line = string.gsub(line, "^%s*(.-)%s*$", "%1")

        if isFirstLine and line == "" then
            isFirstLine = false
        else
            isFirstLine = false
            if self:filterClassRace(line) then
                if line ~= "" then
                    local count = 0
                    stepText, count = string.gsub(line, "%[(.-)%]", function(code)
                        local tag = codes[string.sub(code, 1, 3)]
                        if tag == nil then tag = codes[string.sub(code, 1, 2)] end
                        if tag == nil then tag = codes[string.sub(code, 1, 1)] end

                        local tagContent = string.sub(code, safe_strlen(reverseCodes[tag]) + 1)
                        tagContent = string.gsub(tagContent, "^%s*", "")

                        if tag == "NAME" then
                            parsedGuide.minLevel, parsedGuide.maxLevel, parsedGuide.name, parsedGuide.id = self:getGuideName(tagContent)
                            return ""

                        elseif tag == "DESCRIPTION" then
                            parsedGuide.description = self:getGuideDescription(tagContent)
                            return ""

                        elseif tag == "GUIDE_APPLIES" then
                            parsedGuide.faction = tagContent
                            return ""

                        elseif tag == "NEXT_GUIDE" then
                            parsedGuide.next = tagContent
                            parsedGuide.hasCheckbox = true
                            parsedGuide.clickToNext = true
                            return "-"

                        elseif tag == "OPTIONAL" then
                            parsedLine.optional = true
                            return ""

                        elseif tag == "OPTIONAL_COMPLETE_WITH_NEXT" then
                            parsedLine.complete_with_next = true
                            parsedLine.check = false
                            return ""

                        elseif tag == "APPLIES" then
                            return "|c" .. GLV.Colors[tag] .. self:replaceClassRace(tagContent) .. "|r"

                        elseif tag == "TARGET_ID" then
                            return GLV:getTargetName(tagContent)

                        elseif tag == "LEARN" then
                            return "|c" .. GLV.Colors[tag] .. self:Learn(tagContent) .. "|r"

                        elseif tag == "COLLECT_ITEM" then
                            return "|c" .. GLV.Colors[tag] .. self:CollectItem(tagContent) .. "|r"

                        elseif self:getSuperTag(tag) == "QUEST" then
                            local fullText = ""
                            local questTitle = ""
                            local questId = nil
                            local questCoords = nil
                            questTitle, questId, questCoords = self:GetQuestInfo(tagContent)
                            parsedLine.questId = tonumber(questId)
                            parsedLine.hasCheckbox = true
                            
                            -- Add step type and questId for tracking
                            if tag == "ACCEPT" then
                                parsedLine.stepType = "ACCEPT"
                                fullText = fullText .. "Accept "
                                parsedLine.icon = "Interface\\GossipFrame\\AvailableQuestIcon"
                            elseif tag == "TURNIN" then
                                parsedLine.stepType = "TURNIN"
                                fullText = fullText .. "Turnin "
                                parsedLine.icon = "Interface\\GossipFrame\\ActiveQuestIcon"
                            elseif tag == "COMPLETE" then
                                parsedLine.stepType = "COMPLETE"
                                fullText = fullText .. "Complete "
                            end
                            
                            -- Store quest tag for multi-quest step handling
                            if not parsedLine.questTags then parsedLine.questTags = {} end
                            table.insert(parsedLine.questTags, {
                                tag = tag,
                                questId = tonumber(questId),
                                title = questTitle
                            })
                            
                            -- Debug : afficher les questTags créées
                            if GLV.Debug then
                                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[GuideLime Parser]|r Added questTag: " .. tag .. " for quest " .. questId .. " (" .. questTitle .. ")")
                            end
                            
                            -- Add coordinates to the parsed line
                            if questCoords and table.getn(questCoords) > 0 then
                                parsedLine.coords = questCoords
                            end

                            fullText = fullText .. "|c" .. GLV.Colors[tag] .. questTitle .. "|r"
                            return fullText

                        elseif tag == "REPAIR" then
                            return "|c" .. GLV.Colors[tag] .. "Repair " .. "|r"

                        elseif tag == "VENDOR" then
                            return "|c" .. GLV.Colors[tag] .. "Vendor " .. "|r"

                        elseif tag == "HEARTHSTONE" then
                            parsedLine.icon = "Interface\\Icons\\INV_Misc_Rune_01"
                            parsedLine.useItemId = 6948
                            return tagContent

                        elseif tag == "BIND_HEARTHSTONE" then
                            parsedLine.bindHearthstone = true
                            return "|c" .. GLV.Colors[tag] .. tagContent .. "|r"
                            
                        elseif tag == "EXPERIENCE" then
                            -- Parse les différents formats d'XP
                            local xpData = self:ParseExperienceRequirement(tagContent)
                            if xpData then
                                parsedLine.hasCheckbox = true
                                parsedLine.experienceRequirement = xpData
                                
                                if GLV.Debug then
                                    local debugMsg = "|cFF00FF00[GuideLime Parser]|r Added XP requirement: " .. tagContent .. " -> Level " .. xpData.targetLevel
                                    if xpData.type == "level_minus" then
                                        debugMsg = debugMsg .. " (missing " .. xpData.xpMinus .. " XP)"
                                    elseif xpData.type == "level_percent" then
                                        debugMsg = debugMsg .. " (" .. xpData.targetPercent .. "%)"
                                    else
                                        debugMsg = debugMsg .. " (100%)"
                                    end
                                    if GLV.Debug then
                                        DEFAULT_CHAT_FRAME:AddMessage(debugMsg)
                                    end
                                end
                                
                                return "|c" .. GLV.Colors[tag] .. xpData.text .. "|r"
                            end

                        end

                        return "[" .. code .. "]"

                    end)
                    if stepText == "" and count == 0 then
                        stepText = line
                    end
                    parsedLine.text = stepText
                     
                     -- Inherit questId from previous step if this step doesn't have one
                     if not parsedLine.questId and parsedGuide.steps and table.getn(parsedGuide.steps) > 0 then
                         local lastStep = parsedGuide.steps[table.getn(parsedGuide.steps)]
                         if lastStep.questId then
                             parsedLine.questId = lastStep.questId
                         end
                     end
                 else
                     parsedLine = {
                         text = "",
                         emptyLine = true
                     }
                 end

                 if parsedLine.text ~= "" or parsedLine.emptyLine == true then
                     table.insert(parsedGuide.steps, parsedLine)
                 end
            end
        end
    end

    return parsedGuide
end

function Parser:getGuideName(content)
    -- Try different patterns to extract level and name
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
    
    -- Create a unique guide identifier
    local guideId = "Unknown"
    if guideName and guideName ~= "" then
        guideId = string.gsub(guideName, "%s+", "_") -- Replace spaces with underscores
        if lvlMin and lvlMin ~= "" then
            guideId = guideId .. "_" .. lvlMin
        end
        if lvlMax and lvlMax ~= "" then
            guideId = guideId .. "_" .. lvlMax
        end
    else
        -- Fallback: use group name if guide name is empty
        guideId = "Unknown_Guide"
    end
    
    return lvlMin, lvlMax, guideName, guideId
end

function Parser:getGuideDescription(content)
    guideDescription = string.gsub(content, "\\\\", "\n")
    return guideDescription
end

function Parser:filterClassRace(line)
    local playerClass = GLV.Settings:GetOption({"CharInfo", "Class"}) or ""
    local playerRace = GLV.Settings:GetOption({"CharInfo", "Race"}) or ""
    
    local classRaceTags = {}
    for tag in string.gfind(line, "%[A ([^%]]+)%]") do
        table.insert(classRaceTags, tag)
    end

    if next(classRaceTags) then
        for tagIndex, tag in pairs(classRaceTags) do
            local isMatch = false
            for entry in string.gfind(tag, "[^,]+") do
                entry = string.gsub(entry, "^%s*(.-)%s*$", "%1")
                local normalizedEntry = string.lower(entry)
                local normalizedClass = string.lower(playerClass)
                local normalizedRace = string.lower(playerRace)

                if normalizedEntry == normalizedClass or normalizedEntry == normalizedRace then
                    isMatch = true
                    break
                end
            end
            if not isMatch then
                return false
            end
        end
        return true
    end
    return true
end

function Parser:replaceClassRace(content)
    local playerClass = string.lower(UnitClass("player"))
    local playerRace = string.lower(UnitRace("player"))

    for classRaceTag in string.gfind(content, "([^,]+)") do

        classRaceTag = string.gsub(classRaceTag, "%s+", "")

        if string.lower(classRaceTag) == playerClass or string.lower(classRaceTag) == playerRace then
            return classRaceTag
        end

    end 
end

function Parser:Learn(content)
    -- SP XXXX
    local subcode, id = string.match(content, "(SP)%s(%d+)")
    id = string.gsub(id, "%s+", "")
    
    if subcode == "SP" then
         return GLV:getSpellName(id)
    end
    return "Unknown Spell"
end

function Parser:GetQuestInfo(content)
    local questID, _, questPart = string.match(content, "(%d+)(,?)(%d?)")
    local questName = GLV:GetQuestNameByID(questID)
    
    -- Get quest coordinates from database using DBTools
    -- Pass questPart to get coordinates for the specific part
    local coords = GLV:GetQuestAllCoords(questID, questPart)
    
    return questName, questID, coords
end

function Parser:CollectItem(content)
    local itemID, itemCount = string.match(content, "(%d+)(,?)(%d?)")
    local itemName = GLV:GetItemNameById(itemID)
    return itemName
end

GLV.Parser = Parser