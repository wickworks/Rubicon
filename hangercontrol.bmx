'a component to add to the ships. can be a gun, armour, engines, etc.
Global componentList:TList = New TList'a list of global component archtypes
Type Component
	Field name$
	Field desc$			'a short description of the component
	Field x,y			'when placed into a ship, at this position of the ship's configuration
	Field shape[5,5]		'5x5 grid of what squares this component takes up: 0=empty|1=filled|2=attachment point
	Field rgb[3]		'the color of this component
	Field rot			'0 = 0d | 1 = 90d | 2 = 180d | 3 = 270d
	Field class$		'what color the item should be, and when it consumes power: "gun"|"engine"|"misc"
	Field unique = False	'TRUE/FALSE, whether this component is a unique or if it's stock (NOW DEFUNCT)
	Field cost = 200		'point cost to unlock this component
	
	Field mass#			'how much mass this component adds
	Field armourBonus	#	'how much armour to add
	Field juiceBonus#		'max juice stockpile bonus
	Field engineBonus	#	'adds to the engine rating, which (along with mass) sets maxspeed and thrust.
	Field thrustBonus#	'adds to the ship's thrust
	Field pointBonus		'ability point bonus
	Field damageBonus	#	'% damage added to all guns
	Field burstBonus		'number of shots in a burst
	Field recycleBonus#	'alters time between shots. usually negative.
	Field shotspeedBonus#	'alters the speed of shots
	
	Field fortify#		'damage resistance arc this component proffers
	Field fortify_range# = 90
	Field fortify_offset#		'offset the arc from center
	Field fortify_ramming = False'if it only reduces collision damage
	
	Field gunList:TList = New TList
	
	Field preq[4]		'the type and number of power squares this component needs to work. 0="energy" | 1="munitions" | 2=unused | 3="any"
	Field alt = False		'whether weapons will be tied to the alternate button
	
	Field plugged = True	'whether or not it's on its requisite power tile
	
	Field accepts_addons = True		'can we stick addons on this component?
	Field addon = False	'is THIS component an addon? (addons are always powered, generally have a single attachment tile, add to parent bonuses)
	Field addonList:TList = New TList	'list of addon components attached to this. cleared every loop, they have to re-add themselves constantly
	
	Field locked = False	'TRUE/FALSE whether the player can modify the location of this component (used mostly for engines)
	Field unlockable = True'can the player obtain this component?
	Field special = False'VIP-only?
	
	'makes self a copy of the provided component (if no component is provided, search compList for the provided name
	Method copyComp(_comp:Component,_name$="")
		If _comp = Null
			For Local c:Component = EachIn componentList
				If c.name = _name Then _comp = c
			Next
		EndIf
	
		'component properties
		class = _comp.class
		name = _comp.name
		desc = _comp.desc
		addon = _comp.addon
		accepts_addons = _comp.accepts_addons
		rgb[0] = _comp.rgb[0]
		rgb[1] = _comp.rgb[1]
		rgb[2] = _comp.rgb[2]
		x = 0
		y = 0
		rot = 0
		locked = _comp.locked
		For Local xp = 0 To 4
			For Local yp = 0 To 4
				shape[xp,yp] = _comp.shape[xp,yp]
			Next
		Next
		
		'ship modification stats
		cost = _comp.cost
		armourBonus = _comp.armourBonus
		juiceBonus = _comp.juiceBonus
		engineBonus = _comp.engineBonus
		thrustBonus = _comp.thrustBonus
		pointBonus = _comp.pointBonus
		damageBonus = _comp.damageBonus
		burstBonus = _comp.burstBonus
		recycleBonus = _comp.recycleBonus
		shotspeedBonus = _comp.shotspeedBonus
		fortify = _comp.fortify
		fortify_offset = _comp.fortify_offset
		fortify_range = _comp.fortify_range
		fortify_ramming = _comp.fortify_ramming
		
		preq[0] = _comp.preq[0]
		preq[1] = _comp.preq[1]
		preq[2] = _comp.preq[2]
		preq[3] = _comp.preq[3]

		For Local g:Gun = EachIn _comp.gunList
			gunList.addLast(new_gun(g.name))
		Next
		alt = _comp.alt

	EndMethod
	
	Method loadSelf(cFile:TStream)
		'get the name of the next component
		Local compName$ = ReadLine(cFile)
		
		'see if it's a stock component or a unique
		If Right(compName,7) = "_unique" Then unique = True

		'get the stats for the stock component
		For Local c:Component = EachIn componentList
		If c.name = compName
			copyComp(c)
		EndIf
		Next

		'read how it's configured on the ship, exactly
		x = 		ReadByte(cFile)
		y = 		ReadByte(cFile)
		rot = 	ReadInt(cFile)
		plugged = 	ReadByte(cFile)
		locked = 	ReadByte(cFile)
	EndMethod
	
	Method saveSelf(cFile:TStream)
		'write the name of the component
		Local compName$ = name
		WriteLine(cFile,	compName)
		
		'read how it's configured on the ship, exactly
		WriteByte(cFile,	x)
		WriteByte(cFile,	y)
		WriteInt(cFile,	rot)
		WriteByte(cFile,	plugged)
		WriteByte(cFile,	locked)
	EndMethod
	
	'sets shape to one of a whole bunch of presets
	Method setShape(_id)
		'clear previous shape
		For Local xp = 0 To 4
		For Local yp = 0 To 4
			shape[xp,yp] = 0
		Next
		Next
		
		'set the new shape
		Select _id
		Case 0		'1x1
			shape[0,0]=1
		Case 1		'2x1
			shape[0,0]=1
			shape[1,0]=1
		Case 2		'2x2 corner
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
		Case 3		'2x2
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
			shape[1,1]=1
		Case 4		'3x1
			shape[0,0]=1
			shape[1,0]=1
			shape[2,0]=1
		Case 5		'3x2, L-shape
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
			shape[2,0]=1
		Case 6		'3x2, missing a corner
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
			shape[1,1]=1
			shape[2,0]=1
		Case 7		'3x2, T-shape
			shape[0,0]=1
			shape[1,0]=1
			shape[2,0]=1
			shape[1,1]=1
		Case 8		'3x2
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
			shape[1,1]=1
			shape[2,0]=1
			shape[2,1]=1
		Case 9		'3x3, corner
			shape[0,0]=1
			shape[1,0]=1
			shape[2,0]=1
			shape[0,1]=1
			shape[0,2]=1
		Case 10		'3x3, missing a corner
			shape[0,0]=1
			shape[1,0]=1
			shape[0,1]=1
			shape[1,1]=1
			shape[2,0]=1
			shape[2,1]=1
		Case 12		'3x3, plus-shape
			shape[1,0]=1
			shape[0,1]=1
			shape[1,1]=1
			shape[2,1]=1
			shape[1,2]=1
		Case 12		'3x3
			shape[0,0]=1
			shape[1,0]=1
			shape[2,0]=1
			shape[0,1]=1
			shape[1,1]=1
			shape[2,1]=1
			shape[0,2]=1
			shape[1,2]=1
			shape[2,2]=1
		EndSelect
	EndMethod
EndType

'makes a new component, copies one from the archtype, and returns it
Function new_comp:Component(_name$)
	Local c:Component = New Component
	c.copyComp(Null,_name)
	If c.class = "engine" Then c.locked = True
	Return c
EndFunction

'rotates & returns a set of two points around a 0,0 by some amount
Function rotAdjust[](_cx,_cy,_rot)
	Local adjust[2]
	
	'adjust for rotation
	adjust[0] = ((_rot-2) Mod 2)*_cy - ((_rot-1) Mod 2)*_cx
	adjust[1] = -((_rot-2) Mod 2)*_cx - ((_rot-1) Mod 2)*_cy
	
	Return adjust
EndFunction

Global psquareMap:TMap = CreateMap()
MapInsert(psquareMap, "2", "energy")'power tiles of -1 are energy-type
MapInsert(psquareMap, "3", "munition")'power tiles of -2 are munition-type
MapInsert(psquareMap, "4", "unused")'unused - reserved for later expansion
MapInsert(psquareMap, "5", "omni")'power tiles of -3 are omni-type

Global preqMap:TMap = CreateMap()
MapInsert(preqMap, "0", "energy")'preq[0] is number of energy-requiring tiles
MapInsert(preqMap, "1", "munition")'preq[0] is number of munition-requiring tiles
MapInsert(preqMap, "2", "unused")'unused
MapInsert(preqMap, "3", "any")'preq[0] is number of ADDITIONAL power tiles of any type

'list of components currently installed on the ship
Global cshapedim = 11				'the X-by-X grid for ships that you can drop components onto
Global cshaperatio = 6				'how many pixels x pixels in the gfx that make up a placeable tile
Global selshipscale = 7
Global csize = cshaperatio*selshipscale	'size of the component squares

Global loadout$[16,3]'because we can't convert from 'string array' to 'string array' and I'm sick of this shit
Global loadoutB:Button[16]'loadout mouseover-detecting buttons
For Local i = 0 To 15
	loadoutB[i] = New button
Next

Global configSList:SList 'FUCK IT TWO TEARS IN A BUCKET

