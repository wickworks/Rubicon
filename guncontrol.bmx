Global firemodeMap:TMap = CreateMap()
MapInsert(firemodeMap, "0", "Automatic")
MapInsert(firemodeMap, "1", "Semi-automatic")
MapInsert(firemodeMap, "2", "Hold-and-release")

Type Gun
	Field name$		'what kind of gun is it. determines firing behavior
	Field dispname$	'the name to say it is
	
	Field offsetx,offsety		'x,y offset at rot=0 that shots come from (scaled by shipscale)
	
	Field icon				'the index pointer to weapon_gfx[] to use for an icon
	
	Field shotdamage#			'the damage of shots
	Field shotspeed#			'the speed of shots
	Field shotrange#			'the range of the shots
	Field freedom			'degrees of arc from center shots can fire.

	Field fireDelay#			'min delay between bursts, in ms
	Field fireDelay_timer#		'the actual timer
	
	Field burstNum = 1		'the number of shots each burst
	Field burstCount			'the counter for the number of shots left in the curret burst
	Field burstDelay# = 250	'the ms between each shot in a burst
	Field burstDelay_timer#	'the actual timer
	Field burstX,burstY		'stores where it targeted
	
	Field clip				'the current number of shots in the clip
	Field clipNum			'the number of shots in each clip (0 = no clip)
	Field reloadDelay	#		'the time it takes to reload a new clip
	Field reloadDelay_timer#	'the actual timer

	Field mode				' 	0 = automatic | 1 = semi-automatic | 2 = press-hold-release
	
	Field state#			'	tracks different things depending on the firing mode
						'	automatic : 		how long it's been held down
						'	semi-automatic : 		0 = fired and mouse has not yet been released | 1 = ready to fire
						'	press-hold-release :	% charge

	Field value#			'a variable (O RLY) for each weapon to play with in their own way
	
	Field chargetime# = 1000	'for automatic, press-hold-release weapons, this is the time (in ms) it takes for state to reach 1.0
	Field cooltime# = 1000		'for automatic weapons, how long it takes to spin charge back down
	
	
	'_s: ship that's doing the firing | _tarx,y: absolute coords we're aiming at | _release: for charge weapons, if the button was just released
	Method fire(_s:Ship,_tarx,_tary,_release=False)					
	If reloadDelay_timer <= 0'can't do anything if reloading
		'OK to fire: (firedelay timer done) AND (if semiautomatic, we didn't already fire)
		If (fireDelay_timer <= 0) And (mode <> 1 Or state = 1)
		
			'reset the fire timer (unless it's a press+hold weapon and we haven't released yet)
			If (mode <> 2 Or _release)
				'overcharged shots fire faster
				If _s.overchargeOn
					fireDelay_timer = fireDelay / _s.overcharge_mod
				Else
					fireDelay_timer = fireDelay
				EndIf
			EndIf
		
			'find the current relative position of the gun
			Local gy# = (offsetx*Sin(_s.rot+90) + offsety*Cos(_s.rot+90))*SHIPSCALE
			Local gx# = (-offsety*Sin(_s.rot+90) + offsetx*Cos(_s.rot+90))*SHIPSCALE
		
			'find relative angle, dist to target
			Local dx = _tarx-(_s.x+gx)
			Local dy = _tary-(_s.y+gy)
			Local tar_theta# = ATan2(dy,dx)
			Local tar_dist# = approxDist(dx,dy)
			
			'find the difference in shooting angle versus movement angle
			Local v_theta#= tar_theta - _s.movrot
			
			'now figure out how much we need to alter the angle of the shot to hit those coords
			'the vector for how much the velocity is gonna alter the angle of the shot
			Local v_perp# = _s.speed * Sin(v_theta)'for every timestep, the shot is going to go this far perpendicularly as a result of ship speed
			
			'find the angle to modify the shot
			Local theta_mod# = ATan2(v_perp,shotspeed)
			
			'now modify the angle of shot to correct for the movement on the ship's effect on the shot
			tar_theta:+ theta_mod
		
			'keep within bounds
			tar_theta = constrain(convert_to_relative(tar_theta, _s.rot), -freedom/2, freedom/2)
			tar_theta:+ _s.rot'(convert back to absolute)
			
			'ai has a hard time with a straight shot
			If _s <> p1 Then tar_theta:+ Rand(-2,2)
			
			'what kind of gun is firing?
			Select name
			
			'fire a bullet
			Case "plasma","plasma_burst","suppressor"
				Local s:Shot = add_shot(_s,name,shot2_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				s.trailRGB[0] = 255
				s.trailRGB[1] = 200
				s.trailRGB[2] = 120
				playSFX(laserfire1_sfx,_s.x,_s.y)
				
				'plasma guns build up a charge if you don't shoot them for a while
				If name = "plasma"
					'value field is used for charge amount
					If value >= 1
						burstNum = 3
					ElseIf value >= .6
						burstNum = 2
					Else
						burstNum = 1
					EndIf
					value = 0
				EndIf
				
				'suppressed fire gets really inaccurate as time goes on
				If name = "suppressor" Then s.movrot:+ Rand(-(state+.3)*freedom/4,(state+.3)*freedom/4)
			
			'fire a bullet
			Case "machinegun"
				Local s:Shot = add_shot(_s,name,shot3_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				s.hit_gfx = explode4_gfx
				s.hit_sfx = Null
				s.trail = False
				playSFX(autocannonfire_sfx,_s.x,_s.y)
				
			'fire a bullet
			Case "autocannon","autocannon_burst"
				Local s:Shot = add_shot(_s,name,explode4_gfx, _s.x+gx+Rand(-5,5), _s.y+gy+Rand(-5,5), tar_theta+Rand(-5,5), shotspeed, shotrange, shotdamage)
				s.scale = constrain(.7 * (shotdamage / .5), .7, 1.3)
				s.hit_gfx = explode4_gfx
				s.hit_sfx = bullethit_sfx
				's.trail_override_gfx = explode4_gfx
				's.trail_animated = False
				's.trail_scale = .5
				playSFX(autocannonfire_sfx,_s.x,_s.y)
				
			'close-range goodness
			Case "shotgun"

				Local shot = 15
				For Local i = 1 To shot
					Local spread# = Rand(-15,15)
					Local s:Shot = add_shot(_s,name,explode4_gfx, _s.x+gx, _s.y+gy, tar_theta+spread, shotspeed+(4*(RndFloat()-.5)), (RndFloat()+.5)*shotrange, shotdamage/shot)
					s.animated = False
					's.trail = False
					s.hit_sfx = bullethit_sfx
					s.trail_override_gfx = trail_gfx
					s.trail_animated = False
					s.trailRGB[0] = 200
					s.trailRGB[1] = 80
					s.trailRGB[2] = 80
					s.scale = 2
					s.RGB[0] = 200
					s.RGB[1] = 80
					s.RGB[2] = 80
				Next
				playSFX(autocannonfire_sfx,_s.x,_s.y)
				'playSFX(shotgunfire_sfx,_s.x,_s.y)
			
			'charge up, fire a penentrating shot
			Case "velocitycannon"
				Local het = ImageHeight(_s.gfx[0])/2
				Local vx# = Cos(_s.movrot)*_s.speed
				Local vy# = Sin(_s.movrot)*_s.speed
				Local offx# = -Cos(_s.rot)*(het+20)' + vx
				Local offy# = -Sin(_s.rot)*(het+20)' + vy
			
				If _release'if we've released the button
					state = Abs(state)
					Local s:Shot = add_shot(_s,name,shot6_gfx, _s.x-offx, _s.y-offy, tar_theta, shotspeed, shotrange, shotdamage * (state^2))
					s.scale = constrain(state, .3, .8)
					s.animated = False
					If state > .3
						s.skipFortify = True
						s.durable = True
						s.animated = True
					EndIf
					If state >= 1
						s.trailRGB[0] = 255
						s.trailRGB[1] = 255
						s.trailRGB[2] = 255
					Else
						s.trailRGB[0] = 180*state
						s.trailRGB[1] = 180*state
						s.trailRGB[2] = 255*state
					EndIf
					playSFX(vcannonfire_sfx,_s.x,_s.y)
				Else'if we're holding down the button
					'charge fx in front of the ship (AAA DISCLAIMER OF MY ETHICALNESS)
					SetAlpha .3 + .1*globalFrame
					'make it flash
					If Not (Abs(state) = 1 Or globalFrame) Then SetColor 255,255,255 Else SetColor 255,60,60
					'draw them
					SetBlend LIGHTBLEND
					For Local i = 1 To 4
						SetRotation (i*45)
						SetScale Abs(state),Abs(state)
						DrawImage warp2_gfx[globalFrame], _s.x-offx+game.camx, _s.y-offy+game.camy
					Next
					SetBlend ALPHABLEND
					
					'make some particles
					Local pspeed# = RndFloat()*2
					Local prot# = Rand(0,359)
					Local pvx# = Cos(prot)*pspeed
					Local pvy# = Sin(prot)*pspeed
					pspeed = approxDist(pvx+vx,pvy+vy)
					prot = ATan2(pvy+vy,pvx+vx)
					Local p:Background
					p = add_particle(_s.x-offx+Cos(prot)*RndFloat()*10, _s.y-offy+Sin(prot)*RndFloat()*10, prot, pspeed, 880*Abs(state), True)
					
					'make the particle flash the same way the charge does
					If Not (Abs(state) = 1 Or globalFrame)
						p.RGB[0] = 255
						p.RGB[1] = 60
						p.RGB[2] = 60
					EndIf
				EndIf
				
			'charge up, release a lightning bolt
			Case "arccaster"
				Local het = ImageHeight(_s.gfx[0])/2
				Local vx# = Cos(_s.movrot)*_s.speed
				Local vy# = Sin(_s.movrot)*_s.speed
			
				If _release'if we've released the button
					state = Abs(state)
					
					Local zapgfx:TImage[]
					Local zapscale# = 1
					If state > .6
						zapgfx = lightning2_gfx
						playSFX(lightning1_sfx,_s.x,_s.y)
						zapscale:+ (state-.6)
					ElseIf state > .3
						zapgfx = lightning1_gfx
						playSFX(lightning2_sfx,_s.x,_s.y)
						zapscale:+ (state-.3)
					Else
						zapgfx = lightning3_gfx
						playSFX(lightning2_sfx,_s.x,_s.y)
						zapscale:+ state
					EndIf
					Local offx# = -Cos(_s.rot)*(het+zapscale*ImageHeight(zapgfx[0])/2)' + vx
					Local offy# = -Sin(_s.rot)*(het+zapscale*ImageHeight(zapgfx[0])/2)' + vy
					
					Local s:Shot = add_shot(_s, name, zapgfx, _s.x-offx, _s.y-offy, tar_theta, shotspeed, shotrange, shotdamage)
					s.lifetimer = constrain(500*(state^2), 100, 500)
					s.durable = True
					s.trail = False
					s.movrot = _s.rot
					s.speed = 0
					s.skipFortify = True
					s.scale = zapscale

				Else'if we're holding down the button
					Local offx# = -Cos(_s.rot)*(het+20)' + vx
					Local offy# = -Sin(_s.rot)*(het+20)' + vy
				
					'charge fx in front of the ship (AAA DISCLAIMER OF MY ETHICALNESS)
					SetAlpha .3 + .1*globalFrame
					'make it flash
					If Not (Abs(state) = 1 Or globalFrame) Then SetColor 255,255,255 Else SetColor 255,60,60
					'draw them
					SetBlend LIGHTBLEND
					For Local i = 1 To 4
						SetRotation (i*45)
						SetScale Abs(state),Abs(state)
						DrawImage warp2_gfx[globalFrame], _s.x-offx+game.camx, _s.y-offy+game.camy
					Next
					SetBlend ALPHABLEND
					
					'make some particles
					Local pspeed# = RndFloat()*2
					Local prot# = Rand(0,359)
					Local pvx# = Cos(prot)*pspeed
					Local pvy# = Sin(prot)*pspeed
					pspeed = approxDist(pvx+vx,pvy+vy)
					prot = ATan2(pvy+vy,pvx+vx)
					Local p:Background
					p = add_particle(_s.x-offx+Cos(prot)*RndFloat()*10, _s.y-offy+Sin(prot)*RndFloat()*10, prot, pspeed, 880*Abs(state), True)
					
					'make the particle flash the same way the charge does
					If Not (Abs(state) = 1 Or globalFrame)
						p.RGB[0] = 255
						p.RGB[1] = 60
						p.RGB[2] = 60
					EndIf
				EndIf

				
			'fire a bullet
			Case "peashooter","vectorshooter"
				Local s:Shot = add_shot(_s,name,shot5_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				If name = "peashooter"
					s.hit_gfx = explode4_gfx
				ElseIf name = "vectorshooter"
					s.gfx = vector_shot1_gfx
					s.hit_gfx = vector_shot1_gfx
				EndIf
				s.hit_sfx = Null
				's.rgb[0] = 255
				's.rgb[1] = 20
				's.rgb[2] = 20
				s.trailRGB[0] = 255
				s.trailRGB[1] = 200
				s.trailRGB[2] = 120
				playSFX(laserfire2_sfx,_s.x,_s.y)
			
			'slow, powerful blast
			Case "photon"
				Local s:Shot = add_shot(_s,name,shot4_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				s.hit_gfx = explode5_gfx
				s.trailRGB[0] = 255
				s.trailRGB[1] = 200
				s.trailRGB[2] = 120
				s.trail_override_gfx = shot3_gfx
				s.spin = .05
				playSFX(laserfire1_sfx,_s.x,_s.y)
			
			'launch a "missile" ship that tracks target
			Case "launcher","torpedolauncher","swarmlauncher","mortarlauncher","nuke"
				'if the conditions are right for this gun to fire
				If (name = "torpedolauncher" Or name = "swarmlauncher") Or (_release And ((name = "mortarlauncher" Or name = "nuke") Or (Abs(state) = 1)))
					Local vx# = Cos(_s.movrot)*_s.speed
					Local vy# = Sin(_s.movrot)*_s.speed
				
					Local missile:Ship = new_ship("Missile",_s.x+gx,_s.y+gy,"default")
					missile.squad.faction = _s.squad.faction
					missile.speedMax = shotspeed
					'set the damage, size of the explosion
					For Local c:Component = EachIn missile.compList
						c.damageBonus = shotdamage
					Next
					missile.recalc()
					
					missile.rot = _s.rot
					missile.ignoreList.addLast(_s.placeholder)
					missile.AI_timer = shotrange
					
					vx:+ Cos(tar_theta)*200
					vy:+ Sin(tar_theta)*200
						
					missile.movrot = ATan2(vy,vx)
					missile.speed = approxDist(vx,vy)
					If missile.speed < 200 Then missile.speed = 200
					
					'missile or torpedo?
					Select name
					Case "launcher","swarmlauncher"'homing
						missile.movrot:+ 15*binsgn(clip Mod 2)'move sideways at first
						If name = "swarmlauncher"
							missile.gfx = missile2_gfx
							missile.thrust = .3
						
							_s.target_closest(_tarx,_tary)
						EndIf
						missile.target = _s.target
						missile.squad.behavior = "missile"
						missile.behavior = "missile"
					Case "torpedolauncher","mortarlauncher","nuke"
						missile.behavior = "torpedo"
						missile.squad.behavior = "torpedo"
						missile.squad.goal_x = _tarx
						missile.squad.goal_y = _tary
						missile.movrot = _s.rot
						
						If name = "mortarlauncher" Or name = "nuke"
							missile.gfx = mine_gfx
							missile.scale = .7
							missile.thrust = 0
							missile.speed = Abs(state) * missile.speedMax
							missile.AI_timer = Max((tar_dist / (missile.speed+1)) * 1000, 1300)
							For Local c:Component = EachIn missile.compList
								For Local g:Gun = EachIn c.gunList
									g.fireDelay_timer = (missile.AI_timer-100)
								Next
							Next
						EndIf
					EndSelect
					
					
					playSFX(missilefire_sfx,_s.x,_s.y)
				
				ElseIf (name = "launcher" Or name = "swarmlauncher") And Not _release'if we're locking on
					Local oldtarget:Gertrude = p1.target
					'target the closest thing to the mouse
					_s.target_closest(_tarx,_tary,False)
					'have we just changed targets?
					If _s.target <> oldtarget Then state = 0
				EndIf
				
				'if we tried to release with the launcher but we weren't quite locked on
				If name = "launcher" And _release And Abs(state) < 1
					fireDelay_timer = 0'reset the fireDelay timer
					burstCount = 0'no bursting neither
					burstDelay_timer = 0
					state = 0
				EndIf
				
			'places a missile that slightly homes in on the target
			Case "minelayer"
				Local mine:Ship = new_ship("Mine",_s.x+gx,_s.y+gy,"default")
				mine.squad.faction = _s.squad.faction
				
				'set the damage, size of the explosion
				For Local c:Component = EachIn mine.compList
					c.damagebonus = shotdamage
				Next
				mine.recalc()
				
				mine.rot = _s.rot
				mine.ignoreList.addLast(_s.placeholder)
				mine.AI_timer = shotrange
				
				mine.squad.behavior = "mine"
				mine.behavior = "mine"

				mine.movrot = _s.movrot
				mine.speed = _s.speed / 2
				
				playSFX(missilefire_sfx,_s.x,_s.y)
								
			'launch a grappling hook
			Case "grappling"
				Local l:Shot = add_shot(_s,name,hook_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				l.hit_gfx = Null
				l.hit_sfx = Null
				l.trail = False
				l.animated = False
				
			'remove self, make a ship that can only be shot off and saps the health of the target
			Case "latch"
				'if we have a target and it's not dead
				If _s.target <> Null And Not _s.target.dead
					'is the target within range?
					Local dx = _s.target.x-_s.x
					Local dy = _s.target.y-_s.y
					If approxDist(dx,dy)
						Local leech:Ship = new_ship("Leech",_s.target.x,_s.target.y,"default")
						leech.squad.faction = _s.squad.faction
						leech.ignoreShipCollisions = True
						leech.target = _s.target
						'find the master, initial offset
						For Local t:Ship = EachIn entityList
							If t.placeholder = _s.target
								leech.master = t
								Local tdist# = Sqr(dx^2+dy^2)
								Local off_theta = (t.rot - tar_theta)
								If off_theta < 360 Then off_theta:+ 360
								If off_theta > 360 Then off_theta:- 360
								leech.master_offx = Cos(off_theta)*tdist
								leech.master_offy = Sin(off_theta)*tdist
								leech.master_offrot = t.rot
							EndIf
						Next
					EndIf
					'remove thyself
					RemoveLink(_s.link)
				EndIf
				
			'push self forward, doing damage
			Case "lunge"
				Local collide_gfx:TImage[2]
				collide_gfx[0] = CreateImage(20,20)
				collide_gfx[1] = CreateImage(20,20)
				Local l:Shot = add_shot(_s,name,collide_gfx, _s.x+gx, _s.y+gy, 0, 0, 0, shotdamage)
				l.hit_gfx = explode1_gfx
				l.hit_sfx = Null
				l.lifetimer = 160
				l.animated = False
				l.alpha = 1'transparent
				
				'push the ship forward
				_s.movrot = _s.rot
				If _s.speed < _s.speedMax*2 Then _s.speed = _s.speedMax*2
				
				'ship becomes untouchable
				_s.ignoreCollisions = True
						
			'create an explosion.
			Case "explode"
				
				Local explodeNum = 2 + Ceil(shotdamage / 6) * 3
				For Local i = -Floor(explodeNum/2) To Floor(explodeNum/2) + 1
					Local s:Shot = add_shot(_s,name,explode5_gfx, _s.x+gx, _s.y+gy, 0, 0, 0, shotdamage / (explodeNum+1))
					ClearList(s.ignoreList)
					s.hit_gfx = Null
					s.hit_sfx = Null
					s.trail = False
					s.durable = True
					
					s.scale = constrain((shotdamage / 26) * 3, .8, 22)
					s.lifetimer = constrain((shotdamage / 6) * 400, 400, 1300)

					'last one is stationary, bigger
					If i = Floor(explodeNum/2)
						s.movrot = 0
						s.speed = 0
						s.scale:*2.5
						
					Else'others go out in a circle
						s.speed = 150
						s.movrot:+ (360/explodeNum)*i
					EndIf
					
				Next
				'playSFX(missileexplode_sfx,_s.x,_s.y)
			
			'a trail of acid that sticks around for a while
			Case "acid"
				'figure out which acid this is in the sequence (burstCount starts at zero, we need to bump it up)
				Local acidCount# = burstCount
				If acidCount = 0 Then acidCount = burstNum
				'later parts of the burst slow down
				Local acidspeed# = shotspeed * ((acidCount / Float(burstNum)) + .3)

				Local s:Shot = add_shot(_s,name,shot_acid_gfx, _s.x+gx, _s.y+gy, tar_theta, acidspeed, shotrange*(RndFloat()+.5), shotdamage)
				s.movrot:+ Rand(-15,15)
				s.hit_gfx = Null
				s.trail = False
				s.spin = RndFloat()-.5
				s.durable = True
				s.scale = 1 + (RndFloat()-.5)
				If Rand(0,1) Then s.blend = ALPHABLEND Else s.blend = LIGHTBLEND
			
			'short-range spike, grappling hook that pulls apart ships
			Case "barb"
				Local s:Shot = add_shot(_s,name,barb_gfx, _s.x+gx, _s.y+gy, tar_theta, shotspeed, shotrange, shotdamage)
				s.hit_gfx = Null
				s.hit_sfx = Null
				s.trail = False
				s.animated = False
				's.skipShields = True
				s.skipFortify = True
			
			'it's only able to fire once, make the tentacles
			Case "tentacle"
				For Local i = 0 To Rand(2,4)
					Local tentacle_gfx:TImage[1]
					tentacle_gfx[0] = zerg_anemone_t1_gfx[Rand(0,1)]
					
					Local s:Shot = add_shot(_s,name, tentacle_gfx, _s.x, _s.y, 0, 0, 0, shotdamage*(RndFloat()+.5))
					s.damage = shotdamage*(RndFloat()+.5)
					s.movrot = Rand(0,359)
					s.rot = s.movrot
					s.durable = True
					s.hit_gfx = Null
					s.hit_sfx = Null
					s.lifetimer = 10000
					s.trail = False
					s.blend = ALPHABLEND
					s.skipShields = True
					s.skipFortify = True
					s.alpha = .3
					s.animated = False
				Next
				
				'longer tentacles
				For Local i = 0 To Rand(6,8)
					Local tentacle_gfx:TImage[1]
					tentacle_gfx[0] = zerg_anemone_t2_gfx[Rand(0,1)]
				
					Local	tent:Background = New Background
					tent.gfx = tentacle_gfx
					tent.animated = False
					tent.x = _s.x 
					tent.y = _s.y
					tent.rot = Rand(0,359)
					tent.spin = (RndFloat()-.5)/5
					tent.lifetimer = 0
					tent.alpha = .4
					tent.link = bgList.addLast(tent)
				Next
				
				'randomize starting direction of ship
				_s.rot = Rand(0,359)

			'pull things toward you, charge them up, and release to shoot them forward
			Case "gravitygun"
				
				'get how far mouse is from the ship
				Local m_dx# = (cursorx - (p1.x+game.camx))
				Local m_dy# = (cursory - (p1.y+game.camy))
				Local m_dist# = constrain(Sqr(m_dy^2 + m_dx^2), 50, SWIDTH)
				
				'where to pull things towards (a bit in front of the ship)
				Local goffset# = (ImageHeight(_s.gfx[0])/2) + m_dist'150
				Local gx# = _s.x + Cos(_s.rot)*goffset
				Local gy# = _s.y + Sin(_s.rot)*goffset
				
				'pull fx in front of the ship (AAA DISCLAIMER OF MY ETHICALNESS)
				SetAlpha .15 + .1*globalFrame
				SetScale 1,1
				'make it flash
				If Not globalFrame Then SetColor 155,100,100 Else SetColor 255,200,200
				'draw them
				SetBlend LIGHTBLEND
				For Local i = 1 To 4
					SetRotation (i*45)
					DrawImage warp2_gfx[globalFrame], gx+game.camx, gy+game.camy
				Next
				SetAlpha .2
				SetRotation _s.rot+90
				SetScale 2,2
				DrawImage warp2_gfx[globalFrame], gx+game.camx, gy+game.camy
				SetBlend ALPHABLEND
				
				'make some particles
				add_particle(gx, gy, Rand(0,359), RndFloat()*3, 2000, True)
				
				'make a list of things to affect
				Local gList:TList = New TList
				
				'only affect the closest ship
				Local closest:Ship,closest_dist# = shotrange
				For Local e:Ship = EachIn entityList
					If e <> _s And Not e.ignorePhysics
						Local dist = approxDist(e.x-gx,e.y-gy)
						If dist < closest_dist
							closest = e
							closest_dist = dist
						EndIf
					EndIf
				Next
				If closest <> Null Then gList.addLast(closest)
				
				'affect all shots, graphical effects
				For Local e:Entity = EachIn shotList
					If Not e.ignorePhysics Then gList.addLast(e)
				Next
				For Local e:Entity = EachIn debrisList
					If Not e.ignorePhysics Then gList.addLast(e)
				Next
				For Local e:Entity = EachIn explodeList
					If Not e.ignorePhysics Then gList.addLast(e)
				Next
				For Local e:Entity = EachIn itemList
					If Not e.ignorePhysics Then gList.addLast(e)
				Next
				
				'go through all entities
				For Local e:Entity = EachIn gList
					'get distance to this entity
					Local gdist# = approxDist(gx-e.x, gy-e.y)
					
					'is it a shot?
					Local isShot = (TTypeId.ForObject(e) = TTypeId.ForName("Shot"))
					
					'charge 'em up
					If Not _release
						'if target is within range of the pulling effect
						If gdist <= shotrange
							'force is inverse to distance (and doesn't care about mass)
							Local gforce# = shotdamage * e.mass * (1 - gdist/shotrange)
							
							'and the ship we're playing with gets treated special
							If e = closest Then gforce# = shotdamage * e.mass * (1 - (gdist^2 / shotrange^2))
							
							'get angle between entities
							Local theta# = ATan2((gy - e.y),(gx - e.x))
							'pull it to the gravity spot!
							If Not isShot Then e.add_force(theta, gforce)
							
							'redirect shots
							If isShot
								Local temp:TList = New TList
								temp.addLast(e)
								For Local l:Shot = EachIn temp
									'exert fake gravity to slow shots down
									If l.speed > .6 * l.speedBase
										l.speed = constrain(gdist/shotrange, .6, 1) * l.speedBase
									Else'real physics take over once everything's safe
										l.add_force(theta, gforce)
									EndIf
									
									'if they're about to die
									If l.lifetimer > 1 And l.lifetimer <= 200
										'extend their lives 
										l.lifetimer = 2000
										'take control of them
										ClearList(l.ignoreList)
									EndIf
								Next
							EndIf
						EndIf
						
					'let 'em rip
					ElseIf Not e.ignoreMovement
					
						'if target is within range of the blasting effect
						If gdist <= shotrange/2
							e.movrot = _s.rot
							If Not isShot Then e.speed = constrain(20 - Sqr(e.mass), 0, 20)
						EndIf
						
						'redirect shots
						If isShot
							Local temp:TList = New TList
							temp.addLast(e)
							For Local l:Shot = EachIn temp
								l.speed = l.speedBase
								l.lifetimer = Max(l.lifetimer, 1000+Rand(-200,200))
							Next
						EndIf
						
						state = 0
					EndIf
				Next
				
			'pull points together, remove them from the game
			Case "collector"
				'where to pull things towards (a bit in front of the ship)
				Local goffset# = (ImageHeight(_s.gfx[0])/2) + 15
				Local gx# = _s.x + Cos(_s.rot)*goffset
				Local gy# = _s.y + Sin(_s.rot)*goffset
				
				'pull fx in front of the ship (AAA DISCLAIMER OF MY ETHICALNESS)
				SetAlpha .35
				SetScale 1+.2*globalFrame,1+.2*globalFrame
				SetColor 255,200,200
				SetBlend LIGHTBLEND
				For Local i = 1 To 4
					SetRotation (i*45)
					DrawImage warp2_gfx[globalFrame], gx+game.camx, gy+game.camy
				Next
				
				'make a list of things to affect
				Local gList:TList = New TList
				
				'affect all points, debris
				For Local e:Entity = EachIn debrisList
					If Not e.ignorePhysics Then gList.addLast(e)
				Next
				For Local i:Item = EachIn itemList
					If Lower(i.name) = "point" Then gList.addLast(i)
				Next
				
				'go through all things sucked
				For Local e:Entity = EachIn gList
					'get distance to this entity
					Local gdist# = approxDist(gx-e.x, gy-e.y)

					'if target is within range of the pulling effect
					Local range = 1000
					If gdist <= range
						'force is inverse to distance (and doesn't care about mass)
						Local gforce# = shotdamage * e.mass * (1 - gdist/range)
						
						'get angle between entities
						Local theta# = ATan2((gy - e.y),(gx - e.x))
						'pull it to the gravity spot!
						e.add_force(theta, gforce)
					EndIf
					
					'destroys anything too close
					If gdist <= 28
						'kill it
						RemoveLink(e.link)
						'make some particles
						For Local i = 0 To 6
							add_particle(gx, gy, Rand(0,359), RndFloat()*5, 800, False)
						Next
					EndIf
				Next

				
			'put a springlike force on self, all entities within range
			Case "GRAVITY"
				'shotdamage = strength of gravity
				'shotrange = range of gravity effect
				
				'we affect entities, debris
				Local gList:TList = New TList
				For Local e:Entity = EachIn entityList
					gList.addLast(e)
				Next
				For Local e:Entity = EachIn shotList
					gList.addLast(e)
				Next
				For Local e:Entity = EachIn debrisList
					gList.addLast(e)
				Next
				For Local e:Entity = EachIn explodeList
					gList.addLast(e)
				Next
				
				'go through all entities, find nearby ones
				Local eatList:TList = New TList
				For Local e:Entity = EachIn gList
				If e <> _s
					'get distance to this entity
					Local gdist# = approxDist(_s.x-e.x, _s.y-e.y)
					
					'if target is within range
					If gdist <= shotrange
						'force is inverse to distance (and doesn't care about mass)
						Local gforce# = shotdamage * e.mass * (1 - gdist/shotrange)'ATan(-gdist+shotrange)/90
						
						'get angle between entities
						Local theta# = ATan2((_s.y - e.y),(_s.x - e.x))
						'pull 'em together!
						'_s.add_force(theta+180, gforce)
						e.add_force(theta, gforce)
						
						'make it blacker
						e.shade = 255.0 * (1.0 - gdist*2/shotrange)
					EndIf
					
					'if target is REALLY close, eat 'im up!
					If gdist <= (ImageWidth(e.gfx[0])/2)+10 Then eatList.addLast(e)
				EndIf
				Next
				
				'eat stuff differently
				For Local s:Ship = EachIn eatList
					s.armour = 0
				Next
				For Local bg:Background = EachIn eatList
					bg.lifetimer = 1
				Next
				For Local s:Shot = EachIn eatList
					s.lifetimer = 1
				Next
				
			EndSelect
			
			'depending on the mode, change the state
			Select mode
			Case 1'semiautomatic
				'if we've finished the burst, we don't shoot again until the mouse is released
				If burstCount >= burstNum Then state = 0
			EndSelect
			
			'does this gun come in bursts? (only trigger on the first shot of a burst) (also, with hold-release guns, only burst on release)
			If (burstNum > 1 And burstCount <= 0) And (mode <> 2 Or _release) And fireDelay_timer > 0'(and we didn't abort the shot)
				burstDelay_timer = burstDelay	'countdown to next shot in the burst
				burstCount = burstNum - 1		'set number of remaining shots in burst
				burstX = _tarx				'store position of target for this burst
				burstY = _tary
			EndIf
			
			'does this gun have a clip?
			If clipNum > 0
				clip:- 1		'count down the number of shots left in the clip
				'if the clip is out of ammo, time to reload
				If clip <= 0
					If _s = p1 Then playSFX(ammodeplete_sfx,_s.x,_s.y)
					reloadDelay_timer = reloadDelay
				EndIf
			EndIf
		
		'ElseIf clip = 0 And clipNum > 0'if player is out of ammo and tries to fire
			'playSFX(ammodeplete_sfx,_s.x,_s.y)
		EndIf
		
		
		Select mode
		Case 0'automatic weapons heat up even if they didn't fire a shot as per se...
			'still need to have ammo, etc.
			If (reloadDelay_timer <= 0) And (clip > 0 Or clipNum = 0)
				state = constrain(state + frameTime/chargeTime + frameTime/coolTime, 0, 1)
			EndIf
		
		Case 1'semi-automatic weapons need to stop trying to be fired before they shoot again
			'semiauto states:
			'1 = ready to fire
			'0 = not ready to fire
			'-1 = attempt to reready by update
			
			'if update is trying to reready but we're still firing, tell it NO!
			If state = -1 Then state = 0
			
			'unless it's bursting, then we're always ready
			If burstNum > 1 And burstCount <= 0 Then state = 1
			
		Case 2'press-and-hold weapons are always trying to release their charge, keep it in if we're still trying to fire
			If Not _release And fireDelay_timer <= 0
				If state < 0 Then state = Abs(state)
				'build up a % charge (and cancel out the cooling)
				Local oldstate = state
				state = constrain(state + frameTime/chargeTime + frameTime/coolTime, 0, 1)
				If oldstate <> 1 And state >= 1 Then playSFX(click_sfx,_s.x,_s.y)'play a blip when we fully whatever
			EndIf
		
		EndSelect
	EndIf
	EndMethod
	
	'called every cycle-> shots cool down, missiles try to lock on...
	'_s is containing ship, _md 1 and 2 are the current mousedown states (for non-player, determine here what the best course of action is and do it)
	Method update(_s:Ship)
		'find the position of the gun offset from the ship
		Local gx = offsetx*Cos(_s.rot-90) + offsety*Sin(_s.rot-90)
		Local gy = offsety*Cos(_s.rot-90) + offsetx*Sin(_s.rot-90)
		
		'find the absolute coords of the mouse
		Local mx,my
		If _s = p1
			mx = p1.x + (cursorx - (p1.x+game.camx))
			my = p1.y + (cursory - (p1.y+game.camy))
		EndIf
		
		'are we bursting?
		If burstCount > 0 
			burstDelay_timer:- frameTime
			If burstDelay_timer <= 0
				'fire the gun
				fireDelay_timer = 0
					'figure out where to shoot
					Local tarx, tary
					If _s = p1'if player
						tarx = mx'shoot at the mouse
						tary = my
					'otherwise, shoot at the current target's predicted position
					ElseIf _s.target <> Null
						Local tar_p#[] = _s.predictTargetPos(Null, shotspeed)
						tarx = tar_p[0]
						tary = tar_p[1]
					'otherise, just use the initial aiming point
					Else
						tarx = burstX
						tary = burstY
					EndIf
					fire(_s, tarx, tary, True)
				fireDelay_timer = fireDelay
				
				'count down the number of bursts, reset the timer
				burstCount:- 1
				If burstCount > 0 Then burstDelay_timer = burstDelay
			EndIf
		ElseIf mode = 1 And state = 1'once we finish bursting a semi-automatic, set state to 0
			If _s <> p1 Then 	state = 0
		EndIf
		
		'dec. the timer for firing (if the burst is over)      and not a press-and-hold weapon)
		If (fireDelay_timer > 0 And burstCount <= 0)'          And (mode = 0 Or mode = 1 Or state = 0)
			fireDelay_timer = constrain(fireDelay_timer - frameTime, 0, fireDelay)
		EndIf
		
		'dec. the timer for reloading
		If reloadDelay_timer > 0
			reloadDelay_timer = constrain(reloadDelay_timer - frameTime, 0, reloadDelay)
			'finish reloading
			If reloadDelay_timer <= 0
				If _s = p1 Then playSFX(ammoreload_sfx,_s.x,_s.y)
				clip = clipNum
			EndIf
		EndIf
		
		'update teh staet ov the gun
		Select mode
		Case 0'automatic
			'cool off all the time; when firing we cancel this out
			state = constrain(state - frameTime/coolTime, 0, 1)
			
		Case 1'semi-automatic
			'was the gun re-readied? (not tried to fire) -> if so, then ready it for the next shot
			If state = -1 Or (_s <> p1) Then state = 1
			'try and re-ready the gun
			If state = 0 Then state = -1
		Case 2'press-hold-release
			'was the charge not re-held? (not tried to fire) - OR - if an AI has reached full charge
			If ((state < 0) Or (_s <> p1 And state = 1))
				'figure out where to shoot
				Local tarx,tary
				'if the player, shoot the released shot at the mouse
				If _s = p1
					tarx = mx
					tary = my
				'otherwise, shoot at the current target's predicted position
				ElseIf _s.target <> Null
					Local tar_p#[] = _s.predictTargetPos(Null,shotspeed)
					tarx = tar_p[0]
					tary = tar_p[1]
				'otherise, just shoot straight forward
				Else
					tarx = _s.x + Cos(_s.rot)*shotrange
					tary = _s.y + Sin(_s.rot)*shotrange
				EndIf
				
				'fire the released shot!
				fire(_s,tarx,tary,True)
				
				'if there's no burst, we're done, reset the charge
				If burstNum <= 0 Then state = 0
			EndIf
			
			'cool off all the time; when firing we cancel this out
			If burstCount <= 0
				If state < .95 Then state = constrain(state - frameTime/coolTime, 0, 1)
			
				'try and release the charge (if we're not bursting)
				If state > 0 Then state = -Abs(state)
			EndIf
		EndSelect
		
		Select Lower(name)
		Case "plasma"'builds up a charge over time (firing disperses the charge) (higher charge = better burst)
			If value < 1 Then value = constrain(value + frameTime/coolTime, 0, 1)
		
		Case "launcher","swarmlauncher"
			'Print "state:"+state+"  burstCount:"+burstCount+"  burstDelay_timer:"+burstDelay_timer+"  firedelay_timer:"+fireDelay_timer
		
			'have a lock-on graphic
			If _s.target <> Null' And state <> 0
				If _s = p1
					'have the graphic spin around as it closes in
					SetBlend LIGHTBLEND
					SetColor 255,255,255
					SetScale 7-Abs(state)*5,7-Abs(state)*5
					SetAlpha Abs(state)/2
					SetRotation value
					Local drawx = _s.target.x + game.camx
					Local drawy = _s.target.y + game.camy
					Local frame = 0
					If Abs(state) = 1 Then frame = globalFrame'once totally locked on, have it flash
						
					'draw the circle
					DrawImage target6_gfx,drawx,drawy,frame
					
					'SetScale 4-Abs(state)*2,4-Abs(state)*2
					'SetRotation -value
					
					'draw the biggercircle
					'DrawImage target6_gfx,drawx,drawy,frame
					
					'rotate the image
					value:+ (frameTime/2.5) * state
					If value > 359 Then value:- 359
				EndIf
			EndIf
			
		Case "mortarlauncher"
			'have a target area graphic
			If _s = p1 And state <> 0
				'have the graphic spin around as it closes in
				SetBlend LIGHTBLEND
				SetColor 255,255,255
				SetScale 4,4
				SetAlpha Abs(state)/2
				SetRotation value
				Local drawx = cursorx
				Local drawy = cursory
				Local frame = 0
				If Abs(state) = 1 Then frame = globalFrame'once totally locked on, have it flash
					
				'draw the circle
				DrawImage target6_gfx,drawx,drawy,frame
				
				SetColor 255,80,1
				SetRotation 0
				SetScale 1,1
				DrawOval drawx - 60, drawy - 60, 120, 120
				
				'rotate the image
				value:+ (frameTime/2.5) * state
				If value > 359 Then value:- 359
			EndIf
			
		Case "pointdefense"
			'autoaquire targets
			Local tar:Ship
			For Local o:Ship = EachIn entityList
				If fTable[_s.squad.faction,o.squad.faction] = -1
					'if lacking a target, take the first one we see
					If tar = Null Then tar = o
					'if this new target is closer than the old one
					If tar <> o And (Sqr((o.x-gx)^2+(o.y-gy)^2) < Sqr((tar.x-gx)^2+(tar.y-gy)^2)) Then tar = o
				EndIf
			Next
			'if found a target & in range, fire!
			If tar <> Null
				If Sqr((tar.x-(_s.x+gx))^2+(tar.y-(_s.y+gy))^2) <= shotrange Then fire(_s,tar.x,tar.y)
			EndIf
			
		Case "tentacle"
			'owner slowly spins
			_s.rot:+ .02*frameTime*RndFloat()
			
			_s.animated = True

			_s.ignoreCollisions = True
			_s.invulnerable = True
			_s.tweenOnHit = False
			
			'fire right off the bat
			state = 1
			
			'then never finish reloading
			If reloadDelay_timer > 0 Then reloadDelay_timer = 10000
			
		Case "lunge"
			'OWNER CANNOT RUN INTO THE TARGET
			If _s.target <> Null And _s.target.dead = False
				If Not ListContains(_s.ignoreList, _s.target) Then _s.ignoreList.addLast(_s.target)
			EndIf
			
			'but make sure the no-collisions thing is reversed when we're done lunging
			If reloadDelay_timer <= 0 Then _s.ignoreCollisions = False

		
		Rem
		Case "alarm"
			Local linetween# = constrain(fireDelay_timer / fireDelay, 0, 1)
			
			'draw a scanning red line (AAA I KNOW I KNOW I AM A BAD PERSON FOR PUTTING THIS HERE)
			SetAlpha .25
			If globalframe Then SetColor 255,120,30 Else SetColor 255,0,0
			If linetween > 0 Then SetColor 255*linetween,255*linetween,255*linetween
			
			'if the alarm is active
			If linetween > .9 Or linetween = 0
				Local rad = shotrange
				Local dx1 = Cos(_s.rot)*rad, dy1 = Sin(_s.rot)*rad
				Local dx2 = Cos(_s.rot+90)*rad, dy2 = Sin(_s.rot+90)*rad
				Local dx3 = Cos(-_s.rot)*rad, dy3 = Sin(-_s.rot)*rad
				Local dx4 = Cos(-_s.rot-90)*rad, dy4 = Sin(-_s.rot-90)*rad
				SetLineWidth 2
				DrawLine _s.x-dx1+game.camx,_s.y-dy1+game.camy,_s.x+dx1+game.camx,_s.y+dy1+game.camy
				DrawLine _s.x-dx2+game.camx,_s.y-dy2+game.camy,_s.x+dx2+game.camx,_s.y+dy2+game.camy
				DrawLine _s.x-dx3+game.camx,_s.y-dy3+game.camy,_s.x+dx3+game.camx,_s.y+dy3+game.camy
				DrawLine _s.x-dx4+game.camx,_s.y-dy4+game.camy,_s.x+dx4+game.camx,_s.y+dy4+game.camy
				SetLineWidth 1
			EndIf
		EndRem
		Case "gravity"
			'make particles!
			Local dir = Rand(0,359) 'random direction
			Local lt = 7500
			add_particle(_s.x+(shotrange-100)*Cos(dir),_s.y+(shotrange-100)*Sin(dir),0,0,lt,True)
			
			'draw a transparent black-hole circle (AAA I KNOW I KNOW I AM A BAD PERSON FOR PUTTING THIS HERE)
			SetAlpha 1
			SetColor 0,0,0
			Local rad = 50
			For Local i = 0 To 7
				DrawOval (_s.x+game.camx)/_s.dist-rad*i, (_s.y+game.camy)/_s.dist-rad*i, i*rad*2, i*rad*2
				SetAlpha .25'non-center circles are transparent
			Next
		EndSelect

	EndMethod
