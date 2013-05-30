'adjust gameplay options, audio, controls
Function option_menu()
	'make the buttons
	
	'resume game button
	Local resumeB:Button = New Button
	resumeB.text = "<- RETURN"
	resumeB.wid = 160
	resumeB.het = 60
	resumeB.x = 0
	resumeB.y = 0
	
	'general options button
	Local gameB:Button = New Button
	gameB.text = "GAME"
	gameB.wid = 160
	gameB.het = 40
	gameB.x = 200
	gameB.y = 100
	gameB.toggle = 2
	gameB.tab = True
	
	'audio button
	Local audioB:Button = New Button
	audioB.text = "AUDIO"
	audioB.wid = 160
	audioB.het = 40
	audioB.x = gameB.x + gameB.wid
	audioB.y = 100
	audioB.toggle = 1
	audioB.tab = True
	
	'game option buttons
	'invincibility cheat
	Local cheat_invincB:Button = New Button
	cheat_invincB.text = "Invincibility"
	cheat_invincB.wid = 142
	cheat_invincB.het = 30
	cheat_invincB.toggle = 1
	
	'screen resolution options
	Local resoBList:TList = New TList
	For Local r = 0 To 7
		Local resoB:Button = New Button
		resoB.wid = 142
		resoB.het = 30
		Select r
		Case 0
			resoB.text = "FULLSCREEN"
		Case 1
			resoB.text = "FIT TO SCREEN"
		Case 2
			resoB.text = "1920 x 1200"
		Case 3
			resoB.text = "1360 x 768 "
		Case 4
			resoB.text = "1280 x 768 "
		Case 5
			resoB.text = "1024 x 768 "
		Case 6
			resoB.text = "960 x 600"
		Case 7
			resoB.text = "800 x 600"
		EndSelect
		
		resoBList.addLast(resoB)
	Next
	
	'fullscreen toggler
	'Local fullscreenB:Button = New Button
	'fullscreenB.text = "Fullscreen"
	'fullscreenB.wid = 64
	'fullscreenB.het = 30
	'If GraphicsDepth() = 2 Then fullscreenB.toggle = 2 Else fullscreenB.toggle = 1
	
	'list of buttons to set the scale of different audio levels
	Local audio_sndBList:TList = New TList'global volume
	Local audio_sfxBList:TList = New TList'sound effect volume
	Local audio_musicBList:TList = New TList'music volume
	
	For Local l = 0 To 2'which list we're working with
		Local BList:TList
		If l = 0 Then BList = audio_sndBList
		If l = 1 Then BList = audio_sfxBList
		If l = 2 Then BList = audio_musicBList
		For Local i = 0 To 4
			Local vb:Button = New Button
			vb.skipborder = True
			vb.wid = 20
			vb.het = 30
			BList.addLast(vb)
		Next
	Next
		
	
	'controls button
	Local controlB:Button = New Button
	controlB.text = "CONTROLS"
	controlB.wid = 160
	controlB.het = 40
	controlB.x = gameB.x + gameB.wid + audioB.wid
	controlB.y = 100
	controlB.toggle = 1
	controlB.tab = True
	
	'reset to default controls button
	Local resetB:Button = New Button
	resetB.text = "RESTORE TO DEFAULT"
	resetB.wid = 220
	resetB.het = 40
	resetB.x = SWIDTH-resetB.wid
	resetB.y = SHEIGHT-resetB.het
	
	'list of buttons for the control keys
	Local keyBList:TList = New TList
	For Local i = 0 To 19
		Local keyB:Button = New Button
		keyB.wid = 400
		keyB.het = 30
		keyB.text_centered = False
		Select i
		Case 0
			keyB.text = "Fire Primary (mouse)    : "
		Case 1
			keyB.text = "Fire Alternate (mouse)  : "
		Case 2
			keyB.text = "Thrust                  : "
		Case 3
			keyB.text = "Reverse                 : "
		Case 4
			keyB.text = "Strafe/Turn Left        : "
		Case 5
			keyB.text = "Strafe/Turn Right       : "
		Case 6
			keyB.text = "Afterburner             : "
		Case 7
			keyB.text = "Ability                 : "
		Case 8
			keyB.text = "Switch Alternate Weapon : "
		Case 9
			keyB.text = "Display Map             : "
		Case 10
			keyB.text = "Fire Primary (joy)      : "
		Case 11
			keyB.text = "Fire Alternate (joy)    : "
		Case 12
			keyB.text = "Aim Axis                : "
		Case 13
			keyB.text = "Thrust Axis             : "
		Case 14
			keyB.text = "Thrust (press-and-hold) : "
		Case 15
			keyB.text = "Pause                   : "
		Case 16
			keyB.text = "Afterburner             : "
		Case 17
			keyB.text = "Ability                 : "
		Case 18
			keyB.text = "Switch Alternate Weapon : "
		Case 19
			keyB.text = "Display Map             : "
		EndSelect

		keyBList.addLast(keyB)
	Next
	
	'joystick sensitivity
	Local joy_amplifyBList:TList = New TList
	For Local i = 0 To 4
		Local vb:Button = New Button
		vb.skipborder = True
		vb.wid = 20
		vb.het = 30
		joy_amplifyBList.addLast(vb)
	Next

	
	SetBlend ALPHABLEND
	Local m'mousedown information
	Repeat
		Cls
		
		'update the particles
		For Local p:MenuParticle = EachIn menuParticleList
			p.draw
			p.update
		Next
		
		updateMusic()
		
		updateCursor()
		m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		
		'game pause!
		SetAlpha 1
		SetColor 255,255,255
		SetScale 2,2
		Local text$ = "OPTIONS"
		DrawText text, SWIDTH/2 - TextWidth(text)/2, 50
		
		'draw the different option buttons
		resumeB.update(m)
		resumeB.draw()
		If resumeB.pressed = 0 Then Exit
		
		gameB.update(m)
		gameB.draw()
		If gameB.toggle = 2
			audioB.toggle = 1
			controlB.toggle = 1
		EndIf
		
		audioB.update(m)
		audioB.draw()
		If audioB.toggle = 2
			gameB.toggle = 1
			controlB.toggle = 1
		EndIf
		
		controlB.update(m)
		controlB.draw()
		If controlB.toggle = 2
			gameB.toggle = 1
			audioB.toggle = 1
		EndIf
		
		'now DO the different options
		If gameB.toggle = 2			'GAME OPTIONS
			
			'cheat buttons
			cheat_invincB.x = 250
			cheat_invincB.y = 540
			cheat_invincB.draw()
			cheat_invincB.update(m)
			If cheat_invincB.toggle = 2 Then cheat_invincible = True Else cheat_invincible = False
			
			'resolution buttons
			SetScale 2,2
			SetColor 255,255,255
			draw_text("SCREEN RESOLUTION:", 250, 190)
			draw_text("'GAMEPLAY ASSIST':", cheat_invincB.x, cheat_invincB.y - 40)
			SetScale 1,1
			
			Local r = 0
			For Local resoB:Button = EachIn resoBList
			
				resoB.x = 250
				resoB.y = 230 + (r * resoB.het)
				resoB.draw()
				resoB.update(m)
				
				Local reso_x, reso_y
				Select r
				Case 0,1'FULLSCREEN, FIT TO SCREEN
					reso_x = DesktopWidth()
					reso_y = DesktopHeight()
				Case 2
					reso_x = 1920
					reso_y = 1200
				Case 3
					reso_x = 1366
					reso_y = 768
				Case 4
					reso_x = 1280
					reso_y = 768
				Case 5
					reso_x = 1024
					reso_y = 768
				Case 6
					reso_x = 960
					reso_y = 600
				Case 7
					reso_x = 800
					reso_y = 600
				EndSelect
				
				If OS = 1
					reso_x:- 150
					reso_y:- 150
				EndIf

				'if press a resolution
				If GraphicsModeExists(reso_x,reso_y) Or (OS = 1 And r > 0)'no fullscreen for macs, otherwise nonstandard screen sizes OK
					resoB.active = True
					If resoB.pressed = 2
						If r = 0'FULSCREEN
							Graphics reso_x,reso_y,2
						Else
							Graphics reso_x,reso_y
						EndIf
						SWIDTH = GraphicsWidth()
						SHEIGHT = GraphicsHeight()
					EndIf
				Else
					resoB.active = False
				EndIf
							
				
				Rem
				If resoB.pressed = 2
					Select r
					Case 0'FULLSCREEN
						If GraphicsModeExists(DesktopWidth(),DesktopHeight()) Then Graphics DesktopWidth(),DesktopHeight(),2
					Case 1'FIT TO SCREEN
						If GraphicsModeExists(DesktopWidth(),DesktopHeight()) Then Graphics DesktopWidth(),DesktopHeight()
					Case 2
						If GraphicsModeExists(1920,1200) Then Graphics 1920,1200
					Case 3
						If GraphicsModeExists(1366,768) Then Graphics 1366,768
					Case 4
						If GraphicsModeExists(1280,768) Then Graphics 1280,768
					Case 5
						If GraphicsModeExists(1024,768) Then Graphics 1024,768
					Case 6
						If GraphicsModeExists(960,600) Then Graphics 960,600
					Case 7
						If GraphicsModeExists(800,600) Then Graphics 800,600
					EndSelect
					
					SWIDTH = GraphicsWidth()
					SHEIGHT = GraphicsHeight()
				EndIf
				EndRem
				
				r:+ 1
			Next
						
		ElseIf audioB.toggle = 2		'AUDIO OPTIONS
			
			'starting coords for the first set of buttons
			Local bx = 300
			Local by = 300
			For Local l = 0 To 2'which list we're working with
				Local BList:TList, label$
				If l = 0
					BList = audio_sndBList
					label = "Global Volume"
				ElseIf l = 1
					BList = audio_sfxBList
					label = "Sound Effect Volume"
				ElseIf l = 2
					BList = audio_musicBList
					label = "Music Volume"
				EndIf
				
				'draw the text label
				DrawText label,bx,by
				by:+ TextHeight(label)
				'draw the buttons
				Local i = 0
				For Local vol:Button = EachIn BList
					'set the button's position
					vol.x = bx + i*vol.wid
					vol.y = by
					If i = 4 Then by:+ vol.het + 8
					
					vol.update(m)
					
					'press the button; change the volume
					If vol.pressed = 2
						If l = 0 Then sndVol = i*.25
						If l = 1 Then sfxVol = i*.25
						If l = 2 Then musicVol = i*.25
					EndIf
					
					'set the color of the button
					Select l
					Case 0
						If sndVol >= i*.25 Then vol.RGB[0] = 255 Else vol.RGB[0] = 0
					Case 1
						If sfxVol >= i*.25 Then vol.RGB[0] = 255 Else vol.RGB[0] = 0
					Case 2
						If musicVol >= i*.25 Then vol.RGB[0] = 255 Else vol.RGB[0] = 0
					EndSelect
						
					If vol.RGB[0] = 255
						vol.RGB[1] = 180
						vol.RGB[2] = 60
					Else'default colors
						vol.RGB[1] = 0
						vol.RGB[2] = 0
					EndIf

					vol.draw()

					i:+ 1
				Next
			Next
			
		ElseIf controlB.toggle = 2		'control OPTIONS
		
			'reset controls to default button
			resetB.update(m)
			resetB.draw()
			If resetB.pressed = 2 Then setControlsToDefault()

			'display current controls
			Local i = 0
			For Local keyB:Button = EachIn keyBList
				'what is the current key for this control?
				Local currentKey
				Select i
				Case 0
					currentKey = MOUSE_FIREPRIMARY
				Case 1
					currentKey = MOUSE_FIRESECONDARY
				Case 2
					currentKey = KEY_THRUST
				Case 3
					currentKey = KEY_REVERSE
				Case 4
					currentKey = KEY_STRAFELEFT
				Case 5
					currentKey = KEY_STRAFERIGHT
				Case 6
					currentKey = KEY_AFTERBURN
				Case 7
					currentKey = KEY_SHIELD
				Case 8
					currentKey = KEY_CYCLEGUN
				Case 9
					currentKey = KEY_MAP
				Case 10
					currentKey = JOY_FIREPRIMARY
				Case 11
					currentKey = JOY_FIRESECONDARY
				Case 12
					currentKey = JOY_AIMAXIS
				Case 13
					currentKey = JOY_MOVEAXIS
				Case 14
					currentKey = JOY_THRUST
				Case 15
					currentKey = JOY_MENU
				Case 16
					currentKey = JOY_AFTERBURN
				Case 17
					currentKey = JOY_SHIELD
				Case 18
					currentKey = JOY_CYCLEGUN
				Case 19
					currentKey = JOY_MAP
				EndSelect
			
				'modify the button's text so it says the current key for this
				Local controlName$ = keyB.text
				'for keyboard controls
				If i <= 9 Or (i = 12 Or i = 13)				' (+ aim/thrust axis for joystick, handled with custom keyNames)
					keyB.text = controlName + keyName[currentKey]
				'for joystick controls
				Else					
					keyB.text = controlName + String(currentKey)'just give the number of the button, they'll figure it out
				EndIf
				
				'update and draw teh button
				If i <= 9 Then keyB.x = 200 Else keyB.x = 200 + keyB.wid + 20
				keyB.y = 150+(i Mod 10)*keyB.het
				keyB.update(m)
				keyB.draw()
				
				'restore the original control name
				keyB.text = controlName
			
				'if we want to modify this control...
				If keyB.pressed = 0 And (joyDetected Or i <= 9)'(need to have a joystick to alter joystick controls)

					FlushKeys()
					FlushMouse()
					Local newKey

					'draw the "press the new button" box
					SetAlpha 1
					SetColor 32,32,32
					DrawRect SWIDTH/2-200,SHEIGHT/2-40,400,150
					SetColor 255,255,255
					
					Local text$ = "Press the new key for:"
					DrawText text, SWIDTH/2-TextWidth(text)/2,SHEIGHT/2-TextHeight(text) - 10
					
					Local space = keyB.text.Find(" ")
					If space <> -1 Then controlName = keyB.text[..space] Else controlName = keyB.text
					DrawText controlName, SWIDTH/2-TextWidth(controlName)/2,SHEIGHT/2
					
					text$ = "(Old key: " + keyName[currentKey] + ")"
					DrawText text, SWIDTH/2-TextWidth(text)/2,SHEIGHT/2+TextHeight(text) + 20
					
					text$ = "(press ESCAPE to cancel)"
					DrawText text, SWIDTH/2-TextWidth(text)/2,SHEIGHT/2-TextHeight(text) + 70
					
					Flip
					
					If i <= 1		'a mouse control
						newKey = WaitMouse()
					ElseIf i <= 9	'a keyboard control
						newKey = WaitKey()
					ElseIf i = 12 Or i = 13 'a joystick axis
						newKey = waitJoy(JOY_MENU, True)
					Else			'a joystick control
						newKey = waitJoy(JOY_MENU, False)
					EndIf
					
					'cancel if hit escape or start
					If Not (newKey = 27 Or newKey = -1)
					
						'set the control to the new button
						Select i
						Case 0
							MOUSE_FIREPRIMARY = newKey
						Case 1
							MOUSE_FIRESECONDARY = newKey
						Case 2
							KEY_THRUST = newKey
						Case 3
							KEY_REVERSE = newKey
						Case 4
							KEY_STRAFELEFT = newKey
						Case 5
							KEY_STRAFERIGHT = newKey
						Case 6
							KEY_AFTERBURN = newKey
						Case 7
							KEY_SHIELD = newKey
						Case 8
							KEY_CYCLEGUN = newKey
						Case 9
							KEY_MAP = newKey
						Case 10
							JOY_FIREPRIMARY = newKey
						Case 11
							JOY_FIRESECONDARY = newKey
						Case 12
							JOY_AIMAXIS = newKey
						Case 13
							JOY_MOVEAXIS = newKey
						Case 14
							JOY_THRUST = newKey
						Case 15
							JOY_MENU = newKey
						Case 16
							JOY_AFTERBURN = newKey
						Case 17
							JOY_SHIELD = newKey
						Case 18
							JOY_CYCLEGUN = newKey
						Case 19
							JOY_MAP = newKey
						EndSelect
						
					EndIf
				EndIf
				
				i:+ 1
			Next
			
			'joystick senstitivity adjuster
			Local bx = controlB.x + controlB.wid + 40, by = controlB.y - 10'below the final joystick button
			DrawText "Joystick Sensitivity",bx,by
			by:+ TextHeight("FOXTROT")
			'draw the buttons
			i = 0
			For Local sensiB:Button = EachIn joy_amplifyBList
				'set the button's position
				sensiB.x = bx + i*sensiB.wid
				sensiB.y = by
				sensiB.update(m)
				
				'press the button; change the sensitivity
				Local amplify# = 10 + (i*5)
				If sensiB.pressed = 2 Then JOY_AMPLIFY = amplify
				
				'set the color of the button
				If JOY_AMPLIFY >= amplify
					sensiB.RGB[0] = 255
					sensiB.RGB[1] = 180
					sensiB.RGB[2] = 60
				Else'default colors
					sensiB.RGB[0] = 0
					sensiB.RGB[1] = 0
					sensiB.RGB[2] = 0
				EndIf

				sensiB.draw()

				i:+ 1
			Next
			
		EndIf
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		draw_cursor()
		Flip
	Until KeyHit(KEY_ESCAPE) Or JoyHit(JOY_MENU)
	
	'save any changed controls
	save_controls()
	