Function hanger()
	FlushKeys()
	FlushMouse()
	FlushJoy()

	Local barbuttonhet = 50			'height of fleet/component buttons above list
	Local barwid = 220				'the fleet/component list bar
	Local infoboxhet = 250				'height of the ship/component information box below the list
	
	'set up the (main) buttons and whatnot
	
	'ships button
	Local shipB:Button = New Button
	'shipB.text = "Ships"
	shipB.skipdraw = True
	shipB.x = 6
	shipB.y = 10
	shipB.wid = 94
	shipB.het = 28
	shipB.toggle = 2
	shipB.tab = True
	
	'components button
	Local compB:Button = New Button
	'compB.text = "Components"
	compB.skipdraw = True
	compB.x = 106
	compB.y = 10
	compB.wid = 120
	compB.het = 28
	compB.toggle = 1
	shipB.tab = True
	
	'"return to ships" button
	Local returnB:Button = New button
	returnB.text = "Ship List"
	returnB.x = 228
	returnB.y = 2
	returnB.wid = 108
	returnB.het = 30
	
	'how-to button
	Local helpB:Button = New button
	helpB.text = "How-To"
	helpB.wid = 108
	helpB.het = 30
	helpB.x = SWIDTH - ImageWidth(hanger_infoaddon_gfx) + 50 - helpB.wid
	helpB.y = 2
	helpB.toggle = 1
	
	'unlock components
	Local unlockB:Button = New button
	unlockB.text = "Unlock Components"
	unlockB.wid = 218
	unlockB.het = 30
	unlockB.x = ((returnB.x + returnB.wid) + helpB.x) / 2 - (unlockB.wid/2)
	unlockB.y = 2
	unlockB.toggle = 1
	
	'and the close button for it
	Local closeB:Button = New Button
	closeB.text = "Close"
	closeB.text_scale = 2
	closeB.wid = 256
	closeB.het = 60
	closeB.x = SWIDTH/2 - closeB.wid/2
	closeB.y = SHEIGHT/2 + ImageHeight(hangerhelp_gfx)/2
	
	'mission select button
	Local systB:Button = New Button
	systB.text = "Back"
	systB.wid = 152
	systB.het = 30
	systB.x = SWIDTH - systB.wid - 8
	systB.y = SHEIGHT - 52
	
	'test drive button
	Local testB:Button = New Button
	testB.text = "Test Drive"
	testB.wid = 152
	testB.het = 30
	testB.x = SWIDTH - testB.wid - 8
	testB.y = systB.y - 2 - testB.het
	
	'color scheme buttons
	Local cschemeBList:TList = New TList
	Local colornum = 8
	If Not pilot.VIP Then colornum = 4'agh, it hurts to cut off functionality for some people
	For Local scheme = 0 To colornum
		Local cb:Button = New Button
		cb.wid = 30
		cb.het = 30
		cb.x = SWIDTH - 176 - (cb.wid+8)*(scheme+1)
		cb.y = SHEIGHT - cb.het - 8
		cb.RGB = colorScheme(scheme,2)'dark shade for buttons
		cschemeBList.addlast(cb)
	Next
	
	'new configuration button
	Local newconfigB:Button = New Button
	newconfigB.text = "New Config"
	newconfigB.wid = 10'we reinitialize this constantly, below, so no worries
	newconfigB.het = 30
	newconfigB.textbox = True
	newconfigB.allow_underscores = False'can't name configs with underscores
	newconfigB.toggle = 1
	
	'list of configurations that are available for this ship
	configSList = New SList
	configSList.init(0, 0, 10, 10, True, 30)'we reinitialize this constantly, below, so no worries
	configSList.skipscrollbar = True
	
	'strip components button
	Local stripB:Button = New Button
	stripB.text = "Clear"
	stripB.wid = 154
	stripB.het = 30
	
	'revert config button
	'Local revertB:Button = New Button
	'revertB.text = "Revert"
	'revertB.wid = 76
	'revertB.het = 30
	
	'save config button
	'local saveB:Button = New Button
	'saveB.text = "Save Changes"
	'saveB.wid = 118
	'saveB.het = 30
	'saveB.x = SWIDTH - saveB.wid - 2
		
	'list of actual ships to modify
	Local modshipList:TList = New TList
	'corresponding scrolling list of buttons for each ship- will be in same order as above!
	Local shipSList:SList = New SList
	shipSList.init(6, 10+ImageHeight(hanger_tabs_gfx)+4, ImageWidth(hanger_tabs_gfx)-12, SHEIGHT-(10+ImageHeight(hanger_tabs_gfx)+16)-4, False)
	'grab ships from the pilot's fleetlist
	For Local s:Ship = EachIn pilot.fleetList
		modshipList.addLast(s)
		Local sb:Button = shipSList.add_button(s.name,0,0,s.gfx[0],25,10 + ImageHeight(s.gfx[0])/2)
		sb.text_y = -18
		sb.text_x = 20
		sb.toggle = 1'they're toggle buttons!
		sb.tab = True'also, can't unselect it
	Next
	'make a slave button to automatically switch over to component customization, only the selected ship has this as a child
	Local customizeB:Button = New Button
	customizeB.text = "Customize"
	customizeB.text_scale = 2
	customizeB.wid = 256
	customizeB.het = 60
	customizeB.x = SWIDTH/2 - customizeB.wid/2
	customizeB.y = SHEIGHT/2 + (cshapedim/2)*csize

	'list of actual components to add
	Local modcompList:TList = New TList
	'corresponding scrolling list of buttons for the components
	Local compSList:SList = New SList
	compSList.init(shipSList.x, shipSList.y, shipSList.wid, shipSList.het, shipSList.barside, 50)
	'grab components from the pilot's complist
	For Local c:Component = EachIn pilot.compList
		modcompList.addLast(c)
		Local nb:Button = compSList.add_button(c.name)
		nb.text_centered = False
		nb.text_x = 45
		nb.text_y = (-nb.het/2) + 15
	Next
	
	'make a list of components available to unlock
	Local unlock_compList:TList = New TList
	Local unlock_compSList:SList = New SList
	unlock_compSList.init(compSList.x, compSList.y, compSList.wid, compSList.het, compSList.barside, compSList.entryhet)
	For Local c:Component = EachIn componentList
		'if we haven't already unlocked it
		If Not pilot.alreadyhave_component(c.name)
			'if this component is available to unlock
			If c.unlockable And (Not c.special Or pilot.VIP)
				unlock_compList.addLast(c)
				Local nb:Button = unlock_compSList.add_button(c.name)
				nb.text_centered = False
				nb.text_x = 45
				nb.text_y = (-nb.het/2) + 15
			EndIf
		EndIf
	Next
	
	
	'------------------------------------------------------------------------------------------------------------------------------------
	'------------------------------------------------------------------MAIN HANGER LOOP--------------------------------------------------
	'------------------------------------------------------------------------------------------------------------------------------------
	
	'sidebar dimensions
	Local statwid = ImageWidth(hanger_infoaddon_gfx)
	Local stathet = 144
	Local texthet = TextHeight("BOBCAT")
	Local addonwid = 178
	Local addonhet = 86
	Local buttonspace = 2 + stripB.het + 2 + ImageHeight(boxseparator_gfx) + 2
	Local staty = 10
	Local addony = staty+ImageHeight(hanger_infoaddon_gfx)+stathet-4
	
	'amount of scrap to display
	'Local dispscrap = pilot.scrap
	'the current color of ship on display
	Local hangercolor = -1
	'has there been a change to a configuration?
	'Local changes = False
	'should we hide the current components?
	Local hidecomps = False
	'selected ship to modify
	Local selship:Ship, old_selship:Ship'(old used to detect changes, resets some important stuff when that happens)
	Local selship_gfx:TImage
	'selected component to add
	Local selcomp:Component
	'mouse button state information
	Local m,mc,mc2,mr,old_m
	Local m_dc, dc_delay = 100, dc_timer=dc_delay'double click timer
	oldTime = MilliSecs()
	timePass = 22'just so no tricky stuff at the initial loop
	Repeat
		WaitTimer(frameTimer)
		Cls
		SetColor 255,255,255
		
		updateTime()
		
		updateCursor()
		
		'mousedown information
		old_m = m
		m = MouseDown(1) Or (joyDetected And JoyDown(JOY_FIREPRIMARY))
		'mouseclick information
		If (old_m <> m) And (m = True) Then mc = True Else mc = False
		mc2 = MouseHit(2) Or (joyDetected And JoyHit(JOY_FIRESECONDARY))
		'mouserelease information
		If (old_m <> m) And (m = False) Then mr = True Else mr = False
		
		'double clicks
		If dc_timer > 0
			dc_timer:- frameTime
			If mc Then m_dc = True
		EndIf
		If mc Then dc_timer = dc_delay
		
		'draw the background
		SetRotation 0
		SetScale 1,1
		SetAlpha 1
		SetColor 16,16,35
		If unlockB.toggle = 2 Then SetColor 60,20,0
		TileImage grid_gfx
		
		'change the amount of scrap displayed to match reality
		'If dispscrap > pilot.scrap
		'	SetColor 255,120,120
		'ElseIf dispscrap < pilot.scrap
		'	SetColor 120,120,255
		'Else
		'	SetColor 255,255,255
		'EndIf
		'change scrap counter by a percentage
		'dispscrap = constrain(dispscrap -  Float(dispscrap - pilot.scrap)*frameTime/1000.0, pilot.scrap, dispscrap)
		
		'current amount of scrap available
		'SetScale 2,2
		'SetRotation 0
		'DrawText dispscrap+" scp.", ImageWidth(hanger_tabs_gfx) + 15 ,15
		
		'exitbox box
		SetScale 1,1
		SetColor 255,255,255
		SetAlpha 1
		SetRotation 0
		drawBorderedRect(testB.x-8,testB.y-8,SWIDTH-testB.wid-16,testB.het*2+18)
		SetColor 255,255,255
		DrawImage hanger_exitbox_gfx,testB.x-8,testB.y-30,0
		DrawImage hanger_exitbox_gfx,systB.x-8,systB.y+systB.het+6,1
		
		'TEST DRIVE BUTTON
		testB.update(m)
		testB.draw()
		If testB.pressed = 2 And selship <> Null
			selship.save_config()
			p1 = selship
			p1.reset()
			new_game("testdrive")
		EndIf
		
		'MISSION SELECT BUTTON
		systB.update(m)
		systB.draw()
		
		'save changes button
		'If changes Then saveB.active = True Else saveB.active = False'only can save changes if there's been changes
		'saveB.y = testB.y-32-saveB.het
		'saveB.update(m)
		'saveB.draw()
		'If saveB.pressed = 2
		'	selship.save_config()
		'	changes = False
		'EndIf
		
		'box for list of installed components, LOADOUT
		SetRotation 0
		SetScale 1,1
		SetAlpha 1
		SetColor 255,255,255
		addony = staty+ImageHeight(hanger_infoaddon_gfx)*2+stathet-4	'y of capping (middle) gfx
		
		'default to displaying the components in configuration
		hidecomps = False
		
		'--------------------------------------------------------------------------------------------  CURRENT SHIP  -------------------------
		If selship <> Null
		
			'DRAW THE SHIP BIG in the center of the screen
			SetColor 255,255,255
			SetAlpha 1
			If selship_gfx <> Null Then DrawImage selship_gfx,SWIDTH/2-1,SHEIGHT/2
			
			'draw the ship color schemes
			If (Lower(selship.config) <> "default" Or Lower(pilot.name) = "wik")'only if we can customize this ship
				Local cscheme = 0
				For Local schemeB:Button = EachIn cschemeBList
					schemeB.update(m)
					schemeB.draw()
					
					'if mouse-near the buttons, hide the current components
					If cursory >= schemeB.y And (Abs(cursorx - schemeB.x) < 30 Or Abs(cursorx - (schemeB.x + schemeB.wid)) < 30)
						hidecomps = True
					EndIf
					
					'if press button to change current color scheme
					If schemeB.pressed = 2 And selship.color <> cscheme
						'changes = True
						selship.scheme = cscheme
						'actually recolor the thing
						selship.recalc()
					EndIf
					cscheme:+1
				Next
			EndIf
			
			'figure out where to start drawing the topleft corner of component grid
			Local ox = SWIDTH/2 - (cshapedim/2)*csize - csize/2
			Local oy = SHEIGHT/2 - (cshapedim/2)*csize - csize/2
			
			'if we're currently editing components
			If compB.toggle = 2
				'draw the component grid
				SetScale 1,1
				
				'draw the grid
				Local MOptile[3]'0:the type of ptile | 1,2:x,y position of ptile
				If Not hidecomps
					For Local y = 0 To cshapedim-1
					For Local x = 0 To cshapedim-1
						'if this square is not unavailable
						If selship.cshape[x,y] <> 0
							SetAlpha 1
							
							Local tx = x*csize
							Local ty = y*csize
							
							'draw a border
							SetColor 64,64,64
							DrawRect ox+tx-2,oy+ty-2,csize+2,csize+2
							
							'is it a power tile color?
							Local rgb[3]
							rgb = getTileColor(String(MapValueForKey(psquareMap, String(Abs(selship.cshape[x,y])))))
							
							'dark colored border
							SetColor 32,32,32
							DrawRect ox+tx,oy+ty,csize-2,csize-2
							
							'normal tiles are just plain/with a 1px border
							If Abs(selship.cshape[x,y]) = 1
								'dark colored border
								SetColor rgb[0],rgb[1],rgb[2]
								DrawRect ox+tx+4,oy+ty+4,csize-8,csize-8
								
								'lighter center
								SetColor rgb[0]*2,rgb[1]*2,rgb[2]*2
								DrawRect ox+tx+4,oy+ty+4,csize-10,csize-10
							
							'power tiles are made of concentric circles 
							Else
								'lighter center box
								SetColor 64,64,64
								DrawRect ox+tx+2,oy+ty+2,csize-6,csize-6
							
								'concentric circles
								SetColor 32,32,32
								DrawOval ox+tx+1,oy+ty+1,csize-4,csize-4
								
								SetColor rgb[0],rgb[1],rgb[2]
								DrawOval ox+tx+3,oy+ty+3,csize-8,csize-8
								
								SetColor rgb[0]*2,rgb[1]*2,rgb[2]*2
								DrawOval ox+tx+7,oy+ty+7,csize-16,csize-16
								
								SetColor rgb[0],rgb[1],rgb[2]
								DrawOval ox+tx+13,oy+ty+13,csize-28,csize-28
								
								'mouseover?
								If cursorx > ox+tx And cursorx < ox+tx+csize And cursory > oy+ty And cursory < oy+ty+csize
									MOptile[0] = Abs(selship.cshape[x,y])
									MOptile[1] = ox+tx
									MOptile[2] = oy+ty
								EndIf
							EndIf
							
							
							'SetColor 255,255,255
							'DrawText x+","+y,ox+x*csize+2,oy+y*csize+2
							'DrawText selship.cshape[x,y],ox+x*csize+2,oy+y*csize+2
						EndIf
					Next
					Next
				EndIf
				
				'----------------------------------------------------------------------  draw/select current components  -------------------
				Local MOcomp:Component = Null'the currently mouseover'd component 
				For Local c:Component = EachIn selship.compList
					'is the mouse over this component?
					Local mouseover = False
					For Local cy = 0 To 4
					For Local cx = 0 To 4
						'adjust for rotation
						Local cr[2]
						cr = rotAdjust(cx,cy,c.rot)
						'component occupies this space?
						If c.shape[cx,cy] = 1
							If cursorx >= ox+(c.x+cr[0])*csize And cursorx < ox+(c.x+cr[0])*csize+csize
								If cursory >= oy+(c.y+cr[1])*csize And cursory < oy+(c.y+cr[1])*csize+csize
									mouseover = True
									MOcomp = c
								EndIf
							EndIf
						EndIf
					Next
					Next
					
					'pick up or delete the component
					If mouseover And (Not c.locked Or Lower(pilot.name) = "wik")
						'pick it up
						If mc
							selcomp = c
							ListRemove(selship.compList,c)
							'recalculate the shape data for the ship
							selship.cshape_recalc()
							mc = 0'lie! we've "used up" this release, so we don't just replace it
							'changes = True'we messed with stuff
						
						'just kill it
						ElseIf mc2 And selcomp = Null
							ListRemove(selship.compList,c)
							'recalculate the shape data for the ship
							selship.cshape_recalc()
							'changes = True'we messed with stuff
						EndIf	
					EndIf				
					
					'draw the component
					If Not hidecomps
						For Local cy = 0 To 4
						For Local cx = 0 To 4
							'adjust for rotation
							Local cr[2]
							cr = rotAdjust(cx,cy,c.rot)
							'component occupies this space?
							If c.shape[cx,cy] = 1
								'draw it (mouseover, plugged components are highlighted)
								Local cmod = 42*mouseover
								SetColor c.rgb[0]+cmod, c.rgb[1]+cmod, c.rgb[2]+cmod
								If Not c.plugged Then SetColor 168+cmod,128+cmod,128+cmod
								SetAlpha .8
								SetScale 1,1
								DrawRect ox+(c.x+cr[0])*csize+2,oy+(c.y+cr[1])*csize+2,csize-6,csize-6
								
							ElseIf c.shape[cx,cy] = 2'this is an attachment tile
								SetColor 128,128,64
								SetAlpha .7
								DrawRect ox+(c.x+cr[0])*csize+8, oy+(c.y+cr[1])*csize+8, csize-16, csize-16
								DrawRect ox+(c.x+cr[0])*csize+12, oy+(c.y+cr[1])*csize+12, csize-24, csize-24
							EndIf
						Next
						Next
					EndIf
				Next
				
				If Not hidecomps
					'make a tooltip for the mouseover'd component
					If MOcomp <> Null' And selcomp = Null
						drawTooltip(MOcomp, ox+(MOcomp.x*csize)+csize/2, oy+(MOcomp.y*csize))
					
					'make a tooltip for the mouseover'd power tile
					ElseIf MOptile[0] > 1
						Local tipwid = 170
						Local tiphet = 30
						Local ox = MOptile[1]+csize/2-tipwid/2
						Local oy = MOptile[2]-ImageHeight(boxpointer_gfx)-tiphet
						
						drawBorderedRect(ox,oy,tipwid,tiphet)
						SetColor 255,255,255
						DrawImage boxpointer_gfx, ox + tipwid/2, oy + tiphet
						
						Local tiletext$ = String(MapValueForKey(psquareMap, String(MOptile[0]))) + " power tile"
						
						draw_text(tiletext, ox+(tipwid-TextWidth(tiletext))/2, oy+8)
					EndIf
				EndIf
				
				
			EndIf
			
			'-- ATTACHMENT TILES --
			For Local c:Component = EachIn selship.compList
				ClearList(c.addonList)'clear any components that are added to this one, we'll re-add them in a second
			Next
			
			'see if this component is adjecent to any others of the same name, attach components to their parents
			For Local c:Component = EachIn selship.compList
				For Local cy = 0 To 4
				For Local cx = 0 To 4	
					'if this component has an attactment tile at this space
					If c.addon And c.shape[cx,cy] = 2
						'overlappers?
						For Local a:Component = EachIn selship.compList
						'if it's the right class, accepts addons, and is not an addon itself (heaven forbid!)
						If c.class = a.class And a.accepts_addons And Not a.addon
							For Local ay = 0 To 4
							For Local ax = 0 To 4
								'if THAT comp is occupying this space
								If a.shape[ax,ay] = 1
									'adjust for rotation
									Local cr[2],ar[2]
									cr = rotAdjust(cx,cy,c.rot)
									ar = rotAdjust(ax,ay,a.rot)
									'see if that component's square is on top of the attachement tile
									If (c.x+cr[0]) = (a.x+ar[0]) And (c.y+cr[1]) = (a.y+ar[1])
										a.addonList.addLast(c)'attach this component to this other component
									EndIf
								EndIf
							Next
							Next
						EndIf
						Next
					EndIf
				Next
				Next
			Next
			
			'for ALL components...
			For Local c:Component = EachIn selship.compList
				'check to see if it's plugged in to a degree it wishes
				c.plugged = False
				
				'engines are always plugged in
				If c.class = "engine"
					c.plugged = True
					
				'if we don't need no stinking power tiles
				ElseIf c.preq[0] = 0 And c.preq[1] = 0 And c.preq[2] = 0 And c.preq[3] = 0
					c.plugged = True
					
				'other things have to check for power tiles
				Else
					'go through all bits of the component to see if any of them are powered
					Local omni_count		'after everything else is checked, use omni tiles to fill remaining requirements
					Local ptile_count[4]	'number of each type of tile that this component needs
					ptile_count[0] = c.preq[0]
					ptile_count[1] = c.preq[1]
					ptile_count[2] = c.preq[2]
					ptile_count[3] = c.preq[3]
					For Local cy = 0 To 4
					For Local cx = 0 To 4
						If c.shape[cx,cy] = 1
							'adjust for rotation
							Local cr[2]
							cr = rotAdjust(cx,cy,c.rot)
							'is this square powered?
							If isWithin(c.x+cr[0], 0, cshapedim-1) And isWithin(c.y+cr[1], 0, cshapedim-1)
								'find the type of power tile at this location
								Local ptile$ = String(MapValueForKey(psquareMap, String(Abs(selship.cshape[c.x+cr[0],c.y+cr[1]]))))
								Local spent = False'whether we've spent this tile on filling a requirement yet

								'if we found a power tile
								If ptile <> ""
									'try and knock off a specific requirements first
									For Local i = 0 To 2
										'if we require some number of this type of tile
										If ptile_count[i] > 0
											If ptile = String(MapValueForKey(preqMap, String(i)))'does this ptile match the requirement?
												ptile_count[i]:- 1
												spent = True
											EndIf
										EndIf
									Next
									
									'see if we can't just use it for a flexible slot
									If Not spent
										If ptile_count[3] > 0
											ptile_count[3]:- 1
											spent = True
										EndIf
									EndIf
									
									'if all else fails, and this is an omni tile,
									'just record that we have one omni in the bank for when the dust settles
									If Not spent And ptile = "omni" Then omni_count:+ 1
								EndIf
							EndIf
						EndIf
					Next
					Next
					
					'check if we fulfilled requirements (also, spend omni tiles on any remaining ptile requirements)
					c.plugged = True
					For Local i = 0 To 3
						'spend remaining omni tiles
						If ptile_count[i] > 0 And omni_count > 0
							ptile_count[i]:- omni_count
							omni_count = -ptile_count[i]
						EndIf
						'if we still haven't met the quota
						If ptile_count[i] > 0 Then c.plugged = False
					Next
				EndIf
			Next
			
			'list of the contained components (second value is quantity of that component) (third value is TRUE/FALSE, whether to draw text red)
			tallyComponents(selShip)
			'see how many lines of components we got
			For Local i = 0 To 15
				If loadout[i,0] = ""
					addonhet = (i+1)*textHet
					Exit
				EndIf
			Next
			
			'ACTUAL box for loadout
			SetColor 255,255,255
			SetAlpha 1
			addonhet:+ buttonspace'make space for the two below buttons
			drawBorderedRect(SWIDTH-addonwid, addony-6, addonwid, addonhet+2)
			
			'clear and revert buttons
			stripB.x = SWIDTH - addonwid + 8
			stripB.y = addony + 2
			stripB.update(m)
			stripB.draw()
			If stripB.pressed = 2
				Local configName$ = selship.config	'preserve the current configuration name
				selship.load_config("null")			'but reset components to just the engines.
				selship.config = configName			'restore name
			EndIf
			
			'If revertB.active And changes = False Then revertB.active = False'can only revert if we're not already there
			'revertB.x = SWIDTH - revertB.wid - 8
			'revertB.y = addony + 2
			'revertB.update(m)
			'revertB.draw()
			'If revertB.pressed = 2
			'	changes = False'back to original
			'	selship.load_config(selship.config)
			'EndIf
			
			'draw a divider below them
			SetColor 255,255,255
			DrawImage boxseparator_gfx, SWIDTH - (addonwid/2), stripB.y + stripB.het + 5, 0
			
			addony:+ buttonspace
			
			'list of installed components
			For Local i = 0 To 15
				'update the button
				loadoutB[i].het = textHet
				loadoutB[i].wid = addonwid
				loadoutB[i].x = SWIDTH - addonwid
				loadoutB[i].y = addony + i*textHet
				loadoutB[i].update(m)
			
				If loadout[i,0] <> ""
					Local textx = SWIDTH - addonwid + 8
					Local texty = addony + i*textHet
					
					'is the mouse over it?
					If loadoutB[i].pressed < 5
						'draw a highlighted rectangle
						SetColor 64,64,128
						DrawRect textx-2,texty,addonwid-12,texthet
					EndIf
					
					'list the component
					If loadout[i,2] = "" Then SetColor 255,255,255 Else SetColor 208,105,100'red if there's power
					If loadout[i,1] = "1" Or loadout[i,1] = ""'if there's no quantity
						draw_text(loadout[i,0], textx, texty)
					Else
						draw_text(loadout[i,0] + " x"+loadout[i,1], textx, texty)
					EndIf
				EndIf
			Next
			
			'box for current stats
			drawBorderedRect(SWIDTH-statwid, staty+ImageHeight(hanger_infoaddon_gfx)-2, statwid, stathet)
			
			'draw the "current stats' box for the CURRENT SHIP
			SetRotation 0
			SetScale 1,1
			SetAlpha 1
			SetColor 255,255,255
			'top bar
			DrawImage hanger_infoaddon_gfx, SWIDTH-statwid, staty, 0
			'middle bar
			DrawImage hanger_infoaddon_gfx, SWIDTH-statwid, addony-ImageHeight(hanger_infoaddon_gfx)-buttonspace, 1
			'bottom bar
			DrawImage hanger_infoaddon_gfx, SWIDTH-statwid, addony-buttonspace+addonhet-6, 2
			
			'draw the CURRENT STATS
			draw_stats(selship, SWIDTH-statwid+10, staty+ImageHeight(hanger_infoaddon_gfx)+8)
		
			'CURRENTLY SELECTED COMPONENT
			If selcomp <> Null
			
				'draw the component under the mouse
				SetScale 1,1
				For Local cy = 0 To 4
				For Local cx = 0 To 4
					'adjust for rotation
					Local cr[2]
					cr = rotAdjust(cx,cy,selcomp.rot)
					If selcomp.shape[cx,cy] = 1
						SetAlpha .9
						SetColor selcomp.rgb[0],selcomp.rgb[1],selcomp.rgb[2]
						DrawRect cursorx+cr[0]*csize-csize/2+2,cursory+cr[1]*csize-csize/2+2,csize-4,csize-4
					ElseIf selcomp.shape[cx,cy] = 2
						SetAlpha .5
						SetColor 128,128,64
						DrawRect cursorx+cr[0]*csize-csize/2+2,cursory+cr[1]*csize-csize/2+2,csize-4,csize-4
					EndIf
				Next
				Next
				
				'rotate it
				If mc2 Then selcomp.rot = (selcomp.rot+1) Mod 4
				
				'release it onto an available set of squares
				If (mr) And cursorx > barwid				
					'find the tile we're trying to drop this component on
					Local dropx = -1
					Local dropy = -1
					For Local y = 0 To cshapedim-1
					For Local x = 0 To cshapedim-1
						'if over this square
						If cursorx >= ox+x*csize And cursorx < ox+x*csize+csize And cursory >= oy+y*csize And cursory < oy+y*csize+csize
							'attempt to drop the component here
							dropx = x
							dropy = y
							Exit
						EndIf
					Next
					Next
					
					'was it a valid drop spot?
					Local clear = True
					If dropx > -1 And dropy > -1
						'see if the requisite area is clear
						For Local cy = 0 To 4
						For Local cx = 0 To 4
							'adjust for rotation
							Local cr[2]
							cr = rotAdjust(cx,cy,selcomp.rot)
							'if the component takes up this square
							If selcomp.shape[cx,cy] = 1
								'is it within bounds?
								If dropx+cr[0] < cshapedim And dropx+cr[0] >= 0 And dropy+cr[1] < cshapedim And dropy+cr[1] >= 0
									'is the spot already filled?
									If selship.cshape[dropx+cr[0],dropy+cr[1]] <= 0
										clear = False
									EndIf
								Else
									clear = False
								EndIf
							EndIf
						Next
						Next
						
						'make sure that we're not adding too many alternate weapons
						If selcomp.alt
							Local altNum = 0
							For Local c:Component = EachIn selship.compList
								If c.alt Then altNum:+ 1
							Next
							If altNum >= 2
								clear = False
								confirm_menu("Look, no more than 2 alternate weapons may be placed, OK?")
							EndIf
						EndIf
						
						'this spot is OK!
						If clear
							'add the component
							selship.compList.addLast(selcomp)
							selcomp.x = dropx
							selcomp.y = dropy
							'recalculate the shape data for the ship
							selship.cshape_recalc()
							playSFX(compplace_sfx,-1,-1)
							'changes = True'we messed with stuff
								
						EndIf
					EndIf
					
					'refund the scrap if we didn't place it OK
					'If Not clear Or dropx = -1 Or dropy = -1 Then pilot.scrap:+ selcomp.scrapcost
					
					'if holding shift, be able to place another one
					If KeyDown(KEY_LSHIFT) Or KeyDown(KEY_RSHIFT) Then selcomp = new_comp(selcomp.name) Else selcomp = Null
				EndIf
			EndIf
			
			'recolor the button, big graphic
			If hangercolor <> selship.color
				're-get the big graphic to display
				Local scale = Floor(Min(selshipscale * ImageHeight(selship.gfx[0]), SHEIGHT-200) / ImageHeight(selship.gfx[0]))
				selship_gfx = resizeImage(selship.gfx[0],scale)
				
				'give the correct button a new graphic
				Local i = 0
				For Local s:Ship = EachIn modShipList
					If s = selship Then Exit
					i:+ 1
				Next
				Local j = 0
				For Local b:Button = EachIn shipSList.entryList
					If j = i
						b.gfx = selship.gfx[0]
						Exit
					EndIf
					j:+1
				Next
				
				'record that we recolored it
				hangercolor = selship.color
			EndIf
			
		EndIf
		
		'background, bottom for the ship,component lists
		SetScale 1,1
		SetAlpha 1
		drawBorderedRect(0,10+ImageHeight(hanger_tabs_gfx)-2,ImageWidth(hanger_tabs_gfx),SHEIGHT-ImageHeight(hanger_tabs_gfx)-13)
		SetColor 255,255,255
		DrawImage hanger_tabs_gfx,0,SHEIGHT-16,2
		
		'--------------------------------------------------------------------------------------------------- SHIP LIST ---------------------------
		shipB.update(m)
		shipB.draw()
		If compB.toggle = 1 And shipB.toggle = 1 Then shipB.toggle = 2	'can't just untoggle this button
		If shipB.toggle = 2
			'reset other button
			compB.toggle = 1
			unlockB.toggle = 1
			
			'draw the correct tab frame
			SetColor 255,255,255
			SetScale 1,1
			SetAlpha 1
			DrawImage hanger_tabs_gfx,0,10,0
			
			'update & draw the customize button
			If selship <> Null And (Lower(selship.config) <> "default" Or Lower(pilot.name) = "wik")
				customizeB.update(m)
				customizeB.draw()
			EndIf

			'update & draw the SHIP SList
			shipSList.update(m)
			
			'select which ship to modify
			Local i = 0
			For Local b:Button = EachIn shipSList.entryList
				'default to grey unless selected
				If b.toggle = 1 Then b.RGB = getSquadColor(0) Else b.RGB = getSquadColor(1)
				
				'find the corresponding ship
				Local j = 0, bship:Ship
				For Local s:Ship = EachIn modshipList
					If j = i
						bship = s
						Exit
					EndIf
					j:+ 1
				Next
				
				'also draw the configuration name on the button
				SetViewport 0,shipSList.y,SWIDTH,shipSList.het
					SetColor b.text_RGB[0], b.text_RGB[1], b.text_RGB[2]
					If b.toggle = 2 Then SetColor 160,105,50'if this button is active, configuration name is colored
					Local conftext$ = " - " + bship.config + " - "
					Local addtextx = b.x + b.wid/2 + b.text_x - TextWidth(conftext)/2
					draw_text(conftext, addtextx, b.y + b.het/2 + b.text_y + 20)
				SetViewport 0,0,SWIDTH,SHEIGHT
				
				'if no ship is selected, fucking select this one!
				If selship = Null Then b.pressed = 2
				
				'if we selected this ship by clicking it (or if we need to just grab the first selected ship)
				If b.pressed = 2
					
					'toggle this button
					b.toggle = 2
					
					'untoggle all other buttons
					For Local o:Button = EachIn shipSList.entryList
						If b <> o And o.toggle = 2
							o.toggle = 1
							o.child = Null
						EndIf
					Next
					
					'we do this when we detect a selected ship change now
					'buildConfigSList(bship.name)
					'ClearList(configSList.entryList)
					
					'select this button's ship
					selship = bship
						
				EndIf
				
				'draw the list of configurations for this ship
				If b.toggle = 2'if this is the selected ship
					Local ox = b.x+b.wid+8
					Local oy = b.y
					Local wid = ImageWidth(boxseparator_gfx)+8
					Local het = 6+textHet+10+configSList.het+10+newconfigB.het+8
					
					'box & pointer
					drawBorderedRect(ox,oy,wid,het)
					SetColor 255,255,255
					SetRotation 90
					DrawImage boxpointer_gfx, ox+2, oy+27
					SetRotation 0
					
					'header label & divider
					draw_text("Configuration List:",ox+16,oy+8)
					DrawImage boxseparator_gfx, ox+wid/2, oy+6+textHet+2+ImageHeight(boxseparator_gfx)/2, 0
					
					'list of configurations
					For Local conf:Button = EachIn configSList.entryList
						'the selected configuration is colored
						If Lower(conf.text) = Lower(selship.config)
							conf.text_RGB[0] = 180
							conf.text_RGB[1] = 125
							conf.text_RGB[2] = 70
							conf.RGB[0] = 75
							conf.RGB[1] = 80
							conf.RGB[2] = 160
						Else'every else is default-colored
							conf.text_RGB[0] = 0
							conf.text_RGB[1] = 0
							conf.text_RGB[2] = 0
							conf.RGB[0] = 0
							conf.RGB[1] = 0
							conf.RGB[2] = 0
						EndIf
						
						'load one of the configurations
						If conf.pressed = 2
							selship.load_config(conf.text)
							'changes = False
							
							'if we double-clicked it, then switch to editing
							'If m_dc
							'	shipB.toggle = 1
							'	compB.toggle = 2
							'EndIf
						EndIf
						
						'press the delete button for this config
						If conf.child.pressed = 2
							ListRemove(configSList.entryList,conf)
							DeleteFile("configs/"+selship.name+"_"+conf.text+"_"+Lower(pilot.name)+".conf")
							selship.load_config("default")
							'changes = False
						'mouseover the button
						ElseIf conf.child.pressed < 5
							SetColor 255,255,255
							draw_text("[delete configuration]", conf.x+conf.child.x+conf.child.wid+12, conf.y+6)
						EndIf
					Next
					configSList.x = ox+12
					configSList.y = oy+32
					configSList.het = CountList(configSList.entryList)*configSList.entryHet
					configSList.wid = wid - 12 - 32
					configSList.update(m)
					
					'footer divider & new config button
					SetColor 255,255,255
					DrawImage boxseparator_gfx, ox+wid/2, configSList.y+configSList.het+2+ImageHeight(boxseparator_gfx)/2, 1
					'make it yellow
					newconfigB.RGB[0]	 = 104
					newconfigB.RGB[1]	 = 94
					newconfigB.RGB[2]	 = 50
					'when the button has been typed in then deselected, make a new config
					If newconfigB.toggle = 1
						If (valid_config_name(newconfigB.text) Or Lower(pilot.name) = "wik") And newconfigB.text <> "New Config"
							selship.load_config("null")
							selship.config = newconfigB.text
							selship.save_config()'save this new configuration
							buildConfigSList(selship.name)
						EndIf
					EndIf
					'when the button's not clicked, set the text to what it does
					If newconfigB.toggle = 1 Then newconfigB.text = "New Config"
					'when it is initially clicked, come up with an automatic name for the configuration
					Local nextname
					If newconfigB.toggle = 2 And newconfigB.text = "New Config"
						'see what custom number we're on
						Local i, defaultname$ = "custom "
						Repeat
							i:+ 1
							nextname = False
							For Local cb:Button = EachIn configSList.entryList
								'does this custom number already exist?
								If cb.text = defaultname + i
									nextname = True
									Exit'get the next custom number
								EndIf
							Next
						Until Not nextname
						newconfigB.text = defaultname + i
					EndIf
					'tell them to type when they've pressed the button
					If newconfigB.toggle = 2 
						If globalFrame Then SetColor 255,255,255 Else SetColor 128,128,128
						draw_text("[name configuration]", newconfigB.x+newconfigB.wid+12, newconfigB.y+6)
					Else
						'make the customize button flash if there's only one configuration
						If globalFrame And CountList(configSList.entryList) = 1
							newconfigB.RGB[0] = 128
							newconfigB.RGB[1] = 128
							newconfigB.RGB[2] = 128
						EndIf
					EndIf
					newconfigB.wid = wid - 24
					newconfigB.het = 30
					newconfigB.x = ox+12
					newconfigB.y = oy + het - 8 - newconfigB.het
					newconfigB.update(m)
					newconfigB.draw()
				EndIf
				
				
				i:+ 1
			Next
		EndIf
		
		'if the selected ship changed
		If selship <> old_selship And selship <> Null
			'make sure the button is toggled
			Local j = 0
			For Local s:Ship = EachIn modshipList
				If s = selship Then Exit
				j:+ 1
			Next
			Local i = 0
			For Local b:Button = EachIn shipSList.entryList
				If i = j Then b.toggle = 2
				If i >= CountList(modshipList) Then Exit
				i:+ 1
			Next
		
			'make the ship's image to edit
			Local scale = Floor(Min(selshipscale * ImageHeight(selship.gfx[0]), SHEIGHT-200) / ImageHeight(selship.gfx[0]))
			selship_gfx = resizeImage(selship.gfx[0],scale)
			'resize the component squares
			csize = cshaperatio*scale
			
			'save the old one's configuration
			If old_selship <> Null Then old_selship.save_config()
			
			'build the list of possible configurations
			buildConfigSList(selship.name)
		EndIf
		old_selship = selship
		
		'--------------------------------------------------------------------------------------------------- COMPONENT LIST -------------------
		If selship <> Null And (Lower(selship.config) <> "default" Or Lower(pilot.name) = "wik") Then compB.active = True Else compB.active = False
		compB.update(m)
		compB.draw()
		If shipB.toggle = 1 And compB.toggle = 1 Then compB.toggle = 2	'can't just untoggle this button
		If compB.toggle = 2
			'reset other button
			shipB.toggle = 1
			'draw the correct tab frame
			SetColor 255,255,255
			SetScale 1,1
			SetAlpha 1
			DrawImage hanger_tabs_gfx,0,10,1
			
			'draw the return-to-shiplist button
			returnB.update(m)
			returnB.draw()
			If returnB.pressed = 2 Then compB.toggle = 1
			
			'If pilot.hangerHelp Then helpB.toggle = 2
			
			'draw the how-to button
			If pilot.hangerHelp
				'flash it
				If globalFrame
					helpB.RGB[0] = 128
					helpB.RGB[1] = 128
					helpB.RGB[2] = 128
				Else
					helpB.RGB[0] = 0
					helpB.RGB[1] = 0
					helpB.RGB[2] = 0
				EndIf
			EndIf
			helpB.update(m)
			helpB.draw()
			
			'if help is displayed
			If helpB.toggle = 2
				'flash the button to turn it back off
				If globalFrame
					closeB.RGB[0] = 128
					closeB.RGB[1] = 128
					closeB.RGB[2] = 128
				Else
					closeB.RGB[0] = 0
					closeB.RGB[1] = 0
					closeB.RGB[2] = 0
				EndIf
				
				closeB.update(m)
				closeB.draw()
				If closeB.pressed = 2 Then helpB.toggle = 1
				
				'label the help screen
				SetAlpha 1
				SetRotation 0
				SetScale 3,3
				SetColor 255,255,255
				draw_text("HOW-TO:", SWIDTH/2 - TextWidth("HOW-TO")*1.5, SHEIGHT/2 - ImageHeight(hangerhelp_gfx)/2 - texthet*3 - 4)
				'draw the help screen
				SetScale 1,1
				DrawImage hangerhelp_gfx,SWIDTH/2,SHEIGHT/2
				
				'don't flash the help button anymore
				pilot.hangerHelp = False
			EndIf
			
			'draw the "unlock components" button
			unlockB.RGB[0] = 0
			unlockB.RGB[1] = 0
			unlockB.RGB[2] = 0
			If unlockB.toggle = 2 And globalFrame'flash it to turn it back off
				unlockB.RGB[0] = 128
				unlockB.RGB[1] = 128
				unlockB.RGB[2] = 128
			EndIf
			unlockB.update(m)
			unlockB.draw()
			
			Local updateSList:SList'current or unlockable component list to display
			If unlockB.toggle = 2 Then updateSList = unlock_compSlist Else updateSList = compSlist
			
			'update & draw the whatever COMPONENT SList is active
			updateSList.update(m)
			'for all components in that list...
			Local i = 0
			For Local b:Button = EachIn updateSList.entryList
			
				'find the corresponding component
				Local j = 0, bcomp:Component
				Local cList:TList'current or unlockable actual components
				If unlockB.toggle = 2 Then cList = unlock_compList Else cList = modcompList
				For Local c:Component = EachIn cList
					If j = i
						bcomp = c
						Exit
					EndIf
					j:+ 1
				Next
				
				'mouseover
				If b.pressed < 5
					Local ox = b.x+b.wid+8
					Local oy = b.y
					
					'box & pointer
					drawTooltip(bcomp, ox, oy, False)
					SetColor 255,255,255
					SetRotation 90
					DrawImage boxpointer_gfx, ox+2, oy+27
					SetRotation 0
				EndIf
				
				'additional component information
				SetViewport 0,compSList.y,SWIDTH,compSList.het
				
					'draw the shape & color of the component on the button
					SetColor bcomp.rgb[0],bcomp.rgb[1],bcomp.rgb[2]
					For Local y = 0 To 4
					For Local x = 0 To 4
						If bcomp.shape[x,y] = 1 Then DrawRect b.x+13+x*8, b.y+10+y*8, 7, 7 
					Next
					Next
					
					'draw another divider
					SetColor 13,11,27
					DrawRect b.x+47,b.y+8,2,b.het-16
					
					Local ox = b.x+102
					Local oy = b.y+27
					
					'draw (if applicable) any power tile requirements of the component
					draw_preqs(bcomp, ox, oy, False, (Not b.active))
					
					If b.active Then SetColor 192,192,192 Else SetColor 64,64,64
					
					'draw the class of component
					Local class$ = bcomp.class
					If bcomp.addon Then class = class + " addon"
					ox = b.x + b.wid - 8 - TextWidth("- "+class+" -")
					draw_text("- "+class+" -", ox, oy)
					
					'draw the cost to unlock (if in that mode)
					If unlockB.toggle = 2
						ox = b.x + b.wid
						If b.active Then SetColor 192,192,192 Else SetColor 192,64,64
						draw_text(bcomp.cost, ox - 27 - TextWidth(bcomp.cost), oy - texthet - 3)
						SetColor 255,255,255
						DrawImage(point1_gfx[0], ox - 16, oy - texthet + 4)
					EndIf
				SetViewport 0,0,SWIDTH,SHEIGHT
				
			
				
				'if we're in "unlock components" mode
				If unlockB.toggle = 2
					unlockB.text = "[ Done Unlocking ]"
					
					'display current number of points
					SetScale 2,2
					draw_text(pilot.points, 264, 46)
					SetScale 1,1
					DrawImage bigpoint_gfx, 285 + TextWidth(pilot.points)*2, 55
					
					'if we have enough points for it
					If pilot.points >= bcomp.cost
						b.active = True'available to unlock
					
						'try to unlock this component
						If b.pressed = 2 
							If pilot.unlock_component(bcomp.name, False)'if we successfully unlock
								'pay for it
								pilot.points:- bcomp.cost
								'kaching!
								playSFX(unlock_sfx,-1,-1)
								
								'add it to the list of available components to place
								modcompList.addLast(bcomp)
								Local nb:Button = compSList.add_button(bcomp.name)
								nb.text_centered = False
								nb.text_x = 45
								nb.text_y = (-nb.het/2) + 15
								
								'save the pilot
								pilot.save()
							EndIf
						EndIf
					Else'if we don't have enough points for it
						b.active = False'unavailable to unlock
					EndIf
					
				'if we're working with components we have
				Else
					unlockB.text = "Unlock Components"

					'select the component
					If b.pressed = 2 Then selcomp = new_comp(bcomp.name)
				EndIf
				
				i:+ 1
			Next
			
			'remove all unlocked components from the unlockable list
			For Local unlockedcomp:Component = EachIn unlock_compList
				If pilot.alreadyhave_component(unlockedcomp.name)'if we've unlocked this component
					'remove it from the unlock lists
					For Local b:Button = EachIn unlock_compSList.entryList
						If b.text = unlockedcomp.name Then ListRemove(unlock_compSList.entryList, b)'the button
					Next
					ListRemove(unlock_compList, unlockedcomp)'the component itself
				EndIf
			Next
					
			'give instructions
			SetColor 255,255,255
			If selcomp <> Null
				If globalFrame Then SetColor 128,128,128
				draw_text("RIGHT CLICK : rotate piece", 262,SHEIGHT-20-textHet)
				draw_text("SHIFT CLICK : place multiple", 262,SHEIGHT-20)
			Else
				draw_text("RIGHT CLICK : delete piece", 262,SHEIGHT-20)
			EndIf
			
			'activate the strip & revert buttons
			stripB.active = True
			'revertB.active = True
		Else	'these two buttons are deactivated
			stripB.active = False
			'revertB.active = False
		EndIf
		
		'make the customize button flash
		If globalFrame
			customizeB.RGB[0] = 110
			customizeB.RGB[1] = 25
			customizeB.RGB[2] = 25
		Else
			customizeB.RGB[0] = 128
			customizeB.RGB[1] = 128
			customizeB.RGB[2] = 128
		EndIf
		'was the customize button pressed?
		If customizeB.pressed = 2
			compB.toggle = 2
			shipB.toggle = 1
			customizeB.pressed = 5'un-press the customize button
		EndIf
		
		If current_music <> theme_music Then new_music = theme_music
		updateMusic()
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		draw_cursor()
		Flip
	Until KeyHit(KEY_ESCAPE) Or systB.pressed = 2
	
	'save the current configuration
	If selship <> Null Then selship.save_config()
