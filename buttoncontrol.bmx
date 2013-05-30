
Type Button
	Field x,y,wid,het
	Field text$,text_x,text_y	'text and the amount to offset it from center
	Field text_centered = True	'whether to center the text (false is left justified)
	Field text_scale# = 1		'how big to draw the text
	Field text_RGB[3]			'color of the text
	Field gfx:TImage,gfx_x,gfx_y	'a graphic and the amount to offset it from topleft
	Field pressed = 5		'the state of being pressed:	'| 5 = nothing | 4 = hover, can't press | 3 = hover, can press 
											'| 2 = JUST pressed | 1 = pressing | 0 = JUST released
	Field active = True		'if inactive, can't press it
	Field toggle			'0 = not a toggle button | 1 = a toggle button | 2 = currently toggled
	Field tab = False			'for TOGGLE buttons, if this is true, then you can't untoggle it by clicking it again.
	Field textBox = False		'TRUE/FALSE, whether this is an input-text button, uses the toggle above to track if it's active or not
	Field skipdraw = False		'TRUE/FALSE, whether to draw the button part of the button
	Field skipborder = False 	'TRUE/FALSE, whether to skip drawing the border of the button
	Field skipbar = False		'TRUE/FALSE, whether to skip drawing that lil bar on the left side
	Field RGB[3]			'the RGB values of the unpressed button
	
	Field child:Button		'because fuck it; a delete button for each configuration option

	Field allow_underscores = True	'if it's a textbox, does it permit underscores?

	'update the state of this button based on the state and position of the mouse
	'_click : TRUE/FALSE, whether mouse is being pressed right now
	'can override the position of the button, used for children buttons
	Method update(_click, override_x = 0,override_y = 0)
		Local nx = x, ny = y
		If override_x <> 0 Then nx = override_x
		If override_y <> 0 Then ny = override_y
		
		If active
			Local mx = cursorx
			Local my = cursory
			
			'v-- FUCK YEAH LOGIC & FLOWCHARTS FTW --v
			'is the mouse over this button?
			If mx > nx And mx < nx+wid And my > ny And my < ny+het
				'mouse down?
				If _click
					'do we have the possibility of pressing the button?
					If pressed <= 3
						'was the button already held down?
						If pressed = 2
							pressed = 1'just hold the button down
						ElseIf pressed <> 1
							pressed = 2'we JUST hit the button
							If toggle = 1'toggle this button to ON
								toggle = 2
								If textBox Then FlushKeys()'lose keypresses before we started typing
							ElseIf toggle = 2 And Not tab'toggle this button to OFF
								toggle = 1
							EndIf
						EndIf
					Else
						pressed = 4'hover, without the possibility of pressing button
					EndIf
				Else
					'the button WAS held down?
					If pressed = 2 Or pressed = 1
						pressed = 0'button was just released
						playSFX(click_sfx,-1,-1)
					Else
						If pressed >= 4 Then playSFX(mouseover_sfx,-1,-1)'did we JUST go mouseover?
						pressed = 3'hover, with the possibility of pressing button
					EndIf
				EndIf
			Else
				pressed = 5'nothing
				If _click And textBox Then toggle = 1'inactivate the text box if we click somewhere else
			EndIf
			
						
			'if the button is selected and it's a text input button, let the user input text
			If toggle = 2 And textBox
				Local keypress = GetChar()
				'ENTER
				If keypress = 13
					'deselect the box
					toggle = 1
				'BACKSPACE, DELETE
				ElseIf keypress = 8 Or keypress = 4
					If Len(text) > 0 Then text$ = Left(text, Len(text)-1)	
				ElseIf Len(text) < 16
					If cleankey(keypress, allow_underscores) Then text:+ Chr(keypress)'adds the key press if it's a "clean" character
				EndIf
			EndIf
		EndIf
		
		'update child button
		If child <> Null Then child.update(_click,nx+child.x,ny+child.y)
	EndMethod

	Method draw(override_x = 0,override_y = 0)'can override the position of the button, used for children buttons
		SetScale 1,1
		SetAlpha 1
		SetRotation 0
		
		Local nx = x, ny = y
		If override_x <> 0 Then nx = override_x
		If override_y <> 0 Then ny = override_y
		
		'should we draw the button itself?
		If Not skipdraw
			If Not skipborder
				'draw the border
				SetColor 32,32,32
				DrawRect nx,ny,wid,het
				If toggle = 2 Or pressed <= 2 Or Not active Then SetColor 64,64,64 Else SetColor 128,128,128
				DrawRect nx+2,ny+2,wid-4,het-4
				SetColor 32,32,32
				DrawRect nx+4,ny+4,wid-8,het-8
				
			'(if skipborder, with a TIIINY border)
			Else
				SetColor 128,128,128
				DrawRect nx,ny,wid,het
			EndIf
		
			'set the main color to a default one if unset (black = unset)
			If RGB[0] = 0 And RGB[1] = 0 And RGB[2] = 0
				RGB[0] = 60
				RGB[1] = 60 
				RGB[2] = 130
			EndIf
			
			'set the text color to light grey if unset
			If text_RGB[0] = 0 And text_RGB[1] = 0 And text_RGB[2] = 0
				text_RGB[0] = 192
				text_RGB[1] = 192
				text_RGB[2] = 192
			EndIf
		
			'modify that main color based on the current state
			Select pressed
			Case 4,3'hover
				SetColor RGB[0]+20,RGB[1]+20,RGB[2]+20
			Case 2,1'being pressed
				SetColor RGB[0]-20,RGB[1]-20,RGB[2]-20
			Default
				SetColor RGB[0],RGB[1],RGB[2]
			EndSelect
			
			'if it's a toggled box, it's dark
			If toggle = 2 Then SetColor RGB[0]-20,RGB[1]-20,RGB[2]-20
			
			'if it's a selected textbox, it's bright
			If textBox And toggle = 2 Then SetColor RGB[0]+20,RGB[1]+20,RGB[2]+20
			
			'if it's not active, then it's grey
			If Not active Then SetColor 32,32,32
			
			'draw the main color (offset by any borders)	
			If Not skipborder
				DrawRect nx+6,ny+6,wid-12,het-12
			Else
				DrawRect nx+1,ny+1,wid-2,het-2
			EndIf
			
			'draw a lil line
			If active And Not skipbar
				SetColor 13,11,27
				If wid > 10 And het > 10 And Not skipborder Then DrawRect nx+8,ny+8,2,het-16
			EndIf
				
		EndIf
				
		'graphic
		SetColor 255,255,255
		If gfx <> Null Then DrawImage gfx, nx+gfx_x, ny+gfx_y
		
		'get a little underscore if we're currently modifying this textbox
		Local dtext$ = text
		If textBox And toggle = 2
			'If dtext = "" Then dtext = "[enter text]"
			If globalFrame Then dtext:+ "_"
		EndIf
		
		Local text_drawx = nx+text_x+(wid-(TextWidth(text)*text_scale))/2
		Local text_drawy = 1+ny+text_y+het/2-(TextHeight(text)*text_scale)/2
		
		SetScale text_scale, text_scale
		
		'non-centered text position
		If Not text_centered Then text_drawx = nx + text_x + 12
		
		'modify text color based on the current state
		Select pressed
		Case 4,3'hover
			SetColor text_RGB[0]+40,text_RGB[1]+40,text_RGB[2]+40
		Case 2,1'being pressed
			SetColor text_RGB[0]-60,text_RGB[1]-60,text_RGB[2]-60
		Default'just sitting there
			SetColor text_RGB[0],text_RGB[1],text_RGB[2]
		EndSelect
		
		'inactive buttons are greyed out
		If Not active Then SetColor 64,64,64
		
		'text
		draw_text(dtext, text_drawx, text_drawy)
		
		'draw child button
		If child <> Null Then child.draw(nx+child.x,ny+child.y)
		
		SetScale 1,1
	EndMethod
