--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--  Löve theSegSat                               6 Jun 2017

--  Eli Innis   @Doyousketch2                    GNU GPL v3
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- copy font.dat  font8.dat  SYSTEM.DAT  into theSegSat dir

--     Love2D defaults to sandboxing apps for security.
--     There's a trick to open files outside of that dir,
--     but it involves installing luafilesystem

local filename  = 'SYSTEM.DAT'

local header  = 88420    -- skip data before 88420,  if needed...

local pixelSize  = 11
local gap  = pixelSize +1

local tileWidth  = 8     -- pixels per tile
local tileHeight  = 16

local cols  = 8          -- how many tiles are onscreen at once
local rows  = 4

local fontsize  = 18

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- no need to change variables below here


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
tou  = LO .touch     --
vid  = LO .video     --
win  = LO .window       --  enabled

-- look in conf.lua to enable necessary modules

HH  = gra .getHeight()
WW  = gra .getWidth()

local nib  = {}           -- 4 bits in each index location
local bytes  = {}         -- pairs of nibbles
local pixel  = {}         -- RGBA values for each pixel

local cursorX  = 0      -- actual screen location of mouse
local cursorY  = 0

local cursorCol  = 1    -- position within the grid-of-pixels that's been clicked on
local cursorRow  = 0

local colors  = 16
local paint  = 1        -- current color selected to paint with

local head  = {}        -- cache for header 'till it's flushed out later
local slider  = 0       -- distance slider travels while scrolling.  calculated during readData()

local click  = 0        -- disables click repeat,  when you toggle BPP
local cursor  = 1       -- display cursor position?

local offset  = 0       -- scroll location
local loc  = 0          -- pixel location
local size  = 1         -- size of paintbrush
local bgCount  = 0      -- background counter,  to flash color after written

local maxW  = cols *tileWidth *gap +21   -- boundaries of clickable grid area
local maxH  = rows *tileHeight *gap +11

local font  = gra .newFont( fontsize )

-- hexadecimal to binary-equivalent chart.
local hex2bin  = {  ['0'] = '0000',  ['1'] = '0001',  ['2'] = '0010',  ['3'] = '0011',
                    ['4'] = '0100',  ['5'] = '0101',  ['6'] = '0110',  ['7'] = '0111',
                    ['8'] = '1000',  ['9'] = '1001',  ['A'] = '1010',  ['B'] = '1011',
                    ['C'] = '1100',  ['D'] = '1101',  ['E'] = '1110',  ['F'] = '1111'  }

local bin2hex  = {  ['0000'] = '0',  ['0001'] = '1',  ['0010'] = '2',  ['0011'] = '3',
                    ['0100'] = '4',  ['0101'] = '5',  ['0110'] = '6',  ['0111'] = '7',
                    ['1000'] = '8',  ['1001'] = '9',  ['1010'] = 'A',  ['1011'] = 'B',
                    ['1100'] = 'C',  ['1101'] = 'D',  ['1110'] = 'E',  ['1111'] = 'F'  }

-- 4bit hybrid colorTable for viewing,  2bit values will become tinted
local coTabl  = {  ['0000']  = 0,    ['0001']  = 240,  ['0010']  = 140,  ['0011']  = 40,

                   ['0100']  = 60,   ['0101']  = 75,   ['0110']  = 90,   ['0111']  = 105,
                   ['1000']  = 120,  ['1001']  = 135,  ['1010']  = 150,  ['1011']  = 165,
                   ['1100']  = 180,  ['1101']  = 195,  ['1110']  = 210,  ['1111']  = 255  }

-- "index to key" lookups, 'cuz key-value pairs are unordered in Lua
local ki  = 0

local four   = {  '0000', '0001', '0010', '0011', '0100', '0101', '0110', '0111',
                  '1000', '1001', '1010', '1011', '1100', '1101', '1110', '1111'  }

