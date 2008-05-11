;; $Id: pc_read_yzaver.pro,v 1.7 2008-05-11 08:20:10 ajohan Exp $
;;
;;   Read yz-averages from file
;;
pro pc_read_yzaver, object=object, varfile=varfile, datadir=datadir, $
    monotone=monotone, quiet=quiet
COMPILE_OPT IDL2,HIDDEN
COMMON pc_precision, zero, one
;;
;;  Default data directory.
;;
if (not keyword_set(datadir)) then datadir=pc_get_datadir()
default, varfile, 'yzaverages.dat'
default, monotone, 0
default, quiet, 0
;;
;;  Get necessary dimensions.
;;
pc_read_dim, obj=dim, datadir=datadir, quiet=quiet
pc_set_precision, dim=dim, quiet=quiet
;;
;;  Derived dimensions.
;;
nx=dim.nx
;;
;;  Read variables from xyaver.in
;;
spawn, "echo "+datadir+" | sed -e 's/data\/*$//g'", datatopdir
spawn, 'cat '+datatopdir+'/yzaver.in', varnames
if (not quiet) then print, 'Preparing to read yz-averages ', $
    arraytostring(varnames,quote="'",/noleader)
nvar=n_elements(varnames)
;;
;;  Define arrays to put data in.
;;
spawn, 'wc -l '+datadir+'/'+varfile, nlines
nlines=long(nlines[0])
nit=nlines/(1+nvar*nx/8)

if (not quiet) then print, 'Going to read averages at ', strtrim(nit,2), ' times'

for i=0,nvar-1 do begin
  cmd=varnames[i]+'=fltarr(nx,nit)*one'
  if (execute(cmd,0) ne 1) then message, 'Error defining data arrays'
endfor
var=fltarr(nx)*one
tt =fltarr(nit)*one
;;
;;  Prepare for read
;;
GET_LUN, file
filename=datadir+'/'+varfile 
if (not quiet) then print, 'Reading ', filename
dummy=findfile(filename, COUNT=countfile)
if (not countfile gt 0) then begin
  print, 'ERROR: cannot find file '+ filename
  stop
endif
close, file
openr, file, filename
;;
;;  Read xy-averages and put in arrays.
;;
for it=0L,nit-1 do begin
;; Read time
  readf, file, t
  tt[it]=t
;; Read data
  for i=0,nvar-1 do begin
    readf, file, var
    cmd=varnames[i]+'[*,it]=var'
    if (execute(cmd,0) ne 1) then message, 'Error putting data in array'
  endfor
endfor
;;
;;  Close file.
;;
close, file
free_lun, file
;;
;;  Make time monotonous and crop all variables accordingly.
;;  
if (monotone) then begin
  ii=monotone_array(tt)
endif else begin
  ii=lindgen(n_elements(tt))
endelse
;;
;;  Put data in structure.
;;
makeobject="object = CREATE_STRUCT(name=objectname,['t'," + $
    arraytostring(varnames,QUOTE="'",/noleader) + "]," + $
    "tt[ii],"+arraytostring(varnames+'[*,ii]',/noleader) + ")"

if (execute(makeobject) ne 1) then begin
  message, 'ERROR Evaluating variables: ' + makeobject, /INFO
  undefine,object
endif


end
