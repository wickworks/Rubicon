'loads a possibly-animated image and returns it as an array
Function load_image:TImage[](_url$,_wid=0,_het=0,_framenum=1,_midhandle = True)
	Local gfx:TImage[Max(_framenum,2)]
	If _framenum > 1
		For Local frame = 0 To (_framenum-1)
			gfx[frame] = LoadAnimImage(_url, _wid, _het, frame, 1)'load a single frame from the image
			'do we ACTUALLY midhandle the image in a way that isn't terrible?
			If _midhandle Then midHandle(gfx[frame])
		Next
	Else
		gfx[0] = LoadImage(_url)'load the single image
	EndIf
	If _framenum = 1 Then gfx[1] = gfx[0]'fill the array out if necessary
	Return gfx
EndFunction

'does a BETTER midHandleImage, one that doesn't friggin' make things blurry
Function midHandle(_gfx:TImage)
	SetImageHandle _gfx,ImageWidth(_gfx)/2,ImageHeight(_gfx)/2
EndFunction

'returns a specific frame from an animated image (will mess up your current drawing buffer, so, you know, be careful)
Function getFrame:TImage(source_gfx:TImage, _frame)
	Local gfx:TImage = source_gfx
	Local wid = ImageWidth(gfx)
	Local het = ImageHeight(gfx)
	
	'old drawing settings, to restore later
	Local hand_x#,hand_y#,rot#,scale_x#,scale_y#,mask_r,mask_g,mask_b
	GetMaskColor(mask_r,mask_g,mask_b)
	GetHandle(hand_x,hand_y)
	rot = GetRotation()
	
	'set new drawing settings
	SetMaskColor 0,0,0
	SetImageHandle(gfx,0,0)
	SetRotation 0
	SetScale 1,1
	
	SetViewport 0,0,wid,het
	Cls
	DrawImage gfx,0,0,_frame
	Local frame_image:TImage = CreateImage(wid,het)
	GrabImage frame_image,0,0
	Cls
	SetViewport 0,0,GraphicsWidth(),GraphicsHeight()
	
	'restore the old image handle
	SetMaskColor(mask_r,mask_g,mask_b)
	SetImageHandle(gfx,hand_x,hand_y)
	SetRotation rot
	SetScale scale_x#,scale_y#
	
	midHandle(frame_image)
	Return frame_image
EndFunction

'feed it an image array and it'll spit a bigger one back out
Function resizeAnimImage:TImage[](_image:TImage[], _scale:Int, _framenum = 1)
	Local gfx:TImage[_framenum]
	For Local frame = 0 To _framenum-1
		If _image[frame] <> Null Then gfx[frame] = resizeImage(_image[frame],_scale)
	Next
	Return gfx
EndFunction

'resizes an image w/o making it blurry? (SCALE is integer; how many times bigger the new image will be)
Function resizeImage:TImage(_image:TImage,_scale:Int)
	SetColor 255,255,255
	Local wid = ImageWidth(_image)*_scale
	Local het = ImageHeight(_image)*_scale

	Local output:TImage = CreateImage(wid,het)
	
	Local pixmap:TPixmap = LockImage(_image)
	Local resized:TPixmap = LockImage(output)

	'go through the original image
	For Local x = 0 To ImageWidth(_image) - 1
		For Local y = 0 To ImageHeight(_image) - 1
			
			'and get each pixel
			Local p = ReadPixel(pixmap, x, y)
			
			'for each pixel, draw the appropriate scaled amount for the resize image (basically a rectangle)
			For Local px = 0 To _scale-1
				For Local py = 0 To _scale-1
					WritePixel(resized, x*_scale+px, y*_scale+py, p)
				Next
			Next
		Next			
	Next
	
	'make black the transparent color
	MaskPixmap(resized,0,0,0)

	'free up some stuff
	UnlockImage(_image)
	UnlockImage(output)

	resized= Null	
	pixmap= Null
	
	midHandle(output)
	midHandle(_image)
	Return output
End Function

