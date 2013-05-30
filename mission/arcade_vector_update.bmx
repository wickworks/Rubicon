'-- ARCADE UPDATE --
'ingame, spawn a series of waves of enemies until we're through

'values!
'0: what level we're on
'1: initial wave incoming countdown timer
'2: recall timer
'3: "how long taken" timer
'4: player lives
'5: points to spend
'6-11: upgraded # of specific attribute
'15: the gamemode we're in, for WAVES: 0=AI 1=ZERG 2=HUMAN

'------------------------------UPDATE-----------------------------------------

'soft springy borders
'borders()

'border: wrap ships and items and shots
For Local e:Ship = EachIn entitylist
	If Abs(e.x) > game.width Then e.x:* -.985
	If Abs(e.y) > game.height Then e.y:* -.985
Next

For Local e:Item = EachIn itemList
	If Abs(e.x) > game.width Then e.x:* -.985
	If Abs(e.y) > game.height Then e.y:* -.985
Next

For Local e:Shot = EachIn shotList
	If Abs(e.x) > game.width Then e.x:* -.985
	If Abs(e.y) > game.height Then e.y:* -.985
Next

'check to see how many enemy ships are left
Local enemyCount = 0
For Local s:Ship = EachIn entityList
	If s <> p1 Then enemyCount = enemyCount + 1
Next

'if destroyed all enemies (after we've warped them in)
If (enemyCount <= 0) And (value[1] = -255) And value[2] <= 0

	'reset the music
	new_music = levelmusic
	
	'select the next wave
	stage.wave:+ 1
	
	'if there are no more waves left
	If stage.wave >= 8 Or ListIsEmpty(stage.wave_spawnList())
		'give them a message
		If flashtext_timer <= 0 Then add_flashtext("WELL DONE PILOT")
			
		'recall timer
		value[2] = 4400
		
		'don't spawn more enemies or count down
		value[1] = -255
		
	'if another wave is due
	Else
		'add a life!
		If stage.wave = 3 Or stage.wave = 7
			game.lives:+ 1
			add_text("+1 ship",p1.x,p1.y,3000,False)
		EndIf
	
		'tick down to the next wave
		ClearList(mboxList)
		value[1] = 2000
	EndIf
EndIf

'incoming wave
If value[1] > 0
	
	'count down time till the next wave
	value[1] = constrain(value[1] - frameTime, 0, value[1])

'don't need to do anything
ElseIf value[1] = -255

'time to spawn enemies
ElseIf value[1] <= 0
	
	Local spawnrad = 500
	
	Local wavemod# = (1 + theatres_completed) * pilot.difficulty
	Local waveSquad:Squadron = new_squad("",2)
	
	'make all the ships in this wave
	For Local shipName$ = EachIn stage.wave_spawnList()
		Local s:Ship = new_ship(shipName,Rand(-(game.width-100),(game.width-100)),Rand(-(game.height-100),(game.height-100)),"arcade",waveSquad)
		s.movrot = Rand(0,359)
		s.speed = RndFloat()*s.speedMax/2
		
		If Instr(Lower(s.name),"asteroid")
			s.rot = Rand(0,359)
			s.spin = (RndFloat()-.5)
		EndIf
		
		'make them hunt you down
		waveSquad.detect_dist = 6000
		waveSquad.goal_x = Rand(-200,200)
		waveSquad.goal_y = Rand(-200,200)
	Next
	
	'modify ship stats
	For Local s:Ship = EachIn entityList
		If s <> p1
			For Local g:Gun = EachIn s.gunGroup[0]
				g.fireDelay = constrain(1500 - 300 * wavemod, 300, 1500)
				g.shotrange:* .8
			Next
			s.armourMax = 1
			s.armour = s.armourMax
			
			For Local t:Item = EachIn s.dropList
				ListRemove(s.dropList,t)
			Next
		EndIf
	Next
	
	'ACTION: boss music
	If stage.action[stage.wave] = 2 Then new_music = boss_music
	
	'ACTION: gaxlid screech, scary music
	If stage.action[stage.wave] = 3 Then new_music = mission3_music
	
	value[1] = -255
EndIf

'countdown recall timer
If value[2] > 0

	value[2] = value[2] - frameTime
	'if time to recall
	If value[2] <= 0 And Not p1.placeholder.dead Then over = True
EndIf

'player can't have any points
For Local t:Item = EachIn p1.dropList
	ListRemove(p1.dropList,t)
Next

'dead
If p1.armour <= 0 And game.lives <= 0
	If globalframe Then SetColor 255,255,255 Else SetColor 128,128,128
	SetScale 2,2
	DrawText "GAME OVER", SWIDTH/2 - TextWidth("GAME OVER"), SHEIGHT/2
EndIf
