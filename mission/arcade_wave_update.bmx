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
borders()

'check to see how many enemy ships are left
Local enemyCount = 0, enemies_warping = False
For Local s:Ship = EachIn entityList
	If fTable[p1.squad.faction,s.squad.faction] = -1 And s.base.ord = False Then enemyCount = enemyCount + 1
Next

'are they still warping in?
For Local i:Item = EachIn itemList
	If i.name = "warp"
		enemyCount = enemyCount + 1
		enemies_warping = True
	EndIf
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
		If flashtext_timer <= 0 Then add_flashtext("PLEASE AWAIT INSTANT RECALL")
		'tell them they've done good
		If ListIsEmpty(mboxList)
			For Local i = 0 To 2
				If stage.victory_text[i] <> "" Then new_message(activateText(stage.victory_text[i]))
			Next
		EndIf
			
		'recall timer
		value[2] = 4400
		
		'don't spawn more enemies or count down
		value[1] = -255
		
	ElseIf stage.action[stage.wave] = 4'CUTTLEFISH WAVE

	'if another wave is due
	Else
		'ACTION: say how many waves are remaining
		If stage.action[stage.wave] = 1'flag for this message on this wave
			'how many waves total
			Local waveNum
			For waveNum = 0 To 7
				If ListIsEmpty(stage.wave_spawnList(waveNum)) Then Exit
			Next
			Local wavesleft = (waveNum + 1) - stage.wave
			If wavesleft > 1 Then add_flashtext("["+wavesleft+"] waves remain.") Else add_flashtext("[1] wave remains.")
		EndIf
		
		'send any tutorial messages
		If pilot.difficulty <= .5 And stage.tutorial_text[stage.wave] <> "" Then add_flashtext(activateText(stage.tutorial_text[stage.wave]))
		
		'other flashing text
		If stage.flash_text[stage.wave] <> "" Then add_flashtext(stage.flash_text[stage.wave])
	
		'tick down to the next wave
		ClearList(mboxList)
		value[1] = 1000
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
	
	Local wavemod# = pilot.difficulty * (constrain(theatres_completed, 1, theatres_completed)*2 + value[0] + 1)/3
	'Print "WAVEMOD:"+wavemod
	If wavemod < .5 Then wavemod = .5'zen difficulty still spawns baddies
	Local waveSquad:Squadron = new_squad("",2)
	
	'make all the ships in this wave
	For Local shipName$ = EachIn stage.wave_spawnList()

		'make the ship
		Local s:Ship = new_ship(shipName,0,0,"arcade")
	
		'acutally just make a new squad for EACH SHIP!!! (well what the hell is the point of a squad then???)
		'anyway, set factions accordingly.
		If Not s.base.bio
			s.squad.faction = 2'AI faction
		Else
			s.squad.faction = 3'gaxlid faction
		EndIf
	
		'metal ships warp in
		If Not s.base.bio
			'if we're currently working with a gaxlid squad, make a new one for AI ships
			'If waveSquad.faction = 3 Then waveSquad = new_squad("",2)
			
			waveSquad.detect_dist = 6000
		
			s.x = Rand(-spawnrad,spawnrad)
			s.y = Rand(-spawnrad,spawnrad)
			
			'buff up the enemies
			For Local c:Component = EachIn s.compList
				'just use the first component, then exit
				c.armourBonus:+ wavemod
				Exit
			Next

			'modify ship stats
			For Local g:Gun = EachIn s.gunGroup[0]
				g.shotdamage = (g.shotdamage)*(wavemod/2)
				g.shotspeed = (g.shotspeed)*(wavemod/2)
			Next
			
			'warp them it
			s.warp_in(Null, s.x, s.y)
		
		'squishy space monsters come in from the side
		Else
			'if we're currently working with an AI squad, make a new one for gaxlid ships
			'If waveSquad.faction = 2 Then waveSquad = new_squad("",3)
			
			'bio ships use echolocation to locate the player
			waveSquad.detect_dist = 90000
		
			If Rand(0,1)'start on: 0=top/bottom | 1=left/right
				s.x = Rand(-(game.width-100),(game.width-100)) + Rand(-spawnrad,spawnrad)
				s.y = (game.height+100)*binsgn(Rand(0,1)) + Rand(-spawnrad,spawnrad)
				'waveSquad.goal_x = Rand(-(game.width-100),(game.width-100))
				'waveSquad.goal_y = -s.y
			Else
				s.y = Rand(-(game.height-100),(game.height-100)) + Rand(-spawnrad,spawnrad)
				s.x = (game.width+100)*binsgn(Rand(0,1)) + Rand(-spawnrad,spawnrad)
				'waveSquad.goal_x = -s.x
				'waveSquad.goal_y = Rand(-(game.height-100),(game.height-100))
			EndIf
		EndIf
		
		'make them hunt you down
		waveSquad.goal_x = Rand(-200,200)
		waveSquad.goal_y = Rand(-200,200)
	Next
	
	'ACTION: boss music
	If stage.action[stage.wave] = 2 Then new_music = boss_music
	
	'ACTION: gaxlid screech, scary music
	If stage.action[stage.wave] = 3 Then new_music = mission3_music
	
	value[1] = -255
EndIf

'countdown recall timer
If value[2] > 0 And (p1.armour > 0 Or game.lives <= 0)'only countdown recall when alive
	value[2] = value[2] - frameTime
	'if time to recall
	If value[2] <= 0 And Not p1.placeholder.dead Then over = True
EndIf
