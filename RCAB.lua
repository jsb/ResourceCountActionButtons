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

    -- Check for ActionButton initialization
    if not this.RCAB_initialized then
        RCAB_ActionButton_Init();
        this.RCAB_initialized = true;
    end

    RCAB_ActionButton_Update();
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
    this.RCAB_resourceLabel:SetText("");
    this.RCAB_learnedSkill = false;
end

function RCAB_ActionButton_Update()
    if this.RCAB_learnedSkill then
        local remainingCasts = math.floor(RCAB_GetPlayerResource(this.RCAB_resourceType) / this.RCAB_resourceCost);
        this.RCAB_resourceLabel:SetText(remainingCasts);
    end
end

function RCAB_ActionButton_LearnSkill()
    if not this.RCAB_learnedSkill then
        -- Try to infer resource cost and type from the GameTooltip
        local fontString2 = getglobal("GameTooltipTextLeft2");
        RCAB_ActionButton_LearnSkillFromLine(fontString2:GetText());
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
            this.RCAB_learnedSkill = true;
        end
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
