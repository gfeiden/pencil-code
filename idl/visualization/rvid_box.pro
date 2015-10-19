;
;  $Id$
;
;  Reads in 4 slices as they are generated by the pencil code.
;  The variable "field" can be changed. Default is 'lnrho'.
;
;  If the keyword /mpeg is given, the file movie.mpg is written.
;  tmin is the time after which data are written
;  nrepeat is the number of repeated images (to slow down movie)
;  An alternative is to set the /png_truecolor flag and postprocess the
;  PNG images with ${PENCIL_HOME}/utils/makemovie (requires imagemagick
;  and mencoder to be installed).
;
;  Typical calling sequence
;    rvid_box, 'bz', tmin=190, tmax=200, min=-.35, max=.35, /mpeg
;    rvid_box, 'ss', max=6.7, fo='(1e9.3)'
;
;  For 'gyroscope' look:
;    rvid_box, 'oz', tmin=-1, tmax=1001, /shell, /centred, r_int=0.5, r_ext=1.0
;
;  For centred slices, but without masking outside shell
;    rvid_box, 'oz', tmin=-1, tmax=1010, /shell, /centred, r_int=0.0, r_ext=5.0
;
;  For slice position m
;    rvid_box, field, tmin=0, min=-amax, max=amax, /centred, /shell, $
;       r_int=0., r_ext=8., /z_topbot_swap
;
;  For masking of shell, but leaving projections on edges of box
;    rvid_box, 'oz', tmin=-1, tmax=1001, /shell, r_int=0.5, r_ext=1.0
;
;  If using /centred, the optional keywords /z_bot_twice and /z_top_twice
;  plot the bottom or top xy-planes (i.e. xy and xy2, respectively) twice.
;  (Once in the centred position, once at the bottom of the plot; cf. the
;  default, which plots the top slice in the centred position.)
;  (This can be useful for clarifying hidden features in gyroscope plots.)
;
pro rvid_box, field, $
  mpeg=mpeg, png=png, truepng=png_truecolor, tmin=tmin, tmax=tmax, $
  max=amax,min=amin, noborder=noborder, imgprefix=imgprefix, imgdir=imgdir, $
  dev=dev, nrepeat=nrepeat, wait=wait, stride=stride, datadir=datatopdir, $
  noplot=noplot, fo=fo, swapz=swapz, xsize=xsize, ysize=ysize, $
  title=title, itpng=itpng, global_scaling=global_scaling, proc=proc, $
  exponential=exponential, sqroot=sqroot, logarithmic=logarithmic, $
  shell=shell, centred=centred, r_int=r_int, r_ext=r_ext, colmpeg=colmpeg, $
  z_bot_twice=z_bot_twice, z_top_twice=z_top_twice, $
  z_topbot_swap=z_topbot_swap, xrot=xrot, zrot=zrot, zof=zof, $
  magnify=magnify, ymagnify=ymagnify, zmagnify=zmagnify, xpos=xpos, zpos=zpos, $
  xmax=xmax, ymax=ymax, sample=sample, $
  xlabel=xlabel, ylabel=ylabel, tlabel=tlabel, label=label, $
  size_label=size_label, $
  monotonous_scaling=monotonous_scaling, symmetric_scaling=symmetric_scaling, $
  automatic_scaling=automatic_scaling,roundup=roundup, $
  nobottom=nobottom, oversaturate=oversaturate, cylinder=cylinder, $
  tunit=tunit, qswap=qswap, bar=bar, nolabel=nolabel, norm=norm, $
  divbar=divbar, blabel=blabel, bsize=bsize, bformat=bformat, thlabel=thlabel, $
  bnorm=bnorm, swap_endian=swap_endian, newwindow=newwindow, $
  quiet_skip=quiet_skip, axes=axes, ct=ct, neg=neg, scale=scale, $
  colorbarpos=colorbarpos
