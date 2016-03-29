;+
; :Name: kcorp.pro
;-------------------------------------------------------------------------------
; :Uses: Plot chosen K-coronagraph parameters.
;-------------------------------------------------------------------------------
; :Author: Andrew L. Stanger   HAO/NCAR   26 November 2014
;-------------------------------------------------------------------------------
; :Params:	date [format: 'yyyymmdd']
; :Keywords:	list [format: 'list']
;-------------------------------------------------------------------------------
; 10 Feb 2015 Revised plot date format.
;             Changed hours X-range [16-28],
;             Changed DIMV  Y-range [5.5-7.5].
;             Changed modular temp Y-range [28-36].
; 22 Feb 2015 L0 files are now in level0 sub-directory.
; 31 May 2015 Modify yrange for O1 focus from [130, 140] to [130, 150].  
;  8 Jun 2015 Modify yrange for O1 focus from [130, 150] to [125, 150].
; 10 Jun 2015 Modify yrange for O1 focus from [125, 150] to [110, 150].
;             Also print focus values in log file.
;-------------------------------------------------------------------------------
;-

PRO kcorp, date, list=list

;--- Determine the number of command line parameters. 

np = n_params ()
PRINT, 'np: ', np

IF (np EQ 0) THEN $
BEGIN ;{
   PRINT, "kcorp, 'yyyymmdd', list='list'"
   RETURN
END   ;}

;-------------------------------------------------------------------------------
; Establish directory paths.
;-------------------------------------------------------------------------------

l0_base       = '/hao/mlsodata1/Data/KCor/raw/'

l0_dir        = l0_base + date + '/level0/'
p_dir         = l0_base + date + '/p/'

;-------------------------------------------------------------------------------
; Create sub-directory for plots.
;-------------------------------------------------------------------------------

FILE_MKDIR, p_dir

;-------------------------------------------------------------------------------
; Move to L0 kcor directory.
;-------------------------------------------------------------------------------

CD, current=start_dir			; Save current directory.
CD, l0_dir				; Move to raw (L0) kcor directory.

doview = 0

;--- Establish list of files to process.

IF (KEYWORD_SET (list)) THEN $
BEGIN ;{
   listfile = list
END  $ ;}
ELSE $
BEGIN ;{
   listfile = 'list'
   spawn, 'ls *kcor.fts* > list'
END   ;}

;-------------------------------------------------------------------------------
; Open log file.
;-------------------------------------------------------------------------------

logfile = date + '_p_' + listfile + '.log'

GET_LUN, ULOG
CLOSE,   ULOG 
OPENW,   ULOG, p_dir + logfile

PRINT, 'start_dir: ', start_dir
PRINT, 'l0_dir:    ', l0_dir
PRINT, 'p_dir:     ', p_dir

PRINTF, ULOG, 'start_dir: ', start_dir
PRINTF, ULOG, 'l0_dir:    ', l0_dir
PRINTF, ULOG, 'p_dir:     ', p_dir

;-------------------------------------------------------------------------------
; Set up graphics window & color table.
;-------------------------------------------------------------------------------

;set_plot, 'X'
;window, 0, xs=1024, ys=1024, retain=2

set_plot, 'z'
device, set_resolution=[772,1000], decomposed=0, set_colors=256, $
        z_buffering=0
!P.MULTI = [0, 1, 3]

;-------------------------------------------------------------------------------
; Determine the number of files to process.
;-------------------------------------------------------------------------------

PRINT, 'listfile: ', listfile

GET_LUN, ULIST
OPENR,   ULIST, listfile
l0_file = ''

i = 0 ;
WHILE (NOT EOF (ULIST)) DO $
BEGIN ;{
   i += 1
   READF, ULIST, l0_file
END   ;}
CLOSE, ULIST
FREE_LUN, ULIST
nimg = i;

PRINT,        'nimg: ', nimg
PRINTF, ULOG, 'nimg: ', nimg
;-------------------------------------------------------------------------------
;nwc = intarr (3)
;spawn, 'ls *fts* | wc', nwc

;PRINT,        'nwc: ', nwc
;PRINTF, ULOG, 'nwc: ', nwc

;finfo = FILE_INFO (listfile)
;nimg = finfo.size / 28		; L0 file length is 27 char + CR.
;nimg = nwc (0)

;PRINT,        'finfo.size, nimg: ', finfo.size, nimg
;PRINTF, ULOG, 'finfo.size, nimg: ', finfo.size, nimg

;-------------------------------------------------------------------------------
; Declare storage for plot arrays.
;-------------------------------------------------------------------------------

mod_temp = fltarr (nimg)
sgs_dimv = fltarr (nimg)
sgs_scin = fltarr (nimg)
hours    = fltarr (nimg)

tcam_focus = fltarr (nimg)
rcam_focus = fltarr (nimg)
o1_focus   = fltarr (nimg)

;-------------------------------------------------------------------------------
; Image file loop.
;-------------------------------------------------------------------------------

i = -1
GET_LUN, ULIST
OPENR,   ULIST, listfile

