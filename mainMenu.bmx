'a pilot & his campaign are soon parted
Global pilot:Profile
Global pilotList:Profile[4]
Type Profile
	Field name$
	Field slot					'0-3, which pilot slot it fills
	
	Field VIP = False				'does this profile get the extra bells and whistles due to kickstarter?
	
	Field overhear = False			'have they unlocked the ability to get shards of handler conversation?
	Field selgroup				'active alternate weapon group
	Field selgroup_timer#			'timer to display newly selected weapon group
	Field pausemcoords[2]			'stores the mouse coords when you pause to be restored later
	Field map_toggle = False		'if the map is on or off
	Field psquad:Squadron			'the squad of ships the player controls
	
	Field fleetList:TList = New TList	'list of ships to bring into a game (squad = 0 ships don't get included when the game starts up)
	Field compList:TList = New TList	'list of stock components that the player can build / uniques available to place
	
	Field vectorUnlocked = False		'have they unlocked vector ship mode?
	
	Field tutSection				'the section of the tutorial they've selected
	Field hangerHelp = False		'if the help section of the hanger is toggled on or off

	Field points				'all the points this profile has collected, ever
	
	Field difficulty#				'the difficulty of gameplay (0=zen, anything else just modifies ship num & stats)
	
	'is this profile a VIP?
	Method checkVIP()
		Local vipnum, vipname$
		RestoreData vipnames
		ReadData vipnum
		For Local i = 1 To vipnum
			ReadData vipname
			If Upper(name) = Upper(vipname) Or Upper(name) = Upper(Replace(vipname,"_"," ")) Then VIP = True
		Next
	EndMethod
		
	'saves current stats to file
	Method save()
		'delete the old file
		DeleteFile("pilot/0"+slot+".pilot")
		'make the new file
		CreateFile("pilot/0"+slot+".pilot")
		'write to the new file
		Local pFile:TStream = WriteFile("pilot/0"+slot+".pilot")
			'SAVE PILOT
			WriteLine(pFile,	name)
			'save all the ships in fleetlist
			WriteByte(pFile,	CountList(fleetlist))
			For Local s:Ship = EachIn fleetList
				WriteByte(pFile,	Len(s.name))
				WriteString(pFile, s.name)
				'WriteByte(pFile,	Len(s.config))
				'WriteString(pFile, s.config)
			Next
			'save all the unlocked components
			WriteByte(pFile,	CountList(complist))
			For Local c:Component = EachIn compList
				WriteByte(pFile,	Len(c.name))
				WriteString(pFile, c.name)
			Next
			'save the number of points they have collected
			WriteInt(pFile,	points)
			'save the difficulty
			WriteFloat(pFile,difficulty)
		CloseFile pFile
		
		'if this is the currently selected pilot, open up rubicon.options and record it as such
		If pilot = Self
			'get all the lines of the old file
			Local opLine$[100]
			'read the options file
			Local optionFile:TStream = ReadFile("rubicon.options")	
				Local i = 0
				Repeat
					opLine[i] = Lower$(ReadLine$(optionFile))
					
					Local space = opLine[i].Find(" ")
			
					'if there are parameters
					If space <> -1
						'get the name
						Local optionName$ = opLine[i][..space]
					
						'overwrite the old line with the new information
						Select Lower(optionName)
						Case "current_pilot"
							opLine[i] = optionName + " " + pilot.name
						EndSelect
					EndIf
					
					i:+ 1
				Until Eof(optionFile)
			CloseStream optionFile
			
			
			'delete the old option file
			DeleteFile("rubicon.options")
			'make the new file
			CreateFile("rubicon.options")
			'write to the new file
			Local newFile:TStream = WriteFile("rubicon.options")
				'resave all the lines we got
				For Local i = 0 To 99
					If opLine[i] <> "" Then WriteLine(newFile, opLine[i])
				Next
			CloseFile newFile
		EndIf
	
	EndMethod
	
	'selects the next alternate weapon group (from 1 to 5)
	Method cycleweapons()
		Local oldgroup = pilot.selgroup
		Local newgroup = oldgroup
		Repeat
			newgroup = constrain((newgroup + 1) Mod 5, 1, 5)
			If newgroup = oldgroup Then Exit'if we don't have another weapon group
		Until Not ListIsEmpty(p1.gunGroup[newgroup])
		pilot.selgroup = newgroup
		
		'display the newly-selected weapon's name
		pilot.selgroup_timer = 1100
	EndMethod
	
	Method alreadyhave_ship(_name$)'have we unlocked this ship?
		Local alreadyhave = False
		For Local s:Ship = EachIn fleetList
			If _name = s.name
				alreadyhave = True
				Return True
			EndIf
		Next
		Return False
	EndMethod
	
	Method alreadyhave_component(_name$)'have we unlocked this component?
		Local alreadyhave = False
		For Local c:Component = EachIn compList
			If _name = c.name
				alreadyhave = True
				Return True
			EndIf
		Next
		Return False
	EndMethod
	
	Method unlock_ship(_ship$, _showtext = True)'_showtext says if we should tell the player they've unlocked it
		'unlock the first (or only) chassis in that list
		For Local c:Chassis = EachIn chassisList
			If c.name = _ship And Not alreadyhave_ship(_ship)'then unlock the ship!!
				Local newship:Ship = new_ship(c.name,0,0,"default",Null,False)
				fleetList.addLast(newship)
				
				If _showtext
					playSFX(unlock_sfx,-1,-1)
					shakytext(Upper(newship.name) + " unlocked!")
				EndIf
				
				'and all of its components!
				For Local comp:Component = EachIn newship.compList
					Local alreadyhave = False
					For Local pcomp:Component = EachIn compList
						If pcomp.name = comp.name Then alreadyhave = True
					Next
					If Not alreadyhave And comp.class <> "engine"'then unlock the component!
						unlock_component(comp.name,_showtext)
					EndIf
				Next
				
				'save this pilot to file
				save()
				
				Return True
			EndIf
		Next
		
		Return False
	EndMethod	
	
	'either unlock the next available component or a targeted one
	Method unlock_component(_comp$ = "",_showtext = True)'_showtext says if we should tell the player they've unlocked it
		'make a list of potentially unlockable components
		Local cList:TList = New TList
		For Local c:Component = EachIn componentList
			If (_comp = c.name) Or (_comp = "" And c.unlockable And (Not c.special Or VIP))'if unlockable, plus check if it's a special VIP-only ship
				cList.addLast(c)
				If _comp = c.name Then Exit'one-component list if we're targeting it
			EndIf
		Next
		'scramble the potential list of unlockables
		If _comp = "" Then cList = scrambleList(cList)
		'unlock the first (or only) component in that list
		For Local c:Component = EachIn cList
			Local alreadyhave = False
			For Local comp:Component = EachIn compList
				If c.name = comp.name
					alreadyhave = True
					Exit
				EndIf
			Next
			If Not alreadyhave'then unlock the component!
				Local newcomp:Component = new_comp(c.name)
				compList.addLast(newcomp)
				
				If _showtext
					playSFX(unlock_sfx,-1,-1)
					shakytext(Upper(newcomp.name) + " unlocked!")
				EndIf
				
				'save this pilot to file
				save()
				
				Return True
			EndIf
		Next
		
		Return False
	EndMethod
		
