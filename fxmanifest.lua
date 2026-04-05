fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'zrp_scooter'
author 'Wildz Kreationz'
description 'Reusable electric scooter item'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'data/*.meta'
}

data_file 'HANDLING_FILE'            'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE'    'data/vehicles.meta'
data_file 'CARCOLS_FILE'             'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE'   'data/carvariations.meta'

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target'
}