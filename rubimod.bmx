Strict
AppTitle = "Rubicon"
SeedRnd MilliSecs()
SetMaskColor 255,255,255

Graphics 1024,600
SetBlend(ALPHABLEND)
Global SWIDTH = GraphicsWidth()
Global SHEIGHT = GraphicsHeight()

Global sndVol# = .9			'global sound volume
Global sfxChannel:TChannel = New TChannel
SetChannelVolume sfxChannel,sndVol

Global mouseover_sfx:TSound = LoadSound("sfx/wik_mouseover2.wav")
Global click_sfx:TSound = LoadSound("sfx/wik_mouseclick3.wav")

Local scrollbar_arrows_gfx:TImage = LoadAnimImage("gfx/scrollbar_arrow.png",8,5,0,2)
Global scrollbar_up_gfx:TImage = getFrame:TImage(scrollbar_arrows_gfx, 0)
Global scrollbar_down_gfx:TImage = getFrame:TImage(scrollbar_arrows_gfx, 1)

'deployment graphics
Global grid_gfx:TImage = LoadImage("gfx/grid.png")

'unit icons
Global iconNum = 5'number of icon gfxs
Global deployicons_gfx:TImage = LoadAnimImage("gfx/deploy_icons.png",19,18,0,iconNum)

'terrain icons
Global deployterrain_gfx:TImage = LoadAnimImage("gfx/deploy_terrain.png",20,20,0,5)

Global iconList:TList = New TList
Type Icon
	Field name$
	Field value[4]'icon-specific information
	Field x,y
EndType

Global globalFrame

'the terrain information
Global map[100,100]

'edit modes
Local editBList:TList = New TList
For Local i = 0 To 5
	Local b:Button = New button
	b.wid = 130
	b.het = 30
	b.y = 10
	b.x = 20 + 140*i
	Select i
	Case 0
		b.text = "Borders"
	Case 1
		b.text = "Terrain"
	Case 2
		b.text = "Icons"
	Case 3
		b.text = "Backgrounds"
	Case 4
		b.text = "Save"
	Case 5
		b.text = "Load"
	EndSelect
	editBList.addLast(b)
Next

'edit x border size
Local boardX:Button = New Button
boardX.text = "X Border"
boardX.wid = 100
boardX.het = 30
boardX.x = 20
boardX.y = 60
boardX.toggle = 2
boardX.tab = True

'edit y border size
Local boardY:Button = New Button
boardY.text = "Y Border"
boardY.wid = 100
boardY.het = 30
boardY.x = 20
boardY.y = 100
boardY.toggle = 1
boardY.tab = True

'zoom out
Local zoomout:Button = New Button
zoomout.text = "-"
zoomout.wid = 30
zoomout.het = 30
zoomout.x = SWIDTH - 5 - zoomout.wid
zoomout.y = SHEIGHT - 5 - zoomout.het

'zoom in
Local zoomin:Button = New Button
zoomin.text = "+"
zoomin.wid = 30
zoomin.het = 30
zoomin.x = SWIDTH - 5 - zoomin.wid
zoomin.y = SHEIGHT - 5 - zoomout.het - 5 - zoomin.het

'types of terrain
Local terrainSList:SList = New SList
terrainSList.init(0,60,175,SHEIGHT-60,False,30)
For Local i = 0 To 5
	Local bname$
	Select i
	Case 0
		bname = "Erase"
	Case 1
		bname = "Lightning Nebulae"
	Case 2
		bname = "Fog Nebulae"
	Case 3
		bname = "Asteroids"
	Case 4
		bname = "Anemonae"
	Case 5
		bname = "Exploding Asteroids"
	EndSelect
	Local b:Button = terrainSList.add_button(bname,-10)
	b.toggle = 1
	b.tab = 1
Next

'types of icon
Local iconSList:SList = New SList
Local iconArchtypeList:TList = New TList		'icons to copy
iconSList.init(0,60,175,SHEIGHT-60,False,30)

Global icons = 14