;
common pc_precision, zero, one, precision, data_type, data_bytes, type_idl
;
default,amax,0.05
default,amin,-amax
default,field,'lnrho'
default,dimfile,'dim.dat'
default,varfile,'var.dat'
default,nrepeat,0
default,stride,0
default,tmin,0.0
default,tmax,1e38
default,wait,0.0
default,fo,"(f6.1)"
default,xsize,512
default,ysize,448
default,title,''
default,itpng,0 ;(image counter)
default,noborder,[0,0,0,0,0,0]
default,r_int,0.5
default,r_ext,1.0
default,imgprefix,'img_'
default,imgdir,'.'
default,dev,'x'
default,magnify,1.0
default,ymagnify,1.0
default,zmagnify,1.0
default,xpos,0.0
default,zpos,0.34
default,xrot,30.0
default,zrot,30.0
default,zof,0.7
default,xmax,1.0
default,ymax,1.0
default,xlabel,0.08
default,ylabel,1.18
default,tlabel,'!8t'
default,label,''
default,size_label,1.4
default,thlabel,1.0
default,nobottom,0.0
default,monotonous_scaling,0.0
default,oversaturate,1.0
default,tunit,1.0
default,scale,1.0
default,colorbarpos,[.80,.15,.82,.85]
default,norm,1.0
default,swap_endian,0
default,quiet_skip,1
;
if (keyword_set(png_truecolor)) then png=1
;
; if png's are requested don't open a window
;
if (not keyword_set(png)) then begin
  if (keyword_set(newwindow)) then begin
    window, /free, xsize=xsize, ysize=ysize, title=title
 endif
endif
;
first_print = 1
;
; Construct location of slice_var.plane files
;
if (not keyword_set(datatopdir)) then datatopdir=pc_get_datadir()
datadir=datatopdir
;
;  by default, look in data/, assuming we have run read_videofiles.x before:
;
if (n_elements(proc) le 0) then begin
  pc_read_dim, obj=dim, datadir=datatopdir,/quiet
  if (dim.nprocx*dim.nprocy*dim.nprocz eq 1) then datadir=datatopdir+'/proc0'
endif else begin
  datadir=datatopdir+'/'+proc
endelse
;
;  Swap z slices?
;
if (keyword_set(swapz)) then begin
  file_slice1=datadir+'/slice_'+field+'.xy'
  file_slice2=datadir+'/slice_'+field+'.xy2'
endif else begin
  file_slice1=datadir+'/slice_'+field+'.xy2'
  file_slice2=datadir+'/slice_'+field+'.xy'
endelse
file_slice3=datadir+'/slice_'+field+'.xz'
file_slice4=datadir+'/slice_'+field+'.yz'
;
;  Read the dimensions from dim.dat
;
pc_read_dim, obj=dim, datadir=datadir, /quiet
;
mx=dim.mx
my=dim.my
mz=dim.mz
nx=dim.nx
ny=dim.ny
nz=dim.nz
nghostx=dim.nghostx
nghosty=dim.nghosty
nghostz=dim.nghostz
ncpus = dim.nprocx*dim.nprocy*dim.nprocz
;
;  Consider non-equidistant grid
;
pc_read_param, obj=par, dim=dim, datadir=datatodir, /quiet
if not all(par.lequidist) then begin
  massage = 1
  pc_read_grid, obj=grid, dim=dim, datadir=datadir, /trim, /quiet
  iix=spline(grid.x,findgen(nx),par.xyz0[0]+(findgen(nx)+.5)*(par.lxyz[0] / nx))
  iiy=spline(grid.y,findgen(ny),par.xyz0[1]+(findgen(ny)+.5)*(par.lxyz[1] / ny))
  iiz=spline(grid.z,findgen(nz),par.xyz0[2]+(findgen(nz)+.5)*(par.lxyz[2] / nz))
endif else massage = 0
;
if (keyword_set(shell)) then begin
;
;  Need full grid to mask outside shell.
;
  pc_read_grid, obj=grid, dim=dim, datadir=datadir, /quiet
  x=grid.x
  y=grid.y
  z=grid.z
;
  xx = spread(x, [1,2], [my,mz])
  yy = spread(y, [0,2], [mx,mz])
  zz = spread(z, [0,1], [mx,my])
;
  if (keyword_set(cylinder)) then begin
    rr = sqrt(xx^2+yy^2)
  endif else begin
    rr = sqrt(xx^2+yy^2+zz^2)
  endelse
;
; assume slices are all central for now -- perhaps generalize later
; nb: need pass these into boxbotex_scl for use after scaling of image;
;     otherwise pixelisation can be severe...
; nb: at present using the same z-value for both horizontal slices.
  ix=mx/2
  iy=my/2
  iz=mz/2
  rrxy =rr(nghostx:mx-nghostx-1,nghosty:my-nghosty-1,iz)
  rrxy2=rr(nghostx:mx-nghostx-1,nghosty:my-nghosty-1,iz)
  rrxz =rr(nghostx:mx-nghostx-1,iy,nghostz:mz-nghostz-1)
  rryz =rr(ix,nghosty:my-nghosty-1,nghostz:mz-nghostz-1)
