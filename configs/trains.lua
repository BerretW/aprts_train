Engines = {
    [155] = 1500,
    [376] = 2000,
    [451] = 1700,
    [541] = 2500,
    [249] = 2000
}
Wagons = {
    people = 200,
    cargo = 100,
    crates = 150,
    weapons = 300,
    army = 400
}

InventoryBase = 150
InventoryCratesBase = 50
-----------------------------------------------------
-- Train Model Config
-----------------------------------------------------
Trains = {
    appleseed = {
        model = 'appleseed_config', -- Model Name of the Train - DO NOT CHANGE
        label = 'Appleseed', -- Displayed Name of this Train
        price = 150, -- Purchase Price for this Train
        maxSpeed = 20, -- Max Speed / *30 is Highest Game Allows*
        Train = 155, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 3,
        crates = 0,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true, -- Set false to Disable Fuel Use
            maxAmount = 100, -- Maximum Fuel Capacity
            itemAmount = 5, -- Number of Items Needed to Fuel Train
            decreaseTime = 60, -- Time in Seconds to Decrease Fuel Level
            decreaseAmount = 2 -- Amount of Fuel to Decrease
        },
        condition = {
            enabled = true, -- Set false to Disable Condition Decrease
            maxAmount = 100, -- Maximum Condition
            itemAmount = 5, -- Number of Items Needed to Repair Train
            decreaseTime = 60, -- Time in Seconds to Decrease Condition Level
            decreaseAmount = 2 -- Amount of Condition to Decrease
        },
        inventory = {
            enabled = true, -- Set to false to Disable Train Inventory
            limit = InventoryBase*3, -- Inventory Limit for this Train
            acceptWeapons = false, -- Inventory can Hold Weapons
            shared = true -- Inventory is Shared with All Players
        },
        blip = {
            show = true, -- Show Blip for Train Location
            name = 'Train', -- Name of Blip on the Map
            sprite = -250506368, -- Default: -250506368
            color = 'WHITE' -- Color of Blip
        }
    },
    bountyhunter = {
        model = 'bountyhunter_config',
        label = 'Bounty Hunter',
        price = 4000,
        maxSpeed = 15,
        Train = 376, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 11,
        crates = 7,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*11 + InventoryCratesBase*7,
            acceptWeapons = true,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    engine = {
        model = 'engine_config',
        label = 'Engine (No Cars)',
        price = 1500,
        maxSpeed = 30,
        Train = 155, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 0,
        crates = 0,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = false,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = false,
            maxAmount = 100,
            itemAmount = 1,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = false,
            limit = InventoryBase,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    gunslinger3 = {
        model = 'gunslinger3_config',
        label = 'Gunslinger 3',
        price = 175,
        maxSpeed = 20,
        Train = 451, -- Train Type
        people = 4, -- Number of People Cars
        cargo = 1,
        crates = 3,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*1+InventoryCratesBase*3,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    gunslinger4 = {
        model = 'gunslinger4_config',
        label = 'Gunslinger 4',
        price = 200,
        maxSpeed = 15,
        Train = 376, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 13,
        crates = 7,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*13 + InventoryCratesBase*7,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    prisoner = {
        model = 'prisoner_escort_config',
        label = 'Prisoner Escort',
        price = 100,
        maxSpeed = 15,
        Train = 155, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 3,
        crates = 0,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*3,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    winter4 = {
        model = 'winter4_config',
        label = 'Winter 4',
        price = 150,
        maxSpeed = 15,
        Train = 249, -- Train Type
        people = 2, -- Number of People Cars
        cargo = 2,
        crates = 3,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*2 + InventoryCratesBase*3,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    industry2 = {
        model = 'industry2_config',
        label = 'Industry 2',
        hash = 0x31656D23,
        price = 150,
        maxSpeed = 15,
        Train = 376, -- Train Type
        people = 0, -- Number of People Cars
        cargo = 10,
        crates = 5,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = InventoryBase*10 + InventoryCratesBase*5,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    },
    pacifica = {
        model = 'net_fetch_train_kidnapped_buyer_00',
        label = 'Pacifica 1',
        hash = 0x2D3645FA,
        price = 150,
        maxSpeed = 15,
        Train = 541, -- Train Type
        people = 6, -- Number of People Cars
        cargo = 0,
        crates = 0,
        weapons = 0,
        army = 0,
        fuel = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        condition = {
            enabled = true,
            maxAmount = 100,
            itemAmount = 5,
            decreaseTime = 60,
            decreaseAmount = 2
        },
        inventory = {
            enabled = true,
            limit = (InventoryCratesBase/2)*6,
            acceptWeapons = false,
            shared = true
        },
        blip = {
            show = true,
            name = 'Train',
            sprite = -250506368,
            color = 'WHITE'
        }
    }
}
