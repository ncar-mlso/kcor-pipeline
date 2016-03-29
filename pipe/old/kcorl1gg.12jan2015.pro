;+
; pro kcorl1gg
;
; :Author: Joan Burkepile
;
; Modified version of 'make_calib_kcor_vig_gif.pro' 8 Oct 2014 09:57 (Andrew Stanger)
; 03 Oct 2014: Add date & list parameters.
; 13 Nov 2014: Add base_dir parameter.
; 13 Nov 2014: Use kcor_find_image function to locate disc center.
; 14 Nov 2014: Use Z-buffer instead of X window device for GIF images.
;              Note: charsize for xyouts needs to be reduced to about 2/3 of
;              of the size used for the X window device to yield approximately
;              the same size of characters in the annotated image.
; 19 Nov 2014: Change log file name so that the date always refers to 
;              the observing day (instead of calendar day for the L0 list).
;
; Modified centering algorithm because did not find correct center (Giuliana de Toma)
;  Nov 7 2014:  changed to double precision to properly find inflection points
;               added keyword center_guess to guess center location using with 
;               vertical/horizonatl scans (see Alice's quick-look code)
;               added iteration if center is not found at first attempt 
;               used Randy Meisner fitcircle.pro to fit a circle because faster 
;                
; Modified version to speed up code and fixed a few other things (Giuliana de Toma)
;   Dec 1 2014: negative and zero values in the gain are replaced with the
;               mean value in a 5x5 region centered on bad data point
;   Dec 1 2014: coordinates and radius are defined as arrays for gain and images
;   Dec 1 2014: solar radius, platescale, and occulter are determined at the 
;               beginning of the code
;   Dec 1 2014: gain is not shifted to properly flat-field images 
;               region where gain is not available is based on a shifted gain 
;   Dec 1 2014: removed part about finding the center after demodulation 
;               center for final images is based on distorted raw images - this is the
;               best way to find the correct center (hard to find the center after  
;               image calibration because of saturation ring)
;   Dec 1 2014: Mk4 cordinate transformation is now based on arrays (removed loops)
;   Dec 1 2014: sky polaritzion correction is now based on on arrays (removed loops)
;               sin2theta uses 2 instead of 3 parameters
;               changed derivative in sin2theta and initial guesses in main code
;               U fit is shifted by 45deg for Q correction
;   Dec 1 2014: "a" was used as fit parameter and also as index in for-loops
;               changed to avoid possible variable conflicts
;   Dec 1 2014: final image masking is done with array (removed loop)

;   Dec 2014: Calibrated image is shifted and rotated using ROT - so only
;             one interpolation is made to put north up and image in the
;             array center (Giuliana de Toma & Andrew Stanger)
-------------------------------------------------------------------------------
;   Make semi-calibrated kcor images.
;-------------------------------------------------------------------------------
; 1. Uses a coordinate transform to a mk4-q like image. Need to find a better 
;    way to identify the phase angle.
;*** I am setting a variable called 'phase' to try to minimize coronal signal 
;    in unwanted polarization image.
;*** I HAVE ADDED A BIAS IN  TO HELP REMOVE DARK AREAS
;*** VIGNETTING IS OFF!!!!!!!
;*** USING ONLY FRACTION OF SKY POLARIZATION REMOVAL
;
; I am only removing sky from Q and U. Need to remove it from I as well 
; at a later date.
;
; 2. FUTURE: Alfred needs to add the Elmore calibration of Mk4 Opal 
; 3. Alfred still testing cameras to remove unwanted zeros in creating ncdf file
; 4. NEED TO STREAMLINE CODE AND MINIMIXE NUMBER OF INTERPOLATIONS
; 5. SPEED UP VIGNETTING BY using Giluiana's suggestion of creating a
; vignetting image and doing matrix multiplication to apply to image.
;
; ORDER OF PROCESSING: 
; 1. Apply Alfred's Demodulation Matrix
; 2. Find Image Centers for Each Camera
; 3. Apply Co-ordinate Transformation to get to Tangential (with respect to 
;    solar limb) Polarization ('mk4-q') and polarization 45 degrees from 
;    tangential ('mk4-u').
;    Ideally, tangential image will contain all corona + sky polarization and 
;    image polarized 45 deg.to tangential will contain only sky polarization.
;  
; FINAL CORONAL IMAGE: Only uses mk4-q like data. 
; There is still a small residual coronal signal in mk4-u like images 
; but they contain mostly noise.
;      
;--- HISTORY OF INSTRUMENT CHANGES THAT EFFECT CALIBRATION AND PROCESSING ---
;
; I have hardwired certain parameters to best process images
; acquired between Oct 2013 and present (May 2014)
; By 3rd week of Oct 2013 the instrument software was finally
; operating to give consistent sequences of polarization images
; by running socketcam continuously. Prior to that data may not be usable
; since we are not sure of the order of polarization states 
; CHANGES: 
; BZERO in header Oct 15, and Oct 31 =  2147483648 = 2^15
; OCCLTRID value changes. Prior to ??? it was 'OC-1'. 
; I believe this is occulter 1018.9". Need to verify.
; On Oct 15, the header value for modulator temperture is 512.0 deg C. 
; That's nuts. should be 35 deg C.
; Oct 20: Ben reports changing zero offset(BZERO). It was initially set at 
; 16 bit (65536, 32768)
;
; Other things to check: integrity of SGS values
;
;--- FUTURE: NEED TO CHECK OCCULTER SIZE AND EXPOSURE TO DETERMINE APPROPRIATE 
;    NCDF FILE.
;   CURRENTLY: Hardwired.
; Short cut could be to read date of file to determine which ncdf calibration 
; file to pick up
; As of now (May 2014) we have used 1 msec exposures as the standard since 
; the mk4 opal went in back in early November 2013 so all ncdf files so far 
; have same exposure.
; Occulters: There are 3 Kcor occulters. Dates of changes are: 

; r = 1018.9" occulter installed 30 October 2013 21:02 to 28 March 2014 16:59
; r = 1006.9"  installed for a few minutes only on 28 Jan 2014 01:09:13 
;              installed 28 March 2014 17:00:09 to 28 Apr 2014 16:42
; r = 996.1"   installed 28 April 2014 16:43:47
;------------------------------------------------------------------------------
; FUNCTIONS AND OTHER PROGRAMS CALLED: 
;------------------------------------------------------------------------------
; anytim2tai         (in /ssw/gen dir)
; anytim2jd          (in /ssw/gen dir)
; apply_dist         (tomczyk: in /acos/sw/idl/kcor/pipe dir)
; datecal            (sitongia; located in /acos/sw/idl/kcor/pipe directory)
; ephem2             (in /acos/sw/idl/gen dir)
; kcor_find_image    (tomczyk/detoma author, code is in: /acos/sw/idlkcor/pipe)
; kcor_radial_der    (tomczyk/detoma author, code is in: /acos/sw/idlkcor/pipe)
; fitshead2struct    (in ssw/gen dir)
; fitcircle          (meisner  in: /acos/sw/idlkcor/pipe)
; fshift             (in ssw/yohloh dir)
; jd_carr_long.pro   (in /acos/sw/idl/kcor/pipe dir)
; pb0r               (in ssw/gen dir)
;  
;  -------------------   RECORD OF PARAMETERS USED FOR VARIOUS DATES
;
;  ----- 31 OCT 2013  -----------------
;
; ncdf file:  20131031_cal_214306_kcor.ncdf created in May 2014
; Mk4-like transformation phase= !pi/24.    ; 8 deg.  
; Sky polarization amplitude: skyamp = .0035  
; Sky polarization phase:     skyphase = -1.*!pi/4.   ; -45  deg  
; Used image distortion test results of Oct 30, 2013 generated by Steve Tomczyk
; bias = 0.002     
; tv, bytscl(corona^0.8, min=-.05, max=0.15)      
; mini= 0.00    
; maxi= 0.08     
;------------------------------------------------------------------------------
; SYNTAX :
; kcorl1, date_string, list='list_of_L0_files', base_dir='base_directory_path'
; kcorl1, 'yyyymmdd', list='L0_list', base_dir='/hao/mlsodata1/Data/KCor/raw'
; 
; EXAMPLES:
; kcorl1, '20141101', list='list17'
; kcorl1, '20140731', list='doy212.ls', base_dir='/hao/mlsodata1/Data/KCor/work'
;
; The default base directory is '/hao/mlsodata1/Data/KCor/raw'.
; The base directory may be altered via the 'base_dir' keyword parameter.
;
; The L0 fits files need to be stored in the 'date' directory, 
; which is located in the base directory.
; The list file, containing a list of L0 files to be processed, also needs to
; be located in the 'date' directory.
; The name of the L0 FITS files needs to be specified via the 'list' 
; keyword parameter.
;
; All Level 1 files (fits & gif) will be stored in the sub-directory 'levelg',
; under the date directory.
;------------------------------------------------------------------------------
;-

pro kcorl1gg, date_str, list=list, base_dir=base_dir

;--- Define base directory and L0 directory.

IF NOT KEYWORD_SET (base_dir) THEN base_dir = '/hao/mlsodata1/Data/KCor/raw'

l0_dir   = base_dir + '/' + date_str
l1_dir   = l0_dir + '/levelg/'

IF (NOT FILE_TEST (l1_dir, /DIRECTORY)) THEN FILE_MKDIR, l1_dir

;--- Move to the processing directory.

cd, current=start_dir			; Save current directory.
cd, l0_dir				; Move to L0 processing directory

;--- Identify list of L0 files.

GET_LUN, ULIST
CLOSE,   ULIST

IF (KEYWORD_SET (list)) THEN $
BEGIN
   listfile = list   
END  $
ELSE $
BEGIN
   listfile = l0_dir + 'l0_list'

;   OPENW,   ULIST, listfile
;   PRINTF,  ULIST, 'test.fts'
;   CLOSE,   ULIST

   spawn, 'ls *kcor.fts* > l0_list'
END

;--- Open log file.

logfile = date_str + '_l1_' + listfile + '.log'
GET_LUN, ULOG
CLOSE,   ULOG
OPENW,   ULOG, l1_dir + logfile

;--- SELECT DEMODULATION MATRIX TO USE ---

cal_dir = '/hao/mlsodata1/Data/KCor/calib_files'
calfile = '20140310_cal_191609.ncdf'

; calfile = '20140310_cal_191609.ncdf'
; unit = ncdf_open('/hao/mlsodata1/Data/KCor/calib_files/20140310_cal_191609.ncdf')

; calfile = '20140508_175541_kcor_cal_1.0ms.ncdf'
; unit = ncdf_open('/hao/mlsodata1/Data/KCor/calib_files/20140508_175541_kcor_cal_1.0ms.ncdf')

; calfile = '20140620_201604_cal.ncdf'
; unit = ncdf_open('/hao/mlsodata1/Data/KCor/raw/20140620/20140620_201604_cal.ncdf')

; calfile = '20131031_cal_214306'
; unit = ncdf_open('/hao/mlsodata1/Data/KCor/raw/20131031/20131031_cal_214306_kcor.ncdf')

; calfile = '20141028_183928_kcor_cal_1.1ms.ncdf'
; unit = ncdf_open ('/hao/mlsodata1/Data/KCor/calib_files/20141028_183928_kcor_cal_1.1ms.ncdf')

;--- 2.5 msec data on Aug 29:
; calfile = '20140829_182714_kcor_cal_2.5ms.ncdf'
; unit = ncdf_open('/hao/mlsodata1/Data/KCor/raw/20140829/20140829_182714_kcor_cal_2.5ms.ncdf')

;-------------------------------------------------------------------------------
;--- Extract information from calibration file.
;-------------------------------------------------------------------------------

calpath = cal_dir + '/' + calfile
unit    = ncdf_open (calpath)

ncdf_varget, unit, 'Dark', dark_alfred
ncdf_varget, unit, 'Gain', gain_alfred
ncdf_varget, unit, 'Modulation Matrix', mmat
ncdf_varget, unit, 'Demodulation Matrix', dmat
ncdf_close, unit

; IN FUTURE: Check matrix for any elements > 1.0
; I am only printing matrix for one pixel.

print, 'Mod Matrix = camera 0'
print, reform (mmat(100, 100, 0, *, *))
print, 'Mod Matrix = camera 1'
print, reform (mmat(100, 100, 1, *, *))

;----------------------------------------------------------------------
; GdT: changed gain correction and moved it up (not inside the loop)
; this will change when we read the daily gain instead of a fixed one.
;----------------------------------------------------------------------

;  SET DIMENSIONS

xsize = 1024L
ysize = 1024L

; set zero and negative values in gain to value stored in gain_negative

gain_negative = -10
gain_alfred (WHERE (gain_alfred le 0, /NULL)) = gain_negative

; replace zero and negative values with mean of 5x5 neighbour pixels

FOR b = 0, 1 DO BEGIN
   gain_temp = double (reform(gain_alfred (*, *, b)))
   filter = mean_filter (gain_temp, 5, 5, invalid = gain_negative , missing=1)
   bad = WHERE (gain_temp eq gain_negative, nbad)
   IF nbad GT 0 THEN BEGIN 
      gain_temp (bad) = filter (bad)
      gain_alfred (*, *, b) = gain_temp
   ENDIF
ENDFOR

gain_temp = 0


;   gainshift = fltarr (1024, 1024, 2)

radius_guess = 178		; average radius for occulter.
print, 'radius_guess: ', radius_guess

;----------------------------------------------------------------------
;--- Find center and radius for gains.
;----------------------------------------------------------------------

center_info_gain0 = kcor_find_image (gain_alfred(*, *, 0), radius_guess)
center_info_gain1 = kcor_find_image (gain_alfred(*, *, 1), radius_guess)

; define coordinate arrays for gains

gxx0 = findgen (xsize,ysize) mod (xsize) - center_info_gain0 (0)
gyy0 = transpose(findgen(ysize,xsize)mod(ysize) ) - center_info_gain0(1)
gxx0 = double (gxx0)  &  gyy0 = double (gyy0)
grr0 = sqrt (gxx0^2. + gyy0^2.)  

gxx1 = findgen(xsize,ysize)mod(xsize) - center_info_gain1(0)
gyy1 = transpose(findgen(ysize,xsize)mod(ysize) ) - center_info_gain1(1)
gxx1 = double (gxx1)  &  gyy1 = double (gyy1)
grr1 = sqrt(gxx1^2. + gyy1^2.)  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;-------------------------------------------------------------------------------
; Initialize variables.
;-------------------------------------------------------------------------------

cal_data = fltarr (1024, 1024, 2, 3)

mini =  0.00     ;  USED THIS FOR OCTOBER 31, 2013
maxi =  0.08     ;  USED THIS FOR OCTOBER 31, 2013

set_plot, 'Z'
;set_plot, 'X'

l0_file = ''
fnum    = 0

;-------------------------------------------------------------------------------
; Image file loop.
;-------------------------------------------------------------------------------
OPENR,   ULIST, listfile

WHILE (not EOF (ULIST) ) DO $
BEGIN ;{
   readf, ULIST,   l0_file
   img = readfits (l0_file, header, /SILENT)
   img = float (img)

   fnum += 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT: the date is needed to compute the radius of the Sun 

;--- Read date of observation.

      dateobs = SXPAR (header, 'DATE-OBS') 

;--- Put the fits header into a structure.

   struct = fitshead2struct ((header), DASH2UNDERSCORE = dash2underscore)

;   window, 0, xs = 1024, ys = 1024, retain = 2
;   window, 0, xs = 1024, ys = 1024, retain = 2, xpos = 512, ypos = 512

   device, set_resolution=[1024,1024], decomposed=0, set_colors=256, $
           z_buffering=0
   erase

   TYPE = ''
   TYPE = fxpar (header, 'DATATYPE')

   PRINT,        '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'
   PRINTF, ULOG, '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'

   ;--- CURRENTLY PROCESSING ALL IMAGES  (commented out next line).

;   PRINT,        '--- CURRENTLY PROCESSING ALL IMAGES ---' 
;   PRINTF, ULOG, '--- CURRENTLY PROCESSING ALL IMAGES ---' 

;  IF (TYPE EQ 'science') THEN BEGIN

   ; ----------------------------------
   ;  SOLAR RADIUS, P and B ANGLE
   ; ---------------------------------
   
   ephem = pb0r (dateobs, /earth)
   pangle = ephem (0)      
   bangle = ephem (1)
   radsun = ephem (2)    ; arcmin

   ; ---------------------
   ;  PLATESCALE
   ; ---------------------
   ; Made PRELIMARY measurements of 3 occulter diameters to compute 
   ; first estimate of platescale.
   ; Largest occulter: radius = 1018.9" is 361 pixels in diameter,
   ; giving platescale = 5.64488" / pixel
   ; Medium occulter: radius = 1006.9" is 356.5 pixels in diameter,
   ; giving platescale = 5.64881" / pixel
   ; Smallest occulter: radius = 991.6" is 352 pixels in diameter,
   ; giving platescale = 5.63409" / pixel
   ; Avg value = 5.643 +/- 0.008" / pixel

   platescale = 5.643			; arcsec/pixel.

   ; ---------------------
   ; FIND SIZE OF OCCULTER
   ; ---------------------
   ; One occulter has 4 digits; Other two have 5. 
   ; Only read in 4 digits to avoid confusion.

   occulter_id = ''
   occulter_id = fxpar (header, 'OCCLTRID')
   occulter = strmid (occulter_id, 3, 5)
   occulter = float (occulter)
   IF (occulter eq 1018.0) THEN occulter = 1018.9
   IF (occulter eq 1006.0) THEN occulter = 1006.9

   PRINT, 'occulter size in arcsec = ', occulter
   PRINTF, ULOG, 'occulter size in arcsec = ', occulter

   radius_guess = occulter/platescale

;-------------------------------------------------------------------------------
; FIND IMAGE CENTER
;-------------------------------------------------------------------------------
 
;  FIND CENTER AND RADIUS FOR CAMERA 0
    
   center_info_img  = kcor_find_image (img (*, *, 0, 0), radius_guess, $
                                       /center_guess)
   xctr0 = center_info_img(0)
   yctr0 = center_info_img(1)
   radius_0 = center_info_img(2)

   xx0 = findgen (xsize,ysize) mod (xsize) - xctr0   
   yy0 = transpose (findgen (ysize,xsize) mod (ysize) ) - yctr0
   xx0 = double (xx0)  &  yy0 = double (yy0)
   rr0 = sqrt (xx0^2. + yy0^2.)
   pick0 = where (rr0 le radius_0 )

;   mask_occulter0 = fltarr (xsize, ysize)
;   mask_occulter0 (*) = 1.
;   mask_occulter0 (pick0) = 0.0 

   theta0 = (atan (-yy0,-xx0)) 
   theta0  = theta0 + !pi

; GdT: set pixels inside occulter to zero 
;      for s = 0, 3 do img (*, *, s, 0) = img (*, *,  s, 0) * mask_occulter0

;  FIND CENTER AND RADIUS FOR CAMERA 1

   center_info_img  = kcor_find_image (img (*, *, 0, 1),  radius_guess, /center_guess)
   xctr1 = center_info_img (0)
   yctr1 = center_info_img (1)
   radius_1 = center_info_img (2)

   xx1 = findgen (xsize,ysize) mod (xsize) - xctr1  
   yy1 = transpose (findgen (ysize,xsize) mod (ysize) ) - yctr1
   xx1 = double (xx1) &  yy1 = double (yy1)
   rr1 = sqrt (xx1^2. + yy1^2.)
   pick1 = where (rr1 le radius_1 )

;   mask_occulter1 = fltarr (xsize, ysize)
;   mask_occulter1 (*) = 1.
;   mask_occulter1 (pick1) = 0.0 

   theta1  = (atan (-yy1,-xx1)) 
   theta1  = theta1 + !pi

;  GdT: set pixels inside occulter to zero 
;   for s = 0, 3 do img (*, *, s, 1 ) =  img (*, *, s, 1) * mask_occulter1

;   GdT : GAIN IS NOT SHIFTED.
;   Build new gain to account for image shift.
;   Region of missing data is set to a constant for now.
;   It should be replaced with the values from the gain we took without
;   occulter in.

;-------------------------------------------------------------------------------
; GdT: replace missing data in gain images with shifted gain
; it should use special gain data taken with no occulter
;-------------------------------------------------------------------------------


   replace = WHERE (rr0 GT radius_0 -1. AND grr0 LE center_info_gain0 (2) +2., $
                    nrep)
   gain_temp = gain_alfred (*, *, 0)
   gain_replace = shift (gain_alfred (*, *, 0), $
                         xctr0 - center_info_gain0 (0), $
                         yctr0 - center_info_gain0 (1) )
   IF nrep GT 0 THEN gain_temp (replace) = gain_replace (replace)    ;gain_no_occulter0 (replace)
   gain_alfred (*, *, 0) = gain_temp
   gain_temp =  gain_alfred (*, *, 1)
   gain_replace = shift (gain_alfred (*, *, 1), $
                         xctr1 - center_info_gain1 (0), $
			 yctr1 - center_info_gain1 (1) )
   replace = WHERE (rr1 GT radius_1 -1. AND grr1 LE center_info_gain1 (2) +2. , nrep)
   IF nrep GT 0 THEN gain_temp (replace) = gain_replace (replace)   ; gain_no_occulter1 (replace)
   gain_alfred (*, *, 1) = gain_temp
   gain_temp    = 0
   gain_replace = 0

   FOR b = 0, 1 DO $
   BEGIN ;{

;  OLD CODE THAT WAS SHIFTING GAIN.

;--- Try to correct for camera drifts by shifting gain to image location 
;    for each camera.

;   center_info_gain = kcor_find_image (gain_alfred (*, *, b), radius_guess)

;   center_info_img  = kcor_find_image (img (*, *, 0, b), radius_guess, $
;                                            /center_guess)

;      shiftx_gain = center_info_img (0) - center_info_gain (0)
;      shifty_gain = center_info_img (1) - center_info_gain (1)
;      gainshift (*,*,b) = fshift (gain_alfred (*,*,b), shiftx_gain, shifty_gain)

      FOR s = 0, 3 DO $
      BEGIN ;{
        img(*,*,s,b) = (img(*,*,s,b) - dark_alfred (*,*,b)) / gain_alfred(*,*,b)
;        img(*,*,s,b) = (img(*,*,s,b) - dark_alfred (*,*,b)) / gainshift (*,*,b)
      ENDFOR ;}
   ENDFOR ;}

   ;--- APPLY DEMODULATION MATRIX TO GET I, Q, U images from each camera ---

   FOR b = 0, 1 DO BEGIN     
      FOR y = 0, 1023 DO BEGIN
         FOR x = 0, 1023 DO BEGIN
            cal_data (x,y,b,*) = reform (dmat(x,y,b,*, *))##reform(img(x,y,*,b))
         ENDFOR
      ENDFOR
   ENDFOR   

;-------------------------------------------------------------------------------
; GdT: find image center that will be used later when distorsion is applied
;-------------------------------------------------------------------------------

   image0 = reform (img (*, *, 0, 0))
   image0 = reverse (image0, 2)
   image1 = reform (img (*, *, 0, 1))

   restore, '/home/iguana/idl/kcor/dist_coeff.sav'
   dat1 = image0 
   dat2 = image1 
   apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c

   image0 = dat1
   image1 = dat2
   center0_info_new = kcor_find_image (image0, radius_guess, /center_guess)
   center1_info_new = kcor_find_image (image1, radius_guess, /center_guess)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;   tv, bytscl(cal_data(*, *, 0, 1), min = -.5, max = 0.5)
;   save = tvrd()
;   write_gif, '20140508_caldata01_20140508_175541cal_shiftedgain.gif', save
;   tv, bytscl(cal_data(*, *, 1, 1), min = -.5, max = 0.5)
;   save = tvrd()
;   write_gif, '20140508_caldata11_20140508_175541cal_shiftedgain.gif', save
;   tv, bytscl(cal_data(*, *, 0, 2), min = -0.5, max = 0.5)
;   save = tvrd()
;   write_gif, '20140508_caldata02_20140508_175541cal_shiftedgain.gif', save
;   tv, bytscl(cal_data(*, *, 1, 2), min = -.5, max = 0.5)
;   save = tvrd()
;   write_gif, '20140508_caldata12_20140508_175541cal_shiftedgain.gif', save

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT : do not need to recompute center after demodulation
;
;   ;--- FIND CENTERS AND RADIUS OF OCCULTER BEFORE DISTORTION CORRECTION ---
;   ;
;   ;--- CAMERA 0:
;
;   center_info = kcor_find_image (cal_data (*, *, 0, 0), radius_guess, $
;                                  /center_guess)
;
;   PRINT,  'Camera 0 center info AFTER DEMODULATION & BEFORE DISTORTION : ', $
;           center_info
;   PRINTF, ULOG, $
;           'Camera 0 center info AFTER DEMODULATION & BEFORE DISTORTION : ', $
;           center_info
;   xctr0 = center_info (0)
;   yctr0 = center_info (1)
;   radius_1 = center_info (2)
;
;   ;--- CAMERA 1:
;
;   center_info = kcor_find_image (cal_data (*, *, 1, 0), radius_guess, $
;                                  /center_guess)
;
;   PRINT,  'Camera 1 center info AFTER DEMODULATION & BEFORE DISTORTION : ', $
;           center_info
;   PRINTF, ULOG, $
;           'Camera 1 center info AFTER DEMODULATION & BEFORE DISTORTION : ', $
;           center_info
;
;   xctr1 = center_info (0)
;   yctr1 = center_info (1)
;   radius_2 = center_info (2)
;
;   PRINT,        'center and radius of occulter BEFORE distortion correction:'
;   PRINT,        '(cam0x, cam0y, radius0), (cam1x, cam1y, radius1) : ', $
;                 xctr0, yctr0, radius_1, xctr1, yctr1, radius_2
;   PRINTF, ULOG, 'center and radius of occulter BEFORE distortion correction:'
;   PRINTF, ULOG, '(cam0x, cam0y, radius0), (cam1x, cam1y, radius1) : ', $
;                 xctr0, yctr0, radius_1, xctr1, yctr1, radius_2
;
;   ;--- Before I do Coordinate transformation I want to save camera 0 & 1 'q'.

   sub1 = cal_data (*, *, 0, 1) - cal_data (*, *, 0, 2)
   sub2 = cal_data (*, *, 1, 2) - cal_data (*, *, 1, 1)

   ;--------------------  COORDINATE TRANSFORMATION ----------------------------
   ;
   ; CREATE MK4-like U image (one containing no coronal polarization)
   ; mk4 detector was parallel to the solar limb, rotating with the Sun. 
   ; Q polarization was defined as tangential - radial since the detector 
   ; was in this coordinate system.
   ; U was rotated 45 degrees to Q and contained all unwanted polarization 
   ; (sky, instrument).
   ;----------------------------------------------------------------------------

   umk4_0 = fltarr (1024, 1024)    ; camera 0
   qmk4_0 = fltarr (1024, 1024)    ; camera 0
   umk4_1 = fltarr (1024, 1024)    ; camera 1
   qmk4_1 = fltarr (1024, 1024)    ; camera 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT : the code below is replaced by array operations
;
;   theta0 = dblarr(1024, 1024)
;
;   ; Define theta as follows: theta = zero is the positive x axis and y = 0 
;   ; (quadrant 1) and angle direction goes CCW through 360 degrees. 
; 
;   ;--- CAMERA 0:
;
;   FOR y = 0, 1023  do begin
;      FOR x = 0, 1023 do begin
;	 IF (x-xctr0 eq 0) THEN BEGIN
;	    IF (y - yctr0 lt 0) THEN theta0 (x, y) = 3.0 * !pi / 2.0
;	    IF (y - yctr0 gt 0) THEN theta0 (x, y) = !pi / 2.0
;         ENDIF ELSE BEGIN
;            IF (x - xctr0 gt 0) and (y - yctr0 gt 0) THEN $
;	       theta0 (x, y) = atan((y - yctr0) / (x - xctr0))
;            IF (x - xctr0 lt 0) and (y - yctr0 gt 0) THEN $
;	       theta0 (x, y) = atan((y - yctr0) / (x - xctr0)) + !pi
;            IF (x - xctr0 lt 0) and (y - yctr0 lt 0) THEN $
;	       theta0 (x, y) = atan((y - yctr0) / (x - xctr0)) + !pi
;            IF (x - xctr0 gt 0) and (y - yctr0 lt 0) THEN $
;	       theta0 (x, y) = atan ((y - yctr0) / (x - xctr0)) + 2*!pi
;         ENDELSE
;
;         ; ADD A PHASE ANGLE TO REMOVE OR MINIMIZE CORONAL SIGNAL IN 'U' IMAGE.
;         ; Phase used before image distortion (!p1/8.) doesn't work on images 
;         ; that have been flipped, shifted and image-distortion corrected.
;         ; Phase in radians where 1 radian = 57.296 degrees.
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   GdT: I think these phases should be zero. I leave them unchanged for now 


   phase0 = !pi / 11.       ; camera 0   16. degrees look ok for 18 Jun 2014 
	 		    ; and April 27, 2014
   phase1 = -1. * !pi / 9.  ; camera 1  -20. degrees look ok for 27 Apr 2014

;phase0 = 0
;phase1 = 0

;
;   phase =  -1.*!pi/32.;  -5.5 deg
;   phase =  !pi/24.    ;   8 deg.  ; USED THIS FOR OCTOBER 31, 2013
;   phase =  !pi/48.    ;   4 deg.  ; USED THIS FOR OCTOBER 31, 2013
;   phase =  !pi/11.    ;  16 deg
;   phase =  !pi/8.     ;  22.5 deg
;   phase =  !pi/4.     ;  45 deg.
;   phase =  3*!pi/8.   ;  67.5 deg
;   phase =  !pi/2.     ;  90. deg
;   phase =  !pi        : 180 deg.
;   phase = 3*!pi/2.    ; 270 deg.
;
;   qmk4_0 (x, y) = cal_data (x, y, 0, 1) * sin(2.*theta0(x, y) + phase0) $
;                 + cal_data (x, y, 0, 2) * cos(2.*theta0(x, y) + phase0)
;   umk4_0 (x, y) = cal_data (x, y, 0, 1) * cos(2.*theta0(x, y) + phase0) $
;                 - cal_data (x, y, 0, 2) * sin(2.*theta0(x, y) + phase0)
;   qmk4_0 (x, y) = float (-1.0 * qmk4_0 (x, y))
;   umk4_0 (x, y) = float (umk4_0 (x, y))
;  
;   ; Fix sign to get coordinate system to match alfred's definition 
;   ; of demodulation analysis.
;
;      ENDFOR
;   ENDFOR
;
;   tv, bytscl (theta0, min = -5., max = 5.)
;   save = tvrd ()
;   write_gif, 'theta.gif', save
;
;   umk4_0 = float (umk4_0)
;
;   ;--- CAMERA 1:
; 
;   FOR y = 0, 1023  do begin
;      FOR x = 0, 1023 do begin
;	 IF (x-xctr1 eq 0) THEN BEGIN
;	    IF (y-yctr1 lt 0) THEN theta = 3.0 * !pi / 2.0
;	    IF (y-yctr1 gt 0) THEN theta = !pi / 2.0
;	 ENDIF ELSE BEGIN
;            IF (x-xctr1 gt 0) and (y-yctr1 gt 0) THEN $
;	       theta = atan ((y-yctr1) / (x-xctr1))
;            IF (x-xctr1 lt 0) and (y-yctr1 gt 0) THEN $
;	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
;            IF (x-xctr1 lt 0) and (y-yctr1 lt 0) THEN $
;	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
;            IF (x-xctr1 gt 0) and (y-yctr1 lt 0) THEN $
;	       theta = atan ((y-yctr1) / (x-xctr1)) + 2*!pi
;	 ENDELSE
;
;         qmk4_1 (x, y) = -cal_data (x, y, 1, 1) * sin (2.*theta + phase1) $
;	               +  cal_data (x, y, 1, 2) * cos (2.*theta + phase1)
;         umk4_1 (x, y) =  cal_data (x, y, 1, 1) * cos (2.*theta + phase1) $
;	               +  cal_data (x, y, 1, 2) * sin (2.*theta + phase1)
;         qmk4_1 (x, y) = float (-1.0 * qmk4_1 (x, y))
;         umk4_1 (x, y) = float (umk4_1 (x, y))
;      ENDFOR
;   ENDFOR
;
;   cal_data (*, *, 0, 1) = qmk4_0
;   cal_data (*, *, 0, 2) = umk4_0
;   cal_data (*, *, 1, 1) = qmk4_1
;   cal_data (*, *, 1, 2) = umk4_1
;
;  ; Save individual coordinate transformed images before sky polarization 
;  ; is removed: 
;
;   tv, bytscl (umk4_0, min = -.5, max = 0.5)
;   save = tvrd ()
;   write_gif, '20140427_umk4_0.gif', save
;   tv, bytscl (qmk4_0, min = -.5, max = 0.5)
;   save = tvrd ()
;   write_gif, '20140427_qmk4_0.gif', save
;   tv, bytscl (qmk4_1, min = -0.5, max = 0.5)
;   save = tvrd ()
;   write_gif, '20140427_qmk4_1.gif', save
;   tv, bytscl (umk4_1, min = -.5, max = 0.5)
;   save = tvrd ()
;   write_gif, '20140427_umk4_1.gif', save

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  GdT: NEW CODE FOR COORDINATE TRANSFORMATION

   ;--- CAMERA 0:

   qmk4_0 = cal_data (*, *, 0, 1) * sin (2.*theta0 + phase0) $
	  + cal_data (*, *, 0, 2) * cos (2.*theta0 + phase0)
   umk4_0 = cal_data (*, *, 0, 1) * cos (2.*theta0 + phase0) $
          - cal_data (*, *, 0, 2) * sin (2.*theta0 + phase0)
   qmk4_0 = float (-1.0 * qmk4_0 )
   umk4_0 = float (umk4_0)

   cal_data (*, *, 0, 1) = qmk4_0
   cal_data (*, *, 0, 2) = umk4_0

   ;--- CAMERA 1:
 
   qmk4_1 = - cal_data (*, *, 1, 1) * sin (2.*theta1 + phase1) $
            + cal_data (*, *, 1, 2) * cos (2.*theta1 + phase1)
   umk4_1 =   cal_data (*, *, 1, 1) * cos (2.*theta1 + phase1) $
            + cal_data (*, *, 1, 2) * sin (2.*theta1 + phase1)
   qmk4_1 = float (-1.0 * qmk4_1 )
   umk4_1 = float (umk4_1)

   cal_data (*, *, 1, 1) = qmk4_1
   cal_data (*, *, 1, 2) = umk4_1



   ;--- SKY POLARIZATION REMOVAL ON COORDINATE TRANSFORMED DATA ---
   ;
   ; Extract an annulus of data from 2.4 to 2.8 solar radii in order to 
   ; determine the sky polarization which should have a sin20 dependence.
   ; Use the outer FOV to avoid coronal signals.
   ; Avg over all heights in this annulus at each degree around the sun
   ; and then fit to a sin 20 function.
   ; Do this for both cameras.
   ; ---------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT: this code is replaced to avoid loop
;
;   angle0   = fltarr (360)
;   angle1   = fltarr (360)
;   counter0 = fltarr (360)
;   counter1 = fltarr (360)
;
;   ; Use solar radius = 960 arcsec 
;   ; KCor platescale = 5.643 arcsec / pixel
;
;   r_in  = 2.4 * 960.0 / 5.643
;   r_out = 2.8 * 960.0 / 5.643
;
;   ; Extract annulus and average all heights at 1 degree increments 
;   ; around the sun.
;
;   FOR y = 0, 1023 DO BEGIN
;      FOR x = 0, 1023 DO BEGIN
; 
;         ;--- camera 0:
;
;	 IF (x-xctr0 eq 0) THEN BEGIN
;	    IF (y-yctr0 lt 0) THEN theta = 3.*!pi/2.
;	    IF (y-yctr0 gt 0) THEN theta = !pi/2.
;	 ENDIF ELSE BEGIN
;            IF (x-xctr0 gt 0) and (y-yctr0 gt 0) THEN $
;	       theta = atan ((y-yctr0) / (x-xctr0))
;            IF (x-xctr0 lt 0) and (y-yctr0 gt 0) THEN $
;	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
;            IF (x-xctr0 lt 0) and (y-yctr0 lt 0) THEN $
;	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
;            IF (x-xctr0 gt 0) and (y-yctr0 lt 0) THEN $
;	       theta = atan ((y-yctr0) / (x-xctr0)) + 2*!pi
;	 ENDELSE
;
;         ;--- Convert from radians to degrees. 
;
; 	 thetadeg = fix (theta * 57.2957795)
;         rad0 = sqrt((x-xctr0)^2 + (y-yctr0)^2)
;         IF (rad0 ge r_in and rad0 le r_out) THEN BEGIN 
;	    angle0 (thetadeg)   = angle0 (thetadeg) + umk4_0 (x, y)
;	    counter0 (thetadeg) = counter0 (thetadeg) + 1
;         ENDIF
;
;         ;--- camera 1:
;
;         IF (x-xctr1 eq 0) THEN BEGIN
;	    IF (y-yctr1 lt 0) THEN theta = 3.*!pi/2.
;	    IF (y-yctr1 gt 0) THEN theta = !pi/2.
;	 ENDIF ELSE BEGIN
;            IF (x-xctr1 gt 0) and (y-yctr1 gt 0) THEN $
;	       theta = atan ((y-yctr1)/(x-xctr1))
;            IF (x-xctr1 lt 0) and (y-yctr1 gt 0) THEN $
;	       theta = atan ((y-yctr1)/(x-xctr1)) + !pi
;            IF (x-xctr1 lt 0) and (y-yctr1 lt 0) THEN $
;	       theta = atan ((y-yctr1)/(x-xctr1)) + !pi
;            IF (x-xctr1 gt 0) and (y-yctr1 lt 0) THEN $
;	       theta = atan ((y-yctr1)/(x-xctr1)) + 2*!pi
;	 ENDELSE
;
;         ;--- Convert from radians to degrees. 
;
; 	 thetadeg = fix (theta * 57.2957795)
;         rad1 = sqrt ((x-xctr1)^2 + (y-yctr1)^2)
;
;         IF (thetadeg ge 360) THEN PRINT, 'Theta > =  360 degrees'
;         IF (thetadeg lt 0)   THEN PRINT, 'Theta < zero degrees'
;
;         IF (rad1 GE r_in AND rad1 LE r_out) THEN BEGIN 
;            angle1 (thetadeg)   = angle1 (thetadeg) + umk4_1 (x, y)
;            counter1 (thetadeg) = counter1 (thetadeg) + 1
;         ENDIF
;
;      ENDFOR
;   ENDFOR
;
;   ; GENERATE THE AVERAGE VALUE AT EACH ANGLE:
;
;   FOR a = 0, 359 DO BEGIN
;      IF (counter0 (a) NE 0) THEN angle0 (a) = angle0 (a) / counter0 (a)
;      IF (counter1 (a) NE 0) THEN angle1 (a) = angle1 (a) / counter1 (a)
;      IF (counter0 (a) EQ 0 OR counter1 (a) EQ 0) then $
;      BEGIN ;{
;         PRINT,        ' There is no data at this angle: ', a, ' !!!!'
;         PRINTF, ULOG, ' There is no data at this angle: ', a, ' !!!!'
;      END   ;}
;   ENDFOR
;
;   ;--- Plot radially averaged 360 deg.
;
;   degrees = findgen (360) 
;
;   ; REMOVE SINE (2*THETA)  SKY POLARIZATION:
;   ; ------------  FIT A SINE 2*theta to the 'mk4-u' images from camera 0 
;   ; and camera 1. This should be the signature
;   ; of the sky polarization in the data that needs to be removed. 
;
;   a = fltarr (3)   ;  coefficients for sine(2*theta) fit
;   b = fltarr (3)   ;  coefficients for sine(theta) fit
;
;   ; Initialize guess.
;
;   a (0) =  0.02    
;   a (1) = 20.0
;   a (2) =  0.001
;   b (0) =  0.002
;   b (1) = -0.6
;   b (2) =  0.001
;
;   weights     = fltarr (360)
;   weights (*) = 1.0
;   
;   ;---  Save sky polarization correction as an array.
;
;   sky_polar0 = dblarr (1024, 1024)
;   sky_polar1 = dblarr (1024, 1024)
;
;   bias = 0.07
;
;   ; CAMERA 0:  Fit SINE 2*THETA sky polarization from mk4u images 
;   ; and REMOVE from mk4u and mk4q images;
;  
;   sky_polar_cam0 = curvefit (degrees, angle0, weights, a, $
;                              FUNCTION_NAME = 'sine2theta') 
;   PRINT,        'fits to sine 2 theta curve : ', a
;   PRINTF, ULOG, 'fits to sine 2 theta curve : ', a
;
;   FOR y = 0, 1023 do begin
;      FOR x = 0, 1023 do begin
;         IF (x-xctr0 eq 0) THEN BEGIN
;	    IF (y-yctr0 lt 0) THEN theta = 3.*!pi/2.
;	    IF (y-yctr0 gt 0) THEN theta = !pi/2.
;	 ENDIF ELSE BEGIN
;            IF (x-xctr0 gt 0) AND (y-yctr0 gt 0) THEN $
;               theta = atan ((y-yctr0) / (x-xctr0))
;            IF (x-xctr0 lt 0) AND (y-yctr0 gt 0) THEN $
;               theta = atan ((y-yctr0) / (x-xctr0)) + !pi
;            IF (x-xctr0 lt 0) AND (y-yctr0 lt 0) THEN $
;               theta = atan ((y-yctr0) / (x-xctr0)) + 2*!pi
;	 ENDELSE
;         sky_polar0 (x, y) = a (0) * double (sin (2 * theta + a (1)) + a (2))
;      ENDFOR
;   ENDFOR
;
;   qmk4_0 = qmk4_0 + bias  - 0.5 * sky_polar0
;   umk4_0 = umk4_0 + bias  - 0.5 * sky_polar0
;
;   qmk4_0 = qmk4_0 + bias  - 0.8 * sky_polar0
;   umk4_0 = umk4_0 + bias  - 0.8 * sky_polar0
;   qmk4_0 = qmk4_0 - sky_polar0
;   umk4_0 = umk4_0 - sky_polar0
;
;   help, sky_polar_cam0
;   help, sky_polar0
;
;    tv, bytscl (qmk4_0, min = -.54, max = 0.56)
;    save = tvrd ()
;    write_gif, 'qmk4_0_rm_skypol.gif', save
;   tv, bytscl (umk4_0, min = -0.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'umk4_0_rm_skypol.gif', save
;    tv, bytscl (sky_polar0, min = -0.54, max = 0.56)
;    save = tvrd ()
;    write_gif, 'sky_polar0.gif', save
;
;
;   ; CAMERA 1:  Fit SINE 2*THETA sky polarization from mk4u images 
;   ; and REMOVE from mk4u and mk4q images;
;
;   sky_polar_cam1 = curvefit (degrees, angle1, weights, a, $
;                              FUNCTION_NAME = 'sine2theta')
;   PRINT,        'fits to sine 2 theta curve : ', a
;   PRINTF, ULOG, 'fits to sine 2 theta curve : ', a
;
;   FOR y = 0, 1023 DO BEGIN
;      FOR x = 0, 1023 DO BEGIN
;         IF (x-xctr1 EQ 0) THEN BEGIN
;	    IF (y-yctr1 LT 0) THEN theta = 3.*!pi/2.
;	    IF (y-yctr1 GT 0) THEN theta = !pi/2.
;         ENDIF ELSE BEGIN
;            IF (x-xctr1 GT 0) AND (y-yctr1 GT 0) THEN $
;               theta = atan ((y-yctr1) / (x-xctr1))
;            IF (x-xctr1 LT 0) AND (y-yctr1 GT 0)THEN $
;               theta = atan ((y-yctr1) / (x-xctr1)) + !pi
;            IF (x-xctr1 LT 0) AND (y-yctr1 LT 0) THEN $
;               theta = atan ((y-yctr1) / (x-xctr1)) + !pi
;            IF (x-xctr1 gt 0) AND (y-yctr1 LT 0) THEN $
;	       theta = atan ((y-yctr1) / (x-xctr1)) + 2*!pi
;	 ENDELSE
;         sky_polar1 (x, y) = a (0) * double (sin (2*theta + a(1)) + a(2))
;      ENDFOR
;   ENDFOR
;
;   qmk4_1 = qmk4_1 + bias - 0.5 * sky_polar1
;   umk4_1 = umk4_1 + bias - 0.5 * sky_polar1
;
;;   qmk4_1 = qmk4_1 - sky_polar1
;;   umk4_1 = umk4_1 - sky_polar1
;
;   tv, bytscl (qmk4_1, min = -0.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'qmk4_1_rm_skypol.gif', save
;   tv, bytscl (umk4_1, min = -0.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'umk4_1_rm_skypol.gif', save
;   tv, bytscl (sky_polar1, min = -0.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'sky_polar1.gif', save

;   plot, degrees, angle0, title = 'Camera 0; MK4-like U image; Radially averaged intensity (2.4 to 2.8 Rsun) 1 deg. increments'
;   oplot, sky_polar_cam0, linestyle = 5, thick = 2
;   save = tvrd ()
;   write_gif, 'cam0_mk4u_annulus_sine20.gif', save
;   plot, degrees, angle1, title = 'Camera 1; MK4-like U image; Radially averaged intensity (2.4 to 2.8 Rsun) 1 deg. increments'
;   oplot, sky_polar_cam1, linestyle = 5, thick = 2
;   save = tvrd ()
;   write_gif, 'cam1_mk4u_annulus_sine20.gif', save

;-------------------------------------------------------------------------------
;  GdT: NEW CODE FOR SIN2THETA .
;-------------------------------------------------------------------------------

   angle_ave_u0 = dblarr (360)
   angle_ave_u1 = dblarr (360)

   ; Use solar radius, radsun * 60 = radius in arcsec
   ; KCor platescale = 5.643 arcsec / pixel

   r_in  = 2.4 * radsun * 60. / 5.643
   r_out = 2.8 * radsun * 60. / 5.643

   ; Extract annulus and average all heights at 1 degree increments 
   ; around the sun.

; Make new theta arrays in degrees.

   theta0_deg = theta0 * !radeg
   theta1_deg = theta1 * !radeg

   FOR i = 0, 359 DO BEGIN ;{
      angle = float (i)
      pick0 = WHERE (rr0 GE r_in AND rr0 LE r_out AND theta0_deg GE angle $
                     AND theta0_deg LT angle +1., nnl0)
      IF nnl0 GT 0 THEN angle_ave_u0 (i) = mean (umk4_0 (pick0))
      pick1 = WHERE (rr1 GE r_in AND rr1 LE r_out AND theta1_deg GE angle $
                     AND theta1_deg LT angle +1., nnl1) 
      IF nnl1 GT 0 THEN angle_ave_u1 (i) = mean ( umk4_1(pick1))
   ENDFOR  ;}

   degrees = findgen (360) + 0.5

   ; REMOVE SINE (2*THETA)  SKY POLARIZATION:
   ; ------------  FIT A SINE 2*theta to the 'mk4-u' images from camera 0 
   ; and camera 1. This should be the signature
   ; of the sky polarization in the data that needs to be removed. 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; a is now a 2D array
; initial guesses have been changed (values for camera 0 and 1 have opposite sign)

   a = fltarr (2)               ;  coefficients for sine(2*theta) fit

   weights     = fltarr (360)
   weights (*) = 1.0
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  GdT: LEFT bias to avoid image to be too dark in the outer fov
;  for proper calibration the bias should be set to 0

   bias = 0.07

   ; CAMERA 0:  Fit SINE 2*THETA sky polarization from mk4u images 
   ; and REMOVE from mk4u and mk4q images;

   ; Initialize guess.

   a(0) = -0.013 
   a(1) = -0.25
 
   sky_polar_cam0 = curvefit (degrees, angle_ave_u0, weights, a, $
                              FUNCTION_NAME = 'sine2theta_new') 
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT :  Saved sky polarization correction as arrays
;        the correction for Q has been shifted by 45deg according to
;        D. Elmore notes 

   sky_polar0_u0 = a(0) * double (sin (2.0 * theta0 + a (1)) )
   sky_polar0_q0 = a(0) * double (sin (2.0 * theta0 + 90. / !radeg + a (1)) )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT: left 0.5 scaling to avoid going negative
;      this should be 1.0

   qmk4_0 = qmk4_0 + bias  - 0.5 * sky_polar0_q0
   umk4_0 = umk4_0 + bias  - 0.5 * sky_polar0_u0

   ; CAMERA 1:  Fit SINE 2*THETA sky polarization from mk4u images 
   ; and REMOVE from mk4u and mk4q images;

   ; Initialize guess.

   a(0) = 0.013
   a(1) = 0.25

   sky_polar_cam1 = curvefit (degrees, angle_ave_u1, weights, a, $
                              FUNCTION_NAME = 'sine2theta_new')

   sky_polar1_u1  = a(0) * double (sin (2.0 * theta1 + a (1)))
   sky_polar1_q1  = a(0) * double (sin (2.0 * theta1 - 90. / !radeg + a (1))) 
 
   qmk4_1 = qmk4_1 + bias - 0.5 * sky_polar1_q1
   umk4_1 = umk4_1 + bias - 0.5 * sky_polar1_u1


;---------------------------------------------------------------------
   ; I AM CURRENTLY NOT DOING THE SINE THETA FIT ... 
   ; ITS VERY NOISY IN THE CURRENT PROCESSING SCHEME.
;    Set dosinetheta = 1 to run the sine theta fit

   dosinetheta = 0
   IF (dosinetheta EQ 1) THEN BEGIN

   ; Extract another annulus after sine 20 sky polarization removal 
   ; and average all heights at 1 degree increments around the sun.

   FOR y = 0, 1023 DO BEGIN
      FOR x = 0, 1023 DO BEGIN

   ; camera 0:

         IF (x-xctr0 EQ 0) THEN BEGIN
	    IF (y-yctr0 LT 0) THEN theta = 3. * !pi / 2.
	    IF (y-yctr0 GT 0) THEN theta = !pi / 2.
	 ENDIF ELSE BEGIN
            IF (x-xctr0 GT 0) AND (y-yctr0 GT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0))
            IF (x-xctr0 LT 0) AND (y-yctr0 GT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
            IF (x-xctr0 LT 0) AND (y-yctr0 LT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
            IF (x-xctr0 GT 0) AND (y-yctr0 LT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + 2*!pi
	 ENDELSE

         ;--- Convert from radians to degrees.

 	 thetadeg = fix (theta * 57.2957795)
         rad0 = sqrt ((x-xctr0)^2 + (y-yctr0)^2)
         IF (rad0 GE r_in AND rad0 LE r_out) THEN BEGIN 
	    angle0 (thetadeg) = angle0 (thetadeg) + umk4_0 (x, y)
	    counter0 (thetadeg) = counter0 (thetadeg) + 1
         ENDIF

         ; camera 1:

	 IF (x-xctr1 EQ 0) THEN BEGIN
	    IF (y-yctr1 LT 0) THEN theta = 3.*!pi/2.
	    IF (y-yctr1 GT 0) THEN theta = !pi/2.
	 ENDIF ELSE BEGIN
            IF (x-xctr1 GT 0) AND (y-yctr1 GT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1))
            IF (x-xctr1 LT 0) AND (y-yctr1 GT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
            IF (x-xctr1 LT 0) AND (y-yctr1 LT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
            IF (x-xctr1 GT 0) AND (y-yctr1 LT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + 2*!pi
	 ENDELSE

         ;--- Convert from radians to degrees.

 	 thetadeg = fix (theta*57.2957795)
         rad1 = sqrt ((x-xctr1)^2 + (y-yctr1)^2)
         IF (rad1 GE r_in AND rad1 LE r_out) THEN BEGIN 
	    angle1 (thetadeg)   = angle1 (thetadeg) + umk4_1 (x, y)
            counter1 (thetadeg) = counter1 (thetadeg) + 1
         ENDIF

      ENDFOR
   ENDFOR

   b = fltarr (3)               ;  coefficients for sine(theta) fit

;   plot, angle1

   ;--- Generate the average value at each angle:

   FOR a = 0, 359 DO BEGIN
      IF (counter0 (a) NE 0) THEN angle0 (a) = angle0 (a) / counter0 (a)
      IF (counter1 (a) NE 0) THEN angle1 (a) = angle1 (a) / counter1 (a)
      IF (counter0 (a) EQ 0 OR counter1 (a) EQ 0) THEN $
      BEGIN ;{
         PRINT,        ' There is no data at this angle: ', a, ' !!!!'
         PRINTF, ULOG, ' There is no data at this angle: ', a, ' !!!!'
      END   ;}
   ENDFOR

   ; CAMERA 0:  Fit SINE THETA sky polarization from mk4u images 
   ; and REMOVE from mk4u and mk4q images;
  
   sky_polar_cam0 = curvefit (degrees, angle0, weights, b, $
                              FUNCTION_NAME = 'sinetheta') 
   PRINT,        'fits to sine theta curve : ', b
   PRINTF, ULOG, 'fits to sine theta curve : ', b

   FOR y = 0, 1023 DO BEGIN
      FOR x = 0, 1023 DO BEGIN
         IF (x-xctr0 EQ 0) THEN BEGIN
	    IF (y-yctr0 LT 0) THEN theta = 3. * !pi / 2.
	    IF (y-yctr0 GT 0) THEN theta = !pi / 2.
	 ENDIF ELSE BEGIN
            IF (x-xctr0 GT 0) AND (y-yctr0 GT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0))
            IF (x-xctr0 LT 0) AND (y-yctr0 GT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
            IF (x-xctr0 LT 0) AND (y-yctr0 LT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + !pi
            IF (x-xctr0 GT 0) AND (y-yctr0 LT 0) THEN $
	       theta = atan ((y-yctr0) / (x-xctr0)) + 2*!pi
	 ENDELSE
         sky_polar0 (x, y) = b (0) * sin (theta + b (1)) + b (2) * theta
      ENDFOR
   ENDFOR

;   qmk4_0 = qmk4_0 - sky_polar0
;   umk4_0 = umk4_0 - sky_polar0

;   tv, bytscl (qmk4_0, min = -.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'qmk4_0_rm_skypol.gif', save
;   tv, bytscl (umk4_0, min = -.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'umk4_0_rm_skypol.gif', save


   ; CAMERA 1:  Fit SINE THETA sky polarization from mk4u images 
   ; and REMOVE from mk4u and mk4q images;

   sky_polar_cam1 = curvefit (degrees, angle1, weights, b, $
                              FUNCTION_NAME = 'sinetheta')

   PRINT,        'fits to sine theta curve : ', b
   PRINTF, ULOG, 'fits to sine theta curve : ', b

   FOR y = 0, 1023 DO BEGIN
      FOR x = 0, 1023 DO BEGIN
         IF (x-xctr1 EQ 0) THEN BEGIN
	    IF (y-yctr1 LT 0) THEN theta = 3.*!pi/2.
	    IF (y-yctr1 GT 0) THEN theta = !pi/2.
	 ENDIF ELSE BEGIN
            IF (x-xctr1 GT 0) AND (y-yctr1 GT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1))
            IF (x-xctr1 LT 0) AND (y-yctr1 GT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
            IF (x-xctr1 LT 0) AND (y-yctr1 LT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + !pi
            IF (x-xctr1 GT 0) AND (y-yctr1 LT 0) THEN $
	       theta = atan ((y-yctr1) / (x-xctr1)) + 2*!pi
	 ENDELSE
         sky_polar1 (x, y) = b (0) * sin (theta + b (1)) + b (2) * theta
      ENDFOR
   ENDFOR

   qmk4_1 = qmk4_1 - sky_polar1
   umk4_1 = umk4_1 - sky_polar1

;   tv, bytscl (qmk4_1, min = -.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'qmk4_1_rm_skypol.gif', save
;   tv, bytscl (umk4_1, min = -.54, max = 0.56)
;   save = tvrd ()
;   write_gif, 'umk4_1_rm_skypol.gif', save
;
;   tv, bytscl (sky_polar0, min = -.10, max = 0.10)
;   save = tvrd ()
;   write_gif, 'skypolarization_cam0.gif', save
;   tv, bytscl (sky_polar1, min = -.10, max = 0.10)
;   save = tvrd ()
;   write_gif, 'skypolarization_cam1.gif', save

;   plot, degrees, angle0, title = 'Camera 0; MK4-like U image; Radially averaged intensity (2.4 to 2.8 Rsun) 1 deg. increments'
;   oplot, sky_polar_cam0, linestyle = 5, thick = 2
;   save = tvrd ()
;   write_gif, 'cam0_mk4u_annulus.gif', save
;   plot, degrees, angle1, title = 'Camera 1; MK4-like U image; Radially averaged intensity (2.4 to 2.8 Rsun) 1 deg. increments'
;   oplot, sky_polar_cam1, linestyle = 5, thick = 2
;   save = tvrd ()
;   write_gif, 'cam1_mk4u_annulus.gif', save

   ENDIF

   ;--- END OF SINE THETA FIT.
;---------------------------------------------------------------------

   cal_data (*, *, 0, 1) = qmk4_0
   cal_data (*, *, 0, 2) = umk4_0
   cal_data (*, *, 1, 1) = qmk4_1
   cal_data (*, *, 1, 2) = umk4_1

   ;----- END SKY POLARIZATION PLOTS FOR COORDINATE TRANSFORMED DATA -----------

   ;----------------------------------------------------------------------------
   ;--------------------  IMAGE DISTORTION CORRECTION ----------------

   ;  per Steve's instructions, first flip camera 0 from top to bottom
   ;  BEFORE applying image distortion correction.
   ;  flip camera 0:   

   FOR s = 0, 2 DO BEGIN
      cal_data (*, *, 0, s) = reverse (cal_data (*, *, 0, s), 2)
   ENDFOR

   ; Restore distortion coefficients from Steve's IDL file which currently uses
   ; Oct 30, 2013 test.

   restore, '/home/iguana/idl/kcor/dist_coeff.sav'

   ; Apply distortion correction to both cameras for all 3 polarizations I, Q, U
   ; dat1 is the image from beam 0, dat2 is the image from beam 1, and the other
   ; variables are the coefficients loaded from the sav file.

   FOR s = 0, 2 DO BEGIN
      dat1 = cal_data (*, *, 0, s)
      dat2 = cal_data (*, *, 1, s)

      apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c

      cal_data (*, *, 0, s) = dat1
      cal_data (*, *, 1, s) = dat2
  ENDFOR

;--- Find center of occulter for camera 0 and 1 AFTER DISTORTION ---

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT:  update center info after distorsion.

  ;--- CAMERA 0:

   PRINT, 'Camera 0 center info AFTER DISTORTION : ', center0_info_new
   PRINTF, ULOG, 'Camera 0 center info AFTER DISTORTION : ', center0_info_new

   xctr0    = center0_info_new (0)
   yctr0    = center0_info_new (1)
   radius_0 = center0_info_new (2)

   ;--- CAMERA 1:

   PRINT, 'Camera 1 center info AFTER DISTORTION : ', center1_info_new
   PRINTF, ULOG, 'Camera 1 center info AFTER DISTORTION : ', center1_info_new

   xctr1    = center1_info_new (0)
   yctr1    = center1_info_new (1)
   radius_1 = center1_info_new (2)

   PRINT, 'center and radius of occulter AFTER distortion correction:'
   PRINT, '(cam0x, cam0y, radius0), (cam1x, cam1y, radius1) : ', $
            xctr0, yctr0, radius_0, xctr1, yctr1, radius_1
   PRINTF, ULOG, 'center and radius of occulter AFTER distortion correction:'
   PRINTF, ULOG, '(cam0x, cam0y, radius0), (cam1x, cam1y, radius1) : ', $
            xctr0, yctr0, radius_0, xctr1, yctr1, radius_1

   ; ---------------------------------------------------------------------------
   ; NEED TO SHIFT images to center of array before combining
   ; ---------------------------------------------------------------------------
   ;
   ; Display cameras separately to assess alignment after distortion.
   ;
   ; Shift both camera images to center of array (511.5, 511.5).
   ; fshift uses bi-linear interpolation, shifting non-integer amounts.
   ; ---------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT and AS: changed code to make only one interpolation to put north
; up (pangle correction) and to shift image to array center

;   ;--- CAMERA 0:
;
;      FOR a = 0, 2 DO BEGIN
;         cal_data (*, *, 0, a) = $
;	    fshift (cal_data (*, *, 0, a), 511.5 - xctr0, 511.5 - yctr0)
;      ENDFOR
;
;   ;--- CAMERA 1:
;
;      FOR a = 0, 2 DO BEGIN
;         cal_data (*, *, 1, a) = $
;	    fshift (cal_data (*, *, 1, a), 511.5 - xctr1, 511.5 - yctr1)
;      ENDFOR
;

;      FOR s = 0, 2 do begin
;         cal_data (*, *, 0, s) = fshift (cal_data (*, *, 0, s), $
;                                         511.5 - xctr0, 511.5 - yctr0)
;         cal_data (*, *, 1, s) = fshift (cal_data (*, *, 1, s), $
;                                         511.5 - xctr1, 511.5 - yctr1)
;      ENDFOR

   FOR s = 0, 2 DO BEGIN ;{
      cal_data (*, *, 0, s) = rot (reverse (cal_data (*, *, 0, s), 1), $
                                   pangle, 1, xsize-1-xctr0, yctr0, cubic=-0.5)
      cal_data (*, *, 1, s) = rot (reverse (cal_data (*, *, 1, s), 1), $
                                   pangle, 1, xsize-1-xctr1, yctr1, cubic=-0.5)
   ENDFOR ;}

  xcen = 511.5 + 1	; X Center of FITS array equals one plus IDL center. 
  ycen = 511.5 + 1	; Y Center of FITS array equals one plus IDL center. 

			; IDL starts at zero but FITS starts at one.
			; See Bill Thompson Solar Soft Tutorial on 
			; basic World Coorindate System Fits header.

   ; END DISTORTION CORRECTION AND SHIFTING OF CAMERAS. 
   ;----------------------------------------------------------------------------

   ;----------------------------------------------------------------------------
   ; COMBINE BEAMS.
   ;
   ; Most of coronal signal is in mk4-like q images.
   ; 
   ; USE ONLY q data:

; GdT: This sum should be changed 

   corona = sqrt ( (cal_data (*, *, 0, 1)) ^2 + (cal_data (*, *, 1, 1)) ^2 ) 

   ; ---------------------------------
   ; EXTRACT ANNULUS OF 'GOOD DATA' 
   ; ---------------------------------
   ; Removing occulter area (noise), corners, etc.   
   ; Determine inner radius using size of occulter.


   r_in  = fix (occulter / platescale) + 5
   r_out = 504.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT: Changed to avoid loop
;
;
;   FOR y = 0, 1023 DO BEGIN
;      FOR x = 0, 1023 DO BEGIN
;         rad0 = sqrt ((x - 511.5)^2 + (y - 511.5)^2)
;         IF (rad0 GE r_in AND rad0 LE r_out) THEN corona (x, y) =
;         corona (x, y)
;        IF (rad0 lt r_in OR  rad0 GT r_out) THEN corona (x, y) =  0.0
;      ENDFOR
;   ENDFOR

; GdT: use mask to build final image 

    xx = findgen (xsize, ysize) mod (xsize) - 511.5 
    yy = transpose (findgen (ysize, xsize) mod (ysize) ) - 511.5
    xx = double (xx) &  yy0 = double (yy)  
    rads = sqrt ( xx^2. + yy^2. )  
    bad = WHERE (rads LT r_in OR rads GE r_out) 
    corona (bad) = 0.

   ;----------------------------------------------------------------------------

   ; -----------------------------------------
   ; CREATE STRING DATA FOR ANNOTATING IMAGE
   ; -----------------------------------------
   ;--- Extract date and time from L0 FITS file name.

   year  =  ''
   month =  ''
   day   =  ''
   hr    =  ''
   min   =  ''
   sec   =  ''

   year  = strmid (l0_file, 0, 4)
   month = strmid (l0_file, 4, 2)
   day   = strmid (l0_file, 6, 2)
   hr    = strmid (l0_file, 9, 2)
   min   = strmid (l0_file, 11, 2)
   sec   = strmid (l0_file, 13, 2)

   ;--- Convert month from integer to name of month.

   IF (month EQ '01') THEN name_month = 'Jan'
   IF (month EQ '02') THEN name_month = 'Feb'
   IF (month EQ '03') THEN name_month = 'Mar'
   IF (month EQ '04') THEN name_month = 'Apr'
   IF (month EQ '05') THEN name_month = 'May'
   IF (month EQ '06') THEN name_month = 'Jun'
   IF (month EQ '07') THEN name_month = 'Jul'
   IF (month EQ '08') THEN name_month = 'Aug'
   IF (month EQ '09') THEN name_month = 'Sep'
   IF (month EQ '10') THEN name_month = 'Oct'
   IF (month EQ '11') THEN name_month = 'Nov'
   IF (month EQ '12') THEN name_month = 'Dec'

   ;--- Determine DOY.
   ;    Convert month and year to integer.

   intmonth = month + 0
   leap     = year  + 0
   intday   = day   + 0
   IF (leap mod 4 EQ 0) THEN $
      numdays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
   IF (leap mod 4 NE 0) THEN $
      numdays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
   doy = 0
   FOR aa = 0, intmonth-2 DO doy =  numdays(aa) + doy
   doy = doy + intday
   stringmonth = ''
   stringday   = ''
   stringmonth = padinteger (intmonth, 2)
   stringday   = padinteger (intday, 2)
 
   date =  ''

   ;--- MLSO is close to end of day in UT time so, add 1 day:

    intday = intday + 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT: This is not necessary anymmore, it was done at the beginning
;
;   ;--- CDS format?
;
;   date = string (format = '(a4)', year) + '-' + string (format = '(a2)', $
;                  stringmonth) + '-' + string (format = '(a2)', stringday)
;
;   ; ---------------------------------------------------------------------------
;   ; FIND ephemeris data (pangle, bangle ...) using solarsoft routine pb0r
;   ; ---------------------------------------------------------------------------
;
;   ephem = pb0r (date, /earth)
;   pangle = ephem (0)
;   bangle = ephem (1)
;   radsun = ephem (2)

   ;--- Radius of sun is returned in arc minutes. Convert to arcseconds.

   num_arcsec = radsun mod fix (radsun)
   radsun = fix (radsun) * 60.0 + num_arcsec * 60.0

   PRINT, 'occulter size [arcsec] : ', occulter
   PRINT, 'date, hr, min, sec     : ', date, ' ', hr, min, sec
   PRINT, 'radsun, bangle, pangle : ', radsun, bangle, pangle

   PRINTF, ULOG, 'occulter size [arcsec] : ', occulter
   PRINTF, ULOG, 'date, hr, min, sec     : ', date, ' ', hr, min, sec
   PRINTF, ULOG, 'radsun, bangle, pangle : ', radsun, bangle, pangle

   ; photosphere height = apparent diameter of sun in arcseconds 
   ; divided platescale in arcseconds / pixel
   ; * radius of occulter in pixels :

   r_photo = radsun / platescale

   PRINT, 'Radius of photosphere in pixels = ', r_photo
   PRINTF, ULOG, 'Radius of photosphere [pixels] : ', r_photo

   ;--- Load color table.

   lct, '/hao/acos/sw/colortable/quallab_ver2.lut'	; color table.
   tvlct, red, green, blue, /get

   ; max scale values: Oct 09 (/unsigned long) =  3.0e09
   ; max scale values: Oct 19 (pre-opal) =  5.0e03
   ; max scale values: Nov 22 ~31
   ; max scale values: Nov 23 to Dec 3 ~35
   ; max scales Dec 4: 50
   ; max scales Dec 5: 55
   ; max scales Dec 7-10: 65
   ; 01 lens cleaned end of day Dec 10
   ; max scale Dec 11: 50
   ; maxi = 5.

   ;----------------------------------------------------------------------------
   ; APPLY VIGNETTING FUNCTION TO ENHANCE IMAGE
   ;  I am currently saving an annulus from r = 174 to r = 500 (below)
   ;  so there are 327 steps in radius 

   ; FUNCION USED TO GENERATE VIGNETTING:
   ; 1/(c1*r^p1 + c2*r^p2 + c3*r^p3 + c4*r^p4)

   ;  Initialize powers in power law equation

   p0 = 0.5
   p1 = 1 
   p2 = 1.5
   p3 = 2
   p4 = 3

   ;--- Initialize coefficients of each power.

   c0 = 0.00
   c1 = 0.15
   c2 = 0.25
   c3 = 0.05
   c4 = 0.00   

   ; ONLY OPERATE ON ABOVE OCCULTER (above pixel of r = occulter / platescale):
   ;
   ; ***  GIULIANA'S EXCELLENT SUGGESTION TO SPEED THIS UP
   ;      IS TO CREATE A VIGNETTING IMAGE AND THEN DO A MATRIX MULTIPLICATION
   ;      IMG x VIG  
   ;
   ;  ***********  TURN OFF VIGNETTING FOR NOW ***************
   ;
   ;FOR i = 0, 1023 DO BEGIN
   ;   FOR j = 0, 1023 DO BEGIN
   ;
   ;  NOISE THRESHOLD FOR mk4 is 4.e-09. Set all values below this to zero
   ;      if (img(j, i) lt 4.e-09) then img(j, i) = 0.
   ;  SCALE values above noise limit to eliminate small numbers(e.g. e-09)
   ;      if (img(j, i) ge 4.e-09) then img(j, i) = img(j, i)*5.e09
   ;
   ;   APPLY VIGNETTING 
   ;
   ;      r = sqrt ( (i-511.5)^2 + (j-511.5)^2 )
   ;
   ;   Now compute r in solar radii from pixels 
   ;
   ;      solarrad = r*platescale/radsun
   ;      vig = ( c0*solarrad^p0 + c1*solarrad^p1 + c2*solarrad^p2 + 4
   ;              c3*solarrad^p3 + c4*solarrad^p4)
   ;      IF (r lt r_out and r gt r_in) THEN corona(j, i) = corona(j, i)*vig
   ;      IF (corona(j, i) LT 0. ) THEN corona(j, i) = 0.
   ;   ENDFOR
   ;ENDFOR

   ; END OF VIGNETTING FUNCTION.
   ;----------------------------------------------------------------------------


   ;----------------------------------------------------------------------------
   ; FLIP. ROTATE FOR PANGLE TO PUT SOLAR NORTH UP.
   ;----------------------------------------------------------------------------
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT:  This is now done above together with the shift to the array center


;   corona = reverse (corona, 1)
;   corona = rot (corona, pangle)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; GdT:  Nothing was changed after this point
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


   ;----------------------------------------------------------------------------
   ;  DISPLAY IMAGE, ANNOTATE AND SAVE AS GIF
   ;----------------------------------------------------------------------------

   ; mini = -.02   ; USED FOR MARCH 10, 2014
   ; maxi = 0.5    ; USED FOR MARCH 10, 2014

   mini = 0.00	; 
   maxi = 1.2	; 

   tv, bytscl (corona^0.8, min = mini, max = maxi)

   corona_int = intarr (1024, 1024)
   corona_int = fix (1000*corona)

   PRINT, 'minmax, median : ', minmax (corona), median (corona)
   PRINT, 'minmax, median : ', minmax (corona_int), median (corona_int)
   PRINTF, ULOG, 'minmax, median : ', minmax (corona), median (corona)
   PRINTF, ULOG, 'minmax, median : ', minmax (corona_int), median (corona_int)

   xyouts, 4, 990, 'MLSO/HAO/KCOR', color = 255, charsize = 1.5, /device
   xyouts, 4, 970, 'K-Coronagraph', color = 255, charsize = 1.5, /device
   xyouts, 512, 1000, 'North', color = 255, charsize = 1.2, alignment = 0.5, $
           /device
   xyouts, 1018, 995, string (format = '(a2)', day) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', year), /device, alignment = 1.0, $
	   charsize = 1.2, color = 255
   xyouts, 1010, 975, 'DOY ' + string(format = '(i3)', doy), /device, $
           alignment = 1.0, charsize = 1.2, color = 255
   xyouts, 1018, 955, string (format = '(a2)', hr) + ':' + $
           string (format = '(a2)', min) + $
           ':' + string(format = '(a2)', sec) + ' UT', /device, $
	   alignment = 1.0, charsize = 1.2, color = 255
   xyouts, 22, 512, 'East', color = 255, charsize = 1.2, alignment = 0.5, $
           orientation = 90., /device
   xyouts, 1012, 512, 'West', color = 255, charsize = 1.2, alignment = 0.5, $
           orientation = 90., /device
   xyouts, 4, 26, 'Level 1 data', color = 255, $
           charsize = 1.2, /device
   xyouts, 4, 6, 'scaling: Intensity ^ 0.8', color = 255, $
           charsize = 1.2, /device
   xyouts, 1018, 6, 'Circle = photosphere.', $
           color = 255, charsize = 1.2, /device, alignment = 1.0

   ;--- Image has been shifted to center of array.
   ;--- Draw circle at photosphere.

   tvcircle, r_photo, 511.5, 511.5, color = 255, /device

   device, decomposed = 1 
   save = tvrd ()
   gif_file = 'l1.gif'
   gif_file = strmid (l0_file, 0, 20) + '.gif'
   write_gif, l1_dir + gif_file, save, red, green, blue

   ;----------------------------------------------------------------------------
   ; CREATE A FITS IMAGE:
   ; Burkepile: Some of this code comes from Sitongias update_header_l1.pro 
   ; and _l2.pro programs
   ;
   ; Need to keep level 0 headers and add additional quantities.
   ; Level 0 headers are stored in string variable = header
   ; Need to reorganize the header so that it reads well, e.g. group related 
   ; information togtherer
   ; and put all comments and history at the bottom of the header
   ;
   ; Compute solar ephemeris quantities from date and time
   ;----------------------------------------------------------------------------

   date_str = fxpar (header, 'DATE-OBS')
   times    = anytim2tai (date_str)
   jdstruct = anytim2jd (times)
   jd       = jdstruct.int + jdstruct.frac
   ephem2, jd, sol_ra, sol_dec, b0, p_angle, semi_diam, sid_time, $
           dist, xsun, ysun, zsun

   ; ephem2 doesn't give carrington longitude and rotation number. 
   ; Get that using jd_carr_long:

   julian_date = julday (month, day, year, hr, min, sec)
   jd_carr_long, julian_date, carrington_rotnum, carrington_long


   ; BUILD NEW HEADER: reorder old header and insert new information 
   ; Enter the info from the level 0 header and insert ephemeris and comments
   ; in proper order. Remove information from level 0 header that is 
   ; NOT correct for level 1 and 2 images
   ; For example:  NAXIS = 4 for level 0 but NAXIS =  2 for level 1&2 data. 
   ; Therefore NAXIS3 and NAXIS4 fields are not relevent for level 1 and 2 data.

   ; ***********************************************************
   ; *** ISSUES TO DEAL WITH: 
   ; 1) 01ID objective lens id added on June 18, 2014 
   ; 2) On June 17, 2014 19:30 Allen reports the Optimax 01 was installed. 
   ;    Prior to that date the 01 was from Jenoptik
   ;    NEED TO CHECK  THE EXACT TIME NEW OBJECTIVE WENT IN BY OBSERVING 
   ;    CHANGES IN ARTIFACTS 
   ;    IT MAY HAVE BEEN INSTALLED EARLIER IN DAY
   ; 3) IDL stuctures turn boolean 'T' and 'F' into integers (1, 0); 
   ;    need to turn back to boolean to meet FITS headers standards.
   ; 4) structures don't accept dashes ('-') in keywords which are FITS header 
   ;    standards (e.g. date-obs). 
   ;    use /DASH2UNDERSCORE  
   ; 5) structures don't save comments. Need to type them back in.

   newheader = strarr (200)
   newheader(0) = header(0)         ; contains SIMPLE keyword
   sxaddpar, newheader, 'BITPIX',   struct.bitpix, ' bits per pixel'
   sxaddpar, newheader, 'NAXIS', 2, ' number of dimensions; FITS image' 
   sxaddpar, newheader, 'NAXIS1',   struct.naxis1, ' (pixels) x dimension'
   sxaddpar, newheader, 'NAXIS2',   struct.naxis2, ' (pixels) y dimension'
   sxaddpar, newheader, 'DATE-OBS', struct.date_d$obs, ' UTC observation start'
   sxaddpar, newheader, 'DATE-END', struct.date_d$end, ' UTC observation end'
   sxaddpar, newheader, 'TIMESYS',  'UTC', $
                        ' date/time system: Coordinated Universal Time'
   sxaddpar, newheader, 'LOCATION', 'MLSO', $
                        ' Mauna Loa Solar Observatory, Hawaii'
   sxaddpar, newheader, 'ORIGIN',   struct.origin, $
                        ' Nat.Ctr.Atmos.Res. High Altitude Observatory'
   sxaddpar, newheader, 'TELESCOP', 'COSMO K-Coronagraph'
   sxaddpar, newheader, 'OBJECT',   struct.object, $
                        ' white light polarization brightness'
   sxaddpar, newheader, 'OBSERVER', struct.observer, $
                        ' name of Mauna Loa observer'
   sxaddpar, newheader, 'LEVEL',    'L1', $
                        ' Level 1 note: intensity is NOT fully calibrated'
   sxaddpar, newheader, 'DATE-L1', datecal(), ' Level 1 processing date'
   sxaddpar, newheader, 'CALFILE', calfile, $
                        ' calibration file:dark, opal, 4 pol.states'
   sxaddpar, newheader, 'L1SWID',   '28 Aug 2014', $
                        ' date of Level 1 software'
   sxaddpar, newheader, 'DMODSWID', '18 Aug 2014', $
                        ' date of demodulation software'
   sxaddpar, newheader, 'OBSSWID',  struct.obsswid, $
                        ' version of the observing software'
   sxaddpar, newheader, 'BZERO',    struct.bzero, $
                        ' offset for unsigned integer data'
   sxaddpar, newheader, 'BSCALE',   struct.bscale, $
             ' physical = data * BSCALE + BZERO', format = '(f8.2)'
   sxaddpar, newheader, 'WCSNAME',  'helioprojective-cartesian', $
                        'World Coordinate System (WCS) name'
   sxaddpar, newheader, 'CTYPE1',   'HPLN-TAN', $
                        ' [deg] helioprojective west angle: solar X'
   sxaddpar, newheader, 'CRPIX1',   xcen, $
                        ' [pixel]  solar X sun center (FITS=1+IDL value)'
   sxaddpar, newheader, 'CRVAL1',   0.00, ' [arcsec] solar X sun center'
   sxaddpar, newheader, 'CDELT1',   platescale, $
                        ' [arcsec/pix] solar X increment = platescale'
   sxaddpar, newheader, 'CUNIT1',   'arcsec'
   sxaddpar, newheader, 'CTYPE2',   'HPLT-TAN', $
                        ' [deg] helioprojective north angle: solar Y'
   sxaddpar, newheader, 'CRPIX2',   ycen, $
                        ' [pixel]  solar Y sun center (FITS=1+IDL value)'
   sxaddpar, newheader, 'CRVAL2',   0.00, ' [arcsec] solar Y sun center'
   sxaddpar, newheader, 'CDELT2',   platescale, $
                        ' [arcsec/pix] solar Y increment = platescale'
   sxaddpar, newheader, 'CUNIT2',   'arcsec'
   sxaddpar, newheader, 'INST_ROT', 0.00, $
                        ' [deg] rotation of the image wrt solar north'
   sxaddpar, newheader, 'PC1_1',    1.00, $
                        ' coord transform matrix element (1, 1) WCS std.'
   sxaddpar, newheader, 'PC1_2',    0.00, $
                        ' coord transform matrix element (1, 2) WCS std.'
   sxaddpar, newheader, 'PC2_1',    0.00, $
                        ' coord transform matrix element (2, 1) WCS std.'
   sxaddpar, newheader, 'PC2_2',    1.00, $
                        ' coord transform matrix element (2, 2) WCS std.'
  
   ;--- Add ephemeris data to new newheader.

   sxaddpar, newheader, 'RSUN',     semi_diam, $
                        ' [arcsec] solar radius', format = '(f8.2)'
   sxaddpar, newheader, 'SOLAR_P0', p_angle, $
                        ' [deg] solar P angle', format = '(f8.3)'
   sxaddpar, newheader, 'CRLT_OBS', b0, $
                        ' [deg] solar B angle: Carr. latitude ', $
			format = '(f8.3)'
   sxaddpar, newheader, 'CRLN_OBS', carrington_long, $
                        ' [deg] solar L angle: Carr. longitude', $
			format = '(f8.3)'
   sxaddpar, newheader, 'CAR_ROT',  carrington_rotnum, $
                        ' Carrington rotation number', format = '(i4)'
   sxaddpar, newheader, 'SOLAR_RA', sol_ra, $
                        ' [h]   solar right ascension (in hours)', $
			format = '(f8.3)'
   sxaddpar, newheader, 'SOLARDEC', sol_dec, $
                        ' [deg] solar declination', format = '(f8.2)'

   ;--- Add keywords about instrument hardware.

   sxaddpar, newheader, 'WAVELNTH', 735, $
                        ' [nm] center wavelength   of bandpass filter', $
	                format = '(i4)'
   sxaddpar, newheader, 'WAVEFWHM', 30, $
                        ' [nm] full width half max of bandpass filter', $
	                format = '(i3)'
   sxaddpar, newheader, 'DIFFUSER', struct.diffuser, $
                        ' diffuser in or out of the light beam'
   sxaddpar, newheader, 'DIFFSRID', struct.diffsrid, $
                        ' unique ID of the current diffuser'
   sxaddpar, newheader, 'CALPOL',   struct.calpol, $
                        ' calibration polarizer in or out of beam'
   sxaddpar, newheader, 'CALPANG',  struct.calpang, $
                        ' calibration polarizer angle'
   sxaddpar, newheader, 'CALPOLID', struct.calpolid, $
                        ' unique ID of current polarizer'
   sxaddpar, newheader, 'DARKSHUT', struct.darkshut, $
                        ' dark shutter open(out) or closed(in)'
   sxaddpar, newheader, 'EXPTIME',  struct.exptime*1.e-3, $
                        ' [s] exposure time for each frame', format = '(e10.3)'
   sxaddpar, newheader, 'NUMSUM',   struct.numsum, $
                        ' # frames summed per camera & polarizer state'
   sxaddpar, newheader, 'RCAMID',   'MV-D1024E-CL-11461', $
                        ' unique ID of camera 0'
   sxaddpar, newheader, 'TCAMID',   'MV-D1024E-CL-13889', $
                        ' unique ID of camera 1' 
   sxaddpar, newheader, 'RCAMLUT',  '11461-20131203', $
                        ' unique ID of LUT for camera 0'
   sxaddpar, newheader, 'TCAMLUT',  '13889-20131203', $
                        ' unique ID of LUT for camera 1'
   sxaddpar, newheader, 'RCAMFOCS', struct.rcamfocs, $
                        ' [mm] camera 0 focus position'
   sxaddpar, newheader, 'TCAMFOCS', struct.tcamfocs, $
                        ' [mm] camera 1 focus position'
   sxaddpar, newheader, 'MODLTRT',  struct.modltrt, $
                        ' [deg C] modulator temperature', format = '(f8.3)'
   sxaddpar, newheader, 'MODLTRID', struct.modltrid, $
                        ' unique ID of the current modulator'

   ;--- Ben added keyword 'O1ID' (objective lens id) on June 18, 2014 
   ;    to accommodate installation of Optimax objective lens

   IF (year lt 2014) then $
      sxaddpar, newheader, 'O1ID',     'Jenoptik', $
                           ' unique ID of objective (01) lens'

   IF (year eq 2014) then begin
      if (month lt 6) then $
         sxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' unique ID of objective (01) lens'
      if (month eq 6) and (day lt 17) then $
         sxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' unique ID of objective (01) lens'
      if (month eq 6) and (day ge 17) then $
         sxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' unique ID of objective (01) lens'
      if (month gt 6) then $
         sxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' unique ID of objective (01) lens'
   ENDIF

   IF (year gt 2014) then $
      sxaddpar, newheader, struct.o1id, ' unique ID of objective (01) lens' 

   sxaddpar, newheader, 'O1FOCS',   struct.o1focs, $
                        ' [mm] objective lens (01) focus position', $
			format = '(f8.3)'
   sxaddpar, newheader, 'COVER',    struct.cover, $
                        ' cover in or out of the light beam'
   sxaddpar, newheader, 'OCCLTRID', struct.occltrid, $
                        ' unique ID of current occulter'
   sxaddpar, newheader, 'FILTERID', struct.filterid, $
                        ' unique ID of current bandpass filter'
   sxaddpar, newheader, 'SGSDIMV',  struct.sgsdimv, $
                        ' [V] mean Spar Guider Sys. (SGS) DIM signal', $
			format = '(f9.4)'
   sxaddpar, newheader, 'SGSDIMS',  struct.sgsdims, $
                        ' [V] SGS DIM signal standard deviation', $
			format = '(e10.4)'
   sxaddpar, newheader, 'SGSSUMV',  struct.sgssumv, $
                        ' [V] mean SGS sum signal', format = '(f9.4)'
   sxaddpar, newheader, 'SGSRAV',   struct.sgsrav, $
                        ' [V] mean SGS RA error signal', format = '(e10.4)'
   sxaddpar, newheader, 'SGSRAS',   struct.sgsras, $
                        ' [V] mean SGS RA error standard deviation', $
			format = '(e10.4)'
   sxaddpar, newheader, 'SGSRAZR',  struct.sgsrazr, $
                        ' [arcsec] SGS RA zeropoint offset', format = '(f9.4)'
   sxaddpar, newheader, 'SGSDECV',  struct.sgsdecv, $
                        ' [V] mean SGS DEC error signal', format = '(e10.4)'
   sxaddpar, newheader, 'SGSDECS',  struct.sgsdecs, $
                        ' [V] mean SGS DEC error standard deviation', 4
			format = '(e10.4)' 
   sxaddpar, newheader, 'SGSDECZR', struct.sgsdeczr, $ 
                        ' [arcsec] SGS DEC zeropoint offset', format = '(f9.4)'
   sxaddpar, newheader, 'SGSSCINT', struct.sgsscint, $
                        ' [arcsec] SGS scintillation seeing estimate', $
			format = '(f8.3)'
   sxaddpar, newheader, 'SGSLOOP',  struct.sgsloop, ' SGS loop closed fraction'
   sxaddpar, newheader, 'SGSSUMS',  struct.sgssums, $
                        ' [V] SGS sum signal standard deviation', $
			format = '(e10.4)'

   sxaddpar, newheader, 'COMMENT', $
      ' The COSMO K-coronagraph is a 20-cm aperture, internally occulted'
   sxaddpar, newheader, 'COMMENT', $
      ' coronagraph that observes the polarization brightness of the corona'
   sxaddpar, newheader, 'COMMENT', $
      ' with a field-of-view from ~1.05 to 3 solar radii in a wavelength range'
   sxaddpar, newheader, 'COMMENT', $
      ' from 720 to 750 nm. Nominal time cadence is 15 seconds.'
  
   ;--- Add History.

   sxaddhist, $
     'Level 1 processing performed: dark current subtracted, gain correction,',$
      newheader
   sxaddhist, $
     'polarimetric demodulation, coordinate transformation from cartesian to', $
      newheader
   sxaddhist, $
     'tangent/radial, preliminary removal of sky polarization, ',$
      newheader
   sxaddhist, $
     'image distortion correction, beams combined, Platescale calculated.', $
      newheader
   IF (struct.extend eq 0) then val_extend = 'F'
   IF (struct.extend eq 1) then val_extend = 'T'
   sxaddpar, newheader, 'EXTEND', 'F', ' No FITS extensions'

  
  
   ; For FULLY CALIBRATED DATA:  ADD THESE WHEN READY
   ;  sxaddpar, newheader, 'BUNIT', '10^-6 Bsun', $
   ;                       ' Millionths of Solar brightness'
   ;  sxaddpar, newheader, 'BUNIT', 'MILLIONTHS', $
   ;                       ' Millions of brightness of solar disk'
   ;  sxaddpar, newheader, 'BOPAL', '1.38e-05', $
   ;                       ' Opal Transmission Calibration by Elmore at 775 nm'
   ; sxaddhist, $
   ; 'Level 2 processing performed: sky polarization removed, alignment to ', $
   ; newheader
   ; sxaddhist, $
   ; 'solar north calculated, polarization split in radial and tangential ', $
   ;  newheader
   ; sxaddhist, $
   ; 'components.  For detailed information see the COSMO K-coronagraph ', $
   ; newheader
   ; sxaddhist, 'data reduction paper (reference).', newheader
   ; sxaddpar, newheader, 'LEVEL', 'L2', ' Processing Level'
   ; sxaddpar, newheader, 'DATE-L2', datecal(), ' Level 2 processing date'
   ; sxaddpar, newheader, 'L2SWID', 'Calib Reduction Mar 31, 2014', $
   ;           ' Demodulation Software Version'

   ;--- ADD IMAGE DISTORTION FILE KEYWORD.
  
   ;--- Write FITS image to disc.

   l1_file = strmid (l0_file, 0, 20) + '_l1.fts'
   writefits, l1_dir + l1_file, corona_int, newheader
   ;----------------------------------------------------------------------------

   ;----------------------------------------------------------------------------
   ; NOW MAKE LOW RES GIF AN FITS:
   ;
   ; Use congrid to rebin to 768x768 (75% of original size) 
   ; and crop around center to 512 x 512 image.
   ;----------------------------------------------------------------------------

   rebin_img = fltarr (768, 768)
   rebin_img = congrid (corona, 768, 768)

   crop_img = fltarr (512, 512)
   crop_img = rebin_img (128:639, 128:639)

;   window, 0, xs = 512, ys = 512, retain = 2

   set_plot='Z'
   erase
   device, set_resolution=[512,512], decomposed=0, set_colors=256, $
           z_buffering=0
   erase
   tv, bytscl (crop_img^0.8, min = mini, max = maxi)

   xyouts, 4, 495, 'MLSO/HAO/KCOR', color = 255, charsize = 1.2, /device
   xyouts, 4, 480, 'K-Coronagraph', color = 255, charsize = 1.2, /device
   xyouts, 256, 500, 'North', color = 255, $
           charsize = 1.0, alignment = 0.5, /device
   xyouts, 507, 495, string (format = '(a2)', day) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', year), /device, alignment = 1.0, $
	   charsize = 1.0, color = 255
   xyouts, 500, 480, 'DOY ' + string (format = '(i3)', doy), $
           /device, alignment = 1.0, charsize = 1.0, color = 255
   xyouts, 507, 465, string (format = '(a2)', hr) + ':' + $
           string (format = '(a2)', min) + ':' + $
	   string (format = '(a2)', sec) + ' UT', /device, alignment = 1.0, $
	   charsize = 1.0, color = 255
   xyouts, 12, 256, 'East', color = 255, $
           charsize = 1.0, alignment = 0.5, orientation = 90., /device
   xyouts, 507, 256, 'West', color = 255, $
           charsize = 1.0, alignment = 0.5, orientation = 90., /device
   xyouts, 4, 20, 'Level 1 data', color = 255, $
           charsize = 1.0, /device
   xyouts, 4, 6, 'scaling: Intensity ^ 0.8', color = 255,$
           charsize = 1.0, /device
   xyouts, 508, 6, 'Circle = photosphere', color = 255, $
           charsize = 1.0, /device, alignment = 1.0

   r = r_photo*0.75    ;  image is rebined to 75% of original size
   tvcircle, r, 255.5, 255.5, color = 255, /device

   save = tvrd ()
   cgif_file = strmid (l0_file, 0, 20) + '_cropped.gif'
   write_gif, l1_dir + cgif_file, save, red, green, blue

   FLUSH, ULOG				; send buffered output to file.

   ; end of if statement processing science data
   ;ENDIF

   ; end of WHILE loop

END ;}

PRINT,        '>>>>>>> End of kcorl1g <<<<<<<'
PRINTF, ULOG, '>>>>>>> End of kcorl1g <<<<<<<'

CLOSE, ULIST
CLOSE, ULOG
FREE_LUN, ULIST
FREE_LUN, ULOG

END
