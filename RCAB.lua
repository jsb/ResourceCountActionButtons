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
    if not this.RCAB_initialized then
        RCAB_ActionButton_Init();
        this.RCAB_initialized = true;
    end

    if not this.RCAB_settingsLoaded or event == "ACTIONBAR_PAGE_CHANGED" then
        -- Delayed initialization of persistent settings
        RCAB_ActionButton_LoadSettings();
    elseif this.RCAB_learnedSkill then
        -- Update counter
        if HasAction(ActionButton_GetPagedID(this)) then
            RCAB_ActionButton_UpdateCounter();
        else
            RCAB_ActionButton_ResetButton();
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" and arg1 == ActionButton_GetPagedID(this) then
        -- Learn resource cost right after player placed a skill in a slot
        RCAB_ActionButton_LearnSkill();
    end
end

function RCAB_ActionButton_SetTooltip()
    RCAB_Old_ActionButton_SetTooltip();

    -- Check for ActionButton initialization
    if this.RCAB_initialized then
        RCAB_ActionButton_LearnSkill();
    end
end

-- Internal functionality

function RCAB_ActionButton_Init()
    -- Add the resourceLabel FontString to the ActionButton
    this.RCAB_resourceLabel = this:CreateFontString("", "ARTWORK", "NumberFontNormalSmall");
    this.RCAB_resourceLabel:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT");
    RCAB_ActionButton_ResetButton();
end

function RCAB_ActionButton_ResetButton()
    this.RCAB_resourceLabel:SetText("");
    this.RCAB_learnedSkill = false;
end

function RCAB_ActionButton_UpdateCounter()
    local remainingCasts = math.floor(RCAB_GetPlayerResource(this.RCAB_resourceType) / this.RCAB_resourceCost);
    this.RCAB_resourceLabel:SetText(remainingCasts);
    RCAB_ActionButton_UpdateTextColor();
end

function RCAB_ActionButton_LearnSkill()
    -- Try to infer resource cost and type from the GameTooltip
    local fontString2 = getglobal("GameTooltipTextLeft2");
    RCAB_ActionButton_LearnSkillFromResourceCost(fontString2:GetText());

    local fontString1 = getglobal("GameTooltipTextLeft1");
    RCAB_ActionButton_LearnSkillFromName(fontString1:GetText());
    
    local fontString3 = getglobal("GameTooltipTextLeft3");
    RCAB_ActionButton_LearnSkillFromDescription(fontString3:GetText());

    if this.RCAB_learnedSkill then
        RCAB_ActionButton_SaveSettings();
        RCAB_ActionButton_UpdateCounter();
    end
end

function RCAB_ActionButton_LearnSkillFromResourceCost(line)
    if line ~= nil then
        -- Skills that cost primary resources
        local _, _, resourceCost, resourceType = string.find(line, "(%d+) (%a+)");
        if resourceType == "Mana" or
           resourceType == "Rage" or
           resourceType == "Energy" or
           resourceType == "Health" then
            this.RCAB_resourceCost = resourceCost;
            this.RCAB_resourceType = resourceType;
            this.RCAB_learnedSkill = true;

            this:RegisterEvent("UNIT_" .. string.upper(resourceType));
        end
    end
end

function RCAB_ActionButton_LearnSkillFromName(line)
    if line ~= nil then
        -- Ranged weapon skills
        if line == "Auto Shot" or
           line == "Shoot Bow" or
           line == "Shoot Crossbow" or
           line == "Shoot Gun" or
           line == "Throw" then
            this.RCAB_resourceCost = 1;
            this.RCAB_resourceType = "Ammo";
            this.RCAB_learnedSkill = true;
        end
    end
end

function RCAB_ActionButton_LearnSkillFromDescription(line)
    if line ~= nil then
        -- Life Tap
        local found, _, healthCost = string.find(line, "Converts (%d+) health into %d+ mana.");
        if found then
            this.RCAB_resourceCost = tonumber(healthCost);
            this.RCAB_resourceType = "Health";
            this.RCAB_learnedSkill = true;
            this:RegisterEvent("UNIT_HEALTH");
        end
    end
end

function RCAB_ActionButton_UpdateTextColor()
    if this.RCAB_resourceType == "Mana" then
        this.RCAB_resourceLabel:SetTextColor(0.5, 0.5, 1.0);
    elseif this.RCAB_resourceType == "Rage" then
        this.RCAB_resourceLabel:SetTextColor(1.0, 0.7, 0.4);
    elseif this.RCAB_resourceType == "Energy" then
        this.RCAB_resourceLabel:SetTextColor(1.0, 1.0, 0.4);
    elseif this.RCAB_resourceType == "Health" then
        this.RCAB_resourceLabel:SetTextColor(0.4, 1.0, 0.4);
    else
        this.RCAB_resourceLabel:SetTextColor(0.7, 0.7, 0.7);
    end
end

-- Persistent storage

function RCAB_ActionButton_SaveSettings()
    local slotID = ActionButton_GetPagedID(this);

    if not RCAB_savedResourceCosts then
        RCAB_savedResourceCosts = {};
    end
    RCAB_savedResourceCosts[slotID] = {};
    RCAB_savedResourceCosts[slotID].resourceCost = this.RCAB_resourceCost;
    RCAB_savedResourceCosts[slotID].resourceType = this.RCAB_resourceType;
end

function RCAB_ActionButton_LoadSettings()
    local slotID = ActionButton_GetPagedID(this);
    if RCAB_savedResourceCosts then
        if RCAB_savedResourceCosts[slotID] then
            this.RCAB_resourceCost = RCAB_savedResourceCosts[slotID].resourceCost;
            this.RCAB_resourceType = RCAB_savedResourceCosts[slotID].resourceType;
            this.RCAB_learnedSkill = true;
            this.RCAB_settingsLoaded = true;
        end
    end
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
    elseif resourceType == playerResourceType then
        return UnitMana("player");
    else
        return 0;
    end
end

RCAB_Init();
