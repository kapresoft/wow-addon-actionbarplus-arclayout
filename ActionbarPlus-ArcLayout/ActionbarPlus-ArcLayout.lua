--[[-----------------------------------------------------------------------------
Local Vars
-------------------------------------------------------------------------------]]

local name, xns = ...

--- @type ABP_Core_2_0
local core = ABP_Core_2_0

if not core then return end

--- @type Namespace_ABP_2_0
local cns = core:ns()

--[[-----------------------------------------------------------------------------
Module::ArcLayout
Buttons are arranged along a 90-degree arc, from -45 to 45 degrees, opening
either up or down per this bar's arc config (arcDirection). Backdrop is not supported since
there's no rectangular frame edge to anchor to. Extra buttons form a second concentric
arc (see ApplyExtraButtons) instead of a rectangular row.

Registration
  Treated as an out-of-tree layout addon: self-registers with Core's layout
  registry instead of being wired in directly by BarModuleFactory.
-------------------------------------------------------------------------------]]

--- @see BarsUI_Modules_ABP_2_0
local libName, layoutName = name, 'arc'

--- @class ArcLayout_ABP_2_0 : BarLayout_ABP_2_0
local o = {}; cns:RegisterLayout(layoutName, o)

local p, t = cns:log(libName)

local DEFAULT_ARC_SPAN_DEGREES = 90
local MIN_ARC_SPAN_DEGREES, MAX_ARC_SPAN_DEGREES = 10, 180
local MAX_EXTRA_BUTTON_RINGS = 2
-- Bounds for extraButtonSpacing (this bar's arc config): clearance between adjacent extra
-- buttons within a ring. Chord-distance `size` alone (no spacing) has square-cornered
-- buttons touching/appearing to overlap; round icons hide this since their visible art
-- sits inset from the button's true edge -- different skins need different values.
local DEFAULT_EXTRA_BUTTON_SPACING = 6
local MIN_EXTRA_BUTTON_SPACING, MAX_EXTRA_BUTTON_SPACING = 0, 20

--[[-----------------------------------------------------------------------------
Masque
  Arc owns dedicated Masque groups (main and extra buttons), separate from
  ActionbarPlus-Masque's groups, so Arc's buttons carry their own skin
  independent of the rest of ActionbarPlus. Resolved lazily (not at this file's own
  load time) since neither Masque nor Core's AceDB is guaranteed ready yet here --
  OptionalDeps only orders files, not runtime addon-enabled/OnInitialize state.
-------------------------------------------------------------------------------]]
-- Backwards-compatible: falls back to the literal if an older ActionbarPlus-Core
-- (predating MasqueAddonName()) is installed alongside this addon.
local MASQUE_ADDON_NAME = (type(cns.MasqueAddonName) == 'function' and cns:MasqueAddonName())
  or 'ActionbarPlus'
-- Label is shown in Masque's Skins UI; the static ID keys the options panel
local MASQUE_GROUP_LABEL, MASQUE_GROUP_STATIC_ID = 'Buttons - Arc', 'Buttons_Arc'
local MASQUE_EXTRA_LABEL, MASQUE_EXTRA_STATIC_ID = 'Buttons - Arc (Extra)', 'Buttons_Arc_Extra'

--- @type Masque_Group?
local masqueGroup
--- @type Masque_Group?
local extraGroup

--- @param toggled Masque_Group
--- @param other Masque_Group
local function ForwardToggle(toggled, other)
  toggled:RegisterCallback(function(_, _, disabled)
    -- BarsUI re-renders so ActionbarPlus art isn't left stale
    core:SendMessage(cns:msg('OnMasqueGroupToggled'), disabled)
    if disabled then other:ReSkin() end
  end, 'Disabled')
end

--- Copies the skin only; backdrop, gloss, colors etc. stay per group
--- @param from Masque_Group
--- @param to Masque_Group
local function CopySkin(from, to)
  if to.db.SkinID == from.db.SkinID then return end
  to.db.SkinID = from.db.SkinID
  to:ReSkin()
end

-- An older ActionbarPlus has no masque table: sync on, nothing saved
--- @type MasqueConfig_ABP_2_0
local LEGACY_MASQUE_CONFIG = { syncExtraButtonsSkin = true, arcExtraSkinSeeded = false }

--- @return MasqueConfig_ABP_2_0
local function MasqueConfig()
  if cns.masque then return cns:masque() end
  return LEGACY_MASQUE_CONFIG
end

--- @param from Masque_Group
--- @param to Masque_Group
local function SyncSkinFrom(from, to)
  -- ReSkin doesn't notify, so syncing both ways can't loop
  from:RegisterCallback(function()
    if MasqueConfig().syncExtraButtonsSkin then CopySkin(from, to) end
  end, 'SkinID')
end

-- Once: extra buttons keep the skin they had under the Arc group
local function SeedExtraSkin()
  local mc = MasqueConfig()
  if mc.arcExtraSkinSeeded then return end
  mc.arcExtraSkinSeeded = true
  CopySkin(masqueGroup, extraGroup)
end

--- Created on first use: Masque may not be ready at load time.
local function CreateMasqueGroups()
  local Masque = LibStub('Masque')
  masqueGroup = Masque:Group(MASQUE_ADDON_NAME, MASQUE_GROUP_LABEL, MASQUE_GROUP_STATIC_ID)
  extraGroup = Masque:Group(MASQUE_ADDON_NAME, MASQUE_EXTRA_LABEL, MASQUE_EXTRA_STATIC_ID)
  ForwardToggle(masqueGroup, extraGroup)
  ForwardToggle(extraGroup, masqueGroup)
  SyncSkinFrom(masqueGroup, extraGroup)
  SyncSkinFrom(extraGroup, masqueGroup)
  SeedExtraSkin()
end

--- @return Masque_Group
local function GetMasqueGroup()
  if not masqueGroup then CreateMasqueGroups() end
  return masqueGroup
end

--- @return Masque_Group
local function GetExtraGroup()
  if not extraGroup then CreateMasqueGroups() end
  return extraGroup
end

local events = cns:NewAceEvent()

-- The extra group takes the Arc skin when sync turns on
events:RegisterMessage(cns:msg('OnSyncExtraButtonsSkinChanged'), function(_, enabled)
  if enabled then CopySkin(GetMasqueGroup(), GetExtraGroup()) end
end)

--- @param btn Button_ABP_2_0_X
--- @return Masque_Group
local function GroupOf(btn)
  if btn.widget.isExtraButton then return GetExtraGroup() end
  return GetMasqueGroup()
end

--- @param btn Button_ABP_2_0_X
local function MasqueAddButton(btn) GroupOf(btn):AddButton(btn) end

--- @param btn Button_ABP_2_0_X
local function MasqueReSkin(btn) GroupOf(btn):ReSkin(btn) end

--- @param frame BarFrame_ABP_2_0
--- @return ArcLayoutConfig_ABP_2_0
local function GetLayoutConfig(frame) return frame.widget:layoutConf().arc end

-- An older ActionbarPlus has no global settings: the flag stays per bar
--- @param frame BarFrame_ABP_2_0
--- @return boolean
local function IsDefaultSkinApplied(frame)
  if cns.masque then return cns:masque().arcDefaultSkinApplied end
  return GetLayoutConfig(frame).initialMasqueSkinApplied
end

--- @param frame BarFrame_ABP_2_0
local function MarkDefaultSkinApplied(frame)
  if cns.masque then
    cns:masque().arcDefaultSkinApplied = true
    return
  end
  GetLayoutConfig(frame).initialMasqueSkinApplied = true
end

-- Once for all Arc bars: Masque shares the skin across them. Runs when Arc
-- is picked, not at load time, when Masque may not be ready yet.
--- @param frame BarFrame_ABP_2_0
local function ApplyInitialMasqueSkin(frame)
  local ARC_DEFAULT_SKIN = 'Serenity - Redux'
  if IsDefaultSkinApplied(frame) then return end
  GetMasqueGroup():__Set('SkinID', ARC_DEFAULT_SKIN)
  GetExtraGroup():__Set('SkinID', ARC_DEFAULT_SKIN)
  MarkDefaultSkinApplied(frame)
end

-- A bar with the old per-bar flag means the default was applied before
local function AdoptPerBarFlag()
  if not cns.masque then return end
  local mc = cns:masque()
  if mc.arcDefaultSkinApplied then return end
  for _, bar in pairs(cns:p().bars) do
    if bar.ui.layoutConfig.arc.initialMasqueSkinApplied then
      mc.arcDefaultSkinApplied = true
      return
    end
  end
end

-- Bars are per profile, so each profile is checked as it becomes active
local function WatchProfiles()
  AdoptPerBarFlag()
  local db = cns:db()
  db.RegisterCallback(events, 'OnProfileChanged', AdoptPerBarFlag)
  db.RegisterCallback(events, 'OnProfileCopied', AdoptPerBarFlag)
end

if cns:IsDatabaseReady() then
  WatchProfiles()
else
  events:RegisterMessage(cns:msg('OnDatabaseReady'), WatchProfiles)
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
--- @return boolean
function o:SupportsBackdrop() return false end

--- @return boolean
function o:SupportsHorizontalSpacing() return true end

--- @return boolean
function o:SupportsVerticalSpacing() return false end

--- Extra buttons form a second concentric arc, sharing the main arc's center/span/direction.
--- TOP* anchors push the extra arc outward (radius + offset); BOTTOM* anchors pull it inward
--- (radius - offset, nested between the main arc and its center).
--- @param frame BarFrame_ABP_2_0
function o:ApplyExtraButtons(frame)
  local w = frame.widget
  local uic = w:conf().ui
  local eb = uic.extraButton
  if not eb or not eb.enabled then
    if w.extraButtons then
      for _, btn in ipairs(w.extraButtons) do
        btn:Hide()
      end
    end
    return
  end

  local geo = w.arcGeometry
  if not geo then return end

  local au = cns.O.ActionUtil
  local function CreateExtraButton(name, parent, encodedID)
    -- matches ns.buttonTemplate set in ActionbarPlus-BarsUI/Modules/Button_2_0_3.lua;
    -- referenced by name directly (rather than through BarsUI's namespace object) since
    -- this can run before Core has finished registering BarsUI into its own O table
    return CreateFrame('CheckButton', name, parent, cns:GetButtonTemplateName(), encodedID)
  end

  local anchor = eb.anchor or 'TOPRIGHT'
  local isOuter = anchor == 'TOP' or anchor == 'TOPLEFT' or anchor == 'TOPRIGHT'
  local size = eb.size or 30
  local count = eb.count or 1
  w.extraButtons = w.extraButtons or {}

  -- create any missing buttons
  for i = 1, count do
    if not w.extraButtons[i] then
      local encodedID = au.encodeBarID(w.index, 900 + i)
      local btnName = ('ABP_2_0_F%sExtraBtn%s'):format(w.index, i)
      local btn = CreateExtraButton(btnName, w.frame, encodedID)
      btn:SetClampedToScreen(true)
      btn.widget.isExtraButton = true
      w.extraButtons[i] = btn
    end
  end

  -- hide any buttons beyond the current count
  for i = count + 1, #w.extraButtons do
    w.extraButtons[i]:Hide()
  end

  -- eb.gap applies at every ring boundary: main arc -> ring 0, and ring 0 -> ring 1+.
  -- The main-arc radius is measured to main button centers, so clearing the main
  -- buttons' own edge needs half their size too, not just half the extra button's size.
  local extraSpacing = GetLayoutConfig(frame).extraButtonSpacing or DEFAULT_EXTRA_BUTTON_SPACING
  local mainButtonSize = uic.button.size or 0
  local firstRingStep = (mainButtonSize / 2) + (size / 2) + (eb.gap or 0)
  local ringStep = size + (eb.gap or 0)
  local baseRadius = isOuter and (geo.radius + firstRingStep)
    or math.max(0, geo.radius - firstRingStep)

  local function ringRadius(ring)
    -- ring 0 = baseRadius (main arc + gap); each ring beyond that adds one more
    -- button-width step off the previous ring, plus the same gap
    local offset = ring * ringStep
    return isOuter and (baseRadius + offset) or math.max(0, baseRadius - offset)
  end

  -- Angular step sized for the extra buttons' own size plus a configurable base spacing
  -- (extraButtonSpacing), evaluated at a specific ring's own radius -- a fixed step
  -- reused across rings would under-space inner rings (smaller radius -> smaller chord
  -- for the same angular step), which crunches buttons together as rings stack inward.
  -- Recomputing per ring keeps every ring's buttons a true `size + extraSpacing` apart
  -- regardless of how far its radius has grown/shrunk.
  local function stepForRing(ring)
    local r = ringRadius(ring)
    if r <= 0 then return 0 end
    local ratio = math.min(1, (size + extraSpacing) / (2 * r))
    return 2 * math.deg(math.asin(ratio))
  end

  -- Buttons per ring before wrapping to the next ring, capped to the main arc's span
  -- so a ring never extends past the main arc's edges.
  local function wrapCountForRing(ring)
    local step = stepForRing(ring)
    return step > 0 and (math.floor(geo.arcSpanDegrees / step) + 1) or count
  end

  -- Angle for extra button col (0-based) within a ring, depending on anchor:
  --  TOP: whole row centered on angle 0 (the arc's middle/peak), left-to-right reading order.
  --    col 0..n-1 -> centered spread, e.g. count=2 -> [-step/2, +step/2]
  --  TOPRIGHT/BOTTOMRIGHT: col 0 anchored at the main arc's right edge (+arcSpan/2), each
  --    subsequent col steps counter-clockwise (toward the left) from there.
  --  TOPLEFT/BOTTOMLEFT: col 0 anchored at the main arc's left edge (-arcSpan/2), each
  --    subsequent col steps clockwise (toward the right) from there.
  local function extraAngle(col, ringCount, stepDegrees)
    if anchor == 'TOPRIGHT' or anchor == 'BOTTOMRIGHT' then
      return geo.arcSpanDegrees / 2 - col * stepDegrees
    elseif anchor == 'TOPLEFT' or anchor == 'BOTTOMLEFT' then
      return -geo.arcSpanDegrees / 2 + col * stepDegrees
    end
    return (col - (ringCount - 1) / 2) * stepDegrees
  end

  -- Walk buttons ring-by-ring (rather than a flat index/wrapCount split) since each
  -- ring's own capacity now depends on its own radius. Capped at MAX_EXTRA_BUTTON_RINGS --
  -- once that many rings are full, any remaining count is simply not shown.
  local showEmpty = eb.showEmptyButtons ~= false
  local i = 1
  local ring = 0
  while i <= count and ring < MAX_EXTRA_BUTTON_RINGS do
    local stepDegrees = stepForRing(ring)
    local ringCapacity = wrapCountForRing(ring)
    local ringCount = math.min(ringCapacity, count - i + 1)
    local radius = ringRadius(ring)

    for col = 0, ringCount - 1 do
      local btn = w.extraButtons[i]
      btn:SetSize(size, size)
      MasqueAddButton(btn)
      MasqueReSkin(btn)
      btn:ClearAllPoints()

      local angle = extraAngle(col, ringCount, stepDegrees)
      local rad = math.rad(angle)
      local x = geo.centerX + radius * math.sin(rad)
      local y = geo.isDown and (geo.centerY - radius * math.cos(rad))
        or (geo.centerY + radius * math.cos(rad))

      btn:SetPoint('CENTER', frame, 'BOTTOMLEFT', x, y)
      btn:Show()
      if btn.widget then btn.widget:UpdateEmptyState(showEmpty) end

      i = i + 1
    end
    ring = ring + 1
  end

  -- hide any buttons beyond what MAX_EXTRA_BUTTON_RINGS could fit, even though they're
  -- within `count` -- otherwise leftover buttons from a previous render with more rings
  -- would stay visible at stale positions
  for j = i, count do
    if w.extraButtons[j] then w.extraButtons[j]:Hide() end
  end
end

--- @param frame BarFrame_ABP_2_0
--- @return number
function o:GetButtonCount(frame)
  local arcConf = GetLayoutConfig(frame)
  return math.min(arcConf.buttonCount or 9, self:GetMaxButtonCount())
end

--- @return number
function o:GetMaxButtonCount() return 13 end

--- @return number
function o:GetMinArcSpan() return MIN_ARC_SPAN_DEGREES end

--- @return number
function o:GetMaxArcSpan() return MAX_ARC_SPAN_DEGREES end

--- @return number
function o:GetMinExtraButtonSpacing() return MIN_EXTRA_BUTTON_SPACING end

--- @return number
function o:GetMaxExtraButtonSpacing() return MAX_EXTRA_BUTTON_SPACING end

--- @return string
function o:GetMasqueGroupKey() return MASQUE_ADDON_NAME .. '_' .. MASQUE_GROUP_STATIC_ID end

--- Called once whenever Arc is chosen for this bar from the Layout Type dropdown.
--- @param frame BarFrame_ABP_2_0
function o:OnSelected(frame) ApplyInitialMasqueSkin(frame) end

--- Adds Arc's own controls (Button Count, Arc Direction, Arc Span) to the Layout tab,
--- beyond the shared spacing sliders BarOptionsDialog.lua already builds generically.
--- @param frame BarFrame_ABP_2_0
--- @param tab AceGUITabGroup
--- @param onChanged fun()
function o:ApplyOptionsUI(frame, tab, onChanged)
  local AceGUI = cns:AceGUI()
  local L = cns:GetLocale()
  local arcConf = GetLayoutConfig(frame)

  local maxButtonCount = self:GetMaxButtonCount()
  if (arcConf.buttonCount or 9) > maxButtonCount then
    arcConf.buttonCount = maxButtonCount
    onChanged()
  end

  --- @type AceGUISlider
  local slButtonCount = AceGUI:Create('Slider')
  slButtonCount:SetLabel(L['Button Count'])
  slButtonCount:SetRelativeWidth(0.5)
  slButtonCount:SetSliderValues(1, maxButtonCount, 1)
  slButtonCount:SetValue(arcConf.buttonCount or 9)
  slButtonCount:SetCallback('OnValueChanged', function(_, _, val)
    arcConf.buttonCount = val
    onChanged()
  end)
  tab:AddChild(slButtonCount)

  --- @type AceGUIDropdown
  local ddArcDirection = AceGUI:Create('Dropdown')
  ddArcDirection:SetLabel(L['Arc Direction'])
  do
    local f, _, fl = ddArcDirection.label:GetFont()
    ddArcDirection.label:SetFont(f, 12, fl)
  end
  ddArcDirection:SetRelativeWidth(0.5)
  ddArcDirection:SetList({
    up = L['Up'],
    down = L['Down'],
  }, { 'up', 'down' })
  ddArcDirection:SetValue(arcConf.arcDirection or 'up')
  ddArcDirection:SetCallback('OnValueChanged', function(_, _, val)
    arcConf.arcDirection = val
    onChanged()
  end)
  tab:AddChild(ddArcDirection)

  --- @type AceGUISlider
  local slArcSpan = AceGUI:Create('Slider')
  slArcSpan:SetLabel(L['Arc Span'])
  slArcSpan:SetRelativeWidth(0.5)
  slArcSpan:SetSliderValues(self:GetMinArcSpan(), self:GetMaxArcSpan(), 1)
  slArcSpan:SetValue(arcConf.arcSpan or DEFAULT_ARC_SPAN_DEGREES)
  slArcSpan:SetCallback('OnValueChanged', function(_, _, val)
    arcConf.arcSpan = val
    onChanged()
  end)
  tab:AddChild(slArcSpan)

  --- @type AceGUISlider
  local slExtraButtonSpacing = AceGUI:Create('Slider')
  slExtraButtonSpacing:SetLabel(L['Extra Button Spacing'])
  slExtraButtonSpacing:SetRelativeWidth(0.5)
  slExtraButtonSpacing:SetSliderValues(
    self:GetMinExtraButtonSpacing(),
    self:GetMaxExtraButtonSpacing(),
    1
  )
  slExtraButtonSpacing:SetValue(arcConf.extraButtonSpacing or DEFAULT_EXTRA_BUTTON_SPACING)
  slExtraButtonSpacing:SetCallback('OnValueChanged', function(_, _, val)
    arcConf.extraButtonSpacing = val
    onChanged()
  end)
  tab:AddChild(slExtraButtonSpacing)
end

--- Sizes/positions the drag handle beside the first (TOPLEFT) or last (TOPRIGHT) button on the arc.
--- @param frame BarFrame_ABP_2_0
--- @param dragAnchor string 'TOPLEFT' | 'TOPRIGHT'
--- @param thickness number
function o:ApplyDragHandle(frame, dragAnchor, thickness)
  local w = frame.widget
  local btn1 = w.buttons and w.buttons[1]
  if not btn1 then return end

  local handle = w:GetOrCreateDragHandle()
  handle:ClearAllPoints()
  local btnSize = btn1:GetHeight()
  local heightPad = 6
  handle:SetHeight(btnSize - heightPad)
  handle:SetWidth(thickness)

  if dragAnchor == 'TOPRIGHT' then
    local lastBtn1 = w.buttons[self:GetButtonCount(frame)]
    handle:SetPoint('LEFT', lastBtn1, 'RIGHT', 3, 0)
    handle:SetPoint('CENTER', lastBtn1, 'CENTER', thickness, 0)
  else
    handle:SetPoint('RIGHT', btn1, 'LEFT', -3, 0)
    handle:SetPoint('CENTER', btn1, 'CENTER', -thickness, 0)
  end
end

--- @param frame BarFrame_ABP_2_0
function o:ApplyButtons(frame)
  local ui = frame.widget:conf().ui
  local count = self:GetButtonCount(frame)
  local size = ui.button.size
  local spacing = (ui.button.spacing and ui.button.spacing.horizontal) or 0
  local arcConf = GetLayoutConfig(frame)
  local isDown = arcConf.arcDirection == 'down'
  local arcSpanDegrees = arcConf.arcSpan or DEFAULT_ARC_SPAN_DEGREES
  local arcStartDegrees = -arcSpanDegrees / 2

  -- radius large enough that adjacent button centers are at least size+spacing apart
  -- (chord length = 2 * radius * sin(stepDegrees/2))
  local stepDegrees = count > 1 and (arcSpanDegrees / (count - 1)) or 0
  local minChord = size + spacing
  local minRadius = size
  local radius = stepDegrees > 0
      and math.max(minRadius, (minChord / 2) / math.sin(math.rad(stepDegrees / 2)))
    or minRadius

  local totalWidth = 2 * radius * math.sin(math.rad(arcSpanDegrees / 2)) + size
  local totalHeight = radius * (1 - math.cos(math.rad(arcSpanDegrees / 2))) + size
  frame:SetSize(totalWidth, totalHeight)

  local hotKeyFontSize = math.max(8, math.floor(size * 12 / 40))
  local hotKeyOffsetX = math.floor(size * 5 / 40)
  local hotKeyOffsetY = math.floor(size * 7 / 40)

  -- Circle center sits *outside* the frame (below it for an up-arc, above it for a
  -- down-arc) so the button positions -- at distance `radius` from the center -- land
  -- inside the frame rect: topmost button at totalHeight - size/2, edge buttons at size/2.
  local centerX = totalWidth / 2
  local centerY = isDown and (size / 2 + radius) or (totalHeight - size / 2 - radius)

  -- stashed for ApplyExtraButtons, which runs after Apply() but needs this same geometry
  -- to lay out a second concentric arc
  frame.widget.arcGeometry = {
    centerX = centerX,
    centerY = centerY,
    radius = radius,
    arcStartDegrees = arcStartDegrees,
    arcSpanDegrees = arcSpanDegrees,
    isDown = isDown,
    stepDegrees = stepDegrees,
  }

  for i, _btn in ipairs(frame.widget.buttons) do
    --- @type Button_ABP_2_0_X
    local btn = _btn

    btn:ClearAllPoints()
    if i <= count then
      btn:SetSize(size, size)
      MasqueAddButton(btn)
      MasqueReSkin(btn)
      btn.HotKey:SetFont(btn.HotKey:GetFont(), hotKeyFontSize, 'OUTLINE')
      btn.HotKey:ClearAllPoints()
      btn.HotKey:SetPoint('TOPRIGHT', btn, 'TOPRIGHT', -hotKeyOffsetX, -hotKeyOffsetY)

      local angle = arcStartDegrees + stepDegrees * (i - 1)
      local rad = math.rad(angle)
      local x = centerX + radius * math.sin(rad)
      local y = isDown and (centerY - radius * math.cos(rad)) or (centerY + radius * math.cos(rad))

      btn:SetPoint('CENTER', frame, 'BOTTOMLEFT', x, y)
      btn:Show()
      btn.widget:UpdateEmptyState(ui.showEmptyButtons)
    else
      btn:Hide()
    end
  end
end
