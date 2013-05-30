?Win32
Import "icon.o"
?

Strict
AppTitle = "Rubicon"

?Win32
	Extern "Win32"
		Function GetAsyncKeyState:Int(key:Int)'so we can use PRINTSCREEN
	End Extern
?

Const OS = 0' slight tweaks depending on the OS in question (screen size, icon...) [ 0 = PC | 1 = MAC | 2 = LINUX ]
Global SHIPSCALE# = 1.1 'how big ships, graphics are

'track the cursor position
Global cursorx#,cursory#																	'could you say that the tracking is just... *cursory* ???
HideMouse()

'set up the graphic options
Local RESO_OVERRIDE = 0
Global FULLSCREEN = 0
Global SWIDTH#=680,SHEIGHT#=400

'set up the default control keys
Global MOUSE_FIREPRIMARY, MOUSE_FIRESECONDARY
Global KEY_THRUST, KEY_REVERSE, KEY_STRAFELEFT, KEY_STRAFERIGHT, KEY_AFTERBURN, KEY_SHIELD, KEY_CYCLEGUN, KEY_MAP
Global JOY_FIREPRIMARY, JOY_FIRESECONDARY, JOY_THRUST, JOY_AIMAXIS, JOY_MOVEAXIS, JOY_AMPLIFY#, JOY_AFTERBURN, JOY_SHIELD, JOY_CYCLEGUN, JOY_MAP, JOY_MENU
Const JOY_LEFTSTICK = 255, JOY_RIGHTSTICK = 254, JOY_OTHERSTICK = 253, JOY_HAT = 252 'high numbers so don't conflict with keycodes
setControlsToDefault()

'use the keyboard+mouse or a joystick?
'Const SCHEME_KEY = 0, SCHEME_JOY = 1
'Global control_scheme = SCHEME_JOY
Global joyDetected = False'no joy here, checked in updatecursor()

'STARTING pilot name, we only use this to default to a selected pilot when the game starts
Global SEL_PILOT$

'set up the cheats
Global cheat_modbase = False		'lets you modify locked configs, components
Global cheat_invincible = False		'take no damage
Global cheat_disableengines = False	'can't thrust forward

'read the options file
RESO_OVERRIDE = readOptionsFile("rubicon.options")

'use the settings override?
If RESO_OVERRIDE
	Graphics SWIDTH,SHEIGHT,FULLSCREEN*2
	
'go for a default resolution
Else
	Local default_fullscreen = 2'defaults to fullscreen
	If OS = 1 Then default_fullscreen = 0'...except for macs

	Local reso_x, reso_y
	For Local r = 1 To 8'try out all the default resolutions
		Select r
		Case 1
			reso_x = DesktopWidth()
			reso_y = DesktopHeight()
		Case 2
			reso_x = 1920
			reso_y = 1200
		Case 3
			reso_x = 1366
			reso_y = 768
		Case 4
			reso_x = 1280
			reso_y = 768
		Case 5
			reso_x = 1024
			reso_y = 768
		Case 6
			reso_x = 960
			reso_y = 600
		Case 7
			reso_x = 800
			reso_y = 600
		Case 8
			RuntimeError("Compatible graphics mode not found, sorry. Try opening [rubicon.options] and doing a resolution override.")
			End
		EndSelect
		
		'macs need to account for that stupid bar thing for every program + the frikking "I'm always visible look how graphical I am" dock
		'yes I know they're for standardization of use and actually good design in that you don't have to relearn how to use every single
		'program according to whatever the cracked-out programmer was thinking would be a good idea at the time
		'but still dammit they get in the way of things
		If OS = 1'MAC
			reso_x:- 150
			reso_y:- 150
		EndIf
		
		If GraphicsModeExists(reso_x,reso_y) Or OS = 1'just force it for MACs
			Graphics reso_x, reso_y, default_fullscreen
			Exit'we've found a good resolution
		EndIf
	Next
	
	SWIDTH = GraphicsWidth()
	SHEIGHT = GraphicsHeight()
EndIf

SeedRnd MilliSecs()
AutoMidHandle True
SetMaskColor 255,255,255
SetBlend(ALPHABLEND)

Const game_FPS = 45'set the game to a max # frames per second
Global frameTime# = 1000 / game_FPS'find how many millisecs should be between each frame
Global frameTimer:TTimer = CreateTimer(game_FPS)

'show the player something more than just a black screen
DrawText "LOADING...",0,0
Flip

Include "graphicsmagic.bmx"	'image processing functions: getting individual frames, resizing, recoloring, hardcodes color schemes
Include "buttoncontrol.bmx"	'for use in menus: sets up the button object, SLists for scrolling lists of buttons
Include "mainMenu.bmx"		'sets up the main menu + pilot object
Include "pauseMenu.bmx"		'when press esc during a game, runs this minimenu
Include "optionMenu.bmx"	'menu to adjust gameplay options, audio, controls
Include "intro.bmx"			'does the short intro sequence when the game starts
Include "new_ship.bmx"		'provides the function to create a new ship ingame
Include "add_backdrop.bmx"
Include "hangercontrol.bmx"
Include "deploycontrol.bmx"
Include "arcade_upgradecontrol.bmx"
Include "gamecontrol.bmx"
Include "vip.bmx"