For Local b = 0 To icons-1
	Local i:Icon = New Icon
	Select b
	Case 1
		i.name = "player"
		i.value[2] = 0'player gfx
	Case 2
		i.name = "gate"
		i.value[2] = 4'gate gfx
	Case 3
		i.name = "beacon"
		i.value[2] = 4	'beacon gfx
	Case 4
		i.name = "ship_Flea"
		i.value[0] = 4	'spawn number
		i.value[1] = 2	'faction
		i.value[2] = 2	'mob gfx
		i.value[3] = 0	'game does not track this ship
	Case 5
		i.name = "lamjet_boss"
		i.value[0] = 1	'spawn number
		i.value[1] = 2	'faction
		i.value[2] = 1	'boss gfx
	Case 6
		i.name = "ship_Turret"
		i.value[0] = 3	'spawn number
		i.value[1] = 2	'faction
		i.value[2] = 3	'turret gfx
	Case 7
		i.name = "ship_Scrapper"
		i.value[0] = 3	'spawn number
		i.value[1] = 1	'faction
		i.value[2] = 0
	Case 8
		i.name = "ship_Junker"
		i.value[0] = 2	'spawn number
		i.value[1] = 1	'faction
		i.value[2] = 0
	Case 9
		i.name = "ship_Zukhov Mk II"
		i.value[0] = 2	'spawn number
		i.value[1] = 1	'faction
		i.value[2] = 0
	Case 10
		i.name = "ship_Litus Devil"
		i.value[0] = 1	'spawn number
		i.value[1] = 1	'faction
		i.value[2] = 0
	Case 11
		i.name = "ship_Machinegun Turret"
		i.value[0] = 3	'spawn number
		i.value[1] = 1	'faction
		i.value[2] = 0
	Case 12
		i.name = "ship_Mite"
		i.value[0] = 1
		i.value[1] = 2	'faction
		i.value[2] = 3	'turret gfx
	Case 13
		i.name = "station"
		i.value[0] = 1
		i.value[1] = 1	'faction
		i.value[2] = 0	'player gfx
	EndSelect
	If b <> 0 Then iconArchtypeList.addLast(i)
	Local iname$ = i.name
	If b = 0 Then iname = "Erase"
	Local nb:Button = iconSList.add_button(iname,-10)
	nb.toggle = 1
	nb.tab = 1
Next

'types of background
Local bgSList:SList = New SList
bgSList.init(0,60,175,SHEIGHT-60,False,30)
For Local i = 0 To 2
	Local bname$
	Select i
	Case 0
		bname = "nebulae_paint"
	Case 1
		bname = "greenplanet"
	Case 2
		bname = "rakisplanet"
	EndSelect
	Local b:Button = bgSList.add_button(bname,-10)
	b.toggle = 1
Next

