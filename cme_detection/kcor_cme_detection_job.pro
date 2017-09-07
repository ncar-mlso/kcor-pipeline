; docformat = 'rst'

pro kcor_cme_detection_job, date, timerange=_timerange
  compile_opt strictarr
  @kcor_cme_det_common

  store = 1
  running = 0B
  cme_occurring = 0B

  if (n_elements(_timerange) eq 2) then begin
    timerange = _timerange
  endif else begin
    delvarx, timerange
  endelse

  ; Define the parameters describing the resulting maps.  Note that the product
  ; of NLON*NAVG should be at least as large as the circumference in pixels of
  ; the outer edge of the coronagraph field of view.
  nlon = 120       ; Number of longitude points
  navg = 40        ; Number of points to average in longitude
  nrad = 310       ; Number of radial points.

  ; The top of the directory tree containing the kcor data is given by the
  ; environment variable KCOR_DIR.
  kcor_dir = getenv('KCOR_DIR')
  if (kcor_dir eq '') then begin
    cd, current=current
    kcor_dir = concat_dir(current, 'acos')
  endif

  ; The environment variable KCOR_HPR_DIR points to the top of the directory
  ; tree used for storing images converted into helioprojective-radial (HPR)
  ; coordinates.
  kcor_hpr_dir = getenv('KCOR_HPR_DIR')
  if (kcor_hpr_dir eq '') then begin
    if (~file_test(kcor_hpr_dir, /directory)) then file_mkdir, kcor_hpr_dir
    cd, current=current
    kcor_hpr_dir = concat_dir(current, 'kcor_hpr')
  endif

  ; The environment variable KCOR_HPR_DIFF_DIR points to the top of the
  ; directory tree used for storing running difference maps in
  ; helioprojective-radial (HPR) coordinates.
  kcor_hpr_diff_dir = getenv('KCOR_HPR_DIFF_DIR')
  if (kcor_hpr_diff_dir eq '') then begin
    if (~file_test(kcor_hpr_diff_dir, /directory)) then begin
      file_mkdir, kcor_hpr_diff_dir
    endif
    cd, current=current
    kcor_hpr_diff_dir = concat_dir(current, 'kcor_hpr_diff')
  endif

  ; Determine the date directory from the date. If no date was passed, then use
  ; today's date.
  if (n_elements(date) eq 0) then get_utc, date
  sdate = anytim2utc(date, /ecs, /date_only)
  datedir = concat_dir(kcor_dir, sdate)

  ; make sure that the output directories exist
  hpr_out_dir = concat_dir(kcor_hpr_dir, sdate)
  if keyword_set(store) and (not file_exist(hpr_out_dir)) then $
      file_mkdir, hpr_out_dir
  diff_out_dir = concat_dir(kcor_hpr_diff_dir, sdate)
  if keyword_set(store) and (not file_exist(diff_out_dir)) then $
      file_mkdir, diff_out_dir

  mg_log, logger=logger, name='kcor-cme'
  log_format = '%(time)s %(levelshortname)s: %(message)s'
  logger->setProperty, format=log_format, $
                       filename=string(strmid(date, 0, 4), $
                                       strmid(date, 5, 2), $
                                       strmid(date, 8, 2), $
                                       format='(%"%s%s%s.cme.log")')

  kcor_cme_det_reset

  ; start up SolarSoft display routines
  defsysv, '!image', exists=sys_image_defined
  if (~sys_image_defined) then imagelib
  defsysv, '!aspect', exists=sys_aspect_defined
  if (~sys_aspect_defined) then devicelib

  if (file_exist(datedir)) then begin
    cstop = 0

    ; TODO: should check for time of day, stop after a certain time of day
    ; TODO: but when running with a date set, stop after done with files
    while (1B) do begin
      kcor_cme_det_check, stopped=stopped

      if (stopped) then begin
        if (cme_occurring) then begin
          ref_time = tai2utc(tairef, /time, /truncate, /ccsds)
          kcor_cme_det_report, ref_time
          cme_occurring = 0B
          mg_log, 'CME ended at %s', ref_time, name='kcor-cme', /info
        endif
        break
      endif
    endwhile
  endif else begin
    mg_log, 'directory %s does not exist', datedir, name='kcor-cme', /warn
  endelse
end