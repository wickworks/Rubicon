'-- TESTDRIVE UPDATE --
'drive around an asteroid field

'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

If p1.armour <= 0
	'start a respawn timer
	value[3]:+ timePass
	If value[3] > 3000
		new_message("Your ship has died. Try to be more careful with the new one, yeah?")
		p1.reset()
		value[3] = 0
	EndIf
EndIf

'what stage of the tutorial are we at?
Select value[0]
Case 1'intro messages, stationary astroid shooting
	new_message("Welcome to RUBICON. This tutorial will teach you how to SHOOT and MOVE your ship.")
	new_message("First off, SHOOTING:")
	Local m:Messagebox = new_message("You always aim at your MOUSE. ")
	m.addText("To FIRE PRIMARY WEAPONS, press and hold the LEFT MOUSE BUTTON.")
	mbox = new_message("DESTROY the surrounding asteroids.")
	value[0] = 2
	
Case 2'time to shoot some astroids with your turret!

	Local done = True		'did we kill them all?
	'go through all the surrounding asteroids
	For Local s:Ship = EachIn shipList[0]
		'is at least one still alive?
		If s.armour > 0 Then done = False
		'did any get away?
		Local dx = s.x-p1.x
		Local dy = s.y-p1.y
		If approxDist(dx,dy) > SHEIGHT Then s.movrot = ATan2(dy,dx)+180'whoops! it's getting away!
	Next
	
	If done And Not ListIsEmpty(shipList[0])
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("Now some asteroids will float by. Try to destroy these MOVING TARGETS.")
		ClearList(shipList[0])
	ElseIf ListIsEmpty(shipList[0])
		If mbox.fin
			value[0] = 4
			set_objective(0,"Destroy all of the drifting asteroids")
			'game.fade = 1
			'value[0] = 8
			'mbox = Null
		EndIf
	ElseIf mbox.fin
		set_objective(0,"PRESS and HOLD the LEFT MOUSE BUTTON to fire",0,0,True)
		set_objective(1,"Destroy all of the surrounding asteroids")
	EndIf
	
Case 4,6'spawn some moving asteroids
	mbox = Null
	ClearList(shipList[0])
	For Local i = 0 To 3
		Local ax = p1.x + 700/(1+(3*(i Mod 2)))*Sgn(i*2-3)
		Local ay = p1.y + 700/(1+(3*((i+1) Mod 2)))*Sgn(i*2-3)'holy bejeezus i hope these work
		Local a:Ship = new_ship("Asteroid 1",ax,ay,"",inertSquad)
		a.spin = (RndFloat()-.5)*2
		a.movrot = 90*i
		a.speed = (RndFloat()+.6)*1.5
		a.mass:* 3
		shipList[0].addLast(a)
	Next
	If value[0] = 4 Then value[0] = 5 Else value[0] = 7'check or destruction of first wave -OR- move on to spawn collision asteroid

Case 5'check to see if they've killed the first set of moving asteroids
	Local done = True		'did we kill them all?
	For Local s:Ship = EachIn shipList[0]
		If s.armour > 0 Then done = False
		Local dx = s.x-p1.x
		Local dy = s.y-p1.y
		If approxDist(dx,dy) > SHEIGHT Then s.movrot = Floor(ATan2(dy,dx)+180 / 90) * 90
	Next
	If done And mbox = Null
		new_message("Good job.")
		game.clear_objectives()
		mbox = new_message("More asteroids are on their way. Get ready!")
	ElseIf done
		If mbox.fin
			set_objective(1,"Destroy all of the drifting asteroids")
			value[0] = 6'spawn more asteroids
		EndIf
	EndIf
	