WHILE (NOT EOF (ULIST)) DO $
BEGIN ;{
   i += 1
   READF, ULIST, l0_file

   finfo = FILE_INFO (l0_file)			; Get file information.

   hdu = headfits (l0_file, /SILENT)		; Read FITS header.

   ;--- Get FITS header size.

   hdusize = SIZE (hdu)

   ;--- Extract keyword parameters from FITS header.

   diffuser = ''
   calpol   = ''
   darkshut = ''
   cover    = ''
   occltrid = ''

   naxis    = SXPAR (hdu, 'NAXIS',    count=qnaxis)
   naxis1   = SXPAR (hdu, 'NAXIS1',   count=qnaxis1)
   naxis2   = SXPAR (hdu, 'NAXIS2',   count=qnaxis2)
   naxis3   = SXPAR (hdu, 'NAXIS3',   count=qnaxis3)
   naxis4   = SXPAR (hdu, 'NAXIS4',   count=qnaxis4)
   np       = naxis1 * naxis2 * naxis3 * naxis4 

   date_obs = SXPAR (hdu, 'DATE-OBS', count=qdate_obs)
   level    = SXPAR (hdu, 'LEVEL',    count=qlevel)

   bzero    = SXPAR (hdu, 'BZERO',    count=qbzero)
   bbscale  = SXPAR (hdu, 'BSCALE',   count=qbbscale)

   datatype = SXPAR (hdu, 'DATATYPE', count=qdatatype)

   diffuser = SXPAR (hdu, 'DIFFUSER', count=qdiffuser)
   calpol   = SXPAR (hdu, 'CALPOL',   count=qcalpol)
   darkshut = SXPAR (hdu, 'DARKSHUT', count=qdarkshut)
   cover    = SXPAR (hdu, 'COVER',    count=qcover)

   occltrid = SXPAR (hdu, 'OCCLTRID', count=qoccltrid)

   tcamfocs = SXPAR (hdu, 'TCAMFOCS', count=qtcamfocs)
   rcamfocs = SXPAR (hdu, 'RCAMFOCS', count=qrcamfocs)
   o1focs   = SXPAR (hdu, 'O1FOCS',   count=qo1focs)

   modltrt  = SXPAR (hdu, 'MODLTRT',  count=qmodltrt)
   sgsdimv  = SXPAR (hdu, 'SGSDIMV',  count=qsgsdimv)
   sgsscint = SXPAR (hdu, 'SGSSCINT', count=qsgsscint)

   mod_temp (i) = modltrt
   sgs_dimv (i) = sgsdimv
   sgs_scin (i) = sgsscint

   tcam_focus (i) = tcamfocs
   rcam_focus (i) = rcamfocs
   o1_focus (i)   = o1focs
   
   ;--- Determine occulter size in pixels.

   occulter = strmid (occltrid, 3, 5)	; Extract 5 characters from occltrid.
   IF (occulter EQ '991.6') THEN occulter =  991.6
   IF (occulter EQ '1018.') THEN occulter = 1018.9
   IF (occulter EQ '1006.') THEN occulter = 1006.9

   platescale = 5.643		; arsec/pixel.
   radius_guess = occulter / platescale		; occulter size [pixels].

   PRINTF, ULOG, FORMAT='(a27, " ", i4, " ", a11, 2(" ", f7.3), " ", f9.3)', $
                 l0_file, i+1, datatype, modltrt, sgsdimv, sgsscint
   PRINT,        FORMAT='(a27, " ", i4, " ", a11, 2(" ", f7.3), " ", f9.3)', $
                 l0_file, i+1, datatype, modltrt, sgsdimv, sgsscint 

   PRINTF, ULOG, FORMAT='(44x, 2(" ", f7.3), " ", f9.3)', $
                 tcamfocs, rcamfocs, o1focs
   PRINT,        FORMAT='(44x, 2(" ", f7.3), " ", f9.3)', $
                 tcamfocs, rcamfocs, o1focs

;   PRINTF, ULOG, '>>> ', l0_file, i, ' ', datatype, modltrt, sgsdimv, sgsscint
;   PRINT,        '>>> ', l0_file, i, ' ', datatype, modltrt, sgsdimv, sgsscint
;   PRINT,        'file size: ', finfo.size
;   PRINTF, ULOG, 'file size: ', finfo.size

   ;----------------------------------------------------------------------------
   ; Define array dimensions.
   ;----------------------------------------------------------------------------
   xdim = naxis1
   ydim = naxis2

   ;----------------------------------------------------------------------------
   ; Extract date items from FITS header parameter (DATE-OBS).
   ;----------------------------------------------------------------------------

   year   = strmid (date_obs, 0, 4)
   month  = strmid (date_obs, 5, 2)
   day    = strmid (date_obs, 8, 2)
   hour   = strmid (date_obs, 11, 2)
   minute = strmid (date_obs, 14, 2)
   second = strmid (date_obs, 17, 2)

   ;--- pdate is for the plot title.

   if (i EQ 0) THEN $
   BEGIN ;{
      pyear   = strmid (date, 0, 4)
      pmonth  = strmid (date, 4, 2)
      pday    = strmid (date, 6, 2)
      pdate = string (format='(a4)', pyear)   + '-' $
            + string (format='(a2)', pmonth)  + '-' $
            + string (format='(a2)', pday)
   END ;}

   datedash = string (format='(a4)', year)   + '-' $
            + string (format='(a2)', month)  + '-' $
            + string (format='(a2)', day)
   datetime = datedash + 'T' $
	    + string (format='(a2)', hour)   + ':' $
	    + string (format='(a2)', minute) + ':' $
	    + string (format='(a2)', second)

   ;--- obs_hour is referenced to the observing day, so add 24 hours to
   ;    the hours past midnight UT.

   obs_hour = hour
   if (hour LT 16) THEN obs_hour += 24

   hours (i) = obs_hour + minute / 60.0 + second / 3600.0

   ;----------------------------------------------------------------------------
   ; Find ephemeris data (pangle,bangle ...) using solarsoft routine pb0r.
   ;----------------------------------------------------------------------------

;   ephem = pb0r (datetime, /arcsec)
;   pangle = ephem (0) 		; degrees.
;   bangle = ephem (1)		; degrees.
;   rsun   = ephem (2)		; solar radius (arcsec).

;   PRINTF, ULOG, 'pangle, bangle, rsun: ', pangle, bangle, rsun
;   PRINT,        'pangle, bangle, rsun: ', pangle, bangle, rsun

;   pangle += 180.0		; adjust orientation for Kcor telescope.

   ;----------------------------------------------------------------------------
   ; Verify that image is Level 0.
   ;----------------------------------------------------------------------------

   IF (level    NE 'L0')  THEN $
   BEGIN
      PRINTF, ULOG, '*** not Level 0 data ***'
      PRINT,        '*** not Level 0 data ***'
      CONTINUE
   END


END   ;}
;-------------------------------------------------------------------------------
; End of file loop.
;-------------------------------------------------------------------------------

