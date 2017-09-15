-- Tile size in world coords
local TSIZE=50

local G={
 ex=0, ey=25, ez=100, yaw=180,
 lvlNo=0,
 lvl=nil,  -- reference to LVL[lvlNo]
}

-- sprite numbers
local S={
 FLAG=240,
 META_0=241,
}

-- tile flags
local TF={
 -- walls in the tile
 N=1,
 E=2,
 S=4,
 W=8,
}

-- tile descriptors
-- w: which walls this tile contains
local TD={
 [1]={w=TF.S|TF.E,tid=258},
 [2]={w=TF.S,tid=258},
 [3]={w=TF.S|TF.W,tid=258},
 [17]={w=TF.E,tid=258},
 [19]={w=TF.W,tid=258},
 [33]={w=TF.N|TF.E,tid=258},
 [34]={w=TF.N,tid=258},
 [35]={w=TF.N|TF.W,tid=258},
}

local LVL={
 -- Each has:
 --   name: display name of level.
 --   pg: map page where level starts.
 --   pgw,pgh: width and height of level, in pages
 {name="Level 1",pg=0,pgw=1,pgh=1},
}

function Boot()
 S3Init()
 StartLevel(1)
 --S3WallAdd({lx=0,lz=0,rx=50,rz=0,tid=256})
 --S3WallAdd({lx=50,lz=0,rx=50,rz=-50,tid=258})
 --S3WallAdd({lx=50,lz=-50,rx=0,rz=-50,tid=260})
 --S3WallAdd({lx=0,lz=-50,rx=0,rz=0,tid=262})

 --S3WallAdd({lx=100,lz=0,rx=150,rz=0,tid=256})
 --S3WallAdd({lx=150,lz=0,rx=150,rz=-50,tid=258})
 --S3WallAdd({lx=150,lz=-50,rx=100,rz=-50,tid=260})
 --S3WallAdd({lx=100,lz=-50,rx=100,rz=0,tid=262})
end

function TIC()
 local stime=time()
 cls(2)
 local fwd=btn(0) and 1 or btn(1) and -1 or 0
 local right=btn(2) and -1 or btn(3) and 1 or 0
 G.ex=G.ex-math.sin(G.yaw)*fwd*2.0
 G.ez=G.ez-math.cos(G.yaw)*fwd*2.0
 if btn(4) then
  -- strafe
  G.ex=G.ex-math.sin(G.yaw-1.5708)*right*2.0
  G.ez=G.ez-math.cos(G.yaw-1.5708)*right*2.0
 else
  G.yaw=G.yaw-right*0.03
 end
 S3SetCam(G.ex,G.ey,G.ez,G.yaw)
 S3Rend()
 print(S3Round(1000/(time()-stime)).."fps")
end

function StartLevel(lvlNo)
 G.lvlNo=lvlNo
 G.lvl=LVL[lvlNo]
 local lvl=G.lvl
 S3Reset()

 for r=0,lvl.pgh*17-1 do
  for c=0,lvl.pgw*30-1 do
   local t=LvlTile(c,r)
   local td=TD[t]
   if td then AddWalls(c,r,td) end
  end
 end
end

-- Add the walls belonging to the given level tile.
function AddWalls(c,r,td)
 local s=TSIZE
 local xw,xe=c*s,(c+1)*s -- x of east and west
 local zn,zs=r*s,(r+1)*s -- z of north and south
 if 0~=(td.w&TF.N) then
  -- north wall
  S3WallAdd({lx=xe,rx=xw,lz=zn,rz=zn,tid=td.tid})
 end
 if 0~=(td.w&TF.S) then
  -- south wall
  S3WallAdd({lx=xw,rx=xe,lz=zs,rz=zs,tid=td.tid})
 end
 if 0~=(td.w&TF.E) then
  -- east wall
  S3WallAdd({lx=xe,rx=xe,lz=zs,rz=zn,tid=td.tid})
 end
 if 0~=(td.w&TF.W) then
  -- west wall
  S3WallAdd({lx=xw,rx=xw,lz=zn,rz=zs,tid=td.tid})
 end
end

function LvlTile(c,r)
 if c>=G.lvl.pgw*30 or
   r>=G.lvl.pgh*17 or c<0 or r<0 then
  return 0
 end
 local c0,r0=MapPageStart(G.lvl.pg)
 return mget(c0+c,r0+r)