Case 7'spawn a collision asteroid in the middle of things
	game.fade = 0'no fade
	Local acount = CountList(shipList[0])'count how many they've killed
	For Local s:Ship = EachIn shipList[0]
		If s.armour <= 0 Then acount:- 1
		Local dx = s.x-p1.x
		Local dy = s.y-p1.y
		If approxDist(dx,dy) > SHEIGHT Then s.movrot = Floor(ATan2(dy,dx)+180 / 90) * 90
	Next
	
	If acount = 2 And ships[2] = Null'once we've killed two asteroids, make a rogue killer one
		Local arot = Rand(0,359)
		ships[2] = new_ship("Asteroid 2",p1.x+Cos(arot)*750,p1.y+Sin(arot)*750,"",inertSquad)
		ships[2].movrot = ATan2(p1.y-ships[2].y,p1.x-ships[2].x)
		ships[2].speed = 2.3
	EndIf
	
	'did we get hit?
	If p1.armour < p1.armourMax
		If mbox = Null
			Local m:Messagebox = new_message("Sometimes, asteroids seem to come out of nowhere. ")
			m.addText("If avoidance isn't possible, you can blast them before they hit you.")
			mbox = new_message("I'll repair your damage. Let's try that again. Get ready!")
		ElseIf mbox.fin
			game.fade = 1 'fully fade out
		EndIf
		If game.currentfade = 1'reset stuff once faded out
			ships[2] = Null
			p1.x = 0
			p1.y = 0
			p1.speed = 0
			p1.repair(1000)
			ClearList(shipList[0])
			ClearList(entityList)
			entityList.addLast(p1)
			value[0] = 6
		EndIf
	
	'once we've killed all the asteroids
	ElseIf acount <= 0 And ships[2].armour <= 0
		If mbox = Null
			new_message("Good job. You were able to destroy that larger asteroid before it hit you.")
			mbox = new_message("Now we will move onto SHIP MOVEMENT.")
		ElseIf mbox.fin
			game.clear_objectives()
			mbox = Null
			value[0] = 8
			game.fade = 1
		EndIf
	EndIf
	
Case 8'SHIP MOVEMENT
	'if we've finished fading out
	If game.currentfade = 1
		'reset the map, make the new ship for the player to control
		ships[2] = Null
		ClearList(shipList[0])
		ClearList(entityList)
		ClearList(debrisList)
		ships[0] = new_ship("Lamjet",0,0,"pacifist",p1.squad)
		
		p1 = ships[0]
		p1.behavior = "player"
		
		new_message("For this section, your GUNS have been DISABLED.")
		mbox = new_message("Similar to aiming, a fighter STEERS by facing the MOUSE.")
		
		'fade back in
		game.fade = 0
	EndIf
	
	'once the initial message finishes
	If mbox <> Null And mbox.fin
		new_message("To THRUST, press " + keyName[KEY_THRUST])
		mbox = new_message("Try to pass over this beacon.")
		value[0] = 9
	EndIf
	
Case 9'set up first beacon - THRUSTING
	If mbox.fin
		mbox = Null
		point[0] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		value[1] = False'we have not yet reached the beacon
		set_objective(0,"PRESS and HOLD " + keyName[KEY_THRUST] + " to thrust",0,0,True)
		set_objective(1,"Pass over the first beacon",point[0].x,point[0].y,True)
		value[0] = 10
	EndIf
	
Case 10'first beacon

	'have we reached the first beacon?
	If point[0].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[0].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon but no longer, we've passed over it
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("Now try to pass over the next beacon while avoiding these asteroids.")
		point[0].state[1] = 3'kill the beacon
		value[0] = 11
	EndIf
	
Case 11'set up second beacon - AVOID STATIONARY
	If mbox.fin
		mbox = Null
		point[1] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		value[1] = False'we have not yet reached the beacon
		set_objective(1,"Pass over the second beacon",point[1].x,point[1].y,True)
		
		'make some asteroids around the field
		For Local i = 0 To 31
			Local adist,atheta,ax,ay,collide
			Local a:Ship = new_ship("Asteroid 2",0,0,"",inertSquad)
			a.spin = (RndFloat()-.5)*2
			Repeat
				a.x = Rand(-(width-100),width-100)
				a.y = Rand(-(height-100),height-100)
				
				'make sure we're not placing on top of another asteroid
				collide = False
				For Local o:Ship = EachIn shipList[0]
					If ImagesCollide(a.gfx[0],a.x,a.y,0,o.gfx[0],o.x,o.y,0) Then collide = True
				Next
			Until collide = False
			
			shipList[0].addLast(a)
		Next
		
		value[0] = 12
	EndIf
	
