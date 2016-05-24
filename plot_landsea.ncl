load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"

fnames=systemfunc("/bin/ls $FILES")

; Goal:
; + show topography over land
; + show depth over lakes/ocean
; + show rivers large enought to be resolved by grid
; Method:
; + load topography
; + set topography to zero where LANDMASK=0
; + subtract LAKE_DEPTH from topography
; Expected result
; + Land: value represents height asl
; + Rivers: value = 0
; + Sea: value represent bottom topography relative sea surface
; + Lakes: value represents bottom topography relative lake-surface

; Define our contour levels:
; DO NOT CHANGE THE NUMBER OF LEVELS
; THE 0 LEVEL SHOULD BE 11 LEVELS FROM TOP
levels_land = fspan(400,4000,10)      ; positive values over land
levels_water= fspan(-900,0,10)  ; negative values over lakes/ocean

levels=array_append_record(levels_water,levels_land,0)
;levels=(/levels_water(:),levels_land(:)/)
; Define colormap (first 11=water last 10=land)
cmap = "viridis"  ; Expecting 255 colours
colors = read_colormap_file(cmap)
colors_indexes = (/8,15,22,29,36,43,50,57,64,71,\
  140,152,164,176,188,200,212,224,236,248,253/)


overlay_mask="LANDMASK" ; Sea/Lake/River = 0, Land = 1
overlay_var="LAKE_DEPTH" 
olevels=fspan(0,1000,11)
olevels(0)=11 ;land is 10, we don't want to overlay land areas

;type = "x11"
;type = "pdf"
;type = "ps"
type = "eps"
;type = "ncgm" 

; Read data and set attributes
undef("readwrf")
function readwrf(fname,it)
local fin,data,topo,landmask,depth,lat,lon,dims,rank,nx,ny
begin
  fin = addfiles(fname,"r")
  ; Load variables:
  topo      = wrf_user_getvar(fin,"HGT_M",0)
  landmask  = wrf_user_getvar(fin,"LANDMASK",0)
  depth     = wrf_user_getvar(fin,"LAKE_DEPTH",0)
  ; Set topography to -1 over lakes/rivers/ocean
  data = where(landmask.eq.1,topo,-1)
  ; Set topography to -1001 over ocean
  data = where(topo.le.1 .and. landmask.eq.0,-1001,data)
  ; Set topography to lake depth over lakes
  data = where(depth.gt.10,-depth,data)

  ; Get attributes
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
  data@urx    = lon(ny,nx)
  data@ury    = lat(ny,nx)
  data@xbox   = (/lon(0,0),lon(0,nx),lon(ny,nx),lon(ny,0),lon(0,0)/)
  data@ybox   = (/lat(0,0),lat(0,nx),lat(ny,nx),lat(ny,0),lat(0,0)/)

  ; Get projection attributes:
  data@proj = fin[0]@MAP_PROJ
  if (data@proj .eq. 1) then
    data@LAT1 = fin[0]@TRUELAT1
    data@LAT2 = fin[0]@TRUELAT2
    data@LON0 = fin[0]@STAND_LON
  end if

  return data
end 

nfiles=dimsizes(fnames)


; Set up the plot resources:
res                               = True
print(levels)
res@cnLevels                      = levels
;res@cnFillPalette                 = colors(colors_indexes,:)
res@cnFillColors                  = colors(colors_indexes,:)
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
;res@gsnMajorLatSpacing            = 15
;res@gsnMajorLonSpacing            = 15

; set up resources for the overlay field:

; set up line resources:
lres                              = True
lres@gsLineThicknessF             = 1.0
lres@gsLineColor                  = "grey40"

; set up map resources based on first file
data=readwrf(fnames(0),0)

;mres = set_mp_wrf_map_mresources(fin,res)
mres=res
mres@mpDataBaseVersion            = "MediumRes"
mres@mpLimitMode                  = "Corners"
mres@mpLeftCornerLatF             = data@lly
mres@mpLeftCornerLonF             = data@llx
mres@mpRightCornerLatF            = data@ury
mres@mpRightCornerLonF            = data@urx

mres@pmTickMarkDisplayMode        = "Always"

mres@mpOutlineDrawOrder           = "PostDraw"
mres@mpGridAndLimbOn              = True
mres@mpGridLatSpacingF            = 10
mres@mpGridLonSpacingF            = 10
mres@mpGridLineThicknessF         = 0.5
mres@mpGridLineColor              = "grey20"

mres@tmXMajorGrid                 = False
mres@tmYMajorGrid                 = False
mres@tmXMajorGridLineColor        = "white"
mres@tmYMajorGridLineColor        = "white"
mres@tmXMajorGridThicknessF       = 0.5
mres@tmYMajorGridThicknessF       = 0.5

if ( data@proj .eq. 1 ) then
  mres@mpProjection           = "LambertConformal"
  mres@mpLambertParallel1F    = data@LAT1
  mres@mpLambertParallel2F    = data@LAT2
  mres@mpLambertMeridianF     = data@LON0
end if
; Create the map:
wks = gsn_open_wks(type,"elevation_and_depth")
;gsn_define_colormap(wks,cmap)
map = gsn_csm_contour_map(wks,data,mres)
;map = gsn_contour_map(wks,data,mres)
;draw(map)

; Create overlay plots for all other files:
xbox=new((/5,nfiles/),float)
ybox=new((/5,nfiles/),float)
delete(data)
do i=1,nfiles-1
  data = readwrf(fnames(i),0)       ; read data
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
