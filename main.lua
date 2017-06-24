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
tou  = LO .touch     --
vid  = LO .video     --
win  = LO .window       --  enabled

-- look in conf.lua to enable necessary modules

HH  = gra .getHeight()
WW  = gra .getWidth()

-- copy font.dat  font8.dat  SYSTEM.DAT  into theSegSat dir

--     Love2D defaults to sandboxing apps for security.
--     There's a trick to open files outside of that dir,
--     but it involves installing luafilesystem

-- The fonts default to read-only, because they came from a CD-ROM
-- which is fine for now, 'cuz this app is just a viewer so far,
-- but eventually,  you'll want to set 'em so you can write changes

--     sudo chmod +w fon*.dat

local filename  = 'SYSTEM.DAT'
local BPP  = 4          -- font  = 4,  font8  = 2,  press BPP display to toggle,
                        -- will lose changes you've painted to file tho,  'cuz it reloads data.

local nib  = {}           -- 4 bits in each index location
local bytes  = {}         -- pairs of nibbles
local pixel  = {}         -- RGBA values for each pixel

local pixelSize  = 11
local gap  = pixelSize +1

local tileWidth  = 8    -- "pixels" per tile
local tileHeight  = 16

local cols  = 11        -- how many tiles are onscreen at once
local rows  = 4

local fontsize  = 18
local font  = gra .newFont( fontsize )

local cursorX  = 0      -- actual screen location of mouse
local cursorY  = 0

local cursorCol  = 1    -- position within the grid-of-pixels that's been clicked on
local cursorRow  = 0

local paint  = 4        -- current color selected to paint with
local header  = 0       -- skip data before 88000,  if needed...
local head  = {}        -- storage for that junk 'till it's flushed out later

local till  = 4         -- iterate 'till this many colors.   calculated during LO .load()
local slider  = 0       -- distance slider travels while scrolling.   ^ ditto

local click  = 0        -- disables click repeat,  when you toggle BPP
local cursor  = 1       -- display cursor position?

local offset  = 0       -- scroll location
local loc  = 0          -- pixel location
local size  = 1         -- size of paintbrush
local bgCount  = 0      -- background counter,  to flash color after written

local maxW  = cols *tileWidth *gap +21   -- boundaries of clickable grid area
local maxH  = rows *tileHeight *gap +11

-- hexadecimal to binary-equivalent chart.
local hex2bin  = {  ['0'] = '0000',  ['1'] = '0001',  ['2'] = '0010',  ['3'] = '0011',
                    ['4'] = '0100',  ['5'] = '0101',  ['6'] = '0110',  ['7'] = '0111',
                    ['8'] = '1000',  ['9'] = '1001',  ['A'] = '1010',  ['B'] = '1011',
                    ['C'] = '1100',  ['D'] = '1101',  ['E'] = '1110',  ['F'] = '1111'  }


local bin2hex  = {  ['0000'] = '0',  ['0001'] = '1',  ['0010'] = '2',  ['0011'] = '3',
                    ['0100'] = '4',  ['0101'] = '5',  ['0110'] = '6',  ['0111'] = '7',
                    ['1000'] = '8',  ['1001'] = '9',  ['1010'] = 'A',  ['1011'] = 'B',
                    ['1100'] = 'C',  ['1101'] = 'D',  ['1110'] = 'E',  ['1111'] = 'F'  }

