'makes an icon, gives it values, and adds it to a list, AND ADDS SHIPS FOR IT
Function add_icon:Icon(_name$,_x,_y,_value[],_visible = True)
	
	'default & input values
	Local i:Icon = New Icon
	i.name = _name
	i.x = _x
	i.y = _y
	i.visible = _visible
	'				SPAWNED SHIPS			GATES, BEACONS				STATION
	i.value[0] = _value[0]'# of to spawn		| point index to assign		|
	i.value[1] = _value[1]'faction			|						|faction
	i.value[2] = _value[2]'icon gfx index		| icon gfx index 				|icon gfx index
	i.value[3] = _value[3]'game index to add to	| rotation [x * 15]			|game index to add to
					'^- if negative, tracks this individual ship
					' - if positive, adds to tracking list of ships
					' either case, is [abs(x) - 1] index of this, MAX 9 THEN
	
	'ADD SHIPS
	If Left(i.name,5) = "ship_"
		Local squad:Squadron = Null
		For Local p = 1 To i.value[0]
			Local s:Ship = new_ship(Right(i.name,Len(i.name)-5),0,0,"Default",squad)	'position will be set at the end of deployment
			'the game is watching...
			If i.value[3] < 0 Then game.ships[i.value[3]-1] = s
			If i.value[3] > 0 Then game.shipList[i.value[3]-1].addLast(s)
			
			'the first ship sets the squad
			If p = 1 Then squad = s.squad
		Next
		'inherit the squad from the first ship
		If squad <> Null
			i.squad = squad
			i.squad.x = _x
			i.squad.y = _y
			i.squad.goal_x = _x
			i.squad.goal_y = _y
			i.squad.faction = _value[1]
			i.squad.setPos = True
		EndIf
	Else
		'SPECIAL ICONS
		Select i.name
		Case "player"'the player's deploy location
			i.squad = pilot.psquad'this icon uses the pilot squad
			pilot.psquad.x = _x
			pilot.psquad.y = _y
			pilot.psquad.goal_x = _x
			pilot.psquad.goal_y = _y
			pilot.psquad.setPos = True
		Case "lamjet_boss"
			Local s:Ship = new_ship("Lamjet",0,0,"default",Null)
			s.RGB[0] = 255
			s.RGB[1] = 120
			s.RGB[2] = 120
			
			'inherit the squad from the ship
			i.squad = s.squad
			i.squad.x = _x
			i.squad.y = _y
			i.squad.setPos = True
			
			'the game is watching...
			If i.value[3] < 0 Then game.ships[i.value[3]-1] = s
			If i.value[3] > 0 Then game.shipList[i.value[3]-1].addLast(s)
		Case "gate"'a stationary gate
			'game.point[i.value[0]] = add_gate(_x,_y,_value[3]*15)
		Case "beacon"'a stationary beacon
			game.point[i.value[0]] = add_beacon:Item(_x,_y)
		'Case "station"'a stationary station
		'	Local station:Ship = add_station(_x,_y,_value[1])
		'	'the game is watching...
		'	If i.value[3] < 0 Then game.ships[i.value[3]-1] = station
		'	If i.value[3] > 0 Then game.shipList[i.value[3]-1].addLast(station)
		EndSelect
	EndIf
	
	game.iconList.addLast(i)
	Return i
EndFunction