end

-- Returns col,row where the given map page starts.
function MapPageStart(pg)
 return (pg%8)*30,(pg//8)*16
end

-- Gets the meta "value" of the given tile, or nil
-- if it has none.
function MetaValue(t)
 if t>=S.META_0 and t<=S.META_0+9 then
  return t-S.META_0
 end
end

-- Gets the meta value of a meta tile that's adjacent
-- to the given tile, nil if not found. This is called
-- the tile "label".
function TileLabel(tc,tr)
 for c=tc-1,tc+1 do
  for r=tr-1,tr+1 do
   local mv=MetaValue(LvlTile(c,r))
   if mv then return mv end
  end
 end
 return nil
end

function Assert(c,msg)
 if not c then error(msg) end
end

---------------------------------------------------
-- S3 "Simple 3D" library
---------------------------------------------------

local S3={
 -- eye coordinates (world coords)
 ex=0, ey=0, ez=0, yaw=0,
 -- Precomputed from ex,ey,ez,yaw:
 cosMy=0, sinMy=0, termA=0, termB=0,
 -- These are hard-coded into the projection function,
 -- so if you change then, also update the math.
 NCLIP=0.1,
 FCLIP=1000,
 -- min/max world Y coord of all walls
 W_BOT_Y=0,
 W_TOP_Y=50,
 -- fog start and end dists (squared)
 FOG_S=20000,
 FOG_E=80000,
 -- light flicker amount (as dist squared)
 FLIC_AMP=1500,
 FLIC_FM=0.003,  -- frequency multiplier
 -- list of all walls, each with
 --
 --  lx,lz,rx,rz: x,z coords of left and right endpts
 --  in world coords (y coord is auto, goes from
 --  W_BOT_Y to W_TOP_Y)
 --  tid: texture ID
 --
 --  Computed at render time:
 --   slx,slz,slty,slby: screen space coords of
 --     left side of wall (x, z, top y, bottom y)
 --   srx,srz,srty,srby: screen space coords of
 --     right side of wall (x, z, top y, bottom y)
 walls={},
 -- H-Buffer, used at render time:
 hbuf={},
 -- Floor and ceiling colors.
 floorC=9,
 ceilC=1,
 -- Color model, indicating which colors are shades
 -- of the same hue.
 clrM={
  -- Gray ramp
  {1,2,3,15},
  -- Green ramp
  {7,6,5,4},
  -- Brown ramp
  {8,9,10,11}
 },
 -- Reverse color lookup (ramp for given color)
 -- Fields:
 --   ramp (reference to a ramp in clrM)
 --   i (index of the color within the ramp).
 clrMR={}, -- computed on init
}

local sin,cos,PI=math.sin,math.cos,math.pi
local floor,ceil=math.floor,math.ceil
local min,max,abs,HUGE=math.min,math.max,math.abs,math.huge
local SCRW=240
local SCRH=136

function S3Init()
 _S3InitClr()
 S3Reset()
end

function S3Reset()
 S3SetCam(0,0,0,0)
 S3.walls={}
end

function _S3InitClr()
 -- Build reverse color model
 for c=15,1,-1 do S3.clrMR[c]=nil end
 for _,ramp in pairs(S3.clrM) do
  for i=1,#ramp do
   local thisC=ramp[i]
   S3.clrMR[thisC]={ramp=ramp,i=i}
  end
 end
end

-- Modules a color by a given factor, using the
-- color ramps in the color model.
-- If sx,sy are provided, we will dither using
-- that screen position as reference.
function _S3ClrMod(c,f,x,y)
 if f==1 then return c end
 local mr=S3.clrMR[c]
 if not mr then return c end
 local di=mr.i*f -- desired intensity
 local int
 if x then
  -- Dither.
  local loi=floor(di)
  local hii=ceil(di)
  local fac=di-loi
  local ent=(x+y)%3
  int=fac>0.9 and hii or
   ((fac>0.5 and ent~=1) and hii or
   ((fac>0.1 and ent==1) and hii or loi))
 else
  -- No dither, just round.
  int=S3Round(di)
 end
 return int<=0 and 0 or
   mr.ramp[S3Clamp(int,1,#mr.ramp)]
end

function S3WallAdd(w)
 table.insert(S3.walls,{lx=w.lx,lz=w.lz,rx=w.rx,
   rz=w.rz,tid=w.tid})
end

function S3SetCam(ex,ey,ez,yaw)
 S3.ex,S3.ey,S3.ez,S3.yaw=ex,ey,ez,yaw
 -- Precompute some factors we will need often:
 S3.cosMy,S3.sinMy=cos(-yaw),sin(-yaw)
 S3.termA=-ex*S3.cosMy-ez*S3.sinMy
 S3.termB=ex*S3.sinMy-ez*S3.cosMy
end

function S3Proj(x,y,z)
 local c,s,a,b=S3.cosMy,S3.sinMy,S3.termA,S3.termB
 -- Hard-coded from manual matrix calculations:
 local px=0.9815*c*x+0.9815*s*z+0.9815*a
 local py=1.7321*y-1.7321*S3.ey
 local pz=s*x-z*c-b-0.2
 local pw=x*s-z*c-b
 local ndcx=px/pw
 local ndcy=py/pw
 return 120+ndcx*120,68-ndcy*68,pz
end

function S3Rend()
 -- TODO: compute potentially visible set instead.
 local pvs=S3.walls
 local hbuf=S3.hbuf
 -- For an explanation of the rendering, see: https://docs.google.com/document/d/1do-iPbUHS2RF-lJAkPX98MsT9ZK5d5sBaJmekU1bZQU/edit#bookmark=id.7tkdwb6fk7e2
 _S3PrepHbuf(hbuf,pvs)
 _S3RendHbuf(hbuf)
 _S3RendFlats(hbuf)
end

function _S3ResetHbuf(hbuf)
 local scrw,scrh=SCRW,SCRH
 for x=0,scrw-1 do
  -- hbuf is 1-indexed (because Lua)
  hbuf[x+1]=hbuf[x+1] or {}
  local b=hbuf[x+1]
  b.wall=nil
  b.z=HUGE
 end
end

-- Compute screen-space coords for wall.
function _S3ProjWall(w)
 local topy=S3.W_TOP_Y
 local boty=S3.W_BOT_Y

 -- notation: lt=left top, rt=right top, etc.
 local ltx,lty,ltz=S3Proj(w.lx,topy,w.lz)
 local rtx,rty,rtz=S3Proj(w.rx,topy,w.rz)
 if rtx<=ltx then return false end  -- cull back side
 if rtx<0 or ltx>=SCRW then return false end
 local lbx,lby,lbz=S3Proj(w.lx,boty,w.lz)
 local rbx,rby,rbz=S3Proj(w.rx,boty,w.rz)

 w.slx,w.slz,w.slty,w.slby=ltx,ltz,lty,lby
 w.srx,w.srz,w.srty,w.srby=rtx,rtz,rty,rby

 -- TODO: fix aggressive clipping
 if w.slz<S3.NCLIP or w.srz<S3.NCLIP
   then return false end
 if w.slz>S3.FCLIP or w.srz>S3.FCLIP
   then return false end
 return true
end

function _S3PrepHbuf(hbuf,walls)
 _S3ResetHbuf(hbuf)
 for i=1,#walls do
  local w=walls[i]
  if _S3ProjWall(w) then _AddWallToHbuf(hbuf,w) end
 end
 -- Now hbuf has info about all the walls that we have
 -- to draw, per screen X coordinate.
 -- Fill in the top and bottom y coord per column as
 -- well.
 for x=0,SCRW-1 do
  local hb=hbuf[x+1] -- hbuf is 1-indexed
  if hb.wall then
   local w=hb.wall
   hb.ty=_S3Interp(w.slx,w.slty,w.srx,w.srty,x)
   hb.by=_S3Interp(w.slx,w.slby,w.srx,w.srby,x)
  end
 end
end

function _AddWallToHbuf(hbuf,w)
 local startx=max(0,S3Round(w.slx))
 local endx=min(SCRW-1,S3Round(w.srx))
 for x=startx,endx do
  -- hbuf is 1-indexed (because Lua)
  local hbx=hbuf[x+1]
  local z=_S3Interp(w.slx,w.slz,w.srx,w.srz,x)
  if hbx.z>z then  -- depth test.
   hbx.z,hbx.wall=z,w  -- write new depth.
  end
 end
end

function _S3RendHbuf(hbuf)
 local scrw=SCRW
 for x=0,scrw-1 do
  local hb=hbuf[x+1]  -- hbuf is 1-indexed
  local w=hb.wall
  if w then
   local z=_S3Interp(w.slx,w.slz,w.srx,w.srz,x)
   local u=_S3PerspTexU(w.slx,w.slz,w.srx,w.srz,x)
   _S3RendTexCol(w.tid,x,hb.ty,hb.by,u,z)
  end
 end
end

-- Returns the fog factor (0=completely fogged/dark,
-- 1=completely lit) for a point at screen pos
-- sx and screen-space depth sz.
function _S3FogFact(sx,sz)
 local FOG_S,FOG_E=S3.FOG_S,S3.FOG_E
 sx=120-sx
 local d2=sx*sx+sz*sz
 if S3.FLIC_AMP>0 then
  local f=sin(time()*S3.FLIC_FM)*S3.FLIC_AMP
  d2=d2+f
 end
 return d2<FOG_S and 1 or
   _S3Interp(FOG_S,1,FOG_E,0,d2)
end

-- Renders a vertical column of a texture to
-- the screen given:
--   tid: texture ID
--   x: x coordinate
--   ty,by: top and bottom y coordinate.
--   u: horizontal texture coordinate (0 to 1)
--   z: depth.
function _S3RendTexCol(tid,x,ty,by,u,z)
 local fogf=_S3FogFact(x,z)
 local aty,aby=max(ty,0),min(by,SCRH-1)
 if fogf<=0 then
  -- Shortcut: just a black line.
  line(x,aty,x,aby,0)
  return
 end

 for y=aty,aby do
  -- affine texture mapping for the v coord is ok,
  -- since walls are never slanted.
  local v=_S3Interp(ty,0,by,1,y)
  local clr=_S3TexSamp(tid,u,v)
  clr=_S3ClrMod(clr,fogf,x,y)
  pix(x,y,clr)
 end
end

function _S3PerspTexU(lx,lz,rx,rz,x)
 local a=_S3Interp(lx,0,rx,1,x) 
 -- perspective-correct texture mapping
 return (a/((1-a)/lz+a/rz))/rz
end

-- Returns the factor by which to module the color
-- of the floor or ceiling when drawing at those
-- screen coordinates.
function _S3FlatFact(x,y)
 local z=2944.57/(68-y)  -- manually calculated
 return _S3FogFact(x,z)
end

function _S3RendFlats(hbuf)
 local scrw,scrh=SCRW,SCRH
 local ceilC,floorC=S3.ceilC,S3.floorC
 for x=0,scrw-1 do
  local cby=scrh/2 -- ceiling bottom y
  local fty=scrh/2+1 -- floor top y
  local hb=hbuf[x+1] -- hbuf is 1-indexed
  if hb.wall then
   cby=min(cby,hb.ty)
   fty=max(fty,hb.by)
  end
  for y=0,cby-1 do
   pix(x,y,_S3ClrMod(ceilC,_S3FlatFact(x,y),x,y))
  end
  for y=fty,scrh-1 do
   pix(x,y,_S3ClrMod(floorC,_S3FlatFact(x,y),x,y))
  end
  --line(x,0,x,cby-1,S3.ceilC)
  --line(x,fty,x,scrh-1,S3.floorC)
 end
end

function S3Round(x) return floor(x+0.5) end
function S3Clamp(x,lo,hi)
 return x<lo and lo or (x>hi and hi or x)
end

function _S3Interp(x1,y1,x2,y2,x)
 if x2<x1 then
  x1,x2=x2,x1
  y1,y2=y2,y1
 end
 return x<=x1 and y1 or (x>=x2 and y2 or
   (y1+(y2-y1)*(x-x1)/(x2-x1)))
end

-- Sample texture ID tid at texture coords u,v.
-- The texture ID is just the sprite ID where
-- the texture begins in sprite memory.
function _S3TexSamp(tid,u,v)
 -- texture size in pixels
 -- TODO make this variable
 local SX=16
 local SY=16
 local tx=S3Round(u*SX)%SX
 local ty=S3Round(v*SY)%SY
 local spid=tid+(ty//8)*16+(tx//8)
 tx=tx%8
 ty=ty%8
 return peek4(0x8000+spid*64+ty*8+tx)
end

--------------------------------------------------
Boot()
