from PIL import Image, ImageDraw
import math
exec(open('/home/claude/work/brewtopia/tools/preview_scene.py').read().split("paste('rug'")[0].replace("def paste","def _p"))
d='/home/claude/work/brewtopia/assets/'
def sc(y): return max(.55,min(1.25,.6+(y-560)/500*.5))
S=2
def paste(n,x,y,scale=1.0,folder='scene'):
    im=Image.open(f'{d}{folder}/{n}.png'); w=int(im.width*scale); h=int(im.height*scale); im=im.resize((w,h),Image.LANCZOS); sky.alpha_composite(im,(int(x*S-w/2),int(y*S-h)))
def person(v,x,y,seated=False,tx=None):
    s=sc(y); cs=480*s*(0.84 if seated else 1.0)
    im=Image.new('RGBA',(500,500))
    parts=('body',) if seated else ('legL','legR','body')
    for p in parts: im.alpha_composite(Image.open(f'{d}people/c{v}_{p}.png'))
    im=im.resize((int(cs*S),int(cs*S)),Image.LANCZOS)
    if seated:
        hip=.616 if v<4 else .72; top=y-hip*cs
        sky.alpha_composite(im,(int(x*S-im.width/2),int(top*S)))
    else:
        sky.alpha_composite(im,(int(x*S-im.width/2),int((y-.92*cs)*S)))
# draw order by y
items=[]
paste('rug',300,1000,1.0)
tabs=[(110,905,0),(490,905,1),(300,905,2),(110,1055,3)]
for (tx,ty,i) in tabs:
    s=sc(ty); paste('chair',tx,ty-30*s,s*1.0)   # kursi di belakang
for (tx,ty,i) in tabs:
    s=sc(ty); top=ty-60*s
    person([0,5,2,6][i],tx,top,seated=True)
    paste('table_%d'%(i%3),tx,ty,s)
for (x,v) in ((330,1),(235,4),(140,3)):
    paste('bin',45,700); person(v,x,706)
paste('plant_big',560,870); paste('jukebox',545,1150); paste('frames',415,215); paste('neon',510,170)
paste('barista_m',285,0,0)  if False else None
b=Image.open(d+'people/barista_m.png'); cs=380; b=b.resize((int(cs*S),int(cs*S)),Image.LANCZOS)
# barista di belakang counter: sisipkan sebelum counter
base=sky.copy()
sky.convert('RGB').resize((600,1300)).save('/tmp/compose.png')
sky.convert('RGB').crop((0,600,1200,2200)).resize((750,1000)).save('/tmp/compose_crop.png')
