local Keys_List = {"","Shift","Ctrl","Alt","Alt-Shift","Ctrl-Shift"}
local Mouse_List = {"Left","Right","Middle","Button4","Button5","Button6","Button7","Button8","Button9","Button10"}

local mouseButton = 1

local phConfig = CreateFrame("Frame","PartyHealer_Config", UIParent)
phConfig:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
phConfig:SetScript("OnShow", function(self) self:OnShow() end)

local menu = X_MenuClass:New()

local function escapeEditBox(self)
	self:SetAutoFocus(false)
end

local function saveSettings(self)
	phConfig:SaveSettings(true)
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

local function Slider_OnMouseWheel(self, arg1)
	local step = self:GetValueStep() * arg1
	local value = self:GetValue()
	local minVal, maxVal = self:GetMinMaxValues()

	if step > 0 then
		self:SetValue(min(value+step, maxVal))
	else
		self:SetValue(max(value+step, minVal))
	end
end

local function CreateSlider(text, parent, low, high, step)
	local name = parent:GetName() .. text
	local slider = CreateFrame('Slider', name, parent, 'OptionsSliderTemplate')
	slider:SetScript('OnMouseWheel', Slider_OnMouseWheel)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	slider:EnableMouseWheel(true)
	BlizzardOptionsPanel_Slider_Enable(slider) --colors the slider properly

	getglobal(name .. 'Text'):SetText(text)
	getglobal(name .. 'Low'):SetText('')
	getglobal(name .. 'High'):SetText('')

	local text = slider:CreateFontString(nil, 'BACKGROUND')
	text:SetFontObject('GameFontHighlightSmall')
	text:SetPoint('LEFT', slider, 'RIGHT', 7, 0)
	slider.valText = text

	return slider
end

--MAIN FRAME
-----------------------------

phConfig:SetFrameStrata("HIGH")
phConfig:SetToplevel(true)
phConfig:EnableMouse(true)
phConfig:SetMovable(true)
phConfig:SetClampedToScreen(true)
phConfig:SetWidth(365)
phConfig:SetHeight(480)

phConfig:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 32,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
})

phConfig:SetBackdropColor(0,0,0,1)
phConfig:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

phConfig.MOUSEBUTN = phConfig:CreateFontString(nil, "ARTWORK", "GameFontNormal")
phConfig.MOUSEBUTN:SetPoint("BOTTOMLEFT", phConfig, "TOPLEFT", 25, -40)
phConfig.MOUSEBUTN:SetText("|cFFFFFFFFMouse Button:|r |cFF99CC33LEFT|r")

local closeButton = CreateFrame("Button", nil, phConfig, "UIPanelCloseButton");
closeButton:SetPoint("TOPRIGHT", phConfig, -15, -8);

phConfig.MOUSEMENU = CreateFrame("Button", nil, phConfig, "UIPanelButtonTemplate");
phConfig.MOUSEMENU:SetPoint("BOTTOMLEFT", phConfig, "TOPLEFT", 230, -65)
phConfig.MOUSEMENU:SetHeight(21);
phConfig.MOUSEMENU:SetWidth(120);
phConfig.MOUSEMENU:SetText("Mouse Button");
phConfig.MOUSEMENU:SetScript("OnClick", function() menu:Show() end)

phConfig.NORMAL = createEditBox("$parentEdit1", "Normal Click:", phConfig, 60, -80)
phConfig.SHIFT = createEditBox("$parentEdit2", "Shift:", phConfig, 60, -140)
phConfig.CTRL = createEditBox("$parentEdit3", "Ctrl", phConfig, 60, -200)
phConfig.ALT = createEditBox("$parentEdit4", "Alt", phConfig, 60, -260)
phConfig.ALTSHIFT = createEditBox("$parentEdit5", "Alt+Shift", phConfig, 60, -320)
phConfig.CTRLSHIFT = createEditBox("$parentEdit6", "Ctrl+Shift", phConfig, 60, -380)

phConfig.saveButton = CreateFrame("Button", nil, phConfig, "UIPanelButtonTemplate");
phConfig.saveButton:SetPoint("BOTTOM", phConfig, "BOTTOM", 110, 30);
phConfig.saveButton:SetHeight(21);
phConfig.saveButton:SetWidth(100);
phConfig.saveButton:SetText("Save");
phConfig.saveButton:SetScript("OnClick", function() phConfig:SaveSettings() end)

phConfig.buffButton = CreateFrame("Button", nil, phConfig, "UIPanelButtonTemplate");
phConfig.buffButton:SetPoint("BOTTOM", phConfig, "BOTTOM", -90, 30);
phConfig.buffButton:SetHeight(21);
phConfig.buffButton:SetWidth(135);
phConfig.buffButton:SetText("Buff Detector");
phConfig.buffButton:SetScript("OnClick", function()
	if PartyHealer_ConfigBuff:IsVisible() then
		PartyHealer_ConfigBuff:Hide()
	else
		PartyHealer_ConfigBuff:Show()
	end
end)

