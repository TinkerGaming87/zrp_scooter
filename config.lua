Config = {}

Config.Debug = false

Config.ItemName = 'electric_scooter'
Config.VehicleModel = 'electric_scooter'
Config.SpawnDistance = 2.5
Config.AllowOnlyOneActive = true

Config.Target = {
    Icon = 'fas fa-scooter',
    Label = 'Pick Up Scooter',
    Distance = 2.0
}

Config.Notify = {
    Deployed = 'Your scooter has been deployed.',
    PickedUp = 'You picked up your scooter.',
    AlreadyActive = 'You already have an active scooter out.',
    NotOwner = 'This is not your scooter.',
    InvalidScooter = 'You can only pick up scooters spawned by this item.',
    NoRoom = 'You do not have room to carry the scooter item.',
    SpawnFailed = 'Failed to deploy scooter.',
    AreaBlocked = 'There is not enough room to deploy the scooter here.'
}

Config.Vehicle = {
    PlatePrefix = 'ZSCOOT',
    WarpOntoVehicle = false,
    Fuel = 100.0,
    EngineOnSpawn = false
}