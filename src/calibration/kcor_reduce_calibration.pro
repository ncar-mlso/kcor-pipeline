; docformat = 'rst'

;+
; Main calibration routine.
;
; :Uses:
;   kcor_read_calibration_text, kcor_reduce_calibration_read_data,
;   kcor_reduce_calibration_setup_lm, kcor_reduce_calibration_model,
;   kcor_reduce_calibration_write_data
;
; :Params:
;   date : in, required, type=date
;     date in the form 'YYYYMMDD' to produce calibration for
;
; :Keywords:
;   config_filename : in, required, type=string
;     filename of configuration file
;-
pro kcor_reduce_calibration, date, config_filename=config_filename
  common kcor_random, seed

  run = kcor_run(date, config_filename=config_filename)

  file_list = kcor_read_calibration_text(date, run.process_basedir, $
                                         exposures=exposures, $
                                         n_files=n_files)

  if (n_files lt 1L) then begin
    mg_log, 'missing or empty calibration_files.txt file', name='kcor/cal', /error
    goto, done
  endif

  ; check to make sure exposures are all the same
  unique_exposure_indices = uniq(exposures, sort(exposures))
  if (n_elements(unique_exposure_indices) gt 1L) then begin
    mg_log, 'more than one exposure time in calibration_files.txt', $
            name='kcor/cal', /error
    goto, done
  endif

  ; read the data
  mg_log, 'reading data...', name='kcor/cal', /info
  kcor_reduce_calibration_read_data, file_list, $
                                     filepath('level0', $
                                              subdir=date, $
                                              root=run.raw_basedir), $
                                     data=data, metadata=metadata
  sz = size(data.gain, /dimensions)
  mg_log, 'done reading data', name='kcor/cal', /info

  ; modulation matrix
  mmat = fltarr(sz[0], sz[1], 2, 3, 4)
  dmat = fltarr(sz[0], sz[1], 2, 4, 3)

  ; number of points in the field
  npick = run.npick

  ; fit the calibration data
  for beam = 0, 1 do begin
    mg_log, 'processing beam %d', beam, name='kcor/cal', /info

    ; pick pixels with good signal
    w = where(data.gain[*, *, beam] ge median(data.gain[*, *, beam]) / sqrt(2), nw)
    if (nw lt npick) then begin
      mg_log, 'didn''t find enough pixels with signal: %d', nw, $
              name='kcor/cal', /error
      return
    endif
    pick = sort(randomu(seed, nw))
    pixels = array_indices(data.gain[*, *, beam], w[pick[0:npick - 1]])

    mg_log, 'fitting model to data...', name='kcor/cal', /info
    fits = dblarr(17, npick)
    fiterrors = dblarr(17, npick)
    for i = 0, npick - 1 do begin
      ; setup the LM
      pixel = {x:pixels[0, i], y:pixels[1, i]}
      kcor_reduce_calibration_setup_lm, data, metadata, pixel, beam, parinfo, functargs

      ; run the minimization
      fits[*, i] = mpfit('kcor_reduce_calibration_model', parinfo=parinfo, $
                         functargs=functargs, status=status, errmsg=errmsg, $
                         niter=niter, npegged=npegged, perror=fiterror, /quiet)
      fiterrors[*, i] = fiterror

      if i ne 0 and i mod (npick / 10) eq 0 then begin
        mg_log, '%d%% complete', 100L * i / npick, name='kcor/cal', /debug
      endif
    endfor

    ; Parameters 8-12 may have gone to equivalent solutions due to periodicity
    ; of the parameter space. We have to remove the ambiguity.
    for i = 9, 12 do begin
      ; guarantee the values are between -2*pi and +2*pi first
      fits[i, *] = fits[i, *] mod (2 * !pi)
      ; find approximately the most likely value
      h = histogram(fits[i, *], locations=l, binsize=0.1 * !pi)
      mlv = l[(where(h eq max(h)))[0]]
      ; center the interval around the mlv
      fits[i, *] += (fix(fits[i, *] lt (mlv - !pi)) $
                       - fix(fits[i, *] gt (mlv + !pi))) * 2 * !pi
    endfor
    mg_log, 'done fitting model', name='kcor/cal', /info

    ; 4th order polynomial fits for all parameters
    ; set up some things
    ; center the pixel values in the image for better numerical stability
    mg_log, 'fitting 4th order polynomials...', name='kcor/cal', /info

    cpixels = pixels - rebin([sz[0], sz[1]] / 2., 2, npick)
    x = (findgen(sz[0]) - sz[0] / 2.) # replicate(1., sz[1])  ; X values at each point
    y = replicate(1., sz[1]) # (findgen(sz[1]) - sz[1] / 2.)  ; Y values at each point
    ; pre-compute the x^i y^j matrices
    degree = 4
    n2 = (degree + 1) * (degree + 2) / 2
    m = sz[0] * sz[1]
    ut = dblarr(n2, m, /nozero)
    j0 = 0L
    for i = 0, degree do begin
      for j = 0, degree - i do $
          ut[j0 + j, 0] = reform(x^i * y^j, 1, m)
      j0 += degree - i + 1
    endfor
    ; create the fit images
    fitimgs = fltarr(sz[0], sz[1], 12)
    for i = 1, 12 do begin
      tmp = sfit([cpixels, fits[i, *]], degree, kx=kx, /irregular, /max_degree)
      fitimgs[*, *, i - 1] = reform(reform(kx, n2) # ut, sz[0], sz[1])
    endfor
    mg_log, 'done fitting 4th order polynomials', name='kcor/cal', /info

    ; populate the modulation matrix
    mg_log,  'calculating modulation/demodulation matrices... ', $
             name='kcor/cal', /info
    mmat[*, *, beam, 0, *] = fitimgs[*, *, 0:3]
    mmat[*, *, beam, 1, *] = fitimgs[*, *, 0:3] $
                               * fitimgs[*, *, 4:7] $
                               * cos(fitimgs[*, *, 8:11])
    mmat[*, *, beam, 2, *] = fitimgs[*, *, 0:3] $
                               * fitimgs[*, *, 4:7] $
                               * sin(fitimgs[*, *, 8:11])
    ; populate the demodulation matrix
    for x = 0, sz[0] - 1 do for y = 0, sz[1] - 1 do begin
      xymmat = reform(mmat[x, y, beam, *, *])
      txymmat = transpose(xymmat)
      dmat[x, y, beam, *, *] = la_invert(txymmat ## xymmat) ## txymmat
    endfor
    mg_log, 'done calculating moduluation/demodulation matrices', $
            name='kcor/cal', /info

    ; save pixels, fits, fiterrors
    if (beam eq 0) then begin
      pixels0 = pixels
      fits0 = fits
      fiterrors0 = fiterrors
    endif else if (beam eq 1) then begin
      pixels1 = pixels
      fits1 = fits
      fiterrors1 = fiterrors
    endif
  endfor

  ; write the calibration data
  tokens = strsplit(file_list[0], '_', /extract)
  first_time = tokens[1]
  outfile_basename = string(date, first_time, float(exposures[0]), $
                            format='(%"%s_%s_kcor_cal_%0.1fms.ncdf")')
  outfile = filepath(outfile_basename, root=run.cal_out_dir)

  if (~file_test(run.cal_out_dir, /directory)) then file_mkdir, run.cal_out_dir

  mg_log, 'writing output to %s', outfile, name='kcor/cal', /info
  kcor_reduce_calibration_write_data, data, metadata, $
                                      mmat, dmat, outfile, $
                                      pixels0, fits0, fiterrors0, $
                                      pixels1, fits1, fiterrors1
  mg_log, 'done writing output', name='kcor/cal', /info

  mg_log, 'done', name='kcor/cal', /info

  done:
  obj_destroy, run
end


; main-level example program

config_filename = filepath('kcor.mgalloy.mahi.latest.cfg', $
                           subdir=['..', '..', 'config'], $
                           root=mg_src_root())

kcor_reduce_calibration, '20161127', config_filename=config_filename

end
