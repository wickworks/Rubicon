
Function ship_AI(s:Ship)

	'clear the old direction descision information (default to direction they're facing
	s.AI_dir[0] = Cos(s.rot)
	s.AI_dir[1] = Sin(s.rot)

	Select Lower(s.behavior)

	Case "player"
		'set squad position to player
		s.squad.goal_x = s.x
		s.squad.goal_y = s.y
		
		'target closest enemy
		's.target_closest()
		
	
	'---------------------------ATTACK BEHAVIROS----------------------------

	'protect: stay near the squad's target while shooting enemies
	'mine: scour the battlefield sucking up points
	Case "protect","miner"
		s.proximity_track = True
		
		If s.behavior = "miner"
			s.squad.circle_dist = 2000 'circles a wide area
			s.fireGroup(True)'sucks up points
			'shed excess points
			For Local i:Item = EachIn s.dropList
				If CountList(s.dropList) <= s.mass / 4 Then Exit
				If i.name = "point" Then ListRemove(s.dropList,i)
			Next
		EndIf
		
		'if detect proximity, see how badly we want to avoid them
		If Not ListIsEmpty(s.proximity_shipList) Then AI_avoidcollision(s)
		
		If s.squad.target <> Null
			s.squad.goal_x = s.squad.target.x
			s.squad.goal_y = s.squad.target.y
		Else
			s.squad.goal_x = s.squad.x
			s.squad.goal_y = s.squad.y
		EndIf
		
		'no target, fly in circles looking for a target
		If s.target = Null
			AI_hold(s, s.squad.goal_x, s.squad.goal_y)
		Else
			'circle the target, shooting them
			AI_circle(s)
		EndIf
			
	Case "circle","support","divebomb"
		'[0] - attack state: 0=none | 1=divebomb incoming | -1=divebomb outgoing | 2=circle

		'we care about nearby things!
		s.proximity_track = True

		'if detect proximity, see how badly we want to avoid them
		If Not ListIsEmpty(s.proximity_shipList) Then AI_avoidcollision(s)

		'no target, fly in circles looking for a target
		If s.target = Null
			AI_hold(s, s.squad.goal_x, s.squad.goal_y)
			
		Else
			'sets the squad's goal to the target
			s.squad.goal_x = s.target.x
			s.squad.goal_y = s.target.y
		
			'circle the target, shooting them
			If s.behavior = "circle"
				AI_circle(s)
			ElseIf s.behavior = "divebomb"
				AI_divebomb(s)
			Else
				AI_circle(s,False)
				s.turn(ATan2(s.AI_dir[1],s.AI_dir[0]))
				s.add_thrust(ATan2(s.AI_dir[1],s.AI_dir[0]), 1.0, True)
			EndIf
		EndIf
		
		'if we don't have a goal, set the goal to self
		If s.squad.goal_x = 0 And s.squad.goal_y = 0
			s.squad.goal_x = s.x
			s.squad.goal_y = s.y
		EndIf
		
	Case "ram"
		'[0] - attack state: 0=none | 1=divebomb incoming | -1=divebomb outgoing | 2=circle

		'we care about nearby things!
		s.proximity_track = True
		
		'...but not a lot
		s.squad.avoidcollision_dist = AI_AVOIDCOLLISION_DIST/2

		'we cannot bump into the target (hopefully, we have a weapon that triggers when we're close)
		If s.target <> Null And Not s.target.dead
			If ListIsEmpty(s.ignoreList)
				s.ignoreList.addLast(s.target)
				'what was i thinking?: I was searching for a pointer that matched the pointer I already had...
				'For Local _s:Ship = EachIn entityList' terrible way to look for the placeholder's ship, but the game's due soon
				'	If _s.placeholder = s.target Then s.ignoreList.addLast(_s)
				'Next
			EndIf
		EndIf

		'if detect proximity, see how badly we want to avoid them
		If Not ListIsEmpty(s.proximity_shipList) Then AI_avoidcollision(s)

		'no target, fly in circles looking for a target
		If s.target = Null Or s.target.dead
			'Print "HOLDING @ "+s.squad.goal_x+","+s.squad.goal_y
			AI_hold(s, s.squad.goal_x, s.squad.goal_y)
			
			'we're not trying to bump into anything
			ClearList(s.ignoreList)
		Else

			'are we ready to fire?
			Local cooldown = True
			For Local g:Gun = EachIn s.gunGroup[0]
				If g.fireDelay_timer <= 0 Then cooldown = False
			Next
			
			'if our ram is off cooldown
			If Not cooldown
				'find the ship's angle, distance to the target
				Local tar_dist = approxDist(s.x-s.target.x,s.y-s.target.y)
				Local tar_theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
			
				'RAMMING SPEED!
				AI_goto(s, s.target.x, s.target.y)
				'Print "RAMMING SPEED @ " + s.target.x+","+s.target.y
				
				If tar_dist <= s.rangeGroup(0) Then s.fireGroup(0)
			'if we need to wait for a bit
			Else
				AI_circle(s)
			EndIf
		EndIf

	Case "patrol"'goto a location, but stop to fight
		'we care about nearby things!
		s.proximity_track = True

		'if detect proximity, see how badly we want to avoid them
		If Not ListIsEmpty(s.proximity_shipList) Then AI_avoidcollision(s)

		'no target, go to the location
		If s.target = Null
			AI_goto(s, s.squad.goal_x, s.squad.goal_y)
			
			AI_gettarget(s)
		Else
			'circle the target, shooting them
			AI_circle(s)
		EndIf
			
	Case "heal"'cuttlefish hangs out around the player, heals
		's.AI_value[0] : 0=find, heal player | 1=escape to edge of screen
	
		'we care about nearby things!
		s.proximity_track = True

		Local pdist#

		'if we're looking for the player
		If s.AI_value[0] = 0
			'go towards the player
			If p1 <> Null
				s.squad.goal_x = p1.x
				s.squad.goal_y = p1.y
				
				'don't avoid the player
				pdist = approxDist(p1.x - s.x, p1.y - s.y)
				If pdist > (ImageWidth(p1.gfx[0])+ImageHeight(p1.gfx[0]))/3 + ImageHeight(s.gfx[0])/2 + 50
					ListRemove(s.proximity_shipList, p1.placeholder)
				EndIf
			Else
				s.squad.goal_x = s.x
				s.squad.goal_y = s.y
			EndIf
		EndIf
		
		'if detect proximity, see how badly we want to avoid them
		If Not ListIsEmpty(s.proximity_shipList) Then AI_avoidcollision(s)

		'if we're looking for the player
		If s.AI_value[0] = 0
			'hang out around the player
			If pdist > 300 Then AI_stay(s, s.squad.goal_x, s.squad.goal_y)
				
			'hold still if pretty close
			If pdist > 50
				'face and thrust towards the player
				s.turn(ATan2(s.squad.goal_x,s.squad.goal_y))
				s.add_thrust(ATan2(s.AI_dir[1],s.AI_dir[0]), 1.0, True)
				
				'if the player needs healing, fire
				If p1.armour < p1.armourMax Then s.fireGroup(False,p1.x,p1.y)
			EndIf

		Else'if we're escaping
			'find the closest edge
			Local ex# = (s.x/game.width)*10
			Local ey# = (s.y/game.height)*10
			
			'and go at it
			s.turn(ATan2(ey, ex))
			s.add_thrust(ATan2(ey + s.AI_dir[1], ex + s.AI_dir[0]), 1.0, True)
		EndIf
			
	Case "turret"'aim at the target and fire until it gets out of range or dies (also, deccelerates). otherwise, spins around
		
		'check for targets every second
		AI_gettarget(s,1000)
		
		'if we're busy shooting at nearby things
		'If AI_destroycollision(s)
			s.turn(ATan2(s.AI_dir[1],s.AI_dir[0]))'destroycollision handles the shooting
		
		'if we can shoot at the target
		'Else
		If s.target <> Null
			'turn towards target
			Local tar_theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
			s.turn(tar_theta)
			
			'fire away!
			Local tarDist = approxDist(s.target.x-s.x,s.target.y-s.y)
			Local range0 = s.rangeGroup(0)
			Local range1 = s.rangeGroup(1)
			If tarDist < range0 Then s.fireGroup(False,s.target.x,s.target.y)	'turrets don't do any of that newfangled predictive nonsense!
			If tarDist < range1 Then s.fireGroup(True)					'...well, maaaybe a little...
			
			'if target is out of range or dies, stop tracking it
			If (tarDist >= range0 And tarDist >= range1) Then s.target = Null
		
		'nothing to shoot at
		Else 
			'spin slowly
			s.turn(1,False)
			
		EndIf
		
		'resist movement
		If s.speed > 0 Then s.add_force(s.movrot+180, constrain(.8 * s.speed / s.speedMax, 0, .25))
		
		
	
	'-------------------------------------------------------- ORDNANCE BEHAVIORS --------------------------------------------------------
		
	Case "alarm"
		'if detect enemy, attack! (check every 500 ms)
		s.AI_timer = s.AI_timer - frameTime
		If s.AI_timer <= 0
			s.target_closest()
			s.AI_timer = 500
		EndIf
		
		'spin slowly
		s.turn(20,False)
		
		If s.target <> Null And approxDist(s.target.x-s.x,s.target.y-s.y) > s.rangeGroup(0) Then s.target = Null'out of detection range
		
		'if detects a close intruder, start warping in fleas
		If s.target <> Null Then s.fireGroup(False)

	Case "missile"'go straight at the target, self-destruct after a certain time (if no target, go forward
		
		s.recent_damage = 0
		
		If s.target <> Null And approxDist(s.target.x-s.x,s.target.y-s.y) > s.squad.detect_dist Then s.target = Null'out of detection range
		
		'just turn and thrust all the time
		If Not s.target = Null And Not s.target.dead
			s.animated = True
			Local theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
			s.turn(theta)
			s.add_thrust(0,1)'our maxspeed is bigger 'cause it moves fast at first fired
		Else
			s.animated = False
		EndIf
		
		'exploding on target is handled by ship.collide()

		'out of fuel? EXPLODE!
		s.AI_timer = s.AI_timer - frameTime
		If s.AI_timer <= 0 Then s.fireGroup(0)
	
	Case "torpedo"'go toward a target until they pass it
		s.recent_damage = 0
	
		'if we have not yet passed the target
		If s.AI_value[0] = 0
			'try and turn towards the place clicked
			Local theta# = ATan2(s.squad.goal_y-s.y,s.squad.goal_x-s.x)
			s.turn(theta)'destroycollision handles the shooting
			
			'are we close to the target yet?
			If approxDist(s.squad.goal_x-s.x,s.squad.goal_y-s.y) <= 100 Then s.AI_value[0] = 1
		EndIf
	
		s.add_thrust(0,1.0)
		
		'we start out ignoring collisions. as soon as the explode becomes armed, start colliding!
		If s.ignoreCollisions
			For Local g:Gun = EachIn s.gunGroup[0]
				If g.fireDelay_timer = 0 Then s.ignoreCollisions = False
			Next
		EndIf
		
		'out of fuel? EXPLODE!
		s.AI_timer = s.AI_timer - frameTime
		If s.AI_timer <= 0 Then s.fireGroup(0)
		
	Case "mine"'edge closer to close things, otherwise chill out
		s.recent_damage = 0
		s.animated = True
		
		'check for targets every second
		If (s.AI_timer Mod 1000) <= 40
			s.target_closest()
			'untarget it if it's out of range
			If s.target <> Null And approxDist(s.target.x-s.x,s.target.y-s.y) > s.squad.detect_dist Then s.target = Null
		EndIf
		
		Print "mine faction:"+s.squad.faction
		
		'get closer to the targets
		If Not s.target = Null And Not s.target.dead
			Print "mine has target!"
			Local theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
			s.turn(theta)
			s.add_thrust(0,1.0)'our maxspeed is bigger 'cause it moves fast at first fired
			
		'chill out
		Else
			Print "mine chilling out"
			s.speed = constrain(s.speed - (frameTime/2000), 0, s.speed)
			
		EndIf
		
		'exploding on target is handled by ship.collide()

		'out of fuel? EXPLODE!
		s.AI_timer = s.AI_timer - frameTime
		If s.AI_timer <= 0 Then s.fireGroup(0)
	
	'---------------------------- SQUAD OVERWRITE BEHAVIORS --------------------------------------

	Case "goto"'go straight at the squad's goal, otherwise hold
		AI_goto(s, s.squad.goal_x, s.squad.goal_y, False)
	
	'------------------------------------------MISC BEHAVIORS-----------------------------
	Case "fire"'always fire
		s.fireGroup(False)
		s.fireGroup(True)
	
	Case "hold"'always hold
		AI_stay(s, s.squad.goal_x, s.squad.goal_y)
		
	Case "spin"'just slowly turn
		s.turn(10)
		
	Case "inert"
		s.animated = False
		
		'if inert squadrons have a goal, then they surruptitiously get transported to that goal if the player is not watching
		If (s.squad.goal_x <> 0) Or (s.squad.goal_y <> 0)
			Local goal_theta# = ATan2(s.squad.goal_y-s.y, s.squad.goal_x-s.x)
	
			'if we're far away from our goal
			If approxDist(s.squad.goal_x-s.x, s.squad.goal_y-s.y) > game.cboxSize * 3
				'if the player is elsewhere
				If approxDist(p1.x-s.x,p1.y-s.y) > game.cboxSize * 3 Then s.add_force(goal_theta, .2)
			EndIf
		EndIf
	
	Case "leech"'fly around until we see a target, then chase them - OR - stuck on the target, draining health
		
		s.squad.detect_dist = 800'have to get pretty close
		
		'the latched version?
		If Lower(s.name) = "leech"
			If s.target = Null
				'convert back to larva
				Local larva:Ship = new_ship("Larva",s.x,s.y)
				larva.rot = s.rot
				larva.movrot = s.master.movrot
				larva.speed = s.master.speed
				larva.squad.faction = s.squad.faction
				'remove thyself
				RemoveLink(s.link)
			EndIf
		'the unlatched version
		Else
			Local tarDist#
			If s.target = Null
				'if detect proximity, avoid!
				If Not ListIsEmpty(s.proximity_shipList)
					AI_avoidcollision(s)
				'just hang out
				ElseIf s.speed > 0
					s.add_thrust(180,.2)
				EndIf
		
				AI_gettarget(s)
				
			'KAMAKAZIE!
			Else
				tarDist = approxDist(s.target.x-s.x,s.target.y-s.y)
				
				'avoid other targets
				If CountList(s.proximity_shipList) > 2'you and me and the devil makes three
					AI_avoidcollision(s)
				Else
					'just turn and thrust all the time
					If Not s.target = Null And Not s.target.dead
						Local theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
						s.turn(theta)
						s.add_thrust(0,1)
					EndIf
				EndIf
				
				If tarDist > s.squad.detect_dist Then s.target = Null
			EndIf
		EndIf
	EndSelect