EndFunction

'opens up rubicon.options and saves the current control scheme
Function save_controls()
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
				Select optionName
				Case "mouse_fireprimary"
					opLine[i] = optionName + " " + MOUSE_FIREPRIMARY
				Case "mouse_firesecondary"
					opLine[i] = optionName + " " + MOUSE_FIRESECONDARY
				Case "key_thrust"
					opLine[i] = optionName + " " + KEY_THRUST
				Case "key_reverse"
					opLine[i] = optionName + " " + KEY_REVERSE
				Case "key_strafeleft"
					opLine[i] = optionName + " " + KEY_STRAFELEFT
				Case "key_straferight"
					opLine[i] = optionName + " " + KEY_STRAFERIGHT
				Case "key_afterburn"
					opLine[i] = optionName + " " + KEY_AFTERBURN
				Case "key_shield"
					opLine[i] = optionName + " " + KEY_SHIELD
				Case "key_cyclegun"
					opLine[i] = optionName + " " + KEY_CYCLEGUN
				Case "key_map"
					opLine[i] = optionName + " " + KEY_MAP
				Case "joy_fireprimary"
					opLine[i] = optionName + " " + JOY_FIREPRIMARY
				Case "joy_firesecondary"
					opLine[i] = optionName + " " + JOY_FIRESECONDARY
				Case "joy_aimaxis"
					opLine[i] = optionName + " " + JOY_AIMAXIS
				Case "joy_moveaxis"
					opLine[i] = optionName + " " + JOY_MOVEAXIS
				Case "joy_thrust"
					opLine[i] = optionName + " " + JOY_THRUST
				Case "joy_menu"
					opLine[i] = optionName + " " + JOY_MENU
				Case "joy_afterburn"
					opLine[i] = optionName + " " + JOY_AFTERBURN
				Case "joy_shield"
					opLine[i] = optionName + " " + JOY_SHIELD
				Case "joy_cyclegun"
					opLine[i] = optionName + " " + JOY_CYCLEGUN
				Case "joy_map"
					opLine[i] = optionName + " " + JOY_MAP
				Case "joy_sensitivity"
					opLine[i] = optionName + " " + JOY_AMPLIFY
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
	
