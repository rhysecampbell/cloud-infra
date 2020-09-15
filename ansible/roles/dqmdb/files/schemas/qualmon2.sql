--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: exportws; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA exportws;


ALTER SCHEMA exportws OWNER TO postgres;

--
-- Name: forecast; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA forecast;


ALTER SCHEMA forecast OWNER TO postgres;

--
-- Name: qm; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA qm;


ALTER SCHEMA qm OWNER TO postgres;

--
-- Name: qmfault; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA qmfault;


ALTER SCHEMA qmfault OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


SET search_path = public, pg_catalog;

--
-- Name: dq_sensor_holder; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE dq_sensor_holder AS (
	sensor_id integer,
	status integer,
	stn_id integer,
	sensor_master_id integer
);


ALTER TYPE public.dq_sensor_holder OWNER TO postgres;

SET search_path = qm, pg_catalog;

--
-- Name: station_observations_holder; Type: TYPE; Schema: qm; Owner: postgres
--

CREATE TYPE station_observations_holder AS (
	obs_creationtime timestamp without time zone,
	stn_id integer,
	sensor_id integer,
	nvalue double precision,
	nvalue_str character varying(500),
	qc_check_total integer,
	qc_check_failed integer,
	lane_no integer,
	sensor_no integer,
	sensor_master_id integer,
	symbol character varying(100),
	codespace smallint
);


ALTER TYPE qm.station_observations_holder OWNER TO postgres;

SET search_path = qmfault, pg_catalog;

--
-- Name: data_quality_sensor_holder; Type: TYPE; Schema: qmfault; Owner: postgres
--

CREATE TYPE data_quality_sensor_holder AS (
	data_quality_id bigint,
	sensor_id integer,
	status integer,
	stn_id integer,
	sensor_master_id integer,
	obs_creationtime timestamp without time zone,
	owning_region_id integer,
	fault_type_id integer
);


ALTER TYPE qmfault.data_quality_sensor_holder OWNER TO postgres;

--
-- Name: missing_sensor_holder; Type: TYPE; Schema: qmfault; Owner: postgres
--

CREATE TYPE missing_sensor_holder AS (
	sensor_id integer,
	stn_id integer,
	sensor_master_id integer,
	latest_instance timestamp without time zone
);


ALTER TYPE qmfault.missing_sensor_holder OWNER TO postgres;

--
-- Name: stuck_sensor_holder; Type: TYPE; Schema: qmfault; Owner: postgres
--

CREATE TYPE stuck_sensor_holder AS (
	sensor_id integer,
	stn_id integer,
	sensor_master_id integer,
	obs_creationtime timestamp without time zone
);


ALTER TYPE qmfault.stuck_sensor_holder OWNER TO postgres;

SET search_path = forecast, pg_catalog;

--
-- Name: forecast_insert_trigger_func(); Type: FUNCTION; Schema: forecast; Owner: postgres
--

CREATE FUNCTION forecast_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare

BEGIN
	IF (NEW.lat is not null AND NEW.lon is not null) THEN
		NEW.geom = ST_Transform( ST_SetSRID( ST_MakePoint(NEW.lon, NEW.lat) ,4326) ,4326);
		RETURN NEW; -- probably a good idea to return the insertable row
	ELSE
		RAISE EXCEPTION 'lat or lon is null, unable to insert forecast';
	END IF;
	RETURN NULL;
END;
$$;


ALTER FUNCTION forecast.forecast_insert_trigger_func() OWNER TO postgres;

SET search_path = public, pg_catalog;

