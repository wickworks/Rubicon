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
theatrePool.addLast(theatreStart)'always start with the first theatre
advance_stage()
If stage <> Null Then Print stage.map Else Print "null stage!"

'restart whatever music we were playing
resetmusic = True

'start out with two lives (ZEN MODE: this never decreases)
lives = 2

Repeat
	'reset the game for the next level
	over = False
	cleargame()	
	game.intro_tween = 1

	'clear the pre-approved values for the game types to use
	value[1] = 0
	value[2] = 0
	value[3] = 0
	value[4] = 0
	
	'how many waves we've gone through
	value[0]:+ 1

	'set up factions
	fTable[1,2] = -1	'player enemies with AI
	fTable[1,3] = -1	'player enemies with Gaxlid
	fTable[2,1] = -1	'AI enemies with player
	fTable[2,3] = -1	'AI enemies with Gaxlid
	fTable[3,1] = -1	'Gaxlid enemies with player
	fTable[3,2] = -1	'Gaxlid enemies with AI
	
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
	If stage.map <> "" Then load_map(stage.map) Else load_map("arcade0")
	If stage.music <> Null Then game.levelmusic = stage.music Else game.levelmusic = theme_music
	new_music = game.levelmusic
	If stage.shake_text <> "" Then shakyText(stage.shake_text)
	If stage.overhear_text <> "" And pilot.difficulty > 1 Then shakyText(stage.overhear_text)
	
	'gametype value setup!
	Select stage.gameType
	Case GAMETYPE_WAVES'waves
		'incoming wave timer
		value[1] = 4500
		
		'display initial text
		If stage.flash_text[0] <> "" Then add_flashtext(stage.flash_text[0])
	
		'warp in the player
		Local warp:Item = p1.warp_in(Null, p1.x, p1.y, LEVEL_INTROTIME*1000)
		
	Case GAMETYPE_VECTOR'play friggin' asteroids!
		ships[7] = p1'store the current player's ship
	
		'make the backdrop a grid
		backdrop_gfx[0] = Null
		backdrop_gfx[1] = grid_gfx
		backdrop_rgb[0] = 32
		backdrop_rgb[1] = 32
		backdrop_rgb[2] = 32
		
		'clear the background, map-added stuff
		ClearList bgList
		ClearList entityList
		
		For Local cbx = 0 To 99
		For Local cby = 0 To 99
			game.cboxList[cbx,cby] = Null
			game.map[cbx,cby,0] = 0
			game.map[cbx,cby,1] = 0
		Next
		Next
		
		'lock the camera
		camlocked = True
		
		'make a new ship for the player
		If p1.turnRate = -1'make a fighter
			p1 = new_ship("Vector Ship",0,0,"arcade",pilot.psquad)
		Else'make a frigate
			p1 = new_ship("Vector Frigate",0,0,"arcade",pilot.psquad)
		EndIf
		p1.behavior = "player"
		
		fTable[1,2] = 0	'player neutral with AI
		
		'make the map as big as the screen
		width = SWIDTH/2'+40
		height = SHEIGHT/2'+40
		setup_cbox()
	
	Rem
	Case GAMETYPE_SURVIVAL'Zaxlid survival
		'how long we have to survive
		value[2] = 45000 + theatres_completed * 15000
		new_objective("Time left: ["+time((value[2]/1000) - playTime)+"]")
		
		add_flashtext("SURVIVE")
	
		
	Case 100'mining operation
		fTable[2,3] = 1	'2 protects faction 3 (AI protects mining bots)
		fTable[3,2] = 1	'3 is proteced by faction 2
		fTable[3,4] = -1	'3 attacks faction 4 (mining bots attack special asteroids)
		fTable[3,1] = -1	'3 attacks faction 1 (mining bots attack player)
		fTable[1,3] = -1	'1 attacks faction 3 (player attacks mining bots)
	
		add_flashtext("DESTROY ALL MINING VESSELS")
	
		'warp in the player
		Local warp:Item = p1.warp_in(Null, p1.x, p1.y, LEVEL_INTROTIME*900)
	
	Case 101'warp beacon destruction
		'how long we have to destroy all beacons
		value[3] = 120000
		new_objective("["+time((value[3]/1000) - playTime)+"] before enemy convoy warps in.")
		
		add_flashtext("DESTROY ALL WARP BEACONS")
	EndRem
	
	EndSelect
	
	'play the game!
	currentfade = 1'black it out
	fade = 0'but fade in
	
	'launch the game
	game.play()
	
	'get how many points we collected 
	For Local point:Item = EachIn p1.dropList
		ListRemove(p1.dropList, point)
		If pilot.difficulty > 0 Then value[5]:+ 1	'zen mode gets no upgrades
		'pilot.points:+ 1							'but can still unlock stuff  -> now done by banking
	Next
	
	'post-game processing
	Select stage.gameType
	Case GAMETYPE_VECTOR'play friggin' asteroids!
		camlocked = False'unlock the camera
		p1 = ships[7]'restore the current player's ship
		value[5]:+ 50*theatres_completed'get some points
	EndSelect
	
	ClearList(game.objectiveList)
	
	'if the player died
	If p1.armour <= 0 Then Exit
	
	'if we exited via the menu
	If game.over = 2 Then Exit
	
	'if we're restarting
	If game.restart Then Exit
	
	'proceed through the stages
	advance_stage()
	'if we run out of unlocked theatres, just replay the whole damn thing
	If ListIsEmpty(theatrePool)
		theatrePool = scrambleList(theatreList)
		advance_stage()
	EndIf
	
	'perhaps unlock things?
	'If pilot.points >= (1000 * theatres_completed) Then pilot.unlock_component()
		
	'upgrade stats (and exit if it tells us to)
	If Not arcade_upgrade() Then Exit
Forever

'remove those dang upgrades we gave the ship
p1.load_config(p1.config)