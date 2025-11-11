--- check-lsn.sql
use inventory;
SELECT sys.fn_cdc_get_min_lsn('udpdate_lag') AS min_lsn,
       sys.fn_cdc_get_max_lsn() AS max_lsn;
			 


SELECT 
  sys.fn_cdc_get_min_lsn('udpdate_lag') AS bin_min_lsn,
  sys.fn_cdc_get_max_lsn() AS bin_max_lsn,
  sys.fn_varbintohexstr(sys.fn_cdc_get_min_lsn('udpdate_lag')) AS min_lsn_hex,
  sys.fn_varbintohexstr(sys.fn_cdc_get_max_lsn()) AS max_lsn_hex;
	

