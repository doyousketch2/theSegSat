--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--  Löve theSegSat                               6 Jun 2017

--  Eli Innis   @Doyousketch2                    GNU GPL v3
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- copy font.dat  font8.dat  SYSTEM.DAT  into theSegSat dir

local filename  = 'SYSTEM.DAT'

--  Love2D defaults to sandboxing apps for security.
--  There's a trick to open files outside of that dir,
--  but it involves installing luafilesystem.

--  I'd do it,  if we were opening multiple unknown files.
--  but copying the file in is fine for our purposes.

local header  = 88420    -- skip data before 88420,  if needed...

local fontsize  = 17
local pixelSize  = 11    -- zoom
local gap  = pixelSize +1

local tileX  = 8         -- pixels per tile
local tileY  = 16

local cols  = 8          -- how many tiles are onscreen at once
local rows  = 4

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- no need to change variables below here

-- global shortcut abbreviations
LO   = love
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
halfWid  = WW /2

local nib  = {}         -- 4 bits in each index location,  a nib'ble
local bytes  = {}       -- pairs of nibbles
local pixel  = {}       -- RGBA values for each pixel
local hexlet  = {}      -- colored hex-letters to display on right side of screen

local cursorX  = 0      -- actual screen location of mouse
local cursorY  = 0

local cursorCol  = 1    -- position within the grid-of-pixels that's been clicked on
local cursorRow  = 0

local tileWidth  = tileX *gap  -- how big a tile is = pixels *how much space each pixel takes up
local tileHeight  = tileY *gap

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

local bigG  = gap *2 +1 -- used for drawing pixel highlight
local littleG  = gap +1

local minX  = 21
local minY  = 11

local maxW  = cols *tileX *gap +minX   -- boundaries of clickable grid area
local maxH  = rows *tileY *gap +minY

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

-- 4bit hybrid colorTable for viewing,  2bit values will become tinted,  using 40's for those
local coTabl  = {  ['0000']  = 0,    ['0001']  = 240,  ['0010']  = 140,  ['0011']  = 40,

                   ['0100']  = 60,   ['0101']  = 75,   ['0110']  = 90,   ['0111']  = 105,
                   ['1000']  = 120,  ['1001']  = 135,  ['1010']  = 150,  ['1011']  = 165,
                   ['1100']  = 180,  ['1101']  = 195,  ['1110']  = 210,  ['1111']  = 255  }

-- "index to key" lookups, 'cuz key-value pairs are unordered in Lua
local ki  = 0
local four   = {  '0000', '0001', '0010', '0011', '0100', '0101', '0110', '0111',
                  '1000', '1001', '1010', '1011', '1100', '1101', '1110', '1111'  }

-- turn pixel colors back into hex letters,  notice 2bit values use 40's
local bitTabl4  = {    [0]  = '0',  [240]  = '1',  [140]  = '2',   [40]  = '3',

                      [60]  = '4',   [75]  = '5',   [90]  = '6',  [105]  = '7',
                     [120]  = '8',  [135]  = '9',  [150]  = 'A',  [165]  = 'B',
                     [180]  = 'C',  [195]  = 'D',  [210]  = 'E',  [255]  = 'F'  }

-- generate colored hex letters
local hexcolor  = {  ['0000']  = { {  0,  0,  0, 140},  '0' },  ['0001']  = { {240,240,240, 140},  '1' },
                     ['0010']  = { {140,140,140, 140},  '2' },  ['0011']  = { { 40, 40, 40, 140},  '3' },

                     ['0100']  = { { 60, 60, 60},       '4' },  ['0101']  = { { 75, 75, 75},       '5' },
                     ['0110']  = { { 90, 90, 90},       '6' },  ['0111']  = { {105,105,105},       '7' },
                     ['1000']  = { {120,120,120},       '8' },  ['1001']  = { {135,135,135},       '9' },
                     ['1010']  = { {150,150,150},       'A' },  ['1011']  = { {165,165,165},       'B' },
                     ['1100']  = { {180,180,180},       'C' },  ['1101']  = { {195,195,195},       'D' },
                     ['1110']  = { {210,210,210},       'E' },  ['1111']  = { {255,255,255},       'F' }  }