phConfig:SetScript("OnMouseDown", function(frame, button)
	if frame:IsMovable() then
		frame.isMoving = true
		frame:StartMoving()
	end
end)

phConfig:SetScript("OnMouseUp", function(frame, button) 
	if( frame.isMoving ) then
		frame.isMoving = nil
		frame:StopMovingOrSizing()
		PartyHealer:SaveLayout(frame:GetName())
	end
end)

----SIDE CONFIG FRAME
---------------------------
---------------------------
---------------------------
	local phConfigOpt = CreateFrame("Frame","PartyHealer_ConfigOpt", phConfig)

	phConfigOpt:SetFrameStrata("HIGH")
	phConfigOpt:SetToplevel(true)
	phConfigOpt:EnableMouse(true)
	phConfigOpt:SetMovable(true)
	phConfigOpt:SetClampedToScreen(true)
	phConfigOpt:SetWidth(250)
	phConfigOpt:SetHeight(350)

	phConfigOpt:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 32,
			insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	phConfigOpt:SetBackdropColor(0,0,0,1)
	phConfigOpt:ClearAllPoints()
	phConfigOpt:SetPoint("TOPRIGHT", phConfig, "TOPLEFT", 0, 0)
	phConfigOpt:Show()

	--SCALE SLIDER
	-----------------------------
	phConfigOpt.ScaleSlider = CreateSlider("PartyHealer Scale", phConfigOpt, 0.001, 2, 0.05)
	phConfigOpt.ScaleSlider:SetScript('OnShow', function(self)
		self.onShow = true
		self:SetValue(PH_DB.Scale or 1)
		self.onShow = nil
	end)
	phConfigOpt.ScaleSlider:SetScript('OnValueChanged', function(self, value)
		--self.valText:SetText(floor(value * 100 + 0.5) .. '%')
		self.valText:SetText(string.format("%.2f", value))
		if not self.onShow then
			if PH_DB then PH_DB.Scale = value end
			if PartyHealer then PartyHealer:SetButtonScale() end
		end
	end)
	phConfigOpt.ScaleSlider:SetPoint('TOP', phConfigOpt, 'TOP', -10, -40)
	-----------------------------
	
	--ALPHA SLIDER
	-----------------------------
	phConfigOpt.AlphaSlider = CreateSlider("PartyHealer Alpha", phConfigOpt, 0, 1, 0.1)
	phConfigOpt.AlphaSlider:SetScript('OnShow', function(self)
		self.onShow = true
		self:SetValue(PH_DB.Alpha or 1)
		self.onShow = nil
	end)
	phConfigOpt.AlphaSlider:SetScript('OnValueChanged', function(self, value)
		--self.valText:SetText(floor(value * 100 + 0.5) .. '%')
		self.valText:SetText(string.format("%.2f", value))
		if not self.onShow then
			if PH_DB then PH_DB.Alpha = value end
			if PartyHealer then PartyHealer:SetButtonAlpha() end
		end
	end)
	phConfigOpt.AlphaSlider:SetPoint('TOP', phConfigOpt, 'TOP', -10, -80)
	-----------------------------

	--BAR WIDTH
	-----------------------------
	phConfigOpt.bWidthSlider = CreateSlider("Unit Bar Width", phConfigOpt, 1, 700, 1)
	phConfigOpt.bWidthSlider:SetScript('OnShow', function(self)
		self.onShow = true
		self:SetValue(PH_DB.BarWidth or 1)
		self.onShow = nil
	end)
	phConfigOpt.bWidthSlider:SetScript('OnValueChanged', function(self, value)
		--self.valText:SetText(floor(value * 100 + 0.5) .. '%')
		self.valText:SetText(value)
		if not self.onShow then
			if PH_DB then PH_DB.BarWidth = value end
			if PartyHealer then PartyHealer:SetBarSize() end
		end
	end)
	phConfigOpt.bWidthSlider:SetPoint('TOP', phConfigOpt, 'TOP', -10, -120)
	-----------------------------
	
	--BAR HEIGHT
	-----------------------------
	phConfigOpt.bHeightSlider = CreateSlider("Unit Bar Height", phConfigOpt, 1, 700, 1)
	phConfigOpt.bHeightSlider:SetScript('OnShow', function(self)
		self.onShow = true
		self:SetValue(PH_DB.BarHeight or 1)
		self.onShow = nil
	end)
	phConfigOpt.bHeightSlider:SetScript('OnValueChanged', function(self, value)
		--self.valText:SetText(floor(value * 100 + 0.5) .. '%')
		self.valText:SetText(value)
		if not self.onShow then
			if PH_DB then PH_DB.BarHeight = value end
			if PartyHealer then PartyHealer:SetBarSize() end
		end
	end)
	phConfigOpt.bHeightSlider:SetPoint('TOP', phConfigOpt, 'TOP', -10, -160)
	-----------------------------
	
	
	local bgChk = LibStub("tekKonfig-Checkbox").new(phConfigOpt, nil, "Show in Battleground", "TOP", phConfigOpt, "TOP", -80, -200)
	local checksound = bgChk:GetScript("OnClick")
	bgChk:SetScript("OnClick", function(self) checksound(self); PH_DB.showBG = not PH_DB.showBG end)
	bgChk:SetScript('OnShow', function(self)
		self:SetChecked(PH_DB.showBG)
	end)
	local arenaChk = LibStub("tekKonfig-Checkbox").new(phConfigOpt, nil, "Show in Arena", "TOP", phConfigOpt, "TOP", -80, -230)
	arenaChk:SetScript("OnClick", function(self) checksound(self); PH_DB.showArena = not PH_DB.showArena end)
	arenaChk:SetScript('OnShow', function(self)
		self:SetChecked(PH_DB.showArena)
	end)
	local raidChk = LibStub("tekKonfig-Checkbox").new(phConfigOpt, nil, "Show in Raid", "TOP", phConfigOpt, "TOP", -80, -260)
	raidChk:SetScript("OnClick", function(self) checksound(self); PH_DB.showRaid = not PH_DB.showRaid end)
	raidChk:SetScript('OnShow', function(self)
		self:SetChecked(PH_DB.showRaid)
	end)

	phConfigOpt:SetScript("OnMouseDown", function(frame, button)
		if frame:GetParent():IsMovable() then
			frame:GetParent().isMoving = true
			frame:GetParent():StartMoving()
		end
	end)

	phConfigOpt:SetScript("OnMouseUp", function(frame, button) 
		if( frame:GetParent().isMoving ) then
			frame:GetParent().isMoving = nil
			frame:GetParent():StopMovingOrSizing()
			PartyHealer:SaveLayout(frame:GetParent():GetName())
		end
	end)


