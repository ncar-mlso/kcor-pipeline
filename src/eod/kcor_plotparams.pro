; docformat = 'rst'

;+
; Plot chosen K-coronagraph parameters.
;
; :Params:
;   date : in, required, type=string
;     date in the form 'YYYYMMDD'
;
; :Keywords:
;   list : in, required, type=strarr
;     list of files to process
;   run : in, required, type=object
;     `kcor_run` object
;
; :Author:
;   Andrew L. Stanger   HAO/NCAR   26 November 2014
;
; :History:
;   10 Feb 2015 Revised plot date format.
;               Changed hours X-range [16-28],
;               Changed DIMV  Y-range [5.5-7.5].
;               Changed modular temp Y-range [28-36].
;   22 Feb 2015 L0 files are now in level0 sub-directory.
;   31 May 2015 Modify yrange for O1 focus from [130, 140] to [130, 150].  
;    8 Jun 2015 Modify yrange for O1 focus from [130, 150] to [125, 150].
;   10 Jun 2015 Modify yrange for O1 focus from [125, 150] to [110, 150].
;               Also print focus values in log file.
;-
pro kcor_plotparams, date, list=list, run=run
  compile_opt strictarr

  if (n_params() eq 0) then begin
    mg_log, 'missing date parameter', name='kcor/eod', /error
    return
  endif

  ; establish directory paths
  l0_base = run.raw_basedir
  l0_dir  = filepath('level0', subdir=date, root=l0_base)

  ; TODO: change p/ directory to engineering or plots
  plots_dir   = filepath('p', subdir=date, root=l0_base)

  ; create sub-directory for plots
  file_mkdir, plots_dir

  ; move to L0 kcor directory
  cd, current=start_dir   ; save current directory.
  cd, l0_dir              ; move to raw (l0) kcor directory.

  doview = 0

  ; establish list of files to process

  ; determine the number of files to process
  nimg = n_elements(list)
  mg_log, '%d images to plot', nimg, name='kcor/eod', /debug

  ; declare storage for plot arrays

  mod_temp = fltarr(nimg)

  sgs_dimv = fltarr(nimg)
  sgs_scin = fltarr(nimg)
  sgs_rav = fltarr(nimg)
  sgs_ras = fltarr(nimg)
  sgs_decv = fltarr(nimg)
  sgs_decs = fltarr(nimg)
  sgs_razr = fltarr(nimg)
  sgs_deczr = fltarr(nimg)

  hours    = fltarr(nimg)

  tcam_focus = fltarr(nimg)
  rcam_focus = fltarr(nimg)
  o1_focus   = fltarr(nimg)

  ; used for log messages
  indent = strjoin(strarr(4 + 2 + ceil(alog10(n_elements(list) + 1))) + ' ')

  ; image file loop
  for i = 0L, n_elements(list) - 1L do begin
    l0_file = list[i]

    hdu = headfits(l0_file, /silent)   ; read FITS header

    ; get FITS header size
    hdusize = size(hdu)

    ; extract keyword parameters from FITS header
    diffuser = ''
    calpol   = ''
    darkshut = ''
    cover    = ''

    naxis    = sxpar(hdu, 'NAXIS',    count=qnaxis)
    naxis1   = sxpar(hdu, 'NAXIS1',   count=qnaxis1)
    naxis2   = sxpar(hdu, 'NAXIS2',   count=qnaxis2)
    naxis3   = sxpar(hdu, 'NAXIS3',   count=qnaxis3)
    naxis4   = sxpar(hdu, 'NAXIS4',   count=qnaxis4)
    np       = naxis1 * naxis2 * naxis3 * naxis4 

    date_obs = sxpar(hdu, 'DATE-OBS', count=qdate_obs)
    run.time = date_obs
    level    = sxpar(hdu, 'LEVEL',    count=qlevel)

    bzero    = sxpar(hdu, 'BZERO',    count=qbzero)
    bbscale  = sxpar(hdu, 'BSCALE',   count=qbbscale)

    datatype = sxpar(hdu, 'DATATYPE', count=qdatatype)

    diffuser = sxpar(hdu, 'DIFFUSER', count=qdiffuser)
    calpol   = sxpar(hdu, 'CALPOL',   count=qcalpol)
    darkshut = sxpar(hdu, 'DARKSHUT', count=qdarkshut)
    cover    = sxpar(hdu, 'COVER',    count=qcover)

    occltrid = sxpar(hdu, 'OCCLTRID', count=qoccltrid)

    tcamfocs = sxpar(hdu, 'TCAMFOCS', count=qtcamfocs)
    rcamfocs = sxpar(hdu, 'RCAMFOCS', count=qrcamfocs)
    o1focs   = sxpar(hdu, 'O1FOCS',   count=qo1focs)

    modltrt  = sxpar(hdu, 'MODLTRT',  count=qmodltrt)

    mod_temp[i] = modltrt

    sgs_dimv[i]  = kcor_getsgs(hdu, 'SGSDIMV', /float)
    sgs_scin[i]  = kcor_getsgs(hdu, 'SGSSCINT', /float)
    sgs_rav[i]   = kcor_getsgs(hdu, 'SGSRAV', /float)
    sgs_ras[i]   = kcor_getsgs(hdu, 'SGSRAS', /float)
    sgs_decv[i]  = kcor_getsgs(hdu, 'SGSDECV', /float)
    sgs_decs[i]  = kcor_getsgs(hdu, 'SGSDECS', /float)
    sgs_razr[i]  = kcor_getsgs(hdu, 'SGSRAZR', /float)
    sgs_deczr[i] = kcor_getsgs(hdu, 'SGSDECZR', /float)

    tcam_focus[i] = tcamfocs
    rcam_focus[i] = rcamfocs
    o1_focus[i]   = o1focs

    occulter = kcor_get_occulter_size(occltrid, run=run) ; occulter size [arcsec]
    radius_guess = occulter / run->epoch('plate_scale')  ; occulter size [pixels]

    mg_log, '%4d/%d: %s %s', $
            i + 1, n_elements(list), file_basename(l0_file), $
            strmid(datatype, 0, 3), $
            name='kcor/eod', /debug
    mg_log, '%s%7.3f %7.3f %7.3f', $
            indent, modltrt, sgs_dimv[i], sgs_scin[i], $
            name='kcor/eod', /debug
    mg_log, '%s%7.3f %7.3f %9.3f', $
            indent, tcamfocs, rcamfocs, o1focs, $
            name='kcor/eod', /debug

    ; define array dimensions
    xdim = naxis1
    ydim = naxis2

    ; extract date items from FITS header parameter (DATE-OBS)
    year   = strmid(date_obs, 0, 4)
    month  = strmid(date_obs, 5, 2)
    day    = strmid(date_obs, 8, 2)
    hour   = strmid(date_obs, 11, 2)
    minute = strmid(date_obs, 14, 2)
    second = strmid(date_obs, 17, 2)

    ; pdate is for the plot title
    if (i eq 0) then begin
      pyear   = strmid(date, 0, 4)
      pmonth  = strmid(date, 4, 2)
      pday    = strmid(date, 6, 2)
      pdate   = string(pyear, pmonth, pday, format='(%"%s-%s-%s")')
    endif

    datetime = string(year, month, day, hour, minute, second, $
                      format='(%"%s-%s-%sT%s:%s:%s")')

    ; obs_hour is referenced to the observing day, so add 24 hours to the hours
    ; past midnight UT
    obs_hour = hour
    if (hour lt 16) then obs_hour += 24

    hours[i] = obs_hour + minute / 60.0 + second / 3600.0

    ; verify that image is Level 0
    if (level ne 'L0')  then begin
      mg_log, 'not level 0 data', name='kcor/eod', /warn
      continue
    endif
  endfor

  eng_gif_filename  = filepath(date + '.sgs.eng.gif', root=plots_dir)
  foc_gif_filename  = filepath(date + '.kcor.eng.gif', root=plots_dir)

  mg_log, 'eng gif: %s', file_basename(eng_gif_filename), name='kcor/eod', /debug
  mg_log, 'foc gif: %s', file_basename(foc_gif_filename), name='kcor/eod', /debug

  ; set up graphics window & color table for sgs.eng.gif
  set_plot, 'Z'
  device, set_resolution=[772, 1000], decomposed=0, set_colors=256, $
          z_buffering=0
  !p.multi = [0, 1, 6]

  plot, hours, sgs_dimv, title=pdate + ' KCor SGS DIM', $
        xtitle='Hours [UT]', ytitle='DIM [volts]', /ynozero, $
        xrange=[16.0, 28.0], yrange=[5.5, 7.5], $
        background=255, color=0, charsize=2.0

  ; use fixed y-axis scaling
  plot, hours, sgs_scin, title=pdate + ' KCor SGS Scintillation', $
        xtitle='Hours [UT]', ytitle='Scintillation [arcsec]', $
        xrange=[16.0, 28.0], yrange=[0.0, 20.0], $
        background=255, color=0, charsize=2.0 

  rav_min = min(sgs_rav - sgs_ras, /nan)
  rav_max = max(sgs_rav + sgs_ras, /nan)
  mg_log, 'SGSRAV min=%f, max=%f', rav_min, rav_max, name='kcor/eod', /debug
  gap = (rav_max - rav_min) * 0.05
  plot, hours, sgs_rav, title=pdate + ' KCor SGS RA', $
        xtitle='Hours [UT]', ytitle='volts', $
        xrange=[16.0, 28.0], yrange=[rav_min - gap, rav_max + gap], $
        background=255, color=0, charsize=2.0
  polyfill, [hours, reverse(hours), hours[0]], $
            [sgs_rav + sgs_ras, $
             reverse(sgs_rav - sgs_ras), $
             sgs_rav[0] + sgs_ras[0]], $
            color=200
  oplot, hours, sgs_rav, color=0

  decv_min = min(sgs_decv - sgs_decs, /nan)
  decv_max = max(sgs_decv + sgs_decs, /nan)
  mg_log, 'SGSDECV min=%f, max=%f', decv_min, decv_max, name='kcor/eod', /debug
  gap = (decv_max - decv_min) * 0.05
  plot, hours, sgs_decv, title=pdate + ' KCor SGS Dec', $
        xtitle='Hours [UT]', ytitle='volts', $
        xrange=[16.0, 28.0], yrange=[decv_min - gap, decv_max + gap], $
        background=255, color=0, charsize=2.0 
  polyfill, [hours, reverse(hours), hours[0]], $
            [sgs_decv + sgs_decs, $
             reverse(sgs_decv - sgs_decs), $
             sgs_decv[0] + sgs_decs[0]], $
            color=200
  oplot, hours, sgs_decv, color=0

  razr_min = min(sgs_razr, max=razr_max, /nan)
  if (~finite(razr_min)) then begin
    razr_min = -20.0
    razr_max =  20.0
  endif
  mg_log, 'SGSRAZR min=%f, max=%f', razr_min, razr_max, name='kcor/eod', /debug
  gap = (razr_max - razr_min) * 0.04
  plot, hours, sgs_razr, title=pdate + ' KCor SGS RA zeropoint offset', $
        xtitle='Hours [UT]', ytitle='arcsec', $
        xrange=[16.0, 28.0], yrange=[razr_min - gap, razr_max + gap], $
        background=255, color=0, charsize=2.0 

  deczr_min = min(sgs_deczr, max=deczr_max, /nan)
  if (~finite(deczr_min)) then begin
    deczr_min =  40.0
    deczr_max = 100.0
  endif
  mg_log, 'SGSDECZR min=%f, max=%f', deczr_min, deczr_max, name='kcor/eod', /debug
  gap = (deczr_max - deczr_min) * 0.04
  plot, hours, sgs_deczr, title=pdate + ' KCor SGS Dec zeropoint offset', $
        xtitle='Hours [UT]', ytitle='arcsec', $
        xrange=[16.0, 28.0], yrange=[deczr_min - gap, deczr_max + gap], $
        background=255, color=0, charsize=2.0 

  save = tvrd()
  write_gif, eng_gif_filename, save

  erase

  !p.multi = [0, 1, 4]

  plot, hours, mod_temp, title=pdate + ' KCor Modulator Temperature', $
        xtitle='Hours [UT]', ytitle='Temperature [deg C]', $
        background=255, color=0, charsize=2.0, $
        xrange=[16.0, 28.0], yrange=[28.0, 36.0]

  plot, hours, tcam_focus, title=pdate + ' KCor T Camera Focus position', $
        xtitle='Hours [UT]', ytitle='T Camera Focus [mm]', $
        background=255, color=0, charsize=2.0, $
        xrange=[16.0, 28.0], yrange=[-1.0, 1.0]

  plot, hours, rcam_focus, title=pdate + ' KCor R Camera Focus position', $
        xtitle='Hours [UT]', ytitle='R Camera Focus [mm]', $
        background=255, color=0, charsize=2.0, $
        xrange=[16.0, 28.0], yrange=[-1.0, 1.0]

  plot, hours, o1_focus, title=pdate + ' KCor O1 Focus position', $
        xtitle='Hours [UT]', ytitle='O1 Camera Focus [mm]', $
        background=255, color=0, charsize=2.0, $
        xrange=[16.0, 28.0], yrange=[110.0, 150.0]

  save = tvrd()
  write_gif, foc_gif_filename, save

  cd, start_dir
  set_plot, 'X'

  mg_log, 'done', name='kcor/eod', /info
end


; main-level example program

date = '20130930'
run = kcor_run(date, $
               config_filename=filepath('kcor.mgalloy.mahi.latest.cfg', $
                                        subdir=['..', '..', 'config'], $
                                        root=mg_src_root()))
list = file_search(filepath('*.fts.gz', $
                            subdir=[date, 'level0'], $
                            root=run.raw_basedir))
kcor_plotparams, date, list=list, run=run

end