EndFunction

Function readOptionsFile(_file$)
	Local optionFile:TStream = ReadFile(_file)
	'if it failed, throw up an exception
	If Not optionFile Then RuntimeError("Invalid options load!")
	
	Local RESO_OVERRIDE = False'will we override default resolution with the one found here?
	
	'go through every possible line in the option file
	Repeat
	
		Local opLine$ = Lower$(ReadLine$(optionFile))
		Local space = opLine.Find(" ")
	
		'if there are parameters
		If space <> -1
			'get the parameters
			Local optionName$ = opLine[..space]
		
			Select Lower(optionName)
			
			'graphics
			Case "resolution_override"
				'do we override? 0/1
				RESO_OVERRIDE = Int(opLine[space+1..])
			Case "resolution"
				'what resolution to use?
				Local comma = opLine.Find(",")
				SWIDTH = Int(opLine[space+1..comma])
				SHEIGHT = Int(opLine[comma+1..])
			Case "fullscreen"
				'do we go fullscreen?
				FULLSCREEN = Int(opLine[space+1..])
			
			'gamestuff
			Case "current_pilot"
				SEL_PILOT = opLine[space+1..]
				
			'control scheme (mouse/keyboard or joystick)
			'Case "control_scheme"
			'	control_scheme = Int(opLine[space+1..])
	
			'controls
			Case "mouse_fireprimary"
				MOUSE_FIREPRIMARY = Int(opLine[space+1..])
			Case "mouse_firesecondary"
				MOUSE_FIRESECONDARY = Int(opLine[space+1..])
			Case "key_thrust"
				KEY_THRUST = Int(opLine[space+1..])
			Case "key_reverse"
				KEY_REVERSE = Int(opLine[space+1..])
			Case "key_strafeleft"
				KEY_STRAFELEFT = Int(opLine[space+1..])
			Case "key_straferight"
				KEY_STRAFERIGHT = Int(opLine[space+1..])
			Case "key_afterburn"
				KEY_AFTERBURN = Int(opLine[space+1..])
			Case "key_shield"
				KEY_SHIELD = Int(opLine[space+1..])
			Case "key_cyclegun"
				KEY_CYCLEGUN = Int(opLine[space+1..])
			Case "key_map"
				KEY_MAP = Int(opLine[space+1..])
			Case "joy_fireprimary"
				JOY_FIREPRIMARY = Int(opLine[space+1..])
			Case "joy_firesecondary"
				JOY_FIRESECONDARY = Int(opLine[space+1..])
			Case "joy_aimaxis"
				JOY_AIMAXIS = Int(opLine[space+1..])
			Case "joy_moveaxis"
				JOY_MOVEAXIS = Int(opLine[space+1..])
			Case "joy_thrust"
				JOY_THRUST = Int(opLine[space+1..])
			Case "joy_menu"
				JOY_MENU = Int(opLine[space+1..])
			Case "joy_afterburn"
				JOY_AFTERBURN = Int(opLine[space+1..])
			Case "joy_shield"
				JOY_SHIELD = Int(opLine[space+1..])
			Case "joy_cyclegun"
				JOY_CYCLEGUN = Int(opLine[space+1..])
			Case "joy_map"
				JOY_MAP = Int(opLine[space+1..])
			Case "joy_sensitivity"
				JOY_AMPLIFY = Int(opLine[space+1..])
			EndSelect
		EndIf
	Until Eof(optionFile)
	CloseStream optionFile
	
	Return RESO_OVERRIDE'say whether or not to override a default resolution
