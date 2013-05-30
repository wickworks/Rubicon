'-- ARCADE UPDATE --
'ingame, spawn a series of waves of enemies until we're through

'values!
'0: what level we're on
'1: time to the next spawn wave
'2: how long we have to survive to beat this level
'5: points to spend
'6-11: upgraded # of specific attribute
'15: the gamemode we're in, for WAVES: 0=AI 1=ZERG 2=HUMAN

'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

'spawn squads of zerg offmap, have them head to a random point on the other side, and disappear
value[1]:- frameTime
If value[1] <= 0'if time to spawn a new wave
	'randomly choose the type of zerg to spawn
	Local waveMod# = arcade_difficulty * Ceil(value[0]/3.5)
	Local waveSquad:Squadron = new_squad("patrol",3)'goto location, but stop and fight on the way
	Local wavex,wavey
	If Rand(0,1)'start on: 0=top/bottom | 1=left/right
		wavex = Rand(-(game.width-100),(game.width-100))
		wavey = (game.height+100)*binsgn(Rand(0,1))
		waveSquad.goal_x = Rand(-(game.width-100),(game.width-100))
		waveSquad.goal_y = -wavey
	Else
		wavex = Rand(-(game.height-100),(game.height-100))
		wavey = (game.width+100)*binsgn(Rand(0,1))
		waveSquad.goal_x = -wavex
		waveSquad.goal_y = Rand(-(game.height-100),(game.height-100))
	EndIf

	Local waveType = Rand(1,3)
	Select waveType
	Case 1'Gaxlid zerglings
		For Local i = 2 To Rand(waveMod,waveMod*3)
			new_ship("Timberwolf",wavex+Rand(-150,150),wavey+Rand(-150,150),"",waveSquad)
		Next
	Case 2'Litus devils
		For Local i = 1 To Rand(waveMod/2,waveMod)
			new_ship("Litus Devil",wavex+Rand(-150,150),wavey+Rand(-150,150),"",waveSquad)
		Next
	Case 3'mites
		For Local i = 4 To 4+Rand(waveMod*2,waveMod*4)
			new_ship("Mite",wavex+Rand(-150,150),wavey+Rand(-150,150),"",waveSquad)
		Next
	EndSelect
	
	'reset the timer
	value[1] = 3000
EndIf

'for all patrolling ships, if they're close to their movement target, remove them
For Local s:Ship = EachIn entityList
	If s.squad.behavior = "patrol" And approxDist(s.x-s.squad.goal_x, s.y-s.squad.goal_y) < 150 Then RemoveLink(s.link)
Next


'if we've "won"
If playTime >= (value[2]/1000)
	game.over = 1
	ClearList(game.objectiveList)
Else
	For Local o:Objective = EachIn objectiveList
		If Left(o.text,1) = "[" Then o.text = "["+time((value[2]/1000) - playTime)+"] Until instant recall."
	Next
EndIf