EndFunction

Function AI_avoidcollision(s:Ship)
	'fly away from all the ships in the proximity list
	Local tx,ty
	For Local o:Gertrude = EachIn s.proximity_shipList
		'if we have to worry about this specific proximity thing
		If Not ListContains(s.ignoreList, o)
			Local dx = s.x-o.x
			Local dy = s.y-o.y
			Local tar_dist = approxDist(dx,dy)
			If tar_dist <= s.squad.avoidcollision_dist
				Local tarWt = ((s.squad.avoidcollision_dist - tar_dist)/5)^2
				Local angle# = ATan2(dy,dx)
				tx:+ Cos(angle)*tarWt
				ty:+ Sin(angle)*tarWt
				
				SetColor 255,255,255
				'SetLineWidth tarWt / 200
				'DrawLine s.x+game.camx,s.y+game.camy,o.x+game.camx,o.y+game.camy
				'SetLineWidth 1
			EndIf	
		EndIf
	Next
	
	'SetColor 255,0,0
	'DrawLine s.x+game.camx,s.y+game.camy,s.x+game.camx+tx,s.y+game.camy+ty
	
	'tell the ship's AI how badly it wants to go away from the obstacles
	s.AI_dir[0]:+ tx
	s.AI_dir[1]:+ ty
	
