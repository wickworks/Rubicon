'adds a background to the game
Function add_backdrop(_name$)
	
	Select Lower(_name$)
	Case "nebulae_paint"
		Local nebx = 100
		Local neby = 100
		Local d = Rand(6,8)
	
		'larger, more transparent backdrop
		Local bg:Background = New Background
		bg.gfx = paintnebulae_back_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = -90
		bg.dist = d+.5
		bg.distShade = False
		bg.spin = .0015
		bg.scale = 5
		bg.alpha = .95
		bg.RGB[0] = 200
		bg.RGB[1] = 150
		bg.RGB[2] = 255
		bgList.AddFirst(bg)
		
		bg = New Background
		bg.gfx = paintnebulae_back_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = -160
		bg.dist = d+.3
		bg.distShade = False
		bg.spin = -.003
		bg.scale = 4.5
		bg.alpha = .9
		bg.RGB[0] = 230
		bg.RGB[1] = 220
		bg.RGB[2] = 180
		bgList.AddFirst(bg)
	
		'center bit
		bg = New Background
		bg.gfx = paintnebulae_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = -90
		bg.dist = d
		bg.distShade = False
		bg.scale = 4
		bg.alpha = .85
		bgList.AddFirst(bg)
		
		'front bits
		bg = New Background
		bg.gfx = paintnebulae_back_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = 67
		bg.dist = d-.2
		bg.distShade = False
		bg.spin = .0005
		bg.scale = 6
		bg.alpha = .95
		bg.RGB[0] = 180
		bg.RGB[1] = 150
		bg.RGB[2] = 230
		bgList.AddFirst(bg)
		
		bg = New Background
		bg.gfx = paintnebulae_back_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = 130
		bg.dist = d-.7
		bg.distShade = False
		bg.spin = -.002
		bg.scale = 8
		bg.alpha = .95
		bg.RGB[0] = 170
		bg.RGB[1] = 130
		bg.RGB[2] = 215
		bgList.AddFirst(bg)
		
		bg = New Background
		bg.gfx = paintnebulae_back_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = nebx
		bg.y = neby
		bg.rot = 90
		bg.dist = d-.4
		bg.distShade = False
		bg.spin = .001
		bg.scale = 4
		bg.alpha = .9
		bg.RGB[0] = 220
		bg.RGB[1] = 190
		bg.RGB[2] = 150
		bgList.AddFirst(bg)
		
	Case "greenplanet"
		Local bg:Background = New Background
		bg.gfx = greenplanet_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = 500
		bg.y = 300
		bg.dist = 4
		bg.scale = 5
		bgList.AddFirst(bg)
		
	Case "rakisplanet"
		Local bg:Background = New Background
		bg.gfx = rakisplanet_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = -300
		bg.y = 500
		bg.dist = 4
		bg.scale = 7
		bg.rot = -15
		bgList.AddFirst(bg)
		
		'makes all the asteroids red
		For Local a:Ship = EachIn entityList
			If Lower(Left(a.name,8)) = "asteroid"
				a.RGB[0] = 220
				a.RGB[1] = 140
				a.RGB[2] = 120
			EndIf
		Next

	Case "gravitywells"
		Local bhSquad:Squadron = New Squadron
		bhSquad.faction = 0
		bhSquad.behavior = "fire"
		Local hole:Ship = new_ship("Black Hole",0,0,"",bhSquad)
		hole.ignoreCollisions = True
		
	EndSelect
EndFunction