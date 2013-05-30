Const LEVEL_INTROTIME# = 1.9'time in sec of the starting intro thingy at the beginning of a level
Const LIFECHANCE = 50'one in this many enemies will drop an extra life

Type Level'game types! The DM, sort of. This object sets up & directs levels, win/lose conditions
	Field name$					'the name of this game type
	
	Field theatres_completed		'number of completed theatres
	Field theatrePool:TList		'list of theatres to draw from, the first one is the active one
	Field stage:Stage				'the currently active stage (gets it from the active theatre)
	
	Field lives					'how many lives the player has
	Field respawn_timer			'time in ms to respawn
	Field respawn_delay = 2700
	
	Field value#[16]				'tracks certain values over the course of the game
	Field bgs:Background[8]		'tracks certain backgrounds
	Field point:Item[8]			'tracks certain items
	Field ships:Ship[8]			'tracks certain ships
	Field squads:Squadron[8]		'tracks certain squadrons
	Field shipList:TList[8]		'tracks LISTS of certain ships
	Field mbox:Messagebox			'the current messagebox
	Field over					'game.over = True : end the current game
	Field restart				'game.restart = True : start a new identical game when this one ends
	Field width,height			'the width and height RADIUSES of the current playing field (0,0 is center)
	Field camx#,camy#				'the amount to offset ALL entity drawing operations
	Field camrot#				'the amount the camera is rotated, if applicable
	Field camxoffset#,camyoffset#	'the amount to add to camx,camy each loop
	Field camoffsetmod# = 1		'modifier of camera following the mouse. ( 2 = 1:1 )
	Field camshake#				'generates camera offset due to shake. set to 1 for max shake, as decays back to 0 it shakes the screen
	Field minimap:TImage			'the image of the minimap
	Field backdrop_gfx:TImage[2]
	Field backdrop_rgb[3]
	Field objectiveList:TList = New TList'list of currently active objectives
	Field flashtext$				'text to flash all big at the top
	Field flashtext_timer#
	Field display_objectives = True	'TRUE/FALSE whether to display the objectives
	Field fade#					'the current fade target, set to 1 will fully black out the screen
	Field currentfade#			'the current fade level
	Field intro_tween#			'when > 1, stuff is zoomed in on the player and there are no controls, and the HUD does stuff. decays to 0.
	Field zoom#					'how much to alter everything's distance
	Field zoomtarget#			'what the zoom WANTS to be, will decay to this
	Field decayzoom = True		'if the zoom level should be decayed to zoomtarget
	Field skipDeploy = False		'skips the deploy step in initializing the game, used for restarting
	Field playTime#				'in sec, how long we've been playing this level
	Field enemiesDestroyed			'how many enemies destroyed over the course of the game
	Field camlocked = False			'if true, the camera doesn't move
	
	Field levelmusic:TSound = theme_music	'the default music for this level
	
	Field disable_controls = False	'exactly what it sounds like
	
	'deployment stuff
	Field warprestrict = True		'whether the deployment should be restricted by proximity
	Field iconList:TList = New TList	'the icons to display to put on the map for this mission
	
	'set up the collision box lists
	Field cboxRowNum, cboxColNum		'the number of rows and columns of cboxes in the game 
	Field cboxSize = 256			'the width and height of each cbox
	Field cboxList:TList[100,100]	'array of collision box lists
	
	Field map[100,100,2]			'0: the terrain of a cbox: 0=nothing | 1=lightning nebulae | 2=fog nebulae
							'1: the state of that terrain, used to keep track of rotation, alpha... just for a bit of variation
	
	Field dead_mode				'0: show your score | 1:show highscores | 2:show credits
	Field dead_credits_scroll = -SHEIGHT'how far down the credits are scolled
	
	
	Method play()
		new_music = levelmusic
		Repeat
			mainLoop()
			If Not over Then pause_menu()
		Until over
	EndMethod
	
	'the metagame of a game type
	Method meta()
	
		'should we do deployment?
		Select Lower(name$)
		Case "tutorial"
			skipDeploy = True
			p1 = new_ship("Turret",0,0,"",pilot.psquad,False)'just make a ship so it doesn't yell at us, we'll replace it at the start
			
		Case "testdrive"
			intro_tween = 0
			skipDeploy = True
			
		Case "vector"
			'make a new ship for the player
			p1 = new_ship("Vector Ship",0,0,"arcade",pilot.psquad)
			p1.behavior = "player"
			intro_tween = 0
			skipDeploy = True
			
		EndSelect
		
		'do deployment if we are supposed to
		If Not skipDeploy
			'if we back out of deployment, then exit
			If Not deployment(Self) Then Return
		ElseIf p1 <> Null
			ListRemove(entityList,p1)'just in case...
			p1.link = entityList.addLast(p1)
		EndIf
		
		'set the game to this level
		game = Self
	
		Select Lower(name$)
		'go through a series of waves, with a scoreboard in the middle
		Case "arcade"
			Include "mission/arcade_meta.bmx"
			
		'learn how to play
		Case "tutorial"
			Include "mission/tutorial_meta.bmx"
			
		'drive around in an asteroid field
		Case "testdrive"
			Include "mission/test_meta.bmx"
			
		'play friggin' asteroids!
		Case "vector"
			Include "mission/vector_meta.bmx"
		
		EndSelect
		
	EndMethod
	
	'moniters progress of a game, initialize if needed, changes things as it sees fit
	Method update()
		
		'decay the current fade towards the fade target
		If currentfade <> fade Then currentfade:+ (fade-currentfade) * 4 * (frameTime/2000.0)
		currentfade = constrain(currentfade,0,1)
		If Abs(currentfade-fade) < .05 Then currentfade = fade
		
		'update how long we've been playing this level
		playTime:+ (frameTime/1000)
		
		'decay zoom to target, if applicable
		If decayzoom And zoom <> zoomtarget
			Local decayspeed# = .01
			If Abs(zoom - zoomtarget) > decayspeed Then zoom:- (decayspeed#*Sgn(zoom - zoomtarget)) Else zoom = zoomtarget
		EndIf
		
		'warp-in intro sequence for the player
		If intro_tween > 0
			'set zoom based on intro tween, take away controls
			zoom = -constrain(intro_tween,0,.99)
			game.disable_controls = True
		
			'decay intro tween back to zero
			If playTime <= LEVEL_INTROTIME Then intro_tween = constrain( 1 - ((playTime / LEVEL_INTROTIME)^2 + .05), 0, 1)
		
			'finish the intro
			If intro_tween <= 0
				intro_tween = 0
				zoom = 0
				game.disable_controls = False
			EndIf
			
		Else'during gameplay
			zoomtarget = 0'don't muck about with zooming (if constantly set elsewhere, that'll win)
		EndIf
		
		Select Lower(name$)
		
		'waves of enemies come at you till you die or win (HAHA that was a joke. You can't win.)
		Case "arcade"
			Select stage.gameType'what gametype are we doing?
			Case GAMETYPE_WAVES
				Include "mission/arcade_wave_update.bmx"
			Case GAMETYPE_SURVIVAL
				Include "mission/arcade_wave_update.bmx"
			Case GAMETYPE_VECTOR
				Include "mission/arcade_vector_update.bmx"
			EndSelect
		
			draw_dead_display()
		
		'learn how to play
		Case "tutorial"
			Include "mission/tutorial_update.bmx"
		
		'drive around in an asteroid field
		Case "testdrive"
			Include "mission/test_update.bmx"
			
		'play friggin' asteroids!
		Case "vector"
			Include "mission/arcade_vector_update.bmx"
			
		EndSelect
					
		'if the player dies and we still have lives, warp them back in
		If p1 <> Null And p1.placeholder.dead And game.lives > 0
			'reset/countdown the timer
			If game.respawn_timer <= 0
				game.respawn_timer = game.respawn_delay
				resetmusic = True
			Else
				game.respawn_timer:- frameTime
				If music_fade < .15 Then music_fade = .15'keep the music off for a second
			EndIf
			'once the timer hits 0, respawn
			If game.respawn_timer <= 0
				'player soft reset
				p1.link = entitylist.AddLast(p1)
				p1.reset()
				p1.rot = 0
				p1.speed = 0
				p1.warp_in(Null, p1.x, p1.y, LEVEL_INTROTIME*1000)
				'tick down lives
				Local lifetext$
				If pilot.difficulty > 0'if not zen mode
					game.lives:- 1
					lifetext = game.lives+" ships left"
					If game.lives = 1 Then lifetext = game.lives+" ship left"
				Else
					Select Rand(0,11)
					Case 0
						lifetext = "It's OK. You're doing your best."
					Case 1
						lifetext = "We all need time to learn."
					Case 2
						lifetext = "You're really going through those."
					Case 3
						lifetext = "Boom! I like that effect."
					Case 4
						lifetext = "Try to be more careful, yeah?"
					Case 5
						lifetext = "Good thing nobody was in there."
					Case 6
						lifetext = "Don't worry, we have a lot of these."
					Case 7
						lifetext = "Ah, that new-ship smell..."
					Case 8
						lifetext = "Juuuust one more..."
					Case 9
						lifetext = "Pew pew pew! Kablooie!"
					Case 10
						lifetext = "These things aren't cheap, you know."
					Case 11
						lifetext = "Thank heavens you stopped that bullet. With your face."
					EndSelect
				EndIf
				add_text(lifetext,p1.x+20,p1.y-40, 3000, False)
			EndIf
		EndIf	
	EndMethod
	
	Method updateCamera()
		'CAMERA OFFSET
		'if we're not rotating the camera with the ship
		game.camrot = -90
		
		If Not game.camlocked
			'offset everything by the player's position (centered on the screen)
			game.camx = -p1.x + SWIDTH/2
			game.camy = -p1.y + SHEIGHT/2
			
			'now, on top of that, offset it by some amount based on the position of the mouse
			'find the position of where we want the camera to be
			Local camtarx# = game.camxoffset - ((cursorx-SWIDTH/2)/2)*game.camoffsetmod
			Local camtary# = game.camyoffset - ((cursory-SHEIGHT/2)/2)*game.camoffsetmod
			'change the offset by that position
			game.camxoffset:- camtarx*(frameTime/1000)
			game.camyoffset:- camtary*(frameTime/1000)
			
			'move the camera by that offset amount
			game.camx:- game.camxoffset
			game.camy:- game.camyoffset
		Else
			game.camx = 0
			game.camy = 0
		EndIf
		
		'try to restore normal camera offset tightness
		game.camoffsetmod = 1
		
		'constrain the camera
		game.camx = constrain(game.camx, -game.width+SWIDTH, game.width)
		game.camy = constrain(game.camy, -game.height+SHEIGHT, game.height)
		
		'is the camera shaking?
		If game.camshake > .01
			'as shake decays back down, bump the camera around
			Local camxshake = Sin(game.camshake*720) * (5 + 4*Floor(game.camshake))
			Local camyshake = Sin(game.camshake*360) * (3 + 4*Floor(game.camshake))
			
			'move the camera by that shake amount
			game.camx:- camxshake
			game.camy:- camyshake
		
			'decay the shake
			game.camshake:- frameTime/150
		Else
			game.camshake = 0
		EndIf
	EndMethod
	
	'checks the map boxes for collisions AND updates terrain (like lightning)
	Method updateMapCollisions()
		'check for collisions
		Local temp:TList = New TList
		For Local cbx = 0 To game.cboxColNum-1
		For Local cby = 0 To game.cboxRowNum-1
			Local cbList:TList = game.cboxList[cbx,cby]
			
			If Not ListIsEmpty(cbList)
			
				For Local e:Entity = EachIn cbList
					Local wid = e.scale * ImageWidth(e.gfx[0])/2
					Local het = e.scale * ImageHeight(e.gfx[0])/2
	
					'we're about to check for collisions with ships, and if this entity doesn't want to, there's no point
					If e.ignoreShipCollisions Then Continue
	
					'is THIS entity a ship?
					Local isShip = (TTypeId.ForObject(e) = TTypeId.ForName("Ship"))
					'is it a shot?
					Local isShot = (TTypeId.ForObject(e) = TTypeId.ForName("Shot"))
					'is it an item?
					Local isItem = (TTypeId.ForObject(e) = TTypeId.ForName("Item"))
					
					'get the placeholder if it's a ship
					Local eplaceholder:Gertrude
					If isShip
						temp.addLast(e)
						For Local _e:Ship = EachIn temp
							eplaceholder = _e.placeholder
						Next
					EndIf
					
					For Local o:Ship = EachIn cbList	'<--- THIS IS IMPORTANT! Things only collide with ships, so no shot-shot checking!
						'if not self AND the two are not connected AND one's not ignoring the other
						If (o <> e) And (Not ListContains(e.ignoreList,o.placeholder)) And ((eplaceholder = Null) Or (Not ListContains(o.ignoreList,eplaceholder)))
							'if this new ship can collide with the current entity
							If (Not o.ignoreShipCollisions Or Not isShip) And (Not o.ignoreShotCollisions Or Not isShot)
							
								'did we already check this?
								Local rechecked = False
								'ship-ship rechecking
								For Local checked:Gertrude = EachIn o.proximity_shipList
									If checked.x = Int(e.x) And checked.y = Int(e.y)
										rechecked = True
										Exit
									EndIf
								Next
													
								'if we didn't already check this
								If Not rechecked 
									Local owid = o.scale * ImageWidth(o.gfx[0])/2
									Local ohet = o.scale * ImageHeight(o.gfx[0])/2
									
									'get how close ovals are to colliding
									Local dist = OvalsCollide(e.x,e.y,wid,het,e.rot,o.x,o.y,owid,ohet,o.rot)
									
									'collide?
									If dist <= 0 Then e.collide(o)'negative means ovals are overlapping
									
									'if both are ships, each stores where the other is for purposes of rechecking/AI object avoidance 
									If dist < AI_AVOIDCOLLISION_DIST
										If isShip
											temp.addLast(e)
											For Local _e:Ship = EachIn temp
												If _e.behavior <> "inert" Or o.behavior <> "inert"
													o.proximity_shipList.addLast(_e.placeholder)
													_e.proximity_shipList.addLast(o.placeholder)
													Exit'one-ship list
												EndIf
											Next
											ClearList(temp)
										EndIf
										
										'items store where nearby ships are
										If isItem
											temp.addLast(e)
											For Local _i:Item = EachIn temp
												_i.proximity_shipList.addLast(o.placeholder)
												Exit'one-item list
											Next
											ClearList(temp)
										EndIf
									EndIf
								EndIf
							EndIf
						EndIf
					Next
					
					'if this entity REALLY cares about proximity, find ships in adjacent cboxes, too (for AI purposes)
					If e.proximity_track
						temp.addLast(e)
						For Local _e:Entity = EachIn temp
							'each adjecent cbox
							For Local py = -1 To 1
							For Local px = -1 To 1
								'skip the center tile
								If (py <> 0 Or px <> 0)
									'make sure we're within bounds
									If (cbx+px >= 0) And (cbx+px <= game.cboxColNum-1) And (cby+py >= 0) And (cby+py <= game.cboxRowNum-1)
										For Local o:Ship = EachIn game.cboxList[cbx+px,cby+py]
											If o <> _e'if not self
												If Not ListContains(_e.proximity_shipList, o.placeholder)
													_e.proximity_shipList.addLast(o.placeholder)
												EndIf
											EndIf
										Next
									EndIf
								EndIf
							Next
							Next
						Next
						ClearList(temp)
					EndIf
				Next
				
				'clear it out once we're done
				'ClearList(game.cboxList[i])'we're doing this at the start now
			EndIf
		
			'update terrain
			Local terrain = game.map[cbx,cby,0]
			Select terrain
			Case 1'lightning nebulae
				'is this storm active? (be a cheatyface, only have the universe exist around the player
				If approxDist((cbx*game.cboxSize-game.width) - p1.x, (cby*game.cboxSize-game.height) - p1.y) < 3500
					Local state = game.map[cbx,cby,1]
					'lightning nebulae have some lightning
					If state Mod 3 = 0 And globalFrameSwitch
						'figure out where it is
						Local lrot = Rand(0,359)
						Local lvar = game.cboxSize/2
						Local lx = cbx*game.cboxSize - game.width + Rand(-lvar,lvar)
						Local ly = cby*game.cboxSize - game.height + Rand(-lvar,lvar)
						
						'small lightning
						Local lgfx:TImage[] = lightning3_gfx
						Local ldamage = 2
						Local lanim = True
						Local lsfx:TSound = Null
	
						'medium lightning
						If state Mod 30 = 0
							ldamage = 4
							lgfx = lightning1_gfx
						EndIf
						
						'big lightning
						If state Mod 60 = 0
							ldamage = 10
							lgfx = lightning2_gfx
							lsfx = lightning2_sfx
							lanim = False
						EndIf
	
						'make the zapper
						Local s:Shot = add_shot(Null, "lightning", lgfx, lx, ly, lrot, 0, 0, ldamage)
						s.hit_gfx = lightning4_gfx
						s.hit_sfx = lightning3_sfx
						s.lifetimer = 500
						s.trail = False
						s.blend = LIGHTBLEND
						s.animated = lanim
						s.durable = True
						If lsfx <> Null Then playSFX(lsfx,lx,ly)
	
					EndIf
				EndIf
			EndSelect
		Next
		Next
	EndMethod
	
	
	Method load_map(_mapName$)
		'open the map
		Local fileName$ = _mapName
		Local mFile:TStream = ReadFile("mission/"+Lower(fileName)+".map")
		
		If mFile
			'load each data point
			Repeat
				'get the next datum type
				Local dat$ = ReadString(mFile,1)
				Select dat
				Case "x"'map width
					width = ReadFloat(mfile)
					If height <> 0 Then setup_cbox()'needs to go after width, height set
				Case "y"'map height
					height = ReadFloat(mfile)
					If width <> 0 Then setup_cbox()
				Case "t"'terrain
					Local tx = ReadFloat(mfile)-width
					Local ty = ReadFloat(mfile)-height
					Local t = ReadByte(mfile)
					setTerrain(tx,ty,t)
				Case "i"'icon
					Local namelen = ReadByte(mFile)
					Local iname$ = ReadString(mfile, namelen)
					Local ivalue[4]
					ivalue[0] = ReadByte(mfile)
					ivalue[1] = ReadByte(mfile)
					ivalue[2] = ReadByte(mfile)
					ivalue[3] = ReadByte(mfile)
					Local ix = ReadFloat(mfile)-width
					Local iy = ReadFloat(mfile)-height
					add_icon:Icon(iname,ix,iy,ivalue,True)
				Case "b"'backdrop
					Local namelen = ReadByte(mFile)
					Local bgname$ = ReadString(mfile, namelen)
					add_backdrop(bgname)
				EndSelect
			
			Until Eof(mfile)
			
			'make all the necessary entities via terrain
			For Local tx = 0 To game.cboxColNum-1
			For Local ty = 0 To game.cboxRowNum-1
				'actual absolute coords
				Local ax = tx*game.cboxSize-game.width
				Local ay = ty*game.cboxSize-game.height
				Select map[tx,ty,0]
				Case 3'asteroid
					add_asteroids(Rand(1,2), ax, ay, game.cboxSize)
				Case 4'anemonae
					For Local i = 0 To Rand(0,2)
						new_ship("Anemone",ax+Rand(0,game.cboxSize),ay+Rand(0,game.cboxSize))
					Next
				Case 5'exploding asteroid
					add_exploding_asteroids(Rand(1,2), ax, ay, game.cboxSize)
				EndSelect
			Next
			Next
			
			'set all ships to where their SQUADRONS start out
			For Local s:Ship = EachIn entityList
				If s.squad.setPos
					s.x = s.squad.x + Rand(-300,300)
					s.y = s.squad.y + Rand(-300,300)
				EndIf
			Next
			
			Return True
			
		Else
			RuntimeError "failed to load map:"+Lower(fileName)
			Return False
		EndIf
		
		
	EndMethod
	
	Method advance_stage()
		For Local t:Theatre = EachIn theatrePool
			'skip special arcade mode
			If t.special And Not pilot.VIP
				ListRemove(theatrePool, t)
				Continue
			EndIf
		
			'find the next stage in the theatre
			For Local s:Stage = EachIn t.stageList
				'are we trying to select the next stage?
				If stage = Null
					stage = s'select this one
					Exit
				EndIf
				'find the current stage
				If stage = s Then stage = Null
			Next
			'if we didn't find a new stage, advance to the next theatre
			If stage = Null
				theatres_completed:+ 1
				ListRemove(theatrePool, t)
			EndIf
			'only work with the first, active theatre
			Exit
		Next
		
		'if we finished this theatre (and removed it from the pool), time to select the first stage of the next one
		If stage = Null And Not ListIsEmpty(theatrePool) Then advance_stage()
		
		'reset the stage
		If stage <> Null Then stage.wave = 0
	EndMethod
	
	'draw & enforce soft, springy borders at the edge of the map
	Method borders()
		
		Local edgeforce# = .4
		
		'bounce ships
		For Local a:Ship = EachIn entityList
			If a.base.bio And (Abs(a.x) < width*1.2 And Abs(a.y) < height*1.2) Then Continue'bio entities get more leeway
			If a.x > width Then a.add_force(180, edgeforce*(Abs(a.x)-width))
			If a.x < -width Then a.add_force(0, edgeforce*(Abs(a.x)-width))
			If a.y > height Then a.add_force(270, edgeforce*(Abs(a.y)-height))
			If a.y < -height Then a.add_force(90, edgeforce*(Abs(a.y)-height))
		Next
		
		'bounce items
		For Local a:Item = EachIn itemList
			If a.x > width Then a.add_force(180, edgeforce*(Abs(a.x)-width))
			If a.x < -width Then a.add_force(0, edgeforce*(Abs(a.x)-width))
			If a.y > height Then a.add_force(270, edgeforce*(Abs(a.y)-height))
			If a.y < -height Then a.add_force(90, edgeforce*(Abs(a.y)-height))
		Next
		
		'draw a barrier
		Rem
		If globalCamRot = False
			SetColor 32,32,32
			SetAlpha .4
			SetScale 1,1
			SetRotation 0
			
			'right
			DrawRect -p1.x+width+SWIDTH/2-game.camxoffset,	p1.y-height-SHEIGHT/2-game.camyoffset, 	SWIDTH, 	height*2 + SHEIGHT*2
			'left
			DrawRect -p1.x-width-SWIDTH/2-game.camxoffset,	p1.y-height-SHEIGHT/2-game.camyoffset, 	SWIDTH, 	height*2 + SHEIGHT*2
			'bottom
			DrawRect -p1.x-width+SWIDTH/2-game.camxoffset, 	-p1.y+height+SHEIGHT/2-game.camyoffset,	width*2, 	SHEIGHT
			'top
			DrawRect -p1.x-width+SWIDTH/2-game.camxoffset,	-p1.y-height-SHEIGHT/2-game.camyoffset,	width*2, 	SHEIGHT
		EndIf
		EndRem
	EndMethod
	
	'calculates the number of rows and columns of cboxes on this map, initializes the lists
	Method setup_cbox()
		cboxColNum = Ceil(width*2) / cboxSize
		cboxRowNum = Ceil(height*2) / cboxSize
		'Print "mapsize: " + width+","+height + "   ["+cboxColNum+","+cboxRowNum+"]"
		
		For Local y = 0 To cboxRowNum-1
		For Local x = 0 To cboxColNum-1
			cboxList[x,y] = New TList
		Next
		Next
	EndMethod
	
	'sets the appropriate cbox to a terrain type (x,y are absolute ingame position coords, on same scale as entities)
	Method setTerrain(_x#,_y#,_terrain)
		Local cbx = Floor((width + _x) / cboxSize)
		Local cby = Floor((height + _y) / cboxSize)
		map[cbx,cby,0] = _terrain
	EndMethod
	
	Method new_objective(_text$, _flash = False, _x = 0, _y = 0, _ship:Ship = Null)
		Local o:Objective = New Objective
		o.text = _text
		o.tarx = _x
		o.tary = _y
		If _ship <> Null Then o.tarship = _ship.placeholder
		o.flash = _flash
		
		objectiveList.addLast(o)
	EndMethod
	
	'flash some text all big
	Method add_flashtext(_text$)
		flashtext = _text
		flashtext_timer = 4500
	EndMethod
	
	Method clear_flashtext()
		flashtext = ""
		flashtext_timer = 0
	EndMethod

	'draws the current flashing text, counts down the timer
	Method draw_flashtext()
		If flashtext <> "" And flashtext_timer > 0
			'draw the text
			SetRotation 0
			If flashtext_timer > 4200'FADE IN
				SetAlpha 1 - (flashtext_timer / 4500)
			ElseIf flashtext_timer < 400'FADE OUT
				SetAlpha (flashtext_timer / 400)
			Else'DISPLAY
				SetAlpha 1
			EndIf
			If globalFrame Then SetColor 198,198,198 Else SetColor 64,64,64
			SetScale 2,2
			draw_text(flashtext, SWIDTH/2 - TextWidth(flashtext), SHEIGHT/4)
			
			'count down the timer
			flashtext_timer:- frameTime
		EndIf
	EndMethod
	
	'tells the player they've died
	Method update_deadmessage()
		'if player dies, tell them they can switch ships
		If p1.armour <= 0
			If ListIsEmpty(mboxList)
				new_message("------- YOU ARE DEAD -------")
				new_message("PRESS ESCAPE")
			EndIf
		
		'remove death messages
		ElseIf Not ListIsEmpty(mboxList)
			For Local m:Messagebox = EachIn mboxList
				If m.message = "------- YOU ARE DEAD -------" Then ListRemove(mboxList,m)
				If m.message = "PRESS ESCAPE" Then ListRemove(mboxList,m)
			Next
		EndIf
	EndMethod

	'remove dead ships from the shipLists
	Method update_shipLists()
		For Local i = 0 To 7
			For Local s:Ship = EachIn shipList[i]
				If s.armour <= 0 Then ListRemove(shipList[i],s)
			Next
		Next
	EndMethod
	
EndType

Type Theatre'a series of arcades stages with the same theme (will keep loading maps from this until hits "" in map$[i]
	
	Field name$
	Field stageList:TList = New TList
	Field special = False'if only VIPs can access this theatre
	
	Method add_stage:Stage(_gametype,_map$,_music:TSound = Null, _shake_text$ = "")
		Local s:Stage = New Stage
		s.gameType = _gametype
		s.map = _map
		If _music = Null Then _music = mission1_music
		s.music = _music
		s.shake_text = _shake_text
		
		For Local i = 0 To 7
			s.waveList[i] = New TList
		Next
		
		stageList.addLast(s)
		Return s
	EndMethod
	
EndType
Function new_theatre:Theatre(_name$)
	Local t:Theatre = New Theatre
	t.name = _name
	theatreList.addLast(t)
	Return t
EndFunction

Type Stage'a single arcade mission

	Field wave				'the currently active wave

	Field map$				'the map to load
	Field waveList:TList[8]	'enemies to spawn on this wave (either a type of wave or specific ships)
	Field flash_text$[8]		'text to flash on any specific wave
	Field tutorial_text$[8]	'message to send on this wave is tutorial is enabled
	Field action[8]			'special action for this wave: 1=display waves left | 2=boss music!
	Field music:TSound
	Field gameType			'how to update and use this stage
	Field shake_text$			'shakytext to show at the start
	Field overhear_text$		'if got secret on previous map, get to overhear an additional message
	
	
	
	Field victory_text$[3]		'messages to send on completion of the mission
	
	Field spawnList:TList = New TList'temporary list used to compile ships for specific waves

	Method add_to_wave(_list, _name$, _num = 1)'adds a number of ships to the wavelist
		For Local i = 1 To _num
			waveList[_list].addLast(_name)
		Next
	EndMethod
	
	'returns a list of ships to spawn
	Method wave_spawnList:TList(_wave = -1)
		If _wave = -1 Then _wave = wave
		
		ClearList(spawnList)
		
		For Local waveType$ = EachIn waveList[_wave]
			Select waveType
			Case "human_fighters"
				Select Rand(0,3)
				Case 0
					add_spawn("Scrapper", Rand(3,4))
				Case 1
					add_spawn("Junker", 2)
				Case 2
					add_spawn("Scrapper", Rand(2,3))
					add_spawn("Junker", 1)
				Case 3
					add_spawn("Zukhov Mk II", 1)
				EndSelect
			Case "human_heavyfighters"
				Select Rand(0,2)
				Case 0
					add_spawn("Zukhov Mk II", 2)
				Case 1
					add_spawn("Trajectory", 2)
				Case 2
					add_spawn("Gunskipper", 1)
				EndSelect
			Case "human_turrets"
				Select Rand(0,2)
				Case 0
					add_spawn("Machinegun Turret", Rand(1,4))
				Case 1
					add_spawn("Snail Turret", Rand(1,4))
				Case 2
					add_spawn("Snail Turret", Rand(1,2))
					add_spawn("Machinegun Turret", Rand(1,2))
				EndSelect
			Case "AI_turrets"
				Select Rand(0,2)
				Case 0
					add_spawn("Turret", Rand(1,4))
				Case 1
					add_spawn("Missile Turret", Rand(1,4))
				Case 2
					add_spawn("Turret", Rand(1,2))
					add_spawn("Missile Turret", Rand(1,2))
				EndSelect
			Case "AI_fleas"
				add_spawn("Flea", Rand(3,5))
			Case "AI_drones"
				add_spawn("Drone", Rand(3,5))
			Case "AI_fodder"
				add_spawn("Drone", Rand(2,4))
				add_spawn("Flea", Rand(2,4))
			Case "AI_fighters"
				Select Rand(0,2)
				Case 0
					add_spawn("Lancer", Rand(2,3))
				Case 1
					add_spawn("Pillbug", Rand(1,2))
				Case 2
					add_spawn("Lamjet", 1)
				EndSelect
			Case "AI_cruisers"
				Select Rand(0,2)
				Case 0
					add_spawn("Carrier")
				Case 1
					add_spawn("Destrier")
				Case 2
					add_spawn("Lasareath")
				Case 3
					add_spawn("Frigate", 2)
				EndSelect
			Case "gaxlid_mites"
				add_spawn("Mite", Rand(6,12))
			Case "gaxlid_pack"
				Select Rand(0,2)
				Case 0
					add_spawn("Timberwolf", Rand(3,4))
				Case 1
					add_spawn("Litus Devil", Rand(2,3))
				EndSelect
			Default'must be just a normal ship name
				add_spawn(waveType)
			EndSelect
		Next
		
		Return spawnList
	EndMethod
	
	Method add_spawn(_name$, _num = 1)'adds a number of ships to the spawnlist
		Local wavenum = _num * Ceil(constrain(pilot.difficulty/2, .5, pilot.difficulty/2))
		For Local i = 1 To wavenum
			spawnList.addLast(_name)
		Next
	EndMethod
EndType

Const GAMETYPE_WAVES = 0'series of waves, until we run out of spawnLists
Const GAMETYPE_SURVIVAL = 1'survive for a limited amount of time
Const GAMETYPE_VECTOR = 2'play asteroids

Global theatreList:TList = New TList'list of all theatres
Global theatreStart:Theatre'always start on the same theatre
Function setup_stages()
	Local t:Theatre, s:Stage
	Local wav
	
	'----------------------------------------------AI GREENPLANET WAVES--------------------------------------------
	theatreStart = New Theatre
	theatreStart.name = "waves_greenplanet"
	t = theatreStart
	s = theatreStart.add_stage(GAMETYPE_WAVES, "arcade0", mission1_music, "YOU ARE MANKIND'S LAST HOPE")
	s.overhear_text$ = "'-unit's advisor software is online.'"
	wav = 0
	s.flash_text[wav] = "DESTROY INCOMING ENEMIES"
	wav:+1
	
	s.tutorial_text[wav] = " [ [thrust] ] to thrust.  [ LEFT-MOUSE ] to fire weapon."
	s.add_to_wave(wav, "Turret", 2)
	wav:+1
	
	s.add_to_wave(wav, "AI_drones")
	wav:+1
	
	s.tutorial_text[wav] = "Hold [ RIGHT-MOUSE ] to activate alternate weapon."
	s.add_to_wave(wav, "AI_drones")
	wav:+1
	
	s.tutorial_text[wav] = "Collect points to stronger become!"
	s.add_to_wave(wav, "AI_drones")
	s.add_to_wave(wav, "Turret", 2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	
	s.add_to_wave(wav, "AI_drones",2)
	wav:+1
	
	s = t.add_stage(GAMETYPE_WAVES, "arcade1", mission1_music, "VILE NEMESIS THREATENS US")
	s.overhear_text$ = "'-our military base fell under seige-'"
	wav = 0
	s.flash_text[wav] = "LANCER SCOUT DETECTED"
	wav:+1
	
	s.tutorial_text[wav] = "Aim at leading circle to score hits!"
	s.add_to_wave(wav, "Lancer")
	wav:+1
	
	s.tutorial_text[wav] = "[ [strafeleft]/[straferight] ] to strafe left/right."
	s.add_to_wave(wav, "AI_fleas")
	wav:+1
	
	s.tutorial_text[wav] = "[ [afterburn] ] to afterburn."
	s.add_to_wave(wav, "AI_fleas",2)
	wav:+1
	
	s.tutorial_text[wav] = "[ [map] ] to display map."
	s.add_to_wave(wav, "Turret", 2)
	s.add_to_wave(wav, "AI_drones")
	s.add_to_wave(wav, "AI_fleas")
	wav:+1
	
	s.add_to_wave(wav, "Turret", 4)
	s.add_to_wave(wav, "AI_fleas")
	wav:+1
	
	s.flash_text[wav] = "LANCER SQUADRON DETECTED"
	s.add_to_wave(wav, "Lancer", 3)
	wav:+1

	s.victory_text[0] = "A HERO IS YOU"
	s.victory_text[1] = "WE ARE IN THE RIGHT"
	s.victory_text[2] = "WE OFFERED NO PROVOCATION"
		
	s = t.add_stage(GAMETYPE_WAVES, "arcade8", mission1_music, "MINAT HAS EVERY CONFIDENCE IN YOU")
	s.overhear_text$ = "'-recommend immediate evacuation-'"
	wav = 0
	s.flash_text[wav] = "REMOVE VILE NEMESIS BEACH-HEAD"
	
	wav:+1
	s.tutorial_text[wav] = "[ [shield] ] to activate [ability]."
	s.add_to_wave(wav, "Turret", 12)
	wav:+1
	
	s.action[wav] = 2'boss music
	s.flash_text[wav] = "FRIGATE-CLASS DETECTED"
	s.add_to_wave(wav, "Frigate")
	s.add_to_wave(wav, "AI_drones",2)
	
	s.victory_text[0] = "UNIT [pilot] VICTORIOUS"
	s.victory_text[1] = "PERHAPS DANGEROUS ANOMOLY"
	s.victory_text[2] = "RECOMMEND VIGOROUS RESET"
	
	'------------------------------------------MINING SECTOR WAVES--------------------------------------
	t = new_theatre("waves_wealth")
	s = t.add_stage(GAMETYPE_WAVES, "arcade6", mission2_music, "SENSITIVE RESOURCES THREATENED")
	s.overhear_text$ = "'-them for personal errands like this-'"
	wav = 0
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_turrets")
	s.add_to_wave(wav, "AI_fodder")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder", 2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fighters")
	s.add_to_wave(wav, "AI_fodder")
	wav:+1

	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fighters")
	s.add_to_wave(wav, "AI_turrets")
	wav:+1
	
	s.victory_text[0] = "HUMAN INDEPENDENCE PROSPERS"
	s.victory_text[1] = "A BLOW STRUCK FOR THE COMMON MAN"
	s.victory_text[2] = "THEIR RICHES ARE OURS"
	
	s = t.add_stage(GAMETYPE_WAVES, "arcade9", mission2_music, "TRAITOR SUPPLY DEPOT DISCOVERED")
	s.overhear_text$ = "'-attacking neutral factions like this-'"
	wav = 0
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "Snail Turret", 2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "Machinegun Turret", 2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_fighters",2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_fighters")
	s.add_to_wave(wav, "Gunskipper", 1)
	wav:+1

	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_heavyfighters")
	s.add_to_wave(wav, "human_turrets",2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_fighters",2)
	s.add_to_wave(wav, "human_heavyfighters")
	wav:+1
	
	s.victory_text[0] = "NO BETTER THAN PIRATES"
	s.victory_text[1] = "ENABLERS OF THE ENEMY ARE THE ENEMY"
	s.victory_text[2] = "THEIR RICHES ARE OURS"
	
	s = t.add_stage(GAMETYPE_WAVES, "arcade9", mission2_music, "THEY COVET OUR WEALTH")
	s.overhear_text$ = "'-they're trying to take it back-'"
	wav = 0
	
	s.flash_text[wav] = "DESTROY ALL ENEMIES"
	s.add_to_wave(wav, "AI_fodder")
	s.add_to_wave(wav, "human_fighters")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_turrets")
	s.add_to_wave(wav, "AI_turrets", 3)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "human_heavyfighters")
	s.add_to_wave(wav, "AI_fighters")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder")
	s.add_to_wave(wav, "human_heavyfighters")
	wav:+1
	
	s.flash_text[wav] = "FRIGATES INBOUND"
	s.add_to_wave(wav, "Frigate", 1)
	s.add_to_wave(wav, "Gunskipper", 1)
	wav:+1
	
	s.victory_text[0] = "THE COMMONWEALTH IS SAVED"
	s.victory_text[1] = "YOU ARE THE HERO OF THE HOUR"
	s.victory_text[2] = "OUR LESSERS HAVE LEARNED THEIR PLACE"
	
	'------------------------------------------GAXLID DISCOVERY--------------------------------------
	t = new_theatre("waves_survival")
	'theatreStart = t'TESTING gaxlid stuff
	s = t.add_stage(GAMETYPE_WAVES, "arcade1", mission3_music, "STRANGE SIGNALS DETECTED")
	s.overhear_text$ = "'-sentries all disappeared-'"
	wav = 0
	
	's.flash_text[wav] = "SEARCH AND DESTROY: POSSIBLY PIRATES"
	's.add_to_wave(wav, "human_fighters")
	'wav:+1
	
	's.add_to_wave(wav, "human_heavyfighters",2)
	'wav:+1
	
	s.flash_text[wav] = "NOVEL LIFE-FORM DETECTED: PLEASE STAND BY"
	s.action[wav] = 3'zerg screech, music change
	s.add_to_wave(wav, "gaxlid_mites")',3)
	wav:+1
	
	s.flash_text[wav] = "LIFE-FORMS EXTREME PREJUDICE EXECUTE!"
	s.add_to_wave(wav, "gaxlid_pack")
	s.add_to_wave(wav, "gaxlid_mites")
	wav:+1
	
	s.flash_text[wav] = "ELIMINATE ALL WITNESS : #22"
	s.add_to_wave(wav, "Scrapper", 2)
	s.add_to_wave(wav, "gaxlid_pack")
	s.add_to_wave(wav, "gaxlid_mites",2)
	wav:+1
	
	s.add_to_wave(wav, "gaxlid_mites",3)
	wav:+1
	
	s.victory_text[0] = "MISSION DEBRIEFING CLASSIFIED"
	s.victory_text[1] = "EXECUTIVE ORDER #22 IN EFFECT"
	s.victory_text[2] = "STRICT ENFORCE NOW IN PLACE"
	
	s = t.add_stage(GAMETYPE_WAVES, "arcade3", mission3_music, "NOW ADDITIONAL ALIEN INVESTIGATION")
	s.overhear_text$ = "'-how far the infestation has-'"
	wav = 0
	
	s.flash_text[wav] = "ELECTRONIC INDICATORS IMPOSSIBLE"
	s.add_to_wave(wav, "gaxlid_mites")
	wav:+1
	
	s.add_to_wave(wav, "gaxlid_pack")
	s.add_to_wave(wav, "gaxlid_mites")
	wav:+1
	
	s.flash_text[wav] = "SPACE ANEMONES PROVIDE COVER"
	s.add_to_wave(wav, "gaxlid_mites", 4)
	wav:+1
	
	s.flash_text[wav] = "ELIMINATE ALL WITNESS : #22"
	s.add_to_wave(wav, "gaxlid_pack")
	s.add_to_wave(wav, "gaxlid_mites")
	s.add_to_wave(wav, "Freighter", 2)
	wav:+1
	
	s.add_to_wave(wav, "gaxlid_pack", 2)
	wav:+1
	
	s.add_to_wave(wav, "gaxlid_pack")
	s.add_to_wave(wav, "gaxlid_mites")
	s.add_to_wave(wav, "human_fighters")
	wav:+1
	
	s.add_to_wave(wav, "gaxlid_mites", 5)
	s.add_to_wave(wav, "AI_fodder",2)
	wav:+1
	
	s.victory_text[0] = "CONTINUE TO ELIMINATE WITNESS"
	s.victory_text[1] = "THE REGRETTABLE NECESSITY OF SECRECY"
	s.victory_text[2] = "FINAL INVESTIGATION NOW PROCEEDING"
	
	's = t.add_stage(GAMETYPE_SURVIVAL, "arcade11", mission3_music, "MASSIVE GAXLID PRESENCE")
	s = t.add_stage(GAMETYPE_WAVES, "arcade11", mission3_music, "MASSIVE GAXLID PRESENCE")
	s.overhear_text$ = "'-abandon [pilot], we can't risk-'"
	wav = 0
	
	s.flash_text[wav] = "NO SUPPORT GIVEN"
	s.add_to_wave(wav, "gaxlid_mites",4)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "gaxlid_pack",2)
	s.add_to_wave(wav, "gaxlid_mites",2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "gaxlid_mites", 4)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "gaxlid_pack",3)
	s.add_to_wave(wav, "gaxlid_mites")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "gaxlid_pack")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "gaxlid_mites",2)
	wav:+1
	
	s.flash_text[wav] = "FINAL INFESTATION ADJECENT"
	s.add_to_wave(wav, "gaxlid_pack",5)
	s.add_to_wave(wav, "gaxlid_mites", 3)
	wav:+1
	
	'----------------------------------------------DEEPSPACE WAVES--------------------------------------------
	t = new_theatre("waves_deepspace")
	s = t.add_stage(GAMETYPE_WAVES, "arcade4", mission2_music, "MASSIVE VILE NEMESIS INVASION")
	s.overhear_text$ = "'-we'll raze the planets they've taken-'"
	wav = 0
	s.flash_text[wav] = "DESTROY INCOMING ENEMIES"
	s.add_to_wave(wav, "AI_turrets")
	s.add_to_wave(wav, "AI_fodder")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder")
	s.add_to_wave(wav, "Frigate", 1)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_turrets")
	s.add_to_wave(wav, "AI_fodder",2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder")
	s.add_to_wave(wav, "AI_fighters")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_turrets",2)
	s.add_to_wave(wav, "AI_fighters")
	wav:+1
	
	s.flash_text[wav] = "DESTROY VERY DANGEROUS ALIEN"
	s.action[wav] = 4'cuttlefish healing point
	wav:+1
	
	s.action[wav] = 2'boss music
	s.flash_text[wav] = "LARGE MASS DETECTED"
	s.add_to_wave(wav, "AI_cruisers")
	wav:+1
	
	s.victory_text[0] = "STAGE I COMPLETED"
	s.victory_text[1] = "UNIT [pilot] MISSION SUCCESS"
	s.victory_text[2] = "PROCEEDING TO FURTHER DEPLOYMENT"
	
	s = t.add_stage(GAMETYPE_WAVES, "arcade2", mission2_music, "NEMESIS FLEET ATTEMPTING FLANK")
	s.overhear_text$ = "'-your gross ineptitude allowed them-'"
	wav = 0
	
	s.flash_text[wav] = "GREEN ALLIES DEPLOYED"
	s.add_to_wave(wav, "AI_fodder",3)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fighters",3)
	s.add_to_wave(wav, "AI_fodder",4)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fighters",2)
	s.add_to_wave(wav, "AI_cruisers")
	s.add_to_wave(wav, "AI_fodder",2)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fighters",3)
	s.add_to_wave(wav, "AI_fodder",2)
	wav:+1
	
	s.flash_text[wav] = "LARGE FLEA CONTINGENT INBOUND"
	s.add_to_wave(wav, "AI_fleas",7)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fleas",12)
	wav:+1
	
	s.victory_text[0] = "STAGE II COMPLETED"
	s.victory_text[1] = "THEIR MANUEVER IS DEFEATED"
	s.victory_text[2] = "PROCEEDING TO FURTHER DEPLOYMENT"
		
	s = t.add_stage(GAMETYPE_WAVES, "arcade15", boss_music, "MASSIVE FLEET ENGAGEMENT IMMANENT")
	wav = 0
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder",12)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder",5)
	s.add_to_wave(wav, "AI_fighters",7)
	s.add_to_wave(wav, "Frigate", 3)
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder",7)
	s.add_to_wave(wav, "AI_fighters",3)
	s.add_to_wave(wav, "AI_cruisers")
	wav:+1
	
	s.action[wav] = 1'display waves remaining
	s.add_to_wave(wav, "AI_fodder",6)
	s.add_to_wave(wav, "AI_fighters",3)
	s.add_to_wave(wav, "AI_cruisers",2)
	s.add_to_wave(wav, "Frigate", 4)
	wav:+1
	
	s.victory_text[0] = "STAGE III COMPLETED"
	s.victory_text[1] = "A GREAT VICTORY THIS DAY"
	s.victory_text[2] = "RESET ALL INVOLVED UNITS"
	
	'----------------------------------------------VECTOR ASTEROIDS--------------------------------------------
	t = new_theatre("vector_waves")
	t.special = True'VIP-only!
	s = t.add_stage(GAMETYPE_VECTOR, "arcade0", lilextra_music, "CALIBRATION TEST REQUIRED")
	s.overhear_text$ = "'-deviations from [pilot]'s protocol-'"
	wav = 0
	s.flash_text[wav] = "PLAYER 1"
	s.add_to_wave(wav, "Vector Asteroid 1", 4)
	s.add_to_wave(wav, "Vector Asteroid 2", 2)
	wav:+1

	s.add_to_wave(wav, "Vector Asteroid 1", 8)
	s.add_to_wave(wav, "Vector Asteroid 2", 3)
	wav:+1

	s.add_to_wave(wav, "Vector Asteroid 1", 3)
	s.add_to_wave(wav, "Vector Asteroid 2", 1)
	s.add_to_wave(wav, "Vector Ship", 1)
	wav:+1
	
	s.add_to_wave(wav, "Vector Asteroid 1", 8)
	s.add_to_wave(wav, "Vector Asteroid 2", 7)
	s.add_to_wave(wav, "Vector Ship", 2)
	wav:+1

	s.add_to_wave(wav, "Vector Asteroid 1", 3)
	s.add_to_wave(wav, "Vector Asteroid 2", 4)
	s.add_to_wave(wav, "Vector Ship", 3)
	wav:+1
	
	s.add_to_wave(wav, "Vector Asteroid 1", 5)
	s.add_to_wave(wav, "Vector Asteroid 2", 2)
	s.add_to_wave(wav, "Vector Frigate", 1)
	wav:+1
	
	s.add_to_wave(wav, "Vector Asteroid 1", 8)
	s.add_to_wave(wav, "Vector Asteroid 2", 2)
	s.add_to_wave(wav, "Vector Ship", 3)
	wav:+1
	
	s.action[wav] = 2'boss music
	s.add_to_wave(wav, "Vector Asteroid 1", 9)
	s.add_to_wave(wav, "Vector Asteroid 2", 3)
	s.add_to_wave(wav, "Vector Frigate", 2)
	s.add_to_wave(wav, "Vector Ship", 4)
	wav:+1
		
