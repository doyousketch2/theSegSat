--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--  Löve theSegSat

LO   = love
-- 3 letter abbrev's
aud  = LO .audio     --
eve  = LO .event        --  enabled
fil  = LO .filesystem   --  enabled
fon  = LO .font         --  enabled
gra  = LO .graphics     --  enabled
ima  = LO .image        --  enabled
joy  = LO .joystick  --
key  = LO .keyboard     --  enabled
mat  = LO .math         --  enabled
mou  = LO .mouse        --  enabled
phy  = LO .physics   --
sou  = LO .sound     --
sys  = LO .system    --
thr  = LO .thread    --
tim  = LO .timer        --  enabled
tou  = LO .touch        --  enabled
vid  = LO .video     --
win  = LO .window       --  enabled

-- look in conf.lua to enable necessary modules

HH  = gra .getHeight()
WW  = gra .getWidth()

-- copy font.dat and font8.dat into theSegSat dir

--     there's a trick to open files outside of that dir,
--     but it involves installing luafilesystem

-- The fonts default to read-only, because they came from a CD-ROM
-- which is fine for now, 'cuz this app is just a viewer so far,
-- but eventually, you'll want to set 'em so you can write changes

--     chmod +w fon*.dat

local filename  = 'font8.dat'
local data  = assert(io .open(filename, 'rb'))

local fontsize  = 13
local spacing  = fontsize +3
local font  = gra .newFont( fontsize )

local BPP  = 4
local bits  = {}
local pairs  = {}

local cols  = 11
local rows  = 4

local tileWidth  = 8
local tileHeight  = 16

local pixelSize  = 11
local gap  = pixelSize +1

local cursorX  = 80
local cursorY  = spacing *2 + 10
local cursorCol  = 1
local cursorRow  = 0

local header  = 0     -- skip data before here, if needed.  Maybe 2bit uses a header?
local slider  = 0     -- distance slider travels while scrolling,  will calculate during LO .load()
local offset  = 0     -- scroll location

win .setTitle( win .getTitle() ..'     ' ..filename )
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .load()
  print('Löve App begin')

  gra .setDefaultFilter( 'nearest',  'nearest',  0 )
  gra .setBackgroundColor( 20,  80,  120 )
  gra .setLineWidth( 20 )

  -- loop through raw data and put bytes into pairs
  while true do
    local bytes  = data :read(1)
    if not bytes then  break  end
    pairs[#pairs +1]  = string .format('%02X',  string .byte(bytes))
  end -- while true

  slider  = HH *.7 /#pairs

  local hex2bin  = {  ['0'] = '0000',  ['1'] = '0001',  ['2'] = '0010',  ['3'] = '0011',
                      ['4'] = '0100',  ['5'] = '0101',  ['6'] = '0110',  ['7'] = '0111',
                      ['8'] = '1000',  ['9'] = '1001',  ['A'] = '1010',  ['B'] = '1011',
                      ['C'] = '1100',  ['D'] = '1101',  ['E'] = '1110',  ['F'] = '1111'  }

  -- convert to binary
  for i  = 1,  #pairs do  -- "FF"
    if i >= header then

      for s  = 1,  2 do -- 'FF'  to  'F' and 'F'
        this  = string .sub(pairs[i],  s,  s)

        if BPP  == 2 then -- split '1100'  to  '11' and '00'
          for b  = 1,  3,  2 do
            bits[#bits +1]  = string .sub( hex2bin[this],  b,  b +1 )
          end -- for b  = 1,  3,  2

        else -- BPP == 4
          bits[#bits +1]  = hex2bin[this]
        end -- if BPP

      end --  for s  = 1,  2
    end -- if i >= begin
  end -- for i = 1,  #pairs
end -- LO .load

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .wheelmoved(x, y)
  if y < 0 then -- scrolling down

    if key .isDown( 'lshift' ) or key .isDown( 'rshift' ) then
      offset  = offset +2
    else
      offset  = offset +64
    end

    if offset > #bits -rows *tileHeight *cols *tileWidth then
      offset  = #bits -rows *tileHeight *cols *tileWidth
    end

  elseif y > 0 then -- scrolling up

    if key .isDown( 'lshift' ) or key .isDown( 'rshift' ) then
      offset  = offset -2
    else
      offset  = offset -64
    end

    if offset < 0 then
      offset  = 0
    end
  end
end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .update(dt)
  -- easy exit
  if key .isDown( 'escape' ) then
    eve .push( 'quit' )
  end -- key .isDown


  -- check for mouse
  if mou .isDown(1)  then
    cursorX  = mou .getX()
    cursorY  = mou .getY()
  end -- mou .isDown
end


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- includes 2bit,  and 4bit values,  but we're just using 4bit lookups for now.
local colorTable  = {  ['00']  = { 0,    0,    0,    0 },      ['01']  = { 50,   50,   50,   255 },
                       ['10']  = { 100,  100,  100,  255 },    ['11']  = { 150,  150,  150,  255 },

                       ['0000']  = { 0,    0,    0,    0  },   ['0001']  = { 15,   15,   15,   255 },
                       ['0010']  = { 30,   30,   30,   255 },  ['0011']  = { 45,   45,   45,   255 },
                       ['0100']  = { 60,   60,   60,   255 },  ['0101']  = { 75,   75,   75,   255 },
                       ['0110']  = { 90,   90,   90,   255 },  ['0111']  = { 105,  105,  105,  255 },
                       ['1000']  = { 120,  120,  120,  255 },  ['1001']  = { 135,  135,  135,  255 },
                       ['1010']  = { 150,  150,  150,  255 },  ['1011']  = { 165,  165,  165,  255 },
                       ['1100']  = { 180,  180,  180,  255 },  ['1101']  = { 195,  195,  195,  255 },
                       ['1110']  = { 210,  210,  210,  255 },  ['1111']  = { 255,  255,  255,  255 }  }

function LO .draw()
  gra .setPointSize( 5 )

  i  = 1
  for r  = 0,  rows -1  do
    for c  = 0,  cols -1  do
      for y  = 1,  tileHeight  do
        for x  = 1,  tileWidth  do
          local this  = bits[i + offset]

          local R  = colorTable[this][1]
          local G  = colorTable[this][2]
          local B  = colorTable[this][3]
          local A  = colorTable[this][4]

          gra .setColor( R,  G,  B,  A )

          local xx  = c *gap *tileWidth
          local yy  = r *gap *tileHeight

          -- draw pixel
          gra .rectangle( 'fill',  x *gap +xx +10,  y *gap +yy +10,  pixelSize,  pixelSize )
          i  = i +1

        end -- tileWidth
      end -- tileHeight
    end -- cols
  end -- rows

  -- slider dot on right side of screen
  gra .setPointSize( 16 )
  gra .setColor( 220,  220,  220,  50 )
  gra .points( WW -10,  offset *slider +20 )

  -- cursor
  gra .setPointSize( fontsize )
  if toggle then
    gra .print( cursorRow ..'  ' ..cursorCol,  100,  HH -100 )
    gra .setColor( 255,  20,  50,  50 )
  else
    gra .setColor( 220,  220,  220,  50 )
  end

  -- print offset in bottom-right corner
  gra .setColor( 220,  220,  220,  250 )
  gra .print( offset,  WW -100,  HH -20 )
end -- LO .draw()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .quit()
  print('Löve App exit')
end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