EndFunction

'build the SList of configurations possible to load for this ship
Function buildConfigSList(_shipname$)'alters configSList, a global SList
	If _shipname <> ""
		ClearList(configSList.entryList)
		'get a list of all the configuration names
		Local configFiles$[] = LoadDir("configs\")
		'go through each and get the name of the configuration
		For Local con$ = EachIn configFiles
			'if this configuration file is for this ship
			If Left(con,Len(_shipname)) = _shipname
				'if this configuration is available for this profile
				If configAvailable(con, _shipname, pilot)
					Local conName$ = con
					conName = Right(conName,Len(conName)-Len(_shipname)-1)			'trim the name of the ship
					conName = Left(conName,Len(conName)-5)						'trim the ".conf"
					If Right(conName, Len(pilot.name) + 1) = "_"+Lower(pilot.name)
						conName = Left(conName, Len(conName) - (Len(pilot.name) + 1))	'trim the CURRENT pilot's name
					EndIf
					'add it to the SList
					Local nb:Button = configSList.add_button(conName,0,0,Null,0,0, 0)'the the START of the list!
					'make the delete button for this entry
					Local cb:Button = New Button
					cb.het = nb.het
					cb.wid = nb.het
					cb.x = nb.wid + 2'these are offset from the main button
					cb.y = 0'-2+nb.het/4
					cb.text = "X"
					cb.RGB[0] = 192
					cb.RGB[1] = 92
					cb.RGB[2] = 92
					'cb.skipborder = True
					'can't delete default
					If Lower(conName) = "default" Then cb.active = False
					'set this as the child button of the configuration
					nb.child = cb
				EndIf
			EndIf
		Next
	EndIf
EndFunction

'is the configuration (full name, eg, "lamjet_default.conf") available to the given profile and ship
Function configAvailable(_config$, _shipname$, _profile:Profile = Null)
	If _profile = Null Then _profile = pilot
	
	'Print "checking if "+_shipname+": '"+_config+"' is available for "+_profile.name
	
	'first check to see that this config either is FOR this pilot or doesn't have two underscores (AKA global)
	Local conName$ = _config
	conName = Right(conName,Len(conName)-Len(_shipname)-1)			'trim the name of the ship (plus first underscore)
	conName = Left(conName,Len(conName)-5)						'trim the ".conf"
	'is there an underscore? (if not, it's a global config)
	If Instr(conName,"_")
		'is it for this pilot?
		If Right(conName, Len(_profile.name) + 1) = ("_"+Lower(_profile.name))
			'cause not that ^ doesn't friggin work (parenthesis woes?)
		Else
			Return False'it's for some other pilot
		EndIf
	
	Else'global config, restrict access to arcade configs
		If (Lower(conName) = "arcade" And Lower(_profile.name) <> "wik") Then Return False
	EndIf
	

	'build a list of components needed for this configuration
	Local compReqList:TList = New TList

	'load from file
	Local cFile:TStream = ReadFile("configs/"+_config)
	If cFile
		'LOAD CONFIGURATION
		'load the color
		Local color = ReadByte(cFile)
		While Not Eof(cFile)
			'make the new component
			Local ac:Component = New Component
			ac.loadSelf(cFile)
			compReqList.addLast(ac)
		Wend
		CloseFile cFile
	EndIf
	
	'go through the list of required components and see if they're all unlocked
	For Local c:Component = EachIn compReqList
		If c.class = "engine" Then Continue'don't need to have engines
		Local havethiscomp = False
		For Local have:Component = EachIn _profile.compList
			If have.name = c.name
				havethiscomp = True
				Exit
			EndIf
		Next
		'If Not havethiscomp Then Print "don't have " + c.name+" for "+ _config
		If Not havethiscomp Then Return False'if we don't have it yet, say so!
	Next
	
	'if we made it this far, we're good
	Return True
