fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'RealRPG / VeZse Development'
description 'RealRPG Clothing Designer V14 - fully RealRPG-named custom clothing designer system'
version '14.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.png',
    -- BUGFIX (V14): stream/*.ydd and stream/*.ymt were missing here, so real clothing
    -- addon-component files (e.g. jbib_000_u.ydd, jbib_diff_000_a_uni.ytd, and their
    -- addon-prefixed 'mp_m_freemode_01^...' variants) placed in stream/ would never be
    -- streamed to clients, even though ytd/ydr already were.
    'stream/*.ydr',
    'stream/*.ydd',
    'stream/*.ytd',
    'stream/*.ymt',
    'templates/cloth_templates/**/*.ydd',
    'templates/cloth_templates/**/*.ytd',
    'templates/template_previews/**/*.png',
    'templates/template_previews/**/*.webp',
    'templates/template_previews/**/*.jpg',
    'templates/template_previews/**/*.jpeg',
    'templates/template_slots/**/*.ytd',
    'worker/fivemRpcWorker.cjs',
    'worker/tools/*',
    'TROUBLESHOOTING_V12.md'
}

dependencies {
    'es_extended',
    'oxmysql'
}