'turns the provided image into a pure-white version of itself
Function getHitImage:TImage(source_gfx:TImage, _white = True)'if white = false, then returned pixels are BLACK!
	'we're only going to work with the first frame, an unanimated image
	Local gfx:TImage = getFrame(source_gfx, 0)
	
	Local wid = ImageWidth(gfx)
	Local het = ImageHeight(gfx)

	Local hitgfx:TImage = CreateImage(wid,het)
	
	Local pixmap:TPixmap = LockImage(gfx)
	Local hitmap:TPixmap = LockImage(hitgfx)

	'go through the original image
	For Local x = 0 To wid - 1
		For Local y = 0 To het - 1
			
			'and get each pixel					-> thank you internet person! (impixi at blitzmax forums)
			Local p = ReadPixel(pixmap, x, y)
			Local a:Byte = p Shr 24
			Local r:Byte = p Shr 16
			Local g:Byte = p Shr 8
			Local b:Byte = p
		
			' ***		
			' ***	
			' *** Process pixels HERE
			If _white
				r = 255
				g = 255
				b = 255
			Else
				r = 16
				g = 16
				b = 16
			EndIf
			'a = Rand(96, 255)
			' ***
			' ***
			' ***
			
			'write a white pixel w/ the same transparency value
			WritePixel(hitmap, x, y, Int(a Shl 24 | r Shl 16 | g Shl 8 | b))
		Next			
	Next

	'free up some stuff
	UnlockImage(gfx)
	UnlockImage(hitgfx)

	gfx = Null
	hitmap= Null	
	pixmap= Null
	
	midHandle(hitgfx)
	midHandle(source_gfx)

	Return hitgfx
EndFunction

'feed it an image array and it'll spit a bigger one back out
Function recolorAnimImage:TImage[](_image:TImage[], scheme, _framenum = 1)
	Local gfx:TImage[Max(2,_framenum)]
	For Local frame = 0 To _framenum-1
		If _image[frame] <> Null Then gfx[frame] = recolorImage(_image[frame], scheme)
	Next
	'if we need to fill both frames
	If _framenum = 1 Then gfx[1] = gfx[0]
	Return gfx
EndFunction

'replaces shades of grey with the specified color scheme
'recolor[ shade: 0=light | 1=med | 2=dark | 3=highlight, rgb recolor: 0=red | 1=green | 2=blue ]
Function recolorImage:TImage(source_gfx:TImage, scheme)
	
	'set the colors-to-be-replaced, same format as input recolor[]
	Local source_color[4,3]
	For Local shade = 0 To 3
		Select shade
		Case 0'light
			source_color[shade,0] = 192
			source_color[shade,1] = 192
			source_color[shade,2] = 192
		Case 1'mid
			source_color[shade,0] = 128
			source_color[shade,1] = 128
			source_color[shade,2] = 128
		Case 2'dark
			source_color[shade,0] = 64
			source_color[shade,1] = 64
			source_color[shade,2] = 64
		Case 3'highlight
			source_color[shade,0] = 255
			source_color[shade,1] = 138
			source_color[shade,2] = 1
		EndSelect
	Next
	
	SetColor 255,255,255
	SetAlpha 1
	
	'we're only going to work with the first frame, an unanimated image
	Local gfx:TImage = getFrame(source_gfx, 0)
	
	Local wid = ImageWidth(gfx)
	Local het = ImageHeight(gfx)

	Local colorgfx:TImage = CreateImage(wid,het)
	
	Local pixmap:TPixmap = LockImage(gfx)
	Local colormap:TPixmap = LockImage(colorgfx)

	'go through the original image
	For Local x = 0 To wid - 1
		For Local y = 0 To het - 1
			
			'and get each pixel					-> thank you internet person! (impixi at blitzmax forums)
			Local p = ReadPixel(pixmap, x, y)
			Local a:Byte = p Shr 24
			Local r:Byte = p Shr 16
			Local g:Byte = p Shr 8
			Local b:Byte = p
		
			' ***		
			' ***	
			' *** Process pixels HERE
			If a = 255
				For Local shade = 0 To 3
					If r = source_color[shade,0] And g = source_color[shade,1] And b = source_color[shade,2]
						r = colorScheme(scheme,shade)[0]
						g = colorScheme(scheme,shade)[1]
						b = colorScheme(scheme,shade)[2]
					EndIf
				Next
			EndIf
			' ***
			' ***
			' ***
			
			'write a recolord pixel w/ the same transparency value
			WritePixel(colormap, x, y, Int(a Shl 24 | r Shl 16 | g Shl 8 | b))
		Next			
	Next

	'free up some stuff
	UnlockImage(gfx)
	UnlockImage(colorgfx)

	gfx = Null
	colormap= Null	
	pixmap= Null
	
	midHandle(colorgfx)
	midHandle(source_gfx)
	
	Return colorgfx
EndFunction


