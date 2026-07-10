fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealRPG / VeZse Development'
description 'RealRPG Clothing Designer V17.3 - fixed 3D preview and responsive UV studio'
version '17.3.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/texture_bridge_config.lua'
}

client_scripts {
    'client/main.lua',
    'client/texture_bridge.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/texture_bridge.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/uv_workbench.css',
    'html/uv_workbench.js',
    'html/assets/*.png',
    'templates/template_previews/**/*.png',
    'templates/template_previews/**/*.webp',
    'templates/template_previews/**/*.jpg',
    'templates/template_previews/**/*.jpeg'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_inventory'
}