'forces accelerate entities based on their mass
Type Force
	Field F#
	Field angle#
	'Field speedLimit#		'forces can only accelerate things up to a certain speed. Relativity or something, am I right??? (neg. # = no cap)
EndType

Type Entity Abstract
	Field x#,y#,rot#,movrot#,speed#,spin#,mass# = 2, frameoffset
	
	Field link:TLink					'the link in the entity, bg, debris, shot, or explode TList this entity is part of
	
	Field master:Entity					'if not null, this entity is slaved to another entity
	Field master_offx#, master_offy#	'offset coords from master's position at rot = 0
	Field master_offrot#				'original master's rotation, if the master turns after this we can figure out where to draw in relation
	
	Field ignorePhysics = False			'whether this entity should listen to the forces on it
	Field ignoreCollisions = False		'whether this entity participates in any collisions
	Field ignoreShipCollisions = False	'whehter this entity participates in collisions with other ships
	Field ignoreShotCollisions = False	'whehter this entity participates in collisions with other shots
	Field ignoreMovement = False		'whether this entity should move
	Field ignoreList:TList = New TList	'list of GERTRUDES that this entity can't collide with (e.g. the owner, ships it's already hit...)
	Field forceList:TList = New TList
	Field cboxList:TList = New TList	'list of INTEGERS that correspond to the cboxes this ship is in

	Field skipDraw = False				'skip drawing this
	Field dist# = 1						'parallax-maker! higher this is, slower it moves via player's movement. 1=shiplevel
	Field animated						'true/false, whether to animate this ship
	Field alpha#						'0-1, how transparent to draw this entity (0 = opaque | 1 = transparent)
	Field shade#						'how much to subtract from ALL of the 255 drawcolors
	Field RGB[3]						'color of the entity, defaults to 255,255,255 if untouched
	Field blend = ALPHABLEND			'the kind of blending to use
	Field scale# = 1					'what SHIPSCALE is multiplied by for drawscale (if 0 then default to 1)
	Field text$							'can replace gfx, if it has this it'll be drawn instead
	Field gfx:TImage[]					'two frames, one Timage stored to each one (unless it's not animated)
	
	Field proximity_track = False		'whether this should track the proximity of nearby ships
	Field proximity_shipList:TList = New TList'a list that is constantly updated of other nearby ships, used by the AI (Gertrude types ov cors)

	
	'pays attention to forces and whatnot
	Method physics()
	
		'x,y components of speed
		Local speed_x# = Cos(movrot) * speed
		Local speed_y# = Sin(movrot) * speed
		'Local angle_x# = speed_x
		'Local angle_y# = speed_y
		
		'draw current speedlines
		'If Self = p1
		'	SetColor 0,0,255
		'	DrawLine SWIDTH/2,SHEIGHT/2,SWIDTH/2+speed_y*20,SHEIGHT/2-speed_x*20
		'EndIf
		
		'IF forces are acting on the entity AND we don't ignore them!
		If (Not ignorePhysics) And (mass > 0)
		If (Not ListIsEmpty(forceList))
		
			'tally up all the forces
			Local fx#=0, fy#=0'total force
			'Local sx#=0, sy#=0'speed-altering force only
			For Local f:Force = EachIn forceList
				fx:+ Cos(f.angle) * f.F
				fy:+ Sin(f.angle) * f.F
			
				'find the relative angle of thrust
				'Local rangle# = movrot - f.angle
				
				'find entity's parallel velocity to the angle of thrust
				'Local s_para# = Cos(rangle) * speed
				'find the parallel-to-thrust vector of the MAXIMUM speed at current moving angle
				'Local s_para_max# = f.speedLimit
				
				'draw vector lines
				'If Self = p1
				'	Local lx# = Cos(f.angle) * 20's_para# * 20
				'	Local ly# = Sin(f.angle) * 20's_para# * 20
				'	SetColor 0,255,0
				'	DrawLine SWIDTH/2,SHEIGHT/2,SWIDTH/2+ly,SHEIGHT/2-lx
				'	SetColor 255,0,255
				'	DrawLine SWIDTH/2,SHEIGHT/2,SWIDTH/2+ly*s_para_max/s_para+4,SHEIGHT/2-lx*s_para_max/s_para+4
				'EndIf
				
				'SetColor 255,0,0
				'DrawLine x+game.camx,y+game.camy,x+game.camx+Cos(f.angle)*f.F*200,y+game.camy+Sin(f.angle)*f.F*200
				
				'decrease the force applied as the speed of the object reaches the limit
				'If s_para > 0
				'	f.F = f.F * (1 - constrain(s_para/s_para_max, -1,1) )
				'Else
				'	f.F = f.F
				'EndIf

				'add this force to the speed-altering force tally
				'sx:+ Cos(f.angle) * f.F
				'sy:+ Sin(f.angle) * f.F
			Next
			'get the total force, angle
			Local total_force# = Sqr(fx^2+fy^2)
			Local total_angle# = ATan2(fy,fx)
			'get the speed-altering force
			'Local speed_force# = Sqr(sx^2+sy^2)
			
			'draw forcelines
			'If Self = p1
			'	SetColor 255,0,0
			'	DrawLine x+game.camx,y+game.camy,x+game.camx+fx*200,y+game.camy-fy*200
			'EndIf
			
			'get the amount of speed we want to add: force * passed time / mass
			Local add_speed# = total_force * frameTime / mass
			'Local add_speed# = speed_force * frameTime / mass
			'Local add_steer# = total_force * frameTime / mass

			'add the force's added speed to current speed
			speed_x:+ Cos(total_angle) * add_speed
			speed_y:+ Sin(total_angle) * add_speed
			
			'find the new angle
			'angle_x:+ Cos(total_angle) * add_steer
			'angle_y:+ Sin(total_angle) * add_steer
			
			'store the entity's new angle, speed
			'movrot = ATan2(angle_y,angle_x)
			movrot = ATan2(speed_y,speed_x)
			speed = Sqr(speed_x^2 + speed_y^2)
			
			'clear the force list
			ClearList(forceList)
		EndIf
		EndIf
		
		'move everything how it's supposed to move (if it's supposed to move + isn't slaved to something else)
		If master = Null
			If Not ignoreMovement
				x = x + speed*Cos(movrot)*(frameTime/1000)
				y = y + speed*Sin(movrot)*(frameTime/1000)
				rot = rot + spin
			EndIf
		Else
			'bump the master 
			'master.addSpeed(speed,movrot)
			'reset own speed to zero
			speed = 0
			movrot = 0
			'update position to master's
			x = master.x - master_offx*Cos(-master.rot) + master_offy*Sin(-master.rot)
			y = master.y + master_offy*Cos(-master.rot) - master_offx*Sin(-master.rot)
			'whenever the master rotates, the slave does as well
			'rot = (master.rot + master_offrot)
			'master_offrot = master.rot
		EndIf
		
	EndMethod
	
	'add a force to the entity
	Method add_force(_angle#,_F#)',_speedLimit# = 5)
		Local f:Force = New Force
		f.F# = _F#
		f.angle# = _angle#
		'f.speedLimit# = _speedLimit
		forceList.AddLast f
	EndMethod
	
	Method draw()'draws the entity (relative to the camera!) + returns true if could/bothered to successfully draw
		'valid graphic?
		If (gfx <> Null Or text <> "") And Not skipDraw
			'onscreen?
			If Abs(x-p1.x) < SWIDTH*(dist^2)*1.2 And Abs(y-p1.y) < SHEIGHT*(dist^2)*1.2
			'If Abs(x-p1.x) < SWIDTH*2*dist And Abs(y-p1.y) < SHEIGHT*2*dist
			'If (Abs(x-p1.x)-(ImageWidth(gfx)*SHIPSCALE) < SWIDTH*2*dist) Or (Abs(y-p1.y)-(ImageHeight(gfx)*SHIPSCALE) < SHEIGHT*2*dist)
				If scale = 0 Then scale = 1
				If dist = 0 Then dist = 1
				Local drawdist# = dist + game.zoom	
				If RGB[0] = 0 And RGB[1] = 0 And RGB[2] = 0
					RGB[0] = 255
					RGB[1] = 255
					RGB[2] = 255
				EndIf
				'set drawing states
				SetScale SHIPSCALE*scale/drawdist,SHIPSCALE*scale/drawdist
				SetAlpha 1-alpha
				SetColor RGB[0]-shade,RGB[1]-shade,RGB[2]-shade
				SetBlend blend
				
				'set the frame to draw
				Local frame = 0
				If animated
					frame = frameoffset
					If globalFrame = 1 Then frame = (frame+1) Mod 2
				EndIf
				
				'figure out how to modify their position based on distance
				Local zoom_shift#[] = findDistShift()
				
				SetRotation (rot - game.camrot)
				Local drawx# = x+game.camx+zoom_shift[0]
				Local drawy# = y+game.camy+zoom_shift[1]
				
				'draw the graphic or the text
				If text <> ""
					DrawText text, drawx, drawy
				Else
					DrawImage gfx[frame], drawx, drawy
				EndIf
				
				Return True
			EndIf
		EndIf
		Return False'if it's made it this far...
	EndMethod
	
	'find the offset due to the distance of the object & the camera's zoom
	Method findDistShift#[]()
		Local zoom_shift#[2]
		zoom_shift[0] = 0
		zoom_shift[1] = 0
		If game <> Null
			'find how far they are from the center of the screen
			Local xdif# = x - (-game.camx + SWIDTH/2)'(p1.x+game.camxoffset)
			Local ydif# = y - (-game.camy + SHEIGHT/2)'(p1.y+game.camyoffset)
			
			'find the actual shift in xy axis
			zoom_shift[0] = -xdif + (xdif / (game.zoom + dist))
			zoom_shift[1] = -ydif + (ydif / (game.zoom + dist))
		EndIf
		
		Return zoom_shift
	EndMethod
	
	'adds a certain amount of speed in a certain direction, IN ADDITION TO current
	Method addSpeed(_speed#,_angle#)
		'how fast we're currently moving
		Local speed_x# = Cos(movrot) * speed
		Local speed_y# = Sin(movrot) * speed
		
		'how much to give it a shove
		Local push_x# = Cos(_angle) * _speed
		Local push_y# = Sin(_angle) * _speed
		
		'shove it!
		speed_x:+ push_x
		speed_y:+ push_y
		
		'recalc speed, angle
		movrot = ATan2(speed_y,speed_x)
		speed = Sqr(speed_x^2 + speed_y^2)
	EndMethod	
	
	
	'add things to collision boxes [small groups of entities based on location, so we perform (a^2 + b^2 + c^2... comparisons instead of just n^2)]
	Method addToCollisionBoxes()
		If Not ignoreCollisions
			Local cbx, cby, cbx_old = -1, cby_old = -1' x, y tile of the current and previous cbox
			Local swid# = ImageWidth(gfx[0])/2	'the horizontal radius of the entitiy
			Local shet# = ImageHeight(gfx[0])/2	'the vertical radius of the entity
			Local cb_wide = Ceil(Ceil(swid*2/game.cboxSize)/2)'how many collision boxes-wide the entity is
			Local cb_tall = Ceil(Ceil(shet*2/game.cboxSize)/2)'how many collision boxes-tall the entity is
			'look at each corner of the ship, add self to each cbox group that it overlaps
			For Local y_box# = -cb_tall To cb_tall
				cby = Int((y + (y_box*shet) + game.height) / game.cboxSize)
				cby = constrain(cby, 0, game.cboxRowNum-1)
	
				If cby <> cby_old'if we've moved onto a new row of cboxes for this corner
					For Local x_box# = -cb_wide To cb_wide
						cbx = Int((x + (x_box*swid) + game.width) / game.cboxSize)
						cbx = constrain(cbx, 0, game.cboxColNum-1)

						If cbx <> cbx_old'if we've moved into a new column of cboxes for this corner
							game.cboxList[cbx,cby].addLast(Self)
							
							'SetColor 255,255,255
							'SetAlpha .07
							'DrawRect (cbx*game.cboxSize)+game.camx-game.width, (cby*game.cboxSize)+game.camy-game.height, game.cboxSize, game.cboxSize
						EndIf
						cbx_old = cbx
					Next
				EndIf
				cby_old = cby
				cbx_old = -1'we're on a new row, reset the column check
			Next
		EndIf
	EndMethod
	
	'sets RGB to 255,255,255
	Method resetRGB()
		RGB[0] = 255
		RGB[1] = 255
		RGB[2] = 255
	EndMethod
	
	Method update() Abstract			'what to do every loop
	Method collide(_ship:Ship) Abstract	'what to do when collides with a SHIP (things can only collide with ships!)
EndType
Global entityList:TList = New TList

Const AI_AVOIDCOLLISION_DIST = 250		'min distance to an object before they'll start taking action
Const AI_DIVEBOMB_DIST = 210
Const AI_CIRCLE_DIST = 280			'this is the MAX distance they'll circle, some will be closer
Const AI_DETECT_DIST = 6000			'distance to detect an enemy
Global AI_predict_time = 1500			'how long it takes for the AI to draw a bead on another ship [now defunct]

'a group of ships with common commands. if no ships/icons point to it, it stops existing. whoa. [sorta stopped using them, but it's messily everywhere]
Type Squadron
	Field x,y						'the current center position of this squadron
	Field behavior$					'behavior that overwrites the ship's natural behavior
	Field shipNum					'stores the last shipcount, AKA how many ships are in this squadron
	Field shipCount					'reset each loop, tells the ship how many ships have checked into this squad before it
	Field goal_x,goal_y, target:Gertrude	'the target of this squadron, be it a position or a ship.
	Field faction					'the faction all contained ships are part of
	Field setPos = False				'does this squadron set the position of its members at the start?
	
	Field avoidcollision_dist = AI_AVOIDCOLLISION_DIST
	Field divebomb_dist = AI_DIVEBOMB_DIST
	Field circle_dist = AI_CIRCLE_DIST
	Field detect_dist = AI_DETECT_DIST
EndType
Function new_squad:Squadron(_behav$,_faction,_setPos = False)'makes & returns a squadron of the specified specifications
	Local s:Squadron = New Squadron
	s.behavior = _behav
	s.faction = _faction
	s.setPos = _setPos
	Return s
EndFunction

'for asteroids and suchlike
Global inertSquad:Squadron = new_squad("inert",0)

Global abilityMap:TMap = CreateMap()
MapInsert(abilityMap, "0", "n/a")
MapInsert(abilityMap, "1", "Shield")
MapInsert(abilityMap, "2", "Blink")
MapInsert(abilityMap, "3", "Overburn")
MapInsert(abilityMap, "4", "Cloak")
MapInsert(abilityMap, "5", "Overcharge")
Const ABILITY_SHIELD = 1
Const ABILITY_BLINK = 2
Const ABILITY_BURNER = 3
Const ABILITY_CLOAK = 4
Const ABILITY_OVERCHARGE = 5

Global chassisList:TList = New TList
'the archtype of a ship
Type Chassis
	Field name$
	Field gfx:TImage[]		'two frames
	Field hitgfx:TImage		'an all-white version of the graphic, generated at the end of chassis setup
	Field animated
	
	Field cshape[cshapedim,cshapedim]	'state of component tile: 0=n/a | 1=empty | 2=energy | 3=munition | 4=unused | 5=omni | (NEGATIVE = filled!)
	Field compList:TList = New TList	'list of components installed on this ship
	
	Field cost = 1000				'number of points it takes to unlock this ship
	
	Field mass#
	Field armour#				'health
	Field fortification#		'base damage resistance to apply to each shot
	Field ability				'which special ability this chassis has: 0=n/a
	Field points				'number of special ability points this chassis has: -1=infinite
	Field juice# = 1.2			'base seconds of afterburner for the chassis
	Field speedMax#				'maximum speed you can reach by thrusters (afterburn 2x this)
	Field thrust#				'acceleration, the force the engines provide (to get out of black holes and whatnot)
	Field strafe#				'% of thrusters and maximum speed that strafing can apply
	Field turnRate#				'base rate that the ship can turn
	Field fortifyList:TList = New TList	'list of fortification (damage reduction) amounts, offsets, and ranges
	
	Field behavior$ = "pulse"		'how this ship behaves
	Field trailRGB[3]				'color of the trail, defaults to 255,255,255 if we don't touch it
	Field trailScale#	 = 1			'trail modifier, this will be added/subtracted from the trail scale
	Field explodeSound:TSound		'sound of ship dying
	Field explodeNum	= -1			'number of explosions when it dies/is damaged | -1 = unset, calculate default
	Field explodeShake = 1			'how much to shake the screen on death
	Field debrisType				' 0:metal | 1:rock | 2:gib | 3:vector
	Field debrisRGB[3]	
	Field dropShipList:TList = New TList	'list of SHIP NAMES to drop on death
	Field dropSquad:Squadron			'squadron to add dropped ships to, defaults to inertSquad
	Field dropItemList:TList = New TList	'list of ITEM NAMES to drop of death
	
	Field bio = False				'is this a biological ship? (don't get bounced by borders, no target prediction
	Field ord = False				'is this a piece of ordenance? (explode on contact with anything)
	
	Field stationary = False
	Field invulnerable = False
	
	Field unlockable = False		'can the player unlock this chassis?
	Field special = False			'if unlockable, do only special edition people get it?
	
	'copies the stats of another chassis
	Method copyChassis(_copyName$)
		'find the chassis-to-copy
		For Local c:Chassis = EachIn chassisList
		If c.name = _copyName$
			gfx = c.gfx
			animated = c.animated
			For Local y = 0 To cshapedim-1
			For Local x = 0 To cshapedim-1
				cshape[x,y] = c.cshape[x,y]
			Next
			Next
			mass = c.mass
			armour = c.armour
			ability = c.ability
			points = c.points
			juice = c.juice
			speedMax = c.speedMax
			thrust = c.thrust
			strafe = c.strafe
			turnRate = c.turnRate
			behavior = c.behavior
			trailRGB[0] = c.trailRGB[0]
			trailRGB[1] = c.trailRGB[1]
			trailRGB[2] = c.trailRGB[2]
			explodeSound = c.explodeSound
			explodeNum = c.explodeNum
			debrisType = c.debrisType
			debrisRGB[0] = c.debrisRGB[0]
			debrisRGB[1] = c.debrisRGB[1]
			debrisRGB[2] = c.debrisRGB[2]
			For Local s$ = EachIn c.dropShipList
				dropShipList.addLast(s)
			Next
			dropSquad = c.dropSquad
			For Local i$ = EachIn c.dropItemList
				dropItemList.addLast(i)
			Next
			bio = c.bio
		EndIf
		Next
	EndMethod
	
	'automatically figure out the cshape based on the graphic
	Method auto_cshape()
	If gfx <> Null
		SetScale 1,1
		SetRotation 0
		
		'create the testing rectangle
		Local rect:TImage = CreateImage(cshaperatio-2,cshaperatio-2)
		Cls
		SetColor 0,255,0
		DrawRect 0,0,cshaperatio-2,cshaperatio-2
		GrabImage rect,0,0
		SetImageHandle(rect,0,0)
		
		'see where the gfx and rect overlap
		For Local y = 0 To cshapedim-1
		For Local x = 0 To Ceil(cshapedim/2)
			'check if this spot should be available
			If ImagesCollide(gfx[0],cshapedim*cshaperatio/2,cshapedim*cshaperatio/2,0,rect,x*cshaperatio+1,y*cshaperatio+1,0)
				cshape[x,y] = 1'empty, available spot
			Else
				cshape[x,y] = 0'unavailabe spot
			EndIf
			'mirror things horizontally
			cshape[(cshapedim-1)-x,y] = cshape[x,y]
		Next
		Next
	EndIf
	EndMethod
	
	'kills a square, offset from the center
	Method trim_cshape(_x,_y)
		'x,y input are offset from center
		Local cx = Floor(cshapedim / 2)
		Local cy = Floor(cshapedim / 2)
		
		cshape[cx+_x, cy+_y] = 0
	EndMethod
	
	'set a tile to a power tile
	Method power_cshape(_x,_y,_ptype$)
		'x,y input are offset from center
		Local cx = Floor(cshapedim / 2)
		Local cy = Floor(cshapedim / 2)
		
		'figure out code of powertype
		For Local pcode:Object = EachIn MapKeys(psquareMap)
			'if we find a type of power tile that matches what we were given, set this square to that
			If MapValueForKey(psquareMap, String(pcode)) = _ptype Then cshape[cx+_x, cy+_y] = Int(String(pcode))
		Next
	EndMethod
	
	'adds a component to the chassis
	Method add_comp:Component(_compName$,_x=0,_y=0, _locked = False, _absolute = False)
		'x,y input are offset from center
		Local cx = Floor(cshapedim / 2)
		Local cy = Floor(cshapedim / 2)
		
		'no offset of the provided coords are absolute
		If _absolute
			cx = 0
			cy = 0
		EndIf
		
		'make the component		
		For Local c:Component = EachIn componentList
			If c.name = _compName
				Local ac:Component = new_comp(c.name)
				ac.x = cx + _x
				ac.y = cy + _y
				ac.locked = _locked
				compList.addLast(ac)
				Return ac
			EndIf
		Next
	EndMethod
	
EndType

'an offset and range of angles to apply damage resistance
Type Fortification
	Field offset#		'offset from ship's rot = 0 to center the fortification
	Field range# = 90		'arc centered on offset to reduce incoming damage
	Field DR#			'amount of damage reduced to all incoming shots that hit the fortification
	Field ramming = False	'is it ramming armour? if so, only reduces collision damage
EndType
Function new_fortify:Fortification(_DR#, _range#, _offset#, _ramming = False)
	Local f:Fortification = New Fortification
	f.DR = _DR
	f.range = _range
	f.offset = _offset
	f.ramming = _ramming
	Return f
EndFunction

Type Ship Extends Entity
	Field name$
	Field base:Chassis				'the chassis this ship is based on
	
	Field config$					'the name of the configuration -> if Null then just use "default"
	Field cshape[cshapedim,cshapedim]		'squares to drop components onto: 0=unavailable | 1=empty | 2=filled & transparent | 3=filled & opaque
	Field compList:TList = New TList		'list of components installed on this ship
	Field color, scheme				'the last loaded color and the current target scheme
	
	Field gunGroup:TList[6]			'list of weapongroups, 0=primary weapons, everything above that are secondaries
	
	'SHOOTY STATS, calculated on game initialization based on chassis stats + components
	Field turnRate#					'rate that the ship can turn, a base - a function of mass
	Field speedMax#					'maximum speed you can reach by thrusters (afterburn 2x this)
	Field thrust#					'the force your engines can apply forward. It calculates how fast it SHOULD be able to push you, can't accel faster.
	Field strafe#					'what % of ships main thrust can be applied sidewayss
	Field pointMax					'maximum amount of ability points this ship has (-1:infinite)
	Field points					'current amount of ability points this ship has
	Field armourMax#
	Field armour#
	Field juiceMax#
	Field juice#					'amount of energy currently stored for afterburner
	Field fortifyList:TList = New TList	'damage resistance applied to each incoming shot
	
	Field burner_duration = 8			'the length of time, in seconds, that the overburner lasts
	Field burner_timer#
	Field burnerOn					'TRUE/FALSE whether the burner is currently on
	
	Field shield_duration# = 6			'the length of time, in seconds, that shields last
	Field shield_timer#				'timer for the shield to start regenerating
	Field shield_tween#				'a little hit tweening. decays rapidly to 0, set to 1 for full effect.
	Field shieldOn					'TRUE/FALSE whether shields are currently up
	
	Field blink_timer#				'while this is counting down, the player can hit space again to blink back in. if it hits 0, automatic.
	Field blinkOn					'are we blinking; while this is on, the ship is pretty much removed from the entity list
	
	Field cloak_duration# = 11			'the length of time, in seconds, that cloaking lasts
	Field cloak_timer#
	Field cloakOn					'can we be detected?
	
	Field overcharge_duration# = 8		'length of time the overcharge lasts
	Field overcharge_timer#
	Field overcharge_mod# = 1.5			'* damage, / firerate, * shotspeed
	Field overchargeOn
	
	Field explodeSound:TSound
	Field explodeNum					'number of explosions
	Field debrisRGB[3]				'color of explosions, debris
	Field dropList:TList = New TList		'list of entities or backgrounds to drop when ship dies (debris, powerups)
	
	'SHOOTY tracking variables
	Field squad:Squadron				'a pointer to the squadron this ship is a part of, used to determine baseline behavior, goals
	Field throttle#					'what % the engines are pushin
	Field engineChannel:TChannel			'the sound channel for the engines.
	Field thrust_theta#
	Field hit_tween#					'transparency of white box to draw over the ship. decays rapidly to 0, set to 1 on hit damage
	
	Field recent_damage#				'tracks the amount of damage the ship has taken recently
	Field recent_damage_timer#			'counts down how recent "recent" is. also acts at a damage text tween
	Field recent_damage_delay = 1500		'amount of time, in ms, how recent "recent" is
	Field recent_damage_theta			'angle of the most recent damage
	
	Field recent_points#				'how many points the player has picked up recently
	Field recent_points_timer			'the countdown to fade the counter back out
	Field recent_points_delay = 5500
	
	Field behavior$					'how this ship behaves. "player":player-controlled|"cw":flies in cw circles|"ccw":flies in ccw circles
	Field target:Gertrude				'the ship that this ship is currently targeting
	Field AI_timer					'generic timer that AI uses
	Field AI_value[4]					'used by different AI modes for different things
	Field AI_dir#[2]					'x,y vectors that the AI adds up and then decides which way it wants to go with
	Field player_ffdisplay				'if true, display friend/foe information on this ship	
	Field AI_predict#					'how well OTHER AIs can predict this one's movement
								'changing speed, direction, or afterburning all decrease this, otherwise it steadily increases.
	
	Field collide_sfx_countdown			'can only make a collide noise every 1000 ms
	Field invulnerable				'should it be able to take damage?
	Field tweenOnHit = True			'should we do a little white flash on hit of the ship?
	Field placeholder:Gertrude = New Gertrude'a drop site so other ships can figure out this ships location, faction, etc. without creating strange loop
	
	'general properties
	Method update()
	
		'call the ship's update functions for each gun in each gunGroup
		For Local wgroup = 0 To 5
			For Local g:Gun = EachIn gunGroup[wgroup]
				g.update(Self)
			Next
		Next
		
		'if override current behavior with the squadron's behavior if applicable, otherwise stick to the base
		If squad.behavior <> "" Then behavior = squad.behavior Else behavior = base.behavior
		If p1 = Self Then behavior = "player"
		
		'onscreen?
		Local onscreen = False
		If Abs(x-p1.x) < (SWIDTH+SHEIGHT)*dist And Abs(y-p1.y) < 2*SHEIGHT*dist Then onscreen = True
		
		'bound armour amount
		armour = constrain(armour, 0, armourMax)
		If invulnerable Then armour = armourMax
		
		'special abilities
		Select base.ability
		'invulnerable for a short time
		Case ABILITY_SHIELD
			'shields are only on if the timer is not yet finished
			If shield_timer <= 0 Then shieldOn = False Else shieldOn = True
			'count down the time shields are on
			If shieldOn Then shield_timer:- (frameTime/1000.0)
			'decay shield tween back towards none
			If shield_tween <> 0 Then shield_tween:- (shield_tween*4) * (frameTime/1000.0)
			
		'faster engines for a short time
		Case ABILITY_BURNER
			'burner is only on is the timer is not yet finished
			If burner_timer <= 0 Then burnerOn = False Else burnerOn = True
			If burnerOn
				burner_timer:- (frameTime/1000.0)'count down the time burner is on
				juice = juiceMax'always can afterburn
			EndIf
			
		'teleport to the mouse
		Case ABILITY_BLINK
			If blinkOn
				blink_timer:- frameTime
			
				'choose the target to blink at
				If blink_timer <= 0 Or game.over' Or KeyHit(KEY_SHIELD)'THIS IS SO NOT OKAY!!!
					blinkOn = False
				
					'go at the mouse
					x:+ (cursorx - (p1.x+game.camx))
					y:+ (cursory - (p1.y+game.camy))
					
					'center the cursor, we've moved to it
					moveCursor()
					
					'takes a bit to warp back in
					blink_timer = 200
					
					'make an effect of fading back in
					Local	fade:Foreground = New Foreground
					Local fadegfx:TImage[1]
					fadegfx[0] = base.hitgfx
					fade.gfx = fadegfx
					fade.animated = False
					fade.x = x
					fade.y = y
					fade.rot = rot
					fade.alpha = 1
					fade.alphaspeed = -.05
					fade.lifetimer = blink_timer
					fade.link = bgList.addFirst(fade)
				EndIf
				
			'if we're still finishing the blink
			ElseIf blink_timer > 0
				blink_timer:- frameTime
			
				'finish it!
				If blink_timer <= 0
					'become tangible again
					cloakOn = False
					ignorePhysics = False		'whether this entity should listen to the forces on it
					ignoreCollisions = False	'whether this entity participates in any collisions
					ignoreMovement = False		'whether this entity should move
					skipDraw = False
					game.disable_controls = False
					blink_timer = 0
					hit_tween = 1
					speed = 0
					FlushKeys()
					FlushMouse()
					FlushJoy()
					ClearList(forceList)
				EndIf
			EndIf	
			
		'turn invisible for a short time
		Case ABILITY_CLOAK
			'if cloaking is on
			If cloak_timer > 0
				cloakOn = True
				'count down the time cloak is on
				cloak_timer:- (frameTime/1000.0)
				
				Local fadeTime# = .5 
				'set ship's alpha accordingly
				If cloak_duration - cloak_timer <= fadeTime
					alpha = ((cloak_duration - cloak_timer) / fadeTime)	'FADE OUT
				ElseIf cloak_timer <= fadeTime
					alpha = (cloak_timer / fadeTime)				'FADE IN
				Else
					alpha = 1'								'BE INVISIBLE
				EndIf
			Else
				cloakOn = False
			EndIf
			If Self = p1 Then alpha = constrain(alpha, 0, .8)
			
		'get stronger weapons for a short time
		Case ABILITY_OVERCHARGE
			If overcharge_timer <= 0
				overchargeOn = False
			Else
				overchargeOn = True
				overcharge_timer:- (frameTime/1000.0)'count down the timer
				'make some awesome background effects (red shadows)
				If Rand(1,6) = 1
					Local shadow:Background = add_particle( x, y, Rand(0,359), 37.5+RndFloat()*2, 700, True)' Rand(0,1))
					shadow.gfx = New TImage[2]'so we don't contaminate the normal gfx
					shadow.gfx[0] = base.hitgfx
					shadow.gfx[1] = base.hitgfx
					shadow.animated = False
					shadow.spin = 0
					shadow.scale = 1 + (overcharge_timer/overcharge_duration)
					shadow.rot = rot
					shadow.alpha = .7
					shadow.alphaSpeed = (RndFloat()+.5)/Float(shadow.lifetimer*4)
					shadow.RGB[0] = 120
					shadow.RGB[1] = 0
					shadow.RGB[2] = 0
					
					'push the shadow to match ship speed
					shadow.addSpeed(speed*.7, movrot)
				EndIf

			EndIf

		EndSelect
		
		'steadily increase the predict movement value
		AI_predict = constrain(AI_predict + (frameTime/AI_predict_time), 0, 1)
		
		'decay hit tween back towards none
		If hit_tween <> 0 Then hit_tween:- (hit_tween*8) * (frameTime/1000.0)
		If hit_tween < .05 Then hit_tween = 0
		
		'have the engines make sum noiz in da hous (uses prexisiting engine sound)
		'Local engineVol# = Abs((speed / speedMax) * Sgn(throttle))
		'If engineChannel <> Null Then playSFX(Null,x,y,engineVol,engineChannel)
		
		'regenerate juice
		If throttle <= 1 Then juice = constrain(juice + (frameTime/1000.0), 0, juiceMax)
		
		'lose dead and cloaked targets
		If target <> Null And (target.dead Or target.cloakOn) Then target = Null
		
		'resolve the ship's thrust, add the actual force
		resolve_thrust()
		
		'throttle can't decrease maxspeed
		If throttle < 1 Then throttle = 1
		'constrain to maximum speed
		Local decel# = (thrust*base.mass) * Max((speed / speedMax),1.0)
		If thrust = 0 Then decel = (base.mass) * Max((speed / speedMax), 1.0)'thrustless things are also capped
		
		If Abs(speed) > Abs(speedMax*throttle) Then add_force(movrot+180, decel)
		'If speed > speedMax*throttle
		'	Print "OH FUCK OH FUCK " + name + " speed:"+speed + " forcenum:"+CountList(forceList)
		'	speed = speedMax*throttle
		'EndIf
		'reset throttle to 0, default direction of thrust to forward
		throttle = 0
		thrust_theta = rot
		
		'count down recent damage timer
		If recent_damage_timer > 0 Then recent_damage_timer:- frameTime
		If recent_damage_timer <= 0 Then recent_damage = 0
		
		'count down recent point timer
		If recent_points_timer > 0 Then recent_points_timer:- frameTime
		
		If recent_points_timer <= 0
			recent_points = 0
		ElseIf recent_points_timer <= 4000'count down the recent points
			recent_points = constrain(recent_points - 1, 0, recent_points)
		EndIf
		
		'keep rot b/t 0-359
		If rot < 0 Then rot = rot + 360
		If rot >= 360 Then rot = rot - 360
		If movrot < 0 Then movrot = movrot + 360
		If movrot >= 360 Then movrot = movrot - 360
		
		'physical laws of THIS universe have to do with sound, OK?             -->  ...what? 
		If collide_sfx_countdown > 0 Then collide_sfx_countdown:- frameTime
		
		'update the position of the squadron, pull it towards this ship (weighted towards the current position so last ship doesn't just WIN)
		squad.x = (squad.x*9 + x) / 10
		squad.y = (squad.y*9 + y) / 10

		'update the placeholder's information
		update_placeholder(Self)
		
		'for gfx, ship's radius
		Local rad = SHIPSCALE*(ImageWidth(gfx[0]) + ImageHeight(gfx[0]))/6
		
		'damaged gfx
		If base.debrisType = 0 Or base.debrisType = 1'explode or rock debris
			If onscreen
				If (armour < armourMax/2)
					For Local e = 1 To explodeNum
						If Rand(1,500) = 1
							Local ex:Foreground = add_explode(x+Rand(-rad,rad),y+Rand(-rad,rad))
							If base.debrisType = 1'rock
								ex.gfx = dust_gfx
								ex.alphaspeed:/ 4
								ex.lifetimer = 5000
								ex.animated = False
							EndIf
							ex.RGB[0] = debrisRGB[0]
							ex.RGB[1] = debrisRGB[1]
							ex.RGB[2] = debrisRGB[2]
						EndIf
					Next
				EndIf
			EndIf
		EndIf
		
		'---DESTROYED
		If armour <= 0 Then death(onscreen)'heh onscreen deaths are the only real ones
	EndMethod
	
	'what happens once it's destroyed
	Method death(_onscreen)
		'for gfx, ship's radius
		Local rad = SHIPSCALE*(ImageWidth(gfx[0]) + ImageHeight(gfx[0]))/6
	
		'shake the screen
		Local shake = constrain(1 - (approxDist(x-p1.x,y-p1.y) / SWIDTH), 0, 1) * base.explodeShake
		If shake > 0 Then game.camshake = Max(game.camshake, shake)
	
		'find x and y speed
		Local xspeed = Cos(movrot)*speed
		Local yspeed = Sin(movrot)*speed
	
		'set the color of the debris, explosions
		If debrisRGB[0] = 0 And debrisRGB[1] = 0 And debrisRGB[2] = 0
			debrisRGB[0] = 255
			debrisRGB[1] = 255
			debrisRGB[2] = 255
		EndIf
	
		'explode it
		If _onscreen
			For Local i = 1 To explodeNum/2
				'fast explode
				Local ex:Foreground = add_explode(x+Rand(-rad,rad),y+Rand(-rad,rad),3500)
				ex.movrot = Rand(0,359)
				ex.speed = (RndFloat()+.5)*(speed + 140)
				ex.RGB[0] = debrisRGB[0]
				ex.RGB[1] = debrisRGB[1]
				ex.RGB[2] = debrisRGB[2]
				If base.debrisType = 1'rock
					ex.gfx = dust_gfx
					ex.animated = False
				ElseIf base.debrisType = 2'gib
					ex.gfx = dust_gfx
					ex.RGB[0] = 255
					ex.RGB[1] = 80
					ex.RGB[2] = 80
					ex.speed:/ 4
					ex.lifetimer:* 2.5
					ex.animated = False
				ElseIf base.debrisType = 3'vector
					ex.gfx = trail_gfx
					ex.animated = False
				EndIf
				
				'slow explode
				ex:Foreground = add_explode(x+Rand(-rad,rad),y+Rand(-rad,rad),6500)
				ex.movrot = movrot + Rand(-45,45)
				ex.speed = (speed + 70) * RndFloat()
				ex.RGB[0] = debrisRGB[0]
				ex.RGB[1] = debrisRGB[1]
				ex.RGB[2] = debrisRGB[2]
				If base.debrisType = 1'rock
					ex.gfx = dust_gfx
					ex.animated = False
				ElseIf base.debrisType = 2'gib
					ex.gfx = dust_gfx
					ex.RGB[0] = 255
					ex.RGB[1] = 80
					ex.RGB[2] = 80
					ex.alpha = .5
					ex.speed:/ 4
					ex.lifetimer:* 2.5
					ex.animated = False
				ElseIf base.debrisType = 3'vector
					ex.gfx = trail_gfx
					ex.animated = False
				EndIf
				
				'fire explosion
				If base.debrisType = 0 And (i Mod 2)'half as many
					'bigger explode
					ex:Foreground = add_explode(x+Rand(-rad,rad),y+Rand(-rad,rad),2500)
					ex.movrot = Rand(-0,360)
					ex.speed = (RndFloat()-.5)*100
					ex.gfx = explode5_gfx
					ex.RGB[0] = debrisRGB[0]
					ex.RGB[1] = debrisRGB[1]
					ex.RGB[2] = debrisRGB[2]
					ex.spin:/ 2
				EndIf
			Next
			
			'drop any debris we're carrying
			For Local b:Background = EachIn dropList
				b.x = x + Rand(-rad,rad)
				b.y = y + Rand(-rad,rad)
				
				b.movrot = Rand(0,359)
				b.speed = RndFloat()*170' + speed/2
				Local dspeedx# = Cos(b.movrot)*b.speed + xspeed'add movement vector of the ship to the item
				Local dspeedy# = Sin(b.movrot)*b.speed + yspeed
				b.movrot = ATan2(dspeedy, dspeedx)
				b.speed = approxdist(dspeedx, dspeedy)*RndFloat()*.2
				b.distspeed = RndFloat()/300
				If (TTypeId.ForObject(b) = TTypeId.ForName("Foreground")) Then b.distspeed:* -.5
				
				b.scale = RndFloat()+.5
				
				If Not base.bio Then b.shade:+ Rand(20,110) Else b.shade = 20
				b.RGB[0] = debrisRGB[0]
				b.RGB[1] = debrisRGB[1]
				b.RGB[2] = debrisRGB[2]
				
				b.link = debrisList.addLast(b)
			Next
		EndIf
		If Self <> p1
			If explodeSound <> Null Then playSFX(explodeSound,x,y)
		Else
			playSFX(playerexplode_sfx,x,y)
		EndIf
		'If engineChannel <> Null Then StopChannel(engineChannel)
		'drop whatever items carrying
		For Local t:Item = EachIn dropList
			t.x = x+Rand(-rad/2,rad/2)
			t.y = y+Rand(-rad/2,rad/2)
			t.movrot = Rand(0,359)
			t.speed = (RndFloat()+.5)*300 + speed/2
			If Self <> p1'player's points just go out in a circle around him
				Local ispeedx# = Cos(t.movrot)*t.speed + xspeed'add movement vector of the ship to the item
				Local ispeedy# = Sin(t.movrot)*t.speed + yspeed
				t.movrot = ATan2(ispeedy, ispeedx)
				t.speed = approxdist(ispeedx, ispeedy)+(2*(RndFloat()-.5))
			EndIf
			ClearList(t.proximity_shipList)
			t.lifetimer = POINT_LIFETIME
			t.link = itemList.addLast(t)
		Next
		'drop whatever ships carrying
		'Local dropShipNum
		'For Local t:Ship = EachIn dropList
		'	dropShipNum:+ 1
		'Next
		'Local d 'put stuff in an iterated radius around the destroyed ship
		For Local d:Ship = EachIn dropList
			d.x = x
			d.y = y
			d.movrot = Rand(0,359)
			d.speed = speed * RndFloat()
			d.rot = rot
			d.spin = spin
			d.link = entityList.addLast(d)
		Next
		
		
		'we're done with the droplist
		ClearList(dropList)
		
		'if there's recent damage (likely), transfer that to independent floating text
		If base.ord = False And base.bio = False'missiles & beasties don't do this
			Local txt:Foreground = add_text(Int(recent_damage), x + Cos(recent_damage_theta-15)*ImageWidth(gfx[0])/2, y + Sin(recent_damage_theta-15)*ImageWidth(gfx[0])/2)
			txt.scale = 1.5
		Else'explode ordnance (if it hasn't already exploded due to the collision)
			fireGroup(0)
		EndIf

		'tell the placeholder it's dead
		placeholder.dead = True
		'remove thyself from thy game
		RemoveLink(link)
	EndMethod
	
	'ship-ship collision, handles for both entities
	Method collide(_ship:Ship)
		'bounce!
		Local collision# = transferMomentum(Self,_ship,x,y,_ship.x,_ship.y)
		'EITHER ONE explodes if it's a missile/torpedo
		If base.ord
			fireGroup(False,0)
			Return
		EndIf
		If _ship.base.ord
			_ship.fireGroup(False,0)
			Return
		EndIf
		'do damage
		If behavior <> "inert" Or _ship.behavior <> "inert"
			Local theta# = ATan2(_ship.y - y, _ship.x - x)
			Local cdamage# = (collision / 180) * 4 'the difference in speed between the two ships, normalized to a base amount of speed
			cdamage = Min(cdamage, 3*Min(_ship.armourMax, armourMax))
			
			damage(cdamage, theta, False, False, True)
			_ship.damage(cdamage, theta+180, False, False, True)
		EndIf
		'play sound
		If collide_sfx_countdown <= 0
			If shieldOn Or _ship.shieldOn Then playSFX(reflect_sfx,x,y) Else playSFX(collide_sfx,x,y)
			collide_sfx_countdown = 1000
			_ship.collide_sfx_countdown = 1000
		EndIf
	EndMethod
	
	'this ship takes damage of a certain amount (from a certain direction)
	Method damage(_amt#, _theta = 0, _skipFortify = False, _skipShields = False, _collision = False) ' if _collision = true, this is collision damage
		'shields reflect the damage
		If Not _skipShields And shieldOn
			'tween the shield a bit
			shield_tween = 1
		Else
			If Self = p1 And cheat_invincible Then Return
			If Not _skipFortify
				'apply fortification's damage resistance
				For Local f:Fortification = EachIn fortifyList
					'ramming fortifications only stops collision damage
					If Not f.ramming Or _collision
						If Abs(convert_to_relative(_theta, rot) - f.offset) < f.range/2 Then _amt = constrain(_amt - f.DR, 0, _amt)
					EndIf
				Next
			EndIf
			
			'if there's anything left
			If _amt > 0
			
				'adds up the recent damage
				recent_damage:+ _amt
				'reset the recent damage time
				recent_damage_timer = recent_damage_delay
				'record where it came from
				recent_damage_theta = _theta
			
				'armour takes the damage
				armour = armour - _amt
				
				'tween the ship a bit
				hit_tween = 1
			EndIf
		EndIf


	End Method
	
	'turns the ship towards a target angle (if not absolute, turns towards that angle relative to it's own facing)
	Method turn(_angle#,_absolute = True, _rate = 0)'_rate is an optional override for the turnspeed
		
		'SetColor 255,0,0
		'DrawText Int(_angle),x+game.camx,y+game.camy+20

		Local _turnRate# = turnRate
		If _turnRate = -1 Then _turnRate = 620'fighters turn real fast
		If _rate > 0 Then _turnRate = _rate
	
		'if we're turning towards an absolute angle, convert to a relative angle 
		If _absolute Then _angle = convert_to_relative(_angle,rot)'ASin(constrain(Sin(_angle)*Cos(rot)-Cos(_angle)*Sin(rot), -89,89))

		'SetColor 0,0,255
		'DrawText Int(_angle),x+game.camx,y+game.camy+40

		'change the current heading by turnRate * time passed (tweened a bit for good measure)
		Local turnAmt# = _turnRate * (frameTime/1000.0)
		If Abs(_angle) >= turnAmt#
			rot:+ turnAmt# * Sgn(_angle)
		Else
			turnAmt = Abs(_angle)
			'Local x# = constrain(Abs(_angle)/turnAmt,0,1)
			'Local turn# = (-(x^2) + 2*x)
			'rot:+  turnAmt# * turn * Sgn(_angle)
			rot:+  turnAmt# * Sgn(_angle)
		EndIf
	EndMethod
	
	'adds a direction of thrust to the ship
	Method add_thrust(_angle#,_throttle# = 1, _relative = False)
		'_angle : what angle relative to the ship to thrust
		'_throttle : how much to modify the ship's maxiumum speed by
		'_relative : whether _angle is relative to ship or absolue coords
	
		'see what direction we're currently trying to move
		Local tx# = Cos(thrust_theta) * throttle
		Local ty# = Sin(thrust_theta) * throttle
		
		'find the absolute angle of thrust
		If Not _relative Then _angle:+ rot
		
		'see what direction we're adding now
		Local ax# = Cos(_angle) * _throttle
		Local ay# = Sin(_angle) * _throttle
		
		'add em together
		thrust_theta = ATan2(ty+ay,tx+ax)
		throttle = Max(throttle, _throttle)
	EndMethod
	
	'after all the add_thrusts have been added up, find what direction we finally decided on
	Method resolve_thrust()
		If thrust > 0 And throttle > 0

			'-----EFFECTS-------
		
			Local afterburn = False
			'use up juice when afterburning
			If throttle > 1
				juice:- (frameTime/1000.0)
				If juice < 0 Then juice = 0
				afterburn = True
			EndIf
			'if we're out of juice, we can't afterburn
			If juice <= 0
				throttle = constrain(throttle,0,1.01)
				afterburn = False
			EndIf
			
			'afterburn juicy effects
			If afterburn
				'shake the screen
				game.camshake = Max(game.camshake, RndFloat()/20)
				'reduce camera offset due to mouse
				'game.camoffsetmod = 2.0
				'zoom in a little
				game.zoomtarget = -.015
			EndIf
			
			'overburning?
			If burnerOn Then throttle:* 1.5'go faster
			
			'---------- PHYSICS -------------
	
			'add the pushing force! (ignores base mass of the ship)
			add_force(thrust_theta, thrust * throttle * base.mass)
			
			'-------- TRAIL EFFECT -----------
			'if player or we're going FAST or we're a missile	' or it's time
			If Self = p1 Or burnerOn Or base.ord				' Or Rand(1,3) = 1
				'if onscreen
				If Abs(x-p1.x) < SWIDTH*dist And Abs(y-p1.y) < SHEIGHT*dist
					'trail gfx
					Local length# = (speed / speedMax) * base.trailScale ' scale of trail
					Local lifetime = 1000
					If Self = p1 Then lifetime = 2000
					
					'engines make trails
					For Local c:Component = EachIn compList
					If c.class = "engine"
						'find the width of the component
						Local wid = 0
						For Local x = 0 To 4
						For Local y = 0 To 4
							If c.shape[x,y] = 1
								wid = x
								Exit
							EndIf
						Next
						Next
					
						wid = Floor(wid/2)			'set wid to how many tiles to offset sideways
						wid:* Sgn(c.x - (cshapedim-1)/2)	'and now the direction
					
						Local offsetx = (c.x - wid - (cshapedim-1)/2)*cshaperatio
						Local offsety = (c.y - (cshapedim-1)/2)*cshaperatio + 5
						
						'find the current relative position of the engine
						Local ex# = (-offsety*Sin(rot+90) + offsetx*Cos(rot+90))*SHIPSCALE
						Local ey# = (offsetx*Sin(rot+90) + offsety*Cos(rot+90))*SHIPSCALE
						
						Local trail:Background = add_trail(x + ex, y + ey, movrot, length, base.trailRGB, afterburn, lifetime)
						trail.alpha = alpha
						
						'if overburning, leave a trail of destruction
						If burnerOn
							Local exhaust:Shot = add_shot:Shot(Self,"flame",explode1_gfx, x+ex, y+ey,0,0,0,1)
							exhaust.movrot = movrot+180+Rand(-30,30)
							exhaust.speed = speed/2
							exhaust.RGB[0] = Rand(100,170)
							exhaust.RGB[1] = Rand(140,200)
							exhaust.RGB[2] = Rand(140,200)
							exhaust.scale = (RndFloat()+.5)/2
							exhaust.hit_gfx = Null
							exhaust.hit_sfx = Null
							If burnerOn
								exhaust.lifetimer = 1200
							EndIf
							exhaust.trail = False
							exhaust.durable = True
							exhaust.alpha:/ 3
						EndIf
					EndIf
					Next
					
				EndIf
			EndIf
			
			'animate engines!
			animated = True
		EndIf
	EndMethod
	
	'spend a point to use an ability
	Method activateAbility()
		If points > 0
			Select base.ability
			Case ABILITY_SHIELD
				'if it's not already on and we still have a shield point
				If Not shieldOn
					shield_timer = shield_duration
					shield_tween = 2
					points:- 1	'use up an ability point
				EndIf
				
			Case ABILITY_BLINK
				Local tarx, tary
				'if the player
				If Self = p1
					'if we've just pressed it
					If Not blinkOn
						blinkOn = True
						
						'become intangible
						ignorePhysics = True		'whether this entity should listen to the forces on it
						ignoreCollisions = True	'whether this entity participates in any collisions
						ignoreMovement = True		'whether this entity should move
						skipDraw = True
						cloakOn = True
						game.disable_controls = True
						
						blink_timer = 200
						
						points:- 1	'use up an ability point
					
						'make an effect
						Local	fade:Foreground = New Foreground
						Local fadegfx:TImage[1]
						fadegfx[0] = base.hitgfx
						fade.gfx = fadegfx
						fade.animated = False
						fade.x = x
						fade.y = y
						fade.rot = rot
						fade.alpha = 0
						fade.alphaspeed = .15
						fade.lifetimer = 200
						fade.link = bgList.addFirst(fade)
					
					Else'choose where to go
						blink_timer = 0
					EndIf
					
				Else
					'go randomly
					x:+ Rand(-800,800)
					y:+ Rand(-800,800)
				EndIf
				
			Case ABILITY_BURNER
				If Not burnerOn
					burner_timer = burner_duration
					points:- 1	'use up an ability point
				EndIf	
				
			Case ABILITY_CLOAK
				If Not cloakOn
					cloak_timer = cloak_duration
					points:- 1	'use up an ability point
				EndIf
				
			Case ABILITY_OVERCHARGE
				If Not overchargeOn
					overcharge_timer = overcharge_duration
					points:- 1	'use up an ability point
				EndIf	
			EndSelect
			
		Else'if was already out of points
			Return
		EndIf
		
		If points <= 0
			Local abilityName$ = String(MapValueForKey(abilityMap, String(base.ability)))
			Local depleted:Background = add_text(abilityName$ + " depleted!",x+20,y, 2400)
			depleted.RGB[0] = 255
			depleted.RGB[1] = 255
			depleted.RGB[2] = 255
		EndIf
	EndMethod
	
	Method repair(_amt#)	'restore certain amount hull damage
		armour = armour + _amt
		If armour > armourMax Then armour = armourMax
	End Method
	
	'warps in at the provided gate, adding self to the game with a bang (can NOT be used if we're already in entityList, we'll be added twice!!!)
	'- OR - can warp in at any spot we choose if we provide coords instead (returns the warp item if this is the case
	Method warp_in:Item(_gate:Item,_warpx=0,_warpy=0,_warptime=0)
		'like triple-check to make sure they're removed
		ListRemove(entityList,Self)
		link = Null
		
		'warp in at a gate
		If _gate <> Null
			'just to put the camera there
			x = _gate.x
			y = _gate.y
			'start the timer for warping in (if it's not already counting for something else)
			If _gate.state[0] <= 0
				If _warptime = 0 Then _gate.state[0] = _gate.state[1] Else _gate.state[0] = _warptime
			EndIf
			'add self to the warp list
			_gate.thingList.addLast(Self)
		
		'warp in at a position
		Else
			'just to put the camera there
			x = _warpx
			y = _warpy
			rot = 180
		
			'make an independant warp item that kinda does the same thing as the gate
			Local warp:Item = New Item
			warp.name = "warp"
			warp.gfx = warp3_gfx
			warp.animated = False
			warp.ignoreCollisions = True
			warp.ignorePhysics = True
			warp.ignoreMovement = True
			warp.scale = .1
			warp.mass = 10000
			warp.x = _warpx
			warp.y = _warpy-10
			warp.rot = 90
			warp.lifetimer = 0
			warp.state[1] = Sqr(mass) * 350 * (RndFloat()+.5)'how long it takes to warp in this ship
			If _warptime > 0 Then warp.state[1] = _warptime
			warp.state[0] = warp.state[1]
			warp.thingList.addLast(Self)'add self to warp list
			
			'store the ratio between the graphic sizes
			warp.state[2] = Float((ImageWidth(gfx[0]) + ImageHeight(gfx[0])) / 2) / Float(ImageWidth(warp3_gfx[0]))
			
			warp.link = itemList.addLast(warp)
			
			'play a noise
			playSFX(warpcharge_sfx, warp.x, warp.y)
			
			Return warp
		EndIf
	EndMethod
	
	'predicts the position of ship's target in x,y ; returns an array of size [2] w/ the information in that order
	'time of target travel is determined by how long it would take provided group's bullet to hit them - OR - a custom provided speed
	Method predictTargetPos#[](_group,_shotspeed = 0)
		If target <> Null
			'find distance,angle from self
			Local tar_dist# = Sqr((x - target.x)^2 + (y - target.y)^2)
			Local tar_theta# = ATan2((y - target.y),(x - target.x))
		
			'find para,perp speed of target
			Local s_para# = Cos(target.movrot - tar_theta) * target.speed
			Local s_perp# = Sin(target.movrot - tar_theta) * target.speed
			
			'find how long it'd take for a bullet to reach the target, if it travels at it's shot speed - the movement of the target
			Local shot_speed
			If _shotspeed = 0 Then shot_speed = speedGroup(_group) Else shot_speed = _shotspeed
			Local shot_time# = tar_dist / Abs(shot_speed - s_para)
			'the perpendicular distance they'll have traveled in that time
			Local travel_dist# = Abs(s_perp*shot_time)'Sqr((s_para*shot_time)^2+(s_perp*shot_time)^2)
			
			'find the change in position the target would then be in
			Local tar_p#[2]
			tar_p[0] = target.x - Sin(target.movrot+90)*(-travel_dist)'X COORD
			tar_p[1] = target.y + Cos(target.movrot+90)*(-travel_dist)'Y COORD
			
			'if AI tries to shoot behind itself, take absolute value
			'If behavior <> "player"
			'	Print "inverting!"
			'	Local rel_theta# = convert_to_relative(ATan2(y-tar_p[1], x-tar_p[0]), rot)
			'	If Abs(rel_theta) > 90
			'		'invert the angle, so we're shooting ahead instead
			'		rel_theta = (180 - Abs(rel_theta)) * Sgn(rel_theta)
			'		'find the old distance
			'		Local old_dist# = Sqr((x-tar_p[0])^2+(y-tar_p[1])^2)'approx_dist(x-tar_p[0],y-tar_p[1])
			'		'find the new predict coords
			'		tar_p[0] = Cos(rel_theta+rot)*old_dist
			'		tar_p[1] = Sin(rel_theta+rot)*old_dist
			'	EndIf
			'EndIf
	
			Return tar_p
		EndIf
	EndMethod
	
	'fires a weapongroup
	Method fireGroup(_group,_tarx#=0,_tary#=0)
		If Not ListIsEmpty(gunGroup[_group])
			'TARGETING
			'figure out the absolute coords we want to hit
			Local fx#,fy#
			'use provided coords if available
			If (_tarx<>0) Or (_tary<>0)
				fx = _tarx
				fy = _tary
			'otherwise, shoot at the current target's predicted position
			ElseIf target <> Null
				Local tar_p#[] = predictTargetPos(_group)
				fx = tar_p[0]
				fy = tar_p[1]
			'otherise, just shoot straight forward
			Else
				Local range = 500
				fx = x + Cos(rot)*range
				fy = y + Sin(rot)*range
			EndIf
			
			'AI have trouble shooting moving targets
			'If Self <> p1 And target <> Null
			'	Local jitter = 150*target.AI_predict
			'	fx:+ Rand(-jitter,jitter)
			'	fy:+ Rand(-jitter,jitter)
			'EndIf
			
			'find if we need to do some alternating fire shindig (group things by their firedelay, offset em)
			'only PRIMARY guns alternate-fire
			If _group = 0
				Local alterList:TList = New TList
				For Local g:Gun = EachIn gunGroup[_group]
					Local added = False	'whether we added to an existing group
					Local groupname$		'the gun name for this group
					'look for a group that already has this firedelay, add self to it if applicable
					For Local gList:TList = EachIn alterList
						'find the firedelay for this group
						Local mintime, delaytime
						For Local a:Gun = EachIn gList
							mintime = a.fireDelay_timer'record the current lowest firedelay in this group
							groupname = a.name
							delaytime = a.fireDelay
							Exit
						Next
						'add to this group?
						If g.name = groupname And g.fireDelay = delaytime
							'bump to the front of the list if it has the lowest time to fire
							If g.fireDelay_timer < mintime Then gList.addFirst(g) Else gList.addLast(g)
							added = True
						EndIf
					Next
					'if we couldn't find one, make one
					If Not added
						Local gList:TList = New TList
						gList.addLast(g)
						alterList.addLast(gList)
					EndIf
				Next
				
				'fire the guns! offset other guns in the group by a minimum amount if applicable
				For Local gList:TList = EachIn alterList
					Local i = 0
					For Local g:Gun = EachIn gList
						'offset all the OTHER guns in the group
						If g.fireDelay_timer <= 0
							For Local a:Gun = EachIn gList
								If (a <> g) Then a.fireDelay_timer = Max(g.fireDelay/CountList(gList),a.fireDelay_timer)'
							Next
						EndIf
						
						'fire the gun!
						g.fire(Self,fx,fy)
						
						i:+ 1
					Next
				Next
			Else
			
				'just shoot the fucking things
				For Local g:Gun = EachIn gunGroup[_group]
					g.fire(Self,fx,fy)
				Next
			EndIf
			
		EndIf
	EndMethod
	
	'returns maximum range of a weapongroup
	Method rangeGroup(_group)
		
		Local maxRange = 0
		For Local g:Gun = EachIn gunGroup[_group]
			If g.shotrange > maxRange Then maxRange = g.shotrange
		Next
		Return maxRange
	EndMethod
	
	'returns maximum bullet's speed of a weapongroup
	Method speedGroup(_group)
		Local maxSpeed = 0
		For Local g:Gun = EachIn gunGroup[_group]
			If g.shotspeed > maxSpeed Then maxSpeed = g.shotspeed
		Next
		Return maxSpeed
	EndMethod
	
	'returns minimum rotational freedom of a weapongroup
	Method freedomGroup(_group)
		Local maxFreedom = 0
		For Local g:Gun = EachIn gunGroup[_group]
			maxFreedom = Max(g.freedom, maxFreedom)
		Next
		Return maxFreedom
	EndMethod
	
	'returns average firing delay of a weapongroup
	Method rateGroup(_group)
		Local rate = 0
		For Local g:Gun = EachIn gunGroup[_group]
			If rate = 0 Then rate = g.fireDelay Else rate = (rate + g.fireDelay)/2
		Next
		Return rate
	EndMethod
	
	'targets the closest other enemy ship (closest to given point, that is; defaults to ship's position)
	Method target_closest(_x=0,_y=0,_enemiesOnly = True)
		If _x = 0 And _y = 0
			_x = x
			_y = y
		EndIf	
		target = Null
		For Local o:Ship = EachIn entityList
		If Not o.cloakOn
			Local opinion = fTable[squad.faction,o.squad.faction]'what does this ship think of this other ship? (-1 enemy, 0 neutral, 1 ally)
		
			If opinion = -1' Or (_enemiesOnly = False And opinion <> 1)
				'if lacking a target, take the first one we see
				If target = Null Then target = o.placeholder
				'if this new target is closer than the old one
				If approxDist(o.x-_x,o.y-_y) < approxDist(target.x-_x,target.y-_y) And (target.ord Or Not o.base.ord)
					target = o.placeholder
					'if the new target is better or the same as the old one (in terms of neutral/ordnance)
					'If opinion <= fTable[squad.faction,target.faction] Then 
				EndIf
				'if the old target is a missile
				If approxDist(o.x-_x,o.y-_y) < squad.detect_dist And (target.ord) Then target = o.placeholder
			EndIf
		EndIf
		Next
	EndMethod
	
	'adds a component to the ship (_absolute = FALSE : the component will be added at the x,y absolute coordnates, otherwise rel. to center)
	Method add_comp(_compName$,_x=0,_y=0, _locked = False, _absolute = False)
		'x,y input are offset from center
		Local cx = Floor(cshapedim / 2)
		Local cy = Floor(cshapedim / 2)
		
		'no offset of the provided coords are absolute
		If _absolute
			cx = 0
			cy = 0
		EndIf
		
		'make the component
		For Local c:Component = EachIn componentList
			If c.name = _compName
				Local ac:Component = new_comp(c.name)
				ac.x = cx + _x
				ac.y = cy + _y
				ac.locked = _locked
				compList.addLast(ac)
			EndIf
		Next
		recalc()
	EndMethod
	
	'sets contained compoenents to that of a loaded configuration (returns TRUE if loaded successfully)
	Method load_config(_config$)
		'strip the old components away
		ClearList(compList)
		
		'Print "trying to load "+name+": '"+_config+"'"
	
		'null configs just restore back to chassis state
		If Lower(_config) = "null"
			'Print "    null state set!"
		
			For Local comp:Component = EachIn base.compList
				compList.addLast(comp)
			Next
			'recalculate ship's shape information
			cshape_recalc()
			'recalculate stats
			recalc()
			'successfully loaded null!
			config = _config
			Return True
		Else
			'load from file
			Local filename$ = "configs/"+name+"_"+Lower(_config)
			
			'see if a global, non-pilot-associated config of this name exists
			If FileType(filename+".conf") <> 0
				'Print "                GLOBAL"
				'Exit
			
			'check if a pilot-associated one of this name exilsts
			ElseIf pilot <> Null
				filename = filename + "_" + Lower(pilot.name)
				If FileType(filename+".conf") <> 0
					'Print "                PILOT SPeCIFIC"
					'Exit
				
				ElseIf _config <> "default"'FAILURE TO FIND _CONFIG
					'if we're are not already trying to load default
					'Print "could not load config:'"+filename+".conf'"
					'see if we can load the default
					Return load_config("default")
				EndIf
			EndIf
			
			'if we got this far, this filename is a valid config!
			filename = filename + ".conf"
			'Print "    loading file: '"+filename+"'"
			
			If FileType(filename) > 0'just to make sure
				Local cFile:TStream = ReadFile(filename)
					'LOAD CONFIGURATION
					'load the color
					scheme = ReadByte(cFile)
					While Not Eof(cFile)
						'make the new component
						Local ac:Component = New Component
						ac.loadSelf(cFile)
						compList.addLast(ac)
					Wend
					'set the configuration to the new name
					config = _config
					'recalculate ship's shape information
					cshape_recalc()
					'recalculate stats, color
					color = -1
					recalc()
				CloseFile cFile
				Return True'successfully loaded!
				
			ElseIf Lower(_config) <> "default"'if we're not already trying to load the default
				'see if we can load the default
				config = "default"
				load_config(config)

			Else'if we can't load the default, load the null and save THAT as the default
				Print "Couldn't load '" + _config + "' -OR- default for "+name+", saving null as default."
				load_config("null")
				config = "default"
				save_config(True)
			EndIf
		EndIf
	EndMethod
	
	'saves current compoenents to file
	Method save_config(_globalSave = False)'if TRUE, can save global configuration
		Local pname$
		If pilot <> Null Then pname = Lower(pilot.name)
	
		Local permission = False'do we have permission to save this configuration?
		If (config <> "default") Or (pname = "wik") Or (_globalSave) Then permission = True	'only wik or special permission can save default
	
		If config <> "" And permission
			Local filename$ = "configs/"+name+"_"+Lower(config)			'	"shiptype_configurationname"
			If (pname <> "wik") Then filename = filename + "_" + pname	'	"_pilotname" 					(wik does not record that he did this)
			filename = filename + ".conf"								'	".conf"
			
			Print "saving '" + filename + "' For ship " + name + " in configuration " + config
		
			'delete the old file
			DeleteFile(filename)
			'make the new file
			CreateFile(filename)
			'write to the new file
			Local cFile:TStream = WriteFile(filename)
				'save the color
				WriteByte(cFile, scheme)
				'SAVE COMPONENTS
				For Local ac:Component = EachIn compList
					ac.saveSelf(cFile)
				Next
			CloseFile cFile
		EndIf
	EndMethod
	
	'resets the ship back to its pristine state: max armour & ability points, NO SQUADRON (*need* to reinit that)
	Method reset()
		recalc()
		armour = armourMax
		points = pointMax
		juice = juiceMax
		shield_timer = 0
		shield_tween = 0
		hit_tween = 0
		alpha = 0
		shade = 0
		dist = 1
		spin = 0
		scale = 1
		throttle = 0
		recent_damage = 0
		recent_damage_timer = 0
		recent_points = 0
		recent_points_timer = 0
		shieldOn = False
		shield_timer = 0
		burnerOn = False
		burner_timer = 0
		blinkOn = False
		blink_timer = 0
		cloakOn = False
		cloak_timer = 0
		overchargeOn = False
		overcharge_timer = 0
		placeholder.dead = False
		'If engineChannel <> Null Then SetChannelVolume engineChannel,0
		target = Null
		AI_timer = 0
	EndMethod
	
	'recalculate max ability points, speed, turnspeed, armour, accel based on the chassis + configuration
	Method recalc()
		thrust = base.thrust
		speedMax = base.speedMax
		pointMax = base.points
		armourMax = base.armour
		juiceMax = base.juice
		mass = base.mass
		strafe = base.strafe
		
		ClearList(fortifyList)
		
		'add any fortifications of the base
		For Local f:Fortification = EachIn base.fortifyList
			fortifyList.addLast(new_fortify(f.DR, f.range, f.offset, f.ramming))
		Next
		
		'make the gungroups
		For Local wgroup = 0 To 5
			gunGroup[wgroup] = New TList
		Next
		
		'components?
		For Local c:Component = EachIn compList
			Local gun_damageBonus# = 1.0, gun_shotspeedBonus#, gun_burstBonus, gun_recycleBonus#
			'if this component is plugged in (or doesn't need to be)
			If c.plugged
				mass:+ c.mass
				armourMax:+ c.armourBonus
				pointMax:+ c.pointBonus
				speedMax:+ c.engineBonus
				thrust:+ c.thrustBonus
				juiceMax:+ c.juiceBonus
				
				'add any fortifications of this component
				If c.fortify > 0 Then fortifyList.addLast(new_fortify(c.fortify, c.fortify_range, c.fortify_offset, c.fortify_ramming))
				
				'if this component has any base gun bonuses
				If c.damageBonus > 0 Then gun_damageBonus:* c.damageBonus
				gun_burstBonus:+ c.burstBonus
				gun_recycleBonus:+ c.recycleBonus
				gun_shotspeedBonus:+ c.shotspeedBonus
				
				'addons augment this component's guns
				For Local add:Component = EachIn c.addonList
					If add.damageBonus > 0 Then gun_damageBonus:* add.damageBonus
					gun_burstBonus:+ add.burstBonus
					gun_recycleBonus:+ add.recycleBonus
					gun_shotspeedBonus:+ add.shotspeedBonus
				Next
		
				'make the guns
				For Local g:Gun = EachIn c.gunList
					Local ox = (c.x - (cshapedim-1)/2)*cshaperatio
					Local oy = (c.y - (cshapedim-1)/2)*cshaperatio
					Local ng:Gun = new_gun(g.name,ox,oy)
					g.dispname = c.name
					ng.shotdamage:* gun_damageBonus
					ng.shotspeed:+ gun_shotspeedBonus
					ng.burstNum:+ gun_burstBonus
					ng.fireDelay:+ gun_recycleBonus
					If ng.fireDelay < 10 Then ng.fireDelay = 10
					
					If Not c.alt	'primary weapon
						gunGroup[0].addLast(ng)
					Else			'alternate weapon
						For Local i = 1 To 5
							'if we've gotten to an empty list w/o finding an OK group
							If ListIsEmpty(gunGroup[i]) Or i = 5
								gunGroup[i].addLast(ng)
								Exit
							Else
								'is THIS group OK?
								Local ok = False
								For Local altgun:Gun = EachIn gunGroup[i]
									'does this gun belong here?
									If altgun.name = ng.name
										gunGroup[i].addLast(ng)
										ok = True
									EndIf
								Next
								If ok Then Exit
							EndIf
						Next
					EndIf
				Next
			EndIf
		Next
		
		points = pointMax
		armour = armourMax
		
		'figure out turnrate based on chassis, current mass
		If base.turnRate <> -1 Then turnRate = base.turnRate * (base.mass / mass) Else turnRate = base.turnRate
				
		'recolor the thing
		If color <> scheme'does the current color match the scheme?
			'recolor the graphic with it
			gfx = recolorAnimImage(base.gfx, scheme, 2)
			'record that we have done so
			color = scheme
		EndIf
	EndMethod
	
	'fills cshape based on the current components in compList
	Method cshape_recalc()
		'clear the current shape data
		For Local x = 0 To cshapedim-1
		For Local y = 0 To cshapedim-1
			cshape[x,y] = base.cshape[x,y]
		Next
		Next
		
		'fill up the spaces this component tiles
		For Local c:Component = EachIn compList
			For Local cy = 0 To 4
			For Local cx = 0 To 4
				'if the component takes this tile up
				If c.shape[cx,cy] = 1
					'adjust for rotation
					Local cr[2]
					cr = rotAdjust(cx,cy,c.rot)
					'is it within bounds?
					If c.x+cr[0] < cshapedim And c.x+cr[0] >= 0 And c.y+cr[1] < cshapedim And c.y+cr[1] >= 0
						'fill this tile up
						cshape[c.x+cr[0],c.y+cr[1]] = -Abs(base.cshape[c.x+cr[0],c.y+cr[1]])
					EndIf
				EndIf
			Next
			Next
			
			ClearList(c.addonList)'clear any components that are added to this one, we'll re-add them in a second
		Next
		
		'attach addon tiles
		For Local c:Component = EachIn compList
			For Local cy = 0 To 4
			For Local cx = 0 To 4	
				'if this component has an attactment tile at this space
				If c.addon And c.shape[cx,cy] = 2
					'overlappers?
					For Local a:Component = EachIn compList
					If c.class = a.class And Not a.addon'if it's the right class and not an addon itself (heaven forbid addon-on-addon action!)
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

	EndMethod
EndType
Include "shipAI.bmx"

'a placeholder object to fill up the AI's proximity lists so we don't get memory leaks
Type Gertrude
	Field x,y
	Field speed#
	Field movrot#,rot#
	Field faction
	Field invulnerable
	Field cloakOn
	Field behavior$		'the ship's current behavior
	Field ord			'is this ship ordnance?
	Field dead = False	' the ship sets this to TRUE when it dies
EndType
'updates a ship's placeholder information
Function update_placeholder(_ship:Ship)
	_ship.placeholder.x = _ship.x
	_ship.placeholder.y = _ship.y
	_ship.placeholder.speed = _ship.speed
	_ship.placeholder.movrot = _ship.movrot
	_ship.placeholder.rot = _ship.rot
	_ship.placeholder.faction = _ship.squad.faction
	_ship.placeholder.invulnerable = _ship.invulnerable
	_ship.placeholder.behavior = _ship.behavior
	_ship.placeholder.ord = _ship.base.ord
	_ship.placeholder.cloakOn = _ship.cloakOn
EndFunction

Include "guncontrol.bmx"

'a thing that does a thing when you touch it
Const POINT_LIFETIME = 14000
Global itemList:TList = New TList
Type Item Extends Entity
	Field name$
	Field lifetimer#
	'Field comp:Component			'item to add to inventory when picked up
	Field state#[8]				'used by different items for things
	Field thingList:TList = New TList	'used by different items for listing different things (eg, ships to warp in)	
	
	Method update()
	
		'If link = Null Then Print name+ " has null link during update! " 
	
		'is it a good day to die?
		If lifetimer <> 0
			lifetimer = lifetimer - frameTime
			If lifetimer <= 0
				RemoveLink(link)
				Return False
			EndIf			
		EndIf
		
		'pop a cap in that speed
		speed = constrain(speed,0,1000)
	
		'should it get sucked towards ships?
		Local shipmagnet = False
		
		'components can get picked up
		'If comp <> Null Then shipmagnet = True
		
		'points can get picked up (eventually)
		If (name = "point" Or name = "life" Or name = "abilitypoint") And state[0] = 1 Then shipmagnet = True
		
		'move towards ship
		If shipmagnet
			'For Local s:Gertrude = EachIn proximity_shipList
			'If s.behavior <> "inert" And s.behavior <> "missile" And s.behavior <> "torpedo"'if it's a ship that picks up things
				'If s = p1.placeholder'only the player can pick them up
					'Local ship_theta# = ATan2(y-s.y,x-s.x)
					'Local ship_dist# = approxDist((x-s.x),(y-s.y))
					
					'only care about the player
					Local ship_theta# = ATan2(y-p1.y,x-p1.x)
					Local ship_dist# = approxDist((x-p1.x),(y-p1.y))
					
					If ship_dist <= 430 And ListContains(entityList, p1)
						'move towards the ship
						Local pull# = constrain(500 - ship_dist/4, 0, 500)
						If pull > 0
							Local x_speed# = Cos(movrot)*speed
							Local y_speed# = Sin(movrot)*speed
							Local x_thrust# = -Cos(ship_theta)*pull
							Local y_thrust# = -Sin(ship_theta)*pull
							
							'average the two
							Local x_avg = (x_speed+x_thrust)/2
							Local y_avg = (y_speed+y_thrust)/2
							
							'accel to the new speed, rotation
							speed = approxDist(x_avg,y_avg)
							movrot = ATan2(y_avg,x_avg)
						EndIf
					EndIf
				'EndIf
			'Next
		EndIf
		
		'points explode outwards, decelerate, then can get picked up
		If name = "point" Or name = "life" Or name = "abilitypoint"
			'proximity_track = True
			
			'decelerate
			speed:- speed*(frameTime/700)
			
			'fade out when they're about to die
			alpha = 1 - constrain(lifetimer / 1200, 0, 1)
			
			'flip to pickupable mode
			If speed <= 50 Then state[0] = 1
		EndIf
		
		'abilitypoints have glowy background
		'If name = "abilitypoint" And globalFrameSwitch
		'	Local	glow:Background = New Background
		'	glow.gfx = warp3_gfx
		'	glow.animated = True
		'	glow.x = x
		'	glow.y = y
		'	glow.rot = Rand(0,359)
		'	glow.movrot = movrot
		'	glow.speed = speed
		'	glow.spin = -Rand(6,12)
		'	glow.scale = (RndFloat()+.5)/3
		'	glow.scalespeed = .06
		'	glow.alpha = .3
		'	glow.alphaSpeed = .02
		'	glow.lifetimer = 700
			'glow.RGB[0] = 255
			'glow.RGB[1] = 255
			'glow.RGB[2] = 0
		'	glow.link = bgList.addLast(glow)
		'EndIf
		
		'beacons change color depending on state[1]
		If name = "beacon"
			If state[1] = 0'beacon state[1] = normal, red
				RGB[0] = 240
				RGB[1] = 80
				RGB[2] = 10
			ElseIf state[1] = 1'beacon state[1] = 1 ACTIVATED, orange
				RGB[0] = 240
				RGB[1] = 150
				RGB[2] = 10
			ElseIf state[1] = 2'beacon state[1] = 2: inactivated, grey
				resetRGB()
			ElseIf state[1] = 3'beacon state[1] = 3: kill it! fade out
				Local	fade:Background = New Background
				fade.gfx = gfx
				fade.animated = animated
				fade.x = x
				fade.y = y
				fade.rot = rot
				fade.scale = scale
				fade.dist = dist
				fade.distspeed = .005'sucked down
				fade.distShade = True
				fade.alpha = 0
				fade.alphaSpeed = .02
				fade.lifetimer = 700
				fade.link = bgList.addLast(fade)
				'play a noise
				playSFX(beacon_sfx,x,y)
				'kill the beacon
				RemoveLink(link)
			EndIf
			
			'default to not colliding with anything
			state[0] = 0
		EndIf
		
		'gates, wormhols warp their ships in
		If name = "gate" Or name = "warp" And Not ListIsEmpty(thingList)
			'STATES for WARPS and GATES:
			'state[0]: warp countdown timer
			'state[1]: time it takes to warp in
			'state[2]: for individual warpings, the ratio between ship's gfx and own
			
			'did the gate JUST start warping in?
			If state[0] = state[1]
				'gate spawns a big glowy blue effect
				If name = "gate"
					Local warp:Foreground = add_explode(x,y+10,state[1]+200)
					warp.gfx = warp_gfx
					warp.rot = rot+180
					warp.spin = 0
					warp.alpha = 0
					warp.alphaSpeed = 0'10 / state[1]
					warp.scale = .1
					warp.scalespeed = 75 / state[1]
					warp.blend = LIGHTBLEND
					warp.ignorePhysics = True
				'point warp spawns a whole bunch of more transparent versions
				ElseIf name = "warp"
					For Local i = 0 To 6
						Local warp:Foreground = add_explode(x,y,0)
						warp.gfx = warp3_gfx
						warp.rot = rot+35*i+Rand(-90,90)
						warp.spin = -Rand(2,15)
						warp.alpha = (RndFloat()+1)/2
						warp.alphaSpeed = -.5 / state[1]
						warp.scale = RndFloat()/3
						warp.scalespeed = RndFloat() * 75 / state[1]
						warp.ignorePhysics = True
						If Rand(0,1) Then warp.blend = LIGHTBLEND Else warp.blend = ALPHABLEND
						'start tracking these effects
						thingList.addLast(warp)
					Next
				EndIf
				
				'white version of the ship fade in
				For Local s:Ship = EachIn thingList
					Local	fade:Foreground = New Foreground
					Local fadegfx:TImage[1]
					fadegfx[0] = s.base.hitgfx
					fade.gfx = fadegfx
					fade.animated = False
					fade.x = x
					fade.y = y'+ImageHeight(fade.gfx[0])/4
					fade.rot = rot+180
					fade.scale = .1
					fade.scalespeed = 25 / state[1]
					fade.lifetimer = state[1]
					fade.link = bgList.addFirst(fade)
					Exit
				Next
				
				'play a noise
				playSFX(warpcharge_sfx,x,y)
			EndIf
			
			'warping thingies rotate, get bigger
			If name = "warp"
				Local warptween# = (state[0] / state[1])
				'the bigger the ship is and the closer we are to warping, the bigger the portal
				scale = .8 + (1 - warptween) * state[2]
				rot:- (180 + 360*(warptween^2))*(frameTime/1000)
				alpha = constrain(warptween^2, 0, .5)
			EndIf
			
			'count down the timer (ship.warp_in() sets it initially to state[1])
			state[0]:- frameTime
			'time to warp?
			If state[0] <= 0
				For Local s:Ship = EachIn thingList
					'warp in the ship
					s.reset()
					s.x = x
					s.y = y
					If s = p1
						s.speed = s.speedMax*2
						'find the angle to warp (at the mouse)
						Local m_dx# = (cursorx - (p1.x+game.camx))
						Local m_dy# = (cursory - (p1.y+game.camy))
						Local m_theta# = ATan2(m_dy,m_dx)
						'go that way
						s.movrot = m_theta
						s.rot = m_theta
					EndIf
					ClearList(s.forceList)
					If name = "gate"
						s.speed = 12
						s.movrot = rot+180
						s.rot = s.movrot
					EndIf
					s.hit_tween = 8
					s.link = entityList.addLast(s)
					'make some sparks
					If name = "gate"
						For Local i = 0 To 55
							Local zap:Background = add_particle(x,y,rot+Rand(-80,80),(RndFloat()+.5)*4,Rand(800,1800),Rand(0,1))
							zap.scale:+ RndFloat()
							If Rand(0,1) Then zap.blend = LIGHTBLEND
						Next
					EndIf
					'play a noise
					playSFX(warp_sfx,x,y)
					'reset timer if we need to
					If CountList(thingList) > 1 Then state[0] = state[1]
					'only warp in the first one
					ListRemove(thingList,s)
					Exit
				Next
				
				'if it's not a gate
				If name = "warp"
					'suck all the effects back in
					For Local warp:Foreground = EachIn thingList
						warp.lifetimer = Rand(400,800)
						warp.scalespeed = -75 / warp.lifetimer
						warp.alphaspeed = 1.5 / warp.lifetimer
						warp.spin = -warp.spin
					Next
					
					'it dies now
					RemoveLink(link)
				EndIf
			EndIf
		EndIf
				
	EndMethod
	
	Method collide(_ship:Ship)
		'should ships pick it up?
		Local shippickup = False
		
		'If link = Null Then Print name+ " has null link START collision with "+_ship.name
		
		'components can get picked up
		'If comp <> Null Then shippickup = True
		
		'points can get picked up
		'If name = "point" Then shippickup = True
	
		'points, lives, abilitypoints can get picked up by the player only
		If (name = "point" Or name = "life" Or name = "abilitypoint") And (_ship = p1) Then shippickup = True
	
		'picked up by ship, and not already removed from the field
		If shippickup And ListContains(itemList,Self)
			'If _ship.behavior <> "inert" And _ship.base.ord = False'if it's a ship that picks up things  'player can pick up anything
				'make a foreground effect of picking up the item
				Local	fade:Foreground = New Foreground
				fade.gfx = gfx
				fade.animated = animated
				fade.x = x
				fade.y = y
				fade.rot = rot
				fade.scale = scale
				fade.dist = dist
				fade.distspeed = -0.02'sucked up
				fade.distShade = False
				fade.alpha = .4
				fade.alphaSpeed = .05
				fade.lifetimer = 100
				fade.spin = 8*(RndFloat()-.5)
				fade.link = explodeList.addLast(fade)
				
				'play sound
				playSFX(point_sfx,x,y)
				
				'if the player picked up a point
				If name = "point"
					_ship.recent_points:+ 1
					_ship.recent_points_timer = _ship.recent_points_delay
				EndIf
				
				'if the player picked up a life
				If name = "life"
					If _ship = p1
						game.lives:+ 1'add one life
						add_text("+1 ship",p1.x,p1.y,3000,False)
						_ship.hit_tween = 1'visually confirm pickup
						playSFX(point_sfx,x,y)'play sound
					EndIf
				
				'if the player picked up an ability point recharge
				ElseIf name = "abilitypoint"
					'If _ship = p1
						_ship.points = constrain(_ship.points + 1, 0, _ship.pointMax)'recharge one use
						_ship.hit_tween = 1'visually confirm pickup
						playSFX(point_sfx,x,y)'play sound
					'EndIf
					
				Else'everything else can get re-dropped
				
					'add thyself to the ship
					_ship.dropList.AddLast(Self)
				EndIf
				
				'if the player picked up an ability recharge
				'If _ship = p1 And name = "abilitypoint" Then p1.points = constrain(p1.points+1, 0, p1.pointMax)
				
				'remove thyself from the field
				If link <> Null Then RemoveLink(link) Else ListRemove(itemList,Self)
				link = Null
			'EndIf
		EndIf
		
		'beacons have state change on collision
		If name = "beacon"
			If state[0] = 0 Then state[0] = 1'beacon state[0] = 1: currently colliding with a ship
			If _ship = p1 Then state[0] = 2'beacon state[0] = 2: currently colliding with the player
		EndIf
		
		'If link = Null Then Print name+ " has null link END collision with "+_ship.name
		
	EndMethod
EndType

Type Background Extends Entity
	Field accel#'	change in speed, applied constantly, bounded by 0
	Field distSpeed#	'how much to change dist every loop >:)
	Field distShade	'whether to shade the background due to distance
	
	Field lifetimer#	'if > 0, then removes self after this passes 0 (decs by millisecs). if = 0, sticks around indefinately

	Field alphaSpeed#	'how fast alpha is changing
	Field scaleSpeed#'how fast scale is changing
	
	Method update()
		'count down how long the bg lasts, if applicable
		If lifetimer <> 0
			lifetimer = lifetimer - frameTime
			If lifetimer <= 0
				RemoveLink(link)
			EndIf
		EndIf
		
		'PHYSICS STUFF
		'accelerate
		speed = speed + accel
		'cap speed at 0
		If speed < 0 Then speed = 0
		
		'DRAWING STUFF
		'change distance illusion
		dist = dist + distSpeed
		If dist < .001 Then dist = .001
		'change alpha over time
		alpha = constrain(alpha + alphaSpeed,0,1)
		'change scale over time
		scale = scale + scaleSpeed
		If scale <= 0 Then scale = 0.01
		'set the shading according to distance
		If distShade Then shade = (40*dist)
		
	EndMethod
	
	Method collide(_ship:Ship)
	
	EndMethod
EndType
Type Foreground Extends Background	'same thing, only drawn in front of entities
EndType
Global bgList:TList = New TList	'list of all the backgrounds in the game
Global debrisList:TList = New TList	'list of debris backgrounds
Global explodeList:TList = New TList	'list of explode foregrounds

'ingame message box a la starfox

Type Messagebox
	Field message$		'the raw message to display
	Field text$[32]		'the message to display, each item is its own line
	Field icon:TImage		'the portrait of the speaker
	Field progress		'number of characters of the message currently displayed
	Field pdelay = 40		'the delay in ms in displaying characters
	Field ptimer = pdelay	'the timer to countdown when to display the next character
	Field wid = 280
	Field het = 50
	Field x = SWIDTH - wid - 82
	Field y = SHEIGHT - het - 32
	Field fin = False		'has it finished displaying its contents?
	
	'adds some text to the message, reparses
	Method addText(_text$)
		message:+ _text
		text = parseText(message, wid-14)
	EndMethod
EndType

'takes some text and returns it as a divvied array (maxes at 32 lines)
Function parseText$[](_text$, _maxwid)
	Local line$[32]
	Local maxchar = _maxwid / TextWidth("X")'this is the maximum number of characters in a line
	Local l = 0	'which line of text we're on
	'activate the text
	_text = activateText(_text)
	'while we have a message to parse (and space in the message box)
	While Len(_text) > 0 And l < 32
		Local break
		
		'if we can just store the rest of the message in the next line
		If Len(_text) <= maxchar
			line[l] = _text' ^- do that -^
			break = Len(_text)-1'snip the rest of the message away
			
		Else	'if we can only fit a chunk into the next line
			break = maxchar-1
			While break >= 0 And Chr(_text[break]) <> " "'until we run into a space,
				break:- 1							'move backwards from the maximum length of a line
			Wend
			'break the message there & store the line
			line[l] = Left(_text,break+1)
		EndIf
		
		'snip the stored bit of the message away, we've parsed it
		_text = Right(_text,Len(_text)-(break+1))
		
		l:+ 1	'move onto the next line
	Wend
	
	Return line
EndFunction

'replaces certain key strings with their appropriate value
Function activateText$(_text$)
	If Instr(_text,"[ability]") Then _text = Replace(_text,"[ability]",String(MapValueForKey(abilityMap, String(p1.base.ability))))
	If Instr(_text,"[pilot]") Then _text = Replace(_text,"[pilot]",Upper(pilot.name))
	_text = Replace(_text,"[thrust]",Upper(keyName[KEY_THRUST]))
	_text = Replace(_text,"[strafeleft]",Upper(keyName[KEY_STRAFELEFT]))
	_text = Replace(_text,"[straferight]",Upper(keyName[KEY_STRAFERIGHT]))
	_text = Replace(_text,"[reverse]",Upper(keyName[KEY_REVERSE]))
	_text = Replace(_text,"[afterburn]",Upper(keyName[KEY_AFTERBURN]))
	_text = Replace(_text,"[shield]",Upper(keyName[KEY_SHIELD]))
	_text = Replace(_text,"[map]",Upper(keyName[KEY_MAP]))
	
	Return _text
EndFunction

Global mboxList:TList = New TList'queueing (FUCK ME NOW!) list of message boxes to display, they take their turns

'adds a message box to the list of messages to display to the player
Function new_message:Messagebox(_message$)
	Local m:Messagebox = New Messagebox
	m.message = _message
	m.text = parseText(m.message, m.wid)
	mboxList.addLast(m)
	Return m
EndFunction

'faction diplomacy table
Global fTable[8,8]		'ex. fTable[0,1] would be faction 0's relationship towards faction 1
					'values| -1:enemy | 0:neutral | 1:ally
					
Function initFactions()	'set all factions to friendly towards selves, neutral to others
	For Local f = 0 To 7
	For Local r = 0 To 7
		If f=r Then fTable[f,r] = 1 Else fTable[f,r] = 0
	Next
	Next
EndFunction

Const delayFrame = 300'150			'the time of delay b/t the two frames
Global delayFrameTimer = delayFrame'the actual timer for -^

Const debris_max = 1024		'maximum number of debris ever
Global debris_cap = debris_max	'CURRENT maximum number of debris objects

Global globalFrame = 0			'0 or 1. THERE ARE ONLY TWO FRAMES TO EVERYTHING, this tracks which one they're all on
Global globalFrameSwitch = False	'set to TRUE whenever the global frame switches

Global globalCamRot = False	'true/false, whether to rotate camera with ship

Global game:Level		'the current level director object
Global display_ff = True	'whether to display friend/foe information in the HUD
Global p1:Ship			'the ship the player flies around in
Global p1_usemouse = True	'whether to use the mouse for controls

'music
Global mission2_music:TSound = LoadSound("sfx/Mission2-FinalDraft.ogg",1)
Global mission1_music:TSound = LoadSound("sfx/Mission1-FinalDraft.ogg",1)
Global mission3_music:TSound = LoadSound("sfx/Mission3-FinalDraft.ogg",1)
Global theme_music:TSound = LoadSound("sfx/RubiconTheme_FullMix_B_Loop_RD.ogg",1)
Global boss_music:TSound = LoadSound("sfx/RubiconAction_FullMix_Loop_RD.ogg",1)
Global lilextra_music:TSound = LoadSound("sfx/mission2-leadsolo.ogg",1)

Rem
Menu Button - Mouseover (some small indication that you could click)
Menu Button - Click (confirmation that you clicked)
Ship Customization - Component placement (implies a part being set into place, a heavy cluck/click)
Battle - Fire laser
Battle - Laser hits ship
Battle - Laser hits shield & is reflected
Battle - Engine thrusting (low short looping sound that I turn up/down depending on the thrust)
Battle - Ship explodes
EndRem

'sound effects
Global unlock_sfx:TSound = LoadSound("sfx/wik_unlock.wav")
Global mouseover_sfx:TSound = LoadSound("sfx/wik_mouseover2.wav")
Global click_sfx:TSound = LoadSound("sfx/wik_mouseclick3.wav")
Global compplace_sfx:TSound = LoadSound("sfx/wik_mouseclick3.wav")
Global rockexplode_sfx:TSound = LoadSound("sfx/wik_explode3b.wav")
Global shipexplode_sfx:TSound = LoadSound("sfx/wik_explode2.wav")
Global playerexplode_sfx:TSound = LoadSound("sfx/wik_explode2b.wav")
Global missileexplode_sfx:TSound = LoadSound("sfx/wik_explode4.wav")
Global lightning1_sfx:TSound = LoadSound("sfx/wik_lightning1.wav")'technically thunder?
Global lightning2_sfx:TSound = LoadSound("sfx/wik_lightning2.wav")
Global lightning3_sfx:TSound = LoadSound("sfx/wik_lightning3.wav")'electricty hit
Global laserfire1_sfx:TSound = LoadSound("sfx/wik_pew2.wav")
Global laserfire2_sfx:TSound = LoadSound("sfx/wik_smallshoot2.wav")
Global shotgunfire_sfx:TSound = LoadSound("sfx/wik_shotgun1.wav")
Global autocannonfire_sfx:TSound = LoadSound("sfx/wik_pew5.wav")
Global ammodeplete_sfx:TSound = LoadSound("sfx/wik_depleted1.wav")
Global ammoreload_sfx:TSound = LoadSound("sfx/wik_reload1.wav")
Global vcannonfire_sfx:TSound = LoadSound("sfx/wik_pew3.wav")
Global missilefire_sfx:TSound = LoadSound("sfx/wik_missilethoom1.wav")
Global laserhit_sfx:TSound = LoadSound("sfx/wik_hit1.wav")
Global bullethit_sfx:TSound = LoadSound("sfx/wik_hit2.wav")
Global reflect_sfx:TSound = LoadSound("sfx/wik_reflect2.wav")
Global point_sfx:TSound = LoadSound("sfx/wik_mouseover2.wav")
Global collide_sfx:TSound = LoadSound("sfx/wik_hit1.wav")
Global textblip_sfx:TSound = LoadSound("sfx/wik_textblip1.wav")
Global beacon_sfx:TSound = LoadSound("sfx/wik_beacon1.wav")
Global warp_sfx:TSound = LoadSound("sfx/wik_warp1.wav")
Global warpcharge_sfx:TSound = LoadSound("sfx/wik_warp2.wav")
Global engine_sfx:TSound = LoadSound("sfx/wik_mouseover2.wav",SOUND_LOOP=True)

'menu graphics
Global hanger_tabs_gfx:TImage = LoadAnimImage("gfx/hanger_tabs.png",256,40,0,3)
SetImageHandle(hanger_tabs_gfx,0,0)
Global hanger_infoaddon_gfx:TImage = LoadAnimImage("gfx/hanger_infoaddons.png",206,40,0,3)
SetImageHandle(hanger_infoaddon_gfx,0,0)
Global hanger_exitbox_gfx:TImage = LoadAnimImage("gfx/hanger_exitbox.png",168,24,0,2)
SetImageHandle(hanger_exitbox_gfx,0,0)
Global campaign_mission_gfx:TImage = LoadAnimImage("gfx/campaign_mission.png",206,44,0,3)
SetImageHandle(campaign_mission_gfx,ImageWidth(campaign_mission_gfx),0)'origin is top-LEFT corner
Local scrollbar_arrows_gfx:TImage = LoadAnimImage("gfx/scrollbar_arrow.png",8,5,0,2)
Global scrollbar_up_gfx:TImage = getFrame:TImage(scrollbar_arrows_gfx, 0)
Global scrollbar_down_gfx:TImage = getFrame:TImage(scrollbar_arrows_gfx, 1)
Global hangerhelp_gfx:TImage = LoadImage("gfx/hangerhelp.png")
midHandle(hangerhelp_gfx)

'deployment graphics
Global iconNum = 5
Global deployicons_gfx:TImage = LoadAnimImage("gfx/deploy_icons.png",19,18,0,iconNum)
midHandle(deployicons_gfx)
Global deployterrain_gfx:TImage = LoadAnimImage("gfx/deploy_terrain.png",20,20,0,4)
SetImageHandle(deployterrain_gfx,0,0)
Global grid_gfx:TImage = LoadImage("gfx/grid.png")


'ingame graphics
Global fognebulae_gfx:TImage[] = load_image("gfx/nebulae1.png",417,256,2)
'Global blackhole_gfx:TImage[] = load_image("gfx/blackhole1.png",36,25,2)
Global lightning2_gfx:TImage[] = load_image("gfx/lightning2.png")
Global lightning1_gfx:TImage[] = load_image("gfx/lightning1.png",65,131,2)
Global lightning3_gfx:TImage[] = load_image("gfx/lightning3.png",30,65,2)
Global lightning4_gfx:TImage[] = load_image("gfx/lightning4.png",22,27,2)
Global explode1_gfx:TImage[] = load_image("gfx/explode1.png",13,13,2)
Global explode2_gfx:TImage[] = load_image("gfx/explode2.png",44,43,2)
Global explode3_gfx:TImage[] = load_image("gfx/explode3.png",9,7,2)'muzzle flare
Global explode4_gfx:TImage[] = load_image("gfx/explode4.png",5,5,2)'machine gun hit
Global explode5_gfx:TImage[] = load_image("gfx/explode5.png",17,19,2)
Global explode6_gfx:TImage[] = load_image("gfx/explode6.png",13,19,2)'alt small explosion

Global dust_gfx:TImage[] = load_image("gfx/dust.png")
'Global component_gfx:TImage[] = load_image("gfx/component.png",31,31,2)
'Global life_gfx:TImage[] = load_image("gfx/life.png",34,34,2)'extra lives
Global life_gfx:TImage[] = load_image("gfx/life2.png",12,20)'extra lives
Global abilitypoint_gfx:TImage[] = load_image("gfx/HUD_shieldpoint.png",18,18,2)'ability point recharges
Global point1_gfx:TImage[] = load_image("gfx/point1.png",16,18,2)'collectable points
Global bigpoint_gfx:TImage = resizeImage(point1_gfx[0],2)	'big point gfx
Global point2_gfx:TImage[] = load_image("gfx/point2.png",13,13,2)'ability recharge points points
Global shot1_gfx:TImage[] = load_image("gfx/shot1.png",8,8,2)
Global shot1_hit_gfx:TImage[1]
shot1_hit_gfx[0] = getHitImage(shot1_gfx[0])
Global shot2_gfx:TImage[] = load_image("gfx/shot2.png",5,13,2)
Global shot3_gfx:TImage[] = load_image("gfx/shot3.png",6,21,2)
Global shot4_gfx:TImage[] = load_image("gfx/shot4.png",19,13,2)
Global shot5_gfx:TImage[] = load_image("gfx/shot5.png",9,9,2)
Global shot6_gfx:TImage[] = load_image("gfx/shot6.png",13,34,2)'velocity cannon blue spike shot
Global shot_acid_gfx:TImage[] = load_image("gfx/shot_acid.png",14,21,2)'glistening acid shot
Global warp_gfx:TImage[] = load_image("gfx/warp.png",83,17,2)
Global warp2_gfx:TImage[] = load_image("gfx/warp2.png",41,23,2)
Global warp3_gfx:TImage[] = load_image("gfx/warp3.png")
Global hook_gfx:TImage[] = load_image("gfx/hook.png")
Global barb_gfx:TImage[] = load_image("gfx/barb.png")

Local shield_temp:TImage = LoadAnimImage("gfx/shield2.png",19,12,0,4)'contains 4 pieces of shield
midHandle(shield_temp)
Global shield_gfx:TImage[4,4]'we have different frames, sizes of shield
Global shield_hitgfx:TImage[4,4]'same deal, only for the purewhite hitgfxs
For Local frame = 0 To 3
	For Local scale = 0 To 3
		shield_gfx[frame,scale] = resizeImage(getFrame(shield_temp,frame),scale+1)
		shield_hitgfx[frame,scale] = gethitImage(shield_gfx[frame,scale])
		midHandle(shield_gfx[frame,scale])
	Next
Next

Global missile_gfx:TImage[] = load_image("gfx/missile.png",12,17,2)
Global missile2_gfx:TImage[] = load_image("gfx/missile2.png",5,15,2)
Global mine_gfx:TImage[] = load_image("gfx/mine.png",17,15,2)

Global vector_shot1_gfx:TImage[] = load_image("gfx/vectorshot1.png",6,6,2)
Global vector_ship1_gfx:TImage[] = load_image("gfx/vectorship1.png",19,30,2)
Global vector_ship2_gfx:TImage[] = load_image("gfx/vectorship2.png")
Global vector_ship3_gfx:TImage[] = load_image("gfx/vectorship3.png",62,68,2)
Global vector_asteroid1_gfx:TImage[] = load_image("gfx/vectorasteroid1.png")
Global vector_asteroid2_gfx:TImage[] = load_image("gfx/vectorasteroid2.png")

Global ship5_gfx:TImage[] = load_image("gfx/ship5.png",99,183,2)
Global ship6_gfx:TImage[] = load_image("gfx/ship6.png",33,38,2)

Global ship_pillbug_gfx:TImage[] = load_image("gfx/ship_pillbug.png",27,39,2)
Global ship_lancer_gfx:TImage[] = load_image("gfx/ship_lancer.png",23,40,2)
Global ship_flea_gfx:TImage[] = load_image("gfx/ship_flea.png",19,20,2)
Global ship_drone_gfx:TImage[] = load_image("gfx/ship_drone.png",15,21,2)
Global ship_turret_gfx:TImage[] = load_image("gfx/ship_turret.png",51,27,2)
Global ship_missileturret_gfx:TImage[] = load_image("gfx/ship_missileturret.png",43,20,2)
Global ship_warpbeacon_gfx:TImage[] = load_image("gfx/ship_beacon.png",27,33,2)
'Global human_station_gfx:TImage[1]
'human_station_gfx[0] = resizeImage(LoadImage("gfx/station2.png"),2)
Global ship_humanturret_gfx:TImage[] = load_image("gfx/ship_humanturret.png")
Global ship_snailturret_gfx:TImage[] = load_image("gfx/ship_humanturret2.png",35,36,2)
Global ship_hopper_gfx:TImage[] = load_image("gfx/ship_grasshopper.png",31,42,2)
Global ship_tusu_gfx:TImage[] = load_image("gfx/ship_tusu.png",41,31,2)
Global ship_zukhov_gfx:TImage[] = load_image("gfx/ship_zukhov.png",37,36,2)
Global ship_carrier_gfx:TImage[] = load_image("gfx/ship_carrier.png",71,134,2)
Global ship_frigate_gfx:TImage[] = load_image("gfx/ship_frigate.png",27,74,2)
Global ship_battleship_gfx:TImage[] = load_image("gfx/ship_battleship.png",101,73,2)
Global ship_humanfrigate_gfx:TImage[] = load_image("gfx/ship_humanfrigate.png",51,76,2)
Global ship_freighter_gfx:TImage[] = load_image("gfx/ship_freighter.png",45,148,2)
Global ship_scrapfighter_gfx:TImage[] = load_image("gfx/ship_scrapfighter.png",33,36,2)
Global ship_scrapbomber_gfx:TImage[] = load_image("gfx/ship_scrapbomber.png",31,33,2)
Global ship_tortoise_gfx:TImage[] = load_image("gfx/ship_tortoise.png",99,58,2)
Global ship_stealthbomber_gfx:TImage[] = load_image("gfx/ship_stealth.png",63,42,2)
'Global ship_alarm_gfx:TImage[] = load_image("gfx/ship_alarm.png",35,17,2)
Global ship_biscuitfish_gfx:TImage[] = load_image("gfx/ship_biscuitfish.png",37,75,2)
Global zerg_wolf_gfx:TImage[] = load_image("gfx/zerg_wolf.png",49,25,2)
Global zerg_devil_gfx:TImage[] = load_image("gfx/zerg_devil.png",51,41,2)
Global zerg_mite_gfx:TImage[] = load_image("gfx/zerg_mite.png",21,28,2)
Global zerg_cow_gfx:TImage[] = load_image("gfx/zerg_cow.png",90,114,2)
Global zerg_larva_gfx:TImage[] = load_image("gfx/zerg_larva.png",11,27,3)
Global zerg_larva_latched_gfx:TImage[2]
zerg_larva_latched_gfx[0] = zerg_larva_gfx[2]

Global zerg_anemone_gfx:TImage[] = load_image("gfx/zerg_anemone_mouth.png",36,38,2)

Global zerg_anemone_t1_gfx:TImage[] = load_image("gfx/zerg_anemone_tent1.png",64,64,2)
zerg_anemone_t1_gfx = resizeAnimImage(zerg_anemone_t1_gfx, 2, 2)

Global zerg_anemone_t2_gfx:TImage[] = load_image("gfx/zerg_anemone_tent2.png",92,93,2)
zerg_anemone_t2_gfx = resizeAnimImage(zerg_anemone_t2_gfx, 2, 2)

Global asteroid1_gfx:TImage[] = load_image("gfx/asteroid1.png")
Global asteroid2_gfx:TImage[] = load_image("gfx/asteroid2.png")
Global asteroid3_gfx:TImage[] = load_image("gfx/asteroid3.png")'BIG asteroid
Global asteroid4_gfx:TImage[] = load_image("gfx/asteroid4.png")'special asteroid large
Global asteroid5_gfx:TImage[] = load_image("gfx/asteroid5.png")'special asteroid small
Global asteroid6_gfx:TImage[] = load_image("gfx/asteroid6.png")'exploding asteroid large
Global asteroid7_gfx:TImage[] = load_image("gfx/asteroid7.png")'exploding asteroid small
Global asteroid8_gfx:TImage[] = load_image("gfx/asteroid8.png")'exploding asteroid small

'Global gate_gfx:TImage[] = load_image("gfx/gate.png",379,72,2)
'Global gate_edge_gfx:TImage[] = load_image("gfx/gate_edge.png")

Global trail_gfx:TImage[] = load_image("gfx/trail.png")
SetImageHandle(trail_gfx[0], ImageWidth(trail_gfx[0])/2, 0)
Global greenplanet_gfx:TImage[] = load_image("gfx/greenplanet.png")
Global rakisplanet_gfx:TImage[] = load_image("gfx/rakisplanet.png")
Global paintnebulae_gfx:TImage[] = load_image("gfx/paint_nebulae.png")
Global paintnebulae_back_gfx:TImage[] = load_image("gfx/paint_nebulae_back.png")

Global rockdeb_gfx:TImage[] = load_image("gfx/rockdebris.png",14,13,4)
Global metaldeb_gfx:TImage[] = load_image("gfx/metaldebris.png",12,14,5)
Global gibdeb_gfx:TImage[] = load_image("gfx/gibdebris.png",8,15,6)

'misc.
Global stars1_gfx:TImage = LoadImage("gfx/space_tile_big.png")
Global stars2_gfx:TImage = LoadImage("gfx/space_tile.png")

'MENU + HUD graphics
Global cursor_gfx:TImage[] = load_image("gfx/cursor.png",7,10,2)'the mouse cursor
cursor_gfx = resizeAnimImage(cursor_gfx, 2, 2)
SetImageHandle(cursor_gfx[0],0,0)
SetImageHandle(cursor_gfx[1],0,0)
Global arrow1_gfx:TImage = LoadImage("gfx/arrow.png")'offscreen target arrow
Global target1_gfx:TImage = LoadImage("gfx/target1.png")'friendfoe ID
Global target2_gfx:TImage = LoadImage("gfx/target2.png")'recticle aim
Global target3_gfx:TImage = LoadImage("gfx/target3.png")'recticle "actual"
Global target3_hit_gfx:TImage = getHitImage(target3_gfx)
midHandle(target3_gfx)
Global target4_gfx:TImage = LoadImage("gfx/target4.png")'enemy box corner
midHandle(target4_gfx)
Global target5_gfx:TImage[] = load_image("gfx/target5.png",126,122,2)'beacon
Global target5_white_gfx:TImage = getHitImage(target5_gfx[0])'white beacon
Global target6_gfx:TImage = LoadAnimImage("gfx/target6.png",47,47,0,2)'missile targeting circle

Global boxpointer_gfx:TImage = LoadImage("gfx/boxpointer.png")'offscreen target arrow
SetImageHandle boxpointer_gfx, ImageWidth(boxpointer_gfx)/2, 0
Global boxseparator_gfx:TImage = LoadAnimImage("gfx/boxseparator.png",186,6,0,2)'offscreen target arrow
midHandle(boxseparator_gfx)
Global HUD_pointcounter_gfx:TImage = LoadImage("gfx/HUD_pointcounter.png")
SetImageHandle(HUD_pointcounter_gfx,0,0)											'origin is topleft corner		
Global HUD_shieldpoint_gfx:TImage = LoadAnimImage("gfx/HUD_shieldpoint.png",18,18,0,2)
SetImageHandle(HUD_shieldpoint_gfx,0,0)												'origin is topleft corner
Global HUD_armourcap_gfx:TImage = LoadImage("gfx/HUD_armourcap.png")
SetImageHandle(HUD_armourcap_gfx,0,0)												'origin is topleft corner
Global HUD_armournotch_gfx:TImage = LoadImage("gfx/HUD_armournotch.png")
SetImageHandle(HUD_armournotch_gfx,ImageWidth(HUD_armournotch_gfx)/2,0)						'origin is top-center
Global HUD_juicecap_gfx:TImage = LoadImage("gfx/HUD_juicecap.png")
SetImageHandle(HUD_juicecap_gfx,0,0)												'origin is topleft corner
Global HUD_barbase_gfx:TImage = LoadImage("gfx/HUD_barbase.png")
SetImageHandle(HUD_barbase_gfx,0,0)												'origin is topleft corner
Global HUD_arrow_gfx:TImage = LoadAnimImage("gfx/arrow.png",30,30,0,2)
midHandle(HUD_arrow_gfx)
Global HUD_gunlight_gfx:TImage = LoadAnimImage("gfx/HUD_weaponindicator.png",10,10,0,3)
SetImageHandle(HUD_gunlight_gfx,0,0)

'system graphics
'Global mission_gfx:TImage = resizeImage(shot4_gfx[1],2)

Global credits:TList = New TList
'load the credits
Local cFile:TStream = ReadFile("credits.txt")
While Not Eof(cFile)
	credits.addLast(ReadLine(cFile))
Wend
CloseFile(cFile)

'arcade high scores
Type Highscore
	Field name$
	Field ship$
	Field config$
	Field difficulty#
	Field wave
	Field highlight = False'if we should highlight this one in the list
EndType
Global highscoreList:TList = New TList

'loads the highscores and puts them to highscorelist
Function load_highscores()
	'make the highscorelist if it doesn't exit
	If FileType("pilot/highscores.arcade") = 0 Then CreateFile("pilot/highscores.arcade")

	'load the highscores
	ClearList(highscoreList)
	Local sFile:TStream = ReadFile("pilot/highscores.arcade")
	While Not Eof(sFile)
		Local score:Highscore = New Highscore
		score.name = ReadLine(sFile)
		score.ship = ReadLine(sFile)
		score.difficulty = ReadFloat(sFile)
		score.wave = ReadByte(sFile)
		score.highlight = False
		highscoreList.addLast(score)
	Wend
	CloseFile(sFile)
	'sort the list
	sortHighscores()
EndFunction

'remember compsci 101?
Function sortHighscores()
	'well, this ain't the most bestest method
	Local parseList:TList = New TList
	SwapLists(highscoreList, parseList)
	
	'now add stuff back in the order of what's highest
	While Not ListIsEmpty(parseList)
		Local high:Highscore
		For Local score:Highscore = EachIn parseList
			If high = Null Or score.wave > high.wave Then high = score
		Next
		ListRemove(parseList, high)
		highscoreList.addLast(high)
	Wend
EndFunction

'saves the top highscores
Function save_highscores()
	'sort the list
	sortHighscores()
	'delete the old file
	DeleteFile("pilot/highscores.arcade")
	'make the new file
	CreateFile("pilot/highscores.arcade")
	'write to the new file
	Local sFile:TStream = WriteFile("pilot/highscores.arcade")
		'save ALL the scores
		For Local score:Highscore = EachIn highscoreList
			WriteLine(sFile,	score.name)
			WriteLine(sFile,	score.ship)
			WriteFloat(sFile,	score.difficulty)
			WriteByte(sFile,	score.wave)
		Next
	CloseFile sFile
EndFunction

'buttons for when the player dies
Global dead_backB:Button = New Button
dead_backB.text = "BACK"
dead_backB.wid = 168
dead_backB.het = 30

Global dead_restartB:Button = New Button
dead_restartB.text = "RESTART"
dead_restartB.wid = 168
dead_restartB.het = 30

'---------- SET UP SOUND ------------
Global sndVol# = 1			'global sound volume
Global sfxVol# = 1			'sound effect volume
Global sfxChannel:TChannel = New TChannel
SetChannelVolume sfxChannel,sndVol*sfxVol

Global music_channel:TChannel = New TChannel
Global musicVol# = .5
Global music_fade# = 1
Global new_music:TSound	'set this to a music file and it'll start playing
Global current_music:TSound	'currently-playing music
Global resetmusic = False	'whether to reset the currently-playing music

'set up all the components
setup_components()
'set up all the ship chassis
setup_chassis()
'set up all the stages
setup_stages()
'set up the profiles
setup_pilots()

'make a big lamjet to go all sideways and fast
Global lamjet:TImage[] = recolorAnimImage(ship6_gfx, SCHEME_GREEN, 2)
lamjet = resizeAnimImage(lamjet, 6, 2)

new_music = theme_music

intro()
mainMenu()

Function endGame()
	pilot.save()
	cleanUp()
	ClearList(chassisList)
	StopChannel music_channel
	EndGraphics()
	End
EndFunction

'sets everything to null, cleans stuff up
Function cleanUp()
	FlushKeys()
	FlushMouse()
	FlushJoy()

	game = Null
	p1 = Null
	
	ClearList(entityList)
	ClearList(itemList)
	ClearList(explodeList)
	ClearList(bgList)
	ClearList(debrisList)
	ClearList(shotList)
EndFunction

'-------------------------------MAINLOOP
Global timePass#, oldTime#'how many milliseconds since the last frame
'Global md1, md2'whether the primary and secondary mouse buttons are down
Function mainLoop()

	'Local dustDensity = 0, dustList:TList = New TList'list of dust particles that follow the player around
	'For Local d = 1 To dustDensity
	'	Local dust:Background = add_debris("rock",-2000,-2000,0,0)
	'	dust.x = Rand(p1.x-SWIDTH/2,p1.x+SWIDTH/2)
	'	dust.y = Rand(p1.y-SHEIGHT/2,p1.y+SHEIGHT/2)
	'	dust.dist = 1+RndFloat()/2
	'	dust.distSpeed = 0
	'	dust.speed = (RndFloat())*1.5
	'	dust.rot = Rand(0,359)
	'	dust.lifetimer = 0
	'	dust.link = dustList.AddLast(dust)
	'Next
	
	'Print "PLAYING THE GAME      " +GCMemAlloced()
	
	'restore the at-pause-time mouse coords
	moveCursor(pilot.pausemcoords[0], pilot.pausemcoords[1])
	
	Local avgTimePass# = 22
	oldTime = MilliSecs()
	timePass = 22'just so no tricky stuff at the initial loop
	Repeat
		WaitTimer(frameTimer)
		Cls
		SetColor 255,255,255
		
		updateTime()
		avgTimePass = (avgTimePass + timePass)/2
		
		game.updateCamera()
		
		draw_everything()'--> DRAWS EVERYTHING
		
		'SetColor 255,255,255
		'SetAlpha 1
		'SetRotation 0
		'SetScale 1,1
		'DrawText Int(avgTimePass),0,0
		'DrawText GCMemAlloced(),0,15
		'DrawText p1.x+","+p1.y,0,30
		
		'clear the collision boxes
		For Local cbx = 0 To game.cboxColNum-1
		For Local cby = 0 To game.cboxRowNum-1
			ClearList(game.cboxList[cbx,cby])
		Next
		Next
		
		'pre-update/physics stuff
		For Local s:Ship = EachIn entityList
			'add self to appropriate collision boxes
			s.addToCollisionBoxes()
			
			'default to not-animated, if we're thrusting this'll get set to true
			s.animated = False
		
			'tell the squadron that this ship has checked in
			s.squad.shipCount:+ 1
		
			'ship AI
			ship_AI(s)
		
			'clear the proximity list
			ClearList(s.proximity_shipList)
			
		Next
		
		'add shots to appropriate collision boxes
		For Local s:Shot = EachIn shotList
			s.addToCollisionBoxes()
		Next
		
		'add items to appropriate collision boxes
		For Local i:Item = EachIn itemList
			i.addToCollisionBoxes()
			
			'clear the proximity list
			ClearList(i.proximity_shipList)
		Next
		
		'updates the map + checks for collisions between things
		game.updateMapCollisions()
		
		'game, level properties update (score, changing enemy behavior, adding ships...)
		game.update()
		
		'entity update, physics
		SetScale SHIPSCALE,SHIPSCALE
		For Local e:Ship = EachIn entityList
			'store the current speed and angle
			Local curspeed# = e.speed, curangle# = e.movrot
			
			'make the ship do things
			e.physics()
			e.update()
			
			'make it harder to draw a bead on this ship if we changed our movement
			Local change#
				
			'change due to speed
			If Abs(e.speed - e.speedMax) > .15 Then change:+ Abs(curspeed - e.speed)*(e.speed+1)*4 * (frameTime/1000)
			'change due to direction
			change:+ Abs(convert_to_relative(curangle,e.movrot)/120)' * (frameTime/1000)
				
			e.AI_predict = constrain(e.AI_predict - change, 0, 1)
			
			If e.squad.shipCount <> 0 Then e.squad.shipNum = e.squad.shipCount'store the final count of ships in the squadron
			e.squad.shipCount = 0'clear squadron shipcounts
		Next
		
		For Local i:Item = EachIn itemList
			i.update()
			i.physics()
		Next
		
		For Local s:Shot = EachIn shotList
			s.update()
			s.physics()
		Next
		
		'background update
		For Local b:Background = EachIn bgList
			b.update()
			b.physics()
		Next
		
		'dynamically set the current debris cap
		'If avgTimePass - 2  > 1000/game_FPS
		'	debris_cap = debris_cap-1
		'Else
		'	debris_cap = constrain(debris_cap+1,0,debris_max)
		'EndIf
		
		'cap the amount of debris
		'Local overflow = CountList(debrisList) - debris_cap
		'While overflow > 0
		'	debrisList.removeFirst()
		'	overflow = overflow - 1
		'Wend
		
		'update the debris
		For Local b:Background = EachIn debrisList
			b.update()
			b.physics()
			'fade out the debris if it's about to run out of life
			If b.lifetimer < 500 And (b.lifetimer <> 0) Then b.alpha:+ frameTime/200
		Next
		
		'update the explosions
		For Local b:Background = EachIn explodeList
			b.update()
			b.physics()
			'fade out the explode if it's about to run out of life
			If b.lifetimer < 200 And (b.lifetimer <> 0) Then b.alpha:+ frameTime/200
		Next
		
		'update the dust
		'For Local d:Background = EachIn dustList
		'	d.update()
		'	d.physics()
		'	
		'	'if dust has drifted off the screen...
		'	If approxDist(d.x-p1.x,d.y-p1.y)/d.dist > SWIDTH
		'		'reset its distance, speeds, angle
		'		d.dist = 1+RndFloat()/2
		'		d.speed = (RndFloat())*1.5
		'		d.rot = Rand(0,359)
		'		'replace it somewhere else offscreen
		'		Local theta = Rand(0,359)
		'		d.x = p1.x + Cos(theta)*(SWIDTH-100)
		'		d.y = p1.y + Sin(theta)*(SWIDTH-100)
		'	EndIf
		'Next
		
		'controls!
		player_controls()
		
		'quit?
		If KeyHit(KEY_ESCAPE) Or JoyHit(JOY_MENU) Then Exit'game's not over yet, we're just popping out for the menu
		If game.over
			game.fade = 1
			If game.currentfade = 1 Then Exit
		EndIf
		
		If AppTerminate() Then endGame()'game is over, and we're gonna exit the program
		
		updateMusic()
		Flip
	Forever
	
	SetColor 255,255,255
	SetAlpha 1
	SetRotation 0
	
	'if we're just pausing
	If Not game.over
		pilot.pausemcoords[0] = cursorx
		pilot.pausemcoords[1] = cursory
	EndIf
	
	'ClearList(dustList)
	
	FlushKeys()
	FlushMouse()
	FlushJoy()
	
End Function

'draw everything
Function draw_everything()
	'draw the starfield
	SetRotation -game.camrot
	SetScale 1,1
	If game.backdrop_rgb[0] = 0 And game.backdrop_rgb[1] = 0 And game.backdrop_rgb[2] = 0
		SetColor 255,255,255
	Else
		SetColor game.backdrop_rgb[0],game.backdrop_rgb[1],game.backdrop_rgb[2]
	EndIf
	SetAlpha 1
	If game.backdrop_gfx[0] <> Null Then TileImage game.backdrop_gfx[0],game.camx/10,game.camy/10',SWIDTH/2,SHEIGHT/2'stars_gfx
	SetAlpha .8
	SetScale 1/game.zoom,1/game.zoom
	If game.backdrop_gfx[1] <> Null Then TileImage game.backdrop_gfx[1],game.camx/6,game.camy/6
	
	'draw all the backgrounds (relative to player's POV)
	For Local bg:Background = EachIn bgList
		If TTypeId.ForObject(bg) = TTypeId.ForName("Background")'exclude foregrounds for now
			bg.draw()
		EndIf
	Next
	
	'draw all the debris backgrounds
	For Local bg:Background = EachIn debrisList
		If TTypeId.ForObject(bg) = TTypeId.ForName("Background")'exclude foregrounds for now
			bg.draw()
		EndIf
	Next
	
	'draw all the explode foregrounds
	For Local ex:Background = EachIn explodeList
		If TTypeId.ForObject(ex) = TTypeId.ForName("Background")'exclude foregrounds for now
			ex.draw()
		EndIf
	Next

	'----------------------------------- AIMING CONE---------------------------------
	If p1.armour > 0 And p1.link <> Null And game.intro_tween = 0 And Not p1.skipDraw
	
		'find the offset due to zoom
		Local zoom_shift#[] = p1.findDistShift()

		'position of the player's ship on the screen
		Local sx# = (p1.x+game.camx+zoom_shift[0])
		Local sy# = (p1.y+game.camy+zoom_shift[1])
	
		'how far away is the mouse?
		Local m_dx# = (cursorx - sx)
		Local m_dy# = (cursory - sy)
		Local mdist# = approxDist(m_dx,m_dy)
		Local mtheta# = ATan2(m_dy,m_dx)
		
		'firing arc lines HUD
		SetAlpha .2
		SetRotation 0
		SetScale 1,1
		SetColor 255,180,25
		Local fRad = 30 / 2'p1.freedomGroup(1)/2
		If fRad = 0 Then fRad = 15
		For Local i = -1 To 1 Step 2
			'outside line
			DrawLine sx,sy, sx+Cos(mtheta+i*fRad)*SWIDTH, sy+Sin(mtheta+i*fRad)*SWIDTH
			'inside line
			DrawLine sx+Cos(mtheta+i*fRad/2)*(mdist/3-10), sy+Sin(mtheta+i*fRad/2)*(mdist/3-10), sx+Cos(mtheta+i*fRad/2)*2*mdist/3, sy+Sin(mtheta+i*fRad/2)*2*mdist/3
		Next
		'first set of horiz lines
		DrawLine sx+Cos(mtheta+fRad)*2*mdist/3, sy+Sin(mtheta+fRad)*2*mdist/3, sx+Cos(mtheta-fRad)*2*mdist/3, sy+Sin(mtheta-fRad)*2*mdist/3
		DrawLine sx+Cos(mtheta+fRad)*mdist/3, sy+Sin(mtheta+fRad)*mdist/3, sx+Cos(mtheta-fRad)*mdist/3, sy+Sin(mtheta-fRad)*mdist/3
		'aimer horiz lines
		DrawLine sx+Cos(mtheta+fRad)*mdist, sy+Sin(mtheta+fRad)*mdist, sx+Cos(mtheta+2*fRad/3)*mdist, sy+Sin(mtheta+2*fRad/3)*mdist
		DrawLine sx+Cos(mtheta-fRad)*mdist, sy+Sin(mtheta-fRad)*mdist, sx+Cos(mtheta-2*fRad/3)*mdist, sy+Sin(mtheta-2*fRad/3)*mdist
		'DrawRect sx+Cos(p1.rot)*mdist*i-3, sy+Sin(p1.rot)*mdist*i-3,6,6
	EndIf
	
	'draw all the items
	For Local i:Item = EachIn itemList
		i.draw()
	Next

	'draw all the ships (relative to player's POV)
	Local oldTar:Gertrude = p1.target'save the player's current target
	'predict movement for only the closest target
	Local closestDist = 6000
	Local closestTar:Gertrude
	'find the absolute position of the mouse
	Local mx# = p1.x + (cursorx - (p1.x+game.camx))
	Local my# = p1.y + (cursory - (p1.y+game.camy))
	For Local s:Ship = EachIn entityList
	
		'drew = TRUE/FALSE if we successfully drew the ship (if it's not outside screen, valid graphic, etc.)
		
		Local drew = s.draw()
		
		Local zoom_shift#[] = s.findDistShift()

		
		SetAlpha 1
		DrawImage s.gfx[0], s.x+game.camx+zoom_shift[0], s.y+game.camy+zoom_shift[1]
		
		If drew
			'Local zoom_shift#[] = s.findDistShift()
		
			'hit tween (we still have scale, rotation, from entity drawing)
			If s.tweenOnHit
				SetColor 255,255,255
				SetAlpha s.hit_tween
				DrawImage s.base.hitgfx, s.x+game.camx+zoom_shift[0], s.y+game.camy+zoom_shift[1]
			EndIf
			
			'recent damage
			If s.recent_damage > 0 And Not s.base.bio'no damage showing for the wee beasties
				If s = p1 And globalFrame Then SetColor 255,140,140 Else SetColor 255,10,10'player's damage flashes
				If s.recent_damage_timer > 150 Then SetAlpha 1 Else SetAlpha (s.recent_damage_timer/150)
				SetRotation 0
				SetScale 1.5,1.5
				Local rad = ImageWidth(s.gfx[0])/1.5
				DrawText Int(s.recent_damage), s.x+game.camx+Cos(s.recent_damage_theta-25)*rad, s.y+game.camy+Sin(s.recent_damage_theta-25)*rad
			EndIf
			
			'SetColor 255,255,255
			'SetRotation 0
			'SetAlpha 1
			'DrawText s.AI_predict,s.x+game.camx+40,s.y+game.camy+10
			'DrawText s.behavior,s.x+game.camx+40,s.y+game.camy+10
			'DrawText s.speed,s.x+game.camx,s.y+game.camy+10
			'DrawText s.AI_value[0],s.x+game.camx,s.y+game.camy-20
			
			'do we have a shield?
			If s.shieldOn
				'flicker it out as it's about to die
				If Rand(s.shield_timer*1000,s.shield_duration*1000) > 2000
					SetBlend LIGHTBLEND
					SetColor 255,255,255
					SetScale 1+(s.shield_tween+.01)/2 + game.zoom, 1+(s.shield_tween+.01)/2 + game.zoom
					'go through each segment, calculating where on the oval of the gfx (dimensions calculated below) to draw it
					Local wid = 4 + (ImageWidth(s.gfx[0])*s.scale) / 1.8
					Local het = 4 + (ImageHeight(s.gfx[0])*s.scale) / 1.8
					For Local seg = 0 To 7
						Local theta# = seg * -45
						Local rad# = approxDist(wid*Sin(theta),het*Cos(theta))
						SetRotation s.rot + 180*Floor(seg/4) + 90
						Local drawx = Cos(-theta + s.rot)*rad + s.x + game.camx + zoom_shift[0]
						Local drawy = Sin(-theta + s.rot)*rad + s.y + game.camy + zoom_shift[1]
						Local frame = seg Mod 4
						
						Local shieldscale = constrain(Floor(Max(ImageHeight(s.gfx[0])*s.scale*SHIPSCALE/40, SHIPSCALE)),1,4)
						
						'draw the colored shield
						SetAlpha .7 + .3*(s.shield_tween)
						DrawImage shield_gfx[frame,shieldscale-1],drawx,drawy
						
						'draw the hitgfx shield
						If s.shield_tween > 0
							SetAlpha s.shield_tween
							DrawImage shield_hitgfx[frame,shieldscale-1],drawx,drawy
						EndIf
					Next
					SetBlend ALPHABLEND
				EndIf
			EndIf
			
			'targeting recticle on enemy non-aliens
			If fTable[p1.squad.faction,s.squad.faction] = -1 And (Not s.base.bio)'if an enemy ship & not a beastie
				'enemy box
				SetColor 255,255,255
				SetScale SHIPSCALE,SHIPSCALE
				SetAlpha .2
				If s.base.ord Then SetAlpha .1
				Local boxr# = Max(ImageWidth(s.gfx[0])/2, ImageHeight(s.gfx[0])/2) * .6
				'draw four corners around each enemy
				For Local y# = -1 To 1 Step 2
				For Local x# = -1 To 1 Step 2
					If y = -1 And x = -1 Then SetRotation 0
					If y = -1 And x = 1 Then SetRotation 90
					If y = 1 And x = -1 Then SetRotation 270
					If y = 1 And x = 1 Then SetRotation 180
					DrawImage target4_gfx, s.x+(x*boxr)+game.camx, s.y+(y*boxr)+game.camy
				Next
				Next
				'draw a red box on top of them too
				'SetColor 255,150,150
				'SetRotation 0
				'SetAlpha .1
				'DrawRect s.x+game.camx-boxr-4, s.y+game.camy-boxr-4,boxr*2*SHIPSCALE+4,boxr*2*SHIPSCALE+4
				
				'predict target position
				If (Not s.base.ord)' don't predict missiles
					'is this target closer than the last one?
					p1.target = s.placeholder
					Local tar_p#[]
					'find a weapon group that is not empty
					For Local i = 0 To 5
						If Not ListIsEmpty(s.gunGroup[i])
							tar_p = p1.predictTargetPos(i)
							Exit
						EndIf
					Next
					If tar_p# <> Null'if it has a weapon/found a target for it
						Local tarDist = approxDist(tar_p[0]-mx, tar_p[1]-my)
						If tarDist < closestDist
							'if so, store it
							closestTar = s.placeholder
							closestDist = tarDist
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
		
		'draw an arrow at offscreen enemies
		If fTable[p1.squad.faction,s.squad.faction] = -1 And Not s.base.ord 'if an enemy *ship*
			'if within sensor range
			If approxDist(s.x-p1.x,s.y-p1.y) < 4000 Then draw_arrow(s.x,s.y)'draw_arrow makes sure it's offscreen
		EndIf
	Next
	'draw the closest prediction
	If closestTar <> Null
		'get this target's predicted position
		p1.target = closestTar
		Local tar_p#[] = p1.predictTargetPos(0)
		
		'see how far it is to the target
		'draw a series of dots leading up to the prediction
		Local dotx = tar_p[0]
		Local doty = tar_p[1]
		Local dist# = approxDist(dotx - closestTar.x, doty - closestTar.y)
		Local diststep# = 20
		
		SetScale .7,.7
		SetAlpha constrain(dist / (diststep*2), 0, 1)		'fade it out if it gets close to the ship
		
		While dist > diststep
			'zeno's paradox it up
			dotx:- (dotx - closestTar.x)/2
			doty:- (doty - closestTar.y)/2
			'make a dot
			DrawImage vector_shot1_gfx[globalFrame], dotx+game.camx, doty+game.camy
			'calculate new distance
			dist = approxDist(dotx - closestTar.x, doty - closestTar.y)
		Wend
		
		'draw the targeting predicttion
		SetScale 1,1
		DrawImage target2_gfx, tar_p[0]+game.camx, tar_p[1]+game.camy
	EndIf
	p1.target = oldTar'restore the player's original target
	
	'draw all the shots
	For Local s:Shot = EachIn shotList
		s.draw()
	Next
	
	'draw all the foreground debris
	For Local f:Foreground = EachIn debrisList
		f.draw()
	Next
	

	'draw the map foregrounds (only around the player)
	Local cbx, cby
	Local cb_wide = Ceil(SWIDTH/(game.cboxSize*2))'how many collision boxes-wide the screen is
	Local cb_tall = Ceil(SHEIGHT/(game.cboxSize*2))'how many collision boxes-tall the screen is
	'we go the width of the screen left AND right, ditto for height
	For Local y_box# = -cb_tall To cb_tall+1
		'find the cbox row to draw
		cby = Floor((-game.camy + (y_box*game.cboxSize) + game.height + SHEIGHT/2) / game.cboxSize)
		If cby < 0 Or cby > game.cboxRowNum-1 Then Continue
	
		For Local x_box# = -cb_wide To cb_wide+1
			cbx = Floor((-game.camx + (x_box*game.cboxSize) + game.width + SWIDTH/2) / game.cboxSize)
			If cbx < 0 Or cbx > game.cboxColNum-1 Then Continue
			
			'does this tile have terrain?
			Local terrain = game.map[cbx,cby,0]
			Select terrain
			Case 1,2'lightning, fog nebulae
				'is there a shot in this cbox?
				Local light = False
				For Local s:Shot = EachIn game.cboxList[cbx,cby]
					light = True
					Exit
				Next
			
				'initialize the nebulae randomly
				If game.map[cbx,cby,1] = 0 Then game.map[cbx,cby,1] = Rand(1,360)
				'advance it
				If globalFrameSwitch Then game.map[cbx,cby,1]:+ 1
				'wrap it
				If game.map[cbx,cby,1] > 720 Then game.map[cbx,cby,1] = 1
				'draw the nebulae
				Local state# = game.map[cbx,cby,1]
				Local drawx = cbx*game.cboxSize-game.width+game.camx
				Local drawy = cby*game.cboxSize-game.height+game.camy
				If light Then SetBlend LIGHTBLEND Else SetBlend ALPHABLEND
				For Local i# = -3 To 3'-5 To 5 Step 2
					If terrain = 1'lightning
						SetColor 215+Sin(state)*20,150+Cos(state)*60,65+Sin(state/2)*20
					ElseIf terrain = 2'fog
						SetColor 215+Sin(state)*20,215+Cos(state)*20,215+Sin(state/2)*20
					EndIf
					
					SetRotation (state/2.0)+i*45
					SetAlpha .05
					SetScale 1,1
					DrawImage fognebulae_gfx[Abs(i Mod 2)], drawx+Sin(state)*game.cboxSize/(3*i), drawy+Cos(state*2)*game.cboxSize/(4*i)
				Next
			EndSelect
		Next
	Next
	
	'draw all the foreground explosions
	For Local f:Foreground = EachIn explodeList
		f.draw()
	Next
	
	'draw all the foregrounds (relative to player's POV)
	For Local fg:Foreground = EachIn bgList
		fg.draw()
	Next

	SetBlend ALPHABLEND
	
	'draw messages a la starfox
	For Local m:Messagebox = EachIn mboxList
		'draw the background box
		Local RGB[3]
		RGB[0] = 13
		RGB[1] = 11
		RGB[2] = 34
		SetAlpha .3
		SetRotation 0
		SetScale 1,1
		drawBorderedRect(m.x,m.y-10,m.wid+20,m.het+20,RGB)
		
		'draw the message
		SetAlpha 1
		SetColor 212,212,212
		Local texthet = TextHeight("BOBCAT")
		Local dtext = m.progress	'how much text we have left to draw, in characters
		Local line = 0			'which line we're on
		While dtext > 0
			'if we can draw the whole next line
			If Len(m.text[line]) <= dtext
				DrawText m.text[line],m.x+14,m.y+line*texthet'draw it
				dtext:- Len(m.text[line])
			'if we're only going to draw part of it
			Else
				DrawText Left(m.text[line],dtext),m.x+14,m.y+line*texthet
				dtext = 0
			EndIf
			line:+ 1
		Wend
		
		'count down the ptimer
		m.ptimer:- frameTime
		If m.ptimer <= 0 And m.progress <= Len(m.message)-1'(cap the progress to the total length of the message)
			m.ptimer = m.pdelay
			m.progress:+ 1
			If m.progress Mod 2 Then playSFX(textblip_sfx, p1.x, p1.y)
			If m.progress = Len(m.message)
				m.ptimer = m.pdelay * 20	'give them a bit of extra time to finish reading it
			EndIf
		ElseIf m.ptimer <= 0 'if we've reached the end of the message
			m.fin = True			'we're done displaying the message
			ListRemove(mboxList,m)'remove thyself from the game
		EndIf
		
		Exit'just draw the first message
	Next
	
	'update the flashing text, if any
	game.draw_flashtext()
	
	'draw the HUD
	If p1.armour > 0 Then draw_HUD()
	
	'fade the screen out/in
	SetRotation 0
	SetColor 0,0,0
	SetScale 1,1
	SetAlpha game.currentfade
	DrawRect 0,0,SWIDTH,SHEIGHT