;
endif
;
t=zero
xy2=fltarr(nx,ny)*one
xy=fltarr(nx,ny)*one
xz=fltarr(nx,nz)*one
yz=fltarr(ny,nz)*one
slice_xpos=zero
slice_ypos=zero
slice_zpos=zero
slice_z2pos=zero
;
;  Open MPEG file, if keyword is set.
;
if (keyword_set(png)) then begin
  set_plot, 'z'                        ; switch to Z buffer
  device, set_resolution=[xsize,ysize] ; set window size
  dev='z'
endif else if (keyword_set(mpeg)) then begin
  if (!d.name eq 'X') then wdwset, 2, xs=xsize, ys=ysize
  mpeg_name = 'movie.mpg'
  print, 'write mpeg movie: ', mpeg_name
  mpegID = mpeg_open([xsize,ysize], filename=mpeg_name)
  itmpeg=0 ;(image counter)
endif else begin
  if (!d.name eq 'X') then wdwset,xs=xsize,ys=ysize
endelse
;
;  set color table (if keyword set)
;
if (keyword_set(ct)) then loadct,ct
;
;  Go through all video snapshots and find global min and max.
;
if (keyword_set(global_scaling)) then begin
;
  first=1L
;
  openr, lun_1, file_slice1, /f77, /get_lun, swap_endian=swap_endian
  openr, lun_2, file_slice2, /f77, /get_lun, swap_endian=swap_endian
  openr, lun_3, file_slice3, /f77, /get_lun, swap_endian=swap_endian
  openr, lun_4, file_slice4, /f77, /get_lun, swap_endian=swap_endian
;
  while (not eof(lun)) do begin
;
    readu, lun_1, xy2, t, slice_z2pos
    readu, lun_2, xy, t, slice_zpos
    readu, lun_3, xz, t, slice_ypos
    readu, lun_4, yz, t, slice_xpos
;
    if (first) then begin
      amax=max([max(xy2),max(xy),max(xz),max(yz)])
      amin=min([min(xy2),min(xy),min(xz),min(yz)])
      first=0L
    endif else begin
      amax=max([amax,max(xy2),max(xy),max(xz),max(yz)])
      amin=min([amin,min(xy2),min(xy),min(xz),min(yz)])
    endelse
;
  endwhile
;
  close, lun_1
  close, lun_2
  close, lun_3
  close, lun_4
  free_lun, lun_1
  free_lun, lun_2
  free_lun, lun_3
  free_lun, lun_4
;
  print,'Scale using global min, max: ', amin, amax
;
endif
;
;  Redefine min and max according to mathematical operation.
;
if (keyword_set(sqroot)) then begin
  amin=sqrt(amin)
  amax=sqrt(amax)
endif
;
if (keyword_set(exponential)) then begin
  amin=exp(amin)
  amax=exp(amax)
endif
;
if (keyword_set(logarithmic)) then begin
  amin=alog(amin)
  amax=alog(amax)
endif
;
;  Open slice files for reading.
;
openr, lun_1, file_slice1, /f77, /get_lun, swap_endian=swap_endian
openr, lun_2, file_slice2, /f77, /get_lun, swap_endian=swap_endian
openr, lun_3, file_slice3, /f77, /get_lun, swap_endian=swap_endian
openr, lun_4, file_slice4, /f77, /get_lun, swap_endian=swap_endian
;
islice=0L
;
while ((not eof(lun)) and (t le tmax)) do begin
;
  if ((t ge tmin) and (t le tmax) and (islice mod (stride+1) eq 0)) then begin
    readu, lun_1, xy2, t, slice_z2pos
    readu, lun_2, xy, t, slice_zpos
    readu, lun_3, xz, t, slice_ypos
    readu, lun_4, yz, t, slice_xpos
;
    if (keyword_set(neg)) then begin
      xy2=-xy2
      xy=-xy
      xz=-xz
      yz=-yz
    endif