EndFunction


'less of a menu and more of a window
Function confirm_menu(_message$)
	'take a picture of the current game
	Local bg_image:TImage = CreateImage(SWIDTH,SHEIGHT)
	SetImageHandle(bg_image,0,0)
	GrabImage bg_image,0,0

	'make the buttons
	
	'YES
	Local yesB:Button = New Button
	yesB.text = "YES"
	yesB.wid = 160
	yesB.het = 30
	yesB.x = SWIDTH/2 - 10 - yesB.wid
	yesB.y = SHEIGHT/2 - 100
	
	'NO
	Local noB:Button = New Button
	noB.text = "NO"
	noB.wid = 160
	noB.het = 30
	noB.x = SWIDTH/2 + 10
	noB.y = SHEIGHT/2 - 100
	
	SetBlend ALPHABLEND
	Local m'mousedown information
	Repeat
		Cls
		
		WaitTimer(frameTimer)
		updateTime()
		updateCursor()
		
		m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		
		'draw the background
		SetAlpha 1
		SetColor 255,255,255
		SetRotation 0
		SetScale 1,1
		SetMaskColor 0,0,0
		DrawImage bg_image,0,0
		SetMaskColor 255,255,255
		
		SetAlpha .5
		SetColor 0,0,0
		DrawRect 0,0,SWIDTH,SHEIGHT
		
		'confirm message
		SetAlpha 1
		SetColor 255,255,255
		SetScale 2,2
		DrawText _message, SWIDTH/2 - TextWidth(_message), 150
		
		'y/n buttons
		yesB.update(m)
		yesB.draw()
		If yesB.pressed = 2 Then Return True
		
		noB.update(m)
		noB.draw()
		If noB.pressed = 2 Or KeyHit(KEY_ESCAPE) Then Return False
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		draw_cursor()
		Flip
	Forever