local bitTabl4  = {    [0]  = '0',  [240]  = '1',  [140]  = '2',   [40]  = '3',
                      [60]  = '4',   [75]  = '5',   [90]  = '6',  [105]  = '7',
                     [120]  = '8',  [135]  = '9',  [150]  = 'A',  [165]  = 'B',
                     [180]  = 'C',  [195]  = 'D',  [210]  = 'E',  [255]  = 'F'  }

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function alpha( this )

  if this == 0 then -- if {0,0,0} then alpha is also 0  (transparent background)
    a  = { 0, 0, 0,  0 }

  elseif this == 240 or this == 140 or this == 40 then -- 0001  0010  0011
    a  = { this, this, this,  140 } -- if only using two bits, then tint
  else
    a  = { this, this, this,  255 } -- standard color,  solid alpha value 255
  end -- if this ==

    return a
end -- function alpha()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function readData()
  if #nib > 0 then -- clear tables
    local count  = #nib
    for i = 1,  count do  nib[i]  = nil end

    count  = #bytes
    for i = 1,  count do  bytes[i]  = nil end

    count  = #pixel
    for i = 1,  count do  pixel[i]  = nil end
  end -- if #nib

  -- loop through raw data and put bytes into pairs
  local data  = assert( io .open( filename, 'rb' ))

  while true do
    local rawBytes  = data :read(1)
    if not rawBytes then  break  end
    bytes[ #bytes +1 ]  = string .format( '%02X',  string .byte( rawBytes ))
  end -- while true

  offset  = 0
  cursorCol  = 1
  cursorRow  = 0
  slider  = HH /( #bytes *2 )

  -- convert to binary
  for i = 1,  #bytes do  -- "FF"

    if i < header then   -- skip header,  if necessary,
      head[ #head +1 ]  = bytes[i]
    else
      for s = 1,  2 do   --- split nibbles  'FF'  to  'F' and 'F'

        local this  = string .sub( bytes[i],  s,  s )
        nib[ #nib +1 ]  = hex2bin[ this ] -- 'F'  to  '1111'

      end --  for s  = 1,  2
    end -- if i < header
  end -- for i = 1,  #bytes

  for i = 1,  #nib do -- determine alpha value for pixel
    pixel[#pixel +1]  = alpha(  coTabl[ nib[i] ]  )
  end -- for i = 1,  #nib
end -- readData()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function writeData()
  print('Writing to newfont.dat')
  local out  = io .open('newfont.dat', 'wb')
  local str  = ''

  count  = #bytes -- clear list
  for i = 1,  count do  bytes[i]  = nil end

  for i = 1,  #head do -- recover header
    bytes[#bytes +1]  = head[i]
  end -- for i = 1,  #head

  local export  = {} -- generate export list
  for i = 1,  #pixel do
    if pixel[i][1] == pixel[i][2] then -- strip padding

      export[#export +1]  = bitTabl4[ pixel[i][1] ]
    end -- if pixel[i] == pixel[i][2]
  end -- for i = 1,  #pixel

  for i = 1,  #export -1,  2 do -- join pixels (nibbles) to create bytes
      bytes[#bytes +1]  = export[i] ..export[i +1]
  end -- for

  for i = 1,  #bytes do
    local num  = tonumber( bytes[i],  16 )  -- 'F0'  to  240
    out :write(  string .char( num )  )     -- ASCII  U+0240
  end -- for i = 1,  #bytes

  out :close()
  print('Written')
end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .load()
  print('Löve App begin')

  win .setTitle( win .getTitle() ..'     ' ..filename )
  gra .setDefaultFilter( 'nearest',  'nearest',  0 )
  gra .setBackgroundColor( 20,  80,  120 )
  gra .setLineWidth( 2 )

  readData()

end -- LO .load

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .wheelmoved(x, y)
  if y < 0 then -- scrolling down

    if key .isDown( 'lshift' ) or key .isDown( 'rshift' ) then -- coarse rate of change,
      offset  = offset +1024
    elseif key .isDown( 'lctrl' ) or key .isDown( 'rctrl' ) then -- fine rate of change
      offset  = offset +1
    else
      offset  = offset +128            -- 8x8 = 64.  *2 at a time = 128 pixels
    end -- if key

    local max  = #nib -rows *tileHeight *cols *tileWidth -- max value
    if offset > max then
      offset  = max
    end -- if offset >

  elseif y > 0 then -- scrolling up

    if key .isDown( 'lshift' ) or key .isDown( 'rshift' ) then -- coarse rate of change,
      offset  = offset -1024
    elseif key .isDown( 'lctrl' ) or key .isDown( 'rctrl' ) then -- fine rate of change
      offset  = offset -1
    else
      offset  = offset -128            -- 8x8 = 64.  *2 at a time = 128 pixels
    end -- if key

    if offset < 0 then                                   -- min value
      offset  = 0
    end -- if offset <
  end -- if y
end -- LO .wheelmoved

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function mouseStuff()
  cursorX  = mou .getX()
  cursorY  = mou .getY()

  if cursorX > WW -70 and cursorX < WW -30 then  -- clicked on right-side of screen
    cursor  = 0

    if cursorY < 450 then -- clicked within palette
      paint  = math .floor((cursorY -38) /24)    -- determine paint color
      if paint < 1 then                          -- min value
        paint  = 1
      elseif paint > colors then                   -- max
        paint  = colors
      end -- if paint

    elseif cursorY > HH -100 then
      gra .setBackgroundColor( 0,  50,  100 )
      bgCount  = 30  -- dim screen for a moment
      writeData()
    end -- if cursorY

  -- clicked within pixel grid?
  elseif cursorX > 21 and cursorX < maxW and cursorY > 11 and cursorY < maxH then
    cursorCol  = math .ceil( (cursorX -21) /gap )
    cursorRow  = math .floor( (cursorY -11) /gap )
    cursor  = 1

    if cursorCol < 1 then                      -- min value Col
      cursorCol  = 1
    elseif cursorCol > cols *tileWidth then    -- max
      cursorCol  = cols *tileWidth
    end -- cursorCol

    if cursorRow < 0 then                      -- min value Row
      cursorRow  = 0
    elseif cursorRow > cols *tileHeight then   -- max
      cursorRow  = cols *tileHeight
    end -- cursorRow

  end -- if cursorX
end -- mouseStuff()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function paintPixel()
  if cursor == 1 then
    local tileX  = cursorCol %tileWidth          -- pixel X position within tile
    if tileX == 0 then
      tileX  = tileWidth                         -- if mod = 0,  we want to end up in right column
    end

    local tileY  = cursorRow %tileHeight         -- pixel Y position within tile

    local tileCol  = math .floor( (cursorCol -1) /tileWidth ) -- column of tile on screen-grid
    local tileRow  = math .floor( cursorRow /tileHeight )     -- row

    local oneTile  = tileY *tileWidth +tileX     -- localize all clicks to one tile
                                                 -- then multiply by grid placement

                                                 -- 8x8  = 64 *2  = 128   every grid pos takes up...
    local xx  = tileCol *128                     -- 128 pixels to jump to the next horiz pos
    local yy  = tileRow *128 *cols               -- 128x11 tiles per column  = 1408 pixels to go down a row

    loc  = oneTile +xx +yy +offset               -- current pixel position within the data

    if key .isDown( 'lctrl' ) or key .isDown( 'rctrl' ) then
      table .insert(  pixel,  loc,  {235, 175, 135}  ) -- insert padding
    else
      if pixel[ loc ][1] == pixel[ loc ][2] then -- only paint in pixels that aren't padding

        local digits  = four[ paint ] -- get binary digits for current color,  '1' to '0001'

        local rgb  = coTabl[ digits ] -- get RGB value
        local rgba = alpha( rgb ) -- determine alpha transparency

        pixel[ loc ]  = rgba  -- paint with current color

      end -- if pixel[ loc ][1] == pixel[ loc ][2]
    end -- if key .isDown( 'lctrl' )
  end -- if cursor
end -- paintPixel()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .update(dt)

  if key .isDown( 'escape' ) then -- easy exit
    eve .push( 'quit' )

  elseif key .isDown( 'delete' ) or key .isDown( 'backspace' ) then -- delete padding

      if pixel[ loc ][1] ~= pixel[ loc ][2] then
        table .remove( pixel, loc )
        ki  = 0
      end -- if pixel[ loc ][1] ~= pixel[ loc ][2]

  end -- key .isDown


  -- check for mouse
  if mou .isDown(1)  then -- left click
    mouseStuff()
    paintPixel()
    size  = 1

  else -- mouse up
    click  = 0
  end -- mou .isDown

  if mou .isDown(2)  then -- right click
    mouseStuff()
    paintPixel()
    size  = 4 -- paint 4 pixels

    if cursorCol < tileWidth *cols then
      cursorCol  = cursorCol +1
      paintPixel()
    end -- if cursorCol

    if cursorRow < tileHeight *rows -1 then
        cursorRow  = cursorRow +1
        paintPixel()
    end -- if cursorRow

    if cursorCol > 1 and cursorCol < tileWidth *cols then
        cursorCol  = cursorCol -1
        paintPixel()
    end -- if cursorCol and

  end -- if mou .isDown(2)

  if bgCount > 0 then
    bgCount  = bgCount -1

    if bgCount == 0 then
      gra .setBackgroundColor( 20,  80,  120 )
    end -- if bgCount == 0
  end -- if bgCount > 0

end -- LO .update(dt)

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .draw()

  -- draw pixel-grid
  gra .setPointSize( 5 )

  i  = 1
  for r  = 0,  rows -1  do
    for c  = 0,  cols -1  do
      for y  = 1,  tileHeight  do
        for x  = 1,  tileWidth  do
          gra .setColor( pixel[ i +offset ] )

          local xx  = c *gap *tileWidth
          local yy  = r *gap *tileHeight

          -- draw pixel    style,  x pos,           y pos,       width,      height
          gra .rectangle( 'fill',  x *gap +xx +10,  y *gap +yy,  pixelSize,  pixelSize )
          i  = i +1
        end -- tileWidth
      end -- tileHeight
    end -- cols
  end -- rows

  -- outline palette area
  gra .setColor( 220,  220,  220,  50 )
  gra .rectangle( 'line',  WW -70,  50,  40,  410 )

  -- draw in color swatches
  gra .setPointSize( 20 )

  for i = 1,  colors  do

    ki  = four[i] -- look up color key
    local rgba  = alpha(  coTabl[ ki ]  )
    gra .setColor( rgba )

    gra .points( WW -50,  i *24 +50 )
  end -- for i

  -- grid divisions
  gra .setColor( 220,  220,  220,  50 )

  for i = 1,  cols -1 do
    local xx  = i *tileWidth *gap +21
    local yy  = rows *tileHeight *gap +11
    gra .line( xx,  11,  xx,  yy )
  end -- for cols

  for i = 1,  rows -1 do
    local xx  = cols *tileWidth *gap +21
    local yy  = i *tileHeight *gap +11
    gra .line( 20,  yy,  xx,  yy )
  end -- for rows

  -- slider dot on right side of screen
  gra .setColor( 220,  220,  220,  50 )
  gra .points( WW -10,  offset *slider +20 )

  -- highlight selected color
  gra .setColor( 220,  20,  20,  200 )
  gra .rectangle( 'line',  WW -60,  paint *24 +38,  22,  22 )

  -- outline the pixel(s) you just painted
  if cursor > 0 then -- skip during palette select
    if size == 1 then                         -- draw rect around 1 pixel
      local xx  = cursorCol *gap +11
      local yy  = cursorRow *gap +11
      gra .rectangle( 'line',  xx,  yy,  gap,  gap )
    else                                      -- draw rect around 4 pixels
      local xx  = cursorCol *gap +11
      local yy  = cursorRow *gap
      gra .rectangle( 'line',  xx,  yy,  gap *2,  gap *2 )
    end -- if size
  end -- if cursor > 0

  -- print save & offset in bottom-right corner
  gra .setColor( 220,  220,  220,  250 )
  gra .print( offset,  WW -100,  HH -30 )

  if mou .getX() > WW -70 and mou .getX() < WW -30 and mou .getY() > HH -100 then
    gra .setColor( 220,  50,  50,  250 )
  end
  gra .print( 'Save',  WW -60,  HH -50 )
end -- LO .draw()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .quit()
  print('Löve App exit')
end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