EndType

Function setup_pilots()
	Local slen
	'for each pilot slot
	For Local pslot = 0 To 3
		Local pFile:TStream = ReadFile("pilot/0"+pslot+".pilot")
		If pFile'if we have a saved pilot for this slot
			Local p:Profile = New Profile
			p.slot = pslot
			'LOAD PILOT
			p.name = ReadLine(pFile)
			'load all the player's ships
			Local shipNum = ReadByte(pFile)
			For Local i = 1 To shipNum
				slen = ReadByte(pFile)
				Local shipName$ = ReadString(pFile,slen)
				'slen = ReadByte(pFile)
				'Local shipConfig$ = ReadString(pFile,slen)
				p.fleetList.addLast(new_ship(shipName,0,0,"default",Null,False))
			Next
			'load all the player's components
			Local compNum = ReadByte(pFile)
			For Local i = 1 To compNum
				slen = ReadByte(pFile)
				Local compName$ = ReadString(pFile,slen)
				p.compList.addLast(new_comp(compName))
			Next
			'load the number of points they have collected
			p.points = ReadInt(pFile)
			'load the last-used difficulty
			p.difficulty = ReadFloat(pFile)
			
			'set it to the correct slot
			pilotList[p.slot] = p
			
			'is it a VIP?
			p.checkVIP()
			
			'some stuff the pilot needs for the game	
			p.psquad:Squadron = new_squad("hold",1,True)
			p.psquad.setPos = False'none of this now
		
			CloseFile pFile
		EndIf
	Next

	'is there a pilot set by the options?
	If SEL_PILOT <> "" And SEL_PILOT <> "null"
		For Local pslot = 0 To 3
			If pilotList[pslot] <> Null
				If Upper(pilotList[pslot].name) = Upper(SEL_PILOT) Then pilot = pilotList[pslot]'select this profile as the active pilot
			EndIf
		Next
	EndIf
