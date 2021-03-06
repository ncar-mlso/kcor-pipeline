; docformat = 'rst'

;+
; Display image, annotate, and save as a full resolution GIF file.
;
; :Params:
;   filename : in, required, type=string
;     level 0 filename
;   corona : in, required, type="fltarr(1024, 1024)"
;     corona
;   date_obs : in, required, type=string
;     observation date
;
; :Keywords:
;   scaled_image : out, optional, type=lonarr
;     set to a named variable to retrieve the scaled image
;   nomask : in, optional, type=boolean
;     set to not mask the occulter
;   run : in, required, type=object
;     KCor run object
;   log_name : in, optional, type=string
;     logger name to send log messages to
;   level : in, required, type=integer
;     level 1 or 2
;-
pro kcor_create_gif, filename, corona, date_obs, $
                     scaled_image=scaled_image, $
                     nomask=nomask, $
                     run=run, $
                     log_name=log_name, $
                     level=level
  compile_opt strictarr

  date_struct = kcor_parse_dateobs(date_obs)
  sun, date_struct.year, date_struct.month, date_struct.day, date_struct.ehour, $
       sd=radsun
  r_photo = radsun / run->epoch('plate_scale')

  original_device = !d.name
  set_plot, 'Z'
  device, get_decomposed=original_decomposed
  device, set_resolution=[1024, 1024], $
          decomposed=0, $
          set_colors=256, $
          z_buffering=0
  tvlct, rgb, /get

  ; load color table
  lct, filepath('quallab_ver2.lut', root=run.resources_dir)
  tvlct, red, green, blue, /get

  loadct, 0, /silent
  gamma_ct, run->epoch('display_gamma'), /current
  tvlct, red, green, blue, /get

  erase

  display_factor = 1.0e6
  scaled_image = bytscl((display_factor * corona)^run->epoch('display_exp'), $
                        min=display_factor * run->epoch('display_min'), $
                        max=display_factor * run->epoch('display_max'))
  tv, scaled_image

  xyouts, 4, 990, 'MLSO/HAO/KCOR', color=255, charsize=1.5, /device
  xyouts, 4, 970, 'K-Coronagraph', color=255, charsize=1.5, /device
  xyouts, 512, 1000, 'North', color=255, charsize=1.2, alignment=0.5, $
          /device
  xyouts, 1018, 995, $
          string(date_struct.day, date_struct.month_name, date_struct.year, $
                 format='(%"%02d %s %04d")'), $
          /device, alignment=1.0, $
          charsize=1.2, color=255
  xyouts, 1010, 975, $
          string(date_struct.doy, format='(%"DOY %03d")'), $
          /device, $
          alignment=1.0, charsize=1.2, color=255
  xyouts, 1018, 955, $
          string(date_struct.hour, date_struct.minute, date_struct.second, $
                 format='(%"%02d:%02d:%02d UT")'), $
          /device, $
          alignment=1.0, charsize=1.2, color=255
  xyouts, 22, 512, 'East', color=255, charsize=1.2, alignment=0.5, $
          orientation=90., /device
  xyouts, 1012, 512, 'West', color=255, charsize=1.2, alignment=0.5, $
          orientation=90., /device
  xyouts, 4, 46, string(level, format='(%"Level %d data")'), $
          color=255, charsize=1.2, /device
  xyouts, 4, 26, string(run->epoch('display_min'), $
                        run->epoch('display_max'), $
                        format='(%"min/max: %0.2g, %0.2g")'), $
          color=255, charsize=1.2, /device
  xyouts, 4, 6, $
          string(run->epoch('display_exp'), $
                 run->epoch('display_gamma'), $
                 format='(%"scaling: Intensity ^ %3.1f, gamma=%4.2f")'), $
          color=255, charsize=1.2, /device
  xyouts, 1018, 6, 'Circle = photosphere.', $
          color=255, charsize=1.2, /device, alignment=1.0

  ; image has been shifted to center of array
  ; draw circle at photosphere
  if (~keyword_set(nomask)) then begin
    kcor_add_directions, fltarr(2) + 511.5, r_photo, $
                         charsize=1.5, dimensions=lonarr(2) + 1024L
    kcor_suncir, 1024, 1024, 511.5, 511.5, 0, 0, r_photo, 0.0, log_name=log_name
  endif

  device, decomposed=1
  save     = tvrd()
  gif_file = string(strmid(file_basename(filename), 0, 20), $
                    level, $
                    keyword_set(nomask) ? '_nomask' : '', $
                    format='(%"%s_l%d%s.gif")')
  write_gif, filepath(gif_file, $
                      subdir=[run.date, string(level, format='(%"level%d")')], $
                      root=run->config('processing/raw_basedir')), $
             save, red, green, blue

  tvlct, rgb
  device, decomposed=original_decomposed
  set_plot, original_device
end
