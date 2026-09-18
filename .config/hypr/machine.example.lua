-- Windows confirms that the Lenovo 83FD internal panel (CSO1626) runs at
-- 3200x2000@165 and is connected to the Intel iGPU. Copy this file to
-- `machine.lua` after `hyprctl monitors all` reveals the Linux output name.
--
-- Scale 2 matches Windows' recommended 200% scaling. Scale 1.6 is also valid
-- for this resolution and provides more workspace if 2 feels too large.
return {
    monitors = {
        {
            output = "REPLACE_WITH_INTERNAL_OUTPUT",
            mode = "3200x2000@165",
            position = "0x0",
            scale = 2,
        },
    },
}