EndFunction

Function new_pilot:Profile(_name$,_slot)
	Local prof:Profile = New Profile
	prof.name = Upper(_name$)
	prof.slot = _slot
	
	'is this pilot a VIP?
	prof.checkVIP()
	
	If prof.VIP
		playSFX(unlock_sfx,-1,-1)
		shakyText("SPECIAL EDITION UNLOCKED")
		FlushMouse()
	Else
		shakyText("WELCOME NEW PILOT " + prof.name + "!")
	EndIf
	
	'make the initial set of components
	'*I* get special stuff
	If Lower(_name) = "wik"
		For Local c:Component = EachIn componentList
			prof.compList.addLast(new_comp(c.name))
		Next
	Else
		prof.unlock_component("Plasma",False)
		prof.unlock_component("Peashooter",False)
		prof.unlock_component("Autocannon",False)
		prof.unlock_component("Shotgun",False)
		prof.unlock_component("Photon Launcher",False)
		prof.unlock_component("Missile Launcher",False)
		prof.unlock_component("Torpedo Launcher",False)
		prof.unlock_component("Damage Charger",False)
		If prof.VIP Then prof.unlock_component("Arc Caster",False)
		prof.unlock_component("Rerouter",False)
		prof.unlock_component("Armour",False)
		prof.unlock_component("Juicebox",False)
	EndIf
	
	'make the initial fleet	
	'*I* get special stuff!
	If Lower(_name) = "wik"
		For Local c:Chassis = EachIn chassisList
			prof.fleetList.addLast(new_ship(c.name,0,0,"",Null,False))
		Next
	'other people just get the starting ships
	Else
		prof.unlock_ship("Lamjet",False)
		prof.unlock_ship("Lancer",False)
		prof.unlock_ship("Zukhov Mk II",False)
		If prof.VIP Then prof.unlock_ship("Trajectory")
	EndIf
	
	prof.difficulty = .5	'new pilots start out on "normal" difficulty
	
	prof.hangerHelp = True		'default to helping them in the hanger, it'll be false when we load the profile instead
	
	'save this pilot to file
	prof.save()

	'some stuff the pilot needs for the game	
	prof.psquad:Squadron = new_squad("hold",1,True)
	prof.psquad.setPos = False'none of this now
	
	Return prof
EndFunction