EndType


'scrolling list
Type SList
	Field x,y,wid,het
	Field graby			'the y offset from center we're grabbing the bar
	Field barside		'TRUE = right | FALSE = left
	Field barwid		'width of the scrollbar
	Field entryList:TList	'the list of buttons in this scrolling list
	Field entryHet		'the height of each entry
	Field up:Button
	Field down:Button
	Field scroll		'the number of pixels currently scrolled
	Field skipscrollbar = False	'should we even bother with a scroll bar?
	Field ascend = False	'FALSE = buttons go from top to bottom | TRUE = buttons go from bottom to top
	
	'either initialize the list or update all of its buttons
	Method init(_x,_y,_wid,_het,_barside,_entryHet = 70,_entryList:TList = Null,_barwid = 12)
		x = _x
		y = _y
		wid = _wid
		het = _het
		barside = _barside
		barwid = _barwid
		entryHet = _entryHet
		If _entryList <> Null Then entryList = _entryList
		If entryList = Null Then entryList = New TList

		'make the scrollbar buttons
		If up = Null Then up = New Button
		up.wid = barwid
		up.het = barwid
		up.x = x + barside*(wid - up.wid)
		up.y = y
		up.skipborder = True
		up.RGB[0] = 192
		up.RGB[1] = 192
		up.RGB[2] = 192
		up.gfx = scrollbar_up_gfx
		'up.gfx_x = wid/2
		'up.gfx_y = het/2
		
		If down = Null Then down = New Button
		down.wid = barwid
		down.het = barwid
		down.x = x + barside*(wid - down.wid)
		down.y = y + het - down.wid
		down.skipborder = True
		down.RGB[0] = 192
		down.RGB[1] = 192
		down.RGB[2] = 192
		down.gfx = scrollbar_down_gfx
		'down.gfx_x = barwid/2
		'down.gfx_y = barwid/2
	End Method
	
	'updates & draws the buttons contained therin
	Method update(_click)
	If CountList(entryList) > 0
		
		If Not skipscrollbar
			'draw a scrollbar backgound
			'SetColor 13,11,27
			'DrawRect x + barside*(wid - barwid), y + barwid, barwid, het - barwid*2
			'draw the scrollbar
			SetColor 128,128,128
			Local space# = Float(het) / (Float(CountList(entryList))*Float(entryHet)) ' what % of the list we can display
			Local sy# = Float(het)*Float(het + scroll) / (Float(CountList(entryList))*Float(entryHet)) ' how far down we've scrolled
			Local shet# = constrain((het - barwid*2) * space,16,het-barwid*2+16)'the height of the "current location" bar
			If CountList(entryList)*entryHet <= het'if there is no call for a scrollbar
				shet = het-barwid*2
				sy = shet
			EndIf
			DrawRect x + barside*(wid - barwid), y + barwid + shet - sy, barwid, shet
			SetColor 192,192,192
			DrawRect x + barside*(wid - barwid) + 1, y + barwid + shet - sy + 1, barwid - 2, shet - 2
		
			'update the scroll buttons
			up.update(_click)
			up.draw()
			down.update(_click)
			down.draw()
		
			'check to see if either button has been pressed
			If up.pressed = 0 Then scroll = scroll + entryHet'single click
			If down.pressed = 0 Then scroll = scroll - entryHet'single click
			
			'manually check to see if they've clicked the scrollbar
			If _click
				If (cursorx>x+barside*(wid-barwid) And cursorx<x+barside*(wid)+barwid And cursory>y+barwid And cursory<y+barwid+het-barwid*2) Or graby <> 0
					'did we just click?
					If graby = 0 Then graby = -cursory+shet+y+barwid
					'move the bar according to the mouse's position
					scroll = (cursory-(y+barwid)-(shet/2) + graby) / -space
				EndIf
				
			Else' we let go, lose any offset
				graby = 0
			EndIf
			
			'scroll the scrollbar with the scrollwheel
			scroll:+ MouseZSpeed()*entryhet
			
			'scroll the scrollbar with the movement axis stick
			If JOY_MOVEAXIS = JOY_LEFTSTICK And Abs(JoyY()) > .1 Then scroll:+ (JoyY()*JOY_AMPLIFY)
			If JOY_MOVEAXIS = JOY_RIGHTSTICK And Abs(JoyZ()) > .1 Then scroll:+ (JoyZ()*JOY_AMPLIFY)
			
			'keep the scrollbar within constraints
			scroll = constrain(scroll,-entryHet*(CountList(entryList))+het,0)
				
			'lock the scrollbar if there aren't enough entries
			If CountList(entryList)*entryHet < het Then scroll= 0
		EndIf
		
		'is the mouse over this list?
		Local mouseover = False
		If (cursorx > x And cursorx < x+wid And cursory > y And cursory < y + het) Then mouseover = True
		
		'update the entry buttons, put them in the correct locations based on scrolling
		SetViewport 0,y,SWIDTH,het'x + (barwid-barside*(barwid)),y,wid,het
		Local draw_y = y + scroll + (het*ascend)
		For Local b:Button = EachIn entryList
			'set where the button should be drawn
			b.x = x + (barwid-barside*(barwid))
			b.y = draw_y - (b.het*ascend)
			
			'update (if they're within bounds) & draw em
			b.update(_click)
			b.draw()
			
			'BUT! they can't be pressed if we're not over the list
			If Not mouseover Then b.pressed = Max(3,b.pressed)
			
			'move down (or up!) where the next button should be
			draw_y:+ b.het * (1 - 2*ascend)
		Next
		SetViewport 0,0,SWIDTH,SHEIGHT
	EndIf
	EndMethod
	
	'adds a button to this SList & returns it						(_listPos : the position in the SList to add the button, 0 = First)
	Method add_button:Button(_text$,_text_x=0,_text_y=0,_gfx:TImage=Null,_gfx_x=0,_gfx_y=0, _listPos = -1)
		Local mb:Button = New Button
		mb.text = _text
		mb.text_x = _text_x + barwid - barside*(barwid)
		mb.text_y = _text_y
		mb.gfx = _gfx
		mb.gfx_x = _gfx_x + barwid - barside*(barwid)
		mb.gfx_y = _gfx_y
		
		mb.wid = wid - barwid
		mb.het = entryHet
		
		'if we're inserting the button somewhere
		If _listPos > -1 And Not ListIsEmpty(entryList)	'put it at the specified spot
			Local entryArray:Object[] = ListToArray(entryList)
			Local buttonLink:TLink = ListFindLink(entryList, entryArray[_listPos])'find the button link of the place we're cutting into
			entryList.InsertBeforeLink(mb, buttonLink)
			
		Else									'put it at the end
			entryList.addLast(mb)
		EndIf

		Return mb
	EndMethod
EndType

'draws text with a 1-px shadow
Function draw_text(_text$,_x,_y)
	Local RGB[3]
	GetColor RGB[0],RGB[1],RGB[2]
	
	'draw the shadow
	SetColor 13,11,27
	DrawText _text,_x+1,_y+1
	
	'draw the text
	SetColor RGB[0],RGB[1],RGB[2]
	DrawText _text,_x,_y
EndFunction


'returns TRUE if the _code corresponds to a clean text character
Function cleankey(_code,_allowUnderscore = True)
	'If _code > 0 Then Print "code:"+ _code + "   chr:"+Chr(_code)
	If _code >= 32 And _code <= 122'most OK characters plus some others
		'exclude those others
		Select _code
		Case 96,33,64,35,36,37,94,38,42,40,41,45,61,43,91,93,92,59,58,39,34,44,60,46,62,47,63'doesn't exclude underscore
			Return False
		Case 95'underscore
			If Not _allowUnderscore Then Return False
		Default
			Return True
		EndSelect
	Else
		Return False
	EndIf
EndFunction