Case 12'second beacon
	'have we reached the second beacon?
	If point[1].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[1].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("Now the asteroids will be moving. Try reaching the next beacon. Get ready!")
		point[1].state[1] = 3'kill the beacon
		value[0] = 13
	EndIf
	
Case 13'set up the third beacon - AVOID MOVING OBJECTS
	If mbox.fin
		mbox = Null
		point[2] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		value[1] = False'we have not yet reached the beacon
		set_objective(1,"Pass over the third beacon",point[2].x,point[2].y,True)
		
		'make all the asteroids move
		For Local a:Ship = EachIn shipList[0]
			a.speed = RndFloat()*2
			a.movrot = Rand(0,359)
		Next
		
		value[0] = 14
	EndIf
	
Case 14'thirde
	'have we reached the third beacon?
	If point[2].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[2].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("Now try to pass over the next beacon without running into the bordering asteroids. ")
		new_message("You will have to reverse your movement by thrusting in the opposite direction of your movement.")
		point[2].state[1] = 3'kill the beacon
		value[0] = 15
		
		'stop all the asteroids
		For Local a:Ship = EachIn shipList[0]
			a.speed = 0
		Next
	EndIf
		
Case 15'set up the fourth beacon - REVERSE
	If mbox.fin
		mbox = Null
		point[3] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		value[1] = False'we have not yet reached the beacon
		set_objective(1,"Pass over the fourth beacon",point[3].x,point[3].y,True)
		ships[0].reset()'reset the player's stats
		
		
		For Local a:Ship = EachIn shipList[0]
			'stop all the asteroids
			a.speed = 0
			'remove all asteroids close to the beacon
			If approxDist(a.x-point[3].x,a.y-point[3].y) < 160 Then RemoveLink a.link
		Next
		
		'make some asteroids boardering the beacon
		Local dir = Rand(0,360)
		For Local i = 1 To 7
			Local adist = 100
			Local atheta = dir + i*45
			Local ax = point[3].x + Cos(atheta)*adist
			Local ay = point[3].y + Sin(atheta)*adist
			Local a:Ship = new_ship("Asteroid 2",ax,ay,"",inertSquad)
			a.spin = (RndFloat()-.5)*2
			shipList[0].addLast(a)
		Next
		
		value[0] = 16
	EndIf
		
Case 16'forthe
	'have we reached the forth beacon?
	If point[3].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[3].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("For the next beacon, you will need to STOP on top of it for FIVE SECONDS to continue.")
		point[3].state[1] = 3'kill the beacon
		value[0] = 17
	EndIf
	
Case 17'set up the fifth beacon - STOP
	If mbox.fin
		mbox = Null
		point[4] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		value[1] = 5 ' five seconds left
		value[0] = 18
	EndIf
	
Case 18'fifthe - STOP
	If mbox = Null Then set_objective(1,"Stop on top of the fifth beacon for ["+Int(value[1])+"] seconds]",point[4].x,point[4].y)
	
	'have we reached the fifth beacon?
	If point[4].state[0] = 2'if the player is on the beacon
		'countdown the timer
		value[1]:- (timePass/1000.0)
		point[4].state[1] = 1'highlight the beacon
		
	ElseIf value[1] > 0'we fell off
		'reset the timer
		value[1] = 5
		point[4].state[1] = 0'un-highlight the beacon
	EndIf
	
	If value[1] <= 0 And mbox = Null'we sat on the beacon for the right amount of time
		game.clear_objectives()
		new_message("Good job.")
		mbox = new_message("The beacon will begin to MOVE. ")
		mbox.addText("You need to STAY ON TOP of it for FIVE SECONDS to continue.")
	EndIf
	
	'set up the next phase
	If mbox <> Null And mbox.fin
		mbox = Null
		point[4].state[1] = 0'highlight the beacon
		point[4].speed = 1.3
		point[4].movrot = 0
		value[1] = 5'reset the timer
		value[0] = 19
	EndIf
	