'amount the map is scrolled
Local scrollx# = SWIDTH/2,scrolly# = SHEIGHT/2
Local scrolldistx#,scrolldisty#
'screen xy pos where the player started grabbing to drag
Local grabx# = MouseX(),graby# = MouseY()
'what to place. 0=border | 1=terrain | 2=icon (player, enemy ships, gate)
Local editMode = 0
Local terrainPaint = -1	'if currently painting terrain, this is the index pointing to that. otherwise, is -1
Const TSIZE = 256			'each square in the editor at zoom = .1 is this many pixels ingame
Local zoom# = .1			'how many pixels in the editor stands for ingame
Local wid=512,het=512	'game width and height (from origin)
Repeat
	Cls

	'mouse information
	Local mc = MouseHit(1)
	Local md = MouseDown(1)
	
	Local mc2 = MouseHit(2)
	Local md2 = MouseDown(2)

	'click + drag
	If mc2
		grabx = MouseX()
		graby = MouseY()
	EndIf
	If md2
		scrolldistx = (MouseX()-grabx)
		scrolldisty = (MouseY()-graby)
	EndIf
	
	'accelerate screen towards where we dragged it
	Local sx# = scrolldistx*(22.0/1000.0) 
	Local sy# = scrolldisty*(22.0/1000.0)
	If Not md2
		scrolldistx:- sx
		scrolldisty:- sy
	EndIf
	
	grabx:+ sx
	graby:+ sy
	scrollx:+ sx
	scrolly:+ sy

	'draw the grid
	If zoom = .1
		SetColor 255,255,255
		SetRotation 0
		SetAlpha .15
		TileImage grid_gfx, scrollx, scrolly
	EndIf
	
	'draw the active game area
	SetScale 1,1
	SetColor 100,120,200
	SetAlpha .1
	DrawRect -wid*zoom+scrollx,-het*zoom+scrolly,wid*zoom*2,het*zoom*2

	'a little rectangle at origin
	SetColor 255,255,255
	SetAlpha 1
	DrawRect scrollx-2,scrolly-2,4,4
	
	'find which "tile" the mouse is over
	Local mx = Floor(((MouseX()-scrollx)/zoom)/TSIZE)
	Local my = Floor(((MouseY()-scrolly)/zoom)/TSIZE)
	
	'the map dim coords
	Local mapx = constrain(mx + wid/TSIZE, 0,(wid*2.0/TSIZE)-1)
	Local mapy = constrain(my + het/TSIZE, 0,(het*2.0/TSIZE)-1)
	
	'draw the current tile pos
	SetColor 255,255,255
	SetAlpha 1
	DrawText mx+","+my,SWIDTH-50,10
	DrawText mapx+","+mapy,SWIDTH-50,25
	
	'draw the terrain
	SetColor 255,255,255
	Local scale# = TSIZE*zoom/20.0
	SetScale scale,scale
	For Local y = 0 To (het*2.0/TSIZE)-1
	For Local x = 0 To (wid*2.0/TSIZE)-1
		Local drawx = (x-wid/TSIZE)*TSIZE*zoom  + scrollx
		Local drawy = (y-het/TSIZE)*TSIZE*zoom  + scrolly
		
		Select map[x,y]
		Case 0'nothing
		Case 1'lightning nebulae
			DrawImage deployterrain_gfx,drawx,drawy,1
		Case 2'fog nebulae
			DrawImage deployterrain_gfx,drawx,drawy,0
		Case 3'asteroids
			DrawImage deployterrain_gfx,drawx,drawy,2
		Case 4'anemonae
			DrawImage deployterrain_gfx,drawx,drawy,3
		Case 5'exploding asteroids
			DrawImage deployterrain_gfx,drawx,drawy,4
		EndSelect
	Next
	Next
	
	'draw the icons
	For Local i:Icon = EachIn iconList
		Local drawx = (i.x-wid/TSIZE)*TSIZE*zoom  + scrollx
		Local drawy = (i.y-het/TSIZE)*TSIZE*zoom  + scrolly
		
		SetScale scale,scale
		DrawImage deployicons_gfx,drawx+1,drawy+1,constrain(i.value[2],0,iconNum-1)
		
		'display name, values if mouseover
		SetScale 1,1
		If i.x = mapx And i.y = mapy
			DrawText i.name,drawx,drawy-TSIZE*zoom/2
			For Local v = 0 To 3
				DrawText i.value[v],drawx,drawy+TSIZE*zoom/2+5+10*v
			Next
		EndIf
	Next
	
	'zoom in/out
	SetScale 1,1
	SetColor 255,255,255
	SetAlpha 1
	DrawText Left(zoom,3), zoomin.x, zoomin.y - 15
	
	zoomin.update(md)
	zoomin.draw()
	If zoomin.pressed = 2
		zoom = constrain(zoom*2,.01,.2)
		mc = False
	EndIf
	
	zoomout.update(md)
	zoomout.draw()
	If zoomout.pressed = 2
		zoom = constrain(zoom/2,.01,.2)
		mc = False
	EndIf
	
	'change the edit mode 
	Local i = 0
	For Local b:Button = EachIn editBList
		b.update(md)
		b.draw()
		
		If b.pressed = 2
			editMode = i
			mc = False
		EndIf
		i:+1
	Next
	
	'do things!
	Select editMode
	Case 0'border
		'draw,update buttons for border mode
		boardX.update(md)
		boardX.draw()
		SetColor 255,255,255
		DrawText ": "+wid, boardX.x+boardX.wid+10,boardX.y
		If boardX.toggle = 2 Then boardY.toggle = 1
		
		boardY.update(md)
		boardY.draw()
		DrawText ": "+het, boardY.x+boardY.wid+10,boardY.y
		If boardY.toggle = 2 Then boardX.toggle = 1
		
		'use up the mouseclick if we hit a button
		If boardX.pressed = 2 Then mc = False
		If boardY.pressed = 2 Then mc = False
		
		'figure out where the current width WOULD be
		Local tempwid = Abs(MouseX()-scrollx)
		Local temphet = Abs(MouseY()-scrolly)
		
		'for width
		If boardX.toggle = 2
			'draw it
			SetColor 255,255,255
			For Local i = -1 To 1 Step 2
				DrawLine i*tempwid+scrollx,0,i*tempwid+scrollx,SHEIGHT
			Next
			
			'set the width to here if click
			If mc Then wid = constrain(Int((tempwid/zoom)/TSIZE)*TSIZE, 0, 12800)
		EndIf
		
		'for height
		If boardY.toggle = 2
			'draw it
			SetColor 255,255,255
			For Local i = -1 To 1 Step 2
				DrawLine 0,i*temphet+scrolly,SWIDTH,i*temphet+scrolly
			Next
			
			'set the width to here if click
			If mc Then het = constrain(Int((temphet/zoom)/TSIZE)*TSIZE, 0, 12800)
		EndIf

	Case 1'terrain
		terrainSList.update(md)
		
		'untoggle all buttons except one just pressed
		Local press = False
		For Local b:Button = EachIn terrainSList.entryList
			If b.pressed = 0 Then press = True
		Next
		If press
			For Local b:Button = EachIn terrainSList.entryList
				b.toggle = 1
				If b.pressed = 0 Then b.toggle = 2
			Next
		EndIf
		
		'if we're painting terrain
		If terrainPaint > -1 And MouseX() > terrainSList.wid Then map[mapx,mapy] = terrainPaint
		
		'should we start painting?
		If mc
			'find the currently selected terrain to point
			i = 0
			For Local b:Button = EachIn terrainSList.entryList
				If b.toggle = 2 Then terrainPaint = i
				i:+ 1
			Next
			
		ElseIf Not md'when we release, clear the terrain to paint
			terrainPaint = -1
		EndIf
		
		'draw the current tile pos
		SetColor 170,90,90
		SetAlpha .2
		DrawRect mx*TSIZE*zoom + scrollx, my*TSIZE*zoom + scrolly, TSIZE*zoom,TSIZE*zoom
	
	Case 2'icons
		iconSList.update(md)
		
		'untoggle all buttons except one just pressed
		Local press = False
		For Local b:Button = EachIn iconSList.entryList
			If b.pressed = 0 Then press = True
		Next
		If press
			For Local b:Button = EachIn iconSList.entryList
				b.toggle = 1
				If b.pressed = 0 Then b.toggle = 2
			Next
		EndIf
		
		'if we've clicked to place a tile
		If mc And MouseX() > terrainSList.wid
			Local selicon:Icon
			Local selicon_name$
			'find the selected button, icon
			For Local b:Button = EachIn iconSList.entryList
				If b.toggle = 2 Then selicon_name = b.text
			Next
			For Local i:Icon = EachIn iconArchtypeList
				If i.name = selicon_name Then selicon = i
			Next
			
			'delete any old icons at this location (this is how erase works as well as well)
			For Local i:Icon = EachIn iconList
				If i.x = mapx And i.y = mapy Then ListRemove(iconList,i)
			Next
			
			'make the new icon here
			If selicon <> Null
				Local i:Icon = New Icon
				i.name = selicon.name
				i.value[0] = selicon.value[0]
				i.value[1] = selicon.value[1]
				i.value[2] = selicon.value[2]
				i.value[3] = selicon.value[3]
				i.x = mapx
				i.y = mapy
				iconList.addLast(i)
			EndIf
		EndIf
		
		'edit icon values
		For Local i:Icon = EachIn iconList
			If mapx = i.x And mapy = i.y
				If KeyHit(KEY_Q) Then i.value[0]:+ 1
				If KeyHit(KEY_A) Then i.value[0]:- 1
				If KeyHit(KEY_W) Then i.value[1]:+ 1
				If KeyHit(KEY_S) Then i.value[1]:- 1
				If KeyHit(KEY_E) Then i.value[2]:+ 1
				If KeyHit(KEY_D) Then i.value[2]:- 1
				If KeyHit(KEY_R) Then i.value[3]:+ 1
				If KeyHit(KEY_F) Then i.value[3]:- 1
			EndIf
		Next
		
		'draw the instructions for editing value
		SetColor 255,255,255
		SetAlpha 1
		DrawText "Q/A W/S E/D R/F | edit icon values",iconSList.wid+10,SHEIGHT-15
	
		'draw the current tile pos
		SetColor 170,90,90
		SetAlpha .2
		DrawRect mx*TSIZE*zoom + scrollx, my*TSIZE*zoom + scrolly, TSIZE*zoom,TSIZE*zoom
	
	Case 3'backgrounds
		bgSList.update(md)
		
	Case 4'save
		Local mapName$ = Lower(RequestFile$("What do you wish to save this map as?","map",True,"mission/"))
		If mapName <> ""
			Print "Saving map:'"+mapName+"'"
			'delete the old file
			DeleteFile(mapName)
			'make the new file
			CreateFile(mapName)
			'write to the new file
			Local mFile:TStream = WriteFile(mapName)
			
			'write the current dimensions
			WriteString(mfile,"x")		'the upcoming data is width
			WriteFloat(mfile, wid)
			WriteString(mfile,"y")		'the upcoming data is height
			WriteFloat(mfile, het)
			
			'write the terrain
			For Local y = 0 To 99
			For Local x = 0 To 99
				If map[x,y] > 0
					WriteString(mfile,"t")		'the upcoming data is terrain
					WriteFloat(mfile, x*TSIZE)
					WriteFloat(mfile, y*TSIZE)
					WriteByte(mfile, map[x,y])
				EndIf
			Next
			Next
			
			'write the icons
			For Local i:Icon = EachIn iconList
				WriteString(mfile,"i")			'the upcoming data is an icon
				WriteByte(mfile,		Len(i.name))
				WriteString(mfile,	i.name)
				WriteByte(mfile,		i.value[0])
				WriteByte(mfile,		i.value[1])
				WriteByte(mfile,		i.value[2])
				WriteByte(mfile,		i.value[3])
				WriteFloat(mfile,		i.x*TSIZE)
				WriteFloat(mfile,		i.y*TSIZE)
			Next
			
			'write the backgrounds
			For Local b:Button = EachIn bgSList.entryList
				If b.toggle = 2
					WriteString(mfile,"b")		'the upcoming data is a backdrop
					WriteByte(mfile,  Len(b.text))
					WriteString(mfile,	b.text)
				EndIf
			Next
			
			CloseFile mFile
		EndIf
		editMode = 0
	Case 5'load
		Local mapName$ = Lower(RequestFile$("Please select a map","map",False,"mission/"))
		If mapName <> ""
			Print "Loading map:'"+mapName+"'"
			'clear the current map stuffs
			wid = 0
			het = 0
			For Local y = 0 To 99
			For Local x = 0 To 99
				map[x,y] = -1
			Next
			Next
			ClearList(iconList)
			For Local b:Button = EachIn bgSList.entryList
				b.toggle = 1
			Next
		
			'open the map
			Local mFile:TStream = ReadFile(mapName)
			
			'load each data point
			Repeat
				'get the next datum type
				Local dat$ = ReadString(mFile,1)
				Select dat
				Case "x"'map width
					wid = ReadFloat(mfile)
				Case "y"'map height
					het = ReadFloat(mfile)
				Case "t"'terrain
					map[ReadFloat(mfile)/TSIZE,ReadFloat(mfile)/TSIZE] = ReadByte(mfile)
				Case "i"'icon
					Local i:Icon = New Icon
					Local namelen = ReadByte(mFile)
					i.name = ReadString(mfile, namelen)
					i.value[0] = ReadByte(mfile)
					i.value[1] = ReadByte(mfile)
					i.value[2] = ReadByte(mfile)
					i.value[3] = ReadByte(mfile)
					i.x = ReadFloat(mfile)/TSIZE
					i.y = ReadFloat(mfile)/TSIZE
					iconList.addLast(i)
				Case "b"'backdrop
					Local namelen = ReadByte(mFile)
					Local bgname$ = ReadString(mfile, namelen)
					
					'find that button, toggle it
					For Local b:Button = EachIn bgSList.entryList
						If b.text = bgname Then b.toggle = 2
					Next
				EndSelect
			
			Until Eof(mfile)
		EndIf
		editMode = 0
	EndSelect
	
	Flip

