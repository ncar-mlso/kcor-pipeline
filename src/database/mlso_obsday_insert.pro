function mlso_obsday_insert, date, run=run
; IDL function that checks if the passed date (observation day as yyyymmdd) is in the mlso_numfiles db table.
;   If it is, the corresponding day_id is returned.  If it is not, a new entry in the table is
;   created (day_id and obs_day fields) and the new day_id is returned.
;
; 2017-03-20 Don Kolinski
;

	; Connect to MLSO database.

	; Note: The connect procedure accesses DB connection information in the file
	;       .mysqldb. The "config_section" parameter specifies
	;       which group of data to use.

	db = mgdbmysql()
	db->connect, config_filename=run.database_config_filename, $
			   config_section=run.database_config_section

	db->getProperty, host_name=host
	mg_log, 'connected to %s...', host, name='kcor/dbinsert', /info

	db->setProperty, database='MLSO'



	obs_day = strmid(date, 0, 4)+'-'+strmid(date, 4, 2)+'-'+strmid(date, 6, 2)
	obs_day_index = 0;
	
	; Check to see if passed observation day date is in mlso_numfiles table
	obs_day_results = db->query('SELECT count(obs_day) FROM mlso_numfiles WHERE obs_day=''%s''', $
								 obs_day, fields=fields)
	obs_day_count = obs_day_results.COUNT_OBS_DAY_

	if (obs_day_count eq 0) then begin
		; If not already in table, create a new entry for the passed observation day date
		db->execute, 'INSERT INTO mlso_numfiles (obs_day) VALUES (''%s'') ', $
                 obs_day, $
                 status=status, error_message=error_message, sql_statement=sql_cmd
		mg_log, '%d, error message: %s', status, error_message, $
            name='kcor/dbinsert', /debug
		mg_log, 'sql_cmd: %s', sql_cmd, name='kcor/dbinsert', /debug
		
		obs_day_index = db->query('SELECT LAST_INSERT_ID()')
	
	endif else begin
		; If it is in the database, get the corresponding index, day_id
		obs_day_results = db->query('SELECT day_id FROM mlso_numfiles WHERE obs_day=''%s''', $
								 obs_day, fields=fields)	
		obs_day_index = obs_day_results.day_id
	endelse	
	obj_destroy, db
								 
	return, obs_day_index							 
end

date = '20170205'
run = kcor_run(date, $
               config_filename=filepath('kcor.kolinski.mahi.latest.cfg', $
                                        subdir=['..', '..', 'config'], $
                                        root=mg_src_root()))
										
obs_day_num = mlso_obsday_insert(date, run=run)
print, obs_day_num
end


