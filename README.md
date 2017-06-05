# theSegSat
Love2D Sega Saturn font viewer  
Install Love2D  https://love2d.org

Screensize is set in the conf.lua file:  

    It's 1200x900 'cuz that shows up OK on my 1280x1024 monitor.  

    If I'm on the laptop screen, I set it to 1200x700  
    'cuz that does better on 1440x768  

Copy font.dat and font8.dat into theSegSat dir.  
I could do that here, but I don't think you can include the font in a GPL license...  
  
    There's a trick to open files outside of that dir,  
    but it involves installing luafilesystem...  meh.  
    This way is easier.  

Open in Love2D:  

Linux, while inside theSegSat dir:  
>love .

Win:  
>Zip the folder and rename it **theSegSat.love**  
>Open Love2D, then drag that file onto the window  

---
*It crashes if you scroll too far...*

Not a biggie.  It's supposed to keep that from happening,  
but Lua starts counting from 1 instead of 0  
so I prolly have to subtract 1 from the rows and cols.
