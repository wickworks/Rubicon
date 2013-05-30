'-- TESTDRIVE METAGAME --
'drive around an asteroid field

width = 1600
height = 1600
setup_cbox()'needs to go after width, height set

new_music = mission2_music

'just to make sure
If p1.link <> Null Then RemoveLink(p1.link)
p1.link = Null
ListRemove(entityList, p1)

'we set p1 to be the ship we want
p1.link = entityList.addLast(p1)
p1.behavior = "player"
p1.squad = pilot.psquad

'add asteroids
Local cometSquad:Squadron = add_asteroids(100,0,0,width)
cometSquad.goal_x = 0
cometSquad.goal_y = 0
		
For Local s:Ship = EachIn entityList
	If s <> p1
		s.x = Rand(-width,width)
		s.y = Rand(-height,height)
	EndIf
Next

'Select Lower(pilot.currentSystem.name)
'Case "rakis"
'	add_backdrop("rakisplanet")
'EndSelect

game.play()