EndType

Global shotList:TList = New TList
Type Shot Extends Entity
	Field name$					'the name of the gun that fired it
	Field owner:Ship				'the ship that fired it
	Field lifetimer				'how long it lasts, in millisecs
	Field durable				'whether or not it should stick around after hitting a ship
	Field damage#				'amount of damage shot does
	Field speedBase				'the shot remembers how fast it was going when in was fired
	Field skipFortify = False		'does this shot bypass damage resistance?
	Field skipShields = False		'does this shot ignore shields?
	Field hit_gfx:TImage[]			'gfx to make when it hits
	Field hit_sfx:TSound			'sfx to make when it hits
	
	Field trail = True			'TRUE/FALSE whether it leaves a particle trail
	Field trailRGB[3]				'the color of the trail, default to 255,255,255
	Field trail_animated = True
	Field trail_override_gfx:TImage[]		'possible override for the particle graphic
	Field trail_scale# = 1
	Field trail_alpha# = .75
	
	Method update()
		'onscreen?
		Local onscreen = False
		If Abs(x-p1.x) < (SWIDTH+SHEIGHT)*dist And Abs(y-p1.y) < 2*SHEIGHT*dist Then onscreen = True
		
		'-- IN ADDITION TO the default shot behaviors --
		Select name
		Case "acid"
			'decelerate
			add_force(movrot + 180, speed/400)
		EndSelect
		
		'-- REPLACING the default shot behaviors --
		Select name
		Case "grappling","barb"

			'draw the rope from hook to owner (AAA I KNOW I KNOW I AM A BAD PERSON FOR PUTTING THIS HERE)
			SetColor 64,64,64
			SetAlpha 1
			SetScale SHIPSCALE,SHIPSCALE
			Local offx = 0'-Cos(owner.movrot)*owner.speed
			Local offy = 0'-Sin(owner.movrot)*owner.speed
			DrawLine x+game.camx, y+game.camy, owner.x-offx+game.camx, owner.y-offy+game.camy
			
			'dec. lifetimer, kill the shot if it's gone on too long (-255 is code for "we've latched")
			If lifetimer < 0 And lifetimer <> -255 Then RemoveLink(link)
			lifetimer = lifetimer - frameTime
			
			'Local maxrange#,minrange# = 150
			'Local sforce#
			'If name = "grappling"
			'	maxrange = 800
			'	sforce = .5
			'ElseIf name = "barb"
			'	maxrange = 400
			'	sforce = 10
			'EndIf
			
			'get angle,dist to shot
			'Local theta# = ATan2((y - owner.y),(x - owner.x))
			'Local sdist# = approxDist(x-owner.x, y-owner.y)		'get distance to this entity
			
			'pull the ships together
			'If sdist > minrange
			'	sforce:* (sdist/maxrange)
				
				'pull 'em together!
			'	owner.add_force(theta, sforce)
			'EndIf
			
			'kill the shot if the owner died
			If owner.placeholder.dead Then RemoveLink(link)
		
		Case "tentacle"
			'set it to the owner's position
			x = owner.x
			y = owner.y
			
			'set gfx for a bit of variation
			Local rotmod 
			If damage > .35 Then rotmod = 1
			
			'rotate it based on owner
			movrot:+ Sgn(owner.rot-movrot+180*rotmod)*Sin(owner.rot*damage-movrot+180*rotmod)*Cos(movrot*damage-owner.rot+180*rotmod)
			
			'it lives forever!
			lifetimer = 10000
			
			'...until its owner dies
			If owner.placeholder.dead Then RemoveLink(link)
			
		Default
			'dec. lifetimer, kill the shot if it's gone on too long
			lifetimer = lifetimer - frameTime
			If lifetimer < 0 Then RemoveLink(link)

			'shot trail
			If trail
				Local p:Background = add_particle(x,y,0,0,250,True)
				p.rot = movrot
				p.alpha = trail_alpha * (1 - alpha)
				p.scale = trail_scale
				p.blend = ALPHABLEND
				'if there's an override color
				If trailRGB[0] Or trailRGB[1] Or trailRGB[2]
					p.RGB[0] = trailRGB[0]
					p.RGB[1] = trailRGB[1]
					p.RGB[2] = trailRGB[2]
				EndIf
				'if there's an override graphic
				If trail_override_gfx <> Null Then p.gfx = trail_override_gfx Else p.gfx = trail_gfx
				'animated?
				p.animated = False'trail_animated
			EndIf
				
			
			'fade out the shot if it's about to run out of life
			If lifetimer < 200 Then alpha = alpha + frameTime/200

		EndSelect
		
		rot = movrot
	EndMethod
	
	Method collide(_ship:Ship)
		'get angle of hit
		Local hitrot# = ATan2(y-_ship.y,x-_ship.x)
	
		'HIT THE SHIP
		If Not _ship.shieldOn Or skipShields
			Select name
			Case "grappling","barb"		
				'can't shoot more than one at a time
				For Local g:Gun = EachIn owner.gunGroup[0]
					If g.name = name Then g.fireDelay_timer = g.fireDelay
				Next
				
				Local maxrange#,minrange# = 150
				Local sforce#
				If name = "grappling"
					maxrange = 800
					sforce = 15
				ElseIf name = "barb"
					maxrange = 400
					sforce = 15
				EndIf
				
				'get angle between entities
				Local theta# = ATan2((_ship.y - owner.y),(_ship.x - owner.x))
				Local sdist# = approxDist(_ship.x-owner.x, _ship.y-owner.y)		'get distance to this entity
				
				'pull the ships together
				If sdist > minrange
					sforce:* (sdist/maxrange)								'force is proportional to distance
					
					'pull 'em together!
					_ship.add_force(theta+180, sforce)
					owner.add_force(theta, sforce)
				EndIf
				
				'stop counting down, we've latched
				lifetimer = -255
				
				'latch onto the ship
				speed = 0
				rot = theta
				x = _ship.x
				y = _ship.y
				
				'do damage
				If name = "barb" Then _ship.damage(damage*(frameTime/1000), hitrot, skipFortify, skipShields)
				
				'kill the shot if we've stretched too far
				If sdist > maxrange Then RemoveLink(link)
			
			Case "tentacle"
				'if it's not hitting itself
				If (_ship <> owner)
					'sap the target's speed
					Local slowspeed# = 90
					Local decel# = (.3*_ship.base.mass) * Max((speed / slowspeed),1.0)
					If Abs(speed) > slowspeed Then add_force(movrot+180, decel)
				
					'only affects biological beasties
					'If _ship.base.bio = True
						_ship.damage(damage*(frameTime/100), hitrot, skipFortify, skipShields)'do continual damage
					'EndIf
				EndIf
			
			Default 'most shots
			
				'do the damage
				_ship.damage(damage, hitrot, skipFortify, skipShields)
				
				'push the ship a bit
				_ship.addSpeed(damage/_ship.mass, hitrot+180)
				
				'make a small effect
				If hit_gfx <> Null
					Local fg:Foreground = add_explode(x,y)
					fg.gfx = hit_gfx
				EndIf
				
				'SCREEN SHAKE
				Local shake = -2		'it needs to be convinced
				'damage shakes!
				shake:+ constrain(Ceil(damage/3), 0, 3)	
				'proximity shakes!
				Local prox = 1 - (Floor(approxDist(x-p1.x,y-p1.y) / SWIDTH))
				shake:+ prox
				'player's shots shake!
				For Local p:Gertrude = EachIn ignoreList
					'is the first ship the player?
					If p = p1.placeholder Then shake:+ 1
					Exit
				Next
				'shots that hit the player shake!
				If _ship = p1 Then shake:+ 1
				'invulnerable ships don't shake...
				If _ship.invulnerable Then shake:- 1
				'if the ship doesn't shake on death, don't shake on hit
				shake:* Abs(Sgn(_ship.base.explodeShake))
				
				'tell the game to shake however much
				If shake > 0 And prox >= 1 Then game.camshake = Max(game.camshake, shake)
				
				'hit sound
				If hit_sfx <> Null Then playSFX(laserhit_sfx,x,y)
				
				'ignore the contacted ship from now on; each shot can only hit a ship once
				ignoreList.addLast(_ship.placeholder)
				
				'if the shot's expendable, remove it.
				If Not durable Then RemoveLink(link)
			EndSelect
			
		'SHIELD COLLIDE
		Else
			'the angle between the shot and the ship
			Local theta# = ATan2((_ship.y - y),(_ship.x - x))
			'the difference between the shot's movement and theta
			Local drot# = Abs(movrot Mod 90) - theta
			
			'do damage (to the shield)
			_ship.damage(damage, hitrot)
			
			'ignore the contacted ship from now on; each shot can only hit a ship once
			ignoreList.addLast(_ship.placeholder)
			
			'ricochet the shot
			movrot:+ drot
			rot = movrot
			
			'make a small richochet effect
			For Local i = 1 To Rand(1,3)
				Local dir# = theta+180+Rand(-20,20)
				Local veloc# = (RndFloat()+1)*2
				Local xspeed = veloc*Cos(dir) + _ship.speed*Cos(_ship.movrot)
				Local yspeed = veloc*Sin(dir) + _ship.speed*Sin(_ship.movrot)
				add_particle(x,y,ATan2(yspeed,xspeed),approxDist(xspeed,yspeed),Rand(300,1200),False)
			Next
			
			'play a richochet sound
			playSFX(reflect_sfx,x,y,.5)
			
			'still push the ship
			_ship.addSpeed(damage/_ship.mass, hitrot+180)
		EndIf
	EndMethod
