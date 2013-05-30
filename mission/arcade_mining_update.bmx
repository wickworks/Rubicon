'-- ARCADE UPDATE --
'ingame, spawn a series of waves of enemies until we're through

'values!
'0: what level we're on
'1: how many mining bots we've killed
'2: recall timer
'3: "how long taken" timer
'4: 
'5: points to spend
'6-11: upgraded # of specific attribute
'15: the gamemode we're in, for WAVES: 0=AI 1=ZERG 2=HUMAN

'shiplist
'[0] - mining ships

'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

'do we need to make the mining ships + special asteroids? (if there aren't any and none have died)
If ListIsEmpty(shipList[0]) And value[1] <= 0
	Local waveMod# = Ceil(arcade_difficulty * value[0] / 7.5)
	
	'make the mining ships and their protectors
	For Local i = 1 To (waveMod*5)
		Local pillsquad:Squadron = new_squad("miner",3)
		Local pillx = Rand(-(game.width-100),(game.width-100))
		Local pilly = Rand(-(game.height-100),(game.height-100))
		Local pillbug:Ship = new_ship("Pillbug",pillx,pilly,"mining",pillsquad)
		new_objective("",True,0,0,pillbug)
		
		'squad for miner's protectors
		Local botsquad:Squadron = new_squad("protect",2)
		botsquad.target = pillbug.placeholder
		'lancer protectors
		For Local j = 1 To Rand(-2,waveMod*2)
			new_ship("Lancer",pillx+Rand(-150,150),pilly+Rand(-150,150),"arcade",botsquad)
		Next
		'flea protectors
		For Local j = 1 To Rand(3,3+waveMod*4)
			new_ship("Flea",pillx+Rand(-150,150),pilly+Rand(-150,150),"arcade",botsquad)
		Next
		
		'track all the pillbugs
		shipList[0].addLast(pillbug)
	Next
	
	'make the squad for special asteroids
	Local specialcometsquad:Squadron = new_squad("inert",4)'faction 4, to be hunted by mining bots
	'put all prexisting special asteroids on the squad
	For Local s:Ship = EachIn entityList
		If Lower(Left(s.name,8)) = "asteroid" And (s.gfx = asteroid4_gfx Or s.gfx = asteroid5_gfx) Then s.squad = specialcometsquad
	Next
	'make more special asteroids
	For Local i = 1 To 80
		Local a:Ship
		Local size = (Rand(1,5) < 4) '1 (small) or 0 (big)
		If size Then a = new_ship("Asteroid 1",0,0,"",specialcometsquad) Else a = new_ship("Asteroid 2",0,0,"",specialcometsquad)
		If size Then a.gfx = asteroid5_gfx Else a.gfx = asteroid4_gfx'special graphic
		a.x = Rand(-(game.width-100),(game.width-100))
		a.y = Rand(-(game.height-100),(game.height-100))
		a.movrot = Rand(0,359)
		a.speed = RndFloat()*4
		a.spin = (RndFloat()-.5)*2
		'give it points
		For Local p = 0 To (a.mass/4 + Rand(0,2))
			a.dropList.addLast(add_item("point",point1_gfx,0,0,0,0,False))
		Next
		a.shade = 0
		a.debrisRGB[0] = 150
		a.debrisRGB[1] = 200
		a.debrisRGB[2] = 255
	Next
EndIf

'remove the dead mining bots from the tracked list
For Local s:Ship = EachIn shipList[0]
	If s.placeholder.dead
		ListRemove(shipList[0], s)
		value[1]:+ 1'record that one died
		'flash a message
		If CountList(shipList[0]) = 1
			add_flashtext("[1] MINING SHIP REMAINS")
		Else
			add_flashtext("[" + CountList(shipList[0]) + "] MINING SHIPS REMAIN")
		EndIf
	EndIf
Next

'have we destroyed them all?
If ListIsEmpty(shipList[0]) And value[1] > 0
	'countdown to recall
	If flashtext_timer = 0 Then value[2] = game.over = 1
	value[2] = value[2] - frameTime
	
	add_flashtext("PLEASE AWAIT INSTANT RECALL")
	'tell them they've done good
	If ListIsEmpty(mboxList)
		Select Rand(0,4)
		Case 0
			new_message("HUMAN INDEPENDENCE PROSPERS")
		Case 1
			new_message("A BLOW STRUCK FOR THE COMMON MAN")
		Case 2
			new_message("WE ARE HUMANITY'S PROTECTORS")
		Case 3
			new_message("THEIR RICHES ARE OURS")
		EndSelect
	EndIf
	
	'time to recall?
	If value[2] <= 0 Then game.over = True
EndIf