EndFunction

Function draw_HUD()
	
	Local HUD_transparency# = .8'.5
	
	Local greyrgb[3]
	greyrgb[0] = 32
	greyrgb[1] = 32
	greyrgb[2] = 32

	'set drawing state
	SetScale 1,1
	SetRotation 0
	SetColor 255,255,255
	
	'set the position and size of stuff
	Local juicehet = ImageHeight(HUD_juicecap_gfx)
	Local juicewid = 155 - juicehet
	Local juicey = SHEIGHT - 94
	Local armourhet = ImageHeight(HUD_armourcap_gfx)
	Local armourwid = 306
	Local armourx = ImageWidth(HUD_barbase_gfx)
	Local armoury = juicey + juicehet - 2
	Local pointhet = ImageHeight(HUD_shieldpoint_gfx)
	Local pointy = juicey - pointhet - 2
	
	SetAlpha HUD_transparency
	
	'draw the background border of the armour
	drawBorderedRect(armourx-4, armoury, armourwid+8, armourhet, greyrgb)
	
	'draw the background border of the juice
	drawBorderedRect(armourx-4, juicey, juicewid+8, juicehet, greyrgb)
	
	SetAlpha 1
	
	'draw the actual bar of the armour
	'flash if low health/during the intro
	Local armourpercent# = (p1.armour / p1.armourMax)
	If (p1.armour <= 12 And armourpercent <= .3) And globalFrame
		SetColor 255,255,255
	Else
		Local red# = (1-armourpercent)
		Local white# = (p1.hit_tween+(game.intro_tween*2))*220
		SetColor 180 + white + 75*red, 60 + white - 60*red, 40 + white - 40*red
	EndIf
	DrawRect armourx, armoury+6, armourwid * armourpercent * (1-game.intro_tween), armourhet-12
	
	'draw armour notches
	SetColor 255,255,255
	Local notchRatio = 4'how many points of armour each notch counts
	For Local i = 0 To p1.armourMax/notchRatio
		Local notchx = armourx + i*(armourwid / (p1.armourmax/notchRatio))
		SetRotation 180
		DrawImage HUD_armournotch_gfx, notchx, armoury + armourhet - 4
		SetRotation 0
		DrawImage HUD_armournotch_gfx, notchx, armoury + 4
	Next
	
	'draw the actual bar of the juice
	'white if using it up
	If p1.throttle > 1 Then SetColor 255,255,255 Else SetColor 60,130,60
	DrawRect armourx, juicey+6, juicewid * (p1.juice / p1.juiceMax) * (1-game.intro_tween), juicehet-12
	
	SetAlpha HUD_transparency
	SetColor 255,255,255
	
	'draw the cap for the armour
	DrawImage HUD_armourcap_gfx, armourx + armourwid, armoury
	
	'draw the cap for the juice
	DrawImage HUD_juicecap_gfx, armourx + juicewid, juicey
	
	'draw the base gfx for both bars
	DrawImage HUD_barbase_gfx, 0, juicey - 2

	SetColor 255,255,255
	SetAlpha HUD_transparency

	'draw the borders for the ability points
	Local pointcols = 6									'how many points in each row
	Local pointrows = Floor(Float(p1.pointMax-1) / Float(pointcols))	'how many rows of points
	For Local i = 0 To pointrows
		'for all stacked rows, make it the appropriate row width (also for final rows that are filled out)
		If (i < pointrows) Or (p1.pointMax Mod pointcols) = 0
			drawBorderedRect(armourx-4, pointy - 4 - 24*i, 4 + pointcols*20 + 2, 26, greyrgb)
		
		Else'for incomplete rows, only partially filled
			drawBorderedRect(armourx-4, pointy - 4 - 24*i, 4 + (p1.pointMax Mod pointcols)*20 + 2, 26, greyrgb)
			
		EndIf
	Next
	'draw the icons
	SetAlpha 1
	For Local i = 0 To Int((p1.pointMax-1) * (1-game.intro_tween))
		Local row = Floor(Float(i) / Float(pointcols))'the current row this point is on
		DrawImage HUD_shieldpoint_gfx, armourx + 20*(i Mod pointcols), pointy - 24*row, constrain(i-(p1.points-1),0,1)
	Next
	
	'draw the current alt. weapon
	For Local g:Gun = EachIn p1.gunGroup[pilot.selgroup]
		Local gunx = armourx + juicewid + ImageWidth(HUD_juicecap_gfx) + 4 + 4
		Local guny = juicey + 2
		Local gunwid = 132
		Local gunhet = juicehet - 4
		
		'how ready the gun is to fire
		SetAlpha .6
		'border
		SetColor 32,32,32
		drawBorderedRect(gunx, guny, gunwid, gunhet, greyrgb)
		'status bar
		Local reloadstatus# = constrain(.75 - 3*(g.fireDelay_timer / g.fireDelay)/4 + .25 - (g.burstDelay_timer / g.burstDelay)/4, 0,1)
		SetAlpha 1
		If reloadstatus < 1 Then SetColor 80,40,110 Else SetColor 60,60,130
		DrawRect gunx+2,guny+2, (gunwid*reloadstatus) - 4, gunhet-4
		'if we have to charge it up, another bar for that
		If g.mode = 2 And g.state > 0'press-hold-release
			SetAlpha .4
			SetColor 255,80,1
			DrawRect gunx+2,guny+2, (gunwid*g.state) - 4, gunhet-4
		EndIf
		
		'a little light for reload
		Local lightframe = 0'selected
		If reloadstatus < 1 Or g.reloadDelay_timer > 0 Then lightframe = 1'reloading
		SetAlpha 1
		SetColor 255,255,255
		DrawImage HUD_gunlight_gfx, gunx + 6, guny + 6, lightframe
		
		'the name, ammo of the gun
		SetAlpha 1
		If g.mode = 2 And g.state > 0
			If globalframe Then SetColor 128,128,128 Else SetColor 255,255,255	'flash if reach full charge
		EndIf
		If reloadstatus = 1 Then SetColor 255,255,255 Else SetColor 128,128,128	'greyed out if reloading
		draw_text("|"+g.dispname, gunx + 18, guny + 4)
		
		'if we recently switched to this weapon, draw its name, larger
		'If wgroup = pilot.selgroup And pilot.selgroup_timer > 0
		'	'draw the name bigger
		'	SetScale 2,2
		'	SetColor 255,255,255
		'	If pilot.selgroup_timer > 150 Then SetAlpha 1 Else SetAlpha (pilot.selgroup_timer / 150)
		'	Local pointer$ = g.name+" ->"
		'	draw_text(pointer, SWIDTH - listwid - TextWidth(pointer)*2, oy + i*gunhet - 2)
		'	
		'	'count down the timer
		'	pilot.selgroup_timer:- frameTime
		'EndIf
		
		'one-gun list
		Exit
	Next

	
	'draw the point counter
	If p1.recent_points_timer > 0
		Local counterx = 0
		Local countery = SHEIGHT/3
		Local counteralpha# = constrain(Float(p1.recent_points_timer) / 850.0, 0, 1)
		
		SetAlpha counteralpha * HUD_transparency
		DrawImage HUD_pointcounter_gfx, counterx, countery
	
		Local pointcount = Int(game.value[5])'starts out with however many points that carried over from the last wave
		For Local point:Item = EachIn p1.dropList
			pointcount:+ 1
		Next
	
		SetAlpha counteralpha
	
		'draw the new amount of points
		If p1.recent_points > 0 Then draw_text("+"+Int(Ceil(p1.recent_points)), counterx + 63, countery + 28)
	
		'draw the current amount of points
		draw_text(pointcount - Int(Ceil(p1.recent_points)), counterx + 63, countery + 8)
	EndIf
	
	'list all the weapons, how reloaded they are
	Local mousetween#
	Rem
	Local oy = 0'10
	Local listwid = 150
	Local gunhet = 24
	Local i = 0
	For Local wgroup = 0 To 5
		For Local g:Gun = EachIn p1.gunGroup[wgroup]
			'how ready the gun is to fire
			SetAlpha .2
			'border
			SetColor 164,164,164
			DrawRect SWIDTH-listwid-2, oy + i*gunhet, listwid+4, gunhet
			SetAlpha .4
			SetColor 32,32,32
			DrawRect SWIDTH-listwid, oy + i*gunhet+1, listwid, gunhet-2
			'status bar
			Local reloadstatus# = constrain(.75 - 3*(g.fireDelay_timer / g.fireDelay)/4 + .25 - (g.burstDelay_timer / g.burstDelay)/4, 0,1)
			SetAlpha .8
			If reloadstatus < 1 Then SetColor 80,40,110 Else SetColor 60,60,130
			DrawRect SWIDTH-listwid*reloadstatus, oy + i*gunhet+1, listwid, gunhet-2
			
			'a little light for reload & selection
			Local lightframe = 0'selected
			If reloadstatus < 1 Or g.reloadDelay_timer > 0 Then lightframe = 1'reloading
			If wgroup > 0 And wgroup <> pilot.selgroup Then lightframe = 2'unselected
			SetAlpha 1
			SetColor 255,255,255
			DrawImage HUD_gunlight_gfx, SWIDTH - listwid + 6, oy + i*gunhet + gunhet/2, lightframe
			
			'the name, ammo of the gun
			SetAlpha 1
			If reloadstatus = 1 Then SetColor 255,255,255 Else SetColor 128,128,128
			draw_text("|"+g.name, SWIDTH - listwid + 10, oy + i*gunhet + 5)
			If g.clipNum > 0 Then draw_text("clip:"+g.clip, SWIDTH - listwid + 110, oy + i*gunhet + 5)
			
			'should we tween the mouse due to firing this?
			If mousetween = 0 Then mousetween = (1 - reloadstatus)
			
			'if we recently switched to this weapon, draw its name, larger
			If wgroup = pilot.selgroup And pilot.selgroup_timer > 0
				'draw the name bigger
				SetScale 2,2
				SetColor 255,255,255
				If pilot.selgroup_timer > 150 Then SetAlpha 1 Else SetAlpha (pilot.selgroup_timer / 150)
				Local pointer$ = g.name+" ->"
				draw_text(pointer, SWIDTH - listwid - TextWidth(pointer)*2, oy + i*gunhet - 2)
				
				'count down the timer
				pilot.selgroup_timer:- frameTime
			EndIf
			
			i:+ 1
		Next
	Next
	EndRem

	'draw the minimap
	If pilot.map_toggle
		SetRotation 0
		SetScale 1,1
		SetAlpha .7
		Local msize = 500
		Local mapzoom = 10
		SetColor 32,32,32
		
		'only draw within the map's area
		SetViewport SWIDTH/2-msize/2,SHEIGHT/2-msize/2,msize,msize
		
		'the grey background for the map
		DrawRect 0,0,SWIDTH,SHEIGHT
		SetAlpha 1
		
		'draw the ships on the map, rel. to the player
		For Local s:Ship = EachIn entityList
			Local drawx = (s.x - p1.x)/mapzoom + SWIDTH/2
			Local drawy = (s.y - p1.y)/mapzoom + SHEIGHT/2
		
			If (s.behavior <> "inert") And s.base.ord = False'they don't have the bigger rect
				If fTable[p1.squad.faction,s.squad.faction]= 1 Then SetColor 0,255,0
				If fTable[p1.squad.faction,s.squad.faction]= 0 Then SetColor 0,0,255
				If fTable[p1.squad.faction,s.squad.faction]= -1
					If globalFrame Then SetColor 255,0,0 Else SetColor 230,70,0'enemies flash
				EndIf
				DrawRect drawx-1,drawy-1,4,4
			EndIf
			
			SetColor 0,0,0
			
			If s.base.ord
				If globalFrame Then SetColor 230,70,0 Else SetColor 200,0,0'ordnance flashes
			EndIf
			
			DrawRect drawx,drawy,2,2
		Next
		
		'draw the shots on the map, rel. to the player
		For Local s:Shot = EachIn shotList
			Local drawx = (s.x - p1.x)/mapzoom + SWIDTH/2
			Local drawy = (s.y - p1.y)/mapzoom + SHEIGHT/2
			
			If globalFrame Then SetColor 230,70,0 Else SetColor 200,0,0'ordnance flashes
			
			DrawRect drawx,drawy,1,1
		Next
		
		'draw the items on the map rel. to the player
		For Local i:Item = EachIn itemList
			Local drawx = (i.x - p1.x)/mapzoom + SWIDTH/2
			Local drawy = (i.y - p1.y)/mapzoom + SHEIGHT/2
			
			SetColor 200,200,80
			
			If i.name = "point" Then SetColor 80,80,200'points are blue
			
			If i.name = "beacon" And globalFrame Then SetColor 200,20,20'beacons flash
			
			If i.name = "gate"
				DrawRect drawx-3,drawy-3,7,7'gates are long
			Else
				DrawRect drawx,drawy,2,2
			EndIf
		Next
		
		'draw the map borders
		SetAlpha .7
		SetColor 16,16,16
		'right
		DrawRect SWIDTH/2 + (game.width - p1.x)/mapzoom, SHEIGHT/2 + (-game.height - p1.y)/mapzoom - SHEIGHT, SWIDTH, (game.height*2)/mapzoom + SHEIGHT*2
		'left
		DrawRect SWIDTH/2 + (-game.width - p1.x)/mapzoom, SHEIGHT/2 + (-game.height - p1.y)/mapzoom - SHEIGHT, -SWIDTH, (game.height*2)/mapzoom + SHEIGHT*2
		'bottom
		DrawRect SWIDTH/2 + (-game.width - p1.x)/mapzoom, SHEIGHT/2 + (game.height - p1.y)/mapzoom,	(game.width*2)/mapzoom, SHEIGHT
		'top
		DrawRect SWIDTH/2 + (-game.width - p1.x)/mapzoom, SHEIGHT/2 + (-game.height - p1.y)/mapzoom, (game.width*2)/mapzoom, -SHEIGHT
		
		'reset the viewport
		SetViewport 0,0,SWIDTH,SHEIGHT
	EndIf

	
	'how far away is the mouse?
	Local m_dx# = (cursorx - (p1.x+game.camx))
	Local m_dy# = (cursory - (p1.y+game.camy))
	Local mdist# = approxDist(m_dx,m_dy)
	
	'tween the mouse
	SetScale 1+mousetween,1+mousetween
	SetColor 255,255,255
	SetAlpha 1
	SetRotation 360*mousetween
	
	'draw the mouse
	DrawImage target3_gfx,cursorx,cursory
	SetAlpha mousetween
	DrawImage target3_hit_gfx,cursorx,cursory

	'display the current objectives
	If game.display_objectives
		SetScale 1,1
		SetAlpha .6
		SetRotation 0
		Local oy = 30
		Local ox = 12
		For Local o:Objective = EachIn game.objectiveList
			'list any text
			If o.text <> ""
				If o.flash And globalframe = 1 Then SetColor 192,192,192 Else SetColor 255,255,255'flash it?
				DrawText "> "+o.text, ox ,oy
				oy:+ TextHeight("BOBCAT") + 4
			EndIf
			
			'if this objective has a target, draw arrows at it	
			If (o.tarx <> 0) Or (o.tary <> 0)
				draw_arrow(o.tarx,o.tary,"",o.flash)
			EndIf
			If (o.tarship <> Null) And Not o.tarship.dead
				draw_arrow(o.tarship.x,o.tarship.y,"",o.flash)
			EndIf
		Next
	EndIf
	
	'draw arrows to all objectives whether they like it or not
	'For Local o = 0 To 5
		
	'Next
