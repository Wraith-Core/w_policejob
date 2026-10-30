fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'w_PoliceJob'
version '1.0.4'

shared_scripts {
    '@w_lib/init.lua', -- must load before anything that touches w / lib / cache
    'config.lua',
}

client_scripts {
	'client/cards.lua', -- one card at a time (loads first: TrackCard / ScreenIsFree)
	'client/main.lua',
	'client/interactions.lua',
	'client/job.lua',
	'client/evidence.lua',
	'client/objects.lua',
	'client/prison.lua',
}

server_scripts {
	'server/main.lua'
}

files {
	'locales/*.json',
}

-- the library loads locales/<key>.json at start (key = player choice / w_lib:locale convar)
w_lib {
	'locale',
}

lua54 'yes'
-- w_core too: its core object is fetched at load (w.framework:getCoreObject())
dependencies { 'w_lib' }
