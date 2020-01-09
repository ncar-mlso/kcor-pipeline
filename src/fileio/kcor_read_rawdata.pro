; docformat = 'rst'

;+
; Routine to read raw KCor data and, optionally, repair it.
;
; :Params:
;   filename : in, required, type=string
;     raw FITS filename
;
; :Keywords:
;   image : out, optional, type="uintarr(1024, 1024, 4, 2)"
;     repaired image
;   header : out, optional, type=strarr
;     repaired header
;   repair_routine : in, optional, type=string
;     if present, repair routine will be called; interface is::
;
;       pro repair_routine, image=im, header=header
;
;     where `im` and `header` are inputs and outputs
;-
pro kcor_read_rawdata, filename, $
                       image=im, header=header, $
                       repair_routine=repair_routine, $
                       errmsg=errmsg
  compile_opt strictarr

  errmsg = ''

  case 1 of
    arg_present(im) && arg_present(header): im = readfits(filename, header, /silent)
    arg_present(im): im = readfits(filename, /silent)
    arg_present(header): header = headfits(filename, errmsg=errmsg, /silent)
    else: return
  endcase

  if (n_elements(repair_routine) gt 0L && repair_routine ne '') then begin
    call_procedure, repair_routine, image=im, header=header
  endif
end


; main-level example program

f = '/hao/mlsodata1/Data/KCor/raw/20191207/level0/20191207_214536_kcor.fts.gz'
kcor_read_rawdata, f, image=im, header=header, repair_routine='kcor_repair_mid2out'

end