EndType


'make a default-stats gun and return it
Function new_gun:Gun(_name$, _offsetx = 0, _offsety = 0)
	Local g:Gun = New Gun
	g.name = _name
	g.offsetx = _offsetx * SHIPSCALE
	g.offsety = _offsety * SHIPSCALE
	g.icon = 0'points to the weapon_gfx[] array, plasma gun default
	
	Select g.name
	Case "plasma"'standard bolt gun
		g.mode = 0'automatic
		g.fireDelay = 400
		g.freedom = 270
		g.shotrange = 600
		g.shotspeed = 450
		g.shotdamage = 1
		g.burstNum = 2
		g.burstDelay = 70
		g.chargetime = 1800'used specially by plasma gun, it builds up a charge when not fired over this amount of time
	Case "plasma_burst"'only fires in bursts of bolts
		g.mode = 1'semi-automatic
		g.fireDelay = 900
		g.freedom = 270
		g.shotrange = 600
		g.shotspeed = 450
		g.shotdamage = 1
		g.burstNum = 5
		g.burstDelay = 110
	Case "photon"'slow-firing energy explosive
		g.mode = 1'semi-automatic
		g.fireDelay = 1800
		g.freedom = 360
		g.shotrange = 800
		g.shotspeed = 300
		g.shotdamage = 4
		g.burstNum = 3
		g.burstDelay = 300
	Case "shotgun"'close-range stopping power satisfaction
		g.mode = 1'semi-automatic
		g.fireDelay = 950
		g.freedom = 180
		g.shotrange = 250
		g.shotspeed = 900
		g.shotdamage = 9
	Case "autocannon"'slower than the machine gun
		g.mode = 0'automatic
		g.fireDelay = 300
		g.freedom = 270
		g.shotrange = 650
		g.shotspeed = 425
		g.shotdamage = .8
	Case "autocannon_burst"'slower than the machine gun
		g.mode = 0'automatic
		g.fireDelay = 2000
		g.freedom = 0
		g.shotrange = 650
		g.shotspeed = 425
		g.shotdamage = .6
		g.burstNum = 10
		g.burstDelay = 100
	Case "velocitycannon"'charge up a high-velocity penetrating shot
		g.mode = 2'press-hold-release
		g.fireDelay = 100
		g.freedom = 270
		g.shotrange = 750
		g.shotspeed = 700
		g.shotdamage = 14
		g.chargetime = 3000
	Case "arccaster"'charge up a high-voltage close-range automatically-hitting shot
		g.mode = 2'press-hold-release
		g.fireDelay = 100
		g.freedom = 360
		g.shotrange = 300
		g.shotspeed = 0
		g.shotdamage = 8
		g.chargetime = 2000
	Case "gravitygun"'pull things toward you then shove them away
		g.mode = 2'press-hold-release
		g.fireDelay = 100
		g.freedom = 0
		g.shotrange = 250
		g.shotdamage = .6'strength of gravity
		g.chargetime = 2500
	Case "collector"'pulls points together, removes them from the game
		g.mode = 0'automatic
		g.fireDelay = 100
		g.freedom = 0
		g.shotrange = 3000'for AI purposes
		g.shotdamage = .15'strength of force
	Case "peashooter"
		g.mode = 1'semi-automatic
		g.fireDelay = 900
		g.freedom = 360
		g.shotspeed = 400
		g.shotdamage = 2
		g.shotrange = 600
	Case "vectorshooter"
		g.mode = 1'semi-automatic
		g.fireDelay = 500
		g.freedom = 270
		g.shotspeed = 350
		g.shotdamage = 2
		g.shotrange = 550
	Case "grappling"'a grappling hook
		g.mode = 1'semi-automatic
		g.fireDelay = 1000
		g.freedom = 360
		g.shotrange = 800
		g.shotspeed = 500
		g.shotdamage = .5		'strength of springyness
	Case "launcher"'launches a tracking missile
		g.mode = 2'press-hold-release
		g.fireDelay = 800
		g.freedom = 180
		g.shotspeed = 440
		g.shotrange = 6000	'number of milliseconds of life for the missile
		g.shotdamage = 1		'damage comes from component's damagebonus
		g.chargetime = 500
		g.burstNum = 2
		g.burstDelay = 400
	Case "minelayer"'places a homing mine
		g.mode = 1'semiautomatic
		g.fireDelay = 2300
		g.shotrange = 18000	'number of milliseconds of life
		'g.shotdamage = 10	'damage comes from component's damagebonus
	Case "swarmlauncher"'fires a small swarm of homing missiles
		g.mode = 0'automatic
		g.fireDelay = 1500
		g.freedom = 270
		g.shotrange = 2500	'ms of life for the missle
		g.shotspeed = 500
		g.shotdamage = 1		'damage comes from component's damagebonus
		g.burstNum = 6
		g.burstDelay = 350
	Case "torpedolauncher"'launches a dumb straight missile
		g.mode = 1'semi-automatic
		g.fireDelay = 900
		g.freedom = 360
		g.shotrange = 4000	'number of milliseconds of life for the missile
		g.shotspeed = 480
		g.shotdamage = 1		'damage comes from component's damagebonus
	Case "mortarlauncher","nuke"'launches a mortar with a fuse
		g.mode = 2'press-hold-release
		If g.name = "nuke" Then g.fireDelay = 3000 Else g.fireDelay = 300
		g.freedom = 360
		g.shotspeed = 480
		g.shotrange = 8000	'maximum number of milliseconds of life for the fuse
		If g.name = "nuke" Then g.shotdamage = 10 Else g.shotdamage = 1		'damage comes from component's damagebonus
		g.chargetime = 1300
	Case "acid"'fires a burst of acid that sticks around for a while
		g.mode = 1'semi-automatic
		g.fireDelay = 2900
		g.freedom = 360
		g.shotrange = 850'doesn't actually go this far
		g.shotspeed = 450'for the maximum speed, later bits of the burst slow down
		g.shotdamage = 1
		g.burstNum = 25
		g.burstDelay = 40
	Case "barb"'close-range hooked spike that reels them in
		g.mode = 1'semi-automatic
		g.fireDelay = 1000
		g.freedom = 45
		g.shotrange = 300
		g.shotspeed = 600
		g.shotdamage = 5.5	'dps
	Case "tentacle"'stationary, permanent close-range tentacles 
		g.mode = 1'semi-automatic (never reloads)
		g.fireDelay = 1
		g.shotdamage = .25	'dps for each tentacle
		g.clipNum = 1
		g.reloadDelay = 1000
	Case "lunge"'thrusts the ship forward, dropping damaging shots
		g.mode = 1'semi-automatic
		g.fireDelay = 1500
		g.freedom = 360
		g.shotrange = 150
		g.shotdamage = 1	'dps
		g.burstNum = 7
		g.burstDelay = 60
	Case "explode"'AOE explosion at range,angle instantly (usually local)
		g.fireDelay = 70
		g.freedom = 360
		g.shotrange = 0
		g.shotspeed = 0
		g.shotdamage = .5'relies on the component's damagebonus to do anything more
	Case "GRAVITY"
		g.fireDelay = 1
		g.shotrange = 1200
		g.shotdamage = .008'strength of gravity
	EndSelect
	g.fireDelay_timer = g.fireDelay'start out having to recharge
	g.clip = g.clipNum				'don't have to reload
	g.dispname = g.name				'default to displaying the under-the-hood name
	
	Return g:Gun
EndFunction