EndFunction

'draw the power tile requirements for a component somewhere
Function draw_preqs(_comp:Component, _x, _y, _flash = False, _grey = False)
	'does this component even HAVE any power requirements?
	Local req = False
	For Local i = 0 To 3
		If _comp.preq[i] > 0 Then req = True
	Next

	'draw 'em
	If req
		If _flash And globalFrame Then SetColor 255,64,64 Else SetColor 192,192,192
		If _grey Then SetColor 64,64,64
		draw_text("Req:",_x-TextWidth("Req:"),_y)
		Local tnum = 0
		_x:+2
		'_y:+2
		For Local i = 0 To 3
			Local rgb[3]
			rgb = getTileColor( String(MapValueForKey(preqMap, String(i))) )
			'draw however many of this type of tile the component needs
			For Local p = 1 To _comp.preq[i]
				'grey border
				SetColor 32,32,32
				DrawOval _x+(tnum*18)-1,_y-1,15,15
				SetColor 64,64,64
				DrawOval _x+(tnum*18),_y,13,13
				'concentric circles
				SetColor rgb[0],rgb[1],rgb[2]
				DrawOval _x+(tnum*18)+1,_y+1,11,11
				SetColor rgb[0]*2,rgb[1]*2,rgb[2]*2
				DrawOval _x+(tnum*18)+3,_y+3,7,7
				SetColor rgb[0],rgb[1],rgb[2]
				DrawOval _x+(tnum*18)+5,_y+5,3,3
				tnum:+ 1
			Next
		Next
	EndIf
