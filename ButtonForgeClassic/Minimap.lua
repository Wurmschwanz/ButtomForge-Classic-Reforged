-- ButtonForge Classic - Vanilla-style minimap button
local BF = BFClassic

function BF:GetMinimapButtonAngle()
    self:EnsureDB()
    if not ButtonForgeClassicDB.settings.minimapAngle then
        ButtonForgeClassicDB.settings.minimapAngle = 225
    end
    return ButtonForgeClassicDB.settings.minimapAngle
end

function BF:SetMinimapButtonPosition(angle)
    if not self.MinimapButton or not Minimap then return end
    self:EnsureDB()
    angle = angle or self:GetMinimapButtonAngle()
    ButtonForgeClassicDB.settings.minimapAngle = angle

    local rad = angle * 3.141592653589793 / 180
    local radius = 78
    local x = math.cos(rad) * radius
    local y = math.sin(rad) * radius

    self.MinimapButton:ClearAllPoints()
    self.MinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function BF:ShowMinimapTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("ButtonForge Classic")
    GameTooltip:AddLine("Left-click: Toggle Configure Mode", 1, 1, 1)
    GameTooltip:AddLine("Shift + Left-click: Toggle Keybind Mode", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Create New Bar", 1, 1, 1)
    GameTooltip:AddLine("Alt + drag: Move minimap button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function BF:CreateMinimapButton()
    if self.MinimapButton then return end
    if not Minimap then return end

    -- Classic minimap button layout.  The texture anchors intentionally match
    -- Blizzard's own tracking button pattern; many minimap-button-bags expect this.
    local b = CreateFrame("Button", "ButtonForgeClassicMinimapButton", Minimap)
    b:SetWidth(32)
    b:SetHeight(32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:EnableMouse(true)

    local icon = b:CreateTexture("ButtonForgeClassicMinimapButtonIcon", "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)
    icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    local overlay = b:CreateTexture("ButtonForgeClassicMinimapButtonBorder", "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.overlay = overlay

    local highlight = b:CreateTexture("ButtonForgeClassicMinimapButtonHighlight", "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(b)
    b.highlight = highlight

    b:SetScript("OnEnter", function()
        BF:ShowMinimapTooltip(this)
    end)

    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    b:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if IsShiftKeyDown and IsShiftKeyDown() then
                BF:ToggleKeybindMode()
            else
                BF:ToggleConfigMode()
            end
        elseif arg1 == "RightButton" then
            BF:CreateBar()
        end
        BF:ShowMinimapTooltip(this)
    end)

    b:SetScript("OnDragStart", function()
        if IsAltKeyDown and IsAltKeyDown() then
            this:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local px, py = GetCursorPosition()
                local scale = UIParent:GetScale() or 1
                px = px / scale
                py = py / scale
                local angle = math.deg(math.atan2(py - my, px - mx))
                BF:SetMinimapButtonPosition(angle)
            end)
        end
    end)

    b:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
    end)

    self.MinimapButton = b
    self:SetMinimapButtonPosition(self:GetMinimapButtonAngle())
end