-- hex letters for palette.  it begins counting from 1
local hexpal  = {  [1] = '0',   [2] = '1',   [3] = '2',   [4] = '3',
                   [5] = '4',   [6] = '5',   [7] = '6',   [8] = '7',
                   [9] = '8',  [10] = '9',  [11] = 'A',  [12] = 'B',
                  [13] = 'C',  [14] = 'D',  [15] = 'E',  [16] = 'F'  }

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function alpha( this )

  if this == 0 then -- if {0,0,0} then alpha is also 0  (transparent background)
    a  = { 0, 0, 0,  0 }

-- 2 bit values use 40's,  so 0001  0010  0011
  elseif this == 240 or this == 140 or this == 40 then
    a  = { this, this, this,  140 } -- if only using two bits,  then tint
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
    local rawBytes  = data :read(1) -- read a byte at a time
    if not rawBytes then  break  end -- stop if we've reached the end

    bytes[ #bytes +1 ]  = string .format( '%02X',  string .byte( rawBytes )) -- '1111 0000' to 'F0'
  end -- while true

 -- divide screenheight by nibbles to get approx step value for scroll slider
  slider  = HH /( #bytes *2 )

  -- convert to binary
  for i = 1,  #bytes do  -- "FF"

    if i < header then   -- skip header,  if necessary.
      head[ #head +1 ]  = bytes[i] -- keep data so we can write it back later
    else
      for b = 1,  2 do -- split bytes into nibbles  'FF'  to  'F' and 'F'

        local this  = string .sub( bytes[i],  b,  b )
        nib[ #nib +1 ]  = hex2bin[ this ] -- 'F'  to  '1111'

      end --  for s  = 1,  2
    end -- if i < header
  end -- for i = 1,  #bytes

  for i = 1,  #nib do -- determine alpha value for pixel,  and colored hex letter
    pixel[#pixel +1]  = alpha(  coTabl[ nib[i] ]  )

    hexlet[#hexlet +1]  = bin2hex[ nib[i] ]
  end -- for i = 1,  #nib
end -- readData()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function writeData()
  print('Writing to newfont.dat')
  local out  = io .open('newfont.dat', 'wb')

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

    local max  = #nib -rows *tileY *cols *tileX -- max value
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

    if offset < 0 then                 -- min value
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
      elseif paint > colors then                 -- max
        paint  = colors
      end -- if paint

    elseif cursorY > HH -100 then
      gra .setBackgroundColor( 0,  50,  100 )
      bgCount  = 30  -- dim screen for a moment
      writeData()
    end -- if cursorY

  -- clicked within pixel grid?
  elseif cursorX > minX and cursorX < maxW and cursorY > minY and cursorY < maxH then
    cursorCol  = math .ceil( (cursorX -minX) /gap )
    cursorRow  = math .floor( (cursorY -minY) /gap )
    cursor  = 1

    if cursorCol < 1 then                 -- min value Col
      cursorCol  = 1
    elseif cursorCol > cols *tileX then   -- max
      cursorCol  = cols *tileX
    end -- cursorCol

    if cursorRow < 0 then                 -- min value Row
      cursorRow  = 0
    elseif cursorRow > cols *tileY then   -- max
      cursorRow  = cols *tileY
    end -- cursorRow

  end -- if cursorX
end -- mouseStuff()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function paintPixel()
  if cursor == 1 then
    local pixelX  = cursorCol %tileX  -- pixel's X pos within tile
    if pixelX == 0 then
      pixelX  = tileX                 -- if mod = 0,  we want to end up in right column
    end

    local pixelY  = cursorRow %tileY  -- pixel's Y pos within tile

    local tileCol  = math .floor( (cursorCol -1) /tileX ) -- column of tile on screen-grid
    local tileRow  = math .floor( cursorRow /tileY )     -- row

    local oneTile  = pixelX +tileX *pixelY       -- localize all clicks to one tile
                                                 -- then multiply by grid placement

                                                 -- 8x8  = 64 *2  = 128   every grid pos takes up...
    local xx  = tileCol *128                     -- 128 pixels to jump to the next horiz pos
    local yy  = tileRow *128 *cols               -- 128x11 tiles per column  = 1024 pixels to go down a row

    loc  = oneTile +xx +yy +offset               -- current pixel position within the data

    if key .isDown( 'lctrl' ) or key .isDown( 'rctrl' ) then
      table .insert(  pixel,  loc,  {235, 175, 135}  ) -- insert padding
      table .insert(  hexlet,  loc, '')
    else
      if hexlet[ loc ] ~= '' then -- only paint in pixels that aren't padding

        local digits  = four[ paint ] -- get binary digits for current color,  '1' to '0001'

        local rgb  = coTabl[ digits ] -- get RGB value
        local rgba = alpha( rgb ) -- determine alpha transparency

        pixel[ loc ]  = rgba  -- paint with current color
        hexlet[ loc ]  = hexpal[ paint ] -- write in new hex letter

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
      table .remove( hexlet, loc )
      ki  = 0
    end -- if pixel[ loc ][1] ~= pixel[ loc ][2]

  end -- if key .isDown()


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

    if cursorCol < tileX *cols then
      cursorCol  = cursorCol +1
      paintPixel()
    end -- if cursorCol

    if cursorRow < tileY *rows -1 then
        cursorRow  = cursorRow +1
        paintPixel()
    end -- if cursorRow

    if cursorCol > 1 and cursorCol < tileX *cols then
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
      for y  = 0,  tileY -1  do
        for x  = 0,  tileX -1  do
          local item  = i +offset

          local xx  = c *tileWidth +minX -- tile column
          local yy  = r *tileHeight +minY -- row

          local xpos  = x *gap  +xx -- pixel pos within tile column  +xx
          local ypos  = y *gap  +yy                       -- row  +yy

          if hexlet[item] ~= '0' then -- skip printing blank pixels
            gra .setColor( pixel[ item ] )

            -- draw pixel    style,  x,     y,     width,      height
            gra .rectangle( 'fill',  xpos,  ypos,  pixelSize,  pixelSize )
          end -- if hexlet[item] ~= '0'

          gra .setColor( 0, 0, 0 )
          gra .print( hexlet[item],  xpos +1,  ypos -1 )
          i  = i +1
        end -- tileX
      end -- tileY
    end -- cols
  end -- rows

  -- vert grid divisions
  gra .setColor( 220,  220,  220,  150 )
  for i = 1,  cols -1 do
    local xx  = i *tileX *gap +minX
    local yy  = rows *tileY *gap +minY
    gra .line( xx,  minY,  xx,  yy )
  end -- for cols

  -- horiz grid divisions
  for i = 1,  rows -1 do
    local xx  = cols *tileX *gap +minX
    local yy  = i *tileY *gap +minY
    gra .line( minX,  yy,  xx,  yy )
  end -- for rows

  -- outline the pixel(s) you just painted
  gra .setColor( 220,  20,  20,  200 )
  if cursor > 0 then -- skip during palette select
    local xx  = cursorCol *gap +8
    local yy  = cursorRow *gap
    if size == 1 then                         -- draw rect around 1 pixel
      gra .rectangle( 'line',  xx,  yy +minY -1,  littleG,  littleG )
    else                                      -- draw rect around 4 pixels
      gra .rectangle( 'line',  xx,  yy -2,  bigG,  bigG )
    end -- if size
  end -- if cursor > 0

  -- outline palette area
  gra .setColor( 220,  220,  220,  50 )
  gra .rectangle( 'line',  WW -70,  50,  40,  410 )

  -- draw in color swatches
  gra .setPointSize( 20 )

  for i = 1,  colors  do

    ki  = four[i] -- look up color key
    local rgba  = alpha(  coTabl[ ki ]  )
    gra .setColor( rgba )

    local xpos  = WW -50
    local ypos  = i *24 +50

    gra .points( xpos,  ypos ) -- draw swatch

    gra .setColor( 0, 0, 0 )
    gra .print( hexpal[ i ],  xpos -5,  ypos -5 )
  end -- for i

  -- slider dot on right side of screen
  gra .setColor( 220,  220,  220,  50 )
  gra .points( WW -10,  offset *slider +20 )

  -- highlight selected color
  gra .setColor( 220,  20,  20,  200 )
  gra .rectangle( 'line',  WW -60,  paint *24 +38,  22,  22 )

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

