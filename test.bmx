Graphics 400,400

Global animtest_gfx:TImage = LoadAnimImage("gfx/zerg_anemone_mouth.png",36,38,0,2)

DrawImage animtest_gfx,32,32,0

animtest_gfx.frame(0)

DrawImage ,32,64

Flip

WaitKey

End

Local sfx:TSound = LoadSound("sfx/mb_click.wav")
PlaySound sfx

DrawRect 100,100,50,50
DrawRect 100,150,-50,50

Flip
WaitKey

SetColor 255,255,255
Local text$ = "That long brown cat layered itself over the heat vent."

DrawText text,0,0

DrawText text[3],0,30

DrawText Chr(text[3]),0,60

Flip

WaitKey

Global deployicons_gfx:TImage = LoadImage("gfx/paint_nebulae.png")
 
Cls
For i = 0 To 3
	DrawImage deployicons_gfx,i*32,0
Next

'SetAlpha 1
'SetScale 1,1
'SetRotation 0
AutoMidHandle True
'SetMaskColor 255,255,255
'SetBlend(ALPHABLEND)

Global deployicons_gfx2:TImage = LoadAnimImage("gfx/deploy_icons.png",19,18,0,4)
SetImageHandle deployicons_gfx2,ImageWidth(deployicons_gfx2)/2,ImageHeight(deployicons_gfx2)/2

For i = 0 To 3
	DrawImage deployicons_gfx2,i*32,32,i
Next

Global deployicons_gfx3:TImage = LoadAnimImage("gfx/deploy_icons.png",19,18,0,4)
MidHandleImage deployicons_gfx3

For i = 0 To 3
	DrawImage deployicons_gfx3,i*32,64,i
Next

Flip

WaitKey

End