EndFunction

Type Objective
	Field text$
	Field tarx,tary		'absolute coords to point to
	Field tarship:Gertrude	'ship coords to point to
	Field flash = False
EndType

Function new_game(_gameType$)
	
	game = Null
	Local restarted = False
	Local lev:Level
	Repeat
		'If restarted Then Print "RESTARTED!"
		
		cleargame()
		
		'reset player ships 
		For Local s:Ship = EachIn pilot.fleetList
			s.reset()
		Next
		pilot.map_toggle = False
		
		pilot.psquad.setPos = False
		
		'starting selected alt guns = 1
		pilot.selgroup = 1
		pilot.pausemcoords[0] = SWIDTH/2
		pilot.pausemcoords[1] = SHEIGHT/2
		
		'make the new level settings
		lev = New Level
		lev.name = _gameType
		lev.intro_tween = 1
		lev.skipDeploy = restarted'skip ship choosing if we just restarted
		
		'make the backdrop for the game
		Local stars_gfx:TImage[2]
		stars_gfx[0] = stars1_gfx
		stars_gfx[1] = stars2_gfx
		lev.backdrop_gfx = stars_gfx
		
		initFactions()'all sides are friendly towards selves, neutral towards others
			
		'intialize the ship tracking lists
		For Local i = 0 To 7
			lev.shipList[i] = New TList
		Next
	
		'the game is not yet over
		lev.over = False
		
		'we'll fade the game in
		lev.currentfade = 1
		lev.fade = 0
	
		'begin the metagame, which launches the game
		lev.meta()
		
		'reset the player's forces
		For Local s:Ship = EachIn pilot.fleetList
			s.reset()
			s.x = 0
			s.y = 0
			s.speed = 0
			s.movrot = 0
			s.squad = pilot.psquad
		Next
		
		'if we go again, it's restarted
		restarted = True
	Until lev.restart = False
	
	cleanUp()

EndFunction

'clear the current game data away
Function cleargame()
	If game <> Null
		For Local cbx = 0 To 99
		For Local cby = 0 To 99
			game.cboxList[cbx,cby] = Null
			game.map[cbx,cby,0] = 0
			game.map[cbx,cby,1] = 0
		Next
		Next
		
		For Local i = 0 To 7
			game.bgs[i] = Null
			game.point[i] = Null
			game.ships[i] = Null
			game.squads[i] = Null
			game.shipList[i] = New TList
		Next
		
		ClearList(game.objectiveList)
		game.clear_flashtext()
		
		game.playTime = 0
		
		'reset the backdrop
		game.backdrop_gfx[0] = stars1_gfx
		game.backdrop_gfx[1] = stars2_gfx
		game.backdrop_rgb[0] = 0
		game.backdrop_rgb[1] = 0
		game.backdrop_rgb[2] = 0
	EndIf
	
	'set all factions to friendly towards selves, neutral to others
	initFactions()
	
	ClearList(entityList)
	ClearList(shotList)
	ClearList(bgList)
	ClearList(debrisList)
	ClearList(explodeList)
	ClearList(mboxList)
	ClearList(itemList)
	
	GCCollect()
EndFunction
