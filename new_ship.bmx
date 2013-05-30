'makes & returns a default-type ship based off a chassis (determined by a name match)
Function new_ship:Ship(_name$,_x=0,_y=0,_config$ = "", _squad:Squadron = Null, addToEntityList = True)
	Local s:Ship = New Ship
	s.name = _name$
	If _config = "" Then s.config = "default" Else s.config = _config
	s.x = _x
	s.y = _y
	s.frameoffset = Rand(0,1)

	'-DEFAULTS-
	s.explodeSound = shipexplode_sfx
	s.player_ffdisplay = True
	s.ignoreCollisions = False		'bumps off other ships

	'-CHASSIS-DERIVED-
	For Local c:Chassis = EachIn chassisList
		If Lower(c.name) = Lower(s.name) Then s.base = c
	Next
	s.gfx = s.base.gfx
	
	s.animated = s.base.animated
	s.behavior = s.base.behavior
	s.invulnerable = s.base.invulnerable
	If s.base.stationary
		s.ignorePhysics = True
		s.ignoreMovement = True
	EndIf
	s.strafe = s.base.strafe
	
	If s.base.explodeSound <> Null Then s.explodeSound = s.base.explodeSound
	'If Not s.base.bio Then s.explodeNum = s.base.explodeNum Else s.explodeNum = (s.base.explodeNum * 2)	'bio creatures gib more
	s.explodeNum = s.base.explodeNum
	s.debrisRGB[0] = s.base.debrisRGB[0]
	s.debrisRGB[1] = s.base.debrisRGB[1]
	s.debrisRGB[2] = s.base.debrisRGB[2]
	For Local sname$ = EachIn s.base.dropShipList
		s.dropList.addLast(new_ship(sname,0,0,"",s.base.dropSquad,False))
	Next
	
	For Local comp:Component = EachIn s.base.compList
		s.compList.addLast(comp)
	Next
	s.cshape_recalc()				'set the shape data, what's filled up

	'try and load what we got
	s.load_config(s.config)

	'ladies and gentlemen, start your engines
	'If s.thrust > 0 Then s.engineChannel = playSFX(engine_sfx,0,0,0)
	
	'-FIDDLY BITS-
	'set point, explodeNum based on mass
	Local pointNum = 0's.mass/4 + Rand(0,2)
	If s.explodeNum = -1 Then s.explodeNum = Rand(s.mass/2,s.mass*1.5)
	Local debrisNum = s.explodeNum / 2
	If s.explodeNum = -1 Then debrisNum = constrain(debrisNum, 3, debrisNum)

	'add points
	'For Local p = 1 To pointNum
	'	s.dropList.addLast(add_item("Point",point1_gfx,0,0,0,0,False))
	'Next
	'add debris
	For Local d = 1 To debrisNum
		If s.base.debrisType = 0 Then s.dropList.addLast(add_debris("metal",0,0,0,0,False))
		If s.base.debrisType = 1 Then s.dropList.addLast(add_debris("rock",0,0,0,0,False))
		If s.base.debrisType = 2 Then s.dropList.addLast(add_debris("gib",0,0,0,0,False))
		If s.base.debrisType = 3 Then s.dropList.addLast(add_debris("vector",0,0,0,0,False))
	Next
	
	'calculate mass,weapons, maxspeed, maxarmour, thrust, based on current components.
	s.recalc()
	'that new-car-smell
	s.reset()
	
	'set the squadron the ship belongs to
	If _squad <> Null
		s.squad = _squad
	Else
		s.squad = New Squadron'it'll default to faction 0
		s.squad.x = s.x
		s.squad.y = s.y
	EndIf
	
	'arcade configs get points!
	If Lower(s.config) = "arcade"
		For Local p = 0 To ((s.mass/5 + Rand(0,2)) * pilot.difficulty)
			'bio creatures get half points
			If (Not s.base.bio Or Rand(0,1) = 0) Then s.dropList.addLast(add_item("point",point1_gfx,0,0,0,0,False))
		Next
		'NORMAL MODE: drop lives
		'If pilot.difficulty = .5
		'	If Rand(1,LIFECHANCE) = 1
		'		Local life:Item = add_item("life",life_gfx,0,0,0,0,False)
		'		life.scale = 1.4
		'		life.lifetimer = POINT_LIFETIME*2
		'		s.dropList.addLast(life)
		'	EndIf
		'Else 
		
			'EVERY MODE: drop special ability recharges
			If Rand(1,constrain(LIFECHANCE*1.5-s.mass, 3, LIFECHANCE*2)) = 1
				Local ap:Item = add_item("abilitypoint",abilitypoint_gfx,0,0,0,0,False)
				ap.animated = False
				ap.lifetimer = POINT_LIFETIME*2
				s.dropList.addLast(ap)
			EndIf
		'EndIf		
	EndIf
	
	'COLLISION DETECTIONS; random-walk it away from any potential collisions
	'If 1=2
	If Not s.base.ord'not for missiles, etc.
		For Local o:Ship = EachIn entityList
			Local wid = ImageWidth(s.gfx[0])/2
			Local het = ImageHeight(s.gfx[0])/2
		
			Local owid = ImageWidth(o.gfx[0])/2
			Local ohet = ImageHeight(o.gfx[0])/2
			
			'get how close ovals are to colliding
			While OvalsCollide(s.x,s.y,wid,het,s.rot,o.x,o.y,owid,ohet,o.rot) <= 0
				s.x:+ Rand(-40,40)
				s.y:+ Rand(-40,40)
				'Print "random-walking initial "+s.name+" placement"
			Wend
		Next
	EndIf
	'EndIf
	
	If addToEntityList Then s.link = entityList.AddLast(s)
	Return s:Ship
