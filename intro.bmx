Function intro()
	Local oldMilli# = MilliSecs()
	Local introfade#,introfadespeed#,introTimer# = 18
	Repeat
		Cls
		
		timePass = (MilliSecs() - oldMilli#)/1000
		oldMilli = MilliSecs()
		
		introTimer:- timePass
		
		'control what to draw/section of intro we're in
		SetAlpha introfade
		If introTimer>15
			introfadespeed = .3
			SetScale 3,3
			DrawText "WickWorks present",SWIDTH/2-200,SHEIGHT/2
		ElseIf introTimer>10.5
			introfadespeed = -.3
			SetScale 3,3
			DrawText "WickWorks present",SWIDTH/2-200,SHEIGHT/2
		ElseIf introTimer>4
			introfadespeed = .15
			SetScale 10,10
			DrawText "RUBICON",SWIDTH/2-400,SHEIGHT/2-200
		Else
			introfadespeed = -.3
			SetScale 10,10
			DrawText "RUBICON",SWIDTH/2-400,SHEIGHT/2-200
		EndIf
		
		If introTimer <= 0 Then Exit
		
		introfade:+ (introfadespeed * timePass)
		If introfade>1 Then introfade=1
		If introfade<0 Then introfade=0
	
		'update the particles
		For Local p:MenuParticle = EachIn menuParticleList
			p.draw
			p.update(1.5)
		Next
		
		If KeyHit(KEY_ESCAPE) Or KeyHit(KEY_SPACE) Or MouseHit(MOUSE_LEFT) Or JoyHit(JOY_FIREPRIMARY) Or JoyHit(JOY_MENU) Then Exit
		If AppTerminate() Then endGame()
	
		timePass:* 1000'updatemusic uses this form of passing the time
		updateMusic()
		Flip
	Forever
	'Until introTimer <= 0
EndFunction