Case 19'fifthe - MATCH VELOCITIES
	set_objective(1,"Match velocities with the fifth beacon for ["+Int(value[1])+"] seconds]",point[4].x,point[4].y)
	
	'bounce the beacon back and forth
	If point[4].x >= width Then point[4].movrot = 180
	If point[4].x <= -width Then point[4].movrot = 0
	
	'have we reached the fifth beacon?
	If point[4].state[0] = 2'if the player is on the beacon
		'countdown the timer
		value[1]:- (timePass/1000.0)
		point[4].state[1] = 1'highlight the beacon
		
	ElseIf value[1] > 0'we fell off
		'reset the timer
		value[1] = 5
		point[4].state[1] = 0'un-highlight the beacon
	EndIf
	
	If value[1] <= 0 And mbox = Null'we sat on the beacon for the right amount of time
		game.clear_objectives()
		new_message("Good job.")
		new_message("PRESS and HOLD " + keyName[KEY_AFTERBURN] + " to use your afterburner.")
		new_message("While afterburning, you will move and accelerate faster than normal.")
		new_message("You have a limited amount of afterburner fuel. The gauge is right below this message.")
		mbox = new_message("You need to hit the next two beacons in quick succession to continue.")
		p1.juice = p1.juiceMax
		point[4].state[1] = 3'kill the beacon
	EndIf
	
	'setup up afterburner beacons
	If mbox <> Null And mbox.fin
		'the two beacons to hit
		point[5] = add_beacon(150,0)
		point[6] = add_beacon(600,0)
		set_objective(0,"PRESS and HOLD " + keyName[KEY_AFTERBURN] + " to use your afterburner",0,0,True)
		set_objective(1,"Pass over the sixth and seventh beacons in quick succession")
		value[1] = -1'we haven't triggered the time limit yet
		value[0] = 20
	EndIf
	
Case 20'sixthe+seventhe - AFTERBURNER	
	Local done = False
	
	'have we reached either beacon?
	If point[5].state[0] = 2'if the player is on the beacon
		point[5].state[1] = 1'highlight the beacon
		'if we're not counting down
		If value[1] = -1 Or value[1] > 1.5
			'start the countdown
			value[1] = 1.4
		'if we ARE still counting down
		ElseIf point[6].state[1] = 1'if the other beacon is highlighted
			done = True
		EndIf
	EndIf
	If point[6].state[0] = 2'if the player is on the beacon
		point[6].state[1] = 1'highlight the beacon
		'if we're not counting down
		If value[1] = -1 Or value[1] > 1.5
			'start the countdown
			value[1] = 1.4
		'if we ARE still counting down
		ElseIf point[5].state[1] = 1'if the other beacon is highlighted
			done = True
		EndIf
	EndIf
	
	'count the timer down
	If value[1] > -1
		value[1]:- (timePass/1000.0)
	'reset the timer, beacons if we run out of time
	Else
		value[1] = -1
		'un-highlight the beacons
		point[5].state[1] = 0
		point[6].state[1] = 0
	EndIf
	
	'if we've gotten to both of them in the right amount of timer
	If done
		game.clear_objectives()
		cheat_disableengines = True
		new_message("Good job. For the next target, your main engine been disabled.")
		new_message("Fighters can also strafe and reverse. PRESS and HOLD "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+"/"+keyName[KEY_REVERSE]+" to do so.")
		mbox = new_message("Pass over the next beacon using these secondary thrusters.")
		point[5].state[1] = 3'kill the beacons
		point[6].state[1] = 3
		value[0] = 21
	EndIf
	
Case 21'set up the eighth beacon - USE STRAFING
	If mbox.fin
		mbox = Null
		point[7] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
		set_objective(0,"PRESS and HOLD "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+"/"+keyName[KEY_REVERSE]+" to strafe and reverse.",0,0,True)
		set_objective(1,"Pass over the eighth beacon.",point[7].x,point[7].y,True)
		value[1] = False'we have not yet reached the beacon
		
		'make all the asteroids move
		For Local a:Ship = EachIn shipList[0]
			a.speed = RndFloat()*2
			a.movrot = Rand(0,359)
		Next
		
		value[0] = 22
	EndIf
	
