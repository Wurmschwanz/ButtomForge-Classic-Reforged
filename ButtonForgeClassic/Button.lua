-- ButtonForge Classic - Vanilla action-slot backed buttons
-- v0.2.7: stable v0.2.5 + conservative stack/count refresh only. No cooldown frames.
local BF = BFClassic

function BF:IsActionSlotAllocated(slot, currentSave)
    self:EnsureDB()
    local i, j
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        local barSave = ButtonForgeClassicDB.bars[i]
        if barSave and barSave.buttons then
            for j = 1, table.getn(barSave.buttons) do
                local buttonSave = barSave.buttons[j]
                if buttonSave and buttonSave ~= currentSave and buttonSave.actionSlot == slot then
                    return true
                end
            end
        end
    end
    return false
end


function BF:IsBindingIdAllocated(bindingId, currentSave)
    self:EnsureDB()
    local i, j
    for i = 1, table.getn(ButtonForgeClassicDB.bars) do
        local barSave = ButtonForgeClassicDB.bars[i]
        if barSave and barSave.buttons then
            for j = 1, table.getn(barSave.buttons) do
                local buttonSave = barSave.buttons[j]
                if buttonSave and buttonSave ~= currentSave and buttonSave.bindingId == bindingId then
                    return true
                end
            end
        end
    end
    return false
end

function BF:GetBindingIdForButton(parent, index)
    local save = self:GetButtonSave(parent, index)
    local max = self.MaxBindingButtons or ((self.ActionSlotEnd or 120) - (self.ActionSlotStart or 73) + 1)
    if save.bindingId and save.bindingId >= 1 and save.bindingId <= max then
        return save.bindingId
    end

    local id
    for id = 1, max do
        if not self:IsBindingIdAllocated(id, save) then
            save.bindingId = id
            return id
        end
    end

    self:Print("No free ButtonForge binding id left.")
    return nil
end

function BF:GetActionSlotForButton(parent, index)
    -- Vanilla offers only a limited set of safe backing ActionSlots here
    -- (currently 73-120). Instead of reserving 24 fixed slots per bar, we now
    -- allocate the next free slot globally. This allows more than two bars as
    -- long as the total number of visible ButtonForge buttons stays within the
    -- available slot pool.
    local save = self:GetButtonSave(parent, index)
    if save.actionSlot and save.actionSlot >= (self.ActionSlotStart or 73) and save.actionSlot <= (self.ActionSlotEnd or 120) then
        return save.actionSlot
    end

    local slot
    for slot = (self.ActionSlotStart or 73), (self.ActionSlotEnd or 120) do
        if not self:IsActionSlotAllocated(slot, save) then
            save.actionSlot = slot
            return slot
        end
    end

    self:Print("No free Vanilla ActionSlot left. Reduce total buttons or wait for the custom action backend.")
    return nil
end

function BF:ButtonHasCursor()
    if self.InternalCursorActive then return true end

    -- Turtle/Vanilla does not consistently provide CursorHasMacro().
    -- GetCursorInfo() does report dragged macros, so check it first.
    if GetCursorInfo then
        local cursorType = GetCursorInfo()
        if cursorType == "spell" or cursorType == "item" or cursorType == "macro" then
            return true
        end
    end

    if CursorHasSpell and CursorHasSpell() then return true end
    if CursorHasItem and CursorHasItem() then return true end
    if CursorHasMacro and CursorHasMacro() then return true end
    if CursorHasMoney and CursorHasMoney() then return true end
    return false
end

function BF:ClearCursorSafe()
    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    if ClearCursor then ClearCursor() end
end

function BF:SuppressNextClick(button, seconds)
    if not button or not GetTime then return end
    button.bfcSuppressClickUntil = GetTime() + (seconds or 1.25)
end

function BF:IsClickSuppressed(button)
    if not button or not button.bfcSuppressClickUntil or not GetTime then return false end
    if GetTime() <= button.bfcSuppressClickUntil then
        return true
    end
    button.bfcSuppressClickUntil = nil
    return false
end

function BF:GetButtonSave(parent, index)
    if not parent.save.buttons then parent.save.buttons = {} end
    if not parent.save.buttons[index] then parent.save.buttons[index] = {} end
    return parent.save.buttons[index]
end

