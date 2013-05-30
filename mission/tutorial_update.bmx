'-- TESTDRIVE UPDATE --
'drive around an asteroid field

'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

If p1.armour <= 0
	'start a respawn timer
	value[3]:+ frameTime
	If value[3] > 3000
		new_message("Your ship has died. Try to be more careful with the new one, yeah?")
		p1.reset()
		p1.link = entityList.addLast(p1)
		value[3] = 0
	EndIf
EndIf

'------------------------------SECTION 1---------------------------------------------------
Select pilot.tutSection
Case 0'shooting

	'what stage of the tutorial are we at?
	Select value[0]
	Case 0'intro messages, stationary astroid shooting
	
		'setup the player
		p1 = new_ship("Vector Turret",0,0,"",pilot.psquad)
		p1.behavior = "player"
	
		'make a couple of asteroids around the turret (shipList[0] will track these asteroids)
		For Local i = 0 To 3
			Local adist = Rand(100,SHEIGHT/2-100)
			Local ax = Cos(90*i)*adist
			Local ay = Sin(90*i)*adist
			Local a:Ship
			If Rand(1,3)<2 Then a = new_ship("Vector Asteroid 2",ax,ay,"",inertSquad) Else a = new_ship("Vector Asteroid 1",ax,ay,"",inertSquad)
			a.spin = (RndFloat()-.5)*2
			shipList[0].addLast(a)
		Next
	
		new_message("To FIRE PRIMARY WEAPONS, press and hold the LEFT MOUSE BUTTON.")
		mbox = new_message("DESTROY the surrounding asteroids.")
		value[0] = 1
		
	Case 1'time to shoot some astroids with your turret!
	
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
			ClearList(game.objectiveList)
			new_message("Good job.")
			mbox = new_message("Now some asteroids will float by. Try to destroy these MOVING TARGETS.")
			ClearList(shipList[0])
		ElseIf ListIsEmpty(shipList[0])
			If mbox.fin
				value[0] = 2
				new_objective("Destroy all of the drifting asteroids")
			EndIf
		ElseIf mbox.fin And ListIsEmpty(objectiveList)
			new_objective("PRESS and HOLD the LEFT MOUSE BUTTON to fire",True,0,0,Null)
			new_objective("Destroy all of the surrounding asteroids")
		EndIf
		
	Case 2,4'spawn some moving asteroids
		mbox = Null
		ClearList(shipList[0])
		For Local i = 0 To 3
			Local ax = p1.x + 700/(1+(3*(i Mod 2)))*Sgn(i*2-3)
			Local ay = p1.y + 700/(1+(3*((i+1) Mod 2)))*Sgn(i*2-3)'holy bejeezus i hope these work
			Local a:Ship = new_ship("Vector Asteroid 1",ax,ay,"",new_squad("inert",2))
			a.spin = (RndFloat()-.5)*2
			a.movrot = 90*i
			a.speed = (RndFloat()+.6)*50
			a.mass:* 3
			shipList[0].addLast(a)
		Next
		If value[0] = 2 Then value[0] = 3 Else value[0] = 5'check or destruction of first wave -OR- move on to spawn collision asteroid
	
	Case 3'check to see if they've killed the first set of moving asteroids
		Local done = True		'did we kill them all?
		For Local s:Ship = EachIn shipList[0]
			If s.armour > 0 Then done = False
			Local dx = s.x-p1.x
			Local dy = s.y-p1.y
			If approxDist(dx,dy) > SHEIGHT Then s.movrot = Floor(ATan2(dy,dx)+180 / 90) * 90
		Next
		If done And mbox = Null
			ClearList(game.objectiveList)
			new_message("Good job.")
			new_message("More asteroids are on their way. Get ready!")
		ElseIf done
			If mbox.fin
				new_objective("Destroy all of the drifting asteroids")
				value[0] = 4'spawn more asteroids
			EndIf
		EndIf
		
	Case 5'spawn a collision asteroid in the middle of things
		Local acount = CountList(shipList[0])'count how many they've killed
		For Local s:Ship = EachIn shipList[0]
			If s.armour <= 0 Then acount:- 1
			Local dx = s.x-p1.x
			Local dy = s.y-p1.y
			If approxDist(dx,dy) > SHEIGHT Then s.movrot = Floor(ATan2(dy,dx)+180 / 90) * 90
		Next
		
		If acount = 2 And ships[2] = Null'once we've killed two asteroids, make a rogue killer one
			Local arot = Rand(0,359)
			ships[2] = new_ship("Vector Asteroid 2",p1.x+Cos(arot)*750,p1.y+Sin(arot)*750,"",new_squad("inert",2))
			ships[2].movrot = ATan2(p1.y-ships[2].y,p1.x-ships[2].x)
			ships[2].speed = 100
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
				value[0] = 4
			EndIf
		
		'once we've killed all the asteroids
		ElseIf acount <= 0 And ships[2].armour <= 0
			If mbox = Null
				new_message("Good job. You were able to destroy that larger asteroid before it hit you.")
				mbox = new_message("WIK: tell them about alternate weapons!")
			ElseIf mbox.fin
				ClearList(game.objectiveList)
				mbox = Null
				value[0] = 8
				game.over = True
			EndIf
		EndIf
	EndSelect