Case 22'eighthe
	'have we reached the eighth beacon?
	If point[7].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[7].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
		game.clear_objectives()
		cheat_disableengines = False
		new_message("Good job. Your main thrusters have been re-enabled.")
		new_message("Now, finally, HIT " + keyName[KEY_SHIELD] + " to activate your SHIELDS.")
		new_message("When activated, shields will reduce or completely block all incoming damage for a limited time.")
		new_message("As with the afterburner, you have a limited number of activations per mission, so use them wisely.")
		mbox = new_message("Pass over the final beacon without taking any damage.")
		ships[0].points = ships[0].pointMax'reset shield amount
		point[7].state[1] = 3'kill the beacon
		value[0] = 23
		point[0] = Null
		
		'stop all the asteroids
		For Local a:Ship = EachIn shipList[0]
			a.speed = 0
		Next
	EndIf

Case 23'set up the ninth beacon - SHIELDS
	If mbox.fin
		mbox = Null

		point[0] = add_beacon(600,600)
		value[1] = False'we have not yet reached the beacon
		set_objective(0,"HIT the SPACEBAR or ENTER to activate shields.",0,0,True)
		set_objective(1,"Pass over the ninth beacon",point[0].x,point[0].y,True)		
		
		For Local a:Ship = EachIn shipList[0]
			'stop all the asteroids
			a.speed = 0
			'remove all asteroids close to the beacon
			If approxDist(a.x-point[0].x,a.y-point[0].y) < 160
				RemoveLink a.link
				ListRemove(shipList[0],a)
			EndIf
		Next
		
		'make some asteroids bordering the beacon
		For Local i = 1 To 8
			Local adist = 100
			Local atheta = 180 + i*45
			Local ax = point[0].x + Cos(atheta)*adist
			Local ay = point[0].y + Sin(atheta)*adist
			Local a:Ship = new_ship("Asteroid 2",ax,ay,"",inertSquad)
			a.spin = (RndFloat()-.5)*2
			shipList[0].addLast(a)
		Next
		
		value[0] = 24
	EndIf
	
Case 24'ninthe
	'have we reached the ninth beacon?
	If point[0].state[0] = 2'if the player is on the beacon
		value[1] = True'we're on top of the beacon
		point[0].state[1] = 1'highlight the beacon
	
	ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
		clear_objectives()
		new_message("Good job.")
		new_message("It's time to use what you've learned. Several enemy fighters are about to enter the area.")
		mbox = new_message("Your weapons have been re-enabled. Get them!")
		ships[0].add_comp("Plasma",-1,2)
		ships[0].add_comp("Plasma",1,2)
		point[0].state[1] = 3'kill the beacon
		value[0] = 25
		
		'make all the asteroids move
		For Local a:Ship = EachIn shipList[0]
			a.speed = RndFloat()*2
			a.movrot = Rand(0,359)
		Next
		ClearList(shipList[0])
	EndIf
	
Case 25'FLEAS!!!
	If mbox <> Null And mbox.fin
		mbox = Null
		set_objective(1,"Destroy the incoming fighters")
		'introduce the fighters
		For Local i = 0 To 2
			squads[0] = new_squad("hold",2)
			Local s:Ship = new_ship("Flea",-game.width+30,SHEIGHT/3+i*40,"default",squads[0])
			s.armourMax = 2
			s.reset()
			shipList[0].addLast(s)
		Next
	EndIf
	
	'are there any left?
	Local done = True
	For Local s:Ship = EachIn shipList[0]
		If s.armour > 0 Then done = False
	Next
	If done
		clear_objectives()
		new_message("Good job.")
		mbox = new_message("You have completed the tutorial. Fighters will continue to show up until you press ESC.")
		value[0] = 26
	EndIf
	
Case 26'FlEASSSSSSSSSSS!!!!!
	If mbox <> Null And mbox.fin
		mbox = Null
		set_objective(1,"Destroy as many fighters as you want.")
		set_objective(2,"Hit ESC to exit the tutorial.",0,0,True)
	EndIf
	
	
	'are there any left?
	Local done = True
	For Local s:Ship = EachIn shipList[0]
		If s.armour > 0 Then done = False
	Next
	If done
		ClearList(shipList[0])
		'introduce the fighters
		For Local i = 0 To 2
			squads[0] = new_squad("hold",2)
			Local s:Ship = new_ship("Flea",-game.width+30,SHEIGHT/3+i*40,"default",squads[0])
			s.armourMax = 2
			s.reset()
			shipList[0].addLast(s)
		Next
	EndIf
EndSelect
	
	
	
	
	
	