EndFunction


'if the player's dead,  draw highscores, credits
Function draw_dead_display()
If p1 <> Null And game.lives <= 0
	'if they've been dead awhile
	If p1.placeholder.dead
	
		'tell them they're dead
		If ListIsEmpty(mboxList)
			Select Rand(0,10)
			Case 0,1,2,9
				new_message("- YOU ARE DEAD -")
			Case 3,4,5,10
				new_message("- PLEASE TRY AGAIN -")
			Case 6
				new_message("- OUT OF CREDITS -")
				new_message("- INSERT CREDIT TO CONTINUE -")
			Case 7
				new_message("- WELL, AT LEAST YOU TRIED -")
			Case 8
				new_message("- I LOVE THAT DEATH EFFECT -")
			EndSelect
		EndIf
		
		'flip between display modes
		If MouseHit(MOUSE_FIREPRIMARY) Or JoyHit(JOY_FIREPRIMARY) Or KeyHit(KEY_SHIELD) Then game.dead_mode = (game.dead_mode + 1) Mod 2
		
		'back to menu, restart buttons
		Local m = MouseDown(MOUSE_FIREPRIMARY) Or JoyHit(JOY_FIREPRIMARY)
		dead_backB.x = SWIDTH - dead_backB.wid - 20
		dead_backB.y = 20
		'flash it
		If globalFrame
			dead_backB.RGB[0] = 190
			dead_backB.RGB[1] = 100
			dead_backB.RGB[2] = 1
		Else
			dead_backB.RGB[0] = 0
			dead_backB.RGB[1] = 0
			dead_backB.RGB[2] = 0
		EndIf
		dead_backB.draw()
		dead_backB.update(m)
		If dead_backB.pressed = 2 Then game.over = 2
		
		dead_restartB.x = SWIDTH - dead_restartB.wid - 20
		dead_restartB.y = 60
		dead_restartB.draw()
		dead_restartB.update(m)
		If dead_restartB.pressed = 2
			game.over = True
			game.restart = True
		EndIf
		
		'WHAT TO DISPLAY?
		Select game.dead_mode
		Case 1'highscores
			SetColor 255,255,255
			SetRotation 0
			SetBlend ALPHABLEND
			Local texthet = TextHeight("BOBCAT")*2+4
			Local ox = 130
			Local oy = 50
			SetScale 2,2
			SetColor 255,255,255
			Local difftext$
			Select pilot.difficulty
			Case 0'ZEN
				'no zen highscores
			Case .5
				difftext = "NORMAL"
			Case 1
				difftext = "HARD"
			Default
				difftext = "REALLY?"
			EndSelect
			draw_text("HIGH SCORES: "+difftext+" DIFFICULTY", ox,oy)
			'draw all the high scores
			oy:+ 50+texthet
			Local i = 1
			draw_text("NAME          SHIP               WAVE", ox, oy)
			oy:+ texthet
			For Local score:Highscore = EachIn highscoreList
				If score.difficulty = pilot.difficulty
					If score.highlight And globalFrame Then SetColor 212,120,120 Else SetColor 192,192,192
					draw_text(i+"] "+score.name,								ox, oy+texthet*i)
					draw_text("              " + score.ship, 					ox, oy+texthet*i)
					draw_text("                                 " + score.wave,		ox, oy+texthet*i)
					If score.highlight Then draw_text("-->                                       <--",	ox-80, oy+texthet*i)
					
					i:+ 1
					
					If oy+texthet*i >= SWIDTH Then Exit'enough is enough
				EndIf
			Next
		
		Case 0'credits
			Local i = 0
			For Local line$ = EachIn credits
				Local center = False'does this line get its own special center
				Local title = False'is the text bigger
				
				Local space = line.Find(" ")
				'if there are parameters
				If space <> -1
					'get the parameters
					Local optionName$ = line[..space]
				
					Select Lower(optionName)
					'graphics
					Case "title"
						center = True
						title = True
						line = line[space+1..]
					Case "center"
						center = True
						line = line[space+1..]
					EndSelect
				EndIf
				
				Local scale = 1
				SetColor 200,200,200
				SetAlpha 1
				SetRotation 0
				
				If title
					i:+ 1'titles skip a line above them
					scale = 2
				EndIf
				
				SetScale scale,scale
				
				Local drawx = (SWIDTH/2) - 350 + ((i Mod 2) * 400)
				Local drawy
				If Not (title Or center)
					drawy = (Floor(i/2)*2) * TextHeight("BOBCAT") - game.dead_credits_scroll
				Else
					drawy = i * TextHeight("BOBCAT") - game.dead_credits_scroll
				EndIf
				
				If center
					SetColor 255,255,255 
					drawx = (SWIDTH/2) - TextWidth(line)*scale/2
				EndIf
				
				If drawy > -15 And drawy <= SWIDTH Then draw_text(line, drawx, drawy)
					
				If title Or center Then i:+ 3'titles skip a line below them
				
				i:+ 1
			Next
			
			'scroll the credits
			game.dead_credits_scroll:+ 2
			If game.dead_credits_scroll > (i+10)*TextHeight("BOBCAT") Then game.dead_credits_scroll = -SHEIGHT
		EndSelect
		
		'draw the mouse
		draw_cursor()
		
	'if player JUST died, tell them they can switch ships (quirk: the ship has not updated its placeholder.dead at this point yet, so we can distinguish, above)
	ElseIf p1.armour <= 0
		'save your high score
		Local score:Highscore = New Highscore
		score.name = pilot.name
		score.ship = p1.name
		score.difficulty = pilot.difficulty
		score.wave = game.value[0]
		score.highlight = True
		highscoreList.addLast(score)
	
		save_highscores()
	EndIf
