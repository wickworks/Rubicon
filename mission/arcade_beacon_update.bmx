'-- ARCADE UPDATE --
'ingame, spawn a series of waves of enemies until we're through

'values!
'0: what level we're on
'1: how many beacons we've killed
'2: recall timer
'3: how much longer we have to finish killing the beacons
'4: 
'5: points to spend
'6-11: upgraded # of specific attribute
'15: the gamemode we're in, for WAVES: 0=AI 1=ZERG 2=HUMAN

'shiplist
'[0] - beacons
'[1] - convoy
'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

'do we need to make the beacons? (if there aren't any and none have died)
If ListIsEmpty(shipList[0]) And value[1] <= 0
	Local waveMod# = Ceil(arcade_difficulty * value[0] / 7.5)
	
	'make the beacons and their protectors
	For Local i = 1 To (waveMod*5)
		Local bsquad:Squadron = new_squad("inert",2)
		Local bx = Rand(-(game.width-100),(game.width-100))
		Local by = Rand(-(game.height-100),(game.height-100))
		Local warpbeacon:Ship = new_ship("Warp Beacon",bx,by,"arcade",bsquad)
		new_objective("",True,0,0,warpbeacon)
		
		'squad for beacon's protectors
		bsquad = new_squad("protect",2)
		bsquad.target = warpbeacon.placeholder
		'lancer protectors
		For Local j = 1 To Rand(-2,waveMod*2)
			new_ship("Lancer",bx+Rand(-150,150),by+Rand(-150,150),"arcade",bsquad)
		Next
		'pillbug protectors
		For Local j = 1 To Rand(-2,waveMod)
			new_ship("Pillbug",bx+Rand(-150,150),by+Rand(-150,150),"arcade",bsquad)
		Next
		'flea protectors
		For Local j = 1 To Rand(3,3+waveMod*4)
			new_ship("Flea",bx+Rand(-150,150),by+Rand(-150,150),"arcade",bsquad)
		Next
		
		'track all the beacons
		shipList[0].addLast(warpbeacon)
	Next
EndIf

'remove the dead beacons from the tracked list
For Local s:Ship = EachIn shipList[0]
	If s.placeholder.dead
		ListRemove(shipList[0], s)
		value[1]:+ 1'record that one died
		'flash a message
		If CountList(shipList[0]) = 1
			add_flashtext("[1] WARP BEACON REMAINS")
		Else
			add_flashtext("[" + CountList(shipList[0]) + "] WARP BEACONS REMAIN")
		EndIf
	EndIf
Next

'remove the dead convoy from the tracked list
For Local s:Ship = EachIn shipList[1]
	If s.placeholder.dead Then ListRemove(shipList[0], s)
Next

'have we destroyed them all?
If ListIsEmpty(shipList[0]) And ListIsEmpty(shipList[1]) And value[1] > 0
	'countdown to recall
	If flashtext_timer = 0 Then value[2] = game.over = 1
	value[2] = value[2] - frameTime
	
	add_flashtext("PLEASE AWAIT INSTANT RECALL")
	'tell them they've done good
	If ListIsEmpty(mboxList)
		Select Rand(0,4)
		Case 0
			new_message("A GREAT THREAT AVERTED")
		Case 1
			new_message("A BLOW STRUCK FOR THE COMMON MAN")
		Case 2
			new_message("WE ARE HUMANITY'S PROTECTORS")
		Case 3
			new_message("THEY ARE NO MATCH")
		EndSelect
	EndIf
	
	'time to recall?
	If value[2] <= 0 Then game.over = True
EndIf

'if we've run out of time, enemy convoy has warped in (and we haven't already warped them in)
If playTime >= (value[3]/1000) And value[3] > 0
	
	Local convoysquad:Squadron = new_squad("",2)
	Local waveMod# = arcade_difficulty * Ceil(value[0]/3.5)
	
	shipList[1].addLast(new_ship("Carrier",Rand(-200,200),Rand(-200,200),"arcade",convoysquad))
	'lancer protectors
	For Local j = 1 To Rand(-2,waveMod*2)
		shipList[1].addLast(new_ship("Lancer",Rand(-200,200),Rand(-200,200),"arcade",convoysquad))
	Next
	'pillbug protectors
	For Local j = 1 To Rand(-2,waveMod)
		shipList[1].addLast(new_ship("Pillbug",Rand(-200,200),Rand(-200,200),"arcade",convoysquad))
	Next
	'flea protectors
	For Local j = 1 To Rand(3,3+waveMod*4)
		shipList[1].addLast(new_ship("Flea",Rand(-200,200),Rand(-200,200),"arcade",convoysquad))
	Next
		
	'warp them in
	For Local s:Ship = EachIn shipList[1]
		s.warp_in(Null, s.x, s.y)
	Next
	
	'finish the timer
	ClearList(objectiveList)
	value[3] = 0
	
	add_flashtext("CONVOY WARPING IN! DESTROY THEM!")
	
ElseIf value[3] > 0'update timer if it's till relevent
	For Local o:Objective = EachIn objectiveList
		If Left(o.text,1) = "[" Then o.text = "["+time((value[3]/1000) - playTime)+"] before enemy convoy warps in."
	Next
	
EndIf
