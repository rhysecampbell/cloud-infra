-- anything that reported 60mins BEFORE the last reported sensor at this station
CREATE OR REPLACE FUNCTION qmfault.get_sensors_missing_list(owning_region integer, lookback_minutes smallint DEFAULT 60)
  RETURNS SETOF qmfault.missing_sensor_holder AS
$BODY$BEGIN 

	RETURN QUERY
		-- return these
		select last_reading.sensor_id::integer, qm.sensor_identity.stn_id, sensor_identity.sensor_master_id, max_time_table.last_reading_time
		-- from the last reading table
		from qm.last_reading
		-- to get to sensor master
		inner join qm.sensor_identity on last_reading.sensor_id = sensor_identity.sensor_id
		-- needed if globally monitored
		inner join qm.sensor_master_identity on sensor_identity.sensor_master_id = sensor_master_identity.sensor_master_id
		-- only sensors for stations in this region
		inner join qm.station_identity on (sensor_identity.stn_id = station_identity.stn_id and station_identity.owning_region_id = get_sensors_missing_list.owning_region)
		-- last reading for any sensor, this station, within the station offline window
		inner join (
			select max(last_datetime) as last_reading_time, station_identity.stn_id
			from qm.last_reading
			inner join qm.sensor_identity on last_reading.sensor_id = sensor_identity.sensor_id
			inner join qm.sensor_master_identity on sensor_identity.sensor_master_id = sensor_master_identity.sensor_master_id
			inner join qm.station_identity on (sensor_identity.stn_id = station_identity.stn_id and station_identity.owning_region_id = get_sensors_missing_list.owning_region)
			where last_reading.last_datetime > now() - (get_sensors_missing_list.lookback_minutes * INTERVAL '1 minute')
			group by station_identity.stn_id
			order by station_identity.stn_id
		) as max_time_table on qm.sensor_identity.stn_id = max_time_table.stn_id
		
		-- check for any overrides of any kind at region or station level
		LEFT JOIN LATERAL
			(SELECT v_region_id from qm.station_alias_monitored_sensor group by v_region_id) as rms_any
				on rms_any.v_region_id = station_identity.owning_region_id
		LEFT JOIN LATERAL
			(SELECT stn_id from qm.station_monitored_sensor group by stn_id) as sms_any
				on sms_any.stn_id = station_identity.stn_id
				
		-- region/station specific overrides
		left join qm.station_monitored_sensor on sensor_identity.sensor_master_id = station_monitored_sensor.sensor_master_id 
		left join qm.station_alias_monitored_sensor on sensor_identity.sensor_master_id = station_alias_monitored_sensor.sensor_master_id 
		
		where
		-- the last reading more than 60 minutes before the last reading of any station
		max_time_table.last_reading_time > last_reading.last_datetime + INTERVAL '60 minute'
		-- we are monitoring the station
		AND station_identity.monitored = true 
		
		AND true = 
			CASE 
				-- any overrides by the station?
				WHEN sms_any.stn_id is not null then
					-- make sure this particular sensor is monitored
					(station_monitored_sensor.sensor_master_id is not null)
				-- any overrides by the region?
			    WHEN rms_any.v_region_id is not null then
			    	-- make sure this particular sensor is monitored, by the region
					(station_alias_monitored_sensor.sensor_master_id is not null)
			    ELSE
			    	-- only monitored - change from former code
					sensor_master_identity.monitored = true 
				END
		
		order by sensor_identity.stn_id, last_reading.sensor_id;

END;$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION qmfault.get_sensors_missing_list(integer, smallint)
  OWNER TO postgres;