EndIf
EndFunction


'draws an arrow + distance + some text at the edge of the screen towards some point. it can even flash!
Function draw_arrow(_x, _y, _text$ = "", _flash = False)
	'draw a little arrow at them if they're offscreen
	SetColor 255,255,255
	SetBlend ALPHABLEND
	'SetScale 1,1
	Local dx = _x-p1.x
	Local dy = _y-p1.y
	
	Local tarDist# = approxDist(constrain(Abs(dx-game.camxoffset)-SWIDTH/2,0,9999),constrain(Abs(dy-game.camyoffset)-SHEIGHT/2,0,9999))
	Local textDist$ = String(Int(tardist))	
	
	SetAlpha 1'(.7-constrain(tarDist/5000, 0, .7)) + .1
	Local scale# = constrain((16000/((tarDist/5)^2)), 1.0, 1.5)
	SetScale scale,scale
	
	Local arrowy = constrain(_y - (-game.camy + SHEIGHT/2), -SHEIGHT/2, SHEIGHT/2)
	Local arrowx = constrain(_x - (-game.camx + SWIDTH/2), -SWIDTH/2, SWIDTH/2)
	
	Local arrowrot = 0
	Local arrowframe = 0
	If _flash And globalFrame Then arrowframe = 1
	
	'if it's offscreen
	If Abs(arrowy) = SHEIGHT/2 Or Abs(arrowx) = SWIDTH/2
	
		'are we going diagonal?
		If Abs(arrowy) = SHEIGHT/2 And Abs(arrowx) = SWIDTH/2
			'default upright
			arrowrot = 45
			'if pointing down
			If Sgn(arrowy) = 1
				arrowrot:+ 90
				'if pointing downleft
				If Sgn(arrowx) = -1 Then arrowrot:+ 90
			'if pointing upright
			ElseIf Sgn(arrowx) = -1
				arrowrot:+ 270
			EndIf
		'is either directly vertical or horizontal
		Else
			'if it's horizontal
			If Abs(arrowx) = SWIDTH/2
				arrowrot:+ 90
				'to the left?
				If Sgn(arrowx) = -1 Then arrowrot:+ 180
			'if it's below
			ElseIf Sgn(arrowy) = 1
				arrowrot:+ 180
			EndIf
		EndIf
		
		'figure out the offset (BRUTE FORCE? well it's faster than a trig function I guess)
		Local arrowsize = ImageHeight(HUD_arrow_gfx)/2
		Local arrowoffx,arrowoffy
		Local textwid = TextWidth(textDist)/2
		Local texthet = TextHeight(textDist)
		Local textoffx, textoffy
		Select arrowrot
		Case 0
			arrowoffy = arrowsize
			textoffx = -textwid
		Case 45
			arrowoffy = arrowsize
			arrowoffx = -arrowsize
		Case 90
			arrowoffx = -arrowsize
			textoffy = -textwid
		Case 135
			arrowoffy = -arrowsize
			arrowoffx = -arrowsize
		Case 180
			arrowoffy = -arrowsize
			textoffx = -textwid
			textoffy = -texthet
		Case 225
			arrowoffy = -arrowsize
			arrowoffx = arrowsize
		Case 270
			arrowoffx = arrowsize
			textoffx = texthet
			textoffy = -textwid
		Case 315
			arrowoffy = arrowsize
			arrowoffx = arrowsize
		EndSelect
		
		arrowoffx:* scale
		arrowoffy:* scale

		SetRotation arrowrot
		DrawImage HUD_arrow_gfx, arrowx+arrowoffx+SWIDTH/2, arrowy+arrowoffy+SHEIGHT/2, arrowframe
		
		Rem
		'draw how far away the enemy is
		Local textrot = arrowrot Mod 180
		If textrot = 135 Then textrot = 315
		SetRotation textrot
		SetScale 1,1
		Local textx = arrowx+arrowoffx+SWIDTH/2  + textoffx
		Local texty = arrowy+arrowoffy+SHEIGHT/2 + textoffy
		DrawText textDist, textx, texty
		EndRem
	EndIf