-- colorTable for RGBA values.  includes 2bit,  3bit,  4bit  and 5bit values.
local coTabl  = {  ['00']  = 0,  ['01']  = 50,  ['10']  = 150,  ['11']  = 255,

                   ['000']  = 0,    ['001']  = 30,   ['010']  = 60,   ['011']  = 90,
                   ['100']  = 120,  ['101']  = 150,  ['110']  = 180,  ['111']  = 255,

                   ['0000']  = 0,    ['0001']  = 15,   ['0010']  = 30,   ['0011']  = 45,
                   ['0100']  = 60,   ['0101']  = 75,   ['0110']  = 90,   ['0111']  = 105,
                   ['1000']  = 120,  ['1001']  = 135,  ['1010']  = 150,  ['1011']  = 165,
                   ['1100']  = 180,  ['1101']  = 195,  ['1110']  = 210,  ['1111']  = 255,

                   ['00000']  = 0,    ['00001']  = 8,    ['00010']  = 24,   ['00011']  = 32,
                   ['00100']  = 40,   ['00101']  = 48,   ['00110']  = 56,   ['00111']  = 64,
                   ['01000']  = 72,   ['01001']  = 80,   ['01010']  = 88,   ['01011']  = 96,
                   ['01100']  = 104,  ['01101']  = 112,  ['01110']  = 120,  ['01111']  = 128,
                   ['10000']  = 135,  ['10001']  = 143,  ['10010']  = 151,  ['10011']  = 160,
                   ['10100']  = 167,  ['10101']  = 175,  ['10110']  = 183,  ['10111']  = 191,
                   ['11000']  = 200,  ['11001']  = 207,  ['11010']  = 215,  ['11011']  = 223,
                   ['11100']  = 231,  ['11101']  = 240,  ['11110']  = 247,  ['11111']  = 255  }

 -- "index to key" lookups, 'cuz key-value pairs are unordered in Lua
local ki  = 0    -- reverse entries?

local two    = { '11',  '10',  '01',  '00' }

local three  = { '111',  '110',  '101',  '100',  '011',  '010',  '001',  '000'   }

local four   = { '1111', '1110', '1101', '1100', '1011', '1010', '1001', '1000',
                 '0111', '0110', '0101', '0100', '0011', '0010', '0001', '0000'  }

local bitTabl2  = {  [0]  = '00',  [50]  = '01',  [150]  = '10',  [255]  = '11'  }

local bitTabl4  = {    [0]  = '0',   [15]  = '1',   [30]  = '2',   [45]  = '3',
                      [60]  = '4',   [75]  = '5',   [90]  = '6',  [105]  = '7',
                     [120]  = '8',  [135]  = '9',  [150]  = 'A',  [165]  = 'B',
                     [180]  = 'C',  [195]  = 'D',  [210]  = 'E',  [255]  = 'F'  }

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function alpha( r, g, b ) -- if {0,0,0} then alpha is also 0
  a  = { r, g, b }

  if r == 0 and g == 0 and b == 0 then
    a  = { 255, 255, 255,  0 }
  end -- if r...

    return a
