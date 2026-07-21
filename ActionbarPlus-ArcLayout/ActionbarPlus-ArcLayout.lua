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
either up or down per ui.arcDirection. Backdrop/extra-buttons are not supported
since there's no rectangular frame edge for either to anchor to.

Registration
  Treated as an out-of-tree layout addon: self-registers with Core's layout
  registry instead of being wired in directly by BarModuleFactory.
-------------------------------------------------------------------------------]]

--- @see BarsUI_Modules_ABP_2_0
local libName, layoutName = name, 'arc'

--- @class ArcLayout_ABP_2_0 : BarLayout_ABP_2_0
local o = {}; cns:RegisterLayout(layoutName, o)

local p, t = cns:log(libName)

local ARC_SPAN_DEGREES = 90
local ARC_START_DEGREES = -45

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
--- @return boolean
function o:SupportsBackdrop() return false end

--- @return boolean
function o:SupportsHorizontalSpacing() return true end

--- @return boolean
function o:SupportsVerticalSpacing() return false end

--- @param frame BarFrame_ABP_2_0
function o:ApplyExtraButtons(frame)
  -- extra buttons anchor to a rectangular grid edge, which this layout doesn't have
  local extraButtons = frame.widget.extraButtons
  if not extraButtons then return end
  for _, btn in ipairs(extraButtons) do btn:Hide() end
end

--- @param ui BarUIConfig_ABP_2_0
--- @return number
function o:GetButtonCount(ui) return ui.buttonCount or 9 end

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
  local btnSize   = btn1:GetHeight()
  local heightPad = 6
  handle:SetHeight(btnSize - heightPad)
  handle:SetWidth(thickness)

  if dragAnchor == 'TOPRIGHT' then
    local ui = w:conf().ui
    local lastBtn1 = w.buttons[self:GetButtonCount(ui)]
    handle:SetPoint('LEFT', lastBtn1, 'RIGHT', 3, 0)
    handle:SetPoint('CENTER', lastBtn1, 'CENTER', thickness, 0)
  else
    handle:SetPoint('RIGHT', btn1, 'LEFT', -3, 0)
    handle:SetPoint('CENTER', btn1, 'CENTER', -thickness, 0)
  end
end

--- @param frame BarFrame_ABP_2_0
--- @param ui BarUIConfig_ABP_2_0
function o:Apply(frame, ui)
  local count = self:GetButtonCount(ui)
  local size = ui.button.size
  local spacing = (ui.button.spacing and ui.button.spacing.horizontal) or 0
  local isDown = ui.arcDirection == 'down'

  -- radius large enough that adjacent button centers are at least size+spacing apart
  -- (chord length = 2 * radius * sin(stepDegrees/2))
  local stepDegrees = count > 1 and (ARC_SPAN_DEGREES / (count - 1)) or 0
  local minChord = size + spacing
  local minRadius = size
  local radius = stepDegrees > 0 and math.max(minRadius, (minChord / 2) / math.sin(math.rad(stepDegrees / 2))) or minRadius

  local totalWidth  = 2 * radius * math.sin(math.rad(ARC_SPAN_DEGREES / 2)) + size
  local totalHeight = radius * (1 - math.cos(math.rad(ARC_SPAN_DEGREES / 2))) + size
  frame:SetSize(totalWidth, totalHeight)

  local hotKeyFontSize = math.max(8, math.floor(size * 12 / 40))
  local hotKeyOffsetX  = math.floor(size * 5 / 40)
  local hotKeyOffsetY  = math.floor(size * 7 / 40)

  -- arc center sits above (or below, when inverted) the frame's horizontal midline
  local centerX = totalWidth / 2
  local centerY = isDown and (size / 2) or (totalHeight - size / 2)

  for i, _btn in ipairs(frame.widget.buttons) do
    --- @type Button_ABP_2_0_X
    local btn = _btn

    btn:ClearAllPoints()
    if i <= count then
      btn:SetSize(size, size)
      cns:IfMasque(function(abpMasque) abpMasque:ReSkin(btn) end)
      btn.HotKey:SetFont(btn.HotKey:GetFont(), hotKeyFontSize, 'OUTLINE')
      btn.HotKey:ClearAllPoints()
      btn.HotKey:SetPoint('TOPRIGHT', btn, 'TOPRIGHT', -hotKeyOffsetX, -hotKeyOffsetY)

      local angle = ARC_START_DEGREES + stepDegrees * (i - 1)
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