EndFunction

'sets all ships in the provided list to Null
Function resetSquads(_sList:TList)
	For Local s:Ship = EachIn _sList
		s.squad = Null
	Next
EndFunction


'make the global chassis list
Function setup_chassis()
	'--------------------------SHIPS--------------------------
	Local c:Chassis
	Local ex:Component
	
	Local co = Floor(cshapedim / 2)'cshape origin
	
	'LAMJET
	c = New Chassis
	c.name = "Lamjet"
	c.gfx = ship6_gfx
	c.mass = 40
	c.armour = 28
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = -1'fighter physics
	c.speedMax = 170
	c.thrust = .25
	c.strafe = .8
	c.auto_cshape()
	c.power_cshape(0,1,"omni")
	c.power_cshape(-1,-1,"energy")
	c.power_cshape(1,-1,"energy")
	c.add_comp("Engine",-1,2,True)
	c.behavior = "circle"
	c.explodeShake = 2
	c.unlockable = True
	c.cost = 100
	chassisList.addLast(c)
	
	'LANCER
	c = New Chassis
	c.name = "Lancer"
	c.gfx = ship_lancer_gfx
	c.mass = 35
	c.armour = 25
	c.ability = ABILITY_BURNER
	c.points = 5
	c.turnRate = -1'fighter physics
	c.speedMax = 220
	c.thrust = .35
	c.strafe = .5
	c.auto_cshape()
	c.cshape[co-2,co-2] = 1
	c.cshape[co+2,co-2] = 1
	c.power_cshape(0,-1,"energy")
	c.power_cshape(-1,-2,"energy")
	c.power_cshape(1,-2,"energy")
	c.add_comp("Small Engine",0,1,True)
	c.behavior = "circle"'"divebomb"
	c.explodeShake = 2
	c.trim_cshape(0,2)
	c.trim_cshape(-1,-3)
	c.trim_cshape(1,-3)
	c.unlockable = True
	chassisList.addLast(c)
	
	'Zukhov
	c = New Chassis
	c.name = "Zukhov Mk II"
	c.gfx = ship_zukhov_gfx
	c.mass = 40
	c.armour = 40
	c.ability = ABILITY_OVERCHARGE
	c.points = 3
	c.turnRate = -1'fighter physics
	c.speedMax = 150
	c.thrust = .2
	c.strafe = 1
	c.auto_cshape()
	c.cshape[co-1,co-1] = 1
	c.cshape[co+1,co-1] = 1
	c.power_cshape(0,0,"omni")
	c.power_cshape(2,-1,"munition")
	c.power_cshape(-2,-1,"munition")
	c.add_comp("Small Engine",0,1,True)
	c.behavior = "circle"
	c.explodeShake = 2
	For Local x = -2 To 2
		For Local y = -3 To -2
			c.trim_cshape(x,y)
		Next
	Next
	c.trim_cshape(0,2)
	c.unlockable = True
	c.cost = 100
	chassisList.addLast(c)
	
	'HOPPER
	c = New Chassis
	c.name = "Trajectory"
	c.gfx = ship_hopper_gfx
	c.mass = 35
	c.armour = 20
	c.ability = ABILITY_BLINK
	c.points = 5
	c.turnRate = -1'fighter physics
	c.speedMax = 220
	c.thrust = .3
	c.strafe = .5
	c.auto_cshape()
	c.power_cshape(0,-1,"omni")
	c.power_cshape(-2,-2,"omni")
	c.power_cshape(2,-2,"omni")
	c.add_comp("Small Engine",-1,-1,True)
	c.add_comp("Small Engine",1,-1,True)
	c.behavior = "circle"'"divebomb"
	c.explodeShake = 2
	For Local x = -1 To 1
	For Local y = 0 To 3
		c.trim_cshape(x,y)
	Next
	Next
	c.unlockable = True
	c.special = True
	c.cost = 200
	chassisList.addLast(c)
	
	'SCRAP FIGHTER
	c = New Chassis
	c.name = "Scrapper"
	c.gfx = ship_scrapfighter_gfx
	c.mass = 30
	c.armour = 15
	c.ability = ABILITY_SHIELD'ABILITY_BURNER
	c.points = 5
	c.turnRate = -1'fighter physics
	c.speedMax = 180
	c.thrust = .3
	c.strafe = 1
	c.auto_cshape()
	c.power_cshape(0,-2,"omni")
	c.power_cshape(-2,0,"munition")
	c.power_cshape(2,0,"munition")
	c.add_comp("Small Engine",-1,1,True)
	c.add_comp("Small Engine",1,1,True)
	c.behavior = "circle"
	For Local x = -1 To 1
		c.trim_cshape(x,2)
	Next
	c.trim_cshape(0,1)
	c.unlockable = True
	c.cost = 50
	chassisList.addLast(c)
	
	'SCRAP BOMBER
	c = New Chassis
	c.name = "Junker"
	c.gfx = ship_scrapbomber_gfx
	c.mass = 40
	c.armour = 15
	c.ability = ABILITY_SHIELD
	c.points = 2
	c.turnRate = -1'fighter physics
	c.speedMax = 150
	c.thrust = .2
	c.strafe = 1
	c.auto_cshape()
	c.power_cshape(0,-2,"omni")
	c.power_cshape(-2,0,"munition")
	c.power_cshape(2,0,"munition")
	c.add_comp("Small Engine",-1,1,True)
	c.add_comp("Small Engine",1,1,True)
	c.behavior = "support"
	For Local x = -1 To 1
		c.trim_cshape(x,2)
	Next
	c.unlockable = True
	c.cost = 75
	chassisList.addLast(c)
	
	'PILLBUG
	c = New Chassis
	c.name = "Pillbug"
	c.gfx = ship_pillbug_gfx
	c.mass = 40
	c.armour = 25
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = -1'fighter physics
	c.speedMax = 150
	c.thrust = .17
	c.strafe = 1
	c.auto_cshape()
	c.power_cshape(0,-1,"omni")
	c.power_cshape(-2,-2,"energy")
	c.power_cshape(2,-2,"energy")
	c.add_comp("Small Engine",-1,2,True)
	c.add_comp("Small Engine",1,2,True)
	c.behavior = "circle"
	c.explodeShake = 2
	For Local x = -2 To 2
		c.trim_cshape(x,3)
		c.trim_cshape(x,3)
	Next
	c.unlockable = True
	c.cost = 250
	chassisList.addLast(c)
	
	'FRIGATE
	c = New Chassis
	c.name = "Frigate"
	c.gfx = ship_frigate_gfx
	c.mass = 80
	c.armour = 35
	c.ability = ABILITY_BLINK
	c.points = 4
	c.turnRate = 75
	c.speedMax = 160
	c.thrust = .17
	c.trailRGB[0] = 32
	c.trailRGB[1] = 62
	c.trailRGB[2] = 32
	c.auto_cshape()
	c.power_cshape(0,1,"omni")
	c.power_cshape(-2,-2,"energy")
	c.power_cshape(2,-2,"energy")
	c.power_cshape(0,0,"energy")
	c.add_comp("Engine",-1,5,True)
	c.behavior = "support"
	c.explodeShake = 2
	For Local x = -1 To 1
		For Local y = -5 To -2
			c.trim_cshape(x,y)
		Next
	Next
	For Local y = 3 To 5
		c.trim_cshape(-2,y)
		c.trim_cshape(2,y)
	Next
	c.trim_cshape(0,-1)
	c.unlockable = True
	c.cost = 600
	chassisList.addLast(c)
	
	'HUMAN FRIGATE
	c = New Chassis
	c.name = "Gunskipper"
	c.gfx = ship_humanfrigate_gfx
	c.mass = 80
	c.armour = 35
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = 75
	c.speedMax = 160
	c.thrust = .17
	c.trailRGB[0] = 62
	c.trailRGB[1] = 62
	c.trailRGB[2] = 32
	c.auto_cshape()
	c.power_cshape(-4,0,"munition")
	c.power_cshape(-2,0,"omni")
	c.power_cshape(4,0,"munition")
	c.power_cshape(2,0,"omni")
	c.add_comp("Small Engine",-2,1,True)
	c.add_comp("Small Engine",-1,4,True)
	c.add_comp("Small Engine",2,1,True)
	c.add_comp("Small Engine",1,4,True)
	c.behavior = "support"
	c.explodeShake = 2
	For Local x = -2 To 2
		For Local y = -5 To -2
			c.trim_cshape(x,y)
		Next
	Next
	c.trim_cshape(0,-1)
	For Local x = 2 To 3
		c.trim_cshape(x,2)
		c.trim_cshape(-x,2)
	Next
	For Local x = -2 To 2
		c.trim_cshape(x,3)
	Next
	c.trim_cshape(-2,4)
	c.trim_cshape(2,4)
	For Local y = 4 To 5
		c.trim_cshape(0,y)
	Next
	c.trim_cshape(-1,5)
	c.trim_cshape(1,5)
	c.unlockable = True
	c.cost = 650
	chassisList.addLast(c)
	
	'TORTOISE
	c = New Chassis
	c.name = "Tortoise"
	c.gfx = ship_tortoise_gfx
	c.mass = 240
	c.armour = 50
	c.ability = ABILITY_SHIELD
	c.fortifyList.addLast(new_fortify(4.5, 210, 0))'a 115d frontal arc that reduces damage
	c.points = 3
	c.turnRate = 55
	c.speedMax = 120
	c.thrust = .1
	c.trailRGB[0] = 32
	c.trailRGB[1] = 32
	c.trailRGB[2] = 32
	c.trailScale = 2
	c.auto_cshape()
	c.power_cshape(-5,-3,"munition")
	c.power_cshape(-4,-3,"munition")
	c.power_cshape(5,-3,"munition")
	c.power_cshape(4,-3,"munition")
	c.add_comp("Engine",-4,3,True)
	c.add_comp("Engine",2,3,True)
	c.behavior = "circle"
	c.explodeShake = 3
	For Local x = -3 To 3
		For Local y = -5 To -2
			c.trim_cshape(x,y)
		Next
		c.trim_cshape(x,2)
	Next
	c.trim_cshape(-5,-5)
	c.trim_cshape(5,-5)
	For Local y = -1 To 2
		c.trim_cshape(0,y)
		c.trim_cshape(-5,y)
		c.trim_cshape(5,y)
		c.trim_cshape(-4,y)
		c.trim_cshape(4,y)
	Next
	c.trim_cshape(-5,4)
	c.trim_cshape(5,4)
	c.cshape[co-4,co-4] = 1
	c.cshape[co+4,co-4] = 1
	c.unlockable = True
	c.cost = 1500
	chassisList.addLast(c)
	
	'STEALTH BOMBER
	c = New Chassis
	c.name = "Corbeau X-2"
	c.gfx = ship_stealthbomber_gfx
	c.mass = 80
	c.armour = 20
	c.ability = ABILITY_CLOAK
	c.points = 5
	c.turnRate = 100
	c.speedMax = 180
	c.thrust = .2
	c.trailRGB[0] = 32
	c.trailRGB[1] = 32
	c.trailRGB[2] = 62
	c.auto_cshape()
	c.power_cshape(-2,-2,"munition")
	c.power_cshape(-1,1,"omni")
	c.power_cshape(2,-2,"munition")
	c.power_cshape(1,1,"omni")
	c.add_comp("Small Engine",-2,0,True)
	c.add_comp("Small Engine",2,0,True)
	c.behavior = "support"
	c.explodeShake = 2
	For Local y = -1 To 3
		For Local x = 3 To 5
			c.trim_cshape(x,y)
			c.trim_cshape(-x,y)
		Next
	Next
	c.unlockable = True
	c.cost = 550
	chassisList.addLast(c)
	
	'BATTLESHIP
	c = New Chassis
	c.name = "Destrier"
	c.gfx = ship_battleship_gfx
	c.mass = 240
	c.armour = 50
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = 70
	c.speedMax = 120
	c.thrust = .1
	c.trailRGB[0] = 32
	c.trailRGB[1] = 62
	c.trailRGB[2] = 32
	c.trailScale = 3
	c.auto_cshape()
	c.power_cshape(-4,2,"energy")
	c.power_cshape(4,2,"energy")
	c.power_cshape(-3,0,"energy")
	c.power_cshape(3,0,"energy")
	c.power_cshape(-1,0,"omni")
	c.power_cshape(1,0,"omni")
	c.add_comp("Engine",-1,4,True)
	c.behavior = "support"
	c.explodeShake = 2
	For Local x = -2 To 2
		For Local y = -5 To -1
			c.trim_cshape(x,y)
		Next
	Next
	For Local y = -5 To -1
		c.trim_cshape(-3,y)
		c.trim_cshape(3,y)
	Next
	For Local x = -4 To 4
		c.trim_cshape(x,5)
	Next
	c.trim_cshape(0,0)
	c.trim_cshape(0,1)
	For Local x = 4 To 5
		c.trim_cshape(x,0)
		c.trim_cshape(-x,0)
	Next
	For Local y = 0 To 5
		c.trim_cshape(-5,y)
		c.trim_cshape(5,y)
	Next
	For Local x = -1 To 1
		c.trim_cshape(x,2)
		c.trim_cshape(x,3)
	Next
	c.cost = 3000
	c.unlockable = True
	chassisList.addLast(c)
	
	'TUSU
	c = New Chassis
	c.name = "T.U.S.U."
	c.gfx = ship_tusu_gfx
	c.mass = 14
	c.armour = 6
	c.ability = ABILITY_CLOAK
	c.points = 5
	c.turnRate = -1'fighter physics
	c.speedMax = 180
	c.thrust = .4
	c.strafe = 1
	c.trailRGB[0] = 32
	c.trailRGB[1] = 32
	c.trailRGB[2] = 64
	c.auto_cshape()
	c.power_cshape(0,-1,"omni")
	c.power_cshape(0,0,"omni")
	c.add_comp("Small Engine",-1,-1,True)
	c.add_comp("Small Engine",1,-1,True)
	c.behavior = "circle"
	c.unlockable = True
	c.special = True
	c.cost = 135
	chassisList.addLast(c)
	
	'FLEA
	c = New Chassis
	c.name = "Flea"
	c.gfx = ship_flea_gfx
	c.mass = 14
	c.armour = 6
	c.ability = ABILITY_BLINK'BURNER
	c.points = 5
	c.turnRate = -1'fighter physics
	c.speedMax = 180
	c.thrust = .4
	c.strafe = 1
	c.trailRGB[0] = 34
	c.trailRGB[1] = 62
	c.trailRGB[2] = 34
	c.auto_cshape()
	c.power_cshape(0,0,"energy")
	c.add_comp("Small Engine",0,1,True)
	c.behavior = "circle"
	'c.trim_cshape(-1,-1)
	'c.trim_cshape(0,-1)
	'c.trim_cshape(1,-1)
	c.unlockable = True
	c.cost = 45
	chassisList.addLast(c)
	
	'DRONE
	c = New Chassis
	c.name = "Drone"
	c.gfx = ship_drone_gfx
	c.mass = 14
	c.armour = 1
	c.ability = ABILITY_BLINK
	c.points = 0
	c.turnRate = -1'fighter physics
	c.speedMax = 180
	c.thrust = .4
	c.strafe = 1
	c.trailRGB[0] = 34
	c.trailRGB[1] = 62
	c.trailRGB[2] = 34
	c.auto_cshape()
	c.power_cshape(0,0,"energy")
	c.add_comp("Small Engine",0,1,True)
	c.behavior = "divebomb"
	'c.trim_cshape(-1,-1)
	'c.trim_cshape(0,-1)
	'c.trim_cshape(1,-1)
	c.special = True
	chassisList.addLast(c)
	
	'CARRIER
	c = New Chassis
	c.name = "Carrier"
	c.gfx = ship_carrier_gfx
	c.mass = 240
	c.armour = 50
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = 40
	c.speedMax = 120
	c.thrust = .1
	c.trailRGB[0] = 32
	c.trailRGB[1] = 62
	c.trailRGB[2] = 32
	c.trailScale = 2
	c.auto_cshape()
	c.power_cshape(0,1,"munition")
	c.power_cshape(-2,-2,"energy")
	c.power_cshape(2,-2,"energy")
	c.power_cshape(0,-2,"energy")
	c.power_cshape(0,0,"energy")
	c.add_comp("Small Engine",-5,2,True)
	c.add_comp("Small Engine",-5,5,True)
	c.add_comp("Small Engine",5,2,True)
	c.add_comp("Small Engine",5,5,True)
	c.behavior = "support"
	c.explodeShake = 3
	chassisList.addLast(c)
	
	'CARRIER
	c = New Chassis
	c.name = "Lasareath"
	c.gfx = ship5_gfx
	c.mass = 240
	c.armour = 50
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = 40
	c.speedMax = 120
	c.thrust = .1
	c.trailRGB[0] = 32
	c.trailRGB[1] = 62
	c.trailRGB[2] = 32
	c.auto_cshape()
	c.power_cshape(0,-5,"munition")
	c.power_cshape(5,0,"energy")
	c.power_cshape(4,0,"energy")
	c.power_cshape(5,1,"energy")
	c.power_cshape(4,1,"energy")
	c.power_cshape(-4,3,"munition")
	c.add_comp("Small Engine",-1,5,True)
	c.add_comp("Small Engine",0,5,True)
	c.add_comp("Small Engine",1,5,True)
	c.behavior = "support"
	c.explodeShake = 3
	chassisList.addLast(c)
	
	'FREIGHTER
	c = New Chassis
	c.name = "Freighter"
	c.gfx = ship_freighter_gfx
	c.mass = 210
	c.armour = 30
	c.turnRate = 40
	c.speedMax = 120
	c.thrust = .13
	c.trailRGB[0] = 32
	c.trailRGB[1] = 32
	c.trailRGB[2] = 32
	c.trailScale = 2
	c.auto_cshape()
	c.power_cshape(0,-4,"munition")
	c.add_comp("Engine",-1,5,True)
	c.behavior = "hold"
	c.explodeShake = 3
	chassisList.addLast(c)
	
	'TURRET
	c = New Chassis
	c.name = "Turret"
	c.gfx = ship_turret_gfx
	c.mass = 25
	c.armour = 6
	c.turnRate = -1
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,-2,"energy")
	'trim off the engines
	For Local side = -1 To 1 Step 2
		For Local y = -1 To 3
			For Local x = -4 To -2
				c.trim_cshape(x*side,y)
			Next
		Next
	Next
	c.behavior = "turret"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'MISSILE TURRET
	c = New Chassis
	c.name = "Missile Turret"
	c.gfx = ship_missileturret_gfx
	c.mass = 25
	c.armour = 6
	c.turnRate = -1
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,-2,"munition")
	'trim off the engines
	For Local side = -1 To 1 Step 2
		For Local y = -1 To 3
			For Local x = -4 To -2
				c.trim_cshape(x*side,y)
			Next
		Next
	Next
	c.behavior = "turret"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'HUMAN TURRET
	c = New Chassis
	c.name = "Machinegun Turret"
	c.gfx = ship_humanturret_gfx
	c.animated = False
	c.fortifyList.addLast(new_fortify(1.5, 120, 90))'side armour
	c.fortifyList.addLast(new_fortify(1.5, 120, 270))
	c.mass = 25
	c.armour = 6
	c.turnRate = 90
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,-2,"munition")
	c.behavior = "turret"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'HUMAN TURRET
	c = New Chassis
	c.name = "Snail Turret"
	c.gfx = ship_snailturret_gfx
	c.animated = False
	c.fortifyList.addLast(new_fortify(2, 160, 0))'frontal armour
	c.mass = 25
	c.armour = 6
	c.turnRate = 45
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,-2,"munition")
	c.behavior = "turret"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'VECTOR TURRET
	c = New Chassis
	c.name = "Vector Turret"
	c.gfx = vector_ship2_gfx
	c.mass = 25
	c.armour = 10
	c.turnRate = -1
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,-2,"energy")
	c.behavior = "turret"
	c.explodeShake = 2
	c.debrisType = 3'vector debris
	chassisList.addLast(c)
	
	'VECTOR SHIP
	c = New Chassis
	c.name = "Vector Ship"
	c.gfx = vector_ship1_gfx
	c.mass = 40
	c.armour = 21
	c.ability = ABILITY_SHIELD
	c.points = 3
	c.turnRate = -1'fighter physics
	c.speedMax = 180
	c.thrust = .2
	c.strafe = 1
	c.auto_cshape()
	c.power_cshape(0,1,"omni")
	c.power_cshape(-1,-1,"energy")
	c.power_cshape(1,-1,"energy")
	c.add_comp("Engine",-1,2,True)
	c.behavior = "circle"
	c.explodeShake = 2
	c.debrisType = 3'vector debris
	chassisList.addLast(c)
	
	'VECTOR FRIGATE
	c = New Chassis
	c.name = "Vector Frigate"
	c.gfx =  vector_ship3_gfx
	c.mass = 80
	c.armour = 31
	c.ability = ABILITY_BLINK
	c.points = 3
	c.turnRate = 90
	c.speedMax = 180
	c.thrust = .2
	c.auto_cshape()
	c.power_cshape(-4,0,"munition")
	c.power_cshape(-2,0,"omni")
	c.power_cshape(4,0,"munition")
	c.power_cshape(2,0,"omni")
	c.add_comp("Small Engine",0,3,True)
	c.behavior = "circle"
	c.explodeShake = 2
	c.debrisType = 3'vector debris
	chassisList.addLast(c)
	
	'WARP BEACON
	c = New Chassis
	c.name = "Warp Beacon"
	c.gfx = ship_warpbeacon_gfx
	c.mass = 20
	c.stationary = True
	c.armour = 15
	c.turnRate = 20
	c.speedMax = 50
	c.thrust = 0
	c.strafe = 0
	c.auto_cshape()
	c.power_cshape(0,0,"energy")
	c.behavior = "turret"
	chassisList.addLast(c)
	
	'SPACE CUTTLEFISH
	c = New Chassis
	c.name = "Biscuitfish"
	c.gfx = ship_biscuitfish_gfx
	c.mass = 70
	c.armour = 30
	c.turnRate = -1
	c.speedMax = 180
	c.thrust = .2
	c.strafe = 1
	c.debrisType = 2'gib debris
	c.auto_cshape()
	c.power_cshape(0,1,"energy")
	c.power_cshape(-2,-2,"energy")
	c.power_cshape(2,-2,"energy")
	c.power_cshape(0,0,"energy")
	c.behavior = "heal"
	c.explodeShake = 0
	c.bio = True
	chassisList.addLast(c)

	c = New Chassis
	c.name = "Timberwolf"
	c.gfx = zerg_wolf_gfx
	c.mass = 40
	c.armour = 5
	c.turnRate = -1
	c.speedMax = 230
	c.thrust = .3
	c.strafe = 1
	c.debrisType = 2'gib debris
	c.auto_cshape()
	c.add_comp("Barb",0,-2,True)
	c.behavior = "circle"
	c.explodeShake = 0
	c.bio = True
	chassisList.addLast(c)
	
	c = New Chassis
	c.name = "Litus Devil"
	c.gfx = zerg_devil_gfx
	c.mass = 60
	c.armour = 9
	c.turnRate = -1
	c.speedMax = 180
	c.thrust = .2
	c.strafe = 1
	c.debrisType = 2'gib debris
	c.auto_cshape()
	c.add_comp("Acid",0,-3,True)
	c.behavior = "circle"'"divebomb"
	c.explodeShake = 0
	c.bio = True
	chassisList.addLast(c)
	
	c = New Chassis
	c.name = "Mite"
	c.gfx = zerg_mite_gfx
	c.mass = 25
	c.armour = 1.5
	c.turnRate = -1
	c.speedMax = 250
	c.thrust = .5
	c.strafe = 1
	c.debrisType = 2'gib debris
	c.auto_cshape()
	c.add_comp("Thrust",0,0,True)
	c.behavior = "ram"
	c.explodeShake = 0
	c.bio = True
	chassisList.addLast(c)
		
	c = New Chassis
	c.name = "Anemone"
	c.gfx = zerg_anemone_gfx
	c.mass = 70
	c.armour = 32
	c.turnRate = 10
	c.stationary = True
	c.thrust = 0
	c.strafe = 0
	c.debrisType = 2'gib debris
	c.auto_cshape()
	c.add_comp("Tentacle",0,0,True)
	c.behavior = "fire"
	c.bio = True
	chassisList.addLast(c)
	
	'-------------------------ORDNANCE------------------------
	'MISSILE
	c = New Chassis
	c.name = "Missile"
	c.gfx = missile_gfx
	c.mass = 8
	c.armour = 2
	c.turnRate = -1
	c.speedMax = 310'actually set by gun shotspeed
	c.thrust = 1.2
	c.strafe = 0
	c.auto_cshape()
	c.add_comp("Explode",0,-1,True)
	c.add_comp("Small Engine",0,0,True)
	c.behavior = "missile"
	c.explodeShake = 0
	c.explodeNum = 0
	c.explodeSound = missileexplode_sfx
	c.ord = True'explode on contact
	c.unlockable = True
	chassisList.addLast(c)
	
	'MINE
	c = New Chassis
	c.name = "Mine"
	c.gfx = mine_gfx
	c.mass = 8
	c.armour = 8
	c.turnRate = -1
	c.speedMax = 100
	c.thrust = .2
	c.strafe = 0
	c.auto_cshape()
	c.add_comp("Explode",0,-1,True)
	c.behavior = "missile"
	c.explodeShake = 0
	c.explodeSound = missileexplode_sfx
	c.ord = True'explode on contact
	chassisList.addLast(c)
	
	'-------------------------OBJECTS-------------------------
	
	'SMALL ASTEROID
	c = New Chassis
	c.name = "Asteroid 1"
	c.gfx = asteroid1_gfx
	c.animated = False
	c.mass = 20
	c.armour = 3
	c.speedMax = 120
	c.thrust = 0
	c.explodeSound = rockexplode_sfx'more rock cracky
	c.debrisType = 1'rock debris
	c.behavior = "inert"
	chassisList.addLast(c)
	
	'LARGE ASTEROID
	c = New Chassis
	c.name = "Asteroid 2"
	c.gfx = asteroid2_gfx
	c.animated = False
	c.mass = 40
	c.armour = 5
	c.speedMax = 120
	c.thrust = 0
	c.explodeSound = rockexplode_sfx'more rock cracky
	c.debrisType = 1'rock debris
	'c.dropShipList.addLast("Asteroid 2a")
	'c.dropShipList.addLast("Asteroid 2b")
	'c.dropShipList.addLast("Asteroid 2c")
	c.behavior = "inert"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'c = New Chassis
	'c.name = "Asteroid 2a"
	'c.copyChassis("Asteroid 1")	'just like a small asteroid
	'c.gfx = asteroid2a_gfx		'only looks different
	'chassisList.addLast(c)
	
	'c = New Chassis
	'c.name = "Asteroid 2b"
	'c.copyChassis("Asteroid 1")	'just like a small asteroid
	'c.gfx = asteroid2b_gfx		'only looks different
	'chassisList.addLast(c)
	
	'c = New Chassis
	'c.name = "Asteroid 2c"
	'c.copyChassis("Asteroid 1")	'just like a small asteroid
	'c.gfx = asteroid2c_gfx		'only looks different
	'chassisList.addLast(c)
	
	'BIG BIG ASTEROID
	c = New Chassis
	c.name = "Asteroid 3"
	c.gfx = asteroid3_gfx
	c.animated = False
	c.mass = 300
	c.armour = 60
	c.speedMax = 60
	c.explodeSound = rockexplode_sfx'more rock cracky
	c.explodeNum = 80
	c.debrisType = 1'rock debris
	c.behavior = "inert"
	c.explodeShake = 3
	chassisList.addLast(c)
	
	c = New Chassis
	c.name = "Explosive Asteroid 1"
	c.copyChassis("Asteroid 1")	'just like a small asteroid
	c.gfx = asteroid7_gfx		'only looks different
	ex = c.add_comp("Explode",0,0,True)'and explodes
	ex.damagebonus = 24
	c.armour:* .5
	c.ord = True'explode on contact
	chassisList.addLast(c)
	
	c = New Chassis
	c.name = "Explosive Asteroid 2"
	c.copyChassis("Asteroid 2")	'just like a large asteroid
	c.gfx = asteroid6_gfx		'only looks different
	ex = c.add_comp("Explode",0,0,True)'and explodes
	ex.damagebonus = 44
	c.armour:* .5
	c.ord = True'explode on contact
	chassisList.addLast(c)
	
	c = New Chassis
	c.name = "Explosive Asteroid 3"
	c.copyChassis("Asteroid 3")	'just like a BIG asteroid
	c.gfx = asteroid8_gfx		'only looks different
	ex = c.add_comp("Explode",0,0,True)'and explodes
	ex.damagebonus = 64
	c.armour = 22
	c.ord = True'explode on contact
	chassisList.addLast(c)
	
	'VECTOR SMALL ASTEROID
	c = New Chassis
	c.name = "Vector Asteroid 1"
	c.gfx = vector_asteroid1_gfx
	c.animated = False
	c.mass = 20
	c.armour = 3
	c.speedMax = 180
	c.thrust = 0
	c.explodeSound = rockexplode_sfx'more rock cracky
	c.debrisType = 3'vector debris
	c.behavior = "inert"
	chassisList.addLast(c)
	
	'VECTOR LARGE ASTEROID
	c = New Chassis
	c.name = "Vector Asteroid 2"
	c.gfx = vector_asteroid2_gfx
	c.animated = False
	c.mass = 40
	c.armour = 5
	c.speedMax = 180
	c.thrust = 0
	c.explodeSound = rockexplode_sfx'more rock cracky
	c.debrisType = 3'vector debris
	'c.dropShipList.addLast("Asteroid 2a")
	'c.dropShipList.addLast("Asteroid 2b")
	'c.dropShipList.addLast("Asteroid 2c")
	c.behavior = "inert"
	c.explodeShake = 2
	chassisList.addLast(c)
	
	'BLACK HOLE
	Rem
	c = New Chassis
	c.name = "Black Hole"
	c.gfx = blackhole_gfx
	c.animated = True
	c.mass = 10000
	c.armour = 100
	c.stationary = True
	c.invulnerable = True
	c.behavior = "fire"
	c.add_comp("GRAVITY",0,0,True)
	chassisList.addLast(c)
	EndRem
	
	' --- initialize some things for all chassis ---
	For Local def:Chassis = EachIn chassisList
		'make the hit graphic
		def.hitgfx = getHitImage(def.gfx[0])
		
		'default the drop squad if we haven't set it
		If def.dropSquad = Null Then def.dropSquad = inertSquad
		
		'if we haven't set the trail color already, do it now
		If def.trailRGB[0] = 0 And def.trailRGB[1] = 0 And def.trailRGB[2] = 0
			def.trailRGB[0] = 64
			def.trailRGB[1] = 64
			def.trailRGB[2] = 64
		EndIf
		'detect which tiles are availabe for components
		'def.auto_cshape()
	Next
EndFunction






