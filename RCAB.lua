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

    if this.RCAB_learnedSkill then
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
    RCAB_ActionButton_LearnSkillFromLine(fontString2:GetText());

    if this.RCAB_learnedSkill then
        RCAB_ActionButton_UpdateCounter();
    end
end

function RCAB_ActionButton_LearnSkillFromLine(line)
    if line ~= nil then
        local _, _, resourceCost, resourceType = string.find(line, "(%d+) (%a+)");
        if resourceType == "Mana" or
           resourceType == "Rage" or
           resourceType == "Energy" or
           resourceType == "Health" then
            this.RCAB_resourceCost = resourceCost;
            this.RCAB_resourceType = resourceType;

            this:RegisterEvent("UNIT_" .. string.upper(resourceType));

            this.RCAB_learnedSkill = true;
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
        this.RCAB_resourceLabel:SetTextColor(0.5, 0.5, 0.5);
    end
end

function RCAB_GetPlayerResource(resourceType)
    local playerResourceTypeNumber = UnitPowerType("player");
    local playerResourceType = "";
    if     playerResourceTypeNumber == 0 then playerResourceType = "Mana";
    elseif playerResourceTypeNumber == 1 then playerResourceType = "Rage";
    elseif playerResourceTypeNumber == 3 then playerResourceType = "Energy";
    end

    local playerResourceAmount = UnitMana("player");
    if resourceType == "Health" then
        return UnitHealth("player");
    elseif resourceType == playerResourceType then
        return playerResourceAmount;
    else
        return 0;
    end
end

RCAB_Init();