Until KeyHit(KEY_ESCAPE)

End

'constrains a value between min and max; if it's less or greater than, it'll just cap it
Function constrain#(_var#, _min#, _max#)
	If _var < _min Then Return _min
	If _var > _max Then Return _max
	Return _var
EndFunction

'---MODIFIED FROM MAIN FILE TO WORK HERE---
'play a sound with relative volume, etc to player (can use a prexisitng channel)
Global sfxVol# = 1
Function playSFX:TChannel(_sound:TSound,_x#,_y#, _ampVol# = 1.0, _channel:TChannel = Null)
	If _sound <> Null Or _channel <> Null
		'cue up the sound in question - OR - just alter the prexisting channel
		Local tempChannel:TChannel
		If _channel = Null Then tempChannel = CueSound(_sound) Else tempChannel = _channel
		
		'make the sound channel the correct volume, pan, depth
		Local soundVol# = _ampVol
		If soundVol < 0 Then soundVol = 0
		If soundVol > 1 Then soundVol = 1
		Local sfxAngle# = 0
		SetChannelPan tempChannel,Cos(sfxAngle)*(1-_ampVol)'the closer, the less pronounced the effect is.
		SetChannelDepth tempChannel,Sin(sfxAngle)*(1-_ampVol)
		SetChannelVolume tempChannel,soundVol*sfxVol*sndVol'dist time global vol
		
		'play the sound 
		If Not ChannelPlaying(tempChannel) Then ResumeChannel(tempChannel)
		Return tempChannel
	EndIf
EndFunction

Include "buttoncontrol.bmx"

Include "graphicsmagic.bmx"