-- ActionButton local variables
-- ============================
-- RCAB_label: reference to the TextString for resource display

-- Global variables
-- ================
-- RCAB_resourceCosts: table mapping action slot IDs to ResourceCosts tables
--   each ResourceCosts table is a table indexed by resource type (string, one of "Mana", "Rage", "Energy", "Health", "Ammo", "Reagent") with fields:
--     amount: number
--     name: string, name of the reagent (only in case of "Reagent" type)
-- Example:
-- RCAB_resourceCosts = {
--   [1] = { Mana = {amount = 38} },
--   [2] = { Mana = {amount = 50}, Reagent = {name = "Soul Shard", amount = 1} },
--   [3] = { Health = {amount = 45} },
-- }

RCAB_resourceCosts = {}
RCAB_tooltip = nil

function RCAB_Init()
    -- hook ActionButton event callback
    if not RCAB_Old_ActionButton_OnEvent then
        RCAB_Old_ActionButton_OnEvent = ActionButton_OnEvent
        ActionButton_OnEvent = RCAB_ActionButton_OnEvent
    end
    
    -- do one initial scan of all action slots
    for pagedID = 1, 120 do
        RCAB_ScanResourceCosts(pagedID)
    end
end

-- Hooked ActionButton callbacks

function RCAB_ActionButton_OnEvent(event)
    RCAB_Old_ActionButton_OnEvent(event)

    -- ActionButton initialization
    if not RCAB_ActionButton_IsInitialized() then
        RCAB_ActionButton_Initialize()
    end
    
    if event == "ACTIONBAR_SLOT_CHANGED" then
        if arg1 == ActionButton_GetPagedID(this) then
            RCAB_ActionButton_Rescan()
        end
    end
    -- Update counter
    RCAB_ActionButton_UpdateCounter()
end

-- Internal functionality

function RCAB_ActionButton_Rescan()
    local pagedID = ActionButton_GetPagedID(this)
    if HasAction(pagedID) then
        RCAB_ScanResourceCosts(pagedID)
        RCAB_ActionButton_RegisterForResourceEvents() 
    end
end

function RCAB_ActionButton_Initialize()
    -- Add the resourceLabel FontString to the ActionButton
    if not this.RCAB_label then
        this.RCAB_label = this:CreateFontString("", "ARTWORK", "NumberFontNormalSmall")
        this.RCAB_label:SetPoint("BOTTOMRIGHT", this, "BOTTOMRIGHT")
        this.RCAB_label:SetText("")
        this.RCAB_label:Hide()
    end
    RCAB_ActionButton_RegisterForResourceEvents()
    this:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
end

function RCAB_ActionButton_RegisterForResourceEvents()
    local resourceCosts = RCAB_ActionButton_GetResourceCosts()
    if resourceCosts then
        if resourceCosts.Mana then
            this:RegisterEvent("UNIT_MANA")
        end
        if resourceCosts.Rage then
            this:RegisterEvent("UNIT_RAGE")
        end
        if resourceCosts.Energy then
            this:RegisterEvent("UNIT_ENERGY")
        end
        if resourceCosts.Health then
            this:RegisterEvent("UNIT_HEALTH")
        end
        if resourceCosts.Reagent then
            this:RegisterEvent("BAG_UPDATE")
        end
    end
end

function RCAB_ActionButton_IsInitialized()
    return this.RCAB_label
end

function RCAB_ActionButton_GetResourceCosts()
    local pagedID = ActionButton_GetPagedID(this)
    if HasAction(pagedID) then
        return RCAB_resourceCosts[pagedID]
    end
    return nil
end

function RCAB_ActionButton_UpdateCounter()
    local resourceCosts = RCAB_ActionButton_GetResourceCosts()
    if resourceCosts then
        local textString = ""
        for resourceType, info in resourceCosts do
            if RCAB_ShouldDisplayResource(resourceType) then
                local remainingResource = RCAB_GetPlayerResource(resourceType, info.name)
                local remainingCasts = math.floor(remainingResource / info.cost)
                textString = textString .. "|r "
                textString = textString .. RCAB_ResourceTypeColorString(resourceType)
                textString = textString .. remainingCasts
            end
        end
        this.RCAB_label:SetText(textString)
        this.RCAB_label:Show()
    else
        this.RCAB_label:Hide()
    end
end

function RCAB_ResourceTypeColorString(resourceType)
    if resourceType == "Mana" then
        return "|cFF8080FF"
    elseif resourceType == "Rage" then
        return "|cFFFFB366"
    elseif resourceType == "Energy" then
        return "|cFFFFFF66"
    elseif resourceType == "Health" then
        return "|cFF66FF66"
    else
        return "|cFFB3B3B3"
    end
end

function RCAB_ShouldDisplayResource(resourceType)
    -- this check is basically only necessary for druids who can have different power types while shapeshifting
    local playerResourceTypeNumber = UnitPowerType("player")
    if playerResourceTypeNumber ~= 0 and resourceType == "Mana" then
        return false
    end
    if playerResourceTypeNumber ~= 1 and resourceType == "Rage" then
        return false
    end
    if playerResourceTypeNumber ~= 3 and resourceType == "Energy" then
        return false
    end
    return true
end

function RCAB_GetPlayerResource(resourceType, reagentName)
    local playerResourceTypeNumber = UnitPowerType("player")
    local playerResourceType = ""
    if playerResourceTypeNumber == 0 then
        playerResourceType = "Mana"
    elseif playerResourceTypeNumber == 1 then
        playerResourceType = "Rage"
    elseif playerResourceTypeNumber == 3 then
        playerResourceType = "Energy"
    end

    if resourceType == "Health" then
        return UnitHealth("player")
    elseif resourceType == "Ammo" then
        local pagedID = ActionButton_GetPagedID(this)
        if IsUsableAction(pagedID) then
            local ammoSlotID = GetInventorySlotInfo("AmmoSlot")
            if GetInventoryItemTexture("player", ammoSlotID) then
                return GetInventoryItemCount("player", ammoSlotID)
            else
                return 0
            end
        else
            return 0
        end
    elseif resourceType == "Reagent" then
        return RCAB_CountReagents(reagentName)
    elseif resourceType == playerResourceType then
        return UnitMana("player")
    else
        return 0
    end
end

function RCAB_CountReagents(reagentName)
    local totalCount = 0
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink = GetContainerItemLink(bagID, slot)
            if itemLink and string.find(itemLink, reagentName) then
                local _, itemCount = GetContainerItemInfo(bagID, slot)
                totalCount = totalCount + itemCount
            end
        end
    end
    return totalCount
end

local RCAB_initFrame = CreateFrame("Frame")
RCAB_initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RCAB_initFrame:SetScript("OnEvent", RCAB_Init)