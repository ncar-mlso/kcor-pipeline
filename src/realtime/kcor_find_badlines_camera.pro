; docformat = 'rst'

;+
; Find indices of anomalous lines.
;
; :Returns:
;   `lonarr` of indices, `!null` if none
;
; :Params:
;   im : in, required, type="fltarr(nx, ny)"
;     coronal image from one camera to check
;
; :Keywords:
;   difference_threshold : in, required, type=float
;     minimum value of the mean of a row of column differences to be considered
;     for being a bad row
;   medians : out, optional, type=fltarr(1024)
;     set to named variable to retrieve the median of each row in the column
;     convolution
;-
function kcor_find_badlines_camera, corona, $
                                    difference_threshold=difference_threshold, $
                                    n_skip=n_skip, $
                                    medians=medians
  compile_opt strictarr

  col_diff_kernel = fltarr(3, 3)
  col_diff_kernel[1, 1] = 1.0
  col_diff_kernel[1, [0, 2]] = -0.5
  col_diffs = convol(corona, col_diff_kernel)
  medians = median(abs(col_diffs), dimension=1)

  ; number of lines to skip at the top and bottom of the image
  _n_skip = n_elements(n_skip) eq 0L ? 3 : n_skip

  bad_lines = where(medians[_n_skip:-_n_skip-1] gt difference_threshold, $
                    n_bad_lines, /null)

  ; need to add bad the index offset for the skipping lines
  if (n_bad_lines gt 0L) then bad_lines += _n_skip

  ; if multiple bad lines found, take the worst one in each contiguous block of
  ; bad lines
  if (n_bad_lines gt 1L) then begin
    dims = size(corona, /dimensions)
    mask = bytarr(dims[1])
    mask[bad_lines] = 1B
    labels = label_region(mask)
    n_labels = max(labels)
    worse_lines = lonarr(n_labels)

    for r = 1L, n_labels do begin
      ind = where(labels eq r, count)
      if (count gt 0L) then begin
        !null = max(medians[ind], max_index)
        worse_lines[r - 1L] = ind[max_index]
      endif
    endfor

    bad_lines = worse_lines
  endif

  return, bad_lines
end


; main-level example program

f = filepath('20190625_174555_kcor.fts.gz', $
             subdir=['20190625', 'level0'], $
             root='/hao/sunset/Data/KCor/raw.latest')

im = readfits(f, heade)
corona1 = kcor_corona(im[*, *, *, 1]
cam1_badlines = kcor_find_badlines_camera(corona1, diff_threshold=20.0)

end
