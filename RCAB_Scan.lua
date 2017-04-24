function RCAB_ScanResourceCosts(pagedID)
    if not RCAB_tooltip then
        RCAB_tooltip = CreateFrame("GameTooltip", "RCAB_tooltip", nil, "GameTooltipTemplate")
        RCAB_tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        for line = 1, 5 do
            RCAB_tooltip:AddFontStrings(
                RCAB_tooltip:CreateFontString("$parentTextLeft" .. line, nil, "GameTooltipText"),
                RCAB_tooltip:CreateFontString("$parentTextRight" .. line, nil, "GameTooltipText")
            )
        end
    end
    RCAB_tooltip:ClearLines()
    RCAB_tooltip:SetAction(pagedID)

    local resourceCost = {}
    for line = 1, RCAB_tooltip:NumLines() do
        local label = getglobal("RCAB_tooltipTextLeft" .. line)
        local text = RCAB_StripEscapeSequences(label:GetText())
        if line == 1 then
            resourceCost = RCAB_Merge(resourceCost, RCAB_ActionButton_ScanSkillName(text))
        else
            resourceCost = RCAB_Merge(resourceCost, RCAB_ActionButton_ScanSkillResourceCost(text))
            resourceCost = RCAB_Merge(resourceCost, RCAB_ActionButton_ScanSkillDescription(text))
            resourceCost = RCAB_Merge(resourceCost, RCAB_ActionButton_ScanSkillReagents(text))
        end
    end
    RCAB_resourceCosts[pagedID] = resourceCost
end


function RCAB_ActionButton_ScanSkillName(line)
    if line ~= nil then
        -- Ranged weapon skills
        if line == "Auto Shot" or
           line == "Shoot Bow" or
           line == "Shoot Crossbow" or
           line == "Shoot Gun" or
           line == "Throw" then
            return {Ammo = {cost = 1}}
        else
            return {}
        end
    end
    return {}
end

function RCAB_ActionButton_ScanSkillResourceCost(line)
    if line ~= nil then
        -- Skills that cost primary resources
        local _, _, resourceCost, resourceType = string.find(line, "(%d+) (%a+)")
        if resourceType == "Mana" or
           resourceType == "Rage" or
           resourceType == "Energy" or
           resourceType == "Health" then
            return {[resourceType] = {cost = resourceCost}}
        end
    end
    return {}
end

function RCAB_ActionButton_ScanSkillDescription(line)
    if line ~= nil then
        -- Life Tap
        local found, _, healthCost = string.find(line, "Converts (%d+) health into %d+ mana.")
        if found then
            return {Health = {cost = tonumber(healthCost)}}
        end
    end
    return {}
end

function RCAB_ActionButton_ScanSkillReagents(line)
    if line ~= nil then
        -- Single Reagent
        local found, _, reagentName = string.find(line, "Reagents: ([^,]+)")
        if found then
            return {Reagent = {cost = 1, name = reagentName}}
        end
    end
    return {}
end

function RCAB_StripEscapeSequences(text)
    text = string.gsub(text, "\|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "\|r", "")
    return text
end

function RCAB_Merge(table1, table2)
    for key, val in pairs(table2) do
        table1[key] = val
    end
    return table1
end