Type MenuParticle
	Field x#,y#
	Field alpha#
	Field size
	
	Method draw()
		SetColor 255,255,255
		SetScale 1,1
		SetAlpha alpha
		DrawRect x,y,size,size
	EndMethod
	
	Method update(_speed# = 8.0)
		'alpha = alpha / _decay
		x:- alpha * _speed
		
		'reset?
		If x <= -20
			alpha = RndFloat() + .1
			size = Rand(5,15)
			x = SWIDTH + size
			y = 2*SHEIGHT/3 + alpha*(SHEIGHT/3)
		EndIf
	EndMethod
EndType
Global menuParticleList:TList = New TList
Global menuExhaustList:TList = New TList

'make the particles!
ClearList menuParticleList
For Local i = 0 To SWIDTH/15
	Local p:MenuParticle = New MenuParticle
	p.alpha = RndFloat() + .1
	p.x = Rand(150,450) - (200 * (1-p.alpha))
	p.y = 2*SHEIGHT/3 + p.alpha*(SHEIGHT/3)
	menuParticleList.addlast(p)
Next

'-------------------------------------------------------main MENU------------------------------------------------------------------------------------------
Function mainMenu()

	'centur the cursor
	moveCursor()

	'setup pilot select buttons
	Local pilotBList:Button[4]
	Local blankProfile$ = "- blank profile -"
	'make new pilot buttons
	For Local pslot = 0 To 3
		Local pb:Button = New Button
		pb.het = 25
		pb.wid = 268
		If pilotList[pslot] <> Null
			pb.text = pilotList[pslot].name
		Else
			pb.text = blankProfile
			pb.textbox = True
			pb.toggle = 1
		EndIf
		pilotBList[pslot] = pb
	Next
	
	'make the delete pilot button
	Local deleteB:Button = New Button
	deleteB.het = 30
	deleteB.wid = TextWidth("WHO ARE YOU PILOT:")
	deleteB.text = "DELETE PILOT"
	deleteB.x = SWIDTH - deleteB.wid
	deleteB.y = 0

	Local menuMode = 0'0:main menu|1:tutorial|2:profile select|3:exit
	Local buttonNum = 0
	Local jety# = SHEIGHT / 2', jetwaver# = 0, jettheta# = 0
	Local jetx# = -100
	Local jetspeed# = 0'speed up or down
	Local jettar# = jety
	
	'jump to profile select if there's not a valid pilot selected
	If pilot = Null Then menuMode = 2
	
	Local disableButton_timer = 0'when press a button, can't do it again for like 10 ms
	
	oldTime = MilliSecs()
	timePass = 22'just so no tricky stuff at the initial loop
	Repeat
		WaitTimer(frameTimer)
		Cls
		SetColor 255,255,255
		
		'mouse information
		Local m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		Local mc = MouseHit(1) Or (joyDetected And JoyHit(JOY_FIREPRIMARY))
		
		If disableButton_timer > 0 Then disableButton_timer:- frameTime
		
		updateTime()
		
		updateCursor(False)
		
		'update the particles
		For Local p:MenuParticle = EachIn menuParticleList
			p.draw
			p.update
		Next
		
		Local button_x = 3*SWIDTH/4-100, button_y = SHEIGHT/2-30
		
		SetAlpha 1
		SetScale 7,7
		SetColor 255,255,255
		SetRotation 0
		DrawText "RUBICON",120,80
		SetScale 2,2
		If pilot <> Null And menumode <> 2
			If pilot.VIP Then DrawText " [SPECIAL EDITION]",248,170
			If menuMode = 0'if we're doing main menu stuff
				Local welcometext$ = "- WELCOME PILOT "+Upper(pilot.name)+" -"
				DrawText welcometext$, button_x + TextWidth("[          ]") - TextWidth(welcometext$), button_y - 50
			EndIf
		EndIf
		
		Select menuMode
		
		Case 0'mainmenu
			buttonNum = 5
			DrawText "[   PLAY   ]",button_x,button_y
			DrawText "[  HANGAR  ]",button_x,button_y+25
			'DrawText "[ TUTORIAL ]",button_x,button_y+50
			DrawText "[  OPTION  ]",button_x,button_y+50
			DrawText "[  PILOTS  ]",button_x,button_y+75
			DrawText "[   EXIT   ]",button_x,button_y+100
			
		Case 1'tutorial
			DrawText "TUTORIAL SECTIONS:",button_x,button_y-50
			buttonNum = 4
			DrawText "[ WEAPONS ]",button_x,button_y
			DrawText "[ MOVEMENT ]",button_x,button_y+25
			DrawText "[ ABILITIES ]",button_x,button_y+50
			DrawText "[ BACK ]",button_x,button_y+75
			
			'also just give the controls
			DrawText "CONTROLS",110,SWIDTH
			
		Case 2'profile selection
			DrawText "WHO YOU ARE PILOT:",button_x,button_y-50
			If pilot <> Null Then buttonNum = 5 Else buttonNum = 4
			For Local pslot = 0 To 3
				SetColor 128,128,128
				pilotBList[pslot].update(m)
				pilotBList[pslot].x = button_x
				pilotBList[pslot].y = button_y+25*pslot
				
				Local buttontext$ = Upper(pilotBList[pslot].text)
				
				'if it's a blank profile
				If pilotList[pslot] = Null
					'if we've entered a profile, make the profile!
					If pilotBList[pslot].toggle = 1 And pilotBList[pslot].text <> blankProfile And pilotBList[pslot].text <> ""
						'make the new pilot
						pilotList[pslot] = new_pilot(pilotBList[pslot].text, pslot)
						'select this new pilot
						pilot = pilotList[pslot]
						'modify the button
						pilotBList[pslot].textBox = False
						pilotBList[pslot].toggle = 0
						'go to the main menu
						menumode = 0
					EndIf
					
					'when the button's not clicked, set the text to blank
					If pilotBList[pslot].toggle = 1 And pilotList[pslot] = Null Then pilotBList[pslot].text = blankProfile
					'when it is initially clicked, clear the text
					If pilotBList[pslot].toggle = 2 And pilotBList[pslot].text = blankProfile Then pilotBList[pslot].text = ""
					'as text is being entered...
					If pilotBList[pslot].toggle = 2
						'tell them to press enter when finished (flashing of course)
						SetColor 128,128,128
						If buttontext <> "" And globalFrame Then SetColor 255,255,255
						DrawText "[ENTER TO CONTINUE]",button_x,button_y+100
						'make it white & unselect the current pilot
						SetColor 255,255,255
						pilot = Null
						'and also flash an underscore
						If globalFrame
							If buttontext = "" Then buttontext = "[ enter text ]" Else buttontext:+ "_"
						EndIf
					EndIf
				
				'if it's a pilot's profile
				Else
					'white, bracketed if this profile is selected
					If pilotList[pslot] = pilot
						SetColor 255,255,255
						buttontext = "[ "+buttontext+" ]"
					EndIf
					
					'if we click it, select this profile
					If pilotBList[pslot].pressed = 2 Then pilot = pilotList[pslot]
				EndIf
					
				'draw whatever text is currently on the button
				DrawText buttontext,button_x,button_y+25*pslot
			Next
			
			SetColor 255,255,255
			If pilot <> Null
				'select button
				If globalframe Then SetColor 128,128,128'make it flash if it's available to click
				DrawText "[ SELECT ]",button_x,button_y+100
				
				'delete button
				deleteB.update(m)
				deleteB.draw()
			
				'press delete
				If deleteB.pressed = 0
					'confirm choice
					If confirm_menu("DELETE PILOT "+pilot.name+"?")
						'delete the old file
						DeleteFile("pilot/0"+pilot.slot+".pilot")
						'reset the button
						pilotBList[pilot.slot].text = blankProfile
						pilotBList[pilot.slot].textBox = True
						pilotBList[pilot.slot].toggle = 1
						'delete it from memory
						pilotList[pilot.slot] = Null
						pilot = Null
					EndIf
				EndIf
			EndIf
					
		Case 3'exit
			Exit
		EndSelect
		
		'click something?
		If (cursorx > button_x) And (cursorx < button_x + 240)
			For Local button = 0 To buttonNum-1
				If cursory >= button_y + (25 * button) And cursory < button_y + (25 * (button+1))
					SetColor 255,255,255
					DrawText "==>  |", button_x - 100, button_y + (25 * button)
	
					jettar = (button_y + (25 * button) + 15)
					
					If mc And disableButton_timer <= 0'if we click the mouse
						Local oldMode = menuMode
						
						Select menuMode
						Case 0'mainmenu
							If button = 0 Then new_game("arcade")
							If button = 1 Then hanger()		'ship hanger
							'If button = 2 Then menuMode = 1	'tutorial
							If button = 2 Then option_menu()	'options
							If button = 3 Then menuMode = 2	'profile select
							If button = 4 Then menuMode = 3	'exit
						Case 1'tutorial
							'if one of the tutorial buttons was pressed
							If button < 3
								pilot.tutSection = button
								new_game("tutorial")
							Else'if we pressed "back"
								menuMode = 0
							EndIf
						Case 2'pilot select
							If button = 4 And pilot <> Null
								menuMode = 0'back
								'and save all of the current pilots
								For Local pslot = 0 To 3
									If pilotList[pslot] <> Null Then pilotList[pslot].save()
								Next
							EndIf
						EndSelect
						
						FlushKeys()
						FlushMouse()
						FlushJoy()
						
						'did we switch menu modes?
						If menuMode <> oldMode Then playsfx(click_sfx, -1, -1)' Else PlaySound laserfire_sfx
						
						disableButton_timer = 40
					EndIf
				EndIf
			Next
		Else
			FlushMouse()
		EndIf
		
		'hit escape
		If KeyHit(KEY_ESCAPE)
			If menumode = 0 Or (pilot = Null)'can't skip pilot selection
				Exit
			Else
				menumode = 0
			EndIf
		EndIf
		
		'draw a big lamjet on the side of the screen
		delayFrameTimer:- timePass
		globalFrameSwitch = False
		If delayFrameTimer <= 0
			delayFrameTimer = delayFrame
			If globalFrame = 0 Then globalFrame = 1 Else globalFrame = 0
			globalFrameSwitch = True
		EndIf
		SetScale 1,1
		SetRotation 90
		SetColor 255,255,255
		'move the jet
		jetspeed = (jety - jettar)/10
		jety = jety - jetspeed
		Local jetxspeed# = (jetx - (SWIDTH/2-100))/10
		jetx = jetx - jetxspeed
		'exhaust comes out of the back
		Local p:MenuParticle = New MenuParticle
		p.alpha = 1
		p.size = 6 * (1+(jetxspeed/6)) + 1
		p.x = jetx - ImageWidth(lamjet[0])/2
		p.y = jety - 3
		menuExhaustList.addlast(p)
		'update all the exhaust
		For Local e:MenuParticle = EachIn menuExhaustList
			e.x = e.x - 6'move
			If e.x < e.size Then ListRemove(menuExhaustList, e)'die
			e.draw()'draw
		Next
		'draw the jet
		DrawImage lamjet[globalFrame], jetx, jety
		
		'if we're a VIP, we can click the jet to get secret arcade mode
		If pilot <> Null And pilot.VIP
			If ImagesCollide2(lamjet[globalFrame], jetx, jety, 0, 90, 1, 1, trail_gfx[0], cursorx, cursory, 0, 0, 1, .2)
				'tell them they can click
				SetScale 1,1
				SetColor 255,255,255
				SetRotation 0
				DrawText "v- SECRET ARCADE MODE -v", jetx - ImageWidth(lamjet[0])/2, jety - ImageHeight(lamjet[0])/2 - 20
				
				'if click it
				If mc And disableButton_timer <= 0
					new_game("vector")
					disableButton_timer = 40
				EndIf
			EndIf
		EndIf
		
		If current_music <> theme_music Then new_music = theme_music
		timePass:* 1000'for SOME fuckin reason
		updateMusic()
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		draw_cursor()
		Flip
	Forever
EndFunction

'draws a bordered rectangle in the rubicon-appropriate style
Function drawBorderedRect(x,y,wid,het,RGB[] = Null)
	'draw the border
	SetColor 32,32,32
	DrawRect x,y,wid,het
	SetColor 128,128,128
	DrawRect x+2,y+2,wid-4,het-4
	SetColor 32,32,32
	DrawRect x+4,y+4,wid-8,het-8

	'do we use the input or default color?
	If RGB <> Null Then SetColor RGB[0],RGB[1],RGB[2] Else SetColor 13,11,27

	'draw the main box
	DrawRect x+6,y+6,wid-12,het-12
	
	SetColor 255,255,255
EndFunction
