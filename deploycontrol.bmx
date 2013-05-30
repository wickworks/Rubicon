'a little graphic showing beginning deployment stuff
Type Icon
	Field name$
	Field x,y
	Field value[4]		'modifies what this icon does (value[2] is generally the frame of the icon array)
	Field squad:Squadron	'the squadron any ships this spawns is part of
	Field visible		'TRUE/FALSE, whether this icon should be visible or is just for spawning enemy squadrons
EndType
Include "new_icon.bmx"

'lets you choose your ship, go to the hanger, or back out
Function deployment(_lev:Level)
	'launch: 0=back | 1=launch misssion | 2 = hanger
	Local launch = 0
	
	'repeat until we either launch or back out
	Repeat
		launch = deployment_loop(_lev)
		
		'go to the hanger?
		If launch = 2 Then hanger()
	Until launch = 0 Or launch = 1

	Return launch
EndFunction

'choose your ship
Function deployment_loop(_lev:Level)
	FlushKeys()
	FlushMouse()
	
	'set up the buttons and whatnot
	'------------------------------
	
	'back button
	Local backB:Button = New Button
	backB.text = "Back"
	backB.wid = 112
	backB.het = 30
	backB.x = 0
	backB.y = 0

	'hanger button
	Local hangerB:Button = New Button
	hangerB.text = "Hangar"
	hangerB.wid = 112
	hangerB.het = 30
	hangerB.x = SWIDTH - hangerB.wid
	hangerB.y = 0
	
	'mission launch button
	Local launchB:Button = New Button
	launchB.text = "Launch"
	launchB.text_scale = 2
	launchB.wid = 196
	launchB.het = 90
	launchB.x = SWIDTH - launchB.wid - 2
	launchB.y = SHEIGHT - launchB.het - 2
	launchB.rgb[0] = 148
	launchB.rgb[1] = 60
	launchB.rgb[2] = 60
	
	'back and forth arrows
	'...for the configuration
	Local configWid = 128'how much space to give the configuration text
	
	Local prevConfigB:Button = New Button
	prevConfigB.text = "<"
	prevConfigB.wid = 22
	prevConfigB.het = 22
	prevConfigB.x = SWIDTH/2 - configWid/2 - prevConfigB.wid
	prevConfigB.y = 0'will be set later
	prevConfigB.skipBorder = True
	prevConfigB.skipbar = True
	
	Local nextConfigB:Button = New Button
	nextConfigB.text = ">"
	nextConfigB.wid = prevConfigB.wid
	nextConfigB.het = prevConfigB.het
	nextConfigB.x = SWIDTH/2 + configWid/2
	nextConfigB.y = 0
	nextConfigB.skipBorder = True
	nextConfigB.skipbar = True
	
	'...for the ships
	Local prevShipB:Button = New Button
	prevShipB.text = "<"
	prevShipB.text_scale = 3
	prevShipB.wid = 74
	prevShipB.het = 190
	prevShipB.x = SWIDTH/2 - configWid*2 - prevShipB.wid
	prevShipB.y = (SHEIGHT - prevShipB.het) / 2.5
	prevShipB.skipbar = True
	
	Local nextShipB:Button = New Button
	nextShipB.text = ">"
	nextShipB.text_scale = 3
	nextShipB.wid = prevShipB.wid
	nextShipB.het = prevShipB.het
	nextShipB.x = SWIDTH/2 + configWid*2
	nextShipB.y = prevShipB.y
	nextShipB.skipbar = True
	
	'unlock ship button
	Local unlockB:Button = New Button
	unlockB.text = "UNLOCK"
	unlockB.text_scale = 2
	unlockB.wid = launchB.wid
	unlockB.het = launchB.het
	unlockB.x = SWIDTH/2 - unlockB.wid/2
	unlockB.y = SHEIGHT/2
	
	'difficulty buttons
	Local difficultyBList:TList = New TList
	For Local i = 1 To 4
		Local db:Button = New Button
		db.skipborder = True
		db.wid = 30
		db.het = 20
		db.toggle = 1
		db.tab = True
		difficultyBList.addLast(db)
		
		Select i
		Case 1
			db.text = "Z"
		Case 2
			db.text = "1"
		Case 3
			db.text = "2"
		Case 4
			db.text = "3"
		EndSelect
		
		'find which one is initially toggled
		Select pilot.difficulty
		Case 0
			If i = 1 Then db.toggle = 2
		Case .5
			If i = 2 Then db.toggle = 2
		Case 1
			If i = 3 Then db.toggle = 2
		Case 3
			If i = 4 Then db.toggle = 2
		EndSelect
	Next
	
	Local texthet = TextHeight("BOBCAT")
	
	'space for the ship's name all big
	Local namewid = 300
	Local namehet = 64
	
	'space for the ship all big
	Local shiphet = 256
	
	'space for the stats
	Local statwid = 206
	Local stathet = 138
	
	'the number of ships available to deploy
	Local ship:Ship[64]
	'convert fleetlist to an array
	Local i
	'make an entry for each available ship
	For Local c:Chassis = EachIn chassisList
		Local alreadyhave = False
		For Local s:Ship = EachIn pilot.fleetList
			If c.name = s.name
				ship[i] = s
				i:+ 1
				alreadyhave = True
				Exit
			EndIf
		Next
		
		If Not alreadyhave'if we have to make a new placeholder ship for this entry
			If c.unlockable And (Not c.special Or pilot.VIP)'if unlockable, plus check if it's a special VIP-only ship
				ship[i] =  new_ship(c.name,0,0,"",Null,False)
				i:+ 1
			EndIf
		EndIf	
	Next
	Local fleetNum = i'CountList(pilot.fleetList) ' how many ships we can look at, unlocked or locked
	
	'the current place in the fleet array
	Local sel = 0
	
	'the currently selected ship's image
	Local scale = findMaxScale(ship[sel].gfx[0], shiphet)
	Local selship_gfx:TImage = resizeImage(ship[sel].gfx[0], scale-1)
	
	'the image of the previously selected ship as it tweens out
	Local selship_old_gfx:TImage
	Local selship_tween#			'tracks the tweening of changing selected ship, decays to 0 (negative: scrolling left | positive: scrolling right)
	Local selship_tween_decay# = .035'how fast the tween decays
	
	'did we just unlock a ship? (used for updating the graphic)
	Local justunlocked = False
	
	'launch: 0=back | 1=play mission | 2=hanger
	Local launch = 0
	p1 = Null
	
	'============================================================================================== MAIN LOOP ============================================
	Repeat
		Cls
		updateTime()
		
		'mouse information
		updateCursor()
		Local m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		
		'draw the grid background
		SetRotation 0
		SetScale 1,1
		SetAlpha 1
		SetColor 16,16,35
		TileImage grid_gfx
		
		'mission launch button
		launchB.update(m)
		launchB.draw()
		If launchB.pressed = 2
			launch = True
			Exit
		EndIf
		'make the button flash if it's active
		If launchB.active
			If globalFrame
				launchB.rgb[0] = 178
				launchB.rgb[1] = 60
				launchB.rgb[2] = 60
			Else
				launchB.rgb[0] = 128
				launchB.rgb[1] = 60
				launchB.rgb[2] = 60
			EndIf
		EndIf


		
		'---------------------------------------------------- DIFFICULTY SELECTION -----------------------------------------------------
		SetScale 1,1
		drawBorderedRect(0, SHEIGHT - launchB.het, launchB.wid, launchB.het)
		SetScale 2,2
		draw_text("DIFFICULTY:", 10, SHEIGHT - launchB.het + 10)
		Local i, diff$, desc$[3]
		For Local db:Button = EachIn difficultyBList
			db.x = 8 + (db.wid+20)*i
			db.y = SHEIGHT - launchB.het + 10 + texthet + 14

			db.draw()
			db.update(m)
			
			'if we just toggled this one
			If db.pressed < 5 And db.toggle = 2
				'untoggle the others
				For Local o:Button = EachIn difficultyBList
					If o <> db Then o.toggle = 1
				Next
			EndIf
			
			'if this one is toggled
			If db.toggle = 2
				Select i
				Case 0
					desc[2] = "ZEN MODE"
					desc[1] = "Cycle of rebirth; unlimited lives."
					desc[0] = "Little challenge means little reward."
					diff = "- Zen -"
					pilot.difficulty = 0
				Case 1
					desc[2] = "NORMAL MODE"
					desc[1] = "Play through series of waves."
					desc[0] = "Tutorial text enabled."
					diff = "- Normal -"
					pilot.difficulty = .5
				Case 2
					desc[2] = "HARD MODE"
					desc[1] = "Powerful enemies."
					desc[0] = "x2 points"
					diff = "- Hard -"
					pilot.difficulty = 1
				Case 3
					desc[2] = "REALLY? MODE"
					desc[1] = "Many powerful enemies."
					desc[0] = "x3 points"
					diff = "- Really? -"
					pilot.difficulty = 3
				EndSelect
				
				'have it flash
				If globalFrame
					db.RGB[0] = 255
					db.RGB[1] = 180
					db.RGB[2] = 60
				Else
					db.RGB[0] = 215
					db.RGB[1] = 140
					db.RGB[2] = 60
				EndIf
			
			Else'default colors
				db.RGB[0] = 0
				db.RGB[1] = 0
				db.RGB[2] = 0
			EndIf
			
			i:+ 1
		Next
		SetColor 255,255,255
		draw_text(diff, launchB.wid/2 - TextWidth(diff)/2, SHEIGHT - 8 - texthet)
		'difficulty description text
		For i = 0 To 2
			If desc[i] <> "" Then draw_text("- " + desc[i], 2, SHEIGHT - launchB.het - 20 - (texthet*i))
		Next
		
		'---------------------------------------------------- SELECTED SHIP -----------------------------------------------------
		'do we own the currently selected ship?
		Local ownCurrentShip = pilot.alreadyhave_ship(ship[sel].name)
		
		'stores the height to draw the bigshipgfx
		Local selship_y
		
		'draws all of the stats and numbers and whatnot for the selected ship (and get the above height)
		selship_y = shiphet/2 + draw_shipbar(ship[sel], ownCurrentShip)
		
		'draw the currently selected ship
		If selship_tween = 0
			DrawImage selship_gfx, SWIDTH/2, selship_y
			
		Else'tween the transition of switching ship
			Local inMod# = Abs(selship_tween)			'goes from 1 to 0
			Local outMod# = Abs(Abs(selship_tween)-1)	'goes from 0 to 1
		
			'where to draw the scrolling ships
			Local tweenx = (SWIDTH/2) + 300
			Local tweeny = 14'nextShipB.y - nextShipB.het
			
			'draws the new ship coming in
			SetScale .2 + (outMod/1.25), .5 + (outMod/2)
			SetScale outMod,outMod
			DrawImage selship_gfx, SWIDTH/2 + tweenx*inMod*Sgn(selship_tween), selship_y + (tweeny*inMod)^2
			
			'draws the old ship going out
			SetScale .2 + (inMod/1.25), .5 + (inMod/2)
			SetScale inMod,inMod
			DrawImage selship_old_gfx, SWIDTH/2 - tweenx*outMod*Sgn(selship_tween), selship_y + (tweeny*outMod)^2						'it's outMod'ed
			
			'decay the tween
			If Abs(selship_tween) <= selship_tween_decay Then selship_tween = 0 Else selship_tween:- selship_tween_decay*Sgn(selship_tween)
		EndIf
			
		
		'if we've unlocked this ship
		If ownCurrentShip
			'config-change buttons
			Local yconfig = (SHEIGHT / 40)*3 + 64 + 256 - 24'be a cheatyface and a bad programmer
			SetColor 150,105,50
			SetScale 1,1
			draw_text(ship[sel].config, SWIDTH/2 - TextWidth(ship[sel].config)/2, yconfig + 12)'current config name
			yconfig:+ 6
			
			prevConfigB.y = yconfig
			prevConfigB.update(m)
			prevConfigB.draw()
			
			nextConfigB.y = yconfig
			nextConfigB.update(m)
			nextConfigB.draw()

			launchB.active = True
			
		Else'if we still need to pay up
			'points icon so they know what we're talking about
			SetColor 255,255,255
			SetScale 1,1
			DrawImage bigpoint_gfx, SWIDTH/2 + 48, SHEIGHT/3.5 + 10
			
			'say how many points this costs
			SetScale 2,2
			SetColor 198,198,198
			If pilot.points >= ship[sel].base.cost
				SetColor 255,255,255
				If globalFrame Then SetColor 255,140,1'flash if have enough to unlock
			EndIf
			draw_text(ship[sel].base.cost, SWIDTH/2 - TextWidth(ship[sel].base.cost)*1.5, SHEIGHT/3.5)
			draw_text("TO UNLOCK", SWIDTH/2 - TextWidth("TO UNLOCK"), SHEIGHT/3.5 + 40)
			
			'update + draw the unlock button itself
			unlockB.update(m)
			unlockB.draw()
			
			'if we try to unlock the ship
			If unlockB.pressed = 2
				If pilot.points >= ship[sel].base.cost'if we have enough points
					If pilot.unlock_ship(ship[sel].name, False)
						'pay for it
						pilot.points:- ship[sel].base.cost
						'kaching!
						playSFX(unlock_sfx,-1,-1)
						'the last ship in the fleetlist is the actual ship now, replace the placeholder
						Local tempList:TList = New TList
						tempList.addLast(pilot.fleetList.last())
						For Local s:Ship = EachIn tempList
							ship[sel] = s
						Next
						'reset the big graphic
						justunlocked = True
						'save the pilot
						pilot.save()
					EndIf
				EndIf
			EndIf
			
			'draw the number of points that the pilot currently has
			SetScale 2,2
			SetColor 255,255,255
			draw_text("YOU HAVE", SWIDTH/2 - TextWidth("YOU HAVE"), unlockB.y + unlockB.het + 115 - texthet*2.5)
			draw_text(pilot.points, SWIDTH/2 - TextWidth(pilot.points)*1.5, unlockB.y + unlockB.het + 115)
			SetScale 1,1
			DrawImage bigpoint_gfx, SWIDTH/2 + 48, unlockB.y + unlockB.het + 125
			
			'can't launch with a locked ship
			launchB.active = False
		EndIf
		
		
		'--------------------------------------- CHANGE SHIP BUTTONS ------------------------------------------------------------------
		prevShipB.update(m)
		prevShipB.draw()
		
		nextShipB.update(m)
		nextShipB.draw()
		
		Local shipchange = 0
		If prevShipB.pressed = 2 Then shipchange = -1
		If nextShipB.pressed = 2 Then shipchange = 1
		
		'if we've changed the ship
		If shipchange <> 0 Or justunlocked
			
			'wrap the ship selection
			sel:+ shipchange
			If sel < 0 Then sel = fleetNum - 1
			If sel >= fleetNum Then sel = 0
			
			'store the old bigship graphic
			selship_old_gfx = selship_gfx
			
			' - new bigship graphic -
			Local scale = findMaxScale( ship[sel].gfx[0], shiphet ) 'find how big we can resize the image
			
			'if it's not unlocked yet, black it out
			If Not pilot.alreadyhave_ship(ship[sel].name)
				selship_gfx = getHitImage(ship[sel].gfx[0], False)
				selship_gfx = resizeImage(selship_gfx, scale-1)'and resize it
			Else'just resize it
				selship_gfx = resizeImage(ship[sel].gfx[0], scale-1)
			EndIf
			
			'tween its transistion in
			selship_tween = shipchange
			
		EndIf
		justunlocked = False
		
		
		'--------------------------------------- CHANGE CONFIGURATION BUTTONS ----------------------------------------------------------
		Local confchange = 0
		If prevConfigB.pressed = 2 Then confchange = -1
		If nextConfigB.pressed = 2 Then confchange = 1
		
		'if we've changed the configuration
		If confchange
			'stores the first and last configuration names for this ship (for wrapping)
			Local firstConfig$, lastConfig$
			
			'the new configuration (starts out looking for the current configuration)
			Local newConfig$ = ship[sel].config
		
			'get a list of all the configuration names
			Local configFiles$[] = LoadDir("configs\")
			'go through each and get the name of the configuration
			For Local con$ = EachIn configFiles
				'if this configuration file is for this ship
				If Left(con,Len(ship[sel].name)) = ship[sel].name
					'if this configuration file is unlocked for this profile
					If configAvailable(con, ship[sel].name, pilot)
						'find the name of the config
						Local conName$ = con
						conName = Right(conName,Len(conName)-Len(ship[sel].name)-1)			'trim the name of the ship
						conName = Left(conName,Len(conName)-5)						'trim the ".conf"
						If Right(conName, Len(pilot.name) + 1) = "_"+Lower(pilot.name)
							conName = Left(conName, Len(conName) - (Len(pilot.name) + 1))	'trim the CURRENT pilot's name
						EndIf
						
						'are we looking for a new one?
						If confchange = 1 And newConfig = "" Then newConfig = conName
						
						'is this the name of the current configuration?
						If Lower(conName) = Lower(ship[sel].config)
							'going up
							If confchange = 1 Then newConfig = ""'start looking for a new config
							'going down
							If confchange = -1 Then newConfig = lastConfig'use the previous configuration
						EndIf
	
						'is this the first one we've found?
						If firstConfig = "" Then firstConfig = conName
						
						'if we store each one, we'll end up storing the last one
						lastConfig = conName
						
						'if we found a new config, quit this
						If newConfig <> "" And Lower(newConfig) <> Lower(ship[sel].config) Then Exit
					EndIf
				EndIf
			Next
			
			'if we're going UP one and never found a configuration after the current one, use the first one
			If confchange = 1 And newConfig = "" Then newConfig = firstConfig
			
			'if we're going DOWN one and never found a configuration before the current one, use the last one
			If confchange = -1 And newConfig = "" Then newConfig = lastConfig
			
			'set the configuration to the new one
			ship[sel].config = newConfig
			ship[sel].load_config(newConfig)
		EndIf
		
		
		'----------------- alternative exit buttons -----------------------------
		backB.update(m)
		backB.draw()
		If backB.pressed = 2 Or KeyHit(KEY_ESCAPE) Then Return 0'back out
		
		hangerB.update(m)
		hangerB.draw()
		If hangerB.pressed = 2
			launch = 2'to to the hanger
			Exit
		EndIf
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program

		updateMusic()

		draw_cursor()
		Flip
	Forever

	'set the player's ship
	p1 = ship[sel]
	p1.squad = pilot.psquad
	p1.behavior = "player"
	'add the player to the game
	p1.link = entityList.addLast(p1)

	FlushKeys()
	FlushMouse()
	
	Return launch '0=back out | 1=launch the mission | 2=go to the hanger
End Function

'draws a ship, its name, stats and loadout all in the center of the screen									'CODE WELL OR CODE FAST???
'RETURNS the y coord to draw the big ship graphic															'(  sorry, future me...  )
Function draw_shipbar(_ship:Ship, _unlocked = True)
	Local texthet = TextHeight("BOBCAT")
	
	'space for the ship's name all big
	Local namewid = 450
	Local namehet = 64
	
	'space for the ship all big
	Local shiphet = 256
	
	'space for the stats
	Local statwid = 206
	Local stathet = 138

	Local yspace = SHEIGHT / 40'how much space between each element
	Local ybar = yspace'where we are in drawing a thing
	
	'ship name panel
	SetScale 1,1
	drawBorderedRect(SWIDTH/2-namewid/2, ybar, namewid, namehet)
	SetScale 3,3
	draw_text(_ship.name, SWIDTH/2-TextWidth(_ship.name)*3/2, ybar + (namehet - texthet*3)/2)
	SetScale 1,1
	ybar:+ namehet + yspace
	
	'store the location for the ship graphic
	Local biggfx_y = ybar
	
	'space for the big ship graphic
	ybar:+ shiphet + (yspace*2)
	
	If _unlocked
		'draw the stats
		drawBorderedRect(SWIDTH/2-statwid/2, ybar, statwid, stathet)
		
		draw_stats(_ship, SWIDTH/2-statwid/2+9, ybar + 9)	'(in hangercontrol.bmx)
		ybar:+ stathet + yspace
		
		'update the loadout
		tallyComponents(_ship, False)'2, SWIDTH/6 - 70, SHEIGHT/2+50)
		Local loadouthet
		'see how many lines of components we got
		For Local i = 0 To 15
			If loadout[i,0] = ""
				loadouthet = (i+1)*textHet
				Exit
			EndIf
		Next
			
		'loadout box
		SetColor 255,255,255
		draw_text("Current Loadout:", SWIDTH/2-TextWidth("Current Loadout:")/2, ybar - texthet)
		drawBorderedRect(SWIDTH/2-statwid/2, ybar, statwid, loadouthet)
			
		'list of installed components
		For Local i = 0 To 15
			If loadout[i,0] <> ""
				Local textx = SWIDTH/2-statwid/2 + 8
				Local texty = ybar + i*textHet + 8
				
				'list the component
				If loadout[i,2] = "" Then SetColor 255,255,255 Else SetColor 208,105,100
				If loadout[i,1] = "1" Or loadout[i,1] = ""'if there's no quantity
					draw_text(loadout[i,0], textx, texty)
				Else
					draw_text(loadout[i,0] + " x"+loadout[i,1], textx, texty)
				EndIf
			EndIf
		Next
	EndIf
	
	'returns y location to draw the big draw ship
	Return biggfx_y
EndFunction

'find how big we can resize an image and still have it fit in a box
Function findMaxScale(_gfx:TImage, _boxhet, _min = 2, _max = 7)
	Local scale
	For scale = _min To _max
		If ImageHeight(_gfx)*scale < _boxhet Then Continue Else Exit
	Next
	Return scale
EndFunction

'returns and RGB array containing the appropriate player squad color
Function getSquadColor[](_groupID)
	Local RGB[3]
	Select _groupID
	Case 1'blue
		RGB[0] = 64
		RGB[1] = 64
		RGB[2] = 128
	Case 2'green
		RGB[0] = 84
		RGB[1] = 127
		RGB[2] = 61
	Default'grey
		RGB[0] = 64
		RGB[1] = 64
		RGB[2] = 64
	EndSelect
	Return RGB
EndFunction