function BF:CreateEmptyButton(parent, index)
    local name = parent:GetName() .. "Button" .. tostring(index)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(self.ButtonSize)
    button:SetHeight(self.ButtonSize)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp", "Button4Up", "Button5Up")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)

    button.parentBar = parent
    button.index = index
    button.save = self:GetButtonSave(parent, index)
    button.actionSlot = button.save.actionSlot or self:GetActionSlotForButton(parent, index)
    button.save.actionSlot = button.actionSlot
    button.bindingId = button.save.bindingId or self:GetBindingIdForButton(parent, index)
    button.save.bindingId = button.bindingId

    -- v0.2.4: Do NOT use native-size quickslot artwork. In some 1.12 clients
    -- texture width/height can behave oddly after SetTexture(), so we anchor the
    -- icon to all four inner corners. This forces the artwork into the slot.
    button.icon = button:CreateTexture(name .. "Icon", "ARTWORK")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Vanilla 1.12 uses a Model frame for the Blizzard cooldown spiral.
    -- Keep this independent from click/drag/keybind logic.
    local cooldownName = name .. "Cooldown"
    button.cooldown = CreateFrame("Model", cooldownName, button, "CooldownFrameTemplate")
    if button.cooldown then
        button.cooldown:ClearAllPoints()
        button.cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        button.cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
    end

    -- Avoid the Blizzard quickslot border texture for now; it was the likely
    -- source of oversized artwork on Turtle/1.12. Use a simple backdrop instead.
    button:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    button:SetBackdropColor(0, 0, 0, 0.75)

    button.count = button:CreateFontString(name .. "Count", "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)

    button.hotkey = button:CreateFontString(name .. "HotKey", "OVERLAY", "NumberFontNormalSmallGray")
    button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
    button.hotkey:SetText("")

    button:SetScript("OnReceiveDrag", BF.Button_OnReceiveDrag)
    button:SetScript("OnDragStart", BF.Button_OnDragStart)
    button:SetScript("OnClick", BF.Button_OnClick)
    button:SetScript("OnMouseDown", BF.Button_OnMouseDown)
    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", BF.Button_OnMouseWheel)
    button:SetScript("OnEnter", BF.Button_OnEnter)
    button:SetScript("OnLeave", BF.Button_OnLeave)

    self:RefreshButton(button)
    self:UpdateButtonHotkey(button)
    return button
end

function BF:UpdateButtonCooldown(button)
    if not button or not button.cooldown or not button.actionSlot then return end
    if not GetActionCooldown or not CooldownFrame_SetTimer then return end

    local start, duration, enable = GetActionCooldown(button.actionSlot)
    start = start or 0
    duration = duration or 0
    enable = enable or 0

    CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
end


function BF:UpdateButtonRange(button)
    if not button or not button.icon then return end

    local slot = button.actionSlot
    if not slot or not HasAction or not HasAction(slot) then
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
        return
    end

    -- Vanilla returns 1 when in range, 0 when out of range and nil when the
    -- action has no range component or cannot currently be evaluated.
    local inRange = nil
    if IsActionInRange then
        inRange = IsActionInRange(slot)
    end

    -- Auto Attack / basic melee actions often return nil from IsActionInRange
    -- on 1.12/Turtle.  Use a conservative melee-distance fallback only for
    -- attack actions.  CheckInteractDistance(..., 3) is the closest reliable
    -- built-in distance check available on this client; it is approximate but
    -- correctly distinguishes clearly out-of-melee targets.
    if inRange == nil and IsAttackAction and IsAttackAction(slot) then
        if UnitExists and UnitExists("target") and not (UnitIsDead and UnitIsDead("target")) then
            if CheckInteractDistance then
                if CheckInteractDistance("target", 3) then
                    inRange = 1
                else
                    inRange = 0
                end
            end
        else
            -- No valid target: do not paint Auto Attack red permanently.
            inRange = 1
        end
    end

    -- Match the Blizzard action-bar coloring order: out-of-range stays red;
    -- otherwise actions that are unusable specifically because of mana/rage/
    -- energy are tinted blue.  Other usable actions remain full color.
    local usable, noMana = nil, nil
    if IsUsableAction then
        usable, noMana = IsUsableAction(slot)
    end

    if inRange == 0 then
        button.icon:SetVertexColor(1.0, 0.15, 0.15)
    elseif (usable == nil or usable == 0) and noMana == 1 then
        button.icon:SetVertexColor(0.35, 0.35, 1.0)
    else
        button.icon:SetVertexColor(1.0, 1.0, 1.0)
    end
end

function BF:RefreshButton(button)
    if not button then return end

    -- A button can still exist after the bar was resized smaller. Keep it hidden
    -- even if its backing Vanilla ActionSlot still contains an action. Without
    -- this guard, old buttons can reappear after ACTIONBAR_SLOT_CHANGED or moving
    -- the bar, creating phantom rows/gaps below the real layout.
    if button.activeInLayout == false then
        button:Hide()
        return
    end

    local slot = button.actionSlot
    local hasAction = slot and HasAction and HasAction(slot)

    if button.SetBackdropBorderColor then
        if self:IsKeybindMode() then
            button:SetBackdropBorderColor(0.0, 1.0, 0.25, 1.0)
        else
            button:SetBackdropBorderColor(0.45, 0.45, 0.55, 1.0)
        end
    end
    local configMode = self:IsConfigMode()
    local showGrid = button.parentBar and button.parentBar.save and button.parentBar.save.showGrid
    local tempGrid = self:IsTemporaryGridActive()

    -- In play mode, empty slots disappear unless Grid/edit mode is enabled.
    -- While dragging/swapping actions, empty slots temporarily reappear so the
    -- swapped action can be dropped somewhere else.
    if (not hasAction) and (not configMode) and (not showGrid) and (not tempGrid) then
        button:Hide()
    else
        button:Show()
    end

    button.count:SetText("")

    -- Keep visuals constrained even after reloads or client-side texture refreshes.
    if button.icon then
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    if hasAction then
        local texture = GetActionTexture(slot)
        button.icon:SetTexture(texture or self.QuestionIcon)

        -- v0.2.7: Stack/item count only. Keep this very conservative: no
        -- cooldown frames, no native ActionButton template, no slot rebuilding.
        if GetActionCount then
            local count = GetActionCount(slot)
            if count and count > 1 then
                button.count:SetText(tostring(count))
            end
        end
    else
        button.icon:SetTexture(nil)
    end

    self:UpdateButtonCooldown(button)
    self:UpdateButtonHotkey(button)
    self:UpdateButtonRange(button)
end

function BF:IsTemporaryGridActive()
    if self.InternalCursorActive then return true end
    if self.TempGridUntil and GetTime and GetTime() < self.TempGridUntil then
        return true
    end
    return false
end

function BF:StartTemporaryGrid(seconds)
    if not GetTime then return end
    self.TempGridUntil = GetTime() + (seconds or 6)
    if self.TempGridFrame then
        self.TempGridFrame:Show()
    end
    self:RefreshAllButtons()
end

function BF:StopTemporaryGrid()
    self.TempGridUntil = nil
    if self.TempGridFrame then
        self.TempGridFrame:Hide()
    end
    self:RefreshAllButtons()
end


function BF:CompleteInternalDragDrop(targetButton)
    local sourceButton = self.InternalDragSource
    if not sourceButton or not targetButton then return false end
    if not sourceButton.actionSlot or not targetButton.actionSlot then return false end

    -- v0.4.15: Internal ButtonForge drags no longer use PickupAction/PlaceAction.
    -- Turtle/Vanilla can race these calls with mouse-up/click events, which made
    -- repeated swaps about 90% reliable but not 100%.  Instead we swap the
    -- backing ActionSlot references used by the two ButtonForge buttons.
    --
    -- This is deterministic:
    --   A -> empty B: B now points at A's old ActionSlot, A points at B's empty slot.
    --   A -> occupied B: the two buttons exchange their ActionSlot references.
    -- The real Blizzard ActionSlots are untouched; only ButtonForge's mapping
    -- changes. That makes repeated internal moves/swaps stable.

    if sourceButton == targetButton then
        self.InternalDragSource = nil
        self.InternalDragStartedAt = nil
        self.InternalCursorActive = false
        self:StopTemporaryGrid()
        self:RefreshAllButtons()
        return true
    end

    local sourceSlot = sourceButton.actionSlot
    local targetSlot = targetButton.actionSlot

    sourceButton.actionSlot = targetSlot
    targetButton.actionSlot = sourceSlot

    if sourceButton.save then sourceButton.save.actionSlot = targetSlot end
    if targetButton.save then targetButton.save.actionSlot = sourceSlot end

    -- Keep keybinds on the physical button position instead of letting them
    -- travel with the swapped spell/item/macro.

    self.InternalCursorActive = false
    self.InternalDragSource = nil
    self.InternalDragStartedAt = nil
    self.LastInternalDropAt = GetTime and GetTime() or 0

    self:SuppressNextClick(sourceButton, 0.4)
    self:SuppressNextClick(targetButton, 0.4)

    if ClearCursor then ClearCursor() end
    if PlaySound then PlaySound("igMainMenuOptionCheckBoxOn") end
    self:StopTemporaryGrid()
    self:RefreshAllButtons()
    return true
end

function BF:PlaceCursorOnButton(button)
    if not button or not button.actionSlot then return false end
    if button.actionSlot > (self.ActionSlotEnd or 120) then
        self:Print(self:T("NO_FREE_SLOT"))
        return false
    end

    if PlaceAction then
        -- Remember whether the target had an action before placing. If it did,
        -- Vanilla swaps that action onto the cursor. Turtle/1.12 does not always
        -- report that swapped cursor through CursorHasSpell/Item/Macro, so we
        -- track it ourselves. This is the core fix for repeated slot-to-slot
        -- swapping and moving a swapped action into an empty slot.
        local targetHadAction = false
        if HasAction and HasAction(button.actionSlot) then
            targetHadAction = true
        end

        PlaceAction(button.actionSlot)

        if targetHadAction then
            self.InternalCursorActive = true
            self.InternalDragSource = nil
            self:StartTemporaryGrid(6)
        else
            self.InternalCursorActive = false
            self.InternalDragSource = nil
        end

        self:RefreshAllButtons()
        return true
    end

    self:Print(self:T("PLACEACTION_MISSING"))
    return false
end

function BF:ClearButton(button)
    if not button or not button.actionSlot then return end
    if HasAction and HasAction(button.actionSlot) and PickupAction then
        PickupAction(button.actionSlot)
        self:ClearCursorSafe()
    end
    self:RefreshButton(button)
    self:Print(self:T("SLOT_CLEARED"))
end

function BF:UseButton(button)
    if not button or not button.actionSlot then return end
    if HasAction and HasAction(button.actionSlot) and UseAction then
        UseAction(button.actionSlot, 0, 0)
    end
    self:RefreshButton(button)
end

function BF.Button_OnReceiveDrag()
    -- Internal ButtonForge button drag: complete a true move/swap and clear the cursor.
    if BF.InternalDragSource then
        if BF:CompleteInternalDragDrop(this) then
            BF:SuppressNextClick(this, 1.25)
        end
        return
    end

    -- External spell/item/macro drag from spellbook, bags or macro frame.
    if BF:PlaceCursorOnButton(this) then
        BF:SuppressNextClick(this, 1.25)
    end
end

function BF.Button_OnDragStart()
    -- Internal ButtonForge drag. Do not call PickupAction here.
    -- We only remember the source button and later swap ButtonForge's
    -- ActionSlot references on the drop target. This avoids Turtle/1.12 cursor
    -- race conditions during repeated slot-to-slot swaps.
    if this.parentBar and this.parentBar.save and this.parentBar.save.locked then
        return
    end
    if this.actionSlot and HasAction and HasAction(this.actionSlot) then
        BF.InternalCursorActive = true
        BF.InternalDragSource = this
        BF.InternalDragStartedAt = GetTime and GetTime() or 0
        BF:SuppressNextClick(this, 0.4)
        BF:RefreshAllButtons()
        BF:StartTemporaryGrid(6)
    end
end

function BF.Button_OnMouseDown()
    if BF:IsKeybindMode() then
        -- Never capture primary mouse buttons in Keybind Mode. Left and right
        -- mouse are reserved for camera, targeting, looting and normal UI use.
        -- We ignore them completely so they cannot disturb WoW controls.
        if arg1 == "LeftButton" or arg1 == "RightButton" or
           arg1 == "BUTTON1" or arg1 == "BUTTON2" or
           arg1 == "Button1" or arg1 == "Button2" or
           arg1 == "MouseButton1" or arg1 == "MouseButton2" then
            return
        end

        BF.KeybindTarget = this

        -- If the player is holding an action on the cursor, treat the click as
        -- a drop operation instead of a keybind.
        if BF:ButtonHasCursor() then
            BF:PlaceCursorOnButton(this)
            return
        end

        if arg1 then
            BF:AssignKeyToButton(this, arg1)
        end
        return
    end
end

function BF.Button_OnMouseWheel()
    if BF:IsKeybindMode() then
        BF.KeybindTarget = this
        if arg1 and arg1 > 0 then
            BF:AssignKeyToButton(this, "MOUSEWHEELUP")
        else
            BF:AssignKeyToButton(this, "MOUSEWHEELDOWN")
        end
        return
    end
end

function BF.Button_OnClick()
    if BF:IsClickSuppressed(this) then
        return
    end

    -- Extra guard after an internal drag/drop. Some clients fire a normal click
    -- on the drop target a fraction of a second after OnReceiveDrag/OnClick has
    -- already completed the deterministic swap. Without this, repeated swaps can
    -- occasionally be undone or converted into a normal UseAction().
    if BF.LastInternalDropAt and GetTime and (GetTime() - BF.LastInternalDropAt) < 0.75 then
        return
    end

    if BF:IsKeybindMode() then
        BF.KeybindTarget = this

        -- Cursor action wins over keybind assignment. This fixes spell/item/macro
        -- drops while the green Keybind Mode highlight is active.
        if BF:ButtonHasCursor() then
            BF:PlaceCursorOnButton(this)
            return
        end

        if arg1 == "LeftButton" or arg1 == "RightButton" or
           arg1 == "BUTTON1" or arg1 == "BUTTON2" or
           arg1 == "Button1" or arg1 == "Button2" or
           arg1 == "MouseButton1" or arg1 == "MouseButton2" then
            -- Ignore primary mouse buttons completely in Keybind Mode.
            return
        elseif arg1 == "MiddleButton" or arg1 == "Button4" or arg1 == "Button5" then
            BF:AssignKeyToButton(this, arg1)
        else
            BF:Print(BF:T("KEYBIND_PRESS_KEY"))
        end
        return
    end

    -- After an internal drag starts, some 1.12 clients may fire a stray click
    -- even if the drop handler did not complete yet. While the temporary grid is
    -- active, never treat such a click as UseAction(); only drop/swap handlers
    -- below may consume it. This reduces rare failed swaps caused by mouse-up
    -- race conditions.
    if BF.InternalDragStartedAt and GetTime and (GetTime() - BF.InternalDragStartedAt) < 1.25 then
        if not BF.InternalDragSource and not BF:ButtonHasCursor() then
            return
        end
    end

    if IsShiftKeyDown and IsShiftKeyDown() and arg1 == "RightButton" then
        BF:ClearButton(this)
        return
    end

    -- Mouse-up after an internal drag. Finish a deterministic move/swap here as
    -- well, because some 1.12 clients do not fire OnReceiveDrag reliably between
    -- custom frames.
    if BF.InternalDragSource then
        BF:CompleteInternalDragDrop(this)
        BF:SuppressNextClick(this, 1.25)
        return
    end

    -- Empty slot: try PlaceAction even if Vanilla does not report the cursor.
    if (not this.actionSlot) or (not HasAction) or (not HasAction(this.actionSlot)) then
        BF:PlaceCursorOnButton(this)
        return
    end

    -- Only place when an action is actually on the cursor (including our
    -- internally tracked swapped cursor). Temporary grid alone must not turn a
    -- normal click into Pickup/PlaceAction; that caused unreliable one-time swaps.
    if BF:ButtonHasCursor() then
        BF:PlaceCursorOnButton(this)
    else
        BF:UseButton(this)
    end
end

function BF.Button_OnEnter()
    if BF:IsKeybindMode() then
        BF.KeybindTarget = this
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(BF:T("KEYBIND_MODE"))
        GameTooltip:AddLine(BF:T("KEYBIND_PRESS_KEY"), 1, 1, 1)
        GameTooltip:AddLine(BF:T("KEYBIND_MOUSE_HINT"), 0.8, 1, 0.8)
        GameTooltip:AddLine(BF:T("KEYBIND_CLEAR_HINT"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(BF:T("KEYBIND_EXIT_HINT"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    end

    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")

    if this.actionSlot and HasAction and HasAction(this.actionSlot) then
        -- Safe Vanilla tooltip path. SetAction exists on 1.12 clients and shows
        -- spells, items and macros from the backing action slot.
        local shown = false
        if GameTooltip.SetAction then
            GameTooltip:SetAction(this.actionSlot)
            shown = true
        end

        if not shown then
            GameTooltip:SetText("ButtonForge Classic")
            GameTooltip:AddLine("ActionSlot " .. tostring(this.actionSlot), 1, 1, 1)
        end
    else
        GameTooltip:SetText("Empty ButtonForge Classic Slot")
        GameTooltip:AddLine("Drag a spell, item or macro here.", 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Shift + Right Click: Clear Slot", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Pick up action", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function BF.Button_OnLeave()
    if BF.KeybindTarget == this then
        BF.KeybindTarget = nil
    end
    GameTooltip:Hide()
end


-- v0.2.7: conservative global refresh for count text.
-- This only calls RefreshButton on existing buttons and does not create, hide,
-- replace or reassign action slots.
function BF:RefreshAllButtons()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                if bar.buttons[j] then
                    self:RefreshButton(bar.buttons[j])
                end
            end
        end
    end
end

BF.CountFrame = CreateFrame("Frame")
BF.CountFrame.Elapsed = 0
BF.CountFrame:RegisterEvent("BAG_UPDATE")
BF.CountFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
BF.CountFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BF.CountFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BF.CountFrame:SetScript("OnEvent", function()
    BF:RefreshAllButtons()
    BF:RefreshAllHotkeys()
end)


-- Show empty drop targets whenever the cursor carries a spell, item or macro.
-- CURSOR_UPDATE is event-driven and works outside Configure Mode without a
-- permanent OnUpdate loop. This is especially important for macros on
-- Turtle/Vanilla, where CursorHasMacro() is unreliable but GetCursorInfo()
-- reports the cursor type correctly.
BF.CursorWatchFrame = CreateFrame("Frame")
BF.CursorWatchFrame:RegisterEvent("CURSOR_UPDATE")
BF.CursorWatchFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
BF.CursorWatchFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
BF.CursorWatchFrame:SetScript("OnEvent", function()
    if BF:IsConfigMode() or BF:IsKeybindMode() then
        return
    end

    -- Vanilla/Turtle fires ACTIONBAR_SHOWGRID reliably when dragging a spell,
    -- item or macro, even when CURSOR_UPDATE/GetCursorInfo is inconsistent.
    if event == "ACTIONBAR_SHOWGRID" then
        BF:StartTemporaryGrid(10)
        return
    elseif event == "ACTIONBAR_HIDEGRID" then
        if not BF.InternalDragSource and not BF:ButtonHasCursor() then
            BF:StopTemporaryGrid()
        end
        return
    end

    if BF:ButtonHasCursor() then
        BF:StartTemporaryGrid(10)
    elseif not BF.InternalDragSource then
        BF:StopTemporaryGrid()
    end
end)

function BF:RefreshAllButtonRanges()
    if not self.Bars then return end
    local i, j
    for i = 1, table.getn(self.Bars) do
        local bar = self.Bars[i]
        if bar and bar.buttons then
            for j = 1, table.getn(bar.buttons) do
                local button = bar.buttons[j]
                if button and button:IsShown() then
                    self:UpdateButtonRange(button)
                end
            end
        end
    end
end

-- Range updates need a light periodic check because distance can change without
-- a dedicated event.  Twenty checks per second makes the range and usability tint react quickly while remaining
-- inexpensive with the full 48-button Vanilla slot pool.
BF.RangeFrame = CreateFrame("Frame")
BF.RangeFrame.Elapsed = 0
BF.RangeFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
BF.RangeFrame:RegisterEvent("UNIT_FACTION")
BF.RangeFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
BF.RangeFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
BF.RangeFrame:RegisterEvent("SPELL_UPDATE_USABLE")
BF.RangeFrame:SetScript("OnEvent", function()
    BF:RefreshAllButtonRanges()
end)
BF.RangeFrame:SetScript("OnUpdate", function()
    this.Elapsed = (this.Elapsed or 0) + arg1
    if this.Elapsed < 0.05 then return end
    this.Elapsed = 0
    BF:RefreshAllButtonRanges()
end)

-- Temporary grid while dragging/swapping actions. This frame is hidden most of
-- the time and only wakes briefly after a drag starts, so it should not cost FPS.
BF.TempGridFrame = CreateFrame("Frame")
BF.TempGridFrame.Elapsed = 0
BF.TempGridFrame:Hide()
BF.TempGridFrame:SetScript("OnUpdate", function()
    this.Elapsed = (this.Elapsed or 0) + arg1
    if this.Elapsed < 0.25 then return end
    this.Elapsed = 0
    if (not BF.TempGridUntil) or (GetTime and GetTime() >= BF.TempGridUntil) then
        BF:StopTemporaryGrid()
    end
end)

-- Performance hotfix: no global OnUpdate refresh.
-- Turtle/Vanilla clients can stutter when we refresh all buttons repeatedly.
-- Counts now refresh only on events and after direct button changes.