;
    if massage then begin
      xy  = interpolate(xy,  iix, iiy, /grid)
      xy2 = interpolate(xy2, iix, iiy, /grid)
      xz  = interpolate(xz,  iix, iiz, /grid)
      yz  = interpolate(yz,  iiy, iiz, /grid)
    endif
  endif else begin
    ; Read only time.
    dummy=zero
    readu, lun_1, xy2, t
    readu, lun_2, dummy
    readu, lun_3, dummy
    readu, lun_4, dummy
  endelse
;
;  Possible to set time interval and to skip over "stride" slices.
;
  if ( (t ge tmin) and (t le tmax) and (islice mod (stride+1) eq 0) ) then begin
;
;  Perform preset mathematical operation on data before plotting.
;
    if (keyword_set(sqroot)) then begin
      xy2=sqrt(xy2)
      xy=sqrt(xy)
      xz=sqrt(xz)
      yz=sqrt(yz)
    endif
;
    if (keyword_set(exponential)) then begin
      xy2=exp(xy2)
      xy=exp(xy)
      xz=exp(xz)
      yz=exp(yz)
    endif
;
    if (keyword_set(logarithmic)) then begin
      xy2=alog(xy2)
      xy=alog(xy)
      xz=alog(xz)
      yz=alog(yz)
    endif
;
;  If monotonous scaling is set, increase the range if necessary.
;
    if (keyword_set(monotonous_scaling)) then begin
      amax1=max([amax,max(xy2),max(xy),max(xz),max(yz)])
      amin1=min([amin,min(xy2),min(xy),min(xz),min(yz)])
      amax=(4.*amax+amax1)/5.
      amin=(4.*amin+amin1)/5.
    endif else if(keyword_set(automatic_scaling)) then begin
      amax=max([max(xy2),max(xy),max(xz),max(yz)])
      amin=min([min(xy2),min(xy),min(xz),min(yz)])
    endif
;
;  Symmetric scaling about zero.
;
    if (keyword_set(symmetric_scaling)) then begin
      amax=amax>abs(amin)
      amin=-amax
    endif
;
;  possibility of rounding up the amax and amin value
;
    if (keyword_set(roundup)) then begin
      amax=pc_round(amax)
      amin=pc_round(amin)
    endif
;
;  If noborder is set.
;
    s=size(xy)
    l1=noborder(0)
    l2=s[1]-1-noborder(1)
    s=size(yz)
    m1=noborder(2)
    m2=s[1]-1-noborder(3)
    n1=noborder(4)
    n2=s[2]-1-noborder(5)
;
;  Possibility of swapping xy2 and xy (here if qswap is set).
;
    if (keyword_set(qswap)) then begin
      xy2s=rotate(xy(l1:l2,m1:m2),2)
      xys=rotate(xy2(l1:l2,m1:m2),2)
      xzs=rotate(xz(l1:l2,n1:n2),5)
      yzs=rotate(yz(m1:m2,n1:n2),5)
    endif else begin
      xy2s=xy2(l1:l2,m1:m2)
      xys=xy(l1:l2,m1:m2)
      xzs=xz(l1:l2,n1:n2)
      yzs=yz(m1:m2,n1:n2)
    endelse
;
;  Possible to output min and max without plotting.
;
    if (keyword_set(noplot)) then begin
      if (first_print) then $
          print, '   islice        t           min          max'
      first_print=0
      print, islice, t, $
          min([min(xy2),min(xy),min(xz),min(yz)]), $
          max([max(xy2),max(xy),max(xz),max(yz)]), format='(i9,e12.4,2f13.7)'
    endif else begin
;
;  Plot normal box.
;
      if (not keyword_set(shell)) then begin
        boxbotex_scl,xy2s,xys,xzs,yzs,xmax,ymax,zof=zof,zpos=zpos,ip=3, $
            amin=amin/oversaturate,amax=amax/oversaturate,dev=dev, $
            xpos=xpos,magnify=magnify,ymagnify=ymagnify,zmagnify=zmagnify,scale=scale, $
            nobottom=nobottom,norm=norm,xrot=xrot,zrot=zrot,sample=sample
        if (keyword_set(nolabel)) then begin
          if (label ne '') then begin
            xyouts,xlabel,ylabel,label,col=1,siz=size_label,charthick=thlabel
          endif
        endif else begin
          if (label eq '') then begin
            xyouts,xlabel,ylabel, $
                tlabel+'!3='+string(t/tunit,fo=fo)+'!c!6'+title, $
                col=1,siz=size_label,charthick=thlabel
          endif else begin
            xyouts,xlabel,ylabel, $
                label+'!c!8t!3='+string(t,fo=fo)+'!c!6'+title, $
                col=1,siz=size_label,charthick=thlabel
          endelse
        endelse
      endif else begin
