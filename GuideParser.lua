--[[
Guidelime Vanilla

Author: Grommey
Version: 0.1

Description:
Guide Parser.
This file is used to extract every steps in the guide and format it
]]--
local GLV = LibStub("GuidelimeVanilla")

Parser = {}

--[[
guide = {
    group = "",
    minLevel = 0,
    maxLevel = 0,
    name = "",
    description = "",
    faction = "",
    steps = {
        {
            check = true|false,
            complete_with_next = true|false,
            xp =
            text = "",
            coords = {
                x = "",
                y = "",
                z = ""
            },
            { ... }
        },
        {...},
        {...},
    }
    next = ""
}
]]

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
}
local reverseCodes = {}
for k, v in pairs(codes) do reverseCodes[v] = k end

function Parser:parseGuide(guide, group)
    local parsedGuide = {}
    parsedGuide.steps = {}

    local lines = {}

    parsedGuide.group = group

    for line in string.gmatch(guide .. "\n", "([^\n]*)\n") do

        -- if line == "" then
        --     table.insert(parsedGuide.steps, lines)
        --     lines = {}
        -- end

        line = string.gsub(line, "^%s*(.-)%s*$", "%1")

        if line ~= "" then
            
            local parsedLine = string.gsub(line, "(.-)%[(.-)%]", function(text, code)

                tag = codes[string.sub(code, 1,3)]
                if tag == nil then tag = codes[string.sub(code, 1,2)] end
                if tag == nil then tag = codes[string.sub(code, 1,1)] end

                local tagContent = string.sub(code, safe_strlen(reverseCodes[tag]) + 1)
                tagContent = string.gsub(tagContent, "^%s*", "")

                if tag == "NAME" then
                    parsedGuide.minLevel, parsedGuide.maxLevel, parsedGuide.name = self:getGuideName(tagContent)
                    return ""
                end

            end)

            -- if parsedLine ~= "" then table.insert(lines, parsedLine) end

        else
            local parsedLine = {
                text = "",
                emptyLine = true
            }
            table.insert(parsedGuide.steps, parsedLine)
        end

    end

    DumpTable(parsedGuide)

    return parsedGuide

end

function Parser:getGuideName(content)
    local lvlMin, lvlMax, guideName = string.match(content, "%s*(%d*%.?%d*)%s*%-?%s*(%d*%.?%d*)%s*(.*)")
    return lvlMin, lvlMax, guideName
end

function Parser:getGuideDescription(guide)
    for line in string.gfind(guide, "[^\r\n]+") do
        local _, _, guideDescription = string.find(line, "^%[D%s(.-)%]$")
        if guideDescription then
            guideDescription = string.gsub(guideDescription, "\\", "\n")
            return guideDescription
        end
    end
    return nil
end

GLV.Parser = Parser