EndFunction

'draws a gfx at the current cursor position
Function draw_cursor()
	'"key pressing" frame of the cursor?
	'Local cursorframe = 0
	'If MouseDown(MOUSE_FIREPRIMARY) Or JoyDown(JOY_FIREPRIMARY) Then cursorframe = 1

	SetScale 1,1
	SetAlpha 1
	SetRotation 0
	SetColor 255,255,255
	DrawImage cursor_gfx[0], cursorx, cursory
EndFunction

'moves the mouse/cursor to a position (center if none provided)
Function moveCursor(_x = -1, _y = -1)
	If _x = -1 And _y = -1
		_x = SWIDTH/2
		_y = SHEIGHT/2
	EndIf
	
	'move the mouse and cursor
	MoveMouse(_x, _y)
	cursorx = _x
	cursory = _y
EndFunction

'updates the global variables cursorx and cursory (heh) according to the current control scheme
'moves differently ingame vs in menus. ingame, depends on distance to player, while in menus it's just constant
'when not ingame, forces the mouse to be functional
Function updateCursor(_ingame = False)
	'is there a joystick?
	If JoyCount() Then joyDetected = True Else joyDetected = False


	'Select control_scheme
	
	'using the mouse
	If Not joyDetected
	'Case SCHEME_KEY 
	'	cursorx = MouseX()
	'	cursory = MouseY()

	'using the joystick
	Else
	'Case SCHEME_JOY
		Local amplify# = JOY_AMPLIFY
	
		If _ingame
			'the further the distance from player, the faster it moves
			Local m_dx# = (cursorx - (p1.x+game.camx))
			Local m_dy# = (cursory - (p1.y+game.camy))
			Local m_radius# = Floor(Sqr(m_dx^2 + m_dy^2))
			
			amplify:+ (m_radius / 50)
		EndIf

		'If Not JoyCount()
			'control_scheme = SCHEME_KEY	'if no joystick, revert to mouse
		'	FlushJoy()
		'	FlushKeys()
		'	FlushMouse()
		'Else
		
			'move the cursor according to the selected movement axis
			Select JOY_AIMAXIS
			Case JOY_RIGHTSTICK
				If Abs(JoyZ()) > .05 Then cursorx:+ JoyZ()*amplify
				If Abs(JoyR()) > .05 Then cursory:+ JoyR()*amplify
				
			Case JOY_LEFTSTICK
				If Abs(JoyX()) > .05 Then cursorx:+ JoyX()*amplify
				If Abs(JoyY()) > .05 Then cursory:+ JoyY()*amplify
				
			Case JOY_HAT
				Select JoyHat()
				Case 0'UP
					cursory:- amplify
				Case 1'UPRIGHT
					cursory:- amplify
					cursorx:+ amplify
				Case 2'RIGHT
					cursorx:+ amplify
				Case 3'DOWNRIGHT 		ridiculous!
					cursory:+ amplify
					cursorx:+ amplify
				Case 4'DOWN
					cursory:+ amplify
				Case 5'DOWNLEFT
					cursory:+ amplify
					cursorx:- amplify
				Case 6'LEFT
					cursorx:- amplify
				Case 7'UPLEFT
					cursory:- amplify
					cursorx:- amplify
				EndSelect
			EndSelect
		'EndIf
	EndIf
	'EndSelect
	
	'forces mouse functionality: mouse movement sets the cursor
	If (Abs(MouseXSpeed()) > 1 Or Abs(MouseYSpeed()) > 1)' And Not _ingame
		cursorx = MouseX()
		cursory = MouseY()
	EndIf
		
	
	'keep it within the screen
	cursorx = constrain(cursorx, 0, SWIDTH)
	cursory = constrain(cursory, 0, SHEIGHT)
	If Not AppSuspended() And _ingame Then MoveMouse(cursorx, cursory)

