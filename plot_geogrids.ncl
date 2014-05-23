load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

fnames=systemfunc("/bin/ls test02/geo_em.d??.nc")
;print(fnames)
var="HGT_M"
autocontours=True
levels = fspan(0,4000,11);
levels(0) = 10
;type = "x11"
;type = "pdf"
;type = "ps"
type = "eps"
;type = "ncgm" 

; Read data and set attributes
undef("readwrf")
function readwrf(fname,var,it)
local fin,data,lat,lon,dims,rank,nx,ny
begin
  ; start with first file (should be outermost domain)
  fin = addfiles(fname,"r")
  data  = wrf_user_getvar(fin,var,0)
  lat   = wrf_user_getvar(fin,"XLAT",0)
  lon   = wrf_user_getvar(fin,"XLONG",0)
  dims  = dimsizes(data)
  rank  = dimsizes(dims)
  nx    = dims(rank-1)-1
  ny    = dims(rank-2)-1
  data@lon2d  = lon
  data@lat2d  = lat
  data@llx    = lon(0,0)
  data@lly    = lat(0,0)
  printVarSummary(lon)
  print((/nx,ny/))
  data@urx    = lon(ny,nx)
  data@ury    = lat(ny,nx)
  data@xbox   = (/lon(0,0),lon(0,nx),lon(ny,nx),lon(ny,0),lon(0,0)/)
  data@ybox   = (/lat(0,0),lat(0,nx),lat(ny,nx),lat(ny,0),lat(0,0)/)
  return data
end 

; Some automatic settings:
maxval=0.1
maxval@_fillValue=-999
maxval=maxval@_fillValue
minval=0.0

nfiles=dimsizes(fnames)

; First we should find the span of the data to be plotted
; so that we can use common contour levels for all domains
do i=0,nfiles-1
  ; read data from file (using our own wrapper)
  print(1)
  data=readwrf(fnames(i),var,0)
  ; open new file
  print(2)
  printVarSummary(data)

  ; adjust contour limits if necessary
  maxval=max( (/maxval,max(data)/) )
  minval=min( (/minval,min(data)/) )

  delete(data)
end do

; Calculate nice contour levels:
if( autocontours ) then
  if( minval.lt.0 ) then
    lo=-10^(floor(log10(-minval)))
    hi=10^(floor(log10(maxval)))
  else
    lo=0
    ;hi=1.5*10^(floor(log10(maxval)))
    ;print(maxval)
    maxlog=floor(log10(maxval))
    maxval=ceil(maxval/10^(maxlog-1))
    ;print(maxval)
    hi=maxval*10^(maxlog-1)
  end if
  levels=fspan(lo,hi,10)
  ;print(levels)
else
  ; use user defined contour levels
  print("Using manual contours")
end if

; Set up the plot resources:
res                               = True
res@cnLevels                      = levels
res@lbOrientation                 = "Vertical"
res@cnFillOn                      = True
res@cnLinesOn                     = False
;res@cnLinesLabelsOn               = True
res@cnInfoLabelOn                 = False
res@cnLevelSelectionMode          = "ExplicitLevels"

res@gsnSpreadColors               = True
;res@gsnLeftString                 = ""
;res@gsnRightSting                 = ""
res@gsnDraw                       = False
res@gsnFrame                      = False

; set up line resources:
lres                              = True
lres@gsLineThicknessF             = 0.5

; set up map resources based on first file
data=readwrf(fnames(0),var,0)

;mres = set_mp_wrf_map_mresources(fin,res)
mres=res
mres@mpDataBaseVersion            = "MediumRes"
mres@mpOutlineDrawOrder           = "PostDraw"
mres@mpGridAndLimbOn              = True
mres@pmTickMarkDisplayMode        = "Always"
mres@mpLimitMode                  = "Corners"
mres@mpLeftCornerLatF             = data@lly
mres@mpLeftCornerLonF             = data@llx
mres@mpRightCornerLatF            = data@ury
mres@mpRightCornerLonF            = data@urx

; Create the map:
wks = gsn_open_wks(type,var)
map = gsn_csm_contour_map(wks,data,mres)
;draw(map)

; Create overlay plots for all other files:
xbox=new((/5,nfiles/),float)
ybox=new((/5,nfiles/),float)
delete(data)
do i=1,nfiles-1
  data = readwrf(fnames(i),var,0)       ; read data
  plot = gsn_csm_contour(wks,data,res)  ; create plot
  overlay(map,plot)                     ; add to previous figure
  ;draw(map)
  ; Draw a box around the current domain 
  datatondc(map,data@xbox,data@ybox,xbox(:,i),ybox(:,i)) ;convert xy-plot to NDC
  ;gsn_polyline_ndc(wks,xbox,ybox,lres)
  delete(data)
  ;delete(plot)
end do
draw(map)

; Draw boxes
do i=1,nfiles-1
  gsn_polyline_ndc(wks,xbox(:,i),ybox(:,i),lres)
end do

frame(wks)