EndSelect
	
'--------------------------SECTION 2---------------------------------'SHIP MOVEMENT
Select pilot.tutSection
Case 1'movement

	'disable the guns
	If value[0] <= 13
		For Local group = 0 To 3
			ClearList(p1.gunGroup[group])
		Next
	ElseIf ListIsEmpty(p1.gunGroup[0])
		p1.recalc()
	EndIf
	
	'remove dead asteroids
	For Local a:Ship = EachIn shipList[0]
		If a.placeholder.dead Then ListRemove(shipList[0],a)
	Next

	'what stage of the tutorial are we at?
	Select value[0]
	Case 0
		'make the new ship for the player to control
		p1 = new_ship("Vector Ship",0,0,"default",p1.squad)
		p1.behavior = "player"
		
		new_message("Similar to aiming, a fighter STEERS by facing the MOUSE.")
		mbox = new_message("To THRUST, press " + keyName[KEY_THRUST]+".")
		new_message("Try to pass over this beacon.")
		value[0] = 1
		
	Case 1'set up first beacon - THRUSTING
		If mbox.fin
			mbox = Null
			point[0] = add_beacon(450,100)
			value[1] = False'we have not yet reached the beacon
			new_objective("PRESS and HOLD " + keyName[KEY_THRUST] + " to thrust",True)
			new_objective("Pass over the beacon",True,point[0].x,point[0].y)
			value[0] = 2
		EndIf
		
	Case 2'first beacon
	
		'have we reached the first beacon?
		If point[0].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[0].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon but no longer, we've passed over it
			ClearList(game.objectiveList)
			new_message("Good job.")
			mbox = new_message("Now try to pass over the next beacon while avoiding these asteroids.")
			point[0].state[1] = 3'kill the beacon
			value[0] = 3
		EndIf
		
	Case 3'set up second beacon - AVOID STATIONARY
		If mbox.fin
			mbox = Null
			new_message("If you're having trouble finding it, HIT "+ keyName[KEY_MAP] + " to display the map.")
			point[1] = add_beacon(-(game.width-100),Rand(-game.height/1.2,game.height/1.2))
			value[1] = False'we have not yet reached the beacon
			new_objective("Pass over the second beacon.",True,point[1].x,point[1].y)
			new_objective("Hit " + keyName[KEY_MAP] + " to display the map.")
			
			'make some asteroids around the field
			For Local i = 0 To 31
				Local adist,atheta,ax,ay,collide
				Local a:Ship = new_ship("Vector Asteroid 2",0,0,"",inertSquad)
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
			
			value[0] = 4
		EndIf
		
	Case 4'second beacon
		'have we reached the second beacon?
		If point[1].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[1].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
			ClearList(game.objectiveList)
			new_message("Good job.")
			mbox = new_message("Now the asteroids will be moving. Try reaching the next beacon. Get ready!")
			point[1].state[1] = 3'kill the beacon
			value[0] = 5
		EndIf
		
	Case 5'set up the third beacon - AVOID MOVING OBJECTS
		If mbox.fin
			mbox = Null
			point[2] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
			value[1] = False'we have not yet reached the beacon
			new_objective("Pass over the third beacon",True,point[2].x,point[2].y)
			
			'make all the asteroids move
			For Local a:Ship = EachIn shipList[0]
				a.speed = RndFloat()*100
				a.movrot = Rand(0,359)
			Next
			
			value[0] = 6
		EndIf
		
	Case 6'third beacon
		'have we reached the third beacon?
		If point[2].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[2].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
			ClearList(game.objectiveList)
			new_message("Good job.")
			mbox = new_message("Now try to pass over the next beacon without running into the bordering asteroids. ")
			'new_message("Fighters can also strafe and reverse. PRESS and HOLD "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+"/"+keyName[KEY_REVERSE]+" to do so.")
			'mbox = new_message("I'm about to disable your main thruster.")
			point[2].state[1] = 3'kill the beacon
			value[0] = 9
		EndIf
		
	Case 7'set up the forth beacon - USE STRAFING
		If mbox.fin
			cheat_disableengines = True
			mbox = Null
			point[3] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
			new_message("Pass over the next beacon using these secondary thrusters.")
			new_objective("PRESS and HOLD "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+"/"+keyName[KEY_REVERSE]+" to strafe and reverse.",True)
			new_objective("Pass over the forth beacon.",True,point[3].x,point[3].y)
			value[1] = False'we have not yet reached the beacon
			
			'make all the asteroids move
			For Local a:Ship = EachIn shipList[0]
				a.speed = RndFloat()*100
				a.movrot = Rand(0,359)
			Next
			
			value[0] = 8
		EndIf
		
	Case 8'fourth beacon
		'have we reached the fourth beacon?
		If point[3].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[3].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
			ClearList(game.objectiveList)
			cheat_disableengines = False
			new_message("Good job.")
			mbox = new_message("Now try to pass over the next beacon without running into the bordering asteroids. ")
			point[3].state[1] = 3'kill the beacon
			value[0] = 9
		EndIf
			
	Case 9'set up the fourth beacon - REVERSE
		If mbox.fin
			mbox = Null
			point[3] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
			value[1] = False'we have not yet reached the beacon
			new_objective("Pass over the fourth beacon",True,point[3].x,point[3].y)
			p1.reset()'reset the player's stats
			
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
				Local a:Ship = new_ship("Vector Asteroid 2",ax,ay,"",inertSquad)
				a.spin = (RndFloat()-.5)*2
				shipList[0].addLast(a)
			Next
			
			value[0] = 10
		EndIf
			
	Case 10'forthe
		'have we reached the forth beacon?
		If point[3].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[3].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
			ClearList(game.objectiveList)
			new_message("Good job.")
			mbox = new_message("For the next beacon, you will need to STOP on top of it for FIVE SECONDS to continue.")
			point[3].state[1] = 3'kill the beacon
			value[0] = 11
		EndIf
		
	Case 11'set up the fifth beacon - STOP
		If mbox.fin
			mbox = Null
			point[4] = add_beacon(Rand(-game.width/1.2,game.width/1.2),Rand(-game.height/1.2,game.height/1.2))
			value[1] = 5 ' five seconds left
			value[0] = 12
			new_objective("Stop on top of the fifth beacon for 5 seconds]",True,point[4].x,point[4].y)
		EndIf
		
	Case 12'fifthe - STOP
		
		'have we reached the fifth beacon?
		If point[4].state[0] = 2'if the player is on the beacon
			'countdown the timer
			value[1]:- (frameTime/1000.0)
			point[4].state[1] = 1'highlight the beacon
			
			'display the timer
			If flashtext <> "-[ "+String(Int(Ceil(value[1])))+" ]-" And value[1] >= 0 Then add_flashtext("-[ "+Int(Ceil(value[1]))+" ]-")
			
		ElseIf value[1] > 0'we fell off
			'reset the timer
			value[1] = 5
			point[4].state[1] = 0'un-highlight the beacon
			
			clear_flashtext()
		EndIf
		
		If value[1] <= 0 And mbox = Null'we sat on the beacon for the right amount of time
			clear_flashtext()
			ClearList(game.objectiveList)
			playSFX(beacon_sfx,p1.x,p1.y)
			new_message("Good job.")
			mbox = new_message("The beacon will begin to MOVE. ")
			mbox.addText("You need to STAY ON TOP of it for FIVE SECONDS to continue.")
		EndIf
		
		'set up the next phase
		If mbox <> Null And mbox.fin
			mbox = Null
			point[4].state[1] = 0'highlight the beacon
			point[4].speed = 80
			point[4].movrot = 0
			value[1] = 5'reset the timer
			value[0] = 13
			new_objective("Match velocities with the fifth beacon for 5 seconds.",point[4].x,point[4].y)
		EndIf
		
	Case 13'fifthe - MATCH VELOCITIES
		
		'bounce the beacon back and forth
		If point[4].x >= width-100 Then point[4].movrot = 180
		If point[4].x <= -width+100 Then point[4].movrot = 0
		
		'have we reached the fifth beacon?
		If point[4].state[0] = 2'if the player is on the beacon
			'countdown the timer
			value[1]:- (frameTime/1000.0)
			point[4].state[1] = 1'highlight the beacon
			
			'display the timer
			If flashtext <> "-[ "+String(Int(Ceil(value[1])))+" ]-" And value[1] >= 0 Then add_flashtext("-[ "+Int(Ceil(value[1]))+" ]-")
			
		ElseIf value[1] > 0'we fell off
			'reset the timer
			value[1] = 5
			point[4].state[1] = 0'un-highlight the beacon
			
			clear_flashtext()
		EndIf
		
		If value[1] <= 0 And mbox = Null'we sat on the beacon for the right amount of time
			clear_flashtext()
			ClearList(game.objectiveList)
			point[4].state[1] = 3'kill the beacon
			mbox = new_message("Good job.")
			
		EndIf
		
		If mbox <> Null And mbox.fin
			mbox = Null
			new_message("Your weapons have been re-enabled. Destroy some asteroids!")
			new_objective("Destroy 5 asteroids.")
			value[0] = 14
		EndIf
		
		
	Case 14'destroy a couple of asteroids
		Local asteroidCount = CountList(shipList[0])
		
		'track the starting number of asteroids
		If value[4] = 0 Then value[4] = asteroidCount
		
		'see if we've destroyed a couple yet
		If mbox = Null And asteroidCount <= value[4] - 5 Or asteroidCount <= 2
			ClearList(game.objectiveList)
			value[4] = 0
			mbox = new_message("Good job. You will now learn how to pilot FRIGATES.")
		EndIf
		
		If mbox <> Null And mbox.fin
			game.fade = 1
			value[0] = 15
		EndIf
		
	Case 15'setup frigate movement
		If game.currentfade = 1 And game.fade = 1
			mbox = Null
			RemoveLink(p1.link)
			p1 = new_ship("Vector Frigate",0,0,"default",p1.squad)
			p1.behavior = "player"
			game.fade = 0
		EndIf
		
		If game.fade = 0
			If mbox = Null And game.currentfade <= 0
				new_message("Heavier ships are flown a little differently than fighters.")
				new_message("Instead of steering with the mouse, FRIGATES use "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+" to turn.")
				new_message("As such, they lose the ability to strafe, but can move and shoot in separate directions.")
				mbox = new_message("Destroy a couple of asteroids to continue.")
			EndIf
			
			If mbox <> Null And mbox.fin
				mbox = Null
				new_objective("Use "+keyName[KEY_STRAFELEFT]+"/"+keyName[KEY_STRAFERIGHT]+" to turn.",True)
				new_objective("Destroy 5 asteroids.")
				value[0] = 16
			EndIf
		EndIf
		
	Case 16'frigate flight test
		Local asteroidCount = CountList(shipList[0])
		
		'track the starting number of asteroids
		If value[4] = 0 Then value[4] = asteroidCount
		
		'see if we've destroyed a couple yet
		If asteroidCount <= value[4] - 5 Or asteroidCount <= 2
			ClearList(game.objectiveList)
			mbox = new_message("Good job. This concludes the MOVEMENT TUTORIAL.")
		EndIf
		
		If mbox <> Null And mbox.fin Then game.over = 1
		
	EndSelect
