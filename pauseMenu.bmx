'takes a screencap of the game, fades it out and has menu options over it
Function pause_menu(_restartEnabled = True)'can we restart?
	'take a picture of the current game
	Local bg_image:TImage = CreateImage(SWIDTH,SHEIGHT)
	SetImageHandle(bg_image,0,0)
	GrabImage bg_image,0,0
	
	'make the buttons
	
	'resume game button
	Local resumeB:Button = New Button
	resumeB.text = "RESUME"
	resumeB.wid = 260
	resumeB.het = 60
	resumeB.x = SWIDTH/2 - resumeB.wid/2
	resumeB.y = 200
	
	'resume game button
	Local restartB:Button = New Button
	restartB.text = "RESTART MISSION"
	restartB.wid = 260
	restartB.het = 60
	restartB.x = SWIDTH/2 - restartB.wid/2
	restartB.y = 280
	restartB.active = _restartEnabled
	
	'options button
	Local optionB:Button = New Button
	optionB.text = "OPTIONS"
	optionB.wid = 260
	optionB.het = 60
	optionB.x = SWIDTH/2 - optionB.wid/2
	optionB.y = 360
	
	'resume game button
	Local exitB:Button = New Button
	exitB.text = "END MISSION"
	exitB.wid = 260
	exitB.het = 60
	exitB.x = SWIDTH/2 - exitB.wid/2
	exitB.y = 440

	
	SetBlend ALPHABLEND
	Local m'mousedown information
	Repeat
		Cls
		
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
		
		'game pause!
		SetAlpha 1
		SetColor 255,255,255
		SetScale 2,2
		Local text$ = "GAME PAUSED"
		DrawText text, SWIDTH/2 - TextWidth(text), 150
		
		'draw the menu options
		resumeB.update(m)
		resumeB.draw()
		If resumeB.pressed = 0 Or KeyHit(KEY_ESCAPE) Or (joyDetected And JoyDown(JOY_MENU)) Then Exit
		
		restartB.update(m)
		restartB.draw()
		If restartB.pressed = 0
			game.over = True
			game.restart = True
			Exit
		EndIf
		
		optionB.update(m)
		optionB.draw()
		If optionB.pressed = 0 Then option_menu()
		
		exitB.update(m)
		exitB.draw()
		If exitB.pressed = 0
			game.over = 2'AKA "super-true"
			Exit
		EndIf
	
		updateMusic()
	
		draw_cursor()
		Flip
	Forever
	
	FlushKeys()
	FlushMouse()
EndFunction