EndFunction

Function draw_stats(_ship:Ship, _x, _y)
	SetColor 255,255,255
	SetAlpha 1
	SetRotation 0
	SetScale 1,1
	Local statwid = ImageWidth(hanger_infoaddon_gfx)
	Local labelx = _x
	Local labely = _y
	Local datumx = _x + statwid - 36
	Local texthet = TextHeight("BOBCAT")
	_ship.recalc()
	SetColor 255,255,255
	For Local i = 0 To 6
		Local label$,datum$
		Select i
		Case 0'name, configuration
			label = _ship.name
			datum = _ship.config
			SetColor 160,105,50
		Case 1'separator
			DrawImage boxseparator_gfx, _x+statwid/2-8, labely+texthet/2-2
			labely:- 2
		'Case 2'mass				'this is a video game not a physics class
		'	label = "Mass:"
		'	datum = Int(_ship.mass)+"k"
		Case 2'armour
			label = "Armour:"
			datum = Int(_ship.armourMax) + Chr(34)
		Case 3'max speed
			label = "Max Speed:"
			datum = Int(_ship.speedMax)+" m/s"
		Case 4'afterburner
			label = "Afterburner:"
			datum = Int(_ship.juiceMax)+" sec"
		Case 5'special ability
			label = "Ability:"
			datum = String(MapValueForKey(abilityMap, String(_ship.base.ability))) + " x" + _ship.pointMax
		Case 6'class of ship
			Local class$
			If _ship.turnRate = -1
				SetColor 110,110,80
				class = "- Fighter Class -"
			Else
				SetColor 120,60,70
				class = "- Gunship Class -"
			EndIf
			draw_text(class, _x + statwid/2 - TextWidth(class)/2 - 8, labely+4)
		EndSelect
		
		datumx = _x + statwid - 20 - TextWidth(datum)
		
		'draw the data
		If datum <> "" Then draw_text(datum, datumx, labely)
		'draw the label
		SetColor 255,255,255
		If label <> "" Then draw_text(label, labelx, labely)
		
		labely:+ texthet-1
	Next