EndSelect
	
'-------------------------- SECTION 2 - ABILITIES --------------------------------
Select pilot.tutSection
Case 2'afterburner + abilities
	
	'what stage of the tutorial are we at?
	Select value[0]
	Case 0'sixthe+seventhe - AFTERBURNER
	
		'make the new ship for the player to control
		p1 = new_ship("Vector Ship",0,0,"default",p1.squad)
		p1.behavior = "player"
	
		'make some asteroids around the field
		For Local i = 0 To 31
			Local adist,atheta,ax,ay,collide
			Local a:Ship = new_ship("Vector Asteroid 2",0,0,"",inertSquad)
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
		
		new_message("All ships are equipped with and AFTERBURNER, which allows them to move faster for a short time.")
		new_message("PRESS and HOLD " + keyName[KEY_AFTERBURN] + " to use your afterburner.")
		mbox = new_message("You only have a few seconds of fuel, but it regenerates when not in use.")
		new_message("Hit these two beacons in quick succession to continue.")
		
		value[0] = 1
	
	Case 1'afterburner between two beacons
		'setup up afterburner beacons
		If mbox <> Null And mbox.fin
			mbox = Null
			'the two beacons to hit
			point[5] = add_beacon(150,0)
			point[6] = add_beacon(600,0)
			new_objective("PRESS and HOLD " + keyName[KEY_AFTERBURN] + " to use your afterburner.")
			new_objective("Pass over these two beacons in quick succession",True,point[5].x,point[5].y)
			value[1] = -1'we haven't triggered the time limit yet
			value[0] = 2
		EndIf
	
	Case 2
		Local done = False
		
		'have we reached either beacon?
		If point[5].state[0] = 2'if the player is on the beacon
			point[5].state[1] = 1'highlight the beacon
			'if we're not counting down
			If value[1] = -1 Or value[1] > .3
				'start the countdown
				value[1] = .4
			'if we ARE still counting down
			ElseIf point[6].state[1] = 1'if the other beacon is highlighted
				done = True
			EndIf
		EndIf
		If point[6].state[0] = 2'if the player is on the beacon
			point[6].state[1] = 1'highlight the beacon
			'if we're not counting down
			If value[1] = -1 Or value[1] > .3
				'start the countdown
				value[1] = .4
			'if we ARE still counting down
			ElseIf point[5].state[1] = 1'if the other beacon is highlighted
				done = True
			EndIf
		EndIf
		
		'count the timer down
		If value[1] > -1
			value[1]:- (frameTime/1000.0)
		'reset the timer, beacons if we run out of time
		Else
			value[1] = -1
			'un-highlight the beacons
			point[5].state[1] = 0
			point[6].state[1] = 0
		EndIf
		
		'if we've gotten to both of them in the right amount of timer
		If done And mbox = Null
			ClearList(game.objectiveList)
			
			'kill the beacons
			point[5].state[1] = 3
			point[6].state[1] = 3
			
			new_message("Good job.")
			new_message("To activate your SHIELDS, HIT " + keyName[KEY_SHIELD] + ".")
			new_message("Shield block ALL incoming damage for a LIMITED TIME.")
			mbox = new_message("However, you have a limited number of activations, so use them wisely.")
			new_message("Try to pass over the next beacon without taking any damage.")
		EndIf
		
		If mbox <> Null And mbox.fin
			mbox = Null
		
			'stop all the asteroids
			For Local a:Ship = EachIn shipList[0]
				a.speed = 0
			Next
			
			p1.points = p1.pointMax'reset shield amount
			
			'set up the ninth beacon - SHIELDS
			point[0] = add_beacon(600,600)
			value[1] = False'we have not yet reached the beacon
			new_objective("HIT " + keyName[KEY_SHIELD] + " to activate shields.",True)
			new_objective("Pass over the next beacon without taking damage.",True,point[0].x,point[0].y)		
			
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
				Local a:Ship = new_ship("Vector Asteroid 2",ax,ay,"",inertSquad)
				a.spin = (RndFloat()-.5)*2
				shipList[0].addLast(a)
			Next
			
			value[0] = 3
		EndIf
			
	Case 3'SHEILD BEACON
		'have we reached the ninth beacon?
		If point[0].state[0] = 2'if the player is on the beacon
			value[1] = True'we're on top of the beacon
			point[0].state[1] = 1'highlight the beacon
		
		ElseIf value[1]'we WERE touching the beacon, but no longer- we've passed over it.
			ClearList(game.objectiveList)
			point[0].state[1] = 3'kill the beacon
			new_message("Good job.")
			value[0] = 4
		EndIf
	Case 4'set up point collection
		If mbox = Null
			new_message("Enemies and some asteroids drop POINTS when destroyed.")
			mbox = new_message("These points can be spent to get upgrades between missions.")
			new_message("Collect fifteen points to continue.")
		ElseIf mbox <> Null And mbox.fin
			mbox = Null
			
			new_objective("Collect 15 points by destroying asteroids.",True)
			
			'give all asteroids some points, make them move again
			For Local a:Ship = EachIn shipList[0]
				'move all the asteroids
				a.speed = RndFloat()*100
				a.movrot = Rand(0,359)
				'give them points
				For Local p = 0 To Rand(2,4)
					a.dropList.addLast(add_item("point",point1_gfx,0,0,0,0,False))
				Next
			Next
			
			value[0] = 5
		EndIf
	
	Case 5'point collection
		'count the number of points in player's posession
		Local pointnum
		For Local point:Item = EachIn p1.dropList
			pointnum:+ 1
		Next
		
		'if we've collected enough
		If pointnum >= 15
			If mbox = Null
				mbox = new_message("Good job.")
			ElseIf mbox.fin
				game.fade = 1
				ClearList(shipList[0])
				value[0] = 6
			EndIf
		EndIf
		
	Case 6'tenthe + eleventhe; BLINK
		If game.currentfade = 1
			game.fade = 0	
			
			'give the player a new ship
			RemoveLink(p1.link)
			p1 = new_ship("Vector Frigate",0,0,"default",pilot.psquad)
			p1.behavior = "player"
			
			new_message("Some ships have a different activated ability.")
			new_message("This frigate, for example, has BLINK; a short-range instant teleportation ability that gets you out of a tight spot fast.")
			new_message("You will reappear at your MOUSE's location.")
			new_message("Try to blink from one of these beacons to the other.")
			
			'the two beacons to hit
			point[5] = add_beacon(-250,0)
			point[6] = add_beacon(300,0)
			new_objective("HIT " + keyName[KEY_SHIELD] + " to BLINK..",True)
			new_objective("Teleport from one beacon to the other.")
			value[1] = -1'we haven't triggered the time limit yet
			value[0] = 7
			
		EndIf		
	
	Case 7'BLINK beacons
		Local done = False
		
		'have we reached either beacon?
		If point[5].state[0] = 2'if the player is on the beacon
			point[5].state[1] = 1'highlight the beacon
			'if we're not counting down
			If value[1] = -1 Or value[1] > .1
				'start the countdown
				value[1] = .15
			'if we ARE still counting down
			ElseIf point[6].state[1] = 1'if the other beacon is highlighted
				done = True
			EndIf
		EndIf
		If point[6].state[0] = 2'if the player is on the beacon
			point[6].state[1] = 1'highlight the beacon
			'if we're not counting down
			If value[1] = -1 Or value[1] > .1
				'start the countdown
				value[1] = .15
			'if we ARE still counting down
			ElseIf point[5].state[1] = 1'if the other beacon is highlighted
				done = True
			EndIf
		EndIf
		
		'count the timer down
		If value[1] > -1
			value[1]:- (frameTime/1000.0)
		'reset the timer, beacons if we run out of time
		Else
			value[1] = -1
			'un-highlight the beacons
			point[5].state[1] = 0
			point[6].state[1] = 0
		EndIf
		
		'if we've gotten to both of them in the right amount of timer
		If done
			ClearList(game.objectiveList)
			point[5].state[1] = 3'kill the beacons
			point[6].state[1] = 3
			new_message("Good job.")
			game.over = 1
		EndIf

	EndSelect
EndSelect
			
	
	
	