EndFunction

'returns FALSE if cannot destroy the collision, otherwise TRUE
Function AI_destroycollision(s:Ship)

	'find the nearby sculler
	Local minDist = s.squad.avoidcollision_dist
	Local closest:Gertrude
	For Local o:Gertrude = EachIn s.proximity_shipList
		'find the closest non-allied
		If fTable[s.squad.faction,o.faction] <> 1 And Not o.invulnerable
			Local tarDist = approxDist(s.x-o.x, s.y-o.y)
			If tarDist <= minDist
				closest = o
				minDist = tarDist
			EndIf
		EndIf 
	Next
	
	If closest <> Null
		'find distance and angle
		Local tarDist = approxDist(closest.x-s.x,closest.y-s.y)
		Local theta# = ATan2(closest.y-s.y,closest.x-s.x)
				
		'convert to a relative angle 
		theta = Int(ASin(constrain(Sin(theta)*Cos(s.rot)-Cos(theta)*Sin(s.rot), -89,89)))
		'do we have to turn?
		If s.turnRate = -1 Or theta > s.freedomGroup(0)/2
			'tell it to back the hell up, dir is going to go away from the closest thing
			s.AI_dir[0]:- Cos(theta)*50'back up
			s.AI_dir[1]:- Sin(theta)*50
		EndIf
		
		'shoot at the target
		s.fireGroup(False,closest.x,closest.y)
		
		'we're shooting at the target
		Return True
		
	Else'there's nothing that we can do here
		AI_avoidcollision(s:Ship)
		
		Return False
	EndIf
	
