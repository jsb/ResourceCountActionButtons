function RCAB_Init()
    -- hook ActionButton functions
    RCAB_Old_ActionButton_OnEvent = ActionButton_OnEvent;
    ActionButton_OnEvent = RCAB_ActionButton_OnEvent;
end

-- Hooked ActionButton callback
function RCAB_ActionButton_OnEvent(event)
    RCAB_Old_ActionButton_OnEvent(event);

    -- Check for ActionButton initialization
    if (this.RCAB_initialized == nil) or (not this.RCAB_initialized) then
        RCAB_ActionButton_Init();
        this.RCAB_initialized = true;
    end

    RCAB_ActionButton_Update();
end

function RCAB_ActionButton_Init()
    -- Add the resourceLabel FontString to the ActionButton
    this.RCAB_resourceLabel = this:CreateFontString("", "ARTWORK", "NumberFontNormalSmall");
    this.RCAB_resourceLabel:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT");
    this.RCAB_resourceLabel:SetText("");
end

function RCAB_ActionButton_Update()
end

RCAB_Init();
