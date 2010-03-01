PH_CB = {}

local min = math.min
local GetTime = _G['GetTime']
local frames_PHCB = {}

function PH_CB:New(parent)

	local fcb = CreateFrame('Frame', parent:GetName() .. 'Cast', parent)
	fcb:SetScript('OnShow', self.Update)
	fcb:SetScript('OnUpdate', function(self, elapsed) PH_CB:OnUpdate(self, elapsed) end)

	fcb:SetWidth(180)
	fcb:SetHeight(15)
	
	local icon = fcb:CreateTexture(fcb:GetName() .. 'Icon', 'ARTWORK')
	icon:SetPoint('BOTTOMLEFT', fcb)
	icon:SetHeight(15)
	icon:SetWidth(15)
	icon:SetTexture("Interface\\Icons\\Spell_Shadow_Shadowbolt")
	icon:Show()
	fcb.icon = icon
	
	local bar = CreateFrame("StatusBar", nil, fcb)
	bar:SetPoint('BOTTOMLEFT', icon, 'BOTTOMRIGHT')
	bar:SetPoint('BOTTOMRIGHT', fcb)
	bar:SetScript('OnUpdate', function(self, elapsed) PH_CB:OnUpdate(self, elapsed) end)
	bar:SetWidth(180)
	bar:SetHeight(15)
	bar:SetStatusBarTexture("Interface\\AddOns\\PartyHealer\\textures\\statusbar")
	bar:Show()
	fcb.bar = bar

	local barbg = CreateFrame("StatusBar", nil, fcb)
	barbg:SetMinMaxValues(0, 1)
	barbg:SetValue(1)
	barbg:SetAllPoints(bar)
	barbg:SetWidth(180)
	barbg:SetHeight(15)
	barbg:SetStatusBarTexture("Interface\\AddOns\\PartyHealer\\textures\\statusbar")
	barbg:Show()
	fcb.bg = barbg
	
	local text = bar:CreateFontString(nil, "OVERLAY")
	text:SetFont("Interface\\AddOns\\PartyHealer\\fonts\\barframes.ttf", 11);
	text:SetJustifyH("LEFT")
	text:SetJustifyV("CENTER")
	text:SetPoint('BOTTOMLEFT', icon, 'BOTTOMRIGHT')
	text:SetWordWrap(false)
	text:SetWidth(bar:GetWidth()-10)
	fcb.text = text

	table.insert(frames_PHCB, fcb)
	
	PH_CB:UpdateUnit("player", fcb)

	return fcb
end

function PH_CB:UpdateUnit(newUnit, frm)
	local newUnit = newUnit or frm:GetParent():GetAttribute('unit')
	if frm.unit ~= newUnit then
		frm.unit = newUnit
		PH_CB:Update(frm)
	end
end

function PH_CB:Update(frm)
	if not frm then frm = self end
	if frm.unit then
		if UnitCastingInfo(frm.unit) then
			PH_CB:OnSpellStart(frm)
		elseif UnitChannelInfo(frm.unit) then
			PH_CB:OnChannelStart(frm)
		else
			PH_CB:Finish(frm)
		end
	end
end

function PH_CB:OnUpdate(frm, elapsed)
	if frm.casting then
		local value = min(GetTime(), frm.maxValue)

		if value == frm.maxValue then
			PH_CB:Finish(frm)
		else
			frm.bar:SetValue(value)
		end
	elseif frm.channeling then
		local value = min(GetTime(), frm.endTime)

		if value == frm.endTime then
			PH_CB:Finish(frm)
		else
			frm.bar:SetValue(frm.startTime + (frm.endTime - value))
		end
	end
end

--[[ Event Functions ]]--

function PH_CB:OnSpellStart(frm)
	if not frm then frm = self end
	local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(frm.unit)
	if not(name) or isTradeSkill then
		frm:Hide()
		return
	end
	if not frm:GetParent().showcastbar then
		frm:Hide()
		return
	end

	frm.bar:SetStatusBarColor(0, 1, 1, 0.8)
	frm.bg:SetStatusBarColor(0, 1, 1, 0.3)
	
	frm.startTime = startTime / 1000
	frm.maxValue = endTime / 1000

	frm.bar:SetMinMaxValues(frm.startTime, frm.maxValue)
	frm.bar:SetValue(frm.startTime)

	frm.icon:SetTexture(texture)

	frm.text:SetText(name)

	frm.casting = true
	frm.channeling = nil
	frm:Show()
end

