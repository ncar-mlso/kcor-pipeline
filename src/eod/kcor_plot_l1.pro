; docformat = 'rst'

;+
; Compute the mean pB value in a polar grid defined by the `n_angles`, `radii`,
; and `radius_width`.
;
; :Returns:
;   `fltarr(n_angles, n_radii)`
;
; :Params:
;   pB : in, required, type="fltarr(nx, ny)"
;     pB data to average
;   date : in, required, type=structure
;     parsed date obs with `year`, `month`, `day`, and `ehour` fields
;   n_angles : in, required, type=integer
;     the number of angular slices to grid the image into
;   radii : in, required, type=fltarr
;     the radii to check in R_sun
;   radius_width : in, required, type=float
;     annulus has inside radius of `radii - radius_width / 2.0` and outside
;     radius of `radii + radius_width / 2.0`
;   plate_scale : in, required, type=float
;-
function kcor_plot_l1_mean_pB, pB, date, $
                               ;n_angles, $
                               radii, radius_width, $
                               plate_scale
  compile_opt strictarr

  ; calculate emphemeris information
  sun, date.year, date.month, date.day, date.ehour, sd=rsun
  sun_pixels = rsun / plate_scale

;  angles = findgen(n_angles + 1) / n_angles * 360.0 * !dtor   ; radians
  n_radii = n_elements(radii)

  ; compute x-y coordinates in R_sun

  center_x = 511.5
  center_y = 511.5
  dims = size(pB, /dimensions)

  x = rebin(reform(findgen(dims[0]) - center_x, dims[0], 1), dims[0], dims[1])
  x /= sun_pixels

  y = rebin(reform(findgen(dims[1]) - center_y, 1, dims[1]), dims[0], dims[1])
  y /= sun_pixels

  ; compute radius-theta coordinates in R_sun and radians
  radius = sqrt(x^2 + y^2)
;  theta = atan(y, x)

  ; compute mean
;  mean_pb = fltarr(n_angles, n_radii)
  mean_pb = fltarr(n_radii)
  for r = 0L, n_radii - 1L do begin
;    for a = 0L, n_angles - 1L do begin
;      ind = where((radius gt (radii[r] - radius_width / 2.0)) $
;                  and (radius lt (radii[r] + radius_width / 2.0)) $
;                  and (theta gt angles[a]) $
;                  and (theta lt angles[a + 1L]), n_pixels)
      ind = where((radius gt (radii[r] - radius_width / 2.0)) $
                  and (radius lt (radii[r] + radius_width / 2.0)), n_pixels)
;      mean_pb[a, r] = n_pixels eq 0L ? !values.f_nan : mean(pb[ind])
      mean_pb[r] = n_pixels eq 0L ? !values.f_nan : mean(pb[ind])
;    endfor
  endfor

  return, mean_pb
end


;+
; Plot quantities in L1.5 files, such as sky transmission.
;
; :Keywords:
;   run : in, required, type=object
;     KCor run object
;-
pro kcor_plot_l1, run=run
  compile_opt strictarr

  original_device = !d.name
  skytrans_range = [0.8, 1.2]

  base_dir  = run->config('processing/raw_basedir')
  date_dir  = filepath(run.date, root=base_dir)
  plots_dir = filepath('p', root=date_dir)
  l1_dir    = filepath('level1', root=date_dir)

  logger_name = 'kcor/eod'

  mg_log, 'starting...', name=logger_name, /info

  l1_files = file_search(filepath('*_*_kcor_l1.5.fts.gz', root=l1_dir), $
                         count=n_l1_files)
  if (n_l1_files eq 0L) then begin
    mg_log, 'no L1 files to plot', name=logger_name, /warn
    goto, done
  endif

  n_angles = 1200L
  radii = [1.11, 1.3, 1.5, 1.8]   ; R_sun
  radius_width = 0.01
  yranges = [[1.0e-07, 7.0e-07], $
             [6.0e-08, 3.0e-07], $
             [5.0e-09, 1.2e-07], $
             [1.0e-09, 4.0e-08]]
  plate_scale = run->epoch('plate_scale')

  times = fltarr(n_l1_files)
  skytrans = fltarr(n_l1_files)
  mean_pb = fltarr(n_elements(radii), n_l1_files)
  for f = 0L, n_l1_files - 1L do begin
    fits_open, l1_files[f], fcb
    fits_read, fcb, pB, header
    fits_close, fcb

    date_obs = sxpar(header, 'DATE-OBS')
    date = kcor_parse_dateobs(date_obs, hst_date=hst_date)
    times[f] = hst_date.ehour + 10.0

    strans = fxpar(header, 'SKYTRANS', /null)
    skytrans[f] = n_elements(strans) eq 0L ? !values.f_nan : strans

    mean_pb[*, f] = kcor_plot_l1_mean_pb(pB, date, $
                                         radii, radius_width, $
                                         plate_scale)
  endfor

  !null = where(finite(skytrans) eq 0L, n_nan)
  !null = where(skytrans lt skytrans_range[0], n_lt)
  !null = where(skytrans gt skytrans_range[1], n_gt)

  n_bad = n_nan + n_lt + n_gt
  if (n_bad gt 0L) then begin
    mg_log, '%d out of range sky transmission values', n_bad, $
            name=logger_name, /error
  endif

  charsize = 1.15

  set_plot, 'Z'
  device, set_resolution=[772, 500], decomposed=0, set_colors=256, $
          z_buffering=0
  loadct, 0, /silent

  plot, times, skytrans, $
        title=string(run.date, format='(%"Sky transmission for %s")'), $
        xtitle='Hours [UT]', $
        yrange=skytrans_range, ystyle=1, ytitle='Sky transmission', $
        background=255, color=0, charsize=charsize

  im = tvrd()
  write_gif, filepath(string(run.date, format='(%"%s.kcor.skytrans.gif")'), $
                      root=plots_dir), $
             im

  ; plot average pB over the day at several heights

  device, set_resolution=[772, 500], decomposed=0, set_colors=256, z_buffering=0

  for r = 0L, n_elements(radii) - 1L do begin
    plot, times, reform(mean_pb[r, *]), $
          title=string(radii[r], run.date, $
                       format='(%"KCor mean pB @ %0.2f R_sun for %s")'), $
          xmargin=[11, 3], xticklen=1.0, xtitle='Hours [UT]', $
          yticklen=1.0, yrange=yranges[*, r], ystyle=1, ytitle='pB', $
          ytickformat='(E0.1)', $
          background=255, color=200, charsize=charsize

    plot, times, reform(mean_pb[r, *]), /noerase, $
          title=string(radii[r], run.date, $
                       format='(%"KCor mean pB @ %0.2f R_sun for %s")'), $
          xmargin=[11, 3], xticklen=0.025, xtitle='Hours [UT]', $
          yticklen=0.03, yrange=yranges[*, r], ystyle=1, ytitle='pB', $
          ytickformat='(E0.1)', $
          color=0, charsize=charsize

    im = tvrd()
    write_gif, filepath(string(run.date, radii[r], $
                               format='(%"%s.kcor.mean-pb-%0.2f.gif")'), $
                        root=plots_dir), $
               im
  endfor

  done:
  set_plot, original_device

  mg_log, 'done', name=logger_name, /info
end


; main-level program

date = '20160603'
config_filename = filepath('kcor.latest.cfg', $
                           subdir=['..', '..', 'config'], $
                           root=mg_src_root())
run = kcor_run(date, config_filename=config_filename)
kcor_plot_l1, run=run
obj_destroy, run

end