EndFunction

'player controls
Function player_controls()
	
	'track the mouse location
	updateCursor(True)
	
	'detect how far mouse is from the ship's location
	Local m_dx# = (cursorx - (p1.x+game.camx))
	Local m_dy# = (cursory - (p1.y+game.camy))
	Local m_theta# = ATan2(m_dy,m_dx) + 90
	If Abs(m_theta) >= 180 Then m_theta = m_theta - 360*Sgn(m_theta)
	Local m_radius# = Floor(Sqr(m_dx^2 + m_dy^2))
	
	'find which direction to turn to face the mouse
	Local rotTar# =  m_theta - 90
	If Abs(rotTar) >= 180 Then rotTar = rotTar - 360*Sgn(rotTar)
	
	If p1.armour > 0 And Not game.disable_controls
		Local tarx,tary
				
		'rotate to face the mouse (if using fighter physics)
		If p1.turnRate = -1 Then p1.rot = rotTar
		
		'find exactly where, hypothetically, we'd shoot at
		tarx = p1.x + m_dx
		tary = p1.y + m_dy
			
		'ship controls!
		Local afterburn, thrust, reverse, strafeleft, straferight, joythrust#, joythrust_theta#, ability, switch, fire1, fire2, map
		
		'Select control_scheme
		'Case SCHEME_KEY	'using the KEYBOARD
		If Not joyDetected
			afterburn = KeyDown(KEY_AFTERBURN)
			thrust = (KeyDown(KEY_THRUST) Or KeyDown(KEY_UP))
			reverse = (KeyDown(KEY_REVERSE) Or KeyDown(KEY_DOWN))
			strafeleft = (KeyDown(KEY_STRAFELEFT) Or KeyDown(KEY_LEFT))
			straferight = (KeyDown(KEY_STRAFERIGHT) Or KeyDown(KEY_RIGHT))
			ability = KeyHit(KEY_SHIELD)
			switch = KeyHit(KEY_CYCLEGUN)
			fire1 = MouseDown(MOUSE_FIREPRIMARY)
			fire2 = MouseDown(MOUSE_FIRESECONDARY)
			map = KeyDown(KEY_TAB)
		
		Else
		'Case SCHEME_JOY 'using a JOYSTICK
			afterburn = JoyDown(JOY_AFTERBURN)	Or afterburn
			thrust = JoyDown(JOY_THRUST)		Or thrust
			ability = JoyDown(JOY_SHIELD)		Or ability
			switch = JoyDown(JOY_CYCLEGUN)		Or switch
			fire1 = JoyDown(JOY_FIREPRIMARY)	Or fire1
			fire2 = JoyDown(JOY_FIRESECONDARY)	Or fire2
			map = JoyDown(JOY_MAP)				Or map
			
			'different method of joy movement
			Select JOY_MOVEAXIS
			Case JOY_HAT
				thrust =		( JoyHat(0) Mod 6 <= 1 )					Or thrust
				straferight = 	(( JoyHat(0) >= 1 ) And ( JoyHat(0) <= 3 ))	Or straferight
				reverse =		(( JoyHat(0) >= 3 ) And ( JoyHat(0) <= 5 )) Or reverse
				strafeleft =	(( JoyHat(0) >= 5 ) And ( JoyHat(0) <= 7 )) Or strafeleft
			Case JOY_LEFTSTICK
				joythrust = constrain(Sqr(JoyX(0)^2 + JoyY(0)^2), 0, 1)
				joythrust_theta = ATan2(-JoyX(0),JoyY(0)) + 90
			Case JOY_RIGHTSTICK
				joythrust = constrain(Sqr(JoyZ(0)^2 + JoyR(0)^2), 0, 1)
				joythrust_theta = ATan2(-JoyZ(0),JoyR(0)) + 90
			Case JOY_OTHERSTICK
				joythrust = constrain(Sqr(JoyU(0)^2 + JoyV(0)^2), 0, 1)
				joythrust_theta = ATan2(-JoyU(0),JoyV(0)) + 90
			EndSelect
			
			'KILL THE NOISE
			If joythrust < .01 Then joythrust = 0	
		'EndSelect		
		EndIf

		'afterburn
		If afterburn Or p1.burnerOn
			If Not cheat_disableengines Then p1.add_thrust(0,2.0)'modify max speed, force
		Else
			'KEYBOARD thrust commands
			'thrusting
			If Not cheat_disableengines
				If thrust Then p1.add_thrust(0,1.0)
			EndIf
			If reverse Then p1.add_thrust(180,1.0)'.8)
			
			'fighter physics: strafing
			If p1.turnRate = -1
				If strafeleft Then p1.add_thrust(270,1.0)'p1.strafe)
				If straferight Then p1.add_thrust(90,1.0)'p1.strafe)
			EndIf
			
			'JOYSTICK thrust commands
			If joythrust > 0 Then p1.add_thrust(joythrust_theta,joythrust,True)
		EndIf
		
		'frigate physics: turning
		If p1.turnRate > 0
			If strafeleft Then p1.turn(-90,False)
			If straferight Then p1.turn(90,False)
		EndIf
		
		'activate shields/other ability?
		If ability Then p1.activateAbility()
		
		'switch weapons
		If switch Then pilot.cycleweapons()
		
		'mouse controls!
		If fire1 Then p1.fireGroup(0,tarx,tary)
		If fire2 Then p1.fireGroup(pilot.selgroup,tarx,tary)
		
		'display map
		If map Then pilot.map_toggle = True Else pilot.map_toggle = False
		
		'toggle objective display
		'If KeyHit(KEY_O) Then game.display_objectives = Not game.display_objectives
		
		'toggle friend/foe info
		'If KeyHit(KEY_F) Then display_ff = Not display_ff
		
		'end the game cheatily
		If KeyHit(KEY_N) Then game.over = True
	
	EndIf
	
	'Windows-ONLY
	?Win32
		'take a screenshot
		If OS = 0'PC
			If GetAsyncKeyState(KEY_SCREEN)
				'make sure the folder exists
				If FileType("screenshots") <> 2 Then CreateDir("screenshots")
				'see what number we're on for screenshots
				Local num, numtext$, nextnum
				Repeat
					'do we need to move onto the next number?
					nextnum = False
					
					'use the next number
					num:+ 1
					
					'stick a couple of zeros at the front of the number we're using
					numtext$ = num
					While Len(numtext) < 3
						numtext = "0"+numtext
					Wend
				
					'if we found a number that there isn't a screenshot for yet
				Until FileType("screenshots\screen_"+numtext+".png") = 0
				
				Print "saving screenshot 'screenshots\screen_"+numtext+".png'"
				
				'take a screenshot and save it as this filename
				SavePixmapPNG(GrabPixmap(0,0,SWIDTH,SHEIGHT), "screenshots\screen_"+numtext+".png")
			EndIf
		EndIf
	?
EndFunction