EndFunction

'resets all controls to the default
Function setControlsToDefault()
	MOUSE_FIREPRIMARY = 1
	MOUSE_FIRESECONDARY = 2
	KEY_THRUST = 87
	KEY_REVERSE = 83
	KEY_STRAFELEFT = 65
	KEY_STRAFERIGHT = 68
	KEY_AFTERBURN = 160
	KEY_SHIELD = 32
	KEY_CYCLEGUN = 81
	KEY_MAP = 9
	
	JOY_FIREPRIMARY = 5
	JOY_FIRESECONDARY = 7
	JOY_AMPLIFY = 20.0
	JOY_AIMAXIS = JOY_RIGHTSTICK
	JOY_MOVEAXIS = JOY_LEFTSTICK
	JOY_AFTERBURN = 6
	JOY_THRUST = 1
	JOY_SHIELD = 4
	JOY_CYCLEGUN = 0
	JOY_MAP = 3
	JOY_MENU = 9
EndFunction

'waits for the player to press a joystick button or cancel (in which case it returns -1)
'_cancelkey = joystick key to cancel the wait
'_axis = True means we're waiting for them to push an axis
Function waitJoy(_cancelKey = 0, _axis = False)
	Local keyCode = -1'the keycode to eventually return
	Repeat
		'cancel?
		If KeyHit(27) Or (joyDetected And JoyHit(_cancelKey)) Then Exit'escape on keyboard OR cancelKey
		
		If Not _axis'waiting for a button
			For Local i = 0 To 31
				If JoyDown(i) Then keyCode = i
			Next
		Else'waiting for an axis
			If JoyX() > .1 Or JoyY() > .1 Then keyCode = JOY_LEFTSTICK
			If JoyX() > .1 Or JoyY() > .1 Then keyCode = JOY_RIGHTSTICK
			If JoyX() > .1 Or JoyY() > .1 Then keyCode = JOY_OTHERSTICK
			If JoyHat() > -1 Then keyCode = JOY_HAT
		EndIf
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
	Until (keyCode  <> -1)

	Return keyCode