EndFunction

'draws a box with the details of the mouseover'd component, with _x, _y = [its pointer origin] -OR- [topleft corner if _pointer=FALSE]
Function drawTooltip(_comp:Component, _x, _y, _pointer = True)'when pointer = False, you can draw your own damn arrow
	SetColor 255,255,255
	SetRotation 0
	SetScale 1,1
	SetAlpha .8
	
	Local wid = 220
	
	'figure out how many lines this tooltip is gonna be
	Local line$[32,2]'line | label/data
	Local lnum
	
	'first line is the name
	line[0,0] = _comp.name
	lnum:+ 1
	
	'next couple of lines are the description
	Local descript$[32]
	descript = parseText(_comp.desc, wid - 16)
	While descript[lnum-1] <> ""
		line[lnum,0] = descript[lnum-1]
		line[lnum,1] = "desc"'just telling the parser that this is a description line
		lnum:+ 1
	Wend
	
	'is it a gun?
	If Not ListIsEmpty(_comp.gunList)
		For Local g:Gun = EachIn _comp.gunList
			'get any addon bonuses
			Local add_damage,add_burst,add_recycle
			For Local add:Component = EachIn _comp.addonList
				add_damage:+ add.damageBonus
				add_burst:+ add.burstBonus
				add_recycle:+ add.recycleBonus
			Next
		
			'alternate/primary weapon
			If _comp.alt Then line[lnum,0] = "- Alternate -" Else line[lnum,0] = "-  Primary  -"
			line[lnum,1] = "alt"
			lnum:+ 1
			'gun type
			line[lnum,0] = " - " + String(MapValueForKey(firemodeMap, String(Abs(g.mode))))
			lnum:+ 1
			'gun damage
			If g.shotdamage > 0
				line[lnum,0] = " - Damage:"
				line[lnum,1] = Left(String(g.shotdamage+add_damage),3)+Chr(34)
				lnum:+ 1
			EndIf
			'gun recycle time
			If g.fireDelay > 0
				line[lnum,0] = " - Recycle Time:"
				line[lnum,1] = Left(String((g.fireDelay+add_recycle)/1000),4)+" sec"
				lnum:+ 1
			EndIf
			'gun range
			If g.shotrange > 0
				line[lnum,0] = " - Range:"
				line[lnum,1] = Int(g.shotrange)+" m"
				lnum:+ 1
			EndIf
			'burst
			If g.burstNum > 0
				line[lnum,0] = " - Burst:"
				line[lnum,1] = (g.burstNum+add_burst)
				lnum:+ 1
			EndIf
			'ammo
			If g.clipNum > 0
				line[lnum,0] = " - Ammo:"
				line[lnum,1] = g.clipNum+"/clip"
				lnum:+ 1
			EndIf
			Exit
		Next
	EndIf
	
	'damage bonus
	If _comp.damageBonus <> 0
		line[lnum,0] = "Damage Bonus:"
		line[lnum,1] = "+"+Int(_comp.damageBonus)+Chr(34)
		lnum:+ 1
	EndIf
	'burst bonus
	If _comp.burstBonus <> 0
		line[lnum,0] = "Burst Bonus:"
		line[lnum,1] = "+"+Int(_comp.burstBonus)
		lnum:+ 1
	EndIf
	'shot speed bonus
	If _comp.shotspeedBonus <> 0
		line[lnum,0] = "Shot Speed Bonus:"
		line[lnum,1] = "+"+Int(_comp.shotspeedBonus)
		lnum:+ 1
	EndIf
	'recycle bonus
	If _comp.recycleBonus <> 0
		line[lnum,0] = "Recycle Bonus:"
		line[lnum,1] = Int(_comp.recycleBonus)+Chr(34)
		lnum:+ 1
	EndIf
	'fortification bonus
	If _comp.fortify <> 0
		line[lnum,0] = "Fortification:"
		line[lnum,1] = "-"+Left(String(_comp.fortify),3)+Chr(34)
		lnum:+ 1
		line[lnum,0] = "          Arc:"
		line[lnum,1] = Int(_comp.fortify_range)+" deg"
		lnum:+ 1
		If _comp.fortify_offset <> 0
			line[lnum,0] = "       Offset:"
			line[lnum,1] = Int(convert_to_relative(_comp.fortify_offset,0)+" deg")
			lnum:+ 1
		EndIf
		If _comp.fortify_ramming
			line[lnum,0] = "  - Collisions Only -"
			lnum:+ 1
		EndIf
	EndIf
	'thrust bonus
	If _comp.thrustBonus <> 0
		line[lnum,0] = "Thrust Bonus:"
		line[lnum,1] = "+"+Left(String(_comp.thrustBonus),3)
		lnum:+ 1
	EndIf
	'engine bonus
	If _comp.engineBonus <> 0
		line[lnum,0] = "Speed Bonus:"
		line[lnum,1] = "+"+Left(String(_comp.engineBonus),3)+" m/s"
		lnum:+ 1
	EndIf
	'juice bonus
	If _comp.juiceBonus <> 0
		line[lnum,0] = "Afterburner:"
		line[lnum,1] = "+"+Left(String(_comp.juiceBonus),3)+" sec"
		lnum:+ 1
	EndIf
	'ability point bonus
	If _comp.pointBonus <> 0
		line[lnum,0] = "Ability Bonus:"
		line[lnum,1] = "+"+_comp.pointBonus+" use"
		lnum:+ 1
	EndIf
	'added mass
	If _comp.mass <> 0
		line[lnum,0] = "Mass:"
		line[lnum,1] = "+"+Int(_comp.mass)+"k"
		lnum:+ 1
	EndIf
	If Not _comp.accepts_addons Then line[lnum,0] = "- Does not accept addons -"
	lnum:+ 1
	'does this component have any power requirements?
	Local req = False
	For Local i = 0 To 3
		If _comp.preq[i] > 0
			req = True
			line[lnum,0] = "preq"'just telling the parser to draw preqs on this line
			lnum:+ 1
			Exit
		EndIf
	Next
	'is the thing powered?
	If Not _comp.plugged
		line[lnum,0] = "      - Unpowered! - "
		lnum:+ 1
	EndIf

	Local textHet = TextHeight("BOBCAT")
	
	Local het = (lnum+1)*textHet
	Local ox = _x
	Local oy = _y
	
	'if we're drawing the pointer, position things as such
	If _pointer
		ox:- (wid/2)
		oy:- (ImageHeight(boxpointer_gfx)+het)
	EndIf
	
	'keep it onscreen
	If oy < 0 Then oy = 0
	If oy + het > SHEIGHT Then oy:- (oy+het - SHEIGHT)
	
	drawBorderedRect(ox,oy,wid,het)
	SetColor 255,255,255
	If _pointer Then DrawImage boxpointer_gfx, _x, _y-ImageHeight(boxpointer_gfx)
	
	SetAlpha 1
	For Local i = 0 To (lnum-1)
		SetColor 255,255,255
		
		'the last line is red if the component is unpowered
		If Not _comp.plugged And i = (lnum - 1) Then SetColor 208,105,100
		
		'preq line gets special consideration
		If line[i,0] = "preq"
			draw_preqs(_comp, ox + 40, oy + 8 + i*textHet, (Not _comp.plugged))
			Continue
		EndIf
		
		'primary/secondary weapon text is centered & colored
		If line[i,1] = "alt"
			SetColor 228,190,190
			draw_text(line[i,0], ox + wid/2 - TextWidth(line[i,0])/2, oy + 8 + i*textHet)
			Continue
		EndIf
		
		'description lines get kinda shafted
		If line[i,1] = "desc"
			line[i,1] = ""'don't draw this
			SetColor 168,168,168
		EndIf
		
		'label
		draw_text(line[i,0], ox + 8, oy + 8 + i*textHet)
		'data
		draw_text(line[i,1], ox + 142, oy + 8 + i*textHet)
	Next
		
