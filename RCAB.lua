-- ActionButton local variables
-- ============================
-- RCAB_label: reference to the TextString for resource display
-- RCAB_resourceCosts: table indexed by resource type (string, one of "Mana", "Rage", "Energy", "Health", "Ammo", "Reagent") with fields:
--   amount: number
--   name: string, name of the reagent (only in case of "Reagent" type)
-- Example:
-- this.RCAB_resourceCosts = { Mana = {amount = 50}, Reagent = {name = "Soul Shard", amount = 1} };

-- Global variables
-- ================
-- RCAB_savedResourceCosts: list
-- RCAB_savedResourceCosts[slotID]: list, RCAB_resourceCosts saved for the ActionButton with index slotID

function RCAB_Init()
    -- hook ActionButton functions
    RCAB_Old_ActionButton_OnEvent = ActionButton_OnEvent;
    ActionButton_OnEvent = RCAB_ActionButton_OnEvent;

    RCAB_Old_ActionButton_SetTooltip = ActionButton_SetTooltip;
    ActionButton_SetTooltip = RCAB_ActionButton_SetTooltip;
end

-- Hooked ActionButton callbacks

function RCAB_ActionButton_OnEvent(event)
    RCAB_Old_ActionButton_OnEvent(event);

    -- ActionButton initialization
    if not RCAB_ActionButton_IsInitialized() then
        RCAB_ActionButton_Initialize();
    end
    
    -- Restore saved settings (with delayed initialization)
    if RCAB_savedResourceCosts and not this.RCAB_variablesLoaded then
        RCAB_ActionButton_LoadSettings();
        this.RCAB_variablesLoaded = true;
    end
    
    -- Load saved settings when switching action bars
    if event == "ACTIONBAR_PAGE_CHANGED" then
        RCAB_ActionButton_LoadSettings();
    end
    
    -- Learn resource cost right after player placed a skill in a slot
    if event == "ACTIONBAR_SLOT_CHANGED" and arg1 == ActionButton_GetPagedID(this) then
        RCAB_ActionButton_LearnSkill();
    end
    
    -- Update counter
    RCAB_ActionButton_UpdateCounter();
end

function RCAB_ActionButton_SetTooltip()
    RCAB_Old_ActionButton_SetTooltip();

    if RCAB_ActionButton_IsInitialized() then
        RCAB_ActionButton_LearnSkill();
    end
end

-- Helper functions

function RCAB_StripEscapeSequences(text)
    text = string.gsub(text, "\|c%x%x%x%x%x%x%x%x", "");
    text = string.gsub(text, "\|r", "");
    return text;
end

function RCAB_Merge(table1, table2)
    for key, val in pairs(table2) do
        table1[key] = val;
    end
    return table1;
end

function RCAB_Empty(t)
    return next(t) == nil;
end

-- Internal functionality

function RCAB_ActionButton_Initialize()
    -- Add the resourceLabel FontString to the ActionButton
    if not this.RCAB_label then
        this.RCAB_label = this:CreateFontString("", "ARTWORK", "NumberFontNormalSmall");
        this.RCAB_label:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT");
        this.RCAB_label:SetText("");
    end
    
    -- Initialize the local variable
    if not this.RCAB_resourceCosts then
        this.RCAB_resourceCosts = {};
    end
end

function RCAB_ActionButton_IsInitialized()
    return this.RCAB_label and this.RCAB_resourceCosts;
end

function RCAB_ActionButton_ShouldShowResource()
    if HasAction(ActionButton_GetPagedID(this)) then
        if not RCAB_Empty(this.RCAB_resourceCosts) then
            return true;
        end
    end
    return false;
end

function RCAB_ActionButton_UpdateCounter()
    if RCAB_ActionButton_ShouldShowResource() then
        local textString = "";
        for resourceType, info in this.RCAB_resourceCosts do
            if resourceType == "Mana" or
               resourceType == "Rage" or
               resourceType == "Energy" or
               resourceType == "Health" or
               resourceType == "Ammo" or
               resourceType == "Reagent" then
                local remainingCasts = math.floor(RCAB_GetPlayerResource(resourceType) / info.cost);
                textString = textString .. "|r ";
                textString = textString .. RCAB_ResourceTypeColorString(resourceType);
                textString = textString .. remainingCasts;
            end
        end
        this.RCAB_label:SetText(textString);
        this.RCAB_label:Show();
    else
        this.RCAB_label:Hide();
    end
end

function RCAB_ActionButton_LearnSkill()
    local learnedResourceCost = {};
    
    for line = 1, GameTooltip:NumLines() do
        local label = getglobal("GameTooltipTextLeft" .. line);
        local text = RCAB_StripEscapeSequences(label:GetText());
        if line == 1 then
            learnedResourceCost = RCAB_Merge(learnedResourceCost, RCAB_ActionButton_LearnSkillFromName(text));
        else
            learnedResourceCost = RCAB_Merge(learnedResourceCost, RCAB_ActionButton_LearnSkillFromResourceCost(text));
            learnedResourceCost = RCAB_Merge(learnedResourceCost, RCAB_ActionButton_LearnSkillFromDescription(text));
            learnedResourceCost = RCAB_Merge(learnedResourceCost, RCAB_ActionButton_LearnSkillFromReagents(text));
        end
    end
        
    this.RCAB_resourceCosts = learnedResourceCost;
    RCAB_ActionButton_SaveSettings();
    RCAB_RegisterForResourceEvents();
    RCAB_ActionButton_UpdateCounter();