;
;  Draw axes box.
;
        if (keyword_set(centred)) then begin
          zrr1=rrxy2
          zrr2=rrxy
          if (keyword_set(z_bot_twice)) then begin
            xy2s=xys
            zrr1=rrxy
          endif else if (keyword_set(z_top_twice)) then begin
            xys=xy2s
            zrr2=rrxy2
          endif else if (keyword_set(z_topbot_swap)) then begin
            xys=xy2s
            zrr2=rrxy2
            xy2s=xys
            zrr1=rrxy
          endif
          boxbotex_scl,xy2s,xys,xzs,yzs,1.,1.,zof=.36,zpos=.25,ip=3, $
              amin=amin,amax=amax,dev=dev, $
              shell=shell,centred=centred,scale=scale,sample=sample, $
              r_int=r_int,r_ext=r_ext,zrr1=zrr1,zrr2=zrr2,yrr=rrxz,xrr=rryz, $
              nobottom=nobottom,norm=norm,xrot=xrot,zrot=zrot
          xyouts, .08, 0.81, '!8t!6='+string(t/tunit,fo=fo)+'!c'+title, $
              col=1,siz=1.6
        endif else begin
          boxbotex_scl,xy2s,xys,xzs,yzs,xmax,ymax,zof=.65,zpos=.34,ip=3, $
              amin=amin,amax=amax,dev=dev,sample=sample, $
              shell=shell, $
              r_int=r_int,r_ext=r_ext,zrr1=rrxy,zrr2=rrxy2,yrr=rrxz,xrr=rryz, $
              nobottom=nobottom,norm=norm,xrot=xrot,zrot=zrot
          xyouts, .08, 1.08, '!8t!6='+string(t/tunit,fo=fo)+'!c'+title, $
              col=1,siz=1.6
        endelse
      endelse
;
;  Draw color bar.
;
      if (keyword_set(bar)) then begin
        default, bsize, 1.5
        default, bformat, '(f5.2)'
        default, bnorm, 1.
        default, divbar, 2
        default, blabel, ''
        !p.title=blabel
        ;colorbar, pos=[.80,.15,.82,.85], color=1, div=divbar, $
        colorbar, pos=colorbarpos, color=1, div=divbar, $
            range=[amin,amax]/bnorm, /right, /vertical, $
            format=bformat, charsize=bsize, title=title
        !p.title=''
      endif
;
;  Draw axes.
;
      if (keyword_set(axes)) then begin
        xx=!d.x_size
        yy=!d.y_size
        aspect_ratio=1.*yy/xx
;  Length of the arrow.
        length=0.1
        xlength=length
        ylength=xlength/aspect_ratio
;  Rotation angles. WL didn't figure out exactly the rotation law. This .7 is
;  an ugly hack that looks good for most angles.
        gamma=.7*xrot*!pi/180.
        alpha=zrot*!pi/180.
;  Position of the origin
        x0=0.12
        y0=0.25
;
;  x arrow
;
        x1=x0+xlength*(cos(gamma)*cos(alpha))
        y1=y0+ylength*(sin(gamma)*sin(alpha))
        angle=atan((y1-y0)/(x1-x0))
        if ((x1-x0 le 0)and(y1-y0 ge 0)) then angle=angle+!pi
        if ((x1-x0 le 0)and(y1-y0 le 0)) then angle=angle-!pi
        x2=x0+length*cos(angle)
        y2=y0+length*sin(angle)
        ;arrow, x0, y0, x1, y1,color=100,/normal
        arrow, x0, y0, x2, y2,col=1,/normal, $
            thick=thlabel,hthick=thlabel
        xyouts,x2-0.01,y2-0.045,'!8x!x',col=1,/normal, $
            siz=size_label,charthick=thlabel
