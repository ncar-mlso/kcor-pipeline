; docformat = 'rst'

;+
; Create a synoptic plot for the current day.
; 
; :Keywords:
;   run : in, required, type=object]
;     KCor run object
;-
pro kcor_daily_synoptic_map, run=run
  compile_opt strictarr

  logger_name = run.logger_name

  ; get all L2 files
  files = file_search(filepath('*_kcor_l2.fts.gz', $
                               subdir=['level2'], $
                               root=run->config('processing/raw_basedir')), $
                      count=n_files)
  if (n_files eq 0L) then begin
    mg_log, 'no L2 files for daily synoptic map', name=logger_name, /warn
    goto, done
  endif else begin
    mg_log, 'producing daily synoptic map from %d L2 files', n_files, $
            name=logger_name, /info
  endelse

  nbins = 720
  map = fltarr(n_files, nbins)
  times = fltarr(n_files)

  for f = 0L, n_files - 1L do begin
    im = readfits(files[f], header, /silent)

    date_obs = sxpar(header, 'DATE-OBS', count=qdate_obs)

    ; normalize odd values for date/times
    date_obs = kcor_normalize_datetime(date_obs)

    year   = long(strmid(date_obs,  0, 4))
    month  = long(strmid(date_obs,  5, 2))
    day    = long(strmid(date_obs,  8, 2))
    hour   = long(strmid(date_obs, 11, 2))
    minute = long(strmid(date_obs, 14, 2))
    second = long(strmid(date_obs, 17, 2))

    fhour = hour + minute / 60.0 + second / 60.0 / 60.0
    sun, year, month, day, fhour, sd=rsun

    run.time = date_obs
    sun_pixels = rsun / run->epoch('plate_scale')

    r13 = kcor_annulus_gridmeans(im, 1.3, sun_pixels, nbins=nbins)

    ; place r13 in the right place in the map
    map[f, *] = r13
    times[f] = fhour - 10.0
  endfor

  ; display map
  set_plot, 'Z'
  device, set_resolution=[n_files + 80, 800]
  original_device = !d.name

  device, get_decomposed=original_decomposed
  tvlct, rgb, /get
  device, decomposed=0

  range = mg_range(map)
  if (range[0] lt 0.0) then begin
    minv = 0.0
    maxv = range[1]

    loadct, 0, /silent
    foreground = 0
    background = 255
  endif else begin
    minv = 0.0
    maxv = range[1]

    loadct, 0, /silent
    foreground = 0
    background = 255
  endelse

  north_up_map = shift(map, 0, -180)
  east_limb = reverse(north_up_map[*, 0:359], 2)
  west_limb = north_up_map[*, 360:*]

  charsize = 1.0
  smooth_kernel = [11, 1]

  title = string(start_date, end_date, $
                 format='(%"Synoptic map for r1.3 from %s to %s")')
  erase, background
  mg_image, reverse(east_limb, 1), reverse(times), $
            xrange=[18.0, 6.0], $
            xtyle=1, xtitle='Time (not offset for E limb)', $
            min_value=minv, max_value=maxv, $
            /axes, yticklen=-0.005, xticklen=-0.01, $
            color=foreground, background=background, $
            title=string(title, format='(%"%s (East limb)")'), $
            position=[0.05, 0.55, 0.97, 0.95], /noerase, $
            yticks=4, ytickname=['S', 'SE', 'E', 'NE', 'N'], yminor=4, $
            smooth_kernel=smooth_kernel, $
            charsize=charsize
  mg_image, reverse(west_limb, 1), reverse(times), $
            xrange=[18.0, 6.0], $
            xstyle=1, xtitle='Time (not offset for W limb)', $
            min_value=minv, max_value=maxv, $
            /axes, yticklen=-0.005, xticklen=-0.01, $
            color=foreground, background=background, $
            title=string(title, format='(%"%s (West limb)")'), $
            position=[0.05, 0.05, 0.97, 0.45], /noerase, $
            yticks=4, ytickname=['S', 'SW', 'W', 'NW', 'N'], yminor=4, $
            smooth_kernel=smooth_kernel, $
            charsize=charsize

  im = tvrd()

  p_dir = filepath('p', subdir=run.date, root=run->config('processing/raw_basedir'))
  output_filename = filepath(string(run.date, format='(%"%s.daily.synoptic.gif")'), $
                             root=p_dir)
  write_gif, output_filename, im, rgb[*, 0], rgb[*, 1], rgb[*, 2]

  ; clean up
  done:
  if (n_elements(original_device) gt 0L) then set_plot, original_device
  if (n_elements(rgb) gt 0L) then tvlct, rgb
  if (n_elements(original_decomposed) gt 0L) then device, decomposed=original_decomposed

  done:
  mg_log, 'done', name=logger_name, /info
end


; main-level example

date = '20200105'
config_filename = filepath('kcor.reprocess.cfg', $
                           subdir=['..', '..', 'config'], $
                           root=mg_src_root())
run = kcor_run(date, config_filename=config_filename)

kcor_daily_synoptic_map, run=run

obj_destroy, run

end