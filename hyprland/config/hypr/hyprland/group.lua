local scheme = require("scheme.everblush")
local vars   = require("variables")

hl.config({
    group = {
        col = {
            border_active          = vars.activeWindowBorderColour,
            border_inactive        = vars.inactiveWindowBorderColour,
            border_locked_active   = vars.activeWindowBorderColour,
            border_locked_inactive = vars.inactiveWindowBorderColour,
        },
        groupbar = {
            font_family               = "Grenze Gotisch",
            font_size                 = 15,
            gradients                 = true,
            gradient_round_only_edges = false,
            gradient_rounding         = 0,
            height                    = 25,
            indicator_height          = 0,
            gaps_in                   = 3,
            gaps_out                  = 3,
            text_color                = "rgb(" .. scheme.bone .. ")",
            col                       = {
                active          = "rgb(" .. scheme.crimson .. ")",
                inactive        = "rgb(" .. scheme.wine .. ")",
                locked_active   = "rgb(" .. scheme.crimson .. ")",
                locked_inactive = "rgb(" .. scheme.plum .. ")",
            },
        },
    },
})