'adds (& returns) an explosion foreground
Function add_explode:Foreground(_x#,_y#,_lifetimer = 2000)
	Local fg:Foreground = New Foreground
	If Rand(1,2) = 1 Then fg.gfx = explode1_gfx Else fg.gfx = explode6_gfx'a bit of explosion variation
	fg.animated = True
	fg.frameoffset = Rand(0,1)
	fg.x = _x
	fg.y = _y
	fg.rot = Rand(0,359)
	fg.spin = (RndFloat()-.5)*15
	fg.lifetimer = _lifetimer
	fg.alphaSpeed = (RndFloat()+.5)*100.0/Float(fg.lifetimer)
	fg.scale = (RndFloat()+.5)*.8
	fg.scalespeed = .01*fg.scale / (fg.lifetimer/1000)
	If Rand(1,2) = 1 Then fg.blend = LIGHTBLEND
	fg.dist = 1
	fg.link = explodeList.addLast(fg)
	
	Return fg
EndFunction

'add debris
'_debrisName | "rock":rock debris | "metal":metal debris | "gib":biological debris
Function add_debris:Background(_debrisName$, _x,_y,_movrot,_speed, addToDebrisList = True) 
	'background or forground?
	Local deb:Background
	Local bg = Rand(0,1)
	If bg 
		deb = New Background
	Else
		deb = New Foreground
	EndIf
	
	'debris properties
	Local deb_gfx:TImage[1]
	If _debrisName = "rock" Then deb_gfx[0] = rockdeb_gfx[Rand(0,3)]
	If _debrisName = "metal" Then deb_gfx[0] = metaldeb_gfx[Rand(0,4)]
	If _debrisName = "gib" Then deb_gfx[0] = gibdeb_gfx[Rand(0,5)]
	If _debrisName = "vector" Then deb_gfx = trail_gfx
	deb.gfx = deb_gfx
	deb.animated = False
	deb.mass = 2
	deb.x = _x
	deb.y = _y
	deb.movrot = _movrot
	deb.speed = _speed
	deb.accel = -.005
	deb.spin = (RndFloat()-.5)*3.5
	deb.dist = 1+RndFloat()/20.0
	deb.distSpeed = _speed*RndFloat()/100.0
	If Not bg'forgrounds move forward
		deb.dist= 1/deb.dist
		deb.distSpeed:* -1
	EndIf
	'deb.distShade = True
	deb.shade = 155
	deb.scale = .9
	deb.lifetimer = Rand(1500,8000)
	If addToDebrisList Then deb.link = debrisList.addLast(deb)
	
	Return deb
EndFunction

'add a little flashing particle
Function add_particle:Background(_x,_y,_movrot,_speed,_lifetime,_bg) '_bg : TRUE=background | FALSE=foreground
	'background or forground?
	Local p:Background
	If _bg Then p = New Background Else p = New Foreground
	p.gfx = explode4_gfx
	p.animated = True
	p.frameoffset = Rand(0,1)
	p.mass = 2
	p.x = _x
	p.y = _y
	p.movrot = _movrot
	p.speed = _speed
	p.spin = (RndFloat()-.5)*2
	p.dist = 1
	p.scale = (RndFloat()+.75)/2
	p.lifetimer = _lifetime
	p.link = explodeList.addLast(p)
	
	Return p
EndFunction

'adds floating text
Function add_text:Foreground(_text$,_x,_y,_lifetime = 2200, _red = True)
	'background or forground?
	Local p:Foreground = New Foreground
	p.text = _text
	p.animated = False
	p.ignorePhysics = True
	p.rot = 270'right-side up
	p.x = _x
	p.y = _y
	p.movrot = 270'up a little
	p.speed = .5
	p.alphaSpeed = .0125
	p.dist = 1
	p.lifetimer = _lifetime
	p.scale = 1 / SHIPSCALE
	'default color = red
	If _red
		p.RGB[0] = 255
		p.RGB[1] = 10
		p.RGB[2] = 10
	EndIf
	p.link = explodeList.addLast(p)
	
	Return p
EndFunction

'adds an trail background
Function add_trail:Background(_x#,_y#,_rot#, _scale# = 1, _RGB[], _red = False, _lifetime = delayFrame*20)
	Local bg:Background = New Background
	bg.animated = False
	'bg.ignorePhysics = True
	bg.x = _x
	bg.y = _y
	bg.rot = _rot
	bg.movrot = Rand(0,359)
	bg.speed = RndFloat()/4
	bg.alphaSpeed = .015 - RndFloat()*.01
	bg.dist = 1
	bg.scale = .01 + _scale
	bg.blend = LIGHTBLEND
	bg.lifetimer = _lifetime*(RndFloat()+.5)
	bg.RGB[0] = _RGB[0]
	bg.RGB[1] = _RGB[1]
	bg.RGB[2] = _RGB[2]
	
	bg.gfx = trail_gfx
	If _red
		bg.shade = Rand(0,100)
		bg.RGB[0] = 255
		bg.RGB[1] = 50
		bg.RGB[2] = 40
		bg.lifetimer:/ 4
		bg.alphaSpeed:*2
		bg.scale:*1.6
	EndIf
	
	'bg.shade:+ 70
	
	bg.link = bgList.addLast(bg)
	
	Return bg
EndFunction

'something fires a shot
Function add_shot:Shot(_owner:Ship,_name$,_gfx:TImage[],_x#,_y#,_movrot#,_speed#,_range,_damage#)
	Local l:Shot = New Shot
	l.frameoffset = Rand(0,1)
	
	'given values
	l.name = _name
	l.gfx = _gfx
	l.x = _x#
	l.y = _y#
	l.rot = _movrot
	l.movrot = _movrot
	l.speed = _speed
	l.speedBase = l.speed
	l.lifetimer = (_range / (_speed+1)) * 1000
	l.damage = _damage
	
	'default values
	l.hit_gfx = explode1_gfx
	l.hit_sfx = laserhit_sfx
	l.mass = 2
	l.durable = False'removed after hitting something
	l.blend = LIGHTBLEND
	l.animated = True
	
	l.link = shotList.AddLast(l)
	
	l.owner = _owner
	
	If l.owner <> Null
		'no self-harm
		l.ignoreList.AddLast(l.owner.placeholder)
	
		'add the ship's current velocity to the shot, NO DOPPLER!!!
		l.addSpeed(l.owner.speed, l.owner.movrot)
		
		'Local ship_sx# = Cos(l.owner.movrot) * l.owner.speed
		'Local ship_sy# = Sin(l.owner.movrot) * l.owner.speed
		'Local shot_sx# = Cos(l.movrot) * l.speed
		'Local shot_sy# = Sin(l.movrot) * l.speed
		
		'l.speed = Sqr((ship_sx+shot_sx)^2+(ship_sy+shot_sy)^2)
		'l.movrot = ATan2((ship_sy+shot_sy),(ship_sx+shot_sx))
	
		'current ship damage bonuses
		If l.owner.overchargeOn
			l.damage:* l.owner.overcharge_mod
			l.speed:* l.owner.overcharge_mod
			l.scale:* l.owner.overcharge_mod
			l.trail_scale:* l.owner.overcharge_mod
			l.RGB[0] = 255
			l.RGB[1] = 205
			l.RGB[2] = 110
			l.trailRGB[0] = 255
			l.trailRGB[1] = 205
			l.trailRGB[2] = 110
		EndIf

		'muzzle flare
		Rem
		If _muzzleFlare = True
			Local fg:Foreground = New Foreground
			fg.forceList = New TList
			fg.gfx = explode3_gfx
			fg.animated = True
			fg.frameoffset = Rand(0,1)
			fg.ignorePhysics = True
			fg.x = _x
			fg.y = _y
			fg.rot = l.owner.rot
			fg.movrot = l.owner.movrot
			fg.speed = l.owner.speed
			fg.lifetimer = delayFrame*2
			fg.alphaSpeed = .04
			fg.scaleSpeed = .05
			fg.dist = 1
			fg.blend = LIGHTBLEND
			fg.link = explodeList.AddLast(fg)
		EndIf
		EndRem
	EndIf
	
	Return l
EndFunction

'drop an item somewhere
Function add_item:Item(_name$,_gfx:TImage[],_x#,_y#,_movrot#,_speed#, addToItemList = True)
	Local t:Item = New Item
	t.gfx = _gfx
	t.animated = True
	t.frameoffset = Rand(0,1)
	t.name = _name
	t.mass = 5
	t.x = _x#
	t.y = _y#
	t.rot = 270'_movrot
	t.movrot = _movrot
	t.spin = 0'RndFloat()*6
	t.speed = _speed
	t.scale = .75
	t.lifetimer = POINT_LIFETIME
	If addToItemList Then t.link = itemList.AddLast(t)
	Return t
EndFunction

'makes a bunch of asteroids within a radius of a point(interactable ones + bg/fg)
Function add_asteroids:Squadron(_asteroidNum, _x, _y, _radius, _specials = True)'if _specials, then spawn dem point-dropping asteroids
	
	'[1 in dropchance] asteroids will drop an ability recharge
	Local dropchance = 9
	'[1 in pointchance] asteroids will drop points
	Local pointchance = 12
	
	Local cometSquad:Squadron = New Squadron
	cometSquad.x = _x
	cometSquad.y = _y
	cometSquad.goal_x = _x
	cometSquad.goal_y = _y
	cometSquad.behavior = "inert"
	cometSquad.setPos = True
	
	Local bignum = constrain(Rand(-8,1),0,1)
	If bignum > 0
		'a couple BIIIG asteroids
		For Local i = 1 To bignum
			Local a:Ship = new_ship("Asteroid 3",0,0,"",cometSquad)
			a.x = _x + Rand(-_radius,_radius)
			a.y = _y + Rand(-_radius,_radius)
			a.movrot = Rand(0,359)
			a.speed = RndFloat()*a.speedMax
			a.spin = (RndFloat()-.5)
			
			'SURPRISE!!!
			Local surprise:Ship = new_ship("Missile",a.x,a.y,"default", Null, False)
			surprise.squad.faction = 0
			surprise.speedMax = 1
			'set the damage, size of the explosion
			For Local c:Component = EachIn surprise.compList
				c.damageBonus = 300
			Next
			surprise.recalc()
			surprise.AI_timer = 2'explode immediately	
			surprise.movrot = 0
			surprise.speed = 0
			surprise.behavior = "torpedo"
			surprise.squad.behavior = "torpedo"
			surprise.squad.goal_x = a.x
			surprise.squad.goal_y = a.y
			'surprise.scale = .1
			surprise.thrust = 0
		
			a.dropList.addLast(surprise)
		Next
	Else		
		For Local i = 1 To _asteroidNum
			'interaction asteroids
			Local a:Ship
			Local size = (Rand(1,5) < 4) '1 (small) or 0 (big)
			If size Then a = new_ship("Asteroid 1",0,0,"",cometSquad) Else a = new_ship("Asteroid 2",0,0,"",cometSquad)
			a.x = _x + Rand(-_radius,_radius)
			a.y = _y + Rand(-_radius,_radius)
			a.movrot = Rand(0,359)
			a.speed = RndFloat()*a.speedMax
			a.spin = (RndFloat()-.5)*2
			Local special = Rand(0,12)
			If special = 0'a special asteroid
				If size Then a.gfx = asteroid5_gfx Else a.gfx = asteroid4_gfx'special graphic
				'give it points
				For Local p = 0 To (a.mass/4 + Rand(0,2))
					a.dropList.addLast(add_item("point",point1_gfx,0,0,0,0,False))
				Next
				a.shade = 0
				a.debrisRGB[0] = 150
				a.debrisRGB[1] = 200
				a.debrisRGB[2] = 255
			'Else'a regular asteroid
				'maybe give it ability recharges
				'If Rand(1,dropchance) = 1 Then a.dropList.addLast(add_item("abilitypoint",point2_gfx,0,0,0,0,False))
			EndIf
		Next
	EndIf
	
	For Local i = 1 To _asteroidNum
		'background asteroids
		Local bg:Background = New Background
		If Rand(1,5)=1 Then bg.gfx = asteroid2_gfx Else bg.gfx = asteroid1_gfx
		bg.animated = False
		bg.ignorePhysics = True
		bg.x = _x + (Rand(-_radius,_radius)*3)
		bg.y = _y + (Rand(-_radius,_radius)*3)
		bg.rot = Rand(0,359)
		bg.spin = (RndFloat()-.5)*1.5
		bg.dist = 2+(3*RndFloat())
		bg.distShade = True
		bg.link = bgList.AddLast(bg)
	Next
	
	Return cometSquad
EndFunction

'makes a bunch of EXPLODING asteroids within a radius of a point
Function add_exploding_asteroids(_asteroidNum, _x, _y, _radius)
	
	Local cometSquad:Squadron = New Squadron
	cometSquad.x = _x
	cometSquad.y = _y
	cometSquad.goal_x = _x
	cometSquad.goal_y = _y
	cometSquad.behavior = "inert"
	cometSquad.setPos = True
	
	For Local i = 1 To _asteroidNum
		'interaction asteroids
		Local a:Ship
		Local size = Rand(1,25)
		If size <= 4
			a = new_ship("Explosive Asteroid 3",0,0,"",cometSquad)'BIG
		ElseIf size < 16
			a = new_ship("Explosive Asteroid 2",0,0,"",cometSquad)'large
		Else
			a = new_ship("Explosive Asteroid 1",0,0,"",cometSquad)'small
		EndIf
		a.x = _x + Rand(-_radius,_radius)
		a.y = _y + Rand(-_radius,_radius)
		a.movrot = Rand(0,359)
		a.speed = RndFloat()*4
		a.spin = (RndFloat()-.5)*2
		
		'MAK GO BOOM
		Local surprise:Ship = new_ship("Missile",a.x,a.y,"default", Null, False)
		surprise.squad.faction = 0
		surprise.speedMax = 1
		'set the damage, size of the explosion
		For Local c:Component = EachIn surprise.compList
			c.damageBonus = 300 / size
		Next
		surprise.recalc()
		surprise.AI_timer = 2'explode immediately	
		surprise.movrot = 0
		surprise.speed = 0
		surprise.behavior = "torpedo"
		surprise.squad.behavior = "torpedo"
		surprise.squad.goal_x = a.x
		surprise.squad.goal_y = a.y
		'surprise.scale = .1
		surprise.thrust = 0
	Next
EndFunction


'add a slowly-spinning beacon at the indicated location
Function add_beacon:Item(_x,_y) 
	Local beacon:Item = New Item
	beacon.name = "beacon"
	beacon.gfx = target5_gfx
	beacon.animated = True
	beacon.mass = 10000
	beacon.x = _x
	beacon.y = _y
	beacon.spin = .5
	beacon.dist = 1
	beacon.alpha = 0
	beacon.lifetimer = 0'sticks around till we kill it
	beacon.link = itemList.addLast(beacon)
	Return beacon
EndFunction

'adds a human station
Rem
Function add_station:Ship(_x,_y,_faction = 1)
	'make the station itself
	Local station:Ship = new_ship("Station",_x,_y)
	station.squad.faction = _faction
	station.skipDraw = True
	station.tweenOnHit = False
	station.animated = False
	station.ignoreCollisions = True
	station.ignorePhysics = True
	'station.ignoreMovement = True
	station.reset()
	station.link = entityList.AddLast(station)
	
	'make the background for the station that you actually see
	Local bg:Background = New Background
	bg.gfx = human_station_gfx
	bg.animated = False
	bg.master = station
	bg.lifetimer = 0
	bg.link = bgList.addLast(bg)
	
	'make some turrets
	Local turret:Ship = new_ship("Human Turret",0,0)
	turret.master = station
	turret.squad.faction = station.squad.faction
	
	turret = new_ship("Human Turret",0,0)
	turret.master = station
	turret.squad.faction = station.squad.faction
	turret.master_offy = -218
	
	turret = new_ship("Human Turret",0,0)
	turret.master = station
	turret.squad.faction = station.squad.faction
	turret.master_offy = 218
	
	turret = new_ship("Human Turret",0,0)
	turret.master = station
	turret.squad.faction = station.squad.faction
	turret.master_offx = 312
EndFunction
EndRem

'add a stationary gate at the specified location. Returns the item you can feed ship to warp in and detects ships (if active) to warp out.
Rem
Function add_gate:Item(_x,_y,_rot# = 0)
	Local gategate_gfx:TImage[2]

	'GATE FOREGROUND
	Local	gatefg:Foreground = New Foreground
	gategate_gfx[0] = gate_gfx[1]
	gategate_gfx[1] = gate_gfx[1]
	gatefg.gfx = gategate_gfx
	gatefg.animated = False
	gatefg.x = _x + Sin(_rot)*18
	gatefg.y = _y - Cos(_rot)*18
	gatefg.rot = _rot-90
	gatefg.lifetimer = 0
	gatefg.link = bgList.addLast(gatefg)
	
	'GATE BACKGROUND
	Local	gatebg:Background = New Background
	gategate_gfx[0] = gate_gfx[0]
	gategate_gfx[1] = gate_gfx[0]
	gatebg.gfx = gategate_gfx
	gatebg.animated = False
	gatebg.x = _x - Sin(_rot)*18
	gatebg.y = _y + Cos(_rot)*18
	gatebg.rot = _rot-90
	gatebg.lifetimer = 0
	gatebg.link = bgList.addLast(gatebg)

	'sides of the gate
	For Local i = -1 To 1 Step 2
		Local gate_edge:Ship = New Ship
		gate_edge.x = _x - i*Cos(_rot)*ImageWidth(gate_gfx[0])/2
		gate_edge.y = _y - i*Sin(_rot)*ImageWidth(gate_gfx[0])/2
		For Local c:Chassis = EachIn chassisList
			If c.name = "Asteroid 3" Then gate_edge.base = c
		Next
		gate_edge.name = "gate"
		gate_edge.behavior = "inert"
		gate_edge.squad = inertSquad
		gate_edge.gfx = gate_edge_gfx
		gate_edge.tweenOnHit = False
		gate_edge.animated = False
		gate_edge.invulnerable = True
		gate_edge.mass = 10000
		gate_edge.rot = _rot
		gate_edge.skipDraw = True
		gate_edge.ignoreCollisions = False
		gate_edge.ignorePhysics = True
		gate_edge.ignoreMovement = True
		gate_edge.reset()
		gate_edge.link = entityList.AddLast(gate_edge)
	Next
	
	Local gate:Item = New Item
	gate.name = "gate"
	gate.gfx = gategate_gfx
	gate.skipDraw = True
	gate.ignoreCollisions = False
	gate.ignorePhysics = True
	gate.ignoreMovement = True
	gate.mass = 10000
	gate.x = _x
	gate.y = _y
	gate.rot = _rot - 90
	gate.lifetimer = 0
	gate.state[1] = 2400'how long it takes to warp in a ship
	gate.link = itemList.addLast(gate)
	Return gate
EndFunction
EndRem

'play a sound with relative volume, etc to player (can use a prexisitng channel)
Function playSFX:TChannel(_sound:TSound,_x#,_y#, _ampVol# = 1.0, _channel:TChannel = Null)
	
	_ampVol:+ ((RndFloat()-.5)/2)
	
	If _sound = Null Then Print "trying to play null sound at :"+ _x+","+_y
	'onscreen?
	Local px,py
	If p1 <> Null And (_x <> -1 Or _y <> -1)'if x,y are -1 then force global playsound
		px = p1.x
		py = p1.y
	EndIf
	'if onscreen
	Local dist = constrain(approxDist(_x-px, _y-py), 0, 9999)
	If dist < SWIDTH And (_sound <> Null Or _channel <> Null)
		'cue up the sound in question - OR - just alter the prexisting channel
		Local tempChannel:TChannel
		If _channel = Null Then tempChannel = CueSound(_sound) Else tempChannel = _channel
		
		'make the sound channel the correct volume, pan, depth
		Local soundVol# = _ampVol * (Float(SHEIGHT)-dist)/Float(SHEIGHT)
		If soundVol < 0 Then soundVol = 0
		If soundVol > 1 Then soundVol = 1
		Local sfxAngle# = ATan2(py-_y,px-_x)
		SetChannelPan tempChannel,Cos(sfxAngle)*(1-_ampVol)'the closer, the less pronounced the effect is.
		SetChannelDepth tempChannel,Sin(sfxAngle)*(1-_ampVol)
		SetChannelVolume tempChannel,soundVol*sfxVol*sndVol'dist time global vol
		
		'play the sound 
		If Not ChannelPlaying(tempChannel) Then ResumeChannel(tempChannel)
		Return tempChannel
	EndIf
EndFunction

'keeps track of time passage, frame switching
Function updateTime()

	'time passage
	timePass = MilliSecs() - oldTime
	oldTime = MilliSecs()
	
	'frame time
	delayFrameTimer:- frameTime
	globalFrameSwitch = False
	If delayFrameTimer <= 0
		delayFrameTimer = delayFrame
		If globalFrame = 0 Then globalFrame = 1 Else globalFrame = 0
		globalFrameSwitch = True
	EndIf
EndFunction

'checks to see if we're trying to play another track; if so, fade the current one out and the new one in
Function updateMusic()

	'don't fade out to play the same thing
	If new_music = current_music Then new_music = Null
	
	'FUCK DA POLICE
	'If timePass < 1 Then timePass = 22
	
	'if there's a new song to play
	If (Not new_music = Null) Or resetmusic
		'fade the old music out
		If music_fade > 0 Then music_fade:- 2*(frameTime/1000.0)
		
		'start the new music
		If music_fade <= 0
			StopChannel music_channel
			If resetmusic And new_music = Null Then new_music = current_music
			current_music = new_music
			new_music = Null
			resetmusic = False
			music_channel = AllocChannel()
			PlaySound (current_music,music_channel)
		EndIf
	'fade in the new music
	ElseIf music_fade < 1'musicVol*sndVol
		music_fade:+ 2*(frameTime/1000.0)
	EndIf
	
	musicVol = constrain(musicVol, 0, 1)
	music_fade = constrain(music_fade, 0, 1)
	SetChannelVolume music_channel, musicVol*music_fade*sndVol
EndFunction


'two entities transfer their momentum to eachother. needs to have predicted positions of the ships inputs
'returns the amount of momentum transfered
Function transferMomentum(e1:Ship,e2:Ship,_e1px,_e1py,_e2px,_e2py)
	Local elastic# = .95

	'find the angle between the two
	Local theta# = ATan2((_e1py - _e2py),(_e1px - _e2px))
	
	'find their velocities perpendicular(alongside) & parallel(towards) to eachother
	Local u_para1# = Cos(e1.movrot - theta) * e1.speed
	Local u_perp1# = Sin(e1.movrot - theta) * e1.speed
	Local u_para2# = Cos(e2.movrot - theta) * e2.speed
	Local u_perp2# = Sin(e2.movrot - theta) * e2.speed
	
	'find the new parallel velocities, after momentum transfer
	Local mass_total# = e1.mass + e2.mass
	Local veloc_diff# = Abs(u_para2 - u_para1)
	
	If veloc_diff > .5
		Local v_para1# = ((elastic*e2.mass*veloc_diff) + (u_para1*e1.mass) + (u_para2*e2.mass)) / mass_total
		Local v_para2# = ((elastic*e1.mass*-veloc_diff) + (u_para1*e1.mass) + (u_para2*e2.mass)) / mass_total
		
		'get the new total speed for the two objects
		e1.speed= Sqr(v_para1^2 + u_perp1^2)' approxDist(v_para1,u_perp1)
		e2.speed= Sqr(v_para2^2 + u_perp2^2)' approxDist(v_para2,u_perp2)'
		If e1.speed < 1 Then e1.speed = 1
		If e2.speed < 1 Then e2.speed = 1
		
		'get the new angle for both objects
		e1.movrot = ATan2(u_perp1,v_para1)+ theta
		e2.movrot = ATan2(u_perp2,v_para2)+ theta
		
		'return the difference in speed
		Return approxDist(v_para1-u_para1, v_para2-u_para2)'Sqr((v_para1 - u_para1)^2+(v_para2 - u_para2)^2)
	
	'low-speed collisions
	Else
		'the lower-mass thing bounces
		If e1.mass <= e2.mass Then e1.movrot = theta
		If e2.mass < e1.mass Then e1.movrot = theta + 180
		Return .5
	EndIf

End Function

'shaky and mysterious text to show
Function shakyText(text$)
	'have a short intro sequence
	Local duration# = 2600
	Local introtime# = 0
	text = activateText(text)
	Local textx = SWIDTH + 100
	Local texty = 0
	Local textscale = 3
	Local textcenterx = (SWIDTH/2) - TextWidth(text)*textscale/2
	Local textcentery = (SHEIGHT/2)-TextHeight(text)*textscale/2
	Local textrad = SHEIGHT / 4
	SetColor 255,255,255
	SetScale textscale,textscale
	SetRotation 0
	SetAlpha 1
	oldTime = MilliSecs()
	Repeat
		Cls
		updateTime()
		introtime:+ frameTime
		
		Local texttween# = (introtime Mod (duration/9) / (duration/9))
		
		If introtime < duration*1/9
			'blank screen
		ElseIf introtime < duration*3/9
			'decay text position to center of screen
			textx = textcenterx + Rand(-textrad,textrad) * (1 - texttween)
			texty = textcentery + Rand(-textrad,textrad) * (1 - texttween)
			SetAlpha texttween
		ElseIf introtime < duration*7/9
			'hold text in center of screen
			textx = textcenterx
			texty = textcentery+(introtime/duration)*8
			SetAlpha 1
		ElseIf introtime < duration*8/9
			'shake it out
			textx = textcenterx + Rand(-textrad,textrad) * (texttween)
			texty = textcentery + Rand(-textrad,textrad) * (texttween)
			SetAlpha 1 - texttween
		ElseIf introtime < duration
			'blank screen
			textx = SWIDTH + 100
		EndIf
		
		DrawText text, textx, texty
		
		If KeyHit(KEY_ESCAPE) Or (joyDetected And JoyHit(JOY_MENU)) Then Exit
		
		updateMusic()
		Flip
	Until introtime >= duration
	SetAlpha 1
	SetScale 1,1
EndFunction

'constrains a value between min and max; if it's less or greater than, it'll just cap it
Function constrain#(_var#, _min#, _max#)
	If _var < _min Then Return _min
	If _var > _max Then Return _max
	Return _var
EndFunction

'checks if _var is above/below a value (or equal to it). if it is, returns it; otherwise returns 0
'_sgn : TRUE = "needs to be greater than" | FALSE = "needs to be less than"
Function threshold#(_var#, _cutoff#, _sgn = True)
	Select _sgn
	Case True
		If _var >= _cutoff Then Return _var Else Return 0
	Case False
		If _var <= _cutoff Then Return _var Else Return 0
	EndSelect
EndFunction

'converts 0 and 1 into -1 and 1, respectively. more useful than you might think.
Function binsgn(_bin)
	If _bin = 0 Then Return -1
	If _bin = 1 Then Return 1
	Return 1
EndFunction

'checks if a value is between two numbers (inclusive)
Function isWithin(_var#, _min#, _max#)
	If _var >= _min And _var <= _max Then Return True Else Return False
EndFunction

'see if two ovals are close enough to touch
'x,y is the center of the oval. wid,het are the x,y distances to the edge of the oval from the center at 0,90 degree angles
'returns how much space is still inbetween the ovals, negative if they overlap
Function OvalsCollide(x1,y1,radx1,rady1,rot1,x2,y2,radx2,rady2,rot2)
	Local dx = (x1 - x2)
	Local dy = (y1 - y2)

	'find the angle between the two
	Local theta = ATan2(dy,dx)
	'find the radius of the two ovals at that angle
	Local rad1# = approxDist(radx1*Sin(theta+rot1),rady1*Cos(theta+rot1))
	Local rad2# = approxDist(radx2*Sin(theta+rot2),rady2*Cos(theta+rot2))
	'find the distance between the two
	Local dist# = approxDist(dx,dy)
	
	'If dist - rad1 - rad2 < 0 Then SetColor 255,0,0 Else SetColor 255,255,255
	'SetAlpha .1
	'DrawOval x1-radx1+game.camx,y1-rady1+game.camy,radx1*2,rady1*2
	'DrawOval x2-radx2+game.camx,y2-rady2+game.camy,radx2*2,rady2*2
	
	'is the distance enough to keep them apart? it'll be negative if they overlap
	Return dist - rad1 - rad2
EndFunction

'quick & dirty collision detection
Function RectsCollide(x1,y1,wid1,het1,x2,y2,wid2,het2)
	If x1 + wid1 < x2 Then Return False
	If x2 + wid2 < x1 Then Return False
	If y1 + het1 < y2 Then Return False
	If y2 + het2 < y1 Then Return False
	
	Return True
EndFunction

'the internet is faster than the greeks but wrong about more things
Function approxDist#(dx#,dy#)
	'keep things positive
	If dx < 0 Then dx = -dx
	If dy < 0 Then dy = -dy

	Return (1007.0/1024.0)*Max(dx,dy) + (441.0/1024.0)*Min(dx,dy)
EndFunction

'returns what angle theta is relative to rot, pos = cw from, neg = ccw from
Function convert_to_relative#(_theta#, _rot#)
	If _theta < 180 Then _theta:+ 360
	If _rot < 180 Then _rot:+ 360
	Local dif# = _theta - _rot
	If dif > 180 Then dif:- 360
	If dif < -180 Then dif:+ 360
	Return dif
EndFunction

'returns a string of minutes:seconds
Function time$(_seconds#)
	Local minutes$ = String(Int(Floor(_seconds / 60.0)))
	Local seconds$ = String(Int(_seconds Mod 60))
	
	If Len(seconds) = 1 Then seconds = "0"+seconds
	
	Return minutes + ":" + seconds
EndFunction

'scrambles up a list of objects
Function scrambleList:TList(_list:TList)
	Local listnum = CountList(_list)
	Local newarray:Object[listnum]
	
	For Local o:Object = EachIn _list
		Local newspot = Rand(0,listnum-1)
		Repeat
			If newarray[newspot] = Null
				newarray[newspot] = o
				Exit
			Else
				newspot:+ 1
				If newspot >= listnum Then newspot = 0
			EndIf
		Forever
	Next
	
	Return ListFromArray(newarray)
EndFunction