;
;  y arrow
;
        x1=x0+xlength*(-cos(gamma)*sin(alpha))
        y1=y0+ylength*( sin(gamma)*cos(alpha))
        angle=atan((y1-y0)/(x1-x0))
        if ((x1-x0 le 0)and(y1-y0 ge 0)) then angle=angle+!pi
        if ((x1-x0 le 0)and(y1-y0 le 0)) then angle=angle-!pi
        x2=x0+length*cos(angle)
        y2=y0+length*sin(angle)
        ;arrow, x0, y0, x1, y1,color=100,/normal
        arrow, x0, y0, x2, y2,col=1,/normal, $
            thick=thlabel,hthick=thlabel
        xyouts,x2-0.03,y2-0.01,'!8y!x',col=1,/normal, $
            siz=size_label,charthick=thlabel
;
;  z arrow
;
        x1=x0
        y1=y0+ylength
        arrow, x0, y0, x1, y1,col=1,/normal, $
            thick=thlabel,hthick=thlabel
        xyouts,x1-0.015,y1+0.01,'!8z!x',col=1,/normal, $
            siz=size_label,charthick=thlabel
      endif
;
;  Save as png file.
;
      if (keyword_set(png)) then begin
        istr2 = strtrim(string(itpng,'(I20.4)'),2) ;(only up to 9999 frames)
        image = tvrd()
;
;  Make background white, and write png file.
;
        bad=where(image eq 0, num)
        if (num gt 0) then image(bad)=255
        tvlct, red, green, blue, /GET
        imgname = imgprefix+istr2+'.png'
        write_png, imgdir+'/'+imgname, image, red, green, blue
        if (keyword_set(png_truecolor)) then $
            spawn, 'mogrify -type TrueColor ' + imgdir+'/'+imgname
        itpng=itpng+1         ;(counter)
;
      endif else if (keyword_set(mpeg)) then begin
;
;  Write mpeg file directly.
;  NOTE: For idl_5.5 and later this requires the mpeg license.
;
        image = tvrd(true=1)
;
        if (keyword_set(colmpeg)) then begin
;ngrs seem to need to work explictly with 24-bit color to get
;     color mpegs to come out on my local machines...
          image24 = bytarr(3,xsize,ysize)
          tvlct, red, green, blue, /GET
        endif
;
        for irepeat=0,nrepeat do begin
          if (keyword_set(colmpeg)) then begin
            image24[0,*,*]=red(image[0,*,*])
            image24[1,*,*]=green(image[0,*,*])
            image24[2,*,*]=blue(image[0,*,*])
            mpeg_put, mpegID, image=image24, frame=itmpeg, /order
          endif else begin
            mpeg_put, mpegID, window=2, frame=itmpeg, /order
          endelse
          itmpeg=itmpeg+1     ;(counter)
        endfor
;
        if (first_print) then $
            print, '   islice    itmpeg       min/norm     max/norm     amin         amax'
        first_print = 0
        print, islice, itmpeg, t, $
            min([min(xy2),min(xy),min(xz),min(yz)])/norm, $
            max([max(xy2),max(xy),max(xz),max(yz)])/norm, $
            amin, amax
;
      endif else begin
;
;  Default: output on the screen
;
        if (first_print) then $
            print, '   islice        t        min/norm     max/norm        amin         amax'
        first_print = 0
        print, islice, t, $
            min([min(xy2),min(xy),min(xz),min(yz)])/norm, $
            max([max(xy2),max(xy),max(xz),max(yz)])/norm, $
            amin, amax, format='(i9,e12.4,4f13.7)'
      endelse
;
;  Wait in case movie runs to fast.
;
      wait, wait
;
;  Check whether file has been written.
;
      if (keyword_set(png)) then spawn, 'ls -l '+imgdir+'/'+imgname
;
    endelse
  endif else begin
;
;  Skip this slice if not in time interval or if striding.
;
    if (not quiet_skip) then $
        print, 'Skipping slice number '+strtrim(islice,2)+ $
               ' at time t=', t
  endelse
;
;  Ready for next video slice.
;
  islice=islice+1
;
endwhile
;
;  Inform the user of why program stopped.
;
if (t gt tmax) then begin
  print, 'Stopping since t>', strtrim(tmax,2)
endif else begin
  print, 'Read last slice at t=', strtrim(t,2)
endelse
;
;  Close slice files.
;
close, lun_1
close, lun_2
close, lun_3
close, lun_4
free_lun, lun_1
free_lun, lun_2
free_lun, lun_3
free_lun, lun_4
;
;  Write and close mpeg file.
;
if (keyword_set(mpeg)) then begin
  print,'Writing MPEG file...'
  mpeg_save, mpegID, filename=mpeg_name
  mpeg_close, mpegID
endif
;
end