EndFunction

'set up the key names
Global keyName$[300]
RestoreData key_data

Local tempkey$, put_index
Repeat
	ReadData tempkey$
	ReadData put_index
	keyName[put_index]=tempkey
Until put_index=191

#key_data
DefData "Left Mouse",1
DefData "Right Mouse",2
DefData "Middle Mouse",4
DefData "Backspace",8
DefData "Tab",9
DefData "Return",13
DefData "Clear",12
DefData "Enter",13
DefData "Shift",16
DefData "Control",17
DefData "Alt",18
DefData "Pause",19
DefData "Caps Lock",20
DefData "Escape",27
DefData "Space",32
DefData "Page Up",33
DefData "Page Down",34
DefData "End",35
DefData "Home",36
DefData "Cursor (Left)",37
DefData "Cursor (Up)",38
DefData "Cursor (Right)",39
DefData "Cursor (Down)",40
DefData "Select",41
DefData "Print",42
DefData "Execute",43
DefData "Screen",44
DefData "Insert",45
DefData "Delete",46
DefData "Help",47
DefData "0",48
DefData "1",49
DefData "2",50
DefData "3",51
DefData "4",52
DefData "5",53
DefData "6",54
DefData "7",55
DefData "8",56
DefData "9",57
DefData "A",65
DefData "B",66
DefData "C",67
DefData "D",68
DefData "E", 69
DefData "F",70
DefData "G",71
DefData "H",72
DefData "I",73
DefData "J",74
DefData "K",75
DefData "L",76
DefData "M",77
DefData "N",78
DefData "O",79
DefData "P",80
DefData "Q",81
DefData "R",82
DefData "S",83
DefData "T",84
DefData "U",85
DefData "V",86
DefData "W",87
DefData "X",88
DefData "Y", 89
DefData "Z", 90
DefData "Sys key (Left)",91
DefData "Sys key (Right)",92
DefData "Numpad 0",96
DefData "Numpad 1",97
DefData "Numpad 2",98
DefData "Numpad 3",99
DefData "Numpad 4",100
DefData "Numpad 5",101
DefData "Numpad 6",102
DefData "Numpad 7",103
DefData "Numpad 8",104
DefData "Numpad 9",105
DefData "Numpad *",106
DefData "Numpad +",107
DefData "Numpad /",108
DefData "Numpad -",109
DefData "Numpad .",110
DefData "Numpad /",111
DefData "F1",112
DefData "F2",113
DefData "F3",114
DefData "F4",115
DefData "F5",116
DefData "F6",117
DefData "F7",118
DefData "F8",119
DefData "F9",120
DefData "F10",121
DefData "F11", 122
DefData "F12",123
DefData "Num Lock",144
DefData "Scroll Lock",145
DefData "Shift (Left)",160
DefData "Shift (Right)",161
DefData "Control (Left)",162
DefData "Control (Right)",163
DefData "Alt key (Left)",164
DefData "Alt key (Right)",165
DefData "Tilde",192
DefData "Minus",107
DefData "Equals",109
DefData "Bracket (Open)",219
DefData "Bracket (Close)",221
DefData "Backslash",226
DefData "Semi-colon",186
DefData "Quote",222
DefData "Comma",188
DefData "Period",190
DefData "Slash",191
'CUSTOM JOYSTICK CODES
DefData "Left Stick",255
DefData "Right Stick",254
DefData "Other Stick",253
DefData "D-Pad",252