function PH_CB:OnSpellDelayed(frm)
	if not frm then frm = self end
	if frm:IsVisible() then
		local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(frm.unit)
		if not(name) or isTradeSkill then
			frm:Hide()
			return
		end

		frm.startTime = startTime / 1000
		frm.maxValue = endTime / 1000

		frm.bar:SetMinMaxValues(frm.startTime, frm.maxValue)

		if not frm.casting then
			frm.bar:SetStatusBarColor(1, 0.7, 0, 0.8)
			frm.bg:SetStatusBarColor(1, 0.7, 0, 0.3)
			frm.casting = true
			frm.channeling = nil
		end
	end
end

function PH_CB:OnChannelStart(frm)
	if not frm then frm = self end
	local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitChannelInfo(frm.unit)
	if not(name) or isTradeSkill then
		frm:Hide()
		return
	end

	if not frm:GetParent().showcastbar then
		frm:Hide()
		return
	end
	
	frm.bar:SetStatusBarColor(0, 1, 1, 0.8)
	frm.bg:SetStatusBarColor(0, 1, 1, 0.3)

	frm.startTime = startTime / 1000
	frm.endTime = endTime / 1000
	frm.duration = frm.endTime - frm.startTime
	frm.maxValue = frm.startTime

	frm.bar:SetMinMaxValues(frm.startTime, frm.endTime)
	frm.bar:SetValue(frm.endTime)
	
	frm.icon:SetTexture(texture)

	frm.text:SetText(name)

	frm.casting = nil
	frm.channeling = true
	frm:Show()
end

function PH_CB:OnChannelUpdate(frm)
	if not frm then frm = self end
	if frm:IsVisible() then
		local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitChannelInfo(frm.unit)
		if not(name) or isTradeSkill then
			frm:Hide()
			return
		end

		frm.startTime = startTime / 1000
		frm.endTime = endTime / 1000
		frm.maxValue = self.startTime
		frm.bar:SetMinMaxValues(frm.startTime, frm.endTime)
	end
end

function PH_CB:OnSpellStop(frm)
	if not frm then frm = self end
	if not frm.channeling then
		PH_CB:Finish(frm)
	end
end

function PH_CB:Finish(frm)
	if not frm then frm = self end
	frm.casting = nil
	frm.channeling = nil
	frm.bar:SetStatusBarColor(0, 0, 0, 0.8)
	frm.bg:SetStatusBarColor(0, 0, 0, 0.3)
	frm:Hide()
end


--[[ Utility Functions ]]--

function PH_CB:ForVisibleUnit(unit, method, ...)

	for _,frm in pairs(frames_PHCB) do
		if frm.unit == unit and frm:GetParent():IsVisible() then
			PH_CB[method](frm, ...)
		end
	end
end

function PH_CB:ForAllVisible(method, ...)
	for _,frm in pairs(frames_PHCB) do
		if frm:GetParent():IsVisible() then
			PH_CB[method](frm, ...)
		end
	end
end

--[[ Events ]]--

do
	local f_PHCB = CreateFrame('Frame')
	f_PHCB:SetScript('OnEvent', function(self, event, unit)
		if event == 'UNIT_SPELLCAST_START' then
			PH_CB:ForVisibleUnit(unit, 'OnSpellStart')
		elseif event == 'UNIT_SPELLCAST_DELAYED' then
			PH_CB:ForVisibleUnit(unit, 'OnSpellDelayed')
		elseif event == 'UNIT_SPELLCAST_CHANNEL_START' then
			PH_CB:ForVisibleUnit(unit, 'OnChannelStart')
		elseif event == 'UNIT_SPELLCAST_CHANNEL_UPDATE' then
			PH_CB:ForVisibleUnit(unit, 'OnChannelUpdate')
		elseif event == 'UNIT_SPELLCAST_STOP' then
			PH_CB:ForVisibleUnit(unit, 'OnSpellStop')
		elseif event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_INTERRUPTED' or event == 'UNIT_SPELLCAST_CHANNEL_STOP' then
			PH_CB:ForVisibleUnit(unit, 'Finish')
		elseif event == 'PLAYER_ENTERING_WORLD' then
			PH_CB:ForAllVisible('Update')
		end
	end)

	f_PHCB:RegisterEvent('PLAYER_ENTERING_WORLD')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_START')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_DELAYED')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_CHANNEL_START')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_CHANNEL_UPDATE')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_STOP')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_FAILED')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_INTERRUPTED')
	f_PHCB:RegisterEvent('UNIT_SPELLCAST_CHANNEL_STOP')
end