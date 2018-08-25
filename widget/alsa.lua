-----------------------------------------------------------------------------------------------------------------------
--                                   RedFlat ALSA volume control widget                                        --
-----------------------------------------------------------------------------------------------------------------------
-- Indicate and change volume level using pacmd
-----------------------------------------------------------------------------------------------------------------------
-- Some code was taken from
------ Pulseaudio volume control
------ https://github.com/orofarne/pulseaudio-awesome/blob/master/pulseaudio.lua
-----------------------------------------------------------------------------------------------------------------------

-- Grab environment
-----------------------------------------------------------------------------------------------------------------------
local io = io
local math = math
local table = table
local tonumber = tonumber
local tostring = tostring
local string = string
local setmetatable = setmetatable
local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local timer = require("gears.timer")

local tooltip = require("redflat.float.tooltip")
local audio = require("redflat.gauge.audio.blue")
local rednotify = require("redflat.float.notify")
local redutil = require("redflat.util")


-- Initialize tables and vars for module
-----------------------------------------------------------------------------------------------------------------------
local alsa = { card = 0, widgets = {}, mt = {} }

-- Generate default theme vars
-----------------------------------------------------------------------------------------------------------------------
local function default_style()
	local style = {
		notify      = {},
		widget      = audio.new,
		audio       = {}
	}
	return redutil.table.merge(style, redutil.table.check(beautiful, "widget.alsa") or {})
end

local change_volume_default_args = {
	down        = false,
	step        = 10,
	show_notify = false
}

-- Change volume level
-----------------------------------------------------------------------------------------------------------------------
function alsa:change_volume(args)

	-- initialize vars
	local args = redutil.table.merge(change_volume_default_args, args or {})
	local diff = args.down and -args.step or args.step

	-- get current volume
	local v = redutil.read.output(
            "amixer -c" .. alsa.card .. " get Master | grep Mono:");
	local volume = tonumber(string.sub(string.match(v, "%[%d+%%%]"), 2, -3))

	-- calculate new volume
	local new_volume = volume + diff

	if new_volume > 100 then
		new_volume = 100
	elseif new_volume < 0 then
		new_volume = 0
	end

    local volume_percent = string.format("%.0f%%", new_volume)
	-- show notify if need
	if args.show_notify then
		rednotify:show(
			redutil.table.merge({
			    value = new_volume / 100, text = volume_percent
			}, alsa.notify)
		)
	end

	-- set new volume
	awful.spawn("amixer -c" .. alsa.card .. " set Master " .. volume_percent)
	-- update volume indicators
	self:update_volume()
end

-- Toggle mute
-----------------------------------------------------------------------------------------------------------------------
function alsa:mute()
    awful.spawn("amixer -c" .. alsa.card .. " set Master toggle")
	self:update_volume()
end

-- Update volume level info
-----------------------------------------------------------------------------------------------------------------------
function alsa:update_volume()

	-- initialize vars
	local volume = 0
	local mute

	-- get current volume and mute state
	local master = redutil.read.output(
	        "amixer -c" .. alsa.card .. " get Master | grep Mono:")

    volume = tonumber(string.sub(string.match(master, "%[%d+%%%]"), 2, -3))
	mute = string.find(master, "%[off%]")

	-- update tooltip
	self.tooltip:set_text(volume .. "%")

	-- update widgets value
	for _, w in ipairs(alsa.widgets) do
		w:set_value(volume / 100)
		w:set_mute(mute)
	end
end

-- Create a new alsa widget
-- @param timeout Update interval
-----------------------------------------------------------------------------------------------------------------------
function alsa.new(args, style)

	-- Initialize vars
	--------------------------------------------------------------------------------
	local style = redutil.table.merge(default_style(), style or {})
	alsa.notify = style.notify

	local args = args or {}
	local timeout = args.timeout or 5
	local autoupdate = args.autoupdate or false

	-- create widget
	--------------------------------------------------------------------------------
	widg = style.widget(style.audio)
	table.insert(alsa.widgets, widg)

	-- Set tooltip
	--------------------------------------------------------------------------------
	if not alsa.tooltip then
		alsa.tooltip = tooltip({ objects = { widg } }, style.tooltip)
	else
		alsa.tooltip:add_to_object(widg)
	end

	-- Set update timer
	--------------------------------------------------------------------------------
	if autoupdate then
		local t = timer({ timeout = timeout })
		t:connect_signal("timeout", function() alsa:update_volume() end)
		t:start()
	end

	--------------------------------------------------------------------------------
	alsa:update_volume()
	return widg
end

-- Config metatable to call alsa module as function
-----------------------------------------------------------------------------------------------------------------------
function alsa.mt:__call(...)
	return alsa.new(...)
end

return setmetatable(alsa, alsa.mt)
