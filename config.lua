CONFIG = {}

CONFIG.VEHICLES = {
    [`pdkn1`] = true,
    [`pdkn2`] = true,
    [`pdkn3`] = true,
    [`pdkn4`] = true,
    [`pdkn5`] = true,
    [`pdkn6`] = true,
    [`pdkn7`] = true,
    [`pdkn8`] = true,
    [`pdkn9`] = true,
    [`pdkns1`] = true,
    [`pdkns2`] = true,
    [`pdkns3`] = true,
    [`pdkns4`] = true,
    [`pdkns5`] = true,
    [`pdkns6`] = true,
    [`pdkns7`] = true,
    [`pdkns8`] = true,
    [`pdkns9`] = true,
}

CONFIG.SIM_WINDOW = {
    COOLING_FACTOR = 0.001,
    OPEN_FACTOR = 0.0025,
}

CONFIG.SIM_DOOR = {
    COOLING_FACTOR = 0.003,
    OPEN_FACTOR = 0.005,
}

CONFIG.SIM_AIRCONDITIONING = {
    MULTIPLIERS = {
        [1] = -0.5,
        [2] = -0.75,
        [3] = -1.25,
        [4] = 0.5,
        [5] = 0.75,
        [6] = 1.25
    },
    COOLING_FACTOR = 0.2,       -- Reduced cooling effect of AC due to frequent updates
    WINDOW_OPEN_FACTOR = 0.025, -- Lesser effect of open windows due to frequent updates
    DOOR_OPEN_FACTOR = 0.075,   -- Lesser effect of open doors due to frequent updates
}

CONFIG.SIM_AMBIENT = {
    DAY = 1.0,
    NIGHT = -1.0,
    FACTOR = 0.1,
    WEATHERS = {
        [`BLIZZARD`] = -0.02,
        [`CLEAR`] = 0.01,
        [`CLEARING`] = 0.005,
        [`CLOUDS`] = 0.002,
        [`EXTRASUNNY`] = 0.015,
        [`FOGGY`] = -0.005,
        [`HALLOWEEN`] = -0.003,
        [`NEUTRAL`] = 0.00,
        [`OVERCAST`] = -0.002,
        [`RAIN`] = -0.008,
        [`SMOG`] = -0.003,
        [`SNOW`] = -0.005,
        [`SNOWLIGHT`] = -0.003,
        [`THUNDER`] = -0.002,
        [`XMAS`] = -0.002
    }
}