EndFunction

'the ship circles around a point at some distance
'_holdDist defaults to s.squad.circle_dist
'_holdDir  1=CW | -1=CCW
Function AI_stay(s:Ship, _x#, _y#, _holdDist=0, _holdDir = 1)
	
	'find distance and angle to center point
	Local locDist# = Sqr((_x-s.x)^2+(_y-s.y)^2)+1'approxDist(_x-s.x,_y-s.y)
	Local theta# = ATan2(_y-s.y,_x-s.x)
	
	'SetColor 0,0,255
	'DrawLine s.x+game.camx,s.y+game.camy,_x+game.camx,_y+game.camy
	
	'should we go towards, alongside, or away from the squad's target?
	Local hold_radius#
	If _holdDist = 0 Then hold_radius = s.squad.circle_dist Else hold_radius = _holdDist
	hold_radius:+ s.squad.shipCount*ImageWidth(s.gfx[0])*2
	
	Local circle_theta# = theta + 90*constrain(locDist / hold_radius, 0, 2)*Sgn(_holdDir)
	
	s.AI_dir[0]:- Cos(circle_theta)*200
	s.AI_dir[1]:- Sin(circle_theta)*200
	
	'DrawText "holding: "+hold_radius+" > "+circle_theta,s.x+game.camx,s.y+game.camy+75
EndFunction

'the ship tries to go to a point.
'if _drive = true, adds thrust & turns
'if personal = true, it uses its own coordinates as current location. otherwise, uses its squads' coordinate
Function AI_goto(s:Ship, _x#, _y#, _drive = True, _personal = True)
	Local sx = s.x
	Local sy = s.y
	If Not _personal And 1=2'IT'S ALWAYS PERSONAL
		sx = s.squad.x
		sy = s.squad.y
	EndIf

	'find distance and angle to center point
	Local locDist = approxDist(_x-sx, _y-sy)
	Local theta# = ATan2(_y-sy, _x-sx)
	
	'go straight at the target
	s.AI_dir[0]:+ Cos(theta)*20
	s.AI_dir[1]:+ Sin(theta)*20
	
	If _drive
		s.turn(ATan2(s.AI_dir[1],s.AI_dir[0]))
		s.add_thrust(ATan2(s.AI_dir[1],s.AI_dir[0]), 1.0, True)
	EndIf
EndFunction

'fly around in circles looking for a target
Function AI_hold(s:Ship, _x, _y, _drive = True)
	AI_stay(s, _x, _y)
			
	'face and thrust whereever stay tells us to
	If _drive
		s.turn(ATan2(s.AI_dir[1],s.AI_dir[0]))
		s.add_thrust(0,1.0)
	EndIf

	AI_gettarget(s)
EndFunction

'if _drive = false, doens't thrust or turn to engage the target
Function AI_circle(s:Ship, _drive = True)
	'engaging a target
	If s.target <> Null
		'find the ship's angle, distance to the target
		Local tar_dist = approxDist(s.x-s.target.x,s.y-s.target.y)
		Local tar_theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
	
		'if we're too far away
		If tar_dist >= s.squad.circle_dist*2
			'go at the target
			AI_goto(s,s.target.x,s.target.y,False,False)
			
			'face and thrust whereever hold tells us to
			s.turn(ATan2(s.AI_dir[1],s.AI_dir[0]))
			s.add_thrust(0,1.0)
		
		'once we're within range
		Else
			'circle the target
			AI_stay(s, s.target.x, s.target.y, 250, binsgn(s.squad.shipCount Mod 2))

			'face the target, strafe
			If _drive
				s.turn(tar_theta)
				s.add_thrust(ATan2(s.AI_dir[1],s.AI_dir[0]), 1.0, True)
			EndIf
			
			'fire away!
			If tar_dist < s.rangeGroup(0) Then s.fireGroup(False)'primary weapon
			If tar_dist < s.rangeGroup(1) Then s.fireGroup(True)'alt weapon
			
			'check for new targets
			AI_gettarget(s)
		EndIf
	EndIf
EndFunction

Function AI_gettarget(s:Ship,_interval = 2000)
	'does this ship see any targets? (check every _interval ms)
	s.AI_timer = s.AI_timer - frameTime
	If s.AI_timer <= 0
		'target the closest enemy
		s.target_closest()
		'untarget it if it's out of range
		If s.target <> Null And approxDist(s.target.x-s.x,s.target.y-s.y) > s.squad.detect_dist Then s.target = Null
		'reset the detect timer if we have no target
		If s.target = Null Then s.AI_timer = _interval
	EndIf
EndFunction


Function AI_divebomb(s:Ship, _drive = True)
	'engaging a target
	If s.target <> Null And s.target.dead = False
		'find the ship's angle, distance to the target
		Local tar_dist = approxDist(s.x-s.target.x,s.y-s.target.y)
		Local tar_theta# = ATan2(s.target.y-s.y,s.target.x-s.x)
	
		'if we've completed an attack run
		If tar_dist <= 180 Or s.AI_value[0] = 1
			'check for new targets
			AI_gettarget(s)
		
			'set to retreat mode
			s.AI_value[0] = 1
			
			Local retreatDist# = s.squad.circle_dist*1.8
			
			'find retreat coords
			Local rx# = Cos(tar_theta+180)*retreatDist
			Local ry# = Sin(tar_theta+180)*retreatDist
		
			'retreat until we get far enough away, then start this whole thing over again
			If tar_dist > retreatDist Then s.AI_value[0] = 0 Else AI_goto(s,rx,ry,_drive,True)
		
		'if we're on an attack run
		ElseIf s.AI_value[0] = 0
			'go at the target
			AI_goto(s,s.target.x,s.target.y,_drive,True)
			
			'fire away!
			If tar_dist < s.rangeGroup(0) Then s.fireGroup(False)'primary weapon
			If tar_dist < s.rangeGroup(1) Then s.fireGroup(True)'alt weapon
		EndIf
	Else
		ClearList s.ignoreList
		s.AI_value[0] = 0'we'll start by divebombing next time
	EndIf
EndFunction
