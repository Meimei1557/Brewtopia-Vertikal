from PIL import Image, ImageDraw
d='/home/claude/work/brewtopia/assets/scene/'
wall=Image.open(d+'wall.png'); cnt=Image.open(d+'counter.png'); door=Image.open(d+'door.png')
sky=Image.new('RGBA',wall.size); sd=ImageDraw.Draw(sky)
for y in range(wall.height):
    t=min(1,y/700); sd.line([0,y,wall.width,y],fill=(int(120+100*t),int(190+50*t),int(240+10*t),255))
sky.alpha_composite(wall); sky.alpha_composite(cnt); sky.alpha_composite(door,(int(458*2),int(196*2)))
def paste(n,x,y):
    im=Image.open(d+n+'.png'); sky.alpha_composite(im,(int(x*2-im.width/2),int(y*2-im.height)))
paste('rug',300,1000)
for x in (110,300,490): paste('chair',x,845); 
for x in (110,300,490): paste('table_0',x,905)
for x in (110,300,490): paste('table_1',x,1055)
paste('bin',45,700); paste('plant_big',555,820); paste('jukebox',545,1130); paste('frames',415,215); paste('neon',510,170); paste('plant_small',60,1180)
sky.convert('RGB').resize((600,1300)).save('/tmp/scene_full.png')
sky.convert('RGB').crop((0,0,1200,1250)).resize((780,813)).save('/tmp/scene_top.png')
