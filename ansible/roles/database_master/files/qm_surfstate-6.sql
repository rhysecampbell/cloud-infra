CREATE OR REPLACE FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric)
  RETURNS integer AS
$BODY$BEGIN
IF (symbol LIKE '%SurfaceStatus.%' AND round(test_value) in (7, 9))
OR (symbol IN ('36', '51', '66', '81') AND round(test_value)%10 IN (6, 7))
THEN
  INSERT INTO alerts(alert_id, sensor_id, channel, message)
  SELECT 'ice/region', sens_id, ch_id, 'WARNING! Winter surface conditions detected in region'
  WHERE NOT EXISTS(
    select * from alerts
    where ch_id = channel
      and alert_id = 'ice/region'
      and entry_datetime < CURRENT_TIMESTAMP
      and entry_datetime >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
  );
  INSERT INTO alerts(alert_id, sensor_id, message, target, locbased)
  SELECT 'ice/loc', sens_id, 'WARNING! Winter surface conditions detected in your vicinity. Please drive carefully!', '@station@', True
  WHERE NOT EXISTS(
    select * from alerts
    where sens_id = sensor_id
      and alert_id = 'ice/loc'
      and entry_datetime < CURRENT_TIMESTAMP
      and entry_datetime >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
  );
  RETURN 105;
ELSE
  RETURN 10;
END IF;
END$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION qm_surfstate(integer, text, text, numeric)
  OWNER TO cloud;
GRANT EXECUTE ON FUNCTION qm_surfstate(integer, text, text, numeric) TO cloud;
GRANT EXECUTE ON FUNCTION qm_surfstate(integer, text, text, numeric) TO public;
GRANT EXECUTE ON FUNCTION qm_surfstate(integer, text, text, numeric) TO qualwrite;
