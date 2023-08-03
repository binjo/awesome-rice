-- DEPENDENCIES: lua-socket (optional)

local os_date = os.date
local _, socket = pcall(require, "socket")
local awful = require("awful")
local naughty = require("naughty")
local wibox = require("wibox")
local ruled = require("ruled")
local beautiful = require("theme.theme")
local capsule = require("widget.capsule")
local gtimer = require("gears.timer")
local ucolor = require("utils.color")

local get_time = socket and socket.gettime


naughty.connect_signal("request::display_error", function(message, startup)
    naughty.notification {
        urgency = "critical",
        title = "Oops, an error happened" .. (startup and " during startup!" or "!"),
        message = message,
    }
end)

naughty.connect_signal("request::display", function(n)
    local box = naughty.layout.box {
        notification = n,
        bg = n.style.bg,
        fg = n.style.fg,
        border_color = n.style.border_color,
        border_width = n.style.border_width,
        shape = n.style.shape,
        widget_template = {
            widget = wibox.container.constraint,
            {
                widget = wibox.layout.fixed.vertical,
                {
                    widget = wibox.container.background,
                    bg = n.style.header_bg,
                    fg = n.style.header_fg,
                    {
                        layout = wibox.layout.stack,
                        {
                            id = "#timer_bar",
                            widget = wibox.widget.progressbar,
                            color = n.style.timer_bg,
                            background_color = ucolor.transparent,
                            forced_height = 1, -- any value > 0, otherwise it will take all space!
                            value = 0,
                            max_value = 1,
                        },
                        {
                            layout = wibox.layout.fixed.horizontal,
                            reverse = true,
                            fill_space = true,
                            {
                                widget = wibox.container.margin,
                                margins = n.style.paddings,
                                {
                                    widget = naughty.widget.title,
                                    valign = "top",
                                },
                            },
                            {
                                widget = wibox.container.margin,
                                margins = n.style.paddings,
                                {
                                    widget = wibox.widget.textbox,
                                    opacity = 0.5,
                                    text = "at " .. os_date("%H:%M"):gsub("^0", ""),
                                    valign = "top",
                                },
                            },
                        },
                    },
                },
                {
                    widget = wibox.container.background,
                    bg = n.style.header_border_color,
                    forced_height = n.style.header_border_width,
                },
                {
                    widget = wibox.container.margin,
                    margins = n.style.paddings,
                    {
                        layout = wibox.layout.fixed.horizontal,
                        fill_space = true,
                        spacing = n.style.icon_spacing,
                        {
                            widget = naughty.widget.icon,
                        },
                        {
                            widget = naughty.widget.message,
                            valign = "top",
                        },
                    },
                },
                {
                    widget = wibox.container.margin,
                    margins = n.style.actions_paddings,
                    visible = #n.actions > 0,
                    {
                        widget = naughty.list.actions,
                        base_layout = wibox.widget {
                            layout = wibox.layout.flex.horizontal,
                            spacing = n.style.actions_spacing,
                        },
                        style = {
                            underline_normal = false,
                            underline_selected = true,
                        },
                        widget_template = {
                            widget = capsule,
                            {
                                id = "text_role",
                                widget = wibox.widget.textbox,
                                halign = "center",
                            },
                        },
                    },
                },
            },
        },
    }

    if get_time then
        local timer_bar = box.widget:get_children_by_id("#timer_bar")[1]
        local timer
        local function stop_timer()
            if timer then
                timer:stop()
                timer = nil
            end
            timer_bar.value = 0
        end
        local function update_timeout()
            stop_timer()
            local timeout = tonumber(n.timeout) or 0
            local start = get_time()
            if timeout > 0 then
                timer = gtimer {
                    timeout = 1 / 30,
                    autostart = true,
                    call_now = true,
                    callback = function()
                        local now = get_time()
                        local value = 1 - ((now - start) / timeout)
                        if value <= 0 then
                            value = 0
                        end
                        timer_bar.value = value
                        if value == 0 then
                            stop_timer()
                        end
                    end,
                }
            end
        end
        n:connect_signal("destroyed", stop_timer)
        n:connect_signal("property::timeout", update_timeout)
        update_timeout()
    end
end)


ruled.notification.connect_signal("request::rules", function()
    ruled.notification.append_rule {
        rule = {},
        properties = {
            screen = awful.screen.preferred,
            max_width = beautiful.notification.width,
            style = beautiful.notification.default_style,
        },
    }
    ruled.notification.append_rule {
        rule = { urgency = "low" },
        properties = {
            implicit_timeout = 8,
        },
    }
    ruled.notification.append_rule {
        rule = { urgency = "normal" },
        properties = {
            implicit_timeout = 30,
        },
    }
    ruled.notification.append_rule {
        rule = { urgency = "critical" },
        properties = {
            never_timeout = true,
            style = beautiful.notification.styles.critical,
        },
    }
end)