--
-- Name: manage_partition(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION manage_partition() RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
    check_dow INT;
    start_date text;
    end_date text;
    drop_date text;
    command_str text;
BEGIN
-- function to create a new weekly (value, quality) partitions and drop old ones
-- MUST only be run on a Monday for correct operation  - BJT November 2014
-------------------------------------------------------

-- check day of week
select INTO check_dow extract(dow from localtimestamp);

if check_dow != 1 then
  -- day of week is not a Monday so:
  -- write a 'notice'; and exit function
  RAISE NOTICE 'Not Monday Exiting... (%)', check_dow;
  RETURN FALSE;
END IF;

-- Day of week is Monday so:
-- Create a partition starting one week ahead of today
start_date = TO_CHAR(localtimestamp + '7 days'::interval, 'YYYY_MM_DD');

-- Partition end date is in the same week so only create a single partition
end_date = TO_CHAR(localtimestamp + '8 days'::interval, 'YYYY_MM_DD');


-- Build command to execute (calls on pre-defined function)
command_str = concat('select * from data_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
--execute command_str;

RAISE NOTICE 'add data command %', command_str;

--*********************************************************************************************

command_str = concat('select * from quality_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
execute command_str;

RAISE NOTICE 'add quality command %', command_str;

--*********************************************************************************************

-- Now drop old partitions ----
-- MUST be run on a Monday and be multiples of 7 days to match the partition date.

drop_date = TO_CHAR(localtimestamp - '14 days'::interval, 'YYYY_MM_DD');

execute 'truncate table qm.data_quality_' || drop_date || '';
execute 'drop table qm.data_quality_' || drop_date || '';

execute 'truncate table qm.data_value_' || drop_date || '';
execute 'drop table qm.data_value_' || drop_date || ''; 

analyse;

RAISE NOTICE 'Dropped old value and quality partitions [%]', drop_date;

RETURN TRUE;

END$$;


ALTER FUNCTION public.manage_partition() OWNER TO postgres;

--
-- Name: script_foreign_tables(text, text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION script_foreign_tables(param_server text, param_schema_search text, param_table_search text, param_ft_prefix text) RETURNS SETOF text
    LANGUAGE sql
    AS $_$
-- params: param_server: name of foreign data server
--        param_schema_search: wildcard search on schema use % for non-exact
--        param_ft_prefix: prefix to give new table in target database 
--                        include schema name if not default schema
-- example usage: SELECT script_foreign_tables('prod_server', 'ch01', '%', 'ch01.ft_');
  WITH cols AS 
   ( SELECT cl.relname As table_name, na.nspname As table_schema, att.attname As column_name
    , format_type(ty.oid,att.atttypmod) AS column_type
    , attnum As ordinal_position
      FROM pg_attribute att
      JOIN pg_type ty ON ty.oid=atttypid
      JOIN pg_namespace tn ON tn.oid=ty.typnamespace
      JOIN pg_class cl ON cl.oid=att.attrelid
      JOIN pg_namespace na ON na.oid=cl.relnamespace
      LEFT OUTER JOIN pg_type et ON et.oid=ty.typelem
      LEFT OUTER JOIN pg_attrdef def ON adrelid=att.attrelid AND adnum=att.attnum
     WHERE 
     -- only consider non-materialized views and concrete tables (relations)
     cl.relkind IN('v','r') 
      AND na.nspname LIKE $2 AND cl.relname LIKE $3 
       AND cl.relname NOT IN('spatial_ref_sys', 'geometry_columns'
          , 'geography_columns', 'raster_columns')
       AND att.attnum > 0
       AND NOT att.attisdropped 
     ORDER BY att.attnum )
        SELECT 'CREATE FOREIGN TABLE ' || $4  || table_name || ' ('
         || string_agg(quote_ident(column_name) || ' ' || column_type 
           , ', ' ORDER BY ordinal_position)
         || ')  
   SERVER ' || quote_ident($1) || '  OPTIONS (schema_name ''' || quote_ident(table_schema) 
     || ''', table_name ''' || quote_ident(table_name) || '''); ' As result        
FROM cols
  GROUP BY table_schema, table_name
$_$;


ALTER FUNCTION public.script_foreign_tables(param_server text, param_schema_search text, param_table_search text, param_ft_prefix text) OWNER TO postgres;

SET search_path = qm, pg_catalog;

--
-- Name: copy_lat_lon_to_geom(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION copy_lat_lon_to_geom() RETURNS void
    LANGUAGE sql
    AS $$
-- simple query to populate the geom with lat, lon point data BJT March 2015
-- and set the geom_updataed to true.
-- usage
-- select qm.copy_lat_lon_to_geom()
UPDATE qm.station_identity
        SET geom = ST_SetSRID(ST_Point( lon, lat),4326), geom_updated = true
        where geom_updated = false
        and lat is not null
        and lon is not null;
$$;


ALTER FUNCTION qm.copy_lat_lon_to_geom() OWNER TO postgres;

--
-- Name: data_creation_week(date, date); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION data_creation_week(date, date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	create_query text;
	index_query text;
	index_query2 text;
	index_query3 text;
BEGIN
	FOR create_query, index_query, index_query2, index_query3 IN SELECT
			'create table qm.data_value_' || TO_CHAR( d, 'YYYY_MM_DD' )

			||  ' ( CONSTRAINT data_value_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_pk'
			|| ' PRIMARY KEY (obs_creationtime,sensor_id),'			
						
			||  '  CONSTRAINT data_value_sensor_id' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_fk'
			|| ' FOREIGN KEY (sensor_id)  REFERENCES qm.sensor_identity (sensor_id) MATCH SIMPLE ,'
			|| '  check( obs_creationtime >= date '''
			
			|| TO_CHAR( d, 'YYYY-MM-DD' )
			|| ''' and obs_creationtime < date '''
			|| TO_CHAR( d + INTERVAL '1 week', 'YYYY-MM-DD' )
			|| ''' ) ) inherits ( qm.data_value );' 
			|| ' ALTER TABLE qm.data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' ) 
			|| ' OWNER TO postgres',
			
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_stn_idx on qm.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( stn_id);',
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_sensor_idx on qm.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (sensor_id) ;',
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_insertiontime_idx on qm.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (db_insertiontime) ;'

			
   		FROM generate_series( $1, $2, '1 week' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
		EXECUTE index_query3;
	END LOOP;
END;
$_$;


ALTER FUNCTION qm.data_creation_week(date, date) OWNER TO postgres;

--
-- Name: data_insert_trigger_func(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION data_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare

    last_w date 		:= date_trunc('week', now() - '1 week'::interval);
    cur_w date 			:= date_trunc('week', now());      
    plus1_w date 		:= date_trunc('week', now() + '1 week'::interval);
    plus2_w date 		:= date_trunc('week', now() + '2 week'::interval);
    
    cur_file text;

BEGIN
        IF ( NEW.obs_creationtime >= cur_w AND NEW.obs_creationtime < plus1_w ) THEN 
	        cur_file:= 'qm.data_value_' || to_char(cur_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW; 
	ELSIF ( NEW.obs_creationtime >= plus1_w AND NEW.obs_creationtime < plus2_w ) THEN 
	        cur_file:= 'qm.data_value_' || to_char(plus1_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;		
	ELSIF ( NEW.obs_creationtime >= last_w AND NEW.obs_creationtime < cur_w ) THEN 
	        cur_file:= 'qm.data_value_' || to_char(last_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;				
	ELSE
		RAISE EXCEPTION 'Date out of range.  Something wrong with the data_insert_trigger_func()';
	END IF;
	RETURN NULL;
END;
$_$;


ALTER FUNCTION qm.data_insert_trigger_func() OWNER TO postgres;

--
-- Name: data_quality_insert_trigger_func(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION data_quality_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare

    last_w date 		:= date_trunc('week', now() - '1 week'::interval);
    cur_w date 			:= date_trunc('week', now());      
    plus1_w date 		:= date_trunc('week', now() + '1 week'::interval);
    plus2_w date 		:= date_trunc('week', now() + '2 week'::interval);
    
    cur_file text;

BEGIN
        IF ( NEW.obs_creationtime >= cur_w AND NEW.obs_creationtime < plus1_w ) THEN 
	        cur_file:= 'qm.data_quality_' || to_char(cur_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW; 
	ELSIF ( NEW.obs_creationtime >= plus1_w AND NEW.obs_creationtime < plus2_w ) THEN 
	        cur_file:= 'qm.data_quality_' || to_char(plus1_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;		
	ELSIF ( NEW.obs_creationtime >= last_w AND NEW.obs_creationtime < cur_w ) THEN 
	        cur_file:= 'qm.data_quality_' || to_char(last_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;				
	ELSE
		RAISE EXCEPTION 'Date out of range.  Something wrong with the data_quality_insert_trigger_func()';
	END IF;
	RETURN NULL;
END;
$_$;


ALTER FUNCTION qm.data_quality_insert_trigger_func() OWNER TO postgres;

--
-- Name: external_forecast_insert_trigger_func(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION external_forecast_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare

BEGIN
	-- maybe update geom, if possible
	IF (NEW.lat is not null AND NEW.lon is not null) THEN
		NEW.geom = ST_Transform( ST_SetSRID( ST_MakePoint(NEW.lon, NEW.lat) ,4326) ,4326);
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION qm.external_forecast_insert_trigger_func() OWNER TO postgres;

--
-- Name: get_station_observations(integer, integer, integer); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION get_station_observations(station_id integer, row_offset integer, row_limit integer) RETURNS SETOF station_observations_holder
    LANGUAGE plpgsql
    AS $$
	DECLARE
	BEGIN
		RETURN QUERY
			SELECT qm.data_value.obs_creationtime, qm.data_value.stn_id, qm.data_value.sensor_id, qm.data_value.nvalue, qm.data_value.nvalue_str, qm.data_value.qc_check_total, qm.data_value.qc_check_failed, qm.sensor_identity.lane_no, qm.sensor_identity.sensor_no, qm.sensor_master_identity.sensor_master_id, qm.sensor_master_identity.symbol, qm.sensor_master_identity.codespace
				FROM qm.data_value
				INNER JOIN qm.sensor_identity ON qm.data_value.sensor_id = qm.sensor_identity.sensor_id
				INNER JOIN qm.sensor_master_identity ON qm.sensor_identity.sensor_master_id = qm.sensor_master_identity.sensor_master_id
				INNER JOIN (
					SELECT DISTINCT qm.data_value.obs_creationtime
					FROM qm.data_value
					WHERE 
						qm.data_value.stn_id = get_station_observations.station_id 
						AND qm.data_value.sensor_id IN (SELECT qm.sensor_identity.sensor_id FROM qm.sensor_identity WHERE qm.sensor_identity.stn_id=get_station_observations.station_id) 
						AND qm.data_value.obs_creationtime BETWEEN (now() - '3 days'::interval) AND (now() - '1 second'::interval)
					ORDER BY qm.data_value.obs_creationtime DESC
					OFFSET get_station_observations.row_offset
					LIMIT get_station_observations.row_limit
					) as sub on sub.obs_creationtime = qm.data_value.obs_creationtime
				WHERE 
					qm.data_value.stn_id = get_station_observations.station_id
					AND qm.data_value.sensor_id IN (SELECT qm.sensor_identity.sensor_id FROM qm.sensor_identity WHERE qm.sensor_identity.stn_id=get_station_observations.station_id) 
					AND qm.data_value.obs_creationtime BETWEEN (now() - '3 days'::interval) AND (now() - '1 second'::interval)
				ORDER BY qm.data_value.obs_creationtime DESC, qm.data_value.sensor_id;
	END;$$;


ALTER FUNCTION qm.get_station_observations(station_id integer, row_offset integer, row_limit integer) OWNER TO postgres;

--
-- Name: getmetadata(text); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION getmetadata(target_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    strresult text;
    rep_rec record;
BEGIN
  strresult := target_name;
    RAISE NOTICE 'pipit';
    
  FOR rep_rec in select * from qm.error_codes

  LOOP

  RAISE NOTICE ' number % -- code %', rep_rec.error_number, rep_rec.error_code;
  
  END LOOP;


  RETURN strresult;
END;
$$;


ALTER FUNCTION qm.getmetadata(target_name text) OWNER TO postgres;

--
-- Name: manage_partition(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION manage_partition() RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
    check_dow INT;
    start_date text;
    end_date text;
    drop_date text;
    command_str text;
BEGIN
-- function to create a new weekly (value, quality) partitions and drop old ones
-- MUST only be run on a Monday for correct operation  - BJT November 2014
-------------------------------------------------------

-- check day of week
select INTO check_dow extract(dow from localtimestamp);

if check_dow != 1 then
  -- day of week is not a Monday so:
  -- write a 'notice'; and exit function
  RAISE NOTICE 'Not Monday Exiting... (%)', check_dow;
  RETURN FALSE;
END IF;

-- Day of week is Monday so:
-- Create a partition starting one week ahead of today
start_date = TO_CHAR(localtimestamp + '7 days'::interval, 'YYYY-MM-DD');

-- Partition end date is in the same week so only create a single partition
end_date = TO_CHAR(localtimestamp + '8 days'::interval, 'YYYY-MM-DD');


-- Build command to execute (calls on pre-defined function)
command_str = concat('select qm.data_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
execute command_str;

RAISE NOTICE 'add data command %', command_str;

--*********************************************************************************************

command_str = concat('select qm.quality_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
execute command_str;

RAISE NOTICE 'add quality command %', command_str;

--*********************************************************************************************

-- Now drop old partitions ----
-- MUST be run on a Monday and be multiples of 7 days to match the partition date.

drop_date = TO_CHAR(localtimestamp - '14 days'::interval, 'YYYY_MM_DD');

execute 'truncate table qm.data_quality_' || drop_date || '';
execute 'drop table qm.data_quality_' || drop_date || '';

execute 'truncate table qm.data_value_' || drop_date || '';
execute 'drop table qm.data_value_' || drop_date || ''; 

analyse;

RAISE NOTICE 'Dropped old value and quality partitions [%]', drop_date;

RETURN TRUE;

END$$;


ALTER FUNCTION qm.manage_partition() OWNER TO postgres;

--
-- Name: quality_creation_week(date, date); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION quality_creation_week(date, date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	create_query text;
	index_query text;
	index_query2 text;
	index_query3 text;
BEGIN
	FOR create_query, index_query, index_query2, index_query3 IN SELECT
			'create table qm.data_quality_' || TO_CHAR( d, 'YYYY_MM_DD' )
			
			||  ' ( CONSTRAINT data_quality' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_pk'
			|| ' PRIMARY KEY (data_quality_id),'
						
			||  '  CONSTRAINT data_quality_creation_sensor_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_fk'
			|| ' FOREIGN KEY (obs_creationtime,sensor_id) '
			|| ' REFERENCES qm.data_value_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '(obs_creationtime,sensor_id) MATCH SIMPLE ,'

-- removing these foreign keys. They block removal of range/step/cross checks, which is required by UI	
--	
--				||  '  CONSTRAINT dq_range_check_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_fk'
--				|| ' FOREIGN KEY (range_check_id) '
--				|| ' REFERENCES qm.sensor_range_check (range_check_id) MATCH SIMPLE ,'
--	
--				||  '  CONSTRAINT dq_step_check_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_fk'
--				|| ' FOREIGN KEY (step_check_id) '
--				|| ' REFERENCES qm.sensor_step_check (step_check_id) MATCH SIMPLE ,'
--	
--				||  '  CONSTRAINT dq_cross_check_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_fk'
--				|| ' FOREIGN KEY (cross_check_id) '
--				|| ' REFERENCES qm.sensor_cross_check (cross_check_id) MATCH SIMPLE ,'
				
			|| '  check( obs_creationtime >= date '''
			
			|| TO_CHAR( d, 'YYYY-MM-DD' )
			|| ''' and obs_creationtime < date '''
			|| TO_CHAR( d + INTERVAL '1 week', 'YYYY-MM-DD' )
			|| ''' ) ) inherits ( qm.data_quality );' 
			|| ' ALTER TABLE qm.data_quality_'
			|| TO_CHAR( d, 'YYYY_MM_DD' ) 
			|| ' OWNER TO postgres',
			
			'create index data_quality_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_sensor_idx on qm.data_quality_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( sensor_id);',
			
			'create index data_quality_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_obs_creationtime_idx on qm.data_quality_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (obs_creationtime) ;',

			'create index data_quality_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_insertiontime_idx on qm.data_quality_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (db_insertiontime) ;'
			
   		FROM generate_series( $1, $2, '1 week' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
		EXECUTE index_query3;
	END LOOP;
END;
$_$;


ALTER FUNCTION qm.quality_creation_week(date, date) OWNER TO postgres;

--
-- Name: remove_dq_fk_constraints(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION remove_dq_fk_constraints() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    constraintRecord RECORD;
    constraintTable varchar(256);
    constraintName varchar(256);
    alterTableStatement varchar(2048);
BEGIN
    RAISE NOTICE 'Removing FK references from any/all known data_quality tables and partitions...';

    FOR constraintRecord IN 
		select * 
			from information_schema.table_constraints
			where constraint_schema = 'qm'
			and constraint_name like '%dq%check%'
			order by constraint_name
			
				LOOP
					-- drop this
					constraintName =  constraintRecord.constraint_name;
					constraintTable = constraintRecord.table_schema || '.' || constraintRecord.table_name;
					--RAISE NOTICE 'will drop constraint % from %', constraintName, constraintTable;

					-- make the statement
					alterTableStatement = 'ALTER TABLE ' || constraintTable || ' DROP CONSTRAINT IF EXISTS ' || constraintName;
					RAISE NOTICE 'will execute %', alterTableStatement;

					-- run it!
					execute alterTableStatement;

    END LOOP;

    RAISE NOTICE 'Done dropping FK references from data_quality tables.';
    RETURN 1;
END;
$$;


ALTER FUNCTION qm.remove_dq_fk_constraints() OWNER TO postgres;

--
-- Name: rollup_camera_performance(character varying); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION rollup_camera_performance(rollup_date character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE
	BEGIN
		-- nothing to do on bad data
		IF (rollup_date IS NULL  or rollup_date='') THEN
			RAISE WARNING 'Empty rollup date';
		ELSE
			-- delete this date
			DELETE FROM qm.rollup_camera_performance 
				WHERE image_date = rollup_date::date;
				
			-- count and update this date
			INSERT into qm.rollup_camera_performance 
				select image_timestamp::date, station_id, count(station_id)
					from qm.cam_image_list
					inner join qm.station_identity on cam_image_list.station_id = station_identity.stn_id
					inner join qm.station_alias_identity on station_identity.owning_region_id = station_alias_identity.v_region_id
					where image_timestamp::date = rollup_date::date
					and station_identity.monitored = true
					and station_alias_identity.monitored = true
					group by station_id, image_timestamp::date;
					
		END IF;
	END;$$;


ALTER FUNCTION qm.rollup_camera_performance(rollup_date character varying) OWNER TO postgres;

--
-- Name: rollup_network_performance(character varying); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION rollup_network_performance(rollup_date character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE
	BEGIN
		-- nothing to do on bad data
		IF (rollup_date IS NULL  or rollup_date='') THEN
			RAISE WARNING 'Empty rollup date';
		ELSE
			-- delete this date
			DELETE FROM qm.rollup_parameter_performance 
				WHERE obs_creationtime::date = rollup_date::date;
			DELETE FROM qm.rollup_network_performance 
				WHERE message_date = rollup_date::date;
				
			-- count and update this date
			INSERT into qm.rollup_parameter_performance 
				select obs_creationtime, data_value.stn_id, data_value.sensor_id, max(sensor_master_identity.sensor_master_id)
					from qm.data_value
					inner join qm.station_identity on data_value.stn_id = station_identity.stn_id
					inner join qm.station_alias_identity on station_identity.owning_region_id = station_alias_identity.v_region_id
					INNER JOIN qm.sensor_identity ON data_value.sensor_id = sensor_identity.sensor_id
					INNER JOIN qm.sensor_master_identity ON sensor_identity.sensor_master_id = sensor_master_identity.sensor_master_id
					where
					-- this date only
					obs_creationtime::date = rollup_date::date
					-- monitored regions only
					and station_alias_identity.monitored = true
					-- only the good readings
					and (qc_check_total > 1 or (qc_check_total = 1 and qc_check_failed = 0))
					group by obs_creationtime, data_value.stn_id, data_value.sensor_id;
				
			-- now count station performance
			INSERT into qm.rollup_network_performance 
				select obs_creationtime::date, stn_id, count(distinct obs_creationtime), count(obs_creationtime)
				from qm.rollup_parameter_performance
				where obs_creationtime::date = rollup_date::date
				group by obs_creationtime::date, stn_id;
				
			-- now dump temporary rows
--			DELETE FROM qm.rollup_parameter_performance 
--				WHERE obs_creationtime::date = rollup_date::date;
				
		END IF;
	END;$$;


ALTER FUNCTION qm.rollup_network_performance(rollup_date character varying) OWNER TO postgres;

--
-- Name: test_manage_partition(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION test_manage_partition() RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
    check_dow INT;
    start_date text;
    end_date text;
    drop_date text;
    command_str text;
BEGIN
-- function to create a new weekly (value, quality) partitions and drop old ones
-- MUST only be run on a Monday for correct operation  - BJT November 2014
-------------------------------------------------------

-- check day of week
select INTO check_dow extract(dow from localtimestamp);

if check_dow != 1 then
  -- day of week is not a Monday so:
  -- write a 'notice'; and exit function
  RAISE NOTICE 'Not Monday Exiting... (%)', check_dow;
  RETURN FALSE;
END IF;

-- Day of week is Monday so:
-- Create a partition starting one week ahead of today
start_date = TO_CHAR(localtimestamp + '7 days'::interval, 'YYYY-MM-DD');

-- Partition end date is in the same week so only create a single partition
end_date = TO_CHAR(localtimestamp + '8 days'::interval, 'YYYY-MM-DD');


-- Build command to execute (calls on pre-defined function)
command_str = concat('select qm.data_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
-- execute command_str;

RAISE NOTICE 'add data command %', command_str;

--*********************************************************************************************

command_str = concat('select qm.quality_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
--execute command_str;

RAISE NOTICE 'add quality command %', command_str;

--*********************************************************************************************

-- Now drop old partitions ----
-- MUST be run on a Monday and be multiples of 7 days to match the partition date.

drop_date = TO_CHAR(localtimestamp - '14 days'::interval, 'YYYY_MM_DD');

execute 'truncate table qm.data_quality_' || drop_date || '';
execute 'drop table qm.data_quality_' || drop_date || '';

execute 'truncate table qm.data_value_' || drop_date || '';
execute 'drop table qm.data_value_' || drop_date || ''; 

analyse;

RAISE NOTICE 'Dropped old value and quality partitions [%]', drop_date;

RETURN TRUE;

END$$;


ALTER FUNCTION qm.test_manage_partition() OWNER TO postgres;

SET search_path = qmfault, pg_catalog;

--
-- Name: decidewhattodowithfaultinfo(smallint, integer, bigint, timestamp without time zone, integer, integer, character varying, smallint); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION decidewhattodowithfaultinfo(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
	DECLARE
	
		retVal smallint DEFAULT 0;
		existingFault qmfault.fault;

		FAULT_ACTION_NONE smallint DEFAULT 0;
		FAULT_ACTION_INSERT smallint DEFAULT 1;
		FAULT_ACTION_UPDATE smallint DEFAULT 2;

		faultAction smallint DEFAULT FAULT_ACTION_NONE;

	BEGIN
		-- see if there's one out there
		SELECT * FROM qmfault.findFault(fault_type_id, station_id, sensor_id, camera_nbr) INTO existingFault;
		IF (existingFault is null) THEN
			-- add this one
			/* RAISE WARNING 'No matching Existing fault % % %', fault_type_id, station_id, sensor_id; */
			retVal := qmfault.insertFault(fault_source, fault_type_id, data_quality_id, obs_creationtime, station_id, sensor_id, camera_nbr, monitor_hours);
		ELSE
			-- gonna depend...
			CASE existingFault.status
				-- Suspected or confirmed
				WHEN 0,2 THEN
					-- happened again, now
					faultAction := FAULT_ACTION_UPDATE;
				-- Monitoring
				WHEN 1 THEN
					if (existingFault.start_time is not null AND existingFault.monitor_hours is not null AND existingFault.monitor_hours>0 ) THEN
						-- enough hours have passed?
						IF ( obs_creationtime > (existingFault.start_time + (existingFault.monitor_hours * INTERVAL '1 HOUR') )) THEN
							-- new fault
							faultAction := FAULT_ACTION_INSERT;
						ELSE
							-- happened again, now
							faultAction := FAULT_ACTION_UPDATE;
						END IF;
					ELSE
						RAISE WARNING 'Fault has bad start time or monitor hours %', existingFault.fault_id;
					END IF;
				-- Fixed
				WHEN 3 THEN
					-- if the old fault was for data
					if (existingFault.data_quality_id is not null) THEN
						-- if the old fault was not the same data_quality id
						if (existingFault.data_quality_id != decidewhattodowithfaultinfo.data_quality_id) THEN
							-- that's a new one...
							faultAction := FAULT_ACTION_INSERT;
						END IF;
					ELSE
						-- the old fault was camera or station
						-- this must be a new one!
						faultAction := FAULT_ACTION_INSERT;
					END IF;
				-- Ignore
				WHEN 4 THEN
					-- ignore date before now?
					IF (obs_creationtime > existingFault.ignore_through_time) THEN
						-- new fault
						faultAction := FAULT_ACTION_INSERT;
					ELSE
						-- happened again, now
						faultAction := FAULT_ACTION_UPDATE;
					END IF;
				ELSE
					RAISE WARNING 'Existing fault has unknown status %', existingFault.status;
			END CASE;
				
			CASE faultAction
				-- no action
				WHEN FAULT_ACTION_NONE THEN
					-- do nothing
				-- insert
				WHEN FAULT_ACTION_INSERT THEN
					retVal := qmfault.insertFault(fault_source, fault_type_id, data_quality_id, obs_creationtime, station_id, sensor_id, camera_nbr, monitor_hours);
				-- update
				WHEN FAULT_ACTION_UPDATE THEN
					retVal := qmfault.updateFault(existingFault.fault_id, obs_creationtime, data_quality_id);
				ELSE
					RAISE WARNING 'Unhandled fault action %', faultAction;
			END CASE;

		END IF;
		return retVal;
	END;
	$$;


ALTER FUNCTION qmfault.decidewhattodowithfaultinfo(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) OWNER TO postgres;

--
-- Name: execute_fault_tests_data(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION execute_fault_tests_data() RETURNS integer
    LANGUAGE plpgsql
    AS $$--
-- POSSIBLY temporary method
-- being called currently by Java/Quartz - not sure that's the right way to go
--
-- this method reads "a number of" quality values
-- and adds faults, accordingly
DECLARE
	retVal integer DEFAULT 0;
	dqSensorJoin RECORD;
	FAULT_SOURCE_DATA smallint DEFAULT 2;
	faultTypeId integer;
	faultTypeRow qmfault.fault_type%rowtype;
	regionRow qm.station_alias_identity%rowType;
	startTime timestamp without time zone;
	endTime timestamp without time zone;
	maxFaultMins integer = 0;
	tmpCount integer;
BEGIN

	endTime = now();

	-- find max fault time - currently it seems to be 1440 minutes
	SELECT into maxFaultMins max(sensor_fault_detection_minutes) FROM qmfault.get_regions_participating_in_fault_collection(); 
	        
        --raise notice 'Max minutes %', maxFaultMins;
        --maxFaultMins = maxFaultMins * 5;
        	
	startTime = endTime - (maxFaultMins * INTERVAL '1 minute');
	--raise notice ' minutes %, time %', maxFaultMins, startTime;
	
	CREATE TEMPORARY TABLE dqm_temp AS SELECT * FROM qmfault.get_recent_data_quality_rows(startTime, endTime); 
       -- select into tmpCount count(*) from dqm_temp;
	--raise notice 'temp rows %', tmpCount;

	-- filter temp table using participating regions
	FOR regionRow in SELECT * FROM qmfault.get_regions_participating_in_fault_collection()
	LOOP
	    startTime = endTime - (regionRow.sensor_fault_detection_minutes * INTERVAL '1 minute');
	    --RAISE WARNING 'Getting recent data quality row for region %, from % thru % -- %', regionRow.v_region_id, startTime, endTime, regionRow.sensor_fault_detection_minutes;
		FOR dqSensorJoin IN SELECT * FROM dqm_temp 
		                             where owning_region_id = regionRow.v_region_id
		                             and obs_creationtime > startTime 
		LOOP
			BEGIN
				retVal := retVal + qmfault.insert_or_update_fault(FAULT_SOURCE_DATA, dqSensorJoin.fault_type_id, dqSensorJoin.data_quality_id, dqSensorJoin.obs_creationtime, dqSensorJoin.stn_id, dqSensorJoin.sensor_id, null, 36::smallint);
			EXCEPTION WHEN OTHERS THEN
				raise WARNING '% %', SQLERRM, SQLSTATE;
			END;
		END LOOP;
	END LOOP;
	
        DROP TABLE IF EXISTS dqm_temp;
	RETURN retVal;

END;$$;


ALTER FUNCTION qmfault.execute_fault_tests_data() OWNER TO postgres;

--
-- Name: execute_fault_tests_system(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION execute_fault_tests_system() RETURNS integer
    LANGUAGE plpgsql
    AS $$-- just run all the (known) system fault tests
DECLARE
	testStationNotRespondingResults integer DEFAULT -1;
	testSensorMissingResults integer DEFAULT -1;
	testSensorStuckFaults integer DEFAULT -1;
BEGIN

	-- station not responding
	SELECT into testStationNotRespondingResults
		qmfault.fault_test_system_station_not_responding();
	--RAISE WARNING 'Station Not Responding test result %', testStationNotRespondingResults;

	-- sensor missing
	SELECT into testSensorMissingResults
		qmfault.fault_test_system_sensor_missing();
	--RAISE WARNING 'Sensor Missing test result %', testStationNotRespondingResults;
	
	-- sensor stuck
	SELECT into testSensorStuckFaults
		qmfault.fault_test_system_sensor_stuck();

	-- TODO: OR the results together
	-- musta worked
	RETURN testStationNotRespondingResults;

END;$$;


ALTER FUNCTION qmfault.execute_fault_tests_system() OWNER TO postgres;

--
-- Name: fault_test_system_sensor_missing(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION fault_test_system_sensor_missing() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	SENSOR_MISSING_ID integer DEFAULT -998; 
	FAULT_SOURCE_SYSTEM smallint DEFAULT 1;
	FAULT_MONITOR_HOURS smallint DEFAULT 36;

	sensorMissingFaultId integer DEFAULT null;
	regionRow qm.station_alias_identity%rowType;
	sensorMissingRow qmfault.missing_sensor_holder;
	faultResults integer;
	faultTotalResults integer DEFAULT 0;

BEGIN

	-- get the 'station not responding' fault id
	SELECT qmfault.fault_type.fault_type_id into sensorMissingFaultId
		FROM qmfault.fault_type 
		WHERE error_code = SENSOR_MISSING_ID;

	IF (sensorMissingFaultId is null) THEN
		RAISE WARNING 'Unable to find Sensor Missing fault type by code %', SENSOR_MISSING_ID;
	ELSE

		-- list of regions participating in fault detection
		FOR regionRow in SELECT * FROM qmfault.get_regions_participating_in_fault_collection()
		LOOP

			--RAISE WARNING 'Region Participating: %', regionRow.v_region_id;
			
			-- list of stations that haven't responded in one hour
			FOR sensorMissingRow IN SELECT * FROM qmfault.get_sensors_missing_list(regionRow.v_region_id, regionRow.fault_detection_minutes) 
			LOOP
			
				--RAISE WARNING 'Sensor Missing: %', sensorMissingRow;
				
				-- use 'now()' as observation time - we don't know when it should have been observed...
				SELECT into faultResults
					qmfault.insert_or_update_fault(FAULT_SOURCE_SYSTEM, sensorMissingFaultId, null::integer, sensorMissingRow.latest_instance, sensorMissingRow.stn_id, sensorMissingRow.sensor_id, null::varchar, FAULT_MONITOR_HOURS);
					
				faultTotalResults := faultTotalResults + faultResults;
				IF (faultResults != 1 AND faultResults !=2) THEN
				
					RAISE WARNING 'Sensor missing:% Source:% fault_id:% stn_id:% sensor_id:%, monitor_hours:%, result:%', 
						sensorMissingRow.stn_id, 
						FAULT_SOURCE_SYSTEM, 
						sensorMissingFaultId, 
						sensorMissingRow.stn_id, null, 
						FAULT_MONITOR_HOURS,
						faultResults;
				END IF;
			END LOOP;
		END LOOP;
		
	END IF;

	-- whatever the count was, return that
	RETURN faultTotalResults;

END;$$;


ALTER FUNCTION qmfault.fault_test_system_sensor_missing() OWNER TO postgres;

--
-- Name: fault_test_system_sensor_stuck(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION fault_test_system_sensor_stuck() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	SENSOR_STUCK_ID integer DEFAULT -994; 
	FAULT_MONITOR_HOURS smallint DEFAULT 36;
	FAULT_SOURCE_SYSTEM smallint DEFAULT 1;

	sensorStuckFaultId integer DEFAULT null;
	regionRow qm.station_alias_identity%rowType;
	sensorStuckRow qmfault.stuck_sensor_holder;
	faultResults integer;
	faultTotalResults integer DEFAULT 0;

BEGIN

	-- get the 'station not responding' fault id
	SELECT qmfault.fault_type.fault_type_id into sensorStuckFaultId
		FROM qmfault.fault_type 
		WHERE error_code = SENSOR_STUCK_ID;

	IF (sensorStuckFaultId is null) THEN
		RAISE WARNING 'Unable to find Sensor Stuck fault type by code %', SENSOR_STUCK_ID;
	ELSE

		-- list of regions participating in fault detection
		FOR regionRow in SELECT * FROM qmfault.get_regions_participating_in_fault_collection()
		LOOP

			--RAISE WARNING 'Region Participating: %', regionRow.v_region_id;
			
			-- stuck sensors
			FOR sensorStuckRow IN SELECT * FROM qmfault.get_stuck_sensors_list(regionRow.v_region_id) 
			LOOP
			
				--RAISE WARNING 'Sensor Missing: %', sensorMissingRow;
				
				-- use 'now()' as observation time - we don't know when it should have been observed...
				SELECT into faultResults
					qmfault.insert_or_update_fault(FAULT_SOURCE_SYSTEM, sensorStuckFaultId, null::integer, sensorStuckRow.obs_creationtime, sensorStuckRow.stn_id, sensorStuckRow.sensor_id, null::varchar, FAULT_MONITOR_HOURS);
					
				faultTotalResults := faultTotalResults + faultResults;
				IF (faultResults != 1 AND faultResults !=2) THEN
				
					RAISE WARNING 'Sensor missing:% Source:% fault_id:% stn_id:% sensor_id:%, monitor_hours:%, result:%', 
						sensorMissingRow.stn_id, 
						FAULT_SOURCE_SYSTEM, 
						sensorStuckFaultId, 
						sensorMissingRow.stn_id, null, 
						FAULT_MONITOR_HOURS,
						faultResults;
				END IF;
			END LOOP;
		END LOOP;
		
	END IF;

	-- whatever the count was, return that
	RETURN faultTotalResults;

END;$$;


ALTER FUNCTION qmfault.fault_test_system_sensor_stuck() OWNER TO postgres;

--
-- Name: fault_test_system_station_not_responding(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION fault_test_system_station_not_responding() RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	STATION_NOT_RESPONDING_ID integer DEFAULT -999; 
	FAULT_SOURCE_SYSTEM smallint DEFAULT 1;
	FAULT_MONITOR_HOURS smallint DEFAULT 36;

	stationNotRespondingFaultId integer DEFAULT null;
	regionRow qm.station_alias_identity%rowType;
	stationRow qm.station_identity%rowType;
	faultResults integer;
	faultTotalResults integer DEFAULT 0;

BEGIN

	-- get the 'station not responding' fault id
	SELECT qmfault.fault_type.fault_type_id into stationNotRespondingFaultId
		FROM qmfault.fault_type 
		WHERE error_code = STATION_NOT_RESPONDING_ID;

	IF (stationNotRespondingFaultId is null) THEN
		RAISE WARNING 'Unable to find Station Not Responding fault type by code %', STATION_NOT_RESPONDING_ID;
	ELSE

		-- list of regions participating in fault detection
		FOR regionRow in SELECT * FROM qmfault.get_regions_participating_in_fault_collection()
		LOOP
			-- list of stations that haven't responded in one hour
			FOR stationRow IN SELECT * FROM qmfault.get_stations_offline_list(regionRow.v_region_id, regionRow.fault_detection_minutes) 
			LOOP
				-- use 'now()' as observation time - we don't know when it should have been observed...
				SELECT into faultResults
					qmfault.insert_or_update_fault(FAULT_SOURCE_SYSTEM, stationNotRespondingFaultId, null, stationRow.last_updated, stationRow.stn_id, null, null, FAULT_MONITOR_HOURS);
--					qmfault.insert_or_update_fault(FAULT_SOURCE_SYSTEM, stationNotRespondingFaultId, null, LOCALTIMESTAMP , stationRow.stn_id, null, null, FAULT_MONITOR_HOURS);
					
				faultTotalResults := faultTotalResults + faultResults;
				IF (faultResults != 1 AND faultResults !=2) THEN
				
					RAISE WARNING 'Station never responded:% Source:% fault_id:% stn_id:% sensor_id:%, monitor_hours:%, result:%', 
						stationRow.xml_target_name, 
						FAULT_SOURCE_SYSTEM, 
						stationNotRespondingFaultId, 
						stationRow.stn_id, null, 
						FAULT_MONITOR_HOURS,
						faultResults;
				END IF;
			END LOOP;
		END LOOP;
		
	END IF;

	-- whatever the count was, return that
	RETURN faultTotalResults;

END;$$;


ALTER FUNCTION qmfault.fault_test_system_station_not_responding() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: fault; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault (
    fault_id integer NOT NULL,
    fault_source smallint,
    fault_type_id integer,
    status smallint,
    station_id integer,
    sensor_id integer,
    sensor_master_id integer,
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    monitor_hours smallint,
    fault_action_id integer,
    fault_resp_id integer,
    ebs_sr_id character varying(10),
    ebs_sr_number character varying(10),
    ebs_sr_create_time timestamp without time zone,
    is_internal boolean,
    is_callout boolean,
    title_internal character varying(256),
    title_external character varying(256),
    create_time timestamp without time zone,
    last_update_time timestamp without time zone,
    ignore_through_time timestamp without time zone,
    data_quality_id bigint,
    camera_number character varying(4)
);


ALTER TABLE qmfault.fault OWNER TO postgres;

--
-- Name: findfault(integer, integer, integer, character varying); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION findfault(fault_type_id integer, station_id integer, sensor_id integer, camera_nbr character varying) RETURNS fault
    LANGUAGE plpgsql
    AS $$
	DECLARE
		retVal qmfault.fault;
	BEGIN
		CASE 
			WHEN findFault.camera_nbr >'' THEN
				-- multiple camera faults may have the same end/start time or combo
				-- so we need to look further to the most recently-created fault, to pick the correct one
				SELECT * from qmfault.fault into retVal
					where fault.fault_type_id = findFault.fault_type_id
					and fault.station_id = findFault.station_id
					and fault.camera_number = findFault.camera_nbr
					order by COALESCE(end_time, start_time) DESC, create_time DESC 
					limit 1;
			WHEN findFault.sensor_id is null THEN
				-- multiple station offline faults may have the same end/start time or combo
				-- so we need to look further to the most recently-created fault, to pick the correct one
				SELECT * from qmfault.fault into retVal
					where fault.fault_type_id = findFault.fault_type_id
					and fault.station_id = findFault.station_id
					and fault.sensor_id is null
					order by COALESCE(end_time, start_time) DESC, create_time DESC
					limit 1;
			ELSE
				SELECT * from qmfault.fault INTO retVal
					where fault.fault_type_id = findFault.fault_type_id
					and fault.station_id = findFault.station_id
					and fault.sensor_id = findFault.sensor_id
					order by COALESCE(end_time, start_time) DESC
					limit 1;
		END CASE;
		RETURN retVal;
	END;
	$$;


ALTER FUNCTION qmfault.findfault(fault_type_id integer, station_id integer, sensor_id integer, camera_nbr character varying) OWNER TO postgres;

--
-- Name: get_recent_data_quality_rows(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION get_recent_data_quality_rows(starttime timestamp without time zone, endtime timestamp without time zone) RETURNS SETOF data_quality_sensor_holder
    LANGUAGE plpgsql
    AS $$ 
DECLARE

myQuery text;

BEGIN 

	RETURN QUERY 
 		SELECT max(data_quality.data_quality_id), data_quality.sensor_id, data_quality.status,  
	                   sensor_identity.stn_id,  sensor_identity.sensor_master_id, max(data_quality.obs_creationtime) as "obs_timestamp",
	                   station_identity.owning_region_id,
	                   fault_type.fault_type_id
			FROM qm.data_quality 
				LEFT JOIN qm.sensor_identity ON data_quality.sensor_id = sensor_identity.sensor_id
				LEFT JOIN qm.sensor_master_identity ON sensor_identity.sensor_master_id = sensor_master_identity.sensor_master_id
				LEFT JOIN qm.station_identity ON sensor_identity.stn_id = station_identity.stn_id
				LEFT JOIN qmfault.fault_type ON fault_type.error_code = data_quality.status
				LEFT JOIN 
					qm.station_alias_monitored_sensor as rms
					ON rms.v_region_id = station_identity.owning_region_id
					AND rms.sensor_master_id = sensor_identity.sensor_master_id
				LEFT JOIN 
					qm.station_monitored_sensor as sms
					ON sms.stn_id = station_identity.stn_id
					AND sms.sensor_master_id = sensor_identity.sensor_master_id 
				LEFT JOIN LATERAL
					(SELECT v_region_id from qm.station_alias_monitored_sensor group by v_region_id) as rms_any
					on rms_any.v_region_id = station_identity.owning_region_id
				LEFT JOIN LATERAL
					(SELECT stn_id from qm.station_monitored_sensor group by stn_id) as sms_any
					on sms_any.stn_id = station_identity.stn_id
				WHERE data_quality.status < -1
				AND station_identity.owning_region_id is not null
				AND station_identity.monitored = true
				AND data_quality.obs_creationtime BETWEEN startTime and endTime
				AND true = 
					CASE WHEN sms_any.stn_id is not null
						then sms.sensor_master_id is not null
					     WHEN rms_any.v_region_id is not null
					        then rms.sensor_master_id is not null
					     ELSE
					        sensor_master_identity.monitored
					END
				AND sensor_master_identity.fault_count_threshold>0
				GROUP BY sensor_identity.stn_id,  data_quality.sensor_id, 
				         sensor_identity.sensor_master_id, data_quality.status,
				         station_identity.owning_region_id, fault_type.fault_type_id
				HAVING count(data_quality.sensor_id) >= min(sensor_master_identity.fault_count_threshold)
				ORDER BY max(data_quality.obs_creationtime) DESC;
				--LIMIT 1000;


END;$$;


ALTER FUNCTION qmfault.get_recent_data_quality_rows(starttime timestamp without time zone, endtime timestamp without time zone) OWNER TO postgres;

SET search_path = qm, pg_catalog;

--
-- Name: station_alias_identity; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_alias_identity (
    v_region_id integer NOT NULL,
    v_region_name character varying(200) NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    display_name character varying(200),
    ebs_party_id integer,
    ebs_acct_nbr integer,
    fault_detection_minutes smallint,
    monitored boolean DEFAULT true,
    v_region_code character varying(2),
    camera_test_period smallint,
    camera_min_image_count smallint,
    sensor_fault_detection_minutes smallint DEFAULT 0,
    image_interval smallint,
    polling_interval_minutes smallint DEFAULT 15 NOT NULL,
    default_codespace integer DEFAULT (-1) NOT NULL,
    vmdb_id integer,
    pows boolean DEFAULT false
);


ALTER TABLE qm.station_alias_identity OWNER TO postgres;

SET search_path = qmfault, pg_catalog;

--
-- Name: get_regions_participating_in_fault_collection(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION get_regions_participating_in_fault_collection() RETURNS SETOF qm.station_alias_identity
    LANGUAGE plpgsql
    AS $$BEGIN
	RETURN QUERY (
		SELECT *  
			FROM qm.station_alias_identity
			WHERE fault_detection_minutes > 0
			/* AND monitored = true  if we do this, we won't get faults for non-monitored stations - we already control display on the faults page this way */
	);
END;$$;


ALTER FUNCTION qmfault.get_regions_participating_in_fault_collection() OWNER TO postgres;

--
-- Name: get_sensors_missing_list(integer, smallint); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION get_sensors_missing_list(owning_region integer, lookback_minutes smallint DEFAULT 60) RETURNS SETOF missing_sensor_holder
    LANGUAGE plpgsql
    AS $$BEGIN 

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
		-- the last reading happened before the last reading of any station
		max_time_table.last_reading_time > last_reading.last_datetime
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

END;$$;


ALTER FUNCTION qmfault.get_sensors_missing_list(owning_region integer, lookback_minutes smallint) OWNER TO postgres;

SET search_path = qm, pg_catalog;

--
-- Name: station_identity; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_identity (
    stn_id integer NOT NULL,
    xml_target_name character varying(100) NOT NULL,
    station_name character varying(200),
    lat double precision,
    lon double precision,
    alt real,
    region_id character varying(2),
    country_id character varying(2),
    org_id character varying(100),
    creation_time timestamp without time zone DEFAULT now() NOT NULL,
    last_updated timestamp without time zone DEFAULT now() NOT NULL,
    owning_region_id integer,
    geom public.geometry(Point,4326),
    geom_updated boolean DEFAULT false NOT NULL,
    camera_count_metadata smallint DEFAULT (-1),
    param_count smallint,
    image_interval smallint,
    polling_interval_minutes smallint,
    monitored boolean DEFAULT true NOT NULL,
    default_codespace integer DEFAULT (-1) NOT NULL,
    vmdb_id integer,
    mso_id character varying(5),
    forecast_expected_minutes integer,
    forecast_missing_minutes integer
);


ALTER TABLE qm.station_identity OWNER TO postgres;

SET search_path = qmfault, pg_catalog;

--
-- Name: get_stations_offline_list(integer, integer); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION get_stations_offline_list(owning_region integer, reported_within_minutes integer DEFAULT 60) RETURNS SETOF qm.station_identity
    LANGUAGE plpgsql
    AS $$BEGIN 

	-- these are considered offline
	RETURN QUERY
		SELECT * FROM qm.station_identity 
			WHERE 
				last_updated <= now() - ( reported_within_minutes * INTERVAL '1 minute')
				AND owning_region_id = owning_region
				AND monitored = true
			ORDER BY last_updated DESC;
			
END;$$;


ALTER FUNCTION qmfault.get_stations_offline_list(owning_region integer, reported_within_minutes integer) OWNER TO postgres;

--
-- Name: get_stuck_sensors_list(integer); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION get_stuck_sensors_list(owning_region integer) RETURNS SETOF stuck_sensor_holder
    LANGUAGE plpgsql
    AS $$BEGIN 

	RETURN QUERY
	

		-- data value
		select data_value.sensor_id,  min(station_identity.stn_id) as stn_id, min(sensor_master_identity.sensor_master_id) as sensor_master_id, max(data_value.obs_creationtime) as obs_creationtime
		from qm.data_value
		
		-- need to get to the sensor master row this way
		inner join qm.sensor_identity on sensor_identity.sensor_id = data_value.sensor_id
		
		-- station for this sensor, this region, monitored stations only
		inner join qm.station_identity on (sensor_identity.stn_id = station_identity.stn_id and station_identity.owning_region_id = get_stuck_sensors_list.owning_region and station_identity.monitored = true)

		-- monitored regions only - too slow otherwise
		inner join qm.station_alias_identity on (station_identity.owning_region_id = station_alias_identity.v_region_id and station_alias_identity.monitored = true)
		
		-- get the sensor master row
		inner join qm.sensor_master_identity on sensor_master_identity.sensor_master_id = sensor_identity.sensor_master_id
		
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

		-- listed stuck minutes
		where sensor_master_identity.sensor_stuck_minutes > 0
		-- within minutes range
		--and data_value.obs_creationtime >= (now() - ('360 minutes'::interval))
		and data_value.obs_creationtime >= (now() - (sensor_master_identity.sensor_stuck_minutes * '1 minutes'::interval))
		-- not an error
		and data_value.nvalue!=sensor_master_identity.error_value
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
		
		-- all for this sensor
		group by data_value.sensor_id
		
		-- at least ten of the exact same reading
		having count(data_value.nvalue)>4 and max(data_value.nvalue) = min(data_value.nvalue);
		
END;$$;


ALTER FUNCTION qmfault.get_stuck_sensors_list(owning_region integer) OWNER TO postgres;

--
-- Name: insert_or_update_fault(smallint, integer, bigint, timestamp without time zone, integer, integer, character varying, smallint); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION insert_or_update_fault(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
	retVal smallint DEFAULT 0; 
	 
	FAULT_SOURE_MANUAL smallint DEFAULT 0; 
	FAULT_SOURE_SYSTEM smallint DEFAULT 1;
	FAULT_SOURE_DATA smallint DEFAULT 2; 

BEGIN 
	--
	-- always do the right thing
	--
	CASE fault_source
		WHEN FAULT_SOURE_MANUAL THEN
			retVal := qmfault.insertFault(fault_source, fault_type_id, data_quality_id, obs_creationtime, station_id, sensor_id, camera_nbr, monitor_hours);
		WHEN FAULT_SOURE_SYSTEM, FAULT_SOURE_DATA THEN
			retVal := qmfault.decideWhatToDoWithFaultInfo(fault_source, fault_type_id, data_quality_id, obs_creationtime, station_id, sensor_id, camera_nbr, monitor_hours);
		ELSE
			RAISE EXCEPTION 'Unknown Fault Source %', fault_source;
	END CASE;

	RETURN retVal;

	
END;
$$;


ALTER FUNCTION qmfault.insert_or_update_fault(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) OWNER TO postgres;

--
-- Name: insertfault(smallint, integer, bigint, timestamp without time zone, integer, integer, character varying, smallint); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION insertfault(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
	DECLARE 
	
		FAULT_SOURE_DATA smallint DEFAULT 2;
		
		CODESPACE_NES_14 smallint DEFAULT 0;
		CODESPACE_NES_16 smallint DEFAULT 1;
		
		ERROR_CODE_NOT_A_NUMBER integer DEFAULT -204;

		faultTypeNotANumber integer DEFAULT null;
		smId integer DEFAULT NULL;
		smCodespace smallint default null;
		
	BEGIN
		
		-- get the 'station not responding' fault id
		SELECT qmfault.fault_type.fault_type_id into faultTypeNotANumber
			FROM qmfault.fault_type 
			WHERE error_code = ERROR_CODE_NOT_A_NUMBER;
		--RAISE LOG 'fault Type Not A Number %',  faultTypeNotANumber;
		
		-- gotta be one 'o me
		IF fault_source = 0 OR fault_source = 1 OR fault_source = 2 THEN
			--RAISE LOG 'Inserting Fault: Source %', fault_source;
		ELSE
			RAISE EXCEPTION 'Unknown Fault Source %', fault_source;
		END IF;
		
		-- gotta specify type
		if (fault_type_id is null) THEN
			RAISE EXCEPTION 'Attempt to create fault with null Fault Type ID';
		END IF;

		-- if there's a sensor, lookup sensor master id
		IF (sensor_id is not null) THEN
		
			SELECT sensor_master_id, codespace INTO smId, smCodespace
				FROM qm.sensor_identity
				WHERE qm.sensor_identity.sensor_id = insertFault.sensor_id;

			IF NOT FOUND THEN
				RAISE EXCEPTION 'Sensor not found by ID %', sensor_id;
				RETURN 0;
			END IF;
			
			-- on data faults, 
			if (fault_source = FAULT_SOURE_DATA) THEN
				-- on NES 14/16
				if (smCodespace = CODESPACE_NES_14 OR smCodespace = CODESPACE_NES_16 ) THEN
					-- and this type of fault...
					if (fault_type_id = faultTypeNotANumber) THEN
						RAISE WARNING 'Skipping NES 14/16 "not a number" fault';
						RETURN 0;
					END IF;
				END IF;
			END IF;
			
		END IF;
		

		-- add it
		INSERT INTO qmfault.FAULT (
				fault_source, fault_type_id, status, station_id, sensor_id, camera_number, sensor_master_id, data_quality_id,
				start_time, monitor_hours, create_time, last_update_time
			)
		SELECT
			fault_source, fault_type_id, 
			0,  /* suspected */
			station_id, sensor_id, insertFault.camera_nbr, smId, insertFault.data_quality_id,
			obs_creationtime, insertFault.monitor_hours, now(), now()
			
		WHERE
			NOT EXISTS (
			   SELECT
			      NULL
			   FROM
			      qmfault.fault
			   WHERE
			      fault.fault_type_id = insertFault.fault_type_id
			   AND
			      fault.station_id = insertFault.station_id 
			   AND
			      fault.sensor_id = insertFault.sensor_id
			   AND
			      fault.camera_number = insertFault.camera_nbr
			);
		return 1;
	EXCEPTION 
		WHEN OTHERS THEN
			RAISE EXCEPTION '% %', SQLERRM, SQLSTATE;
	END;
	$$;


ALTER FUNCTION qmfault.insertfault(fault_source smallint, fault_type_id integer, data_quality_id bigint, obs_creationtime timestamp without time zone, station_id integer, sensor_id integer, camera_nbr character varying, monitor_hours smallint) OWNER TO postgres;

--
-- Name: processfaultupdate(); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION processfaultupdate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		
		-- all adds
		IF (TG_OP = 'INSERT') THEN
				INSERT INTO qmfault.fault_history
					(fault_id, status, create_time)
						values
					(NEW.fault_id, NEW.status, NEW.start_time);
		-- updates only if status changed
		ELSIF (TG_OP = 'UPDATE') THEN
			-- only if the status changed
			IF (OLD.status != NEW.status) THEN
				-- save it!
				INSERT INTO qmfault.fault_history
					(fault_id, status, create_time)
						values
					(OLD.fault_id, OLD.status, now());
			END IF;
		END IF;
		
		return NEW;
	END;
$$;


ALTER FUNCTION qmfault.processfaultupdate() OWNER TO postgres;

--
-- Name: storefaulthistory(fault); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION storefaulthistory(existingfault fault) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
	DECLARE
		retVal smallint DEFAULT 0;
	BEGIN
		
		-- just add the thing
		INSERT INTO
			qmfault.fault_history
				(fault_id, status, create_time)
				values
				(existingFault.fault_id, existingFault.status, now());
				
		-- todo - return something meaningful here
		return retVal;	
	END;
$$;


ALTER FUNCTION qmfault.storefaulthistory(existingfault fault) OWNER TO postgres;

--
-- Name: updatefault(integer, timestamp without time zone, bigint); Type: FUNCTION; Schema: qmfault; Owner: postgres
--

CREATE FUNCTION updatefault(fault_id integer, obs_creationtime timestamp without time zone, data_quality_id bigint) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		retVal smallint DEFAULT 0;
		resultCount integer DEFAULT 0;
	BEGIN
		WITH result AS (
			UPDATE qmfault.fault 
				SET end_time =
					CASE 
						WHEN qmfault.fault.start_time != updatefault.obs_creationtime
						THEN updatefault.obs_creationtime
					ELSE
						qmfault.fault.end_time
					END,
				data_quality_id = updatefault.data_quality_id
				WHERE qmfault.fault.fault_id = updateFault.fault_id
			RETURNING 1)
		SELECT count(*) from result INTO resultCount;
		if (resultCount = 1) THEN
			retVal := 2;
		ELSE
			RAISE WARNING 'No faults updated with ID %', fault_id;
		END IF;
	
		RETURN retVal;
	END;
	$$;


ALTER FUNCTION qmfault.updatefault(fault_id integer, obs_creationtime timestamp without time zone, data_quality_id bigint) OWNER TO postgres;

SET search_path = exportws, pg_catalog;

--
-- Name: groups; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE groups (
    vmdb_id integer NOT NULL,
    group_id integer NOT NULL,
    data_number integer,
    lane_name text,
    xsitype text
);


ALTER TABLE exportws.groups OWNER TO postgres;

--
-- Name: lanes; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE lanes (
    vmdb_id integer NOT NULL,
    data_number integer NOT NULL,
    reverse boolean,
    lane_direction text
);


ALTER TABLE exportws.lanes OWNER TO postgres;

--
-- Name: permissions; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE permissions (
    username text NOT NULL,
    region text NOT NULL,
    role text NOT NULL
);


ALTER TABLE exportws.permissions OWNER TO postgres;

--
-- Name: pwdb; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE pwdb (
    username text NOT NULL,
    salt text,
    password text
);


ALTER TABLE exportws.pwdb OWNER TO postgres;

--
-- Name: qttids; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE qttids (
    vmdb_id integer NOT NULL,
    qtt_id integer
);


ALTER TABLE exportws.qttids OWNER TO postgres;

--
-- Name: sensorindex; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE sensorindex (
    datex_id integer,
    sensor_id integer,
    data_symbol text,
    data_number integer,
    dqm_symbol text NOT NULL
);


ALTER TABLE exportws.sensorindex OWNER TO postgres;

--
-- Name: sensors; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE sensors (
    vmdb_id integer NOT NULL,
    group_id integer,
    datex_id integer NOT NULL,
    enabled boolean
);


ALTER TABLE exportws.sensors OWNER TO postgres;

--
-- Name: stations; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE stations (
    vmdb_id integer NOT NULL,
    measurementside text,
    version integer
);


ALTER TABLE exportws.stations OWNER TO postgres;

--
-- Name: xmltags; Type: TABLE; Schema: exportws; Owner: postgres; Tablespace: 
--

CREATE TABLE xmltags (
    data_symbol text NOT NULL,
    xmltagname text,
    measurementunit text,
    xsitype text,
    datatype text
);


ALTER TABLE exportws.xmltags OWNER TO postgres;

SET search_path = forecast, pg_catalog;

--
-- Name: forecast; Type: TABLE; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE TABLE forecast (
    forecast_id integer NOT NULL,
    forecast_provider character varying(32) NOT NULL,
    forecast_issue_time timestamp without time zone NOT NULL,
    forecast_start_time timestamp without time zone NOT NULL,
    forecast_end_time timestamp without time zone NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    alt integer,
    geom public.geometry(Point,4326),
    qc_tests_run integer DEFAULT 0 NOT NULL,
    qc_tests_passed integer DEFAULT 0 NOT NULL
);


ALTER TABLE forecast.forecast OWNER TO postgres;

--
-- Name: forecast_forecast_id_seq; Type: SEQUENCE; Schema: forecast; Owner: postgres
--

CREATE SEQUENCE forecast_forecast_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forecast.forecast_forecast_id_seq OWNER TO postgres;

--
-- Name: forecast_forecast_id_seq; Type: SEQUENCE OWNED BY; Schema: forecast; Owner: postgres
--

ALTER SEQUENCE forecast_forecast_id_seq OWNED BY forecast.forecast_id;


--
-- Name: forecast_symbol_qc; Type: TABLE; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE TABLE forecast_symbol_qc (
    forecast_symbol_qc_id integer NOT NULL,
    symbol character varying(32) NOT NULL,
    qc_value_low double precision NOT NULL,
    qc_value_high double precision NOT NULL
);


ALTER TABLE forecast.forecast_symbol_qc OWNER TO postgres;

--
-- Name: forecast_symbol_qc_forecast_symbol_qc_id_seq; Type: SEQUENCE; Schema: forecast; Owner: postgres
--

CREATE SEQUENCE forecast_symbol_qc_forecast_symbol_qc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forecast.forecast_symbol_qc_forecast_symbol_qc_id_seq OWNER TO postgres;

--
-- Name: forecast_symbol_qc_forecast_symbol_qc_id_seq; Type: SEQUENCE OWNED BY; Schema: forecast; Owner: postgres
--

ALTER SEQUENCE forecast_symbol_qc_forecast_symbol_qc_id_seq OWNED BY forecast_symbol_qc.forecast_symbol_qc_id;


--
-- Name: forecast_time_parameter; Type: TABLE; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE TABLE forecast_time_parameter (
    forecast_time_parameter_id integer NOT NULL,
    forecast_id integer NOT NULL,
    forecast_valid_time timestamp without time zone NOT NULL,
    symbol character varying(32) NOT NULL,
    value double precision NOT NULL,
    qc_tests_run integer DEFAULT 0 NOT NULL,
    qc_tests_passed integer DEFAULT 0 NOT NULL
);


ALTER TABLE forecast.forecast_time_parameter OWNER TO postgres;

--
-- Name: forecast_time_parameter_forecast_time_parameter_id_seq; Type: SEQUENCE; Schema: forecast; Owner: postgres
--

CREATE SEQUENCE forecast_time_parameter_forecast_time_parameter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE forecast.forecast_time_parameter_forecast_time_parameter_id_seq OWNER TO postgres;

--
-- Name: forecast_time_parameter_forecast_time_parameter_id_seq; Type: SEQUENCE OWNED BY; Schema: forecast; Owner: postgres
--

ALTER SEQUENCE forecast_time_parameter_forecast_time_parameter_id_seq OWNED BY forecast_time_parameter.forecast_time_parameter_id;


--
-- Name: schema_version; Type: TABLE; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE TABLE schema_version (
    version_rank integer NOT NULL,
    installed_rank integer NOT NULL,
    version character varying(50) NOT NULL,
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE forecast.schema_version OWNER TO postgres;


--
-- Data for Name: schema_version; Type: TABLE DATA; Schema: forecast; Owner: postgres
--

INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (1, 1, '0', '<< Flyway Schema Creation >>', 'SCHEMA', '"forecast"', NULL, 'postgres', '2016-10-07 14:38:03.022253', 0, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (2, 2, '118.001', 'initial setup', 'SQL', 'V118_001__initial_setup.sql', -1918072902, 'postgres', '2016-10-07 14:38:03.097832', 66, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (3, 3, '118.002', 'forecast lookup', 'SQL', 'V118_002__forecast_lookup.sql', -1215697535, 'postgres', '2016-10-07 14:38:03.191976', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (4, 4, '118.003', 'forecast starttime', 'SQL', 'V118_003__forecast_starttime.sql', 193452337, 'postgres', '2016-10-07 14:38:03.216816', 12, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (5, 5, '118.004', 'forecast changes', 'SQL', 'V118_004__forecast_changes.sql', 749847230, 'postgres', '2016-10-07 14:38:03.258869', 34, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (6, 6, '118.005', 'forecast symbol qc', 'SQL', 'V118_005__forecast_symbol_qc.sql', -140338051, 'postgres', '2016-10-07 14:38:03.313703', 29, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (7, 7, '118.006', 'forecast param qc', 'SQL', 'V118_006__forecast_param_qc.sql', 1754554437, 'postgres', '2016-10-07 14:38:03.358037', 16, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (8, 8, '118.007', 'forecast symbol qc2', 'SQL', 'V118_007__forecast_symbol_qc2.sql', 1824634766, 'postgres', '2016-10-07 14:38:03.392403', 4, true);

SET search_path = public, pg_catalog;

--
-- Name: faulttypeid; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE faulttypeid (
    fault_type_id integer
);


ALTER TABLE public.faulttypeid OWNER TO postgres;

--
-- Name: schema_version; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE schema_version (
    version_rank integer NOT NULL,
    installed_rank integer NOT NULL,
    version character varying(50) NOT NULL,
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


ALTER TABLE public.schema_version OWNER TO postgres;

--
-- Data for Name: schema_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (1, 1, '1', '<< Flyway Baseline >>', 'BASELINE', '<< Flyway Baseline >>', NULL, 'postgres', '2015-10-05 15:11:18.771209', 0, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (2, 2, '1.1000', 'fault history', 'SQL', 'V1_1000__fault_history.sql', 448028445, 'postgres', '2015-10-05 15:11:18.836972', 24, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (3, 3, '1.1001', 'station message interval', 'SQL', 'V1_1001__station_message_interval.sql', -946346857, 'postgres', '2015-10-05 15:11:18.880819', 6, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (4, 4, '1.1002', 'station param count', 'SQL', 'V1_1002__station_param_count.sql', -955469155, 'postgres', '2015-10-05 15:11:18.902632', 7, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (5, 5, '1.1003', 'rollup network performance', 'SQL', 'V1_1003__rollup_network_performance.sql', -1863154759, 'postgres', '2015-10-05 15:11:18.926318', 14, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (6, 6, '1.1004', 'calc station param count', 'SQL', 'V1_1004__calc_station_param_count.sql', 1829975352, 'postgres', '2015-10-05 15:11:18.954365', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (7, 7, '1.1005', 'cam image list', 'SQL', 'V1_1005__cam_image_list.sql', -17511858, 'postgres', '2015-10-05 15:11:18.971293', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (8, 8, '1.1006', 'rollup camera performance', 'SQL', 'V1_1006__rollup_camera_performance.sql', -2019780296, 'postgres', '2015-10-05 15:11:18.996485', 15, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (9, 9, '1.1007', 'rollup network performance', 'SQL', 'V1_1007__rollup_network_performance.sql', 880443003, 'postgres', '2015-10-05 15:11:19.025779', 19, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (10, 10, '1.1008', 'demo change', 'SQL', 'V1_1008__demo_change.sql', 0, 'postgres', '2015-10-05 15:11:19.06106', 0, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (11, 11, '1.1009', 'demo actual change', 'SQL', 'V1_1009__demo_actual_change.sql', -290548232, 'postgres', '2015-10-05 15:11:19.074138', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (12, 12, '1.1010', 'demo undo change', 'SQL', 'V1_1010__demo_undo_change.sql', -692649699, 'postgres', '2015-10-05 15:11:19.090366', 2, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (13, 13, '1.1011', 'station image interval', 'SQL', 'V1_1011__station_image_interval.sql', -1971145172, 'postgres', '2015-10-05 15:11:19.105569', 6, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (14, 14, '1.1012', 'data bigint', 'SQL', 'V1_1012__data_bigint.sql', -430459778, 'postgres', '2015-10-05 15:11:19.12482', 45, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (15, 15, '1.1013', 'fix dq bigint stored procs', 'SQL', 'V1_1013__fix_dq_bigint_stored_procs.sql', -638537293, 'postgres', '2015-10-05 15:11:19.186737', 52, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (16, 16, '1.1014', 'dmfault schema', 'SQL', 'V1_1014__dmfault_schema.sql', 1380997308, 'postgres', '2015-10-05 15:11:19.253482', 221, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (17, 17, '1.1015', 'qmfault drop old functions', 'SQL', 'V1_1015__qmfault_drop_old_functions.sql', 448760687, 'postgres', '2015-10-05 15:11:19.490526', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (18, 18, '1.1016', 'qm polling interval', 'SQL', 'V1_1016__qm_polling_interval.sql', -936286448, 'postgres', '2015-10-07 12:17:30.991435', 19, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (19, 19, '1.1017', 'qm polling interval defaults', 'SQL', 'V1_1017__qm_polling_interval_defaults.sql', -644831875, 'postgres', '2015-10-07 12:17:31.028135', 19, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (20, 20, '1.1700', 'sensor monitored tables', 'SQL', 'V1_1700__sensor_monitored_tables.sql', 713977187, 'postgres', '2015-12-18 16:37:08.675714', 29, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (21, 21, '1.1701', 'sensor monitored tables and functions', 'SQL', 'V1_1701__sensor_monitored_tables_and_functions.sql', -2070332719, 'postgres', '2015-12-18 16:37:08.730923', 262, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (22, 22, '1.1702', 'default codespaces', 'SQL', 'V1_1702__default_codespaces.sql', 446462308, 'postgres', '2015-12-18 16:37:09.012593', 218, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (23, 23, '1.1703', 'ignore non monitored stations', 'SQL', 'V1_1703__ignore_non_monitored_stations.sql', 110006483, 'postgres', '2015-12-18 16:37:09.245478', 14, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (24, 24, '1.1704', 'default codespaces', 'SQL', 'V1_1704__default_codespaces.sql', -1214071222, 'postgres', '2015-12-18 16:37:09.273131', 251, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (25, 25, '1.1705', 'sensor monitored tables and functions', 'SQL', 'V1_1705__sensor_monitored_tables_and_functions.sql', 1618381569, 'postgres', '2015-12-18 16:37:09.544196', 17, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (26, 26, '1.1706', 'dump faults', 'SQL', 'V1_1706__dump_faults.sql', 1132193165, 'postgres', '2015-12-18 16:37:09.591532', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (27, 27, '1.1707', 'missing sensor proc', 'SQL', 'V1_1707__missing_sensor_proc.sql', 638559225, 'postgres', '2015-12-18 16:37:09.61926', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (28, 28, '1.1708', 'ignore non monitored stations', 'SQL', 'V1_1708__ignore_non_monitored_stations.sql', 524691569, 'postgres', '2015-12-18 16:37:09.648997', 14, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (29, 29, '1.1709', 'recent data quality', 'SQL', 'V1_1709__recent_data_quality.sql', -1031665558, 'postgres', '2015-12-18 16:37:09.679451', 19, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (30, 30, '1.1710', 'report monitored only', 'SQL', 'V1_1710__report_monitored_only.sql', -100657868, 'postgres', '2015-12-18 16:37:09.71158', 10, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (31, 31, '110.001', 'reduce logging', 'SQL', 'V110_001__reduce_logging.sql', -240202004, 'postgres', '2016-02-03 15:13:03.84326', 69, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (32, 32, '110.002', 'rollup parameter performance', 'SQL', 'V110_002__rollup_parameter_performance.sql', -1591737875, 'postgres', '2016-02-03 15:13:03.94501', 24, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (33, 33, '110.003', 'fix dup station faults', 'SQL', 'V110_003__fix_dup_station_faults.sql', -1103528490, 'postgres', '2016-02-03 15:13:04.021438', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (34, 34, '111.001', 'missing sensors', 'SQL', 'V111_001__missing_sensors.sql', 136635933, 'postgres', '2016-02-18 15:47:33.932302', 31, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (35, 35, '112.001', 'exportdbtables', 'SQL', 'V112_001__exportdbtables.sql', -123114628, 'postgres', '2016-03-29 14:43:14.463776', 144, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (36, 36, '113.001', 'forecast stations', 'SQL', 'V113_001__forecast_stations.sql', -1226527730, 'postgres', '2016-03-29 14:43:14.63546', 12, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (37, 37, '113.002', 'station mso', 'SQL', 'V113_002__station_mso.sql', -512365841, 'postgres', '2016-03-29 14:43:14.668782', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (38, 38, '113.003', 'st update1', 'SQL', 'V113_003__st_update1.sql', 1341223089, 'postgres', '2016-03-29 14:43:14.688833', 5, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (39, 39, '113.004', 'st update2', 'SQL', 'V113_004__st_update2.sql', -1790031200, 'postgres', '2016-03-29 14:43:14.70872', 9, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (40, 40, '113.005', 'fs update1', 'SQL', 'V113_005__fs_update1.sql', -796092050, 'postgres', '2016-03-29 14:43:14.737076', 3, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (41, 41, '114.001', 'sensor stuck', 'SQL', 'V114_001__sensor_stuck.sql', 1691464152, 'postgres', '2016-04-19 14:47:20.83828', 71, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (42, 42, '114.002', 'sensor stuck stored procs', 'SQL', 'V114_002__sensor_stuck_stored_procs.sql', -593798694, 'postgres', '2016-04-19 14:47:20.938129', 63, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (43, 43, '114.003', 'sensor stuck stored proc update1', 'SQL', 'V114_003__sensor_stuck_stored_proc_update1.sql', 1899873363, 'postgres', '2016-04-19 14:47:21.02485', 12, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (44, 44, '114.004', 'sensor stuck stored proc update2', 'SQL', 'V114_004__sensor_stuck_stored_proc_update2.sql', 2130252636, 'postgres', '2016-04-19 14:47:21.055566', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (45, 45, '114.005', 'sensor stuck stored proc update3', 'SQL', 'V114_005__sensor_stuck_stored_proc_update3.sql', 1447371911, 'postgres', '2016-04-19 14:47:21.082055', 5, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (46, 46, '114.006', 'sensor stuck stored proc update4', 'SQL', 'V114_006__sensor_stuck_stored_proc_update4.sql', 821217081, 'postgres', '2016-04-19 14:47:21.108818', 26, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (47, 47, '114.007', 'sensor stuck stored proc update5', 'SQL', 'V114_007__sensor_stuck_stored_proc_update5.sql', 1457734743, 'postgres', '2016-04-19 14:47:21.156097', 24, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (48, 48, '114.008', 'sensor stuck stored proc update6', 'SQL', 'V114_008__sensor_stuck_stored_proc_update6.sql', 1964541915, 'postgres', '2016-04-19 14:47:21.194722', 18, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (49, 49, '114.009', 'region pows', 'SQL', 'V114_009__region_pows.sql', 215249288, 'postgres', '2016-04-19 14:47:21.260349', 16, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (50, 50, '115.001', 'drop odd partitions', 'SQL', 'V115_001__drop_odd_partitions.sql', 838655508, 'postgres', '2016-05-04 15:51:16.137868', 33, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (51, 51, '115.002', 'repair data quality partition maker', 'SQL', 'V115_002__repair_data_quality_partition_maker.sql', -1404706159, 'postgres', '2016-05-04 15:51:16.19394', 30, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (52, 52, '115.003', 'remove dq fk constraints', 'SQL', 'V115_003__remove_dq_fk_constraints.sql', -275039734, 'postgres', '2016-05-04 15:51:16.242673', 1035, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (53, 53, '115.004', 'remove sensor overrides', 'SQL', 'V115_004__remove_sensor_overrides.sql', -2071483707, 'postgres', '2016-05-04 15:51:17.302685', 9, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (54, 54, '115.005', 'fix faults for specified customers', 'SQL', 'V115_005__fix_faults_for_specified_customers.sql', 1429697167, 'postgres', '2016-05-04 15:51:17.330969', 43, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (55, 55, '116.001', 'rollup all sensors', 'SQL', 'V116_001__rollup_all_sensors.sql', 589551717, 'postgres', '2016-06-01 15:51:57.237727', 660, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (56, 56, '116.002', 'rollup all sensors plus sm', 'SQL', 'V116_002__rollup_all_sensors_plus_sm.sql', -31461104, 'postgres', '2016-06-01 15:51:57.920749', 74, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (57, 57, '116.003', 'improved parameter table', 'SQL', 'V116_003__improved_parameter_table.sql', 1598523849, 'postgres', '2016-06-01 15:51:58.010911', 21, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (62, 62, '118.001', 'forecast schema', 'SQL', 'V118_001__forecast_schema.sql', 444838219, 'postgres', '2016-10-07 12:58:06.812529', 94, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (58, 58, '117.001', 'Add UOM To SensorMaster', 'SQL', 'V117_001__Add_UOM_To_SensorMaster.sql', -535410858, 'postgres', '2016-06-22 15:13:12.738737', 11, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (59, 59, '117.002', 'get station observations', 'SQL', 'V117_002__get_station_observations.sql', -1501671327, 'postgres', '2016-06-22 15:13:12.77858', 24, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (60, 60, '117.003', 'uom vmdb values', 'SQL', 'V117_003__uom_vmdb_values.sql', 816530483, 'postgres', '2016-06-22 15:13:12.82735', 381, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (61, 61, '117.004', 'uom vmdb values redux', 'SQL', 'V117_004__uom_vmdb_values_redux.sql', -1534383634, 'postgres', '2016-06-22 15:13:13.22983', 389, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (63, 63, '118.002', 'forecast schema fix1', 'SQL', 'V118_002__forecast_schema_fix1.sql', -1363950203, 'postgres', '2016-10-07 12:58:06.934651', 20, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (64, 64, '118.003', 'supported forecast symbols', 'SQL', 'V118_003__supported_forecast_symbols.sql', -2034551389, 'postgres', '2016-10-07 12:58:06.974265', 22, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (65, 65, '118.004', 'master identity to forecast symbol', 'SQL', 'V118_004__master_identity_to_forecast_symbol.sql', 1921136759, 'postgres', '2016-10-07 12:58:07.020183', 18, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (66, 66, '118.005', 'dump forecast schma', 'SQL', 'V118_005__dump_forecast_schma.sql', 1555105558, 'postgres', '2016-10-07 12:58:07.062016', 31, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (67, 67, '118.006', 'external forecast schma', 'SQL', 'V118_006__external_forecast_schma.sql', -761453372, 'postgres', '2016-10-07 14:38:12.414245', 46, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (68, 68, '118.007', 'external forecast update', 'SQL', 'V118_007__external_forecast_update.sql', -1327335654, 'postgres', '2016-10-07 14:38:12.492188', 42, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (69, 69, '118.008', 'external forecast update2', 'SQL', 'V118_008__external_forecast_update2.sql', 1275474548, 'postgres', '2016-10-07 14:38:12.563399', 5, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (70, 70, '118.009', 'forecast provider', 'SQL', 'V118_009__forecast_provider.sql', 293016129, 'postgres', '2016-10-07 14:38:12.592619', 7, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (71, 71, '118.010', 'forecast station updates', 'SQL', 'V118_010__forecast_station_updates.sql', -424706216, 'postgres', '2016-10-07 14:38:12.622792', 7, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (72, 72, '118.011', 'external forecast updates', 'SQL', 'V118_011__external_forecast_updates.sql', 462342321, 'postgres', '2016-10-07 14:38:12.655977', 22, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (73, 73, '118.012', 'external forecast alert', 'SQL', 'V118_012__external_forecast_alert.sql', 207601940, 'postgres', '2016-10-07 14:38:12.698073', 19, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (74, 74, '118.013', 'external forecast alert', 'SQL', 'V118_013__external_forecast_alert.sql', 2027192385, 'postgres', '2016-10-07 14:38:12.739607', 15, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (75, 75, '118.014', 'external forecast station', 'SQL', 'V118_014__external_forecast_station.sql', 1689205243, 'postgres', '2016-10-07 14:38:12.780592', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (76, 76, '118.015', 'external forecast end time', 'SQL', 'V118_015__external_forecast_end_time.sql', -829765342, 'postgres', '2016-10-07 14:38:12.806042', 3, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (77, 77, '118.016', 'external forecast alert new fields', 'SQL', 'V118_016__external_forecast_alert_new_fields.sql', 1409369593, 'postgres', '2016-10-07 14:38:12.834723', 6, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (78, 78, '118.017', 'external forecast alert new fields', 'SQL', 'V118_017__external_forecast_alert_new_fields.sql', -1626459353, 'postgres', '2016-10-07 14:38:12.85671', 7, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (79, 79, '118.018', 'external forecast alert new fields', 'SQL', 'V118_018__external_forecast_alert_new_fields.sql', 1683051389, 'postgres', '2016-10-07 14:38:12.876963', 2, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (80, 80, '118.019', 'external forecast alert new fields', 'SQL', 'V118_019__external_forecast_alert_new_fields.sql', 816367071, 'postgres', '2016-10-07 14:38:12.894514', 3, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (81, 81, '118.020', 'external forecast alert config', 'SQL', 'V118_020__external_forecast_alert_config.sql', 1141059058, 'postgres', '2016-10-07 14:38:12.911969', 16, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (82, 82, '119.001', 'external forecast alert update', 'SQL', 'V119_001__external_forecast_alert_update.sql', 1229144894, 'postgres', '2016-10-07 14:38:12.942647', 5, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (83, 83, '119.002', 'external forecast alert config update', 'SQL', 'V119_002__external_forecast_alert_config_update.sql', 1598615403, 'postgres', '2016-10-07 14:38:12.966647', 3, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (84, 84, '120.001', 'triton sensor list', 'SQL', 'V120_001__triton_sensor_list.sql', -1459511784, 'postgres', '2016-10-07 14:38:12.98417', 250, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (85, 85, '120.002', 'triton sensor update', 'SQL', 'V120_002__triton_sensor_update.sql', -1692804654, 'postgres', '2016-10-07 14:38:13.248316', 44, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (86, 86, '121.001', 'fix forecast schema', 'SQL', 'V121_001__fix_forecast_schema.sql', -281718949, 'postgres', '2016-10-07 14:38:13.307392', 15, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (88, 88, '121.003', 'forecast variation update', 'SQL', 'V121_003__forecast_variation_update.sql', 387162986, 'postgres', '2016-11-21 14:31:53.712814', 3, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (89, 89, '121.004', 'forecast variation update2', 'SQL', 'V121_004__forecast_variation_update2.sql', -1324561242, 'postgres', '2016-11-21 14:31:53.732089', 9, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (90, 90, '121.005', 'forecast variation update3', 'SQL', 'V121_005__forecast_variation_update3.sql', 1421247340, 'postgres', '2016-11-21 14:31:53.757511', 8, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (91, 91, '121.006', 'forecast variation update4', 'SQL', 'V121_006__forecast_variation_update4.sql', 838507035, 'postgres', '2016-11-21 14:31:53.790401', 4, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (87, 87, '121.002', 'forecast variation', 'SQL', 'V121_002__forecast_variation.sql', 550606916, 'postgres', '2016-11-21 14:31:53.621603', 42, true);
INSERT INTO schema_version (version_rank, installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) VALUES (92, 92, '123.001', 'find fault', 'SQL', 'V123_001__find_fault.sql', -166324612, 'postgres', '2016-12-29 15:52:20.061847', 42, true);



SET search_path = qm, pg_catalog;

--
-- Name: cam_image_list; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE cam_image_list (
    station_id integer NOT NULL,
    camera_nbr character varying(4) NOT NULL,
    image_timestamp timestamp without time zone NOT NULL
);


ALTER TABLE qm.cam_image_list OWNER TO postgres;

--
-- Name: data_quality; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE data_quality (
    data_quality_id bigint NOT NULL,
    obs_creationtime timestamp without time zone NOT NULL,
    sensor_id integer NOT NULL,
    test_type integer NOT NULL,
    test_source integer NOT NULL,
    status integer NOT NULL,
    range_check_id integer,
    step_check_id integer,
    cross_check_id integer,
    uncertancy integer,
    db_insertiontime timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE qm.data_quality OWNER TO postgres;

--
-- Name: data_quality_2017_01_02; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE data_quality_2017_01_02 (
    CONSTRAINT data_quality_2017_01_02_obs_creationtime_check CHECK (((obs_creationtime >= '2017-01-02'::date) AND (obs_creationtime < '2017-01-09'::date)))
)
INHERITS (data_quality);


ALTER TABLE qm.data_quality_2017_01_02 OWNER TO postgres;

--
-- Name: data_quality_2017_01_09; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE data_quality_2017_01_09 (
    CONSTRAINT data_quality_2017_01_09_obs_creationtime_check CHECK (((obs_creationtime >= '2017-01-09'::date) AND (obs_creationtime < '2017-01-16'::date)))
)
INHERITS (data_quality);


ALTER TABLE qm.data_quality_2017_01_09 OWNER TO postgres;

--
-- Name: data_quality_2017_01_16; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE data_quality_2017_01_16 (
    CONSTRAINT data_quality_2017_01_16_obs_creationtime_check CHECK (((obs_creationtime >= '2017-01-16'::date) AND (obs_creationtime < '2017-01-23'::date)))
)
INHERITS (data_quality);


ALTER TABLE qm.data_quality_2017_01_16 OWNER TO postgres;

--
-- Name: data_quality_data_quality_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE data_quality_data_quality_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.data_quality_data_quality_id_seq OWNER TO postgres;

--
-- Name: data_quality_data_quality_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE data_quality_data_quality_id_seq OWNED BY data_quality.data_quality_id;


--
-- Name: data_value; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE data_value (
    obs_creationtime timestamp without time zone NOT NULL,
    sensor_id integer NOT NULL,
    db_insertiontime timestamp without time zone NOT NULL,
    nvalue double precision,
    stn_id integer NOT NULL,
    nvalue_str character varying(500),
    qc_check_total integer DEFAULT 0 NOT NULL,
    qc_check_failed integer DEFAULT 0 NOT NULL
);


ALTER TABLE qm.data_value OWNER TO postgres;

--
-- Name: TABLE data_value; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON TABLE data_value IS 'Observations Table.';


--
-- Name: COLUMN data_value.obs_creationtime; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.obs_creationtime IS 'Observation time';


--
-- Name: COLUMN data_value.sensor_id; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.sensor_id IS 'Sensor identificaton.';


--
-- Name: COLUMN data_value.db_insertiontime; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.db_insertiontime IS 'database insertion time';


--
-- Name: COLUMN data_value.nvalue; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.nvalue IS 'Value of numerical observation.';


--
-- Name: COLUMN data_value.stn_id; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.stn_id IS 'User set quality for the observation.';


--
-- Name: COLUMN data_value.nvalue_str; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN data_value.nvalue_str IS 'string aalue of observation (if NaN).';


--
-- Name: dqm_old_stations; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE dqm_old_stations (
    stn_id integer,
    xml_target_name character varying(100),
    station_name character varying(100),
    lat double precision,
    lon double precision,
    region_name character varying(100)
);


ALTER TABLE qm.dqm_old_stations OWNER TO postgres;

--
-- Name: dqm_web_user; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE dqm_web_user (
    dqm_web_user_id integer NOT NULL,
    uid character varying(100) NOT NULL,
    pwd character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    is_expired boolean DEFAULT false NOT NULL,
    is_admin boolean DEFAULT false NOT NULL,
    last_filter_pref integer,
    date_format smallint DEFAULT 0,
    locale character varying(10)
);


ALTER TABLE qm.dqm_web_user OWNER TO postgres;

--
-- Name: dqm_web_user_dqm_web_user_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE dqm_web_user_dqm_web_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.dqm_web_user_dqm_web_user_id_seq OWNER TO postgres;

--
-- Name: dqm_web_user_dqm_web_user_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE dqm_web_user_dqm_web_user_id_seq OWNED BY dqm_web_user.dqm_web_user_id;


--
-- Name: dqm_web_user_preference; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE dqm_web_user_preference (
    pref_id integer NOT NULL,
    pref_type integer NOT NULL,
    owner_id integer NOT NULL,
    name character varying(100),
    value character varying(4098)
);


ALTER TABLE qm.dqm_web_user_preference OWNER TO postgres;

--
-- Name: dqm_web_user_preference_default; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE dqm_web_user_preference_default (
    dqm_web_user_id integer NOT NULL,
    pref_id integer NOT NULL
);


ALTER TABLE qm.dqm_web_user_preference_default OWNER TO postgres;

--
-- Name: dqm_web_user_preference_default_dqm_web_user_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE dqm_web_user_preference_default_dqm_web_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.dqm_web_user_preference_default_dqm_web_user_id_seq OWNER TO postgres;

--
-- Name: dqm_web_user_preference_default_dqm_web_user_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE dqm_web_user_preference_default_dqm_web_user_id_seq OWNED BY dqm_web_user_preference_default.dqm_web_user_id;


--
-- Name: dqm_web_user_preference_pref_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE dqm_web_user_preference_pref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.dqm_web_user_preference_pref_id_seq OWNER TO postgres;

--
-- Name: dqm_web_user_preference_pref_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE dqm_web_user_preference_pref_id_seq OWNED BY dqm_web_user_preference.pref_id;


--
-- Name: error_codes; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE error_codes (
    error_number integer NOT NULL,
    error_code character varying(24),
    error_type character varying(24),
    error_description character varying(200),
    entry_date date DEFAULT now() NOT NULL,
    added_by character varying(24)
);


ALTER TABLE qm.error_codes OWNER TO postgres;

--
-- Name: external_forecast; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE external_forecast (
    external_forecast_id integer NOT NULL,
    pfws_forecast_id integer NOT NULL,
    forecast_provider_id integer NOT NULL,
    issue_time timestamp without time zone NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    geom public.geometry(Point,4326),
    start_time timestamp without time zone,
    qc_tests_run integer DEFAULT 0 NOT NULL,
    qc_tests_passed integer DEFAULT 0 NOT NULL,
    station_id integer,
    end_time timestamp without time zone
);


ALTER TABLE qm.external_forecast OWNER TO postgres;

--
-- Name: external_forecast_alert; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE external_forecast_alert (
    external_forecast_alert_id integer NOT NULL,
    alert_type smallint NOT NULL,
    alert_time timestamp without time zone NOT NULL,
    external_forecast_id integer,
    forecast_provider_id integer NOT NULL,
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    message character varying(2048),
    station_id integer,
    sensor_id integer,
    forecast_parameter_id integer,
    obs_time timestamp without time zone,
    forecast_symbol character varying(256),
    forecast_deviation_config double precision,
    forecast_deviation_amount double precision,
    external_forecast_alert_config_id integer
);


ALTER TABLE qm.external_forecast_alert OWNER TO postgres;

--
-- Name: external_forecast_alert_config; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE external_forecast_alert_config (
    external_forecast_alert_config_id integer NOT NULL,
    alert_type smallint NOT NULL,
    forecast_provider_id integer,
    supported_forecast_symbol_id integer,
    enabled boolean DEFAULT true NOT NULL,
    email_recipient_list character varying(8192),
    maximum_deviation_amount double precision
);


ALTER TABLE qm.external_forecast_alert_config OWNER TO postgres;

--
-- Name: external_forecast_alert_confi_external_forecast_alert_confi_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE external_forecast_alert_confi_external_forecast_alert_confi_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.external_forecast_alert_confi_external_forecast_alert_confi_seq OWNER TO postgres;

--
-- Name: external_forecast_alert_confi_external_forecast_alert_confi_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE external_forecast_alert_confi_external_forecast_alert_confi_seq OWNED BY external_forecast_alert_config.external_forecast_alert_config_id;


--
-- Name: external_forecast_alert_external_forecast_alert_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE external_forecast_alert_external_forecast_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.external_forecast_alert_external_forecast_alert_id_seq OWNER TO postgres;

--
-- Name: external_forecast_alert_external_forecast_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE external_forecast_alert_external_forecast_alert_id_seq OWNED BY external_forecast_alert.external_forecast_alert_id;


--
-- Name: external_forecast_external_forecast_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE external_forecast_external_forecast_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.external_forecast_external_forecast_id_seq OWNER TO postgres;

--
-- Name: external_forecast_external_forecast_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE external_forecast_external_forecast_id_seq OWNED BY external_forecast.external_forecast_id;


--
-- Name: external_forecast_variation; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE external_forecast_variation (
    external_forecast_variation_id integer NOT NULL,
    forecast_provider_id integer NOT NULL,
    forecast_symbol character varying(32) NOT NULL,
    sensor_master_id integer NOT NULL,
    external_forecast_id integer NOT NULL,
    obs_creation_time timestamp without time zone NOT NULL,
    variance double precision NOT NULL,
    station_id integer NOT NULL,
    obs_value double precision NOT NULL,
    obs_offset_minutes smallint NOT NULL,
    fc_first_ftp_offset_minutes smallint NOT NULL,
    fc_first_ftp_fc_value double precision NOT NULL,
    fc_second_ftp_offset_minutes smallint NOT NULL,
    fc_second_ftp_fc_value double precision NOT NULL,
    fc_extrapolated_value double precision NOT NULL,
    fc_start_time timestamp without time zone NOT NULL
);


ALTER TABLE qm.external_forecast_variation OWNER TO postgres;

--
-- Name: external_forecast_variation_external_forecast_variation_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE external_forecast_variation_external_forecast_variation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.external_forecast_variation_external_forecast_variation_id_seq OWNER TO postgres;

--
-- Name: external_forecast_variation_external_forecast_variation_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE external_forecast_variation_external_forecast_variation_id_seq OWNED BY external_forecast_variation.external_forecast_variation_id;


--
-- Name: forecast_provider; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE forecast_provider (
    forecast_provider_id integer NOT NULL,
    forecast_ui_name character varying(32),
    forecast_provider character varying(32)
);


ALTER TABLE qm.forecast_provider OWNER TO postgres;

--
-- Name: forecast_provider_forecast_provider_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE forecast_provider_forecast_provider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.forecast_provider_forecast_provider_id_seq OWNER TO postgres;

--
-- Name: forecast_provider_forecast_provider_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE forecast_provider_forecast_provider_id_seq OWNED BY forecast_provider.forecast_provider_id;


--
-- Name: geo_track; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE geo_track (
    geo_track_id integer NOT NULL,
    mes_datetime timestamp without time zone NOT NULL,
    entry_datetime timestamp without time zone DEFAULT now() NOT NULL,
    geo_user character varying(24) NOT NULL,
    user_phone_no character varying(20),
    geom public.geometry(Point,4326),
    lat double precision NOT NULL,
    lon double precision NOT NULL,
    mes_count integer,
    run_id character varying(60) DEFAULT 'empty'::character varying NOT NULL
);


ALTER TABLE qm.geo_track OWNER TO postgres;

--
-- Name: geo_track_geo_track_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE geo_track_geo_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.geo_track_geo_track_id_seq OWNER TO postgres;

--
-- Name: geo_track_geo_track_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE geo_track_geo_track_id_seq OWNED BY geo_track.geo_track_id;


--
-- Name: last_reading; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE UNLOGGED TABLE last_reading (
    sensor_id bigint NOT NULL,
    nvalue double precision DEFAULT 65335,
    last_datetime timestamp without time zone DEFAULT now() NOT NULL,
    default_status integer DEFAULT 0 NOT NULL,
    last_reading_id bigint NOT NULL
);


ALTER TABLE qm.last_reading OWNER TO postgres;

--
-- Name: last_reading_last_reading_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE last_reading_last_reading_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.last_reading_last_reading_id_seq OWNER TO postgres;

--
-- Name: last_reading_last_reading_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE last_reading_last_reading_id_seq OWNED BY last_reading.last_reading_id;


--
-- Name: region_note; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE region_note (
    region_note_id integer NOT NULL,
    region_id integer NOT NULL,
    region_note character varying(4096),
    region_note_time timestamp without time zone NOT NULL
);


ALTER TABLE qm.region_note OWNER TO postgres;

--
-- Name: region_note_region_note_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE region_note_region_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.region_note_region_note_id_seq OWNER TO postgres;

--
-- Name: region_note_region_note_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE region_note_region_note_id_seq OWNED BY region_note.region_note_id;


--
-- Name: report; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE report (
    report_id integer NOT NULL,
    dqm_web_user_id integer NOT NULL,
    report_definition_id integer NOT NULL,
    status smallint DEFAULT 0,
    output_filename character varying(100),
    creationtime timestamp without time zone NOT NULL,
    is_public boolean
);


ALTER TABLE qm.report OWNER TO postgres;

--
-- Name: report_definition; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE report_definition (
    report_definition_id integer NOT NULL,
    report_name character varying(100) NOT NULL,
    report_file_name character varying(100) NOT NULL,
    creationtime timestamp without time zone NOT NULL,
    updatetime timestamp without time zone NOT NULL
);


ALTER TABLE qm.report_definition OWNER TO postgres;

--
-- Name: report_definition_report_definition_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE report_definition_report_definition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.report_definition_report_definition_id_seq OWNER TO postgres;

--
-- Name: report_definition_report_definition_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE report_definition_report_definition_id_seq OWNED BY report_definition.report_definition_id;


--
-- Name: report_report_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE report_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.report_report_id_seq OWNER TO postgres;

--
-- Name: report_report_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE report_report_id_seq OWNED BY report.report_id;


--
-- Name: rollup_camera_performance; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE rollup_camera_performance (
    image_date date NOT NULL,
    station_id integer NOT NULL,
    image_count integer NOT NULL
);


ALTER TABLE qm.rollup_camera_performance OWNER TO postgres;

--
-- Name: rollup_network_performance; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE rollup_network_performance (
    message_date date NOT NULL,
    stn_id integer NOT NULL,
    message_count integer NOT NULL,
    parameter_message_count integer
);


ALTER TABLE qm.rollup_network_performance OWNER TO postgres;

--
-- Name: rollup_parameter_performance; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE rollup_parameter_performance (
    obs_creationtime timestamp without time zone NOT NULL,
    stn_id integer NOT NULL,
    sensor_id integer NOT NULL,
    sensor_master_id integer NOT NULL
);


ALTER TABLE qm.rollup_parameter_performance OWNER TO postgres;

--
-- Name: sensor_alias; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_alias (
    sensor_alias_id integer NOT NULL,
    sensor_alias character varying(100) NOT NULL,
    sensor_group_id integer,
    sensor_group_display_order integer
);


ALTER TABLE qm.sensor_alias OWNER TO postgres;

--
-- Name: sensor_alias_sensor_alias_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_alias_sensor_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_alias_sensor_alias_id_seq OWNER TO postgres;

--
-- Name: sensor_alias_sensor_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_alias_sensor_alias_id_seq OWNED BY sensor_alias.sensor_alias_id;


--
-- Name: sensor_cross_check; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_cross_check (
    cross_check_id integer NOT NULL,
    sensor_master_id integer NOT NULL,
    region_id integer,
    station_id integer,
    xcheck_definition character varying(100),
    comments character varying(200),
    creation_date date DEFAULT now() NOT NULL,
    start_doy integer DEFAULT 0 NOT NULL,
    end_doy integer DEFAULT 366 NOT NULL,
    sensor_no integer DEFAULT 0 NOT NULL
);


ALTER TABLE qm.sensor_cross_check OWNER TO postgres;

--
-- Name: COLUMN sensor_cross_check.xcheck_definition; Type: COMMENT; Schema: qm; Owner: postgres
--

COMMENT ON COLUMN sensor_cross_check.xcheck_definition IS 'Cross check algorithm defined here';


--
-- Name: sensor_cross_check_cross_check_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_cross_check_cross_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_cross_check_cross_check_id_seq OWNER TO postgres;

--
-- Name: sensor_cross_check_cross_check_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_cross_check_cross_check_id_seq OWNED BY sensor_cross_check.cross_check_id;


--
-- Name: sensor_group; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_group (
    sensor_group_id integer NOT NULL,
    sensor_group_name character varying(100) NOT NULL,
    display_order integer NOT NULL
);


ALTER TABLE qm.sensor_group OWNER TO postgres;

--
-- Name: sensor_group_sensor_group_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_group_sensor_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_group_sensor_group_id_seq OWNER TO postgres;

--
-- Name: sensor_group_sensor_group_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_group_sensor_group_id_seq OWNED BY sensor_group.sensor_group_id;


--
-- Name: sensor_identity; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_identity (
    sensor_id integer NOT NULL,
    stn_id integer NOT NULL,
    symbol character varying(100) NOT NULL,
    sensor_no integer DEFAULT 1 NOT NULL,
    lane_no integer DEFAULT 0 NOT NULL,
    codespace integer NOT NULL,
    sensor_master_id integer NOT NULL,
    creation_time timestamp without time zone DEFAULT now() NOT NULL,
    fault_ignore_until_time timestamp without time zone
);


ALTER TABLE qm.sensor_identity OWNER TO postgres;

--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_identity_sensor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_identity_sensor_id_seq OWNER TO postgres;

--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_identity_sensor_id_seq OWNED BY sensor_identity.sensor_id;


--
-- Name: sensor_master_identity; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_master_identity (
    sensor_master_id integer NOT NULL,
    symbol character varying(100) NOT NULL,
    codespace smallint NOT NULL,
    error_value integer,
    multiplier real DEFAULT 1 NOT NULL,
    complex_transform character varying(100),
    creation_date date DEFAULT now() NOT NULL,
    sensor_alias_id integer,
    monitored boolean DEFAULT true,
    fault_count_threshold smallint DEFAULT 1,
    error_value_string character varying(5),
    sensor_stuck_minutes integer DEFAULT 0,
    unit_of_measurement character varying(64),
    supported_forecast_symbol_id integer
);


ALTER TABLE qm.sensor_master_identity OWNER TO postgres;

--
-- Name: sensor_master_identity_sensor_master_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_master_identity_sensor_master_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_master_identity_sensor_master_id_seq OWNER TO postgres;

--
-- Name: sensor_master_identity_sensor_master_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_master_identity_sensor_master_id_seq OWNED BY sensor_master_identity.sensor_master_id;


--
-- Name: sensor_range_check; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_range_check (
    range_check_id integer NOT NULL,
    sensor_master_id integer NOT NULL,
    region_id integer,
    station_id integer,
    min_value real NOT NULL,
    max_value real NOT NULL,
    end_doy smallint DEFAULT 366 NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    start_doy integer DEFAULT 0 NOT NULL,
    inverted boolean DEFAULT false NOT NULL
);


ALTER TABLE qm.sensor_range_check OWNER TO postgres;

--
-- Name: sensor_range_check_range_check_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_range_check_range_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_range_check_range_check_id_seq OWNER TO postgres;

--
-- Name: sensor_range_check_range_check_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_range_check_range_check_id_seq OWNED BY sensor_range_check.range_check_id;


--
-- Name: sensor_step_check; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE sensor_step_check (
    step_check_id integer NOT NULL,
    sensor_master_id integer NOT NULL,
    region_id integer,
    station_id integer,
    step_value real NOT NULL,
    step_seconds integer NOT NULL,
    end_doy smallint DEFAULT 366 NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    start_doy integer DEFAULT 0 NOT NULL
);


ALTER TABLE qm.sensor_step_check OWNER TO postgres;

--
-- Name: sensor_step_check_step_check_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE sensor_step_check_step_check_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.sensor_step_check_step_check_id_seq OWNER TO postgres;

--
-- Name: sensor_step_check_step_check_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE sensor_step_check_step_check_id_seq OWNED BY sensor_step_check.step_check_id;


--
-- Name: station_alias; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_alias (
    stn_alias_id integer NOT NULL,
    v_region_id integer NOT NULL,
    stn_id integer NOT NULL,
    comments character varying(300),
    creation_date date DEFAULT now() NOT NULL,
    fault_detection_minutes smallint
);


ALTER TABLE qm.station_alias OWNER TO postgres;

--
-- Name: station_alias_identity_v_region_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_alias_identity_v_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_alias_identity_v_region_id_seq OWNER TO postgres;

--
-- Name: station_alias_identity_v_region_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_alias_identity_v_region_id_seq OWNED BY station_alias_identity.v_region_id;


--
-- Name: station_alias_monitored_sensor; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_alias_monitored_sensor (
    v_region_id integer NOT NULL,
    sensor_master_id integer NOT NULL
);


ALTER TABLE qm.station_alias_monitored_sensor OWNER TO postgres;

--
-- Name: station_alias_stn_alias_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_alias_stn_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_alias_stn_alias_id_seq OWNER TO postgres;

--
-- Name: station_alias_stn_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_alias_stn_alias_id_seq OWNED BY station_alias.stn_alias_id;


--
-- Name: station_forecast; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_forecast (
    station_id integer,
    forecast_provider_id integer
);


ALTER TABLE qm.station_forecast OWNER TO postgres;

--
-- Name: station_identity_stn_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_identity_stn_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_identity_stn_id_seq OWNER TO postgres;

--
-- Name: station_identity_stn_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_identity_stn_id_seq OWNED BY station_identity.stn_id;


--
-- Name: station_monitored_sensor; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_monitored_sensor (
    stn_id integer NOT NULL,
    sensor_master_id integer NOT NULL
);


ALTER TABLE qm.station_monitored_sensor OWNER TO postgres;

--
-- Name: station_note; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_note (
    station_note_id integer NOT NULL,
    station_id integer NOT NULL,
    station_note character varying(4096),
    station_note_time timestamp without time zone NOT NULL
);


ALTER TABLE qm.station_note OWNER TO postgres;

--
-- Name: station_note_station_note_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_note_station_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_note_station_note_id_seq OWNER TO postgres;

--
-- Name: station_note_station_note_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_note_station_note_id_seq OWNED BY station_note.station_note_id;


--
-- Name: station_url; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_url (
    station_url_id integer NOT NULL,
    url_name character varying(100) NOT NULL,
    url_location character varying(200) NOT NULL,
    comments character varying(300),
    stn_id integer NOT NULL,
    creation_date date DEFAULT now() NOT NULL
);


ALTER TABLE qm.station_url OWNER TO postgres;

--
-- Name: station_url_station_url_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_url_station_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_url_station_url_id_seq OWNER TO postgres;

--
-- Name: station_url_station_url_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_url_station_url_id_seq OWNED BY station_url.station_url_id;


--
-- Name: supported_forecast_symbol; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE supported_forecast_symbol (
    supported_forecast_symbol_id integer,
    symbol character varying(32)
);


ALTER TABLE qm.supported_forecast_symbol OWNER TO postgres;

SET search_path = qmfault, pg_catalog;

--
-- Name: fault_action; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault_action (
    fault_action_id integer NOT NULL,
    fault_action character varying(100)
);


ALTER TABLE qmfault.fault_action OWNER TO postgres;

--
-- Name: fault_action_fault_action_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_action_fault_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_action_fault_action_id_seq OWNER TO postgres;

--
-- Name: fault_action_fault_action_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_action_fault_action_id_seq OWNED BY fault_action.fault_action_id;


--
-- Name: fault_fault_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_fault_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_fault_id_seq OWNER TO postgres;

--
-- Name: fault_fault_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_fault_id_seq OWNED BY fault.fault_id;


--
-- Name: fault_history; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault_history (
    fault_history_id integer NOT NULL,
    fault_id integer NOT NULL,
    status smallint,
    create_time timestamp without time zone
);


ALTER TABLE qmfault.fault_history OWNER TO postgres;

--
-- Name: fault_history_fault_history_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_history_fault_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_history_fault_history_id_seq OWNER TO postgres;

--
-- Name: fault_history_fault_history_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_history_fault_history_id_seq OWNED BY fault_history.fault_history_id;


--
-- Name: fault_note; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault_note (
    fault_note_id integer NOT NULL,
    fault_id integer,
    fault_note character varying(4096),
    fault_note_time timestamp without time zone
);


ALTER TABLE qmfault.fault_note OWNER TO postgres;

--
-- Name: fault_note_fault_note_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_note_fault_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_note_fault_note_id_seq OWNER TO postgres;

--
-- Name: fault_note_fault_note_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_note_fault_note_id_seq OWNED BY fault_note.fault_note_id;


--
-- Name: fault_resp; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault_resp (
    fault_resp_id integer NOT NULL,
    fault_resp character varying(100)
);


ALTER TABLE qmfault.fault_resp OWNER TO postgres;

--
-- Name: fault_resp_fault_resp_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_resp_fault_resp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_resp_fault_resp_id_seq OWNER TO postgres;

--
-- Name: fault_resp_fault_resp_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_resp_fault_resp_id_seq OWNED BY fault_resp.fault_resp_id;


--
-- Name: fault_type; Type: TABLE; Schema: qmfault; Owner: postgres; Tablespace: 
--

CREATE TABLE fault_type (
    fault_type_id integer NOT NULL,
    fault_name character varying(100),
    error_code integer,
    time_buffer smallint
);


ALTER TABLE qmfault.fault_type OWNER TO postgres;

--
-- Name: fault_type_fault_type_id_seq; Type: SEQUENCE; Schema: qmfault; Owner: postgres
--

CREATE SEQUENCE fault_type_fault_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qmfault.fault_type_fault_type_id_seq OWNER TO postgres;

--
-- Name: fault_type_fault_type_id_seq; Type: SEQUENCE OWNED BY; Schema: qmfault; Owner: postgres
--

ALTER SEQUENCE fault_type_fault_type_id_seq OWNED BY fault_type.fault_type_id;


SET search_path = forecast, pg_catalog;

--
-- Name: forecast_id; Type: DEFAULT; Schema: forecast; Owner: postgres
--

ALTER TABLE ONLY forecast ALTER COLUMN forecast_id SET DEFAULT nextval('forecast_forecast_id_seq'::regclass);


--
-- Name: forecast_symbol_qc_id; Type: DEFAULT; Schema: forecast; Owner: postgres
--

ALTER TABLE ONLY forecast_symbol_qc ALTER COLUMN forecast_symbol_qc_id SET DEFAULT nextval('forecast_symbol_qc_forecast_symbol_qc_id_seq'::regclass);


--
-- Name: forecast_time_parameter_id; Type: DEFAULT; Schema: forecast; Owner: postgres
--

ALTER TABLE ONLY forecast_time_parameter ALTER COLUMN forecast_time_parameter_id SET DEFAULT nextval('forecast_time_parameter_forecast_time_parameter_id_seq'::regclass);


SET search_path = qm, pg_catalog;

--
-- Name: data_quality_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality ALTER COLUMN data_quality_id SET DEFAULT nextval('data_quality_data_quality_id_seq'::regclass);


--
-- Name: data_quality_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_02 ALTER COLUMN data_quality_id SET DEFAULT nextval('data_quality_data_quality_id_seq'::regclass);


--
-- Name: db_insertiontime; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_02 ALTER COLUMN db_insertiontime SET DEFAULT now();


--
-- Name: data_quality_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_09 ALTER COLUMN data_quality_id SET DEFAULT nextval('data_quality_data_quality_id_seq'::regclass);


--
-- Name: db_insertiontime; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_09 ALTER COLUMN db_insertiontime SET DEFAULT now();


--
-- Name: data_quality_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_16 ALTER COLUMN data_quality_id SET DEFAULT nextval('data_quality_data_quality_id_seq'::regclass);


--
-- Name: db_insertiontime; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_16 ALTER COLUMN db_insertiontime SET DEFAULT now();


--
-- Name: dqm_web_user_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY dqm_web_user ALTER COLUMN dqm_web_user_id SET DEFAULT nextval('dqm_web_user_dqm_web_user_id_seq'::regclass);


--
-- Name: pref_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY dqm_web_user_preference ALTER COLUMN pref_id SET DEFAULT nextval('dqm_web_user_preference_pref_id_seq'::regclass);


--
-- Name: dqm_web_user_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY dqm_web_user_preference_default ALTER COLUMN dqm_web_user_id SET DEFAULT nextval('dqm_web_user_preference_default_dqm_web_user_id_seq'::regclass);


--
-- Name: external_forecast_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY external_forecast ALTER COLUMN external_forecast_id SET DEFAULT nextval('external_forecast_external_forecast_id_seq'::regclass);


--
-- Name: external_forecast_alert_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY external_forecast_alert ALTER COLUMN external_forecast_alert_id SET DEFAULT nextval('external_forecast_alert_external_forecast_alert_id_seq'::regclass);


--
-- Name: external_forecast_alert_config_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY external_forecast_alert_config ALTER COLUMN external_forecast_alert_config_id SET DEFAULT nextval('external_forecast_alert_confi_external_forecast_alert_confi_seq'::regclass);


--
-- Name: external_forecast_variation_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY external_forecast_variation ALTER COLUMN external_forecast_variation_id SET DEFAULT nextval('external_forecast_variation_external_forecast_variation_id_seq'::regclass);


--
-- Name: forecast_provider_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY forecast_provider ALTER COLUMN forecast_provider_id SET DEFAULT nextval('forecast_provider_forecast_provider_id_seq'::regclass);


--
-- Name: geo_track_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY geo_track ALTER COLUMN geo_track_id SET DEFAULT nextval('geo_track_geo_track_id_seq'::regclass);


--
-- Name: last_reading_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY last_reading ALTER COLUMN last_reading_id SET DEFAULT nextval('last_reading_last_reading_id_seq'::regclass);


--
-- Name: region_note_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY region_note ALTER COLUMN region_note_id SET DEFAULT nextval('region_note_region_note_id_seq'::regclass);


--
-- Name: report_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY report ALTER COLUMN report_id SET DEFAULT nextval('report_report_id_seq'::regclass);


--
-- Name: report_definition_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY report_definition ALTER COLUMN report_definition_id SET DEFAULT nextval('report_definition_report_definition_id_seq'::regclass);


--
-- Name: sensor_alias_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_alias ALTER COLUMN sensor_alias_id SET DEFAULT nextval('sensor_alias_sensor_alias_id_seq'::regclass);


--
-- Name: cross_check_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_cross_check ALTER COLUMN cross_check_id SET DEFAULT nextval('sensor_cross_check_cross_check_id_seq'::regclass);


--
-- Name: sensor_group_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_group ALTER COLUMN sensor_group_id SET DEFAULT nextval('sensor_group_sensor_group_id_seq'::regclass);


--
-- Name: sensor_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_identity ALTER COLUMN sensor_id SET DEFAULT nextval('sensor_identity_sensor_id_seq'::regclass);


--
-- Name: sensor_master_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_master_identity ALTER COLUMN sensor_master_id SET DEFAULT nextval('sensor_master_identity_sensor_master_id_seq'::regclass);


--
-- Name: range_check_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_range_check ALTER COLUMN range_check_id SET DEFAULT nextval('sensor_range_check_range_check_id_seq'::regclass);


--
-- Name: step_check_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_step_check ALTER COLUMN step_check_id SET DEFAULT nextval('sensor_step_check_step_check_id_seq'::regclass);


--
-- Name: stn_alias_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias ALTER COLUMN stn_alias_id SET DEFAULT nextval('station_alias_stn_alias_id_seq'::regclass);


--
-- Name: v_region_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias_identity ALTER COLUMN v_region_id SET DEFAULT nextval('station_alias_identity_v_region_id_seq'::regclass);


--
-- Name: stn_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_identity ALTER COLUMN stn_id SET DEFAULT nextval('station_identity_stn_id_seq'::regclass);


--
-- Name: station_note_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_note ALTER COLUMN station_note_id SET DEFAULT nextval('station_note_station_note_id_seq'::regclass);


--
-- Name: station_url_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_url ALTER COLUMN station_url_id SET DEFAULT nextval('station_url_station_url_id_seq'::regclass);


SET search_path = qmfault, pg_catalog;

--
-- Name: fault_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault ALTER COLUMN fault_id SET DEFAULT nextval('fault_fault_id_seq'::regclass);


--
-- Name: fault_action_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault_action ALTER COLUMN fault_action_id SET DEFAULT nextval('fault_action_fault_action_id_seq'::regclass);


--
-- Name: fault_history_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault_history ALTER COLUMN fault_history_id SET DEFAULT nextval('fault_history_fault_history_id_seq'::regclass);


--
-- Name: fault_note_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault_note ALTER COLUMN fault_note_id SET DEFAULT nextval('fault_note_fault_note_id_seq'::regclass);


--
-- Name: fault_resp_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault_resp ALTER COLUMN fault_resp_id SET DEFAULT nextval('fault_resp_fault_resp_id_seq'::regclass);


--
-- Name: fault_type_id; Type: DEFAULT; Schema: qmfault; Owner: postgres
--

ALTER TABLE ONLY fault_type ALTER COLUMN fault_type_id SET DEFAULT nextval('fault_type_fault_type_id_seq'::regclass);


SET search_path = exportws, pg_catalog;

--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (vmdb_id, group_id);


--
-- Name: lanes_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lanes
    ADD CONSTRAINT lanes_pkey PRIMARY KEY (vmdb_id, data_number);


--
-- Name: permissions_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (username, region, role);


--
-- Name: pwdb_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pwdb
    ADD CONSTRAINT pwdb_pkey PRIMARY KEY (username);


--
-- Name: qttids_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qttids
    ADD CONSTRAINT qttids_pkey PRIMARY KEY (vmdb_id);


--
-- Name: qttids_qtt_id_key; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY qttids
    ADD CONSTRAINT qttids_qtt_id_key UNIQUE (qtt_id);


--
-- Name: sensorindex_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensorindex
    ADD CONSTRAINT sensorindex_pkey PRIMARY KEY (dqm_symbol);


--
-- Name: sensorindex_sensor_id_key; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensorindex
    ADD CONSTRAINT sensorindex_sensor_id_key UNIQUE (sensor_id);


--
-- Name: sensors_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT sensors_pkey PRIMARY KEY (vmdb_id, datex_id);


--
-- Name: stations_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stations
    ADD CONSTRAINT stations_pkey PRIMARY KEY (vmdb_id);


--
-- Name: xmltags_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY xmltags
    ADD CONSTRAINT xmltags_pkey PRIMARY KEY (data_symbol);


SET search_path = forecast, pg_catalog;

--
-- Name: forecast_symbol_qc.pk; Type: CONSTRAINT; Schema: forecast; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forecast_symbol_qc
    ADD CONSTRAINT "forecast_symbol_qc.pk" PRIMARY KEY (forecast_symbol_qc_id);


--
-- Name: issued_forecast.pk; Type: CONSTRAINT; Schema: forecast; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forecast
    ADD CONSTRAINT "issued_forecast.pk" PRIMARY KEY (forecast_id);


--
-- Name: issued_forecast_value.pk; Type: CONSTRAINT; Schema: forecast; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forecast_time_parameter
    ADD CONSTRAINT "issued_forecast_value.pk" PRIMARY KEY (forecast_time_parameter_id);


--
-- Name: schema_version_pk; Type: CONSTRAINT; Schema: forecast; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schema_version
    ADD CONSTRAINT schema_version_pk PRIMARY KEY (version);


SET search_path = public, pg_catalog;

--
-- Name: schema_version_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY schema_version
    ADD CONSTRAINT schema_version_pk PRIMARY KEY (version);


SET search_path = qm, pg_catalog;

--
-- Name: cam_image_list.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY cam_image_list
    ADD CONSTRAINT "cam_image_list.pk" PRIMARY KEY (station_id, camera_nbr, image_timestamp);


--
-- Name: data_quality2017_01_02_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY data_quality_2017_01_02
    ADD CONSTRAINT data_quality2017_01_02_pk PRIMARY KEY (data_quality_id);


--
-- Name: data_quality2017_01_09_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY data_quality_2017_01_09
    ADD CONSTRAINT data_quality2017_01_09_pk PRIMARY KEY (data_quality_id);


--
-- Name: data_quality2017_01_16_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY data_quality_2017_01_16
    ADD CONSTRAINT data_quality2017_01_16_pk PRIMARY KEY (data_quality_id);


--
-- Name: dq_data_quality_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY data_quality
    ADD CONSTRAINT "dq_data_quality_id.pk" PRIMARY KEY (data_quality_id);


--
-- Name: dv_creation_sensor_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY data_value
    ADD CONSTRAINT dv_creation_sensor_pk PRIMARY KEY (obs_creationtime, sensor_id);


--
-- Name: error_no_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY error_codes
    ADD CONSTRAINT error_no_pk PRIMARY KEY (error_number);


--
-- Name: external_forecast.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY external_forecast
    ADD CONSTRAINT "external_forecast.pk" PRIMARY KEY (external_forecast_id);


--
-- Name: external_forecast_alert_config_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY external_forecast_alert_config
    ADD CONSTRAINT "external_forecast_alert_config_id.pk" PRIMARY KEY (external_forecast_alert_config_id);


--
-- Name: external_forecast_alert_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY external_forecast_alert
    ADD CONSTRAINT "external_forecast_alert_id.pk" PRIMARY KEY (external_forecast_alert_id);


--
-- Name: external_forecast_variation_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY external_forecast_variation
    ADD CONSTRAINT "external_forecast_variation_id.pk" PRIMARY KEY (external_forecast_variation_id);


--
-- Name: geo_track_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY geo_track
    ADD CONSTRAINT geo_track_pk PRIMARY KEY (geo_track_id);


--
-- Name: lr_last_reading_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT lr_last_reading_pk PRIMARY KEY (last_reading_id);


--
-- Name: lr_unique_sen_id; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT lr_unique_sen_id UNIQUE (sensor_id);


--
-- Name: mi_sensor_codespace_unique; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_master_identity
    ADD CONSTRAINT mi_sensor_codespace_unique UNIQUE (symbol, codespace);


--
-- Name: qm.dqm_web_user.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dqm_web_user
    ADD CONSTRAINT "qm.dqm_web_user.pk" PRIMARY KEY (dqm_web_user_id);


--
-- Name: qm.dqm_web_user_preference.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY dqm_web_user_preference
    ADD CONSTRAINT "qm.dqm_web_user_preference.pk" PRIMARY KEY (pref_id);


--
-- Name: qm.region_note.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY region_note
    ADD CONSTRAINT "qm.region_note.pk" PRIMARY KEY (region_note_id);


--
-- Name: qm.station_note.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_note
    ADD CONSTRAINT "qm.station_note.pk" PRIMARY KEY (station_note_id);


--
-- Name: rc_master_region_station_edoy_unique; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_range_check
    ADD CONSTRAINT rc_master_region_station_edoy_unique UNIQUE (sensor_master_id, region_id, station_id, end_doy);


--
-- Name: report_definition_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY report_definition
    ADD CONSTRAINT "report_definition_id.pk" PRIMARY KEY (report_definition_id);


--
-- Name: report_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY report
    ADD CONSTRAINT "report_id.pk" PRIMARY KEY (report_id);


--
-- Name: rollup_camera_performance.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rollup_camera_performance
    ADD CONSTRAINT "rollup_camera_performance.pk" PRIMARY KEY (image_date, station_id);


--
-- Name: rollup_network_performance.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rollup_network_performance
    ADD CONSTRAINT "rollup_network_performance.pk" PRIMARY KEY (message_date, stn_id);


--
-- Name: rollup_parameter_performance.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY rollup_parameter_performance
    ADD CONSTRAINT "rollup_parameter_performance.pk" PRIMARY KEY (obs_creationtime, stn_id, sensor_id);


--
-- Name: sa_region_station_unique; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT sa_region_station_unique UNIQUE (stn_id, v_region_id);


--
-- Name: sa_stn_alias_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT "sa_stn_alias_id.pk" PRIMARY KEY (stn_alias_id);


--
-- Name: sai_v_region_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias_identity
    ADD CONSTRAINT "sai_v_region_id.pk" PRIMARY KEY (v_region_id);


--
-- Name: sc_sensor_master_region_station_edoy_key; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_step_check
    ADD CONSTRAINT sc_sensor_master_region_station_edoy_key UNIQUE (sensor_master_id, region_id, station_id, end_doy);


--
-- Name: scc_cross_check_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_cross_check
    ADD CONSTRAINT "scc_cross_check_id.pk" PRIMARY KEY (cross_check_id);


--
-- Name: sensor_alias_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_alias
    ADD CONSTRAINT sensor_alias_pkey PRIMARY KEY (sensor_alias_id);


--
-- Name: sensor_group_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_group
    ADD CONSTRAINT sensor_group_pkey PRIMARY KEY (sensor_group_id);


--
-- Name: sensor_master_identity_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_master_identity
    ADD CONSTRAINT sensor_master_identity_pkey PRIMARY KEY (sensor_master_id);


--
-- Name: sensor_range_check_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_range_check
    ADD CONSTRAINT sensor_range_check_pkey PRIMARY KEY (range_check_id);


--
-- Name: sensor_step_check_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_step_check
    ADD CONSTRAINT sensor_step_check_pkey PRIMARY KEY (step_check_id);


--
-- Name: si_sensor_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT "si_sensor_id.pk" PRIMARY KEY (sensor_id);


--
-- Name: si_unique_stn_id_symbol_sen_no; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT si_unique_stn_id_symbol_sen_no UNIQUE (stn_id, symbol, sensor_no, codespace);


--
-- Name: station_alias_monitored_sensor.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias_monitored_sensor
    ADD CONSTRAINT "station_alias_monitored_sensor.pk" PRIMARY KEY (v_region_id, sensor_master_id);


--
-- Name: station_identity_stn_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_identity
    ADD CONSTRAINT "station_identity_stn_id.pk" PRIMARY KEY (stn_id);


--
-- Name: station_monitored_sensor.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_monitored_sensor
    ADD CONSTRAINT "station_monitored_sensor.pk" PRIMARY KEY (stn_id, sensor_master_id);


--
-- Name: stn_identity_xml_name; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_identity
    ADD CONSTRAINT stn_identity_xml_name UNIQUE (xml_target_name);


--
-- Name: su_station_url_id.pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_url
    ADD CONSTRAINT "su_station_url_id.pk" PRIMARY KEY (station_url_id);


SET search_path = qmfault, pg_catalog;

--
-- Name: fault.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault
    ADD CONSTRAINT "fault.pk" PRIMARY KEY (fault_id);


--
-- Name: fault_action.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault_action
    ADD CONSTRAINT "fault_action.pk" PRIMARY KEY (fault_action_id);


--
-- Name: fault_history.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault_history
    ADD CONSTRAINT "fault_history.pk" PRIMARY KEY (fault_history_id);


--
-- Name: fault_note.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault_note
    ADD CONSTRAINT "fault_note.pk" PRIMARY KEY (fault_note_id);


--
-- Name: fault_resp.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault_resp
    ADD CONSTRAINT "fault_resp.pk" PRIMARY KEY (fault_resp_id);


--
-- Name: fault_type.pk; Type: CONSTRAINT; Schema: qmfault; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fault_type
    ADD CONSTRAINT "fault_type.pk" PRIMARY KEY (fault_type_id);


SET search_path = forecast, pg_catalog;

--
-- Name: forecast_issue_time; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX forecast_issue_time ON forecast USING btree (forecast_issue_time);


--
-- Name: forecast_provider; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX forecast_provider ON forecast USING btree (forecast_provider);


--
-- Name: forecast_provider_issue_time; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX forecast_provider_issue_time ON forecast USING btree (forecast_provider, forecast_issue_time);


--
-- Name: schema_version_ir_idx; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_ir_idx ON schema_version USING btree (installed_rank);


--
-- Name: schema_version_s_idx; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_s_idx ON schema_version USING btree (success);


--
-- Name: schema_version_vr_idx; Type: INDEX; Schema: forecast; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_vr_idx ON schema_version USING btree (version_rank);


SET search_path = public, pg_catalog;

--
-- Name: schema_version_ir_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_ir_idx ON schema_version USING btree (installed_rank);


--
-- Name: schema_version_s_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_s_idx ON schema_version USING btree (success);


--
-- Name: schema_version_vr_idx; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX schema_version_vr_idx ON schema_version USING btree (version_rank);


SET search_path = qm, pg_catalog;

--
-- Name: data_quality_2017_01_02_insertiontime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_02_insertiontime_idx ON data_quality_2017_01_02 USING btree (db_insertiontime);


--
-- Name: data_quality_2017_01_02_obs_creationtime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_02_obs_creationtime_idx ON data_quality_2017_01_02 USING btree (obs_creationtime);


--
-- Name: data_quality_2017_01_02_sensor_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_02_sensor_idx ON data_quality_2017_01_02 USING btree (sensor_id);


--
-- Name: data_quality_2017_01_09_insertiontime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_09_insertiontime_idx ON data_quality_2017_01_09 USING btree (db_insertiontime);


--
-- Name: data_quality_2017_01_09_obs_creationtime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_09_obs_creationtime_idx ON data_quality_2017_01_09 USING btree (obs_creationtime);


--
-- Name: data_quality_2017_01_09_sensor_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_09_sensor_idx ON data_quality_2017_01_09 USING btree (sensor_id);


--
-- Name: data_quality_2017_01_16_insertiontime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_16_insertiontime_idx ON data_quality_2017_01_16 USING btree (db_insertiontime);


--
-- Name: data_quality_2017_01_16_obs_creationtime_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_16_obs_creationtime_idx ON data_quality_2017_01_16 USING btree (obs_creationtime);


--
-- Name: data_quality_2017_01_16_sensor_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX data_quality_2017_01_16_sensor_idx ON data_quality_2017_01_16 USING btree (sensor_id);


--
-- Name: efv_fcid_stnid_smid_obstime; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX efv_fcid_stnid_smid_obstime ON external_forecast_variation USING btree (external_forecast_id, station_id, sensor_master_id, obs_creation_time);


--
-- Name: external_forecast_variation_ext_forecast_data_value; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX external_forecast_variation_ext_forecast_data_value ON external_forecast_variation USING btree (external_forecast_id, sensor_master_id, obs_creation_time);


--
-- Name: geo_track_geom_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX geo_track_geom_idx ON geo_track USING gist (geom);


--
-- Name: geo_track_lat_lon_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX geo_track_lat_lon_idx ON geo_track USING btree (lat, lon);


--
-- Name: geo_track_mes_time_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX geo_track_mes_time_idx ON geo_track USING btree (mes_datetime);


--
-- Name: geom_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX geom_idx ON station_identity USING gist (geom);


--
-- Name: rollup_parameter_sensor_master; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX rollup_parameter_sensor_master ON rollup_parameter_performance USING btree (obs_creationtime, stn_id, sensor_master_id);


--
-- Name: si_sensor_master_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX si_sensor_master_id_idx ON sensor_identity USING btree (sensor_master_id);


--
-- Name: si_stn_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX si_stn_id_idx ON sensor_identity USING btree (stn_id);


--
-- Name: si_symbol_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX si_symbol_idx ON sensor_identity USING btree (symbol);


--
-- Name: sitn_identity_owning_region_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX sitn_identity_owning_region_idx ON station_identity USING btree (owning_region_id);


--
-- Name: sm_symbol; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX sm_symbol ON sensor_master_identity USING btree (symbol);


--
-- Name: sm_ucase_symbol; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX sm_ucase_symbol ON sensor_master_identity USING btree (upper((symbol)::text));


--
-- Name: stn_identity_xml_name_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX stn_identity_xml_name_idx ON station_identity USING btree (xml_target_name);


--
-- Name: symbol_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX symbol_idx ON sensor_master_identity USING btree (symbol);


SET search_path = forecast, pg_catalog;

--
-- Name: forecast_insert_trigger; Type: TRIGGER; Schema: forecast; Owner: postgres
--

CREATE TRIGGER forecast_insert_trigger BEFORE INSERT ON forecast FOR EACH ROW EXECUTE PROCEDURE forecast_insert_trigger_func();


SET search_path = qm, pg_catalog;

--
-- Name: data_quality_insert_trigger; Type: TRIGGER; Schema: qm; Owner: postgres
--

CREATE TRIGGER data_quality_insert_trigger BEFORE INSERT ON data_quality FOR EACH ROW EXECUTE PROCEDURE data_quality_insert_trigger_func();


--
-- Name: data_value_insert_trigger; Type: TRIGGER; Schema: qm; Owner: postgres
--

CREATE TRIGGER data_value_insert_trigger BEFORE INSERT ON data_value FOR EACH ROW EXECUTE PROCEDURE data_insert_trigger_func();


--
-- Name: external_forecast_insert_trigger; Type: TRIGGER; Schema: qm; Owner: postgres
--

CREATE TRIGGER external_forecast_insert_trigger BEFORE INSERT ON external_forecast FOR EACH ROW EXECUTE PROCEDURE external_forecast_insert_trigger_func();


SET search_path = qmfault, pg_catalog;

--
-- Name: fault_update; Type: TRIGGER; Schema: qmfault; Owner: postgres
--

CREATE TRIGGER fault_update AFTER INSERT OR UPDATE ON fault FOR EACH ROW EXECUTE PROCEDURE processfaultupdate();


SET search_path = exportws, pg_catalog;

--
-- Name: permissions_user_fkey; Type: FK CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_user_fkey FOREIGN KEY (username) REFERENCES pwdb(username);


SET search_path = qm, pg_catalog;

--
-- Name: data_quality_creation_sensor_2017_01_02_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_02
    ADD CONSTRAINT data_quality_creation_sensor_2017_01_02_fk FOREIGN KEY (obs_creationtime, sensor_id) REFERENCES data_value_2017_01_02(obs_creationtime, sensor_id);


--
-- Name: data_quality_creation_sensor_2017_01_09_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_09
    ADD CONSTRAINT data_quality_creation_sensor_2017_01_09_fk FOREIGN KEY (obs_creationtime, sensor_id) REFERENCES data_value_2017_01_09(obs_creationtime, sensor_id);


--
-- Name: data_quality_creation_sensor_2017_01_16_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality_2017_01_16
    ADD CONSTRAINT data_quality_creation_sensor_2017_01_16_fk FOREIGN KEY (obs_creationtime, sensor_id) REFERENCES data_value_2017_01_16(obs_creationtime, sensor_id);


--
-- Name: dq_creation_sensor_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_quality
    ADD CONSTRAINT dq_creation_sensor_fk FOREIGN KEY (obs_creationtime, sensor_id) REFERENCES data_value(obs_creationtime, sensor_id);


--
-- Name: dv_sensor_id_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY data_value
    ADD CONSTRAINT dv_sensor_id_fk FOREIGN KEY (sensor_id) REFERENCES sensor_identity(sensor_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: region_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY region_note
    ADD CONSTRAINT region_id_fkey FOREIGN KEY (region_id) REFERENCES station_alias_identity(v_region_id) ON DELETE CASCADE;


--
-- Name: sa_stn_id.fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT "sa_stn_id.fk" FOREIGN KEY (stn_id) REFERENCES station_identity(stn_id);


--
-- Name: sa_v_region_id.fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT "sa_v_region_id.fk" FOREIGN KEY (v_region_id) REFERENCES station_alias_identity(v_region_id);


--
-- Name: scc_region_id_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_cross_check
    ADD CONSTRAINT scc_region_id_fk FOREIGN KEY (region_id) REFERENCES station_alias_identity(v_region_id);


--
-- Name: scc_sensor_master_id_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_cross_check
    ADD CONSTRAINT scc_sensor_master_id_fk FOREIGN KEY (sensor_master_id) REFERENCES sensor_master_identity(sensor_master_id);


--
-- Name: scc_station_id_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_cross_check
    ADD CONSTRAINT scc_station_id_fk FOREIGN KEY (station_id) REFERENCES station_identity(stn_id);


--
-- Name: sensor_group_group_id; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_alias
    ADD CONSTRAINT sensor_group_group_id FOREIGN KEY (sensor_group_id) REFERENCES sensor_group(sensor_group_id) ON DELETE CASCADE;


--
-- Name: sensor_range_check_region_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_range_check
    ADD CONSTRAINT sensor_range_check_region_id_fkey FOREIGN KEY (region_id) REFERENCES station_alias_identity(v_region_id) ON DELETE CASCADE;


--
-- Name: sensor_range_check_sensor_master_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_range_check
    ADD CONSTRAINT sensor_range_check_sensor_master_id_fkey FOREIGN KEY (sensor_master_id) REFERENCES sensor_master_identity(sensor_master_id) ON DELETE CASCADE;


--
-- Name: sensor_range_check_station_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_range_check
    ADD CONSTRAINT sensor_range_check_station_id_fkey FOREIGN KEY (station_id) REFERENCES station_identity(stn_id) ON DELETE CASCADE;


--
-- Name: sensor_step_check_region_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_step_check
    ADD CONSTRAINT sensor_step_check_region_id_fkey FOREIGN KEY (region_id) REFERENCES station_alias_identity(v_region_id) ON DELETE CASCADE;


--
-- Name: sensor_step_check_sensor_master_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_step_check
    ADD CONSTRAINT sensor_step_check_sensor_master_id_fkey FOREIGN KEY (sensor_master_id) REFERENCES sensor_master_identity(sensor_master_id) ON DELETE CASCADE;


--
-- Name: sensor_step_check_station_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_step_check
    ADD CONSTRAINT sensor_step_check_station_id_fkey FOREIGN KEY (station_id) REFERENCES station_identity(stn_id) ON DELETE CASCADE;


--
-- Name: si_sensor_master_id_fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT si_sensor_master_id_fk FOREIGN KEY (sensor_master_id) REFERENCES sensor_master_identity(sensor_master_id);


--
-- Name: si_stn_id.fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT "si_stn_id.fk" FOREIGN KEY (stn_id) REFERENCES station_identity(stn_id);


--
-- Name: station_id_fkey; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_note
    ADD CONSTRAINT station_id_fkey FOREIGN KEY (station_id) REFERENCES station_identity(stn_id) ON DELETE CASCADE;


--
-- Name: su_stn_id.fk; Type: FK CONSTRAINT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_url
    ADD CONSTRAINT "su_stn_id.fk" FOREIGN KEY (stn_id) REFERENCES station_identity(stn_id);


--
-- Name: exportws; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA exportws FROM PUBLIC;
REVOKE ALL ON SCHEMA exportws FROM postgres;
GRANT ALL ON SCHEMA exportws TO postgres;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


SET search_path = exportws, pg_catalog;

--
-- Name: groups; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM postgres;
GRANT ALL ON TABLE groups TO postgres;


--
-- Name: lanes; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE lanes FROM PUBLIC;
REVOKE ALL ON TABLE lanes FROM postgres;
GRANT ALL ON TABLE lanes TO postgres;


--
-- Name: permissions; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE permissions FROM PUBLIC;
REVOKE ALL ON TABLE permissions FROM postgres;
GRANT ALL ON TABLE permissions TO postgres;


--
-- Name: pwdb; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE pwdb FROM PUBLIC;
REVOKE ALL ON TABLE pwdb FROM postgres;
GRANT ALL ON TABLE pwdb TO postgres;


--
-- Name: qttids; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE qttids FROM PUBLIC;
REVOKE ALL ON TABLE qttids FROM postgres;
GRANT ALL ON TABLE qttids TO postgres;


--
-- Name: sensorindex; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE sensorindex FROM PUBLIC;
REVOKE ALL ON TABLE sensorindex FROM postgres;
GRANT ALL ON TABLE sensorindex TO postgres;


--
-- Name: sensors; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE sensors FROM PUBLIC;
REVOKE ALL ON TABLE sensors FROM postgres;
GRANT ALL ON TABLE sensors TO postgres;


--
-- Name: stations; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE stations FROM PUBLIC;
REVOKE ALL ON TABLE stations FROM postgres;
GRANT ALL ON TABLE stations TO postgres;


--
-- Name: xmltags; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE xmltags FROM PUBLIC;
REVOKE ALL ON TABLE xmltags FROM postgres;
GRANT ALL ON TABLE xmltags TO postgres;


SET search_path = qm, pg_catalog;

--
-- Name: data_value; Type: ACL; Schema: qm; Owner: postgres
--

REVOKE ALL ON TABLE data_value FROM PUBLIC;
REVOKE ALL ON TABLE data_value FROM postgres;
GRANT ALL ON TABLE data_value TO postgres;



--
-- PostgreSQL database dump complete
--