EndFunction

'tallies up the components of the inputted ship and returns an array of strings: [line, (name$ | quantity | unpowered TRUE/FALSE)]
'have to give it an array of buttons to see if we're mouseovering any particular item
'!CHEAT!: does not actually return the loadout. loadout[] has gone fucking GLOBAL!!! (also uses a global array of buttons)
'_tooltips: 0=don't draw | 1=draw at component position, AKA hangermode | 2=draw at provided list position
Function tallyComponents(_ship:Ship, _tooltips = 1, _ox=0, _oy=0)
	'clear the old list
	For Local i = 0 To 15
		loadout[i,0] = ""
		loadout[i,1] = ""
		loadout[i,2] = ""
	Next
	
	'tally up the new list
	Local tooltipped = False'only draw tooltip for single component at a time
	For Local c:Component = EachIn _ship.compList
		'if this is a component we tally up
		If c.class <> "engine" And Not c.addon
			'tally it up for the loadout
			Local j
			For Local i = 0 To 15
				Select loadout[i,0]
				Case ""'if we run into a space that doesn't have anything
					loadout[i,0] = c.name
					loadout[i,1] = "1"'there's just one
					'if unpowered, make it red
					If Not c.plugged Then loadout[i,2] = "True"
					'also record anything attached to it
					Local a = 0
					For Local add:Component = EachIn c.addonList
						a:+ 1
						loadout[i+a,0] = "  > "+add.name
					Next
					j = i+a'record where we aborted
					Exit
				Case c.name'if we run into an entry of the same type
					'do we count up this type of component?
					If c.class <> "gun"
						loadout[i,1]= String(Int(loadout[i,1]) + 1)'just add one to the count
						j = i'record where we aborted
						Exit
					EndIf
				EndSelect
			Next
			
			If _tooltips > 0
				'draw a tooltip if mouseover
				Local ox,oy
				If _tooltips = 1'hangermode
					ox = SWIDTH/2 - (cshapedim/2)*csize - csize/2
					oy = SHEIGHT/2 - (cshapedim/2)*csize - csize/2
					ox:+ (c.x*csize)+csize/2
					oy:+ (c.y*csize)
				Else'listmode
					ox = _ox
					oy = _oy
				EndIf
				
				If loadoutB[j].pressed < 5 And Not tooltipped
					tooltipped = True
					drawTooltip(c,ox,oy)
				EndIf
			EndIf
		EndIf
	Next
EndFunction

'is this configuration name reserved?
Function valid_config_name(_name$)
	Select Lower(_name)
	Case "","arcade","default"
		Return False
	Default
		Return True
	EndSelect
EndFunction

'returns and RGB array containing the appropriate color of power tile
Function getTileColor[](_ptype$)
	Local RGB[3]
	Select Lower(_ptype)
	Case "energy"
		RGB[0] = 64
		RGB[1] = 64
		RGB[2] = 128
	Case "munition"
		RGB[0] = 84
		RGB[1] = 127
		RGB[2] = 61
	Case "omni","any"
		RGB[0] = 64
		RGB[1] = 64
		RGB[2] = 64
	Default 
		RGB[0] = 32
		RGB[1] = 32
		RGB[2] = 32
	EndSelect
	Return RGB
EndFunction