'returns a specific [shade, RGB] array that makes up a color scheme
Const SCHEME_GREY = 0
Const SCHEME_GREEN = 1
Const SCHEME_BLUE = 2
Const SCHEME_RED = 3
Const SCHEME_BROWN = 4
Const SCHEME_PINK = 5
Const SCHEME_YELLOW = 6
Const SCHEME_PURPLE = 7
Const SCHEME_BLACK = 8
Function colorScheme[](schemeID, shade)
	Local rgb[3]
	Select schemeID
	Case SCHEME_GREY
		Select shade
		'light
		Case 0
			rgb[0] = 192
			rgb[1] = 192
			rgb[2] = 192
		'mid
		Case 1
			rgb[0] = 128
			rgb[1] = 128
			rgb[2] = 128
		'dark
		Case 2
			rgb[0] = 64
			rgb[1] = 64
			rgb[2] = 64
		'highlight
		Case 3
			rgb[0] = 255
			rgb[1] = 138
			rgb[2] = 1
		EndSelect
	Case SCHEME_GREEN
		Select shade
		'light
		Case 0
			rgb[0] = 103
			rgb[1] = 147
			rgb[2] = 104
		'mid
		Case 1
			rgb[0] = 71
			rgb[1] = 163
			rgb[2] = 53
		'dark
		Case 2
			rgb[0] = 39
			rgb[1] = 109
			rgb[2] = 25
		'highlight
		Case 3
			rgb[0] = 255
			rgb[1] = 138
			rgb[2] = 1
		EndSelect
	Case SCHEME_BLUE
		Select shade
		'light
		Case 0
			rgb[0] = 192
			rgb[1] = 192
			rgb[2] = 192
		'mid
		Case 1
			rgb[0] = 129
			rgb[1] = 142
			rgb[2] = 189
		'dark
		Case 2
			rgb[0] = 71
			rgb[1] = 81
			rgb[2] = 117
		'highlight
		Case 3
			rgb[0] = 40
			rgb[1] = 40
			rgb[2] = 140
		EndSelect
	Case SCHEME_RED
		Select shade
		'light
		Case 0
			rgb[0] = 147
			rgb[1] = 103
			rgb[2] = 104
		'mid
		Case 1
			rgb[0] = 163
			rgb[1] = 53
			rgb[2] = 53
		'dark
		Case 2
			rgb[0] = 109
			rgb[1] = 25
			rgb[2] = 25
		'highlight
		Case 3
			rgb[0] = 255
			rgb[1] = 138
			rgb[2] = 1
		EndSelect
	Case SCHEME_BROWN
		Select shade
		'light
		Case 0
			rgb[0] = 118
			rgb[1] = 109
			rgb[2] = 92
		'mid
		Case 1
			rgb[0] = 95
			rgb[1] = 82
			rgb[2] = 63
		'dark
		Case 2
			rgb[0] = 95
			rgb[1] = 66
			rgb[2] = 36
		'highlight
		Case 3
			rgb[0] = 95
			rgb[1] = 93
			rgb[2] = 32
		EndSelect
	Case SCHEME_PINK
		Select shade
		'light
		Case 0
			rgb[0] = 215
			rgb[1] = 190
			rgb[2] = 210
		'mid
		Case 1
			rgb[0] = 190
			rgb[1] = 130
			rgb[2] = 165
		'dark
		Case 2
			rgb[0] = 115
			rgb[1] = 70
			rgb[2] = 115
		'highlight
		Case 3
			rgb[0] = 192
			rgb[1] = 192
			rgb[2] = 192
		EndSelect
	Case SCHEME_YELLOW
		Select shade
		'light
		Case 0
			rgb[0] = 233
			rgb[1] = 233
			rgb[2] = 126
		'mid
		Case 1
			rgb[0] = 193
			rgb[1] = 193
			rgb[2] = 76
		'dark
		Case 2
			rgb[0] = 166
			rgb[1] = 143
			rgb[2] = 16
		'highlight
		Case 3
			rgb[0] = 231
			rgb[1] = 143
			rgb[2] = 5
		EndSelect
	Case SCHEME_PURPLE
		Select shade
		'light
		Case 0
			rgb[0] = 247
			rgb[1] = 163
			rgb[2] = 255
		'mid
		Case 1
			rgb[0] = 161
			rgb[1] = 36
			rgb[2] = 161
		'dark
		Case 2
			rgb[0] = 100
			rgb[1] = 10
			rgb[2] = 100
		'highlight
		Case 3
			rgb[0] = 174
			rgb[1] = 106
			rgb[2] = 0
		EndSelect
	Case SCHEME_BLACK
		Select shade
		'light
		Case 0
			rgb[0] = 64
			rgb[1] = 64
			rgb[2] = 64
		'mid
		Case 1
			rgb[0] = 43
			rgb[1] = 43
			rgb[2] = 43
		'dark
		Case 2
			rgb[0] = 14
			rgb[1] = 14
			rgb[2] = 14
		'highlight
		Case 3
			rgb[0] = 130
			rgb[1] = 20
			rgb[2] = 20
		EndSelect
	EndSelect
	
	Return rgb
EndFunction