CLOSE,    ULIST
FREE_LUN, ULIST

modgif  = p_dir + date + '_' + listfile + '_mtmp.gif'
dimvgif = p_dir + date + '_' + listfile + '_dimv.gif'
scingif = p_dir + date + '_' + listfile + '_scin.gif'

enggif  = p_dir + date + '_' + listfile + '_eng.gif'
focgif  = p_dir + date + '_' + listfile + '_foc.gif'

PRINTF, ULOG, 'enggif: ', enggif
PRINTF, ULOG, 'focgif: ', focgif

plot, hours, mod_temp, title=pdate + '  Kcor Modulator Temperature', $
      xtitle='Hours [UT]', ytitle='Temperature [deg C]', $
      background=255, color=0, charsize=2.0, $
      xrange=[16.0, 28.0], yrange=[28.0, 36.0]

plot, hours, sgs_dimv, title=pdate + '  Kcor SGS DIM', $
      xtitle='Hours [UT]', ytitle='DIM [volts]', /ynozero, $
      xrange=[16.0, 28.0], yrange=[5.5, 7.5], $
      background=255, color=0, charsize=2.0

;--- Use fixed y-axis scaling, unless values wander outside the range: 0 to 10.

smin = MIN (sgs_scin)
smax = MAX (sgs_scin)
;IF (smin GT 0.0 AND smax LT 10.0) THEN $
   plot, hours, sgs_scin, title=pdate + '  Kcor SGS Scintillation', $
         xtitle='Hours [UT]', ytitle='Scintillation [arcsec]', $
         xrange=[16.0, 28.0], yrange=[0.0, 10.0], $
         background=255, color=0, charsize=2.0 
;ELSE $
;   plot, hours, sgs_scin, title=pdate + '  Kcor SGS Scintillation', $
;         xtitle='Hours [UT]', ytitle='Scintillation [arcsec]', $
;         background=255, color=0, charsize=2.0 

save = tvrd ()
write_gif, enggif, save

erase

plot, hours, tcam_focus, title=pdate + '  KCOR T Camera Focus position', $
      xtitle='Hours [UT]', ytitle='T Camera Focus [mm]', $
      background=255, color=0, charsize=2.0, $
      xrange=[16.0, 28.0], yrange=[-1.0, 1.0]

plot, hours, rcam_focus, title=pdate + '  KCOR R Camera Focus position', $
      xtitle='Hours [UT]', ytitle='R Camera Focus [mm]', $
      background=255, color=0, charsize=2.0, $
      xrange=[16.0, 28.0], yrange=[-1.0, 1.0]

plot, hours, o1_focus, title=pdate + '  KCOR O1 Focus position', $
      xtitle='Hours [UT]', ytitle='O1 Camera Focus [mm]', $
      background=255, color=0, charsize=2.0, $
      xrange=[16.0, 28.0], yrange=[110.0, 150.0]
save = tvrd () 
write_gif, focgif, save

PRINT,        '>>>>>>> end... kcorp <<<<<<<'
PRINTF, ULOG, '>>>>>>> end... kcorp <<<<<<<'

CD, start_dir
SET_PLOT, 'X'

CLOSE,    ULOG
FREE_LUN, ULOG 

END
