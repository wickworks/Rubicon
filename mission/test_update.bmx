'-- TESTDRIVE UPDATE --
'drive around an asteroid field

'------------------------------UPDATE-----------------------------------------

'soft springy borders
borders()

'if player dies, respawn
If p1.armour <= 0
	'start a respawn timer
	value[3]:+ frameTime
	If value[3] > 3000
		new_message("Your ship has died. Try to be more careful with the new one, yeah?")
		p1.reset()
		p1.link = entityList.addLast(p1)
		value[3] = 0
	EndIf
EndIf
