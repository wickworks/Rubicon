'-- TUTORIAL METAGAME --
'teach the player how to shoot & drive

width = 900
height = 900
setup_cbox()'needs to go after width, height set

levelmusic = mission2_music

'set up factions
fTable[1,2] = -1	'1 enemies of faction 2
fTable[2,1] = -1	'2 enemies of faction 1

'add some scenery
'add_backdrop("greenplanet",500,500)

'remove whatever malarky hoops we had to jump through
RemoveLink(p1.link)
ListRemove(entityList,p1)'just in case...

'make the backdrop a grid
backdrop_gfx[0] = null
backdrop_gfx[1] = grid_gfx
backdrop_rgb[0] = 32
backdrop_rgb[1] = 32
backdrop_rgb[2] = 32

'set the stage of the tutorial to initial
value[0] = 0

'launch the game
game.play()

'just to make sure
cheat_disableengines = False