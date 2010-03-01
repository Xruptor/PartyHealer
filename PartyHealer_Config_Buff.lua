local phConfigBuff = CreateFrame("Frame","PartyHealer_ConfigBuff", PartyHealer_Config)
phConfigBuff:SetScript("OnShow", function(self) self:OnShow() end)

local function escapeEditBox(self)
	self:SetAutoFocus(false)
end

local function saveSettings(self)
	phConfigBuff:SaveSettings()
	self:ClearFocus()
end

local function createEditBox(name, labeltext, obj, x, y)
	local editbox = CreateFrame("EditBox", name, obj, "InputBoxTemplate")
	editbox:SetAutoFocus(false)
	editbox:SetWidth(250)
	editbox:SetHeight(16)
	editbox:SetPoint("TOPLEFT", obj, "TOPLEFT", x or 0, y or 0)
	local label = editbox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("BOTTOMLEFT", editbox, "TOPLEFT", -6, 4)
	label:SetText(labeltext)
	editbox:SetScript("OnEnterPressed", saveSettings)
	editbox:HookScript("OnEscapePressed", escapeEditBox)
	return editbox
end

local function createBoxText(color, obj, obj2, x, y)
	local label = obj:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("BOTTOMLEFT", obj2, "TOPLEFT", x, y)
	label:SetJustifyH('LEFT')
	label:SetFont("Interface\\AddOns\\PartyHealer\\fonts\\squares.ttf", 6, "THINOUTLINE")
	label:SetText("|cFF"..color.."M|r")
	return label
end

phConfigBuff:SetFrameStrata("HIGH")
phConfigBuff:SetToplevel(true)
phConfigBuff:EnableMouse(true)
phConfigBuff:SetMovable(false)
phConfigBuff:SetClampedToScreen(true)
phConfigBuff:SetWidth(365)
phConfigBuff:SetHeight(480)

phConfigBuff:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 32,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
})
phConfigBuff:SetBackdropColor(0,0,0,1)
phConfigBuff:SetPoint("CENTER", PartyHealer_Config, "RIGHT", (PartyHealer_Config:GetWidth() / 2), 0)

phConfigBuff.TITLE = phConfigBuff:CreateFontString(nil, "ARTWORK", "GameFontNormal")
phConfigBuff.TITLE:SetPoint("BOTTOMLEFT", phConfigBuff, "TOPLEFT", 25, -40)
phConfigBuff.TITLE:SetText("|cFFFFFFFFBuff Detector Configuration:|r")

phConfigBuff.BUFF1 = createEditBox("$parentEdit1", "Buff 1:", phConfigBuff, 60, -80)
phConfigBuff.BUFF2 = createEditBox("$parentEdit2", "Buff 2:", phConfigBuff, 60, -140)
phConfigBuff.BUFF3 = createEditBox("$parentEdit3", "Buff 3:", phConfigBuff, 60, -200)
phConfigBuff.BUFF4 = createEditBox("$parentEdit4", "Buff 4:", phConfigBuff, 60, -260)
phConfigBuff.BUFF5 = createEditBox("$parentEdit5", "Buff 5:", phConfigBuff, 60, -320)
phConfigBuff.BUFF6 = createEditBox("$parentEdit6", "Buff 6:", phConfigBuff, 60, -380)

phConfigBuff.BUFF1_T = createBoxText("FF0000", phConfigBuff, phConfigBuff.BUFF1, -16, 7)
phConfigBuff.BUFF2_T = createBoxText("00FF00", phConfigBuff, phConfigBuff.BUFF2, -16, 7)
phConfigBuff.BUFF3_T = createBoxText("0000FF", phConfigBuff, phConfigBuff.BUFF3, -16, 7)
phConfigBuff.BUFF4_T = createBoxText("FF99CC", phConfigBuff, phConfigBuff.BUFF4, -16, 7)
phConfigBuff.BUFF5_T = createBoxText("FF9900", phConfigBuff, phConfigBuff.BUFF5, -16, 7)
phConfigBuff.BUFF6_T = createBoxText("00FFFF", phConfigBuff, phConfigBuff.BUFF6, -16, 7)

phConfigBuff.saveButton = CreateFrame("Button", nil, phConfigBuff, "UIPanelButtonTemplate");
phConfigBuff.saveButton:SetPoint("BOTTOM", phConfigBuff, "BOTTOM", 0, 30);
phConfigBuff.saveButton:SetHeight(21);
phConfigBuff.saveButton:SetWidth(100);
phConfigBuff.saveButton:SetText("Save");
phConfigBuff.saveButton:SetScript("OnClick", function() phConfigBuff:SaveSettings() end)

phConfigBuff:Hide()

function phConfigBuff:OnShow()
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		phConfigBuff:Hide()
		return
	end
	phConfigBuff:DoDisplay()		
end

function phConfigBuff:DoDisplay()
	if PH_DB.buffs then
		for k, v in pairs(PH_DB.buffs) do
			if getglobal("PartyHealer_ConfigBuffEdit"..v) then
				getglobal("PartyHealer_ConfigBuffEdit"..v):SetText(k)
			end
		end
	end
end

function phConfigBuff:SaveSettings(sSwitch)
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		return
	end
	if not phConfigBuff:IsVisible() then return end
	
	local toDel = {}
	
	for y=1, 6 do
		if getglobal("PartyHealer_ConfigBuffEdit"..y) then
			local buffName = getglobal("PartyHealer_ConfigBuffEdit"..y):GetText()
			if strlen(buffName) > 0 then
				buffName = string.lower(buffName)
				if not PH_DB.buffs then PH_DB.buffs = {} end
				PH_DB.buffs[buffName] = y
			else
				toDel[y] = true
			end
		end
	end

	--delete extra crap
	if PH_DB.buffs then
		for k, v in pairs(PH_DB.buffs) do
			if toDel[v] then
				PH_DB.buffs[k] = nil
			end
		end
	end
	
	--reassign the buffs
	if PartyHealer then
		for i=0,4 do
			local button
			if i == 0 then
				--player
				button = PH_PlayerButton
			else
				button = getglobal("PH_Party"..i.."Button")
			end
			 PartyHealer:UpdateBuffs(button, button.unit)
		end
	end
	
	phConfigBuff:Hide()
	print("PartyHealer: Custom Buff Detection Saved!")
end