'make all of the possible components to add
Function setup_components()

	'--------------------------GUNS--------------------------
	Local c:Component
	
	'PLASMA
	c = New Component
	c.setShape(2)'2x2 corner
	c.class = "gun"
	c.name = "Plasma"
	c.desc = "Gains +2 burst if given time between shots to charge."
	c.gunList.addLast(new_gun("plasma"))
	c.preq[0] = 1'req 1 power tile
	c.cost = 100
	componentList.addLast(c)
	
	'MISSILE LAUNCHER
	c = New Component
	c.setShape(7)'3x2 T
	c.class = "gun"
	c.name = "Missile Launcher"
	c.desc = "Hold to lock on, and release to fire a homing missile."
	c.alt = True
	c.damageBonus = 10
	c.gunList.addLast(new_gun("launcher"))
	c.preq[1] = 1'req 1 munition tile
	c.cost = 100
	componentList.addLast(c)
	
	'TORPEDO LAUNCHER
	c = New Component
	c.setShape(7)'3x2 T
	c.class = "gun"
	c.name = "Torpedo Launcher"
	c.desc = "Fires a powerful dumb missle straight forward."
	c.alt = True
	c.damageBonus = 14
	c.gunList.addLast(new_gun("torpedolauncher"))
	c.preq[1] = 1'req 1 munition tile
	c.cost = 100
	componentList.addLast(c)
	
	'AUTOCANNON
	c = New Component
	c.setShape(2)'2x2 corner
	c.class = "gun"
	c.name = "Autocannon"
	c.desc = "Steady stream of low-damage bullets."
	c.gunList.addLast(new_gun("autocannon"))
	c.preq[1] = 1'req 1 munitions tile
	c.cost = 100
	componentList.addLast(c)
	
	'SHOTGUN
	c = New Component
	c.setShape(3)'2x2
	c.class = "gun"
	c.name = "Shotgun"
	c.desc = "Fires a spread of close-range, quick shots."
	c.gunList.addLast(new_gun("shotgun"))
	c.preq[1] = 1'req 1 munitions tile
	c.cost = 55
	componentList.addLast(c)
	
	'PHOTON LAUNCHER
	c = New Component
	c.setShape(6)'3x2 missing a corner
	c.class = "gun"
	c.name = "Photon Launcher"
	c.desc = "Fires a series of slow, powerful blasts."
	c.alt = True
	c.gunList.addLast(new_gun("photon"))
	c.preq[3] = 1'req 1 any tile
	c.cost = 85
	componentList.addLast(c)
	
	'VELOCITY CANNON
	c = New Component
	c.setShape(6)'3x2 missing a corner
	c.class = "gun"
	c.name = "Velocity Cannon"
	c.desc = "Hold to build up a charge, and release to fire a fast armour-penetrating shot."
	c.alt = True
	c.gunList.addLast(new_gun("velocitycannon"))
	c.preq[0] = 2'req 2 energy tiles
	c.cost = 250
	componentList.addLast(c)
	
	'GRAVITY GUN
	c = New Component
	c.setShape(8)'3x2
	c.class = "gun"
	c.name = "Gravity Gun"
	c.desc = "Hold to pull nearby ships close, and release to throw them away."
	c.alt = True
	c.accepts_addons = False
	c.gunList.addLast(new_gun("gravitygun"))
	c.preq[3] = 2'req 2 of any tile
	c.cost = 500
	componentList.addLast(c)
	
	'SWARM LAUNCHER
	c = New Component
	c.setShape(7)'3x2 T
	c.class = "gun"
	c.name = "Swarm Launcher"
	c.desc = "Rapidly fires short-range homing missiles."
	c.alt = True
	c.damageBonus = 1.25
	c.gunList.addLast(new_gun("swarmlauncher"))
	c.preq[1] = 1'req 1 munition tile
	c.cost = 125
	componentList.addLast(c)
	
	'ARCCASTER
	c = New Component
	c.setShape(12)'3x3 plus-shape
	c.class = "gun"
	c.name = "Arc Caster"
	c.desc = "Hold to build up a charge, which can be released as a large lightning bolt."
	c.alt = True
	c.gunList.addLast(new_gun("arccaster"))
	c.preq[0] = 1'req 1 energy tile
	c.cost = 390
	c.special = True'VIP-only
	componentList.addLast(c)
	
	'MORTAR LAUNCHER
	c = New Component
	c.setShape(7)'3x2 T
	c.class = "gun"
	c.name = "Mortar Launcher"
	c.desc = "Fires a mortar with a fuse, set to explode when it reaches the target."
	c.alt = True
	c.damageBonus = 24
	c.gunList.addLast(new_gun("mortarlauncher"))
	c.preq[1] = 1'req 1 munition tile
	c.cost = 180
	componentList.addLast(c)
	
	'MINE LAYER
	c = New Component
	c.setShape(3)'2x2
	c.class = "gun"
	c.name = "Mine Layer"
	c.desc = "Drops a smart mine that drifts towards detected enemies."
	c.alt = True
	c.damageBonus = 16
	c.gunList.addLast(new_gun("minelayer"))
	c.preq[1] = 1'req 1 munition tile
	c.cost = 90
	componentList.addLast(c)
	
	'GRAPPLING
	c = New Component
	c.setShape(3)'2x2
	c.class = "gun"
	c.name = "Grappling Hook"
	c.desc = "Exactly what it sounds like."
	c.alt = True
	c.gunList.addLast(new_gun("grappling"))
	c.preq[3] = 1'req 1 any tile
	c.special = True'VIP-only
	c.cost = 30
	componentList.addLast(c)
	
	'NUKE
	c = New Component
	c.setShape(8)'3x2
	c.class = "gun"
	c.name = "H.E.S."
	c.desc = "High-explosive shell. Lobs a fused high-payload mortar at the target."
	c.alt = True
	c.damageBonus = 34
	c.gunList.addLast(new_gun("nuke"))
	c.preq[1] = 2'req 2 munition tile
	c.special = True'VIP-only
	c.cost = 1500
	componentList.addLast(c)
	
	'PEASHOOTER
	c = New Component
	c.setShape(1)'2x1
	c.class = "gun"
	c.name = "Peashooter"
	c.desc = "Pew pew."
	c.gunList.addLast(new_gun("peashooter"))
	c.preq[0] = 1'req 1 power tile
	c.unlockable = False
	componentList.addLast(c)
	
	'BURSTCANNON
	c = New Component
	c.setShape(2)'2x2 corner
	c.class = "gun"
	c.name = "Burstcannon"
	c.desc = "A burst of low-damage bullets."
	c.gunList.addLast(new_gun("autocannon_burst"))
	c.preq[1] = 1'req 1 munitions tile
	c.unlockable = False
	componentList.addLast(c)
	
	'PLASMA BURSTER
	c = New Component
	c.setShape(2)'2x2 corner
	c.class = "gun"
	c.name = "Plasma Burster"
	c.desc = "A variation of the standard plasma gun. Fires in longer, more infrequent bursts."
	c.gunList.addLast(new_gun("plasma_burst"))
	c.preq[0] = 1'req 1 power tile
	c.cost = 70
	componentList.addLast(c)
	
	'-------------------------ADDONS---------------------------
	'BURST BATTERY
	c = New Component
	c.setShape(1)'2x1
	c.addon = True
	c.class = "gun"'
	c.name = "Burster"
	c.desc = "Grants +1 burst to the attached weapon."
	c.shape[0,1] = 2'addon tile
	c.burstBonus = 1
	c.cost = 200
	componentList.addLast(c)
	
	'RECYCLE GIZMO
	c = New Component
	c.setShape(2)'2x2 corner
	c.shape[1,1] = 2'fills out the 2x2 box
	c.addon = True
	c.class = "gun"'
	c.name = "Recycle Gizmo"
	c.desc = "Decreases the recycle time of the attached weapon, causing it to fire more quickly."
	c.recycleBonus = -100
	c.cost = 300
	componentList.addLast(c)
	
	'DAMAGE CHARGER
	c = New Component
	c.shape[0,0] = 1' unorthodox shape:
	c.shape[1,0] = 2' [] X []
	c.shape[2,0] = 1' where x is the attachment point
	c.addon = True
	c.damageBonus = 1.4
	c.class = "gun"'
	c.name = "Damage Charger"
	c.desc = "Grants +"+Int((c.damageBonus-1)*100)+"% damage to the attached weapon."
	c.cost = 85
	componentList.addLast(c)
	
	'OVERCHARGER
	c = New Component
	c.setShape(0)'1x1
	c.shape[1,0] = 2
	c.addon = True
	c.damageBonus = 1.75
	c.recycleBonus = 600'INCREASES shot delay
	c.class = "gun"'
	c.name = "Overcharger"
	c.desc = "Grants +"+Int((c.damageBonus-1)*100)+"% damage to the attached weapon, but causes it to fire more slowly."
	c.cost = 250
	componentList.addLast(c)
	
	'REROUTER
	c = New Component
	c.setShape(0)'1x1
	c.addon = True
	c.damageBonus = 2
	c.class = "gun"'
	c.name = "Rerouter"
	c.desc = "Grants +"+Int((c.damageBonus-1)*100)+"% damage to the attached weapon, but requires a power tile."
	c.shape[1,0] = 2'addon tile
	c.preq[3] = 1'req 1 tile of any type
	c.cost = 130
	componentList.addLast(c)
	
	'DISTRIBUTER
	c = New Component
	c.shape[0,1] = 1'3x1
	c.shape[1,1] = 1
	c.shape[2,1] = 1
	c.addon = True
	c.damageBonus = 1.2
	c.class = "gun"'
	c.name = "Distributer"
	c.desc = "Grants +"+Int((c.damageBonus-1)*100)+"% damage to ALL attached weapons, but requires a power tile."
	c.shape[0,0] = 2'addon tiles
	c.shape[2,0] = 2
	c.shape[0,2] = 2
	c.shape[2,2] = 2
	c.preq[3] = 1'req 1 tile of any type
	c.cost = 130
	componentList.addLast(c)
	
	'--------------------------MISC--------------------------
	
	'ARMOUR
	c = New Component
	c.setShape(0)'1x1
	c.class = "misc"
	c.name = "Armour"
	c.desc = "Increases the maximum health of your ship."
	c.armourBonus = 3
	c.cost = 15
	componentList.addLast(c)
	
	'DAMAGE RESISTANCE
	c = New Component
	c.setShape(3)'2x2
	c.class = "misc"
	c.name = "Fortification"
	c.fortify = .35
	c.fortify_range = 360
	c.desc = "Reduces all incoming damage by "+ Left(String(c.fortify),3) + Chr(34) + "."
	c.cost = 1200
	componentList.addLast(c)
	
	'RAM
	c = New Component
	c.setShape(3)'2x2
	c.class = "misc"
	c.name = "Ram Bullhead"
	c.fortify = 6
	c.fortify_range = 180
	c.fortify_ramming = True
	c.desc = "Reduces collision damage dealt to the front of the ship by "+ Left(String(c.fortify),3) + Chr(34) + "."
	c.cost = 200
	componentList.addLast(c)
	
	'ABILITY BATTERY
	c = New Component
	c.setShape(1)'2x1
	c.class = "misc"
	c.name = "Ability Battery"
	c.pointBonus = 2
	c.desc = "Grants +"+Int(c.pointBonus)+" uses of the shield."
	c.cost = 100
	componentList.addLast(c)
	
	'BOOSTER
	c = New Component
	c.setShape(1)'2x1
	c.class = "misc"
	c.name = "Booster"
	c.engineBonus = 35
	c.desc = "Boosts max speed by "+Int(c.engineBonus)+" m/s."
	c.cost = 170
	componentList.addLast(c)
	
	'THRUSTER
	c = New Component
	c.setShape(1)'2x1
	c.class = "misc"
	c.name = "Thruster"
	c.thrustBonus = .1
	c.desc = "Boosts thrust by "+Left(String(c.thrustBonus),3)
	c.cost = 170
	componentList.addLast(c)
	
	'JUICEBOX
	c = New Component
	c.setShape(0)'1x1
	c.class = "misc"
	c.name = "Juicebox"
	c.juiceBonus = 1
	c.desc = "Grants +"+Left(String(c.juiceBonus),3)+" seconds of afterburner."
	c.cost = 15
	componentList.addLast(c)
	
	'-------------------------ENGINES--------------------------
	
	'SMALL ENGINE
	c = New Component
	c.setShape(0)'1x1
	c.class = "engine"
	c.name = "Small Engine"
	c.desc = "Cannot modify engine placement."
	c.engineBonus = 0
	c.unlockable = False
	componentList.addLast(c)
	
	'BASIC ENGINE
	c = New Component
	c.setShape(4)'3x1
	c.class = "engine"
	c.name = "Engine"
	c.desc = "Cannot modify engine placement."
	c.engineBonus = 0
	c.unlockable = False
	componentList.addLast(c)
	
	'--------------------------NOT-FOR-PlAYERS--------------------------
	
	'GRAVITY
	c = New Component
	c.setShape(0)'1x1
	c.class = "gun"
	c.name = "GRAVITY"
	c.gunList.addLast(new_gun("GRAVITY"))
	c.unlockable = False
	componentList.addLast(c)
	
	'COLLECTOR
	c = New Component
	c.setShape(0)'1x1
	c.class = "gun"
	c.name = "Collector"
	c.alt = True
	c.accepts_addons = False
	c.gunList.addLast(new_gun("collector"))
	c.unlockable = False
	componentList.addLast(c)
	
	'MISSILE EXPLODE
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Explode"
	c.gunList.addLast(new_gun("explode"))
	c.unlockable = False
	componentList.addLast(c)
	
	'BARB
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Barb"
	c.gunList.addLast(new_gun("barb"))
	c.unlockable = False
	componentList.addLast(c)
	
	'ACID
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Acid"
	c.gunList.addLast(new_gun("acid"))
	c.unlockable = False
	componentList.addLast(c)
	
	'LARVA LATCH
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Latch"
	c.gunList.addLast(new_gun("latch"))
	c.unlockable = False
	componentList.addLast(c)
	
	'ALARM
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Alarm"
	c.gunList.addLast(new_gun("alarm"))
	c.unlockable = False
	componentList.addLast(c)
	
	'ANEMONE TENTACLES
	c = New Component
	c.setShape(0)
	c.class = "gun"
	c.name = "Tentacle"
	c.gunList.addLast(new_gun("tentacle"))
	c.unlockable = False
	componentList.addLast(c)
	
	'VECTORSHOOTER
	c = New Component
	c.setShape(0)'1x1
	c.class = "gun"
	c.name = "Vectorshooter"
	c.desc = "White blip bullet."
	c.gunList.addLast(new_gun("vectorshooter"))
	c.unlockable = False
	componentList.addLast(c)
	
	'LUNGE
	c = New Component
	c.setShape(0)'1x1
	c.class = "gun"
	c.name = "Lunge"
	c.desc = "Jump at the target."
	c.gunList.addLast(new_gun("lunge"))
	c.unlockable = False
	componentList.addLast(c)
	
	'SLOWER SHOTS
	c = New Component
	c.setShape(0)'1x1
	c.shape[0,1] = 2'addon tile
	c.addon = True
	c.class = "gun"'
	c.name = "Nerf"
	c.desc = "Enemy shots are slower."
	c.shotspeedBonus = -50
	'c.recycleBonus = 800
	c.unlockable = False
	componentList.addLast(c)
	
	'LESS HEALTH
	c = New Component
	c.setShape(0)'1x1
	c.class = "misc"
	c.name = "Anti-armour"
	c.desc = "Enemies have less health"
	c.armourBonus = -5
	c.unlockable = False
	componentList.addLast(c)
	
	'ALL COMPONENTS
	For Local comp:Component = EachIn componentList
		'should we use the default colors?
		'If comp.rgb[0] = 0 And comp.rgb[1] = 0 And comp.rgb[2] = 0
			Select comp.class '"gun"|"engine"|"misc"
			Case "gun"
				comp.rgb[0] = 120
				comp.rgb[1] = 45
				comp.rgb[2] = 45
			Case "engine"
				comp.rgb[0] = 45
				comp.rgb[1] = 150
				comp.rgb[2] = 70
			Case "misc"
				comp.rgb[0] = 210
				comp.rgb[1] = 210
				comp.rgb[2] = 210
			Default
				comp.rgb[0] = 98
				comp.rgb[1] = 98
				comp.rgb[2] = 98
			EndSelect
			If comp.addon
				comp.rgb[0] = 34
				comp.rgb[1] = 160
				comp.rgb[2] = 160
			EndIf
		'EndIf
		'alter color based on preqs
		If comp.preq[0] > 0'energy
			comp.rgb[0]:- 60
			comp.rgb[1]:+ 20
			comp.rgb[2]:+ 140
		EndIf
		If comp.preq[1] > 0'munition
			comp.rgb[0]:+ 30
			comp.rgb[1]:+ 100
			comp.rgb[2]:- 20
		EndIf
		If comp.preq[3] > 0'omni
			comp.rgb[0]:+ 40
			comp.rgb[1]:+ 40
			comp.rgb[2]:+ 40
		EndIf
	Next

EndFunction

Rem
'generates & returns an item that gives a unique component
'quality gives the general quality of the item, tier is whether it's from cruiser (2), frigates (1), or fighters (0)
Function rand_unique:Item(tier, quality)
	'make a holder item
	Local i:Item = New Item
	i.gfx = component_gfx
	i.animated = True
	i.spin = RndFloat()
	
	Local drop:Component = New Component
	
	Local dropclass = Rand(0,3)
	Select dropclass
	Case 0 '"gun"
		drop.class = "gun"
		i.RGB[0] = 255
		i.RGB[1] = 120
		i.RGB[2] = 120
	Case 3 '"misc"
		drop.class = "misc"
	EndSelect
	
	Select tier
	Case 0'fighter-type item
		Select drop.class
		Case "gun"
			drop.copyComp(Null,"Plasma")
			drop.name = "Plasma EXT"
			For Local g:Gun = EachIn drop.gunList
				g.shotdamage:*2
				g.shotspeed:-2
			Next
		Case "misc"
			drop.copyComp(Null,"Armour")
			drop.name = "Armour EXT"
			drop.armourBonus:*2
			drop.mass:*3
		EndSelect
	Case 1'frigate-type item
	Case 2'cruiser-type item
	EndSelect
	
	'return the holder item
	i.name = drop.name
	i.comp = drop
	i.mass = drop.mass
	Return i
EndFunction
endrem