
'choose your ship
Function arcade_upgrade()
	FlushKeys()
	FlushMouse()
	
	new_music = theme_music
	
	'set up the buttons and whatnot
	'------------------------------
	
	'back button
	Local menuB:Button = New Button
	menuB.text = "Menu"
	menuB.wid = 112
	menuB.het = 30
	menuB.x = 0
	menuB.y = SHEIGHT - menuB.het
	
	'mission launch button
	Local launchB:Button = New Button
	launchB.text = "Next Wave"
	launchB.text_scale = 2
	launchB.wid = 196
	launchB.het = 90
	launchB.x = SWIDTH - launchB.wid
	launchB.y = SHEIGHT - launchB.het
	launchB.rgb[0] = 128
	launchB.rgb[1] = 60
	launchB.rgb[2] = 60
	
	'bank remaining button
	Local bankB:Button = New Button
	bankB.text = "Bank Remaining"
	bankB.wid = 132
	bankB.het = 30

	'upgrade buttons	
	Local upgradeB:Button[6]
	For Local i = 0 To 5
		upgradeB[i] = New Button
		upgradeB[i].text = "+"
		upgradeB[i].wid = 22
		upgradeB[i].het = 22
		upgradeB[i].skipBorder = True
	Next
	
	Local texthet = TextHeight("BOBCAT")
	
	'space for the ship's name all big
	Local namewid = 300
	Local namehet = 64
	
	'space for the ship all big
	Local shiphet = 256
	
	'space for the stats
	Local statwid = 206
	Local stathet = 138

	'the currently selected ship image
	Local scale
	For scale = 2 To 7'find how big we can resize the image
		If ImageHeight(p1.gfx[0])*scale < shiphet Then Continue Else Exit
	Next
	Local selship_gfx:TImage = resizeImage(p1.gfx[0], scale-1)
	SetImageHandle selship_gfx,ImageWidth(selship_gfx)/2,0
	Local selship_ability$ = String(MapValueForKey(abilityMap, String(p1.base.ability)))
	
	'y location of drawing stuff in the center
	Local ybar
	Local yspace = SHEIGHT / 40'how much space between each element har

	oldTime = MilliSecs()
	timePass = 22'just so no tricky stuff at the initial loop
	Repeat
		Cls
		
		updateTime()
		
		updateCursor()
		
		'mouse information
		Local m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		
		'draw the grid
		SetRotation 0
		SetScale 1,1
		SetAlpha 1
		SetColor 16,16,35
		TileImage grid_gfx
		
		'wave information panel
		Local infox = SWIDTH/6 - 110
		Local infoy = SHEIGHT/3
		drawBorderedRect(infox-10,infoy-10,273,texthet*8)
		SetColor 255,255,255
		SetScale 2,2
		draw_text("WAVE " + Int(game.value[0]) + " SURVIVED!",	infox, infoy)
		draw_text("Good job!", 						infox, infoy + texthet*2)
		SetScale 1,1
		draw_text("- Time: " + time(Int(game.playTime)),		infox, infoy + texthet*4)
		'draw_text("- Enemies destroyed: ",				infox, infoy + texthet*5)
		'draw_text("- Points collected: ",					infox, infoy + texthet*6)
		
		'points, upgrade panel
		Local mincost = -1
		Local upgradex = 5*SWIDTH/6 - 140
		Local upgradey = infoy
		drawBorderedRect(upgradex-20,upgradey-10,306,280)
		SetColor 255,255,255
		SetScale 1,1
		draw_text("Cost:", upgradex, upgradey + 2)
		For Local i = 0 To 5
			Local lev = Int(game.value[6+i])	'current level of attribute
			Local cost = (lev+1)				'cost to upgrade this attribute
			If mincost = -1 Then mincost = cost Else mincost = Min(mincost, cost)'keep track of what's the lowest-costing thing
			Local stat$
			
			Select i
			Case 0
				stat = "Armour"
				cost:* 30
			Case 1
				stat = "Engine"
				cost:* 50
			Case 2
				stat = selship_ability
				cost:* 40
			Case 3
				stat = "Primary Weapons"
				cost:* 60
			Case 4
				stat = "Alternate Weapons"
				cost:* 50
			Case 5
				stat = "Lives"
				cost:* 40
			EndSelect
			
			Local pluses$ = " "
			If i <= 4' a stat upgrade
				For Local i = 1 To lev
					pluses = pluses + "+"
				Next
			EndIf
			
			'draw the cost of this upgrade
			If game.value[5] >= cost Then SetColor 255,255,255 Else SetColor 128,128,128	'greyed out if not enough points
			If upgradeB[i].pressed <= 2 And game.value[5] < cost Then SetColor 255,0,0		'redded out if trying to press it anyway
			draw_text(cost, upgradex + 16 - TextWidth(cost)/2, upgradey + 32 + (texthet+14)*i)
			
			'draw the name of the stat + how many times we've upgraded
			draw_text(stat+pluses, upgradex + 80, upgradey + 32 + (texthet+14)*i)
			'draw extra lives
			If i = 5
				For Local l = 1 To game.lives
					DrawImage(life_gfx[0], upgradex + 78 + TextWidth(stat) + l * (ImageWidth(life_gfx[0]) + 4), upgradey + 38 + (texthet+14)*i)
				Next
			EndIf
			
			upgradeB[i].x = upgradex + 40
			upgradeB[i].y = upgradey + 32 + (texthet+14)*i - 5
			upgradeB[i].update(m)
			upgradeB[i].draw()
			
			'give description of this component
			If upgradeB[i].pressed < 5' Or pilot.difficulty = 0
				Local desc$[8]
				Select stat
				Case "Armour"
					desc[0] = "Increases max health by 5"+Chr(34)
				Case "Engine"
					desc[0] = "Increases thrust by .05, max speed by 15 m/s, and afterburner by .5 s."
				Case selship_ability
					desc[0] = "+1 use of [ability]."
				Case "Primary Weapons"
					desc[0] = "Left-mouse weapons fire 15% faster."
				Case "Alternate Weapons"
					desc[0] = "Right-mouse weapons do more +10% damage."
				Case "Lives"
					desc[0] = "Extra ships for when you wreck the one you have."
				EndSelect
				
				If pilot.difficulty = 0 Then desc[0] = "ZEN MODE: Forfeit material things."
				
				'break the description up into lines
				desc = parseText(desc[0], SWIDTH - upgradex - 40)
				
				'draw the description
				For Local l = 0 To 7
					draw_text(desc[l], upgradex, upgradey + 210 + texthet*l)
				Next
			EndIf
			
			'upgrade this component
			If upgradeB[i].pressed = 0 And game.value[5] >= cost
				Local armourBonus#, engineBonus#, pointBonus, pweapBonus#, aweapBonus#
				Select stat
				Case "Armour"
					armourBonus:+ 5
				Case "Engine"
					engineBonus:+ 1
				Case selship_ability
					pointBonus:+ 1
				Case "Primary Weapons"
					pweapBonus:+ 1
				Case "Alternate Weapon"
					aweapBonus:+ 1
				Case "Lives"
					game.lives:+ 1
				EndSelect 
				
				'give the relavent components their bonuses
				For Local c:Component = EachIn p1.compList
					'use the engine for chassis bonuses >:) (o so u think ur clevr, wat about ZERGS huh)
					If c.class = "engine"
						c.armourBonus:+ armourBonus
						c.pointBonus:+ pointBonus
						c.engineBonus:+ 15*engineBonus
						c.juiceBonus:+ .5*engineBonus
						c.thrustBonus:+ .05*engineBonus
						'only give bonuses once
						armourBonus = 0
						engineBonus = 0
						pointBonus = 0
						c.juiceBonus = 0
					EndIf
					
					If c.class = "gun" And Not c.addon
						For Local g:Gun = EachIn c.gunList
							If Not c.alt						'primary weapons
								c.recycleBonus:- (g.fireDelay*.15)*pweapBonus	'fire faster
							Else								'alternate weapons
								c.damageBonus:+ (Max(g.shotdamage,c.damageBonus)*.10)*aweapBonus	'do more damage
							EndIf
							Exit'one-gun list, we've changed the COMPONENT's bonuses
						Next
					EndIf

				Next
						
				'pay for it
				game.value[5]:- cost
				'record that we got this upgrade
				game.value[6+i]:+ 1
			EndIf
		Next
		
		'how many points do we have left to spend?
		SetColor 255,255,255
		If game.value[5] > mincost And globalFrame Then SetColor 255,140,1'flash the points if an upgrade is available
		SetScale 1,1
		DrawImage bigpoint_gfx, upgradex + 256, upgradey + 19
		SetScale 2,2
		draw_text(Int(game.value[5]), upgradex + 234 - TextWidth(Int(game.value[5]))*2, upgradey + 5)
		
		'bank remaining points button
		bankB.x = upgradex + 286 - bankB.wid
		bankB.y = upgradey + 272
		bankB.update(m)
		bankB.draw()
		'tell you you can put points in yer pocket
		If bankB.pressed < 5
			Local bankText$[8]
			If game.value[5] > 0 Then bankText[0] = "Bank points to later unlock ships & components." Else bankText[0] = pilot.points + " points banked!"
			bankText = parseText(bankText[0], SWIDTH - upgradex - 40)
			'draw the description
			For Local l = 0 To 7
				draw_text(bankText[l], upgradex, upgradey + 210 + texthet*l)
			Next
		EndIf
		'put points in yer pocket
		If bankB.pressed = 2
			pilot.points:+ game.value[5]
			pilot.save()
			game.value[5] = 0
		EndIf
		
		'draw the name, ship gfx, stats, loadout
		Local selship_y = draw_shipbar(p1)
		DrawImage selship_gfx, SWIDTH/2, selship_y
		
		'mission launch button
		launchB.update(m)
		launchB.draw()
		If launchB.pressed = 2 Then Exit
		
		'menu button
		menuB.update(m)
		menuB.draw()
		If menuB.pressed = 2 Or KeyHit(KEY_ESCAPE) Or (joyDetected And JoyHit(JOY_MENU))
			pause_menu(False)'can't restart from here
			If game.over = 2 Then Return False
		EndIf
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		updateMusic()

		If Lower(pilot.name) = "wik" And KeyDown(KEY_P) Then game.value[5]:+ 1

		draw_cursor()
		Flip
	Forever

	FlushKeys()
	FlushMouse()
	
	'continue normatlly
	Return True
End Function