---------------------------
---------------------------
---------------------------

phConfig:Hide()

function phConfig:PLAYER_LOGIN()
	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
	
	--do the mouse menu
	for y=1, getn(Mouse_List), 1 do
		if Mouse_List[y] then
			menu:AddItem(Mouse_List[y], function()
				local mb = y
				self:switchMouse(mb)
			end)
		end
	end
	menu:AddItem(' ', function()  end)
	menu:AddItem('Close', function()  end)
	
end

function phConfig:OnShow()
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		phConfig:Hide()
		return
	end
	
	PartyHealer:RestoreLayout("PartyHealer_Config")
	
	mouseButton = 1 --reset to start on left-click display
	phConfig:DoDisplay()		
end

function phConfig:DoDisplay()
	if PH_DB and PH_DB.spells then
		for y=1, getn(Keys_List), 1 do
			if getglobal("PartyHealer_ConfigEdit"..y) then
				if PH_DB.spells[mouseButton] and PH_DB.spells[mouseButton][y] then
					getglobal("PartyHealer_ConfigEdit"..y):SetText(PH_DB.spells[mouseButton][y])
				else
					getglobal("PartyHealer_ConfigEdit"..y):SetText("")
				end
			end
		end
	end	
end

function phConfig:switchMouse(mouseNum)
	if not mouseNum then return end
	
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		return
	end
	
	--save our current content on the screen, without closing the window
	phConfig:SaveSettings(true)
	--change the mouse number
	mouseButton = mouseNum
	--update mouse button text
	phConfig.MOUSEBUTN:SetText("|cFFFFFFFFMouse Button:|r |cFF99CC33"..Mouse_List[mouseButton].."|r")
	--display mouse data on the screen
	phConfig:DoDisplay()
	
end

function phConfig:SaveSettings(sSwitch)
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("PartyHealer: You cannot edit these settings while in combat!")
		phConfig:Hide()
		return
	end

	for y=1, getn(Keys_List), 1 do
		if getglobal("PartyHealer_ConfigEdit"..y) then
			local spellName = getglobal("PartyHealer_ConfigEdit"..y):GetText()
			if spellName and strlen(spellName) > 0 then
				if not PH_DB.spells[mouseButton] then PH_DB.spells[mouseButton] = {} end
				PH_DB.spells[mouseButton][y] = spellName
			else
				if PH_DB.spells[mouseButton] then
					PH_DB.spells[mouseButton][y] = nil
				end
			end
		end
	end
	
	-- delete empty entries
	-- for x=1, getn(Mouse_List), 1 do
		--new function "table.maxn" that finds the maximum numeric entry, in case you have a table with holes in it.
		-- if PH_DB.spells[x] and table.maxn(PH_DB.spells[x]) <= 0 then
			-- PH_DB.spells[x] = nil
		-- end
	-- end
	
	--reassign the button spells
	if PartyHealer then
		for i=0,4 do
			local button
			if i == 0 then
				--player
				button = PH_PlayerButton
			else
				button = getglobal("PH_Party"..i.."Button")
			end
			 PartyHealer:SetButtonSpells(button)
		end
	end
	
	if not sSwitch then
		print("PartyHealer: Settings have been saved!")
		if PartyHealer then PartyHealer:UpdateFrames() end
		phConfig:Hide()
	end
end

if IsLoggedIn() then phConfig:PLAYER_LOGIN() else phConfig:RegisterEvent("PLAYER_LOGIN") end