end -- function alpha()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function readData()
  if #nib > 0 then -- clear tables
    local count  = #bits
    for i = 1,  count do  bits[i]  = nil end

    count  = #bytes
    for i = 1,  count do  bytes[i]  = nil end

    count  = #pixel
    for i = 1,  count do  pixel[i]  = nil end
  end -- if #bits

  if BPP == 2 then
    till  = 4   -- amount of colors available
    paint  = 4   -- select last color
  else
    till  = 16
    paint  = 16
  end -- if BPP

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
  for i = 1,  #bytes do  -- "FF"                skip header,  if necessary,

    if i < header then
      head[ #head +1 ]  = bytes[i]
    else
      for s = 1,  2 do   --- split nibbles  'FF'  to  'F' and 'F'
        local this  = string .sub( bytes[i],  s,  s )

        if BPP  == 2 then -- reverse twopence,  little endian

          local hex  = hex2bin[ this ]      -- 'C'  to  '1100'

          local high  = string .sub( hex,  1,  2 )   -- '11'
          local low  = string .sub( hex,  3,  4 )    --   '00'

          nib[ #nib +1 ]  = low ..high               -- '0011'

        else -- BPP == 4

          nib[ #nib +1 ]  = hex2bin[ this ] -- 'F'  to  '1111'

        end -- if BPP
      end --  for s  = 1,  2
    end -- if i < header
  end -- for i = 1,  #bytes

  for i = 1,  #nib do
    pixel[#pixel +1]  = alpha(  coTabl[ nib[i] ],  coTabl[ nib[i] ],  coTabl[ nib[i] ]  )
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

  for i = 1,  #pixel,  2 do -- generate export list
    if pixel[i][1] == pixel[i][2] then -- it's not a grey pixel,  so skip padding

      if BPP == 2 then -- use bit table 2
        bytes[#bytes +1]  = bitTabl2[ pixel[i][1] ] ..bitTabl2[ pixel[i +1][1] ]
      else          -- use bit table 4
        bytes[#bytes +1]  = bitTabl4[ pixel[i][1] ] ..bitTabl4[ pixel[i +1][1] ]
      end

    end -- if pixel[i]
  end -- for i = 1,  #pixel

  if BPP == 2 then
    for i = 1,  #bytes,  2 do -- join two reversed twopence  '0011  1100'

      local high  = string .sub( bytes[i],  1,  2 )       -- '00'
      local low  = string .sub( bytes[i],  3,  4 )        --   '11'

      local bin  = low ..high                             -- '1100'
      local nibble1  = bin2hex[ bin ]                     -- 'C'

      local high  = string .sub( bytes[i +1],  1,  2 )          -- '11'
      local low  = string .sub( bytes[i +1],  3,  4 )           --   '00'

      local bin  = low ..high                                   -- '0011'
      local nibble2  = bin2hex[ bin ]                           -- '3'

      local byte  = nibble1 ..nibble2           -- 'C3'
      local num  = tonumber( byte,  16 )       -- 195
      str  = str ..string .char( num )        -- ASCII  U+0195
    end -- for i = 1,  #bytes

  else -- BPP == 4
    for i = 1,  #bytes do
      local num  = tonumber( bytes[i],  16 )  -- 'F0'  to  240
      str  = str ..string .char( num )       -- ASCII  U+0240
    end -- for i = 1,  #bytes
  end

  out :write( str )
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

    if cursorY < 40 then -- toggle BPP's
      if click == 0 then -- only do this once,  no repeat
        if BPP == 2 then  BPP  = 4
        else  BPP  = 2
        end -- BPP
        readData() -- refresh with new BPP value
        click  = 1
      end -- if click

    elseif cursorY < 450 then -- clicked within palette
      paint  = math .floor((cursorY -38) /24)    -- determine paint color
      if paint < 1 then                          -- min value
        paint  = 1
      elseif paint > till then                   -- max
        paint  = till
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

    local digits  = two[ paint ]                 -- lookup binary equivalent
    if BPP == 4 then
      digits  = four[ paint ]
    end -- if BPP

    if key .isDown( 'delete' ) then -- delete
      pixel[ loc ]  = nil
      ki  = 0
    elseif key .isDown( 'lctrl' ) or key .isDown( 'rctrl' ) then
      table .insert(  pixel,  loc,  {235, 175, 135}  )
    else
      pixel[ loc ]  = alpha(  coTabl[ digits ],  coTabl[ digits ],  coTabl[ digits ]  )
    end -- if key .isDown( 'shift' )
  end -- if cursor
end -- paintPixel()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function LO .update(dt)
  -- easy exit
  if key .isDown( 'escape' ) then
    eve .push( 'quit' )
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
  -- draw BPP label
  if mou .getX() > WW -70 and mou .getX() < WW -30 and mou .getY() < 40 then
    gra .setColor( 220,  50,  50,  250 )
  else
    gra .setColor( 220,  220,  220,  250 )
  end
  gra .print( 'BPP: ' ..BPP,  WW -70,  15 )

  -- draw pixel-grid
  gra .setPointSize( 5 )

  if #nib > 0 then -- don't draw during data swaps
    i  = 1
    for r  = 0,  rows -1  do
      for c  = 0,  cols -1  do
        for y  = 1,  tileHeight  do
          for x  = 1,  tileWidth  do
            ki  = i +offset
            gra .setColor( pixel[ ki ] )

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
    if BPP == 2 then
      gra .rectangle( 'line',  WW -70,  50,  40,  120 )
    else
      gra .rectangle( 'line',  WW -70,  50,  40,  410 )
    end

    -- draw in color swatches
    gra .setPointSize( 20 )

    for i = 1,  till  do

      if BPP == 2 then -- convert index to key
        ki  = two[i]
      else
        ki  = four[i]
      end

      local R  = coTabl[ ki ]
      local G  = coTabl[ ki ]
      local B  = coTabl[ ki ]
      local rgba  = alpha( R,  G,  B )

      gra .setColor( rgba )

      gra .points( WW -50,  i *24 +50 )
    end -- for i

  end -- if #nib  a.k.a.  don't draw during data swaps

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

