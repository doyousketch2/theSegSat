# theSegSat
Love2D Sega Saturn font viewer  
Install Love2D  https://love2d.org

Screensize is set in the conf.lua file:  

>It's 1200x800 'cuz it shows up OK on my 1280x1024 monitor.  

Copy **font.dat** and **font8.dat** into **theSegSat** dir.  
*I could do that here, but I don't think you can include the font in a GPL license...*  
  
    There's a trick to open files outside of that dir,  
    but it involves installing luafilesystem...  meh.  
    This is easier.  

Open in Love2D:  

Linux, while inside theSegSat dir:  
>love .

Win, Mac:  
>Drag **theSegSat** folder onto your Love2D shortcut  

For more info:  https://love2d.org/wiki/Getting_Started

---

Right-click to paint 4 pixels at a time.  Good for erasing.  

Click the BPP display to toggle between 2bit and 4 bit.  
Reloads data, so any changes you have painted will revert.  

Save is almost functional.  It saves, but cuts off halfway through.  
If your terminal has a decent scrollback,  you can test it yourself.  
`diff -y <(xxd font8.dat) <(xxd newfont.dat) | colordiff`
