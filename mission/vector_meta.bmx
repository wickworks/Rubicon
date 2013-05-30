'-- ARCADE METAGAME --
'go through a series of waves, with a scoreboard in the middle

'values!
'0-3: level-specific values
'4: lives left
'5: points to spend
'6-11: upgraded # of specific attribute
'15: the stage of game we're playing: 0:AI waves|1:zerg waves|2:human waves|3:----|4:boss battle|5:mining mission|6:zerg survival
						'	6:beacons warping in boss

'load previous arcade highscores
load_highscores()

'get the theatres to play
theatrePool = New TList
For Local t:Theatre = EachIn theatreList
	If t.name = "vector_waves" Then theatrePool.addLast(t)
Next
advance_stage()

'restart whatever music we were playing
resetmusic = True

lives = 2'start out with three lives

'lock the camera
camlocked = True

Repeat
	Print "VECTORLOOP META"

	'reset the game for the next level
	over = False
	cleargame()	
	game.intro_tween = 1

	'set up factions
	fTable[1,2] = 0	'player neutral with AI
	fTable[2,1] = -1	'AI enemies with player
	
	'player soft reset
	p1.link = entitylist.AddLast(p1)
	p1.reset()
	p1.recalc()
	p1.x = 0
	p1.y = 0
	p1.rot = 0
	p1.speed = 0
	pilot.map_toggle = False
	
	'sets the game values to whatever the stage tells us to do
	If stage.music <> Null Then game.levelmusic = stage.music Else game.levelmusic = theme_music
	new_music = game.levelmusic
	
	value[0] = 0
	value[1] = 0
	value[2] = 0
	
	'play friggin' asteroids!
	
	'make the backdrop a grid
	backdrop_gfx[0] = Null
	backdrop_gfx[1] = grid_gfx
	backdrop_rgb[0] = 32
	backdrop_rgb[1] = 32
	backdrop_rgb[2] = 32
	
	
	
	'make the map as big as the screen
	width = SWIDTH/2'+40
	height = SHEIGHT/2'+40
	setup_cbox()
		
	'play the game!
	currentfade = 1'black it out
	fade = 0'but fade in
	
	'launch the game
	game.play()
	
	'get some points
	pilot.points:+ 100
	
	'make the next wave harder
	theatres_completed:+ 1
	
	'reset the current wave
	stage = Null
	advance_stage()
	
	'if the player died
	If p1.armour <= 0 Then Exit
	
	'if we exited via the menu
	If game.over = 2 Then Exit
	
	'if we're restarting
	If game.restart Then Exit

Forever


'unlock the camera
camlocked = False