end

function RCAB_ActionButton_LearnSkillFromResourceCost(line)
    if line ~= nil then
        -- Skills that cost primary resources
        local _, _, resourceCost, resourceType = string.find(line, "(%d+) (%a+)");
        if resourceType == "Mana" or
           resourceType == "Rage" or
           resourceType == "Energy" or
           resourceType == "Health" then
            return {[resourceType] = {cost = resourceCost}};
        end
    end
    return {};
end

function RCAB_ActionButton_LearnSkillFromName(line)
    if line ~= nil then
        -- Ranged weapon skills
        if line == "Auto Shot" or
           line == "Shoot Bow" or
           line == "Shoot Crossbow" or
           line == "Shoot Gun" or
           line == "Throw" then
            return {Ammo = {cost = 1}};
        end
    end
    return {};
end

function RCAB_ActionButton_LearnSkillFromDescription(line)
    if line ~= nil then
        -- Life Tap
        local found, _, healthCost = string.find(line, "Converts (%d+) health into %d+ mana.");
        if found then
            return {Health = {cost = tonumber(healthCost)}};
        end
    end
    return {};
end

function RCAB_ActionButton_LearnSkillFromReagents(line)
    if line ~= nil then
        -- Single Reagent
        line = RCAB_StripEscapeSequences(line);
        local found, _, reagentName = string.find(line, "Reagents: ([^,]+)");
        if found then
            return {Reagent = {cost = 1, name = reagentName}};
        end
    end
    return {};
end

function RCAB_ResourceTypeColorString(resourceType)
    if resourceType == "Mana" then
        return "|cFF8080FF";
    elseif resourceType == "Rage" then
        return "|cFFFFB366";
    elseif resourceType == "Energy" then
        return "|cFFFFFF66";
    elseif resourceType == "Health" then
        return "|cFF66FF66";
    else
        return "|cFFB3B3B3";
    end
end

function RCAB_RegisterForResourceEvents()
    for resourceType, _ in this.RCAB_resourceCosts do
        if resourceType == "Mana" then
            this:RegisterEvent("UNIT_MANA");
        elseif resourceType == "Rage" then
            this:RegisterEvent("UNIT_RAGE");
        elseif resourceType == "Energy" then
            this:RegisterEvent("UNIT_ENERGY");
        elseif resourceType == "Health" then
            this:RegisterEvent("UNIT_HEALTH");
        elseif resourceType == "Ammo" then
            -- ActionButton already reacts to suitable event
        elseif resourceType == "Reagent" then
           this:RegisterEvent("BAG_UPDATE");
        end
    end
end

-- Persistent storage

function RCAB_ActionButton_SaveSettings()
    local slotID = ActionButton_GetPagedID(this);
    if not RCAB_savedResourceCosts then
        RCAB_savedResourceCosts = {};
    end
    RCAB_savedResourceCosts[slotID] = this.RCAB_resourceCosts;
end

function RCAB_ActionButton_LoadSettings()
    local slotID = ActionButton_GetPagedID(this);
    if RCAB_savedResourceCosts then
        if RCAB_savedResourceCosts[slotID] then
            this.RCAB_resourceCosts = RCAB_savedResourceCosts[slotID];
        end
    end
    RCAB_RegisterForResourceEvents();
end

function RCAB_GetPlayerResource(resourceType)
    local playerResourceTypeNumber = UnitPowerType("player");
    local playerResourceType = "";
    if playerResourceTypeNumber == 0 then
        playerResourceType = "Mana";
    elseif playerResourceTypeNumber == 1 then
        playerResourceType = "Rage";
    elseif playerResourceTypeNumber == 3 then
        playerResourceType = "Energy";
    end

    if resourceType == "Health" then
        return UnitHealth("player");
    elseif resourceType == "Ammo" then
        local pageID = ActionButton_GetPagedID(this);
        if IsUsableAction(pageID) then
            local ammoSlotID = GetInventorySlotInfo("AmmoSlot");
            if GetInventoryItemTexture("player", ammoSlotID) then
                return GetInventoryItemCount("player", ammoSlotID);
            else
                return 0;
            end
        else
            return 0;
        end
    elseif resourceType == "Reagent" then
        return RCAB_CountReagents(this.RCAB_resourceCosts[resourceType].name);
    elseif resourceType == playerResourceType then
        return UnitMana("player");
    else
        return 0;
    end
end

function RCAB_CountReagents(reagentName)
    local totalCount = 0;
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink = GetContainerItemLink(bagID, slot);
            if itemLink and string.find(itemLink, reagentName) then
                local _, itemCount = GetContainerItemInfo(bagID, slot);
                totalCount = totalCount + itemCount;
            end
        end
    end
    return totalCount;
end

RCAB_Init();
