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
-- Name: oe; Type: SCHEMA; Schema: -; Owner: cloud
--

CREATE SCHEMA oe;


ALTER SCHEMA oe OWNER TO cloud;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: adminpack; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION adminpack; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


SET search_path = oe, pg_catalog;

--
-- Name: general_value1; Type: TYPE; Schema: oe; Owner: postgres
--

CREATE TYPE general_value1 AS (
	obs_time timestamp without time zone,
	symbol text,
	obs_value double precision,
	sensor_no integer
);


ALTER TYPE oe.general_value1 OWNER TO postgres;

--
-- Name: 131108_run_upsert_queries(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION "131108_run_upsert_queries"(stnid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE 
  cs integer:= -1;
  station text;
  mytime timestamp without time zone;
  AirT numeric;
  RH1 numeric;
  WS numeric;
  WD numeric;
  ST1 numeric;
  SS1 numeric;
  SpST numeric;
  SpSS numeric;
  STATUS integer;
  ACCUM integer:= 0;
BEGIN
 select codespace into cs
 from oe.new_last_reading
 where stn_id = stnid;
 
if cs is null then
-- NTCIP values
 --RAISE NOTICE '(Null Detected) codespace(%)', cs;
 
 select xml_target_name into station
 from oe.station_identity
 where stn_id = stnid;
 --RAISE NOTICE 'xml_target_name(%)', station;

 select codespace into cs
 from oe.sensor_identity
 where stn_id = stnid
 limit 1;
 --RAISE NOTICE 'codespace(%)', cs;

 insert into oe.new_last_reading (stn_id,station_name,codespace,last_datetime)
 values (stnid,station,cs,now());
 end if;


 if cs = 0 then
 --M14 Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;
  
  select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '01'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '02'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '05'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '06'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '30'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime
  --and  si.symbol = '60' 
  and  si.symbol = '61'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
   
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
--               , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    ess_surf_status = SS1,
    Spectro_surf_temp = SpST,
    spectro_surf_status = SpSS,
    status = ACCUM
 WHERE
    stn_id = stnid; 


 
 elsif cs = 1 then
 --M16 Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;
  
  select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '01'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '02'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '05'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '06'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '30'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '60'
 -- and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '66'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
   
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
--               , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    ess_surf_status = SS1,
    Spectro_surf_temp = SpST,
    spectro_surf_status = SpSS,
    status = ACCUM
 WHERE
    stn_id = stnid; 

 elsif cs = 8 then
 --NTCIP Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;

    select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAirTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essRelativeHumidity.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAvgWindSpeed.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAvgWindDirection.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essSurfaceTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essSurfaceStatus.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'spectroSurfaceTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'spectroSurfaceStatus.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
   
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
 --              , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    ess_surf_status = SS1,
    Spectro_surf_temp = SpST,
    spectro_surf_status = SpSS,
    status = ACCUM
 WHERE
    stn_id = stnid;                   
   
 end if;

 
end
$$;


ALTER FUNCTION oe."131108_run_upsert_queries"(stnid integer) OWNER TO cloud;

--
-- Name: 131128_run_upsert_queries(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION "131128_run_upsert_queries"(stnid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE 
  cs integer:= -1;
  station text;
  mytime timestamp without time zone;
  AirT numeric;
  RH1 numeric;
  WS numeric;
  WD numeric;
  ST1 numeric;
  SS1 numeric;
  SS1_S int;
  SS1_OUT numeric;
  SpST numeric;
  SpSS numeric;
  SpSS_OUT numeric;
  STATUS integer;
  ACCUM integer:= 0;
BEGIN
 select codespace into cs
 from oe.new_last_reading
 where stn_id = stnid;
 
if cs is null then
-- NTCIP values
 --RAISE NOTICE '(Null Detected) codespace(%)', cs;
 
 select xml_target_name into station
 from oe.station_identity
 where stn_id = stnid;
 --RAISE NOTICE 'xml_target_name(%)', station;

 select codespace into cs
 from oe.sensor_identity
 where stn_id = stnid
 limit 1;
 --RAISE NOTICE 'codespace(%)', cs;

 insert into oe.new_last_reading (stn_id,station_name,codespace,last_datetime)
 values (stnid,station,cs,now());
 end if;


 if cs < 2 then
 --M14 / M16 Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;
  
  select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '01'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '02'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '05'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '06'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '30'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN 
    ACCUM=ACCUM+STATUS; 
    SS1_S = mod(SS1,10);
    CASE Round(SS1_S)
       WHEN 0 THEN SS1_OUT = 2; -- Error
       WHEN 1 THEN SS1_OUT = 3; -- Dry
       WHEN 2 THEN SS1_OUT = 4; -- Moist
       WHEN 3 THEN SS1_OUT = 5; -- Wet
       WHEN 4 THEN SS1_OUT = 6; -- Wet and Chemical
       WHEN 5 THEN SS1_OUT = 13; -- Frosty
       WHEN 6 THEN SS1_OUT = 10; -- Snow Watch
       WHEN 7 THEN SS1_OUT = 8; -- Ice Watch
       WHEN 8 THEN SS1_OUT = 6; -- Wet and Chemical
       WHEN 9 THEN SS1_OUT = 1; -- other
       ELSE SS1_OUT = 1; -- other
    END CASE;
    

  END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime
  --and  si.symbol = '60' 
  and  si.symbol = '61'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '66'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN 
    ACCUM=ACCUM+STATUS;
    CASE Round(SpSS)
       WHEN 4 THEN SpSS_OUT = 0;
       WHEN 5 THEN SpSS_OUT = 301; -- frostWarning
       WHEN 8 THEN SpSS_OUT = 0;
       ELSE SpSS_OUT = SpSS;
    END CASE;

  END IF;
  
   
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
--               , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    --ess_surf_status = SS1,
    ess_surf_status = SS1_OUT,
    Spectro_surf_temp = SpST,
    --spectro_surf_status = SpSS,
    spectro_surf_status = SpSS_OUT, 
    status = ACCUM
 WHERE
    stn_id = stnid; 

 end if;

 
end
$$;


ALTER FUNCTION oe."131128_run_upsert_queries"(stnid integer) OWNER TO cloud;

--
-- Name: data_insert_trigger_func(); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION data_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare


    last3_d date 		:= date_trunc('day', now() - '3 day'::interval);
    last2_d date 		:= date_trunc('day', now() - '2 day'::interval);
    last1_d date 		:= date_trunc('day', now() - '1 day'::interval);
    cur_d date 			:= date_trunc('day', now());      
    plus1_d date 		:= date_trunc('day', now() + '1 day'::interval);
    plus2_d date 		:= date_trunc('day', now() + '2 day'::interval);

    
    cur_file text;

BEGIN
        IF ( NEW.creationtime >= cur_d AND NEW.creationtime < plus1_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(cur_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW; 
	ELSIF ( NEW.creationtime >= plus1_d AND NEW.creationtime < plus2_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(plus1_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;		
			
	ELSIF ( NEW.creationtime >= last1_d AND NEW.creationtime < cur_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(last1_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;				
	ELSIF ( NEW.creationtime >= last2_d AND NEW.creationtime < last1_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(last2_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;
	ELSIF ( NEW.creationtime >= last3_d AND NEW.creationtime < last2_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(last3_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;				
						
		
	ELSE
		RAISE EXCEPTION 'Date out of range.  Something wrong with the data_value_insert_trigger_func() function!';
	END IF;
	RETURN NULL;
END;
$_$;


ALTER FUNCTION oe.data_insert_trigger_func() OWNER TO cloud;

--
-- Name: general_dv_func1(text, text, text, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) RETURNS SETOF general_value1
    LANGUAGE sql
    AS $$
select dv.creationtime, si.symbol, dv.nvalue, dv.sensor_no

            from oe.station_alias     sa, 
                 oe.user_identity     ui, 
                 oe.sensor_identity   si, 
                 oe.data_value        dv,
                 oe.station_identity  st
            
where st.station_name = 'first test station'
and si.stn_id = st.stn_id
and dv.sensor_id = si.sensor_id
and ui.login_name='BJT'
and ui.password='user1'
and ui.group_id = sa.group_id
and dv.creationtime between '2013-03-14 12:09:00' and '2013-03-14 12:10:00'
and dv.status = 0
order by dv.creationtime;

$$;


ALTER FUNCTION oe.general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) OWNER TO cloud;

--
-- Name: get_codespace(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION get_codespace(stnid integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
  DECLARE 
    myInt integer;
  begin
  select si.codespace into myInt 
  from oe.station_identity st, oe.sensor_identity si
  where st.stn_id = stnid
  and si.stn_id = st.stn_id
  limit 1;
  return myInt;
  end
  $$;


ALTER FUNCTION oe.get_codespace(stnid integer) OWNER TO cloud;

--
-- Name: manage_partitions(); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION manage_partitions() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	old_partition text;
	new_partition text;
	old_date date := current_date - '2 day'::interval;
	new_date date := current_date + '2 days'::interval;
BEGIN
  begin
-- simple function to drop old partition 
-- and create new future partition March 2014 BJT

   old_partition := 'oe.data_value_' || TO_CHAR( old_date, 'YYYY_MM_DD');
   -- RAISE NOTICE 'Old Patition %',old_partition;
   execute 'DROP TABLE ' ||  old_partition;

   exception when others then
     RAISE NOTICE 'Table % does not exist',old_partition;   
  end;   
  begin
    new_partition := TO_CHAR( new_date, 'YYYY-MM-DD');
   -- RAISE NOTICE 'New Partition %',new_partition;
    execute 'SELECT oe.new_creation_day(''' ||  new_partition || ''',''' || new_partition || ''')' ;

   exception when others then
     RAISE NOTICE 'Table % already exists',new_partition;   
  end;
   analyse;
   RAISE NOTICE 'Analyse completed'; 
END;
$$;


ALTER FUNCTION oe.manage_partitions() OWNER TO cloud;

--
-- Name: new_creation_day(date, date); Type: FUNCTION; Schema: oe; Owner: madiswrite
--

CREATE FUNCTION new_creation_day(date, date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	create_query text;
	index_query text;
	index_query2 text;
	index_query3 text;
BEGIN
	FOR create_query, index_query, index_query2, index_query3 IN SELECT
			'create table oe.data_value_' || TO_CHAR( d, 'YYYY_MM_DD' )
			
	--		|| ' ( CONSTRAINT no_duplicates_' 
	--		|| TO_CHAR( d, 'YYYY_MM_DD' )
	--		|| ' UNIQUE (stn_id,creationtime),
						
			||  ' ( CONSTRAINT data_value_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_pk'
			|| ' PRIMARY KEY (creationtime,sensor_id),'
			|| '  check( creationtime >= date '''
			
			|| TO_CHAR( d, 'YYYY-MM-DD' )
			|| ''' and creationtime < date '''
			|| TO_CHAR( d + INTERVAL '1 day', 'YYYY-MM-DD' )
			|| ''' ) ) inherits ( oe.data_value );' 
			|| ' ALTER TABLE oe.data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' ) 
			|| ' OWNER TO cloud',
			
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_station_idx on oe.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( stn_id);',
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_created_idx on oe.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (created DESC NULLS LAST);',
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_sensor_idx on oe.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (sensor_id) ;'

			
   		FROM generate_series( $1, $2, '1 day' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
		EXECUTE index_query3;
	END LOOP;
END;
$_$;


ALTER FUNCTION oe.new_creation_day(date, date) OWNER TO madiswrite;

--
-- Name: new_creation_week(date, date); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION new_creation_week(date, date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	create_query text;
	index_query text;
	index_query2 text;
BEGIN
	FOR create_query, index_query, index_query2 IN SELECT
			'create table oe.data_value_' || TO_CHAR( d, 'YYYY_MM_DD' )
			
	--		|| ' ( CONSTRAINT no_duplicates_' 
	--		|| TO_CHAR( d, 'YYYY_MM_DD' )
	--		|| ' UNIQUE (stn_id,creationtime),
						
			||  ' ( CONSTRAINT data_value_' || TO_CHAR( d, 'YYYY_MM_DD' ) || '_pk'
			|| ' PRIMARY KEY (creationtime,sensor_id),'
			|| '  check( creationtime >= date '''
			
			|| TO_CHAR( d, 'YYYY-MM-DD' )
			|| ''' and creationtime < date '''
			|| TO_CHAR( d + INTERVAL '1 week', 'YYYY-MM-DD' )
			|| ''' ) ) inherits ( oe.data_value );' 
			|| ' ALTER TABLE oe.data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' ) 
			|| ' OWNER TO cloud',
			
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_station_idx on oe.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( stn_id);',
			'create index data_value_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_sensor_idx on oe.data_value_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (sensor_id) ;'

			
   		FROM generate_series( $1, $2, '1 week' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
	END LOOP;
END;
$_$;


ALTER FUNCTION oe.new_creation_week(date, date) OWNER TO cloud;

--
-- Name: old_run_upsert_queries(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION old_run_upsert_queries(stnid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE cs integer:= -1;
BEGIN
 select oe.get_codespace(stnid) into cs;
 --RAISE NOTICE 'codespace(%)', cs;
if cs = 8 then
-- NTCIP values
    perform oe.reset_last_reading_status(stnid);
    perform oe.upsert_val1(stnid);
    perform oe.upsert_val2(stnid);
    perform oe.upsert_val3(stnid);  
    perform oe.upsert_val4(stnid);
    perform oe.upsert_val5(stnid);
    perform oe.upsert_val6(stnid);
    perform oe.upsert_val7(stnid);
    perform oe.upsert_val8(stnid);
 elsif cs < 2 then
 --M14/16 Values
    perform oe.reset_last_reading_status(stnid);
    perform oe.upsert_val1_a(stnid);
    perform oe.upsert_val2_a(stnid); 
    perform oe.upsert_val3_a(stnid); 
    perform oe.upsert_val4_a(stnid); 
    perform oe.upsert_val5_a(stnid); 
    perform oe.upsert_val6_a(stnid);  
    perform oe.upsert_val7_a(stnid);  
    perform oe.upsert_val8_a(stnid);      
 end if;
end
$$;


ALTER FUNCTION oe.old_run_upsert_queries(stnid integer) OWNER TO cloud;

--
-- Name: reset_last_reading_status(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION reset_last_reading_status(stnid integer) RETURNS void
    LANGUAGE sql STRICT
    AS $$
  update oe.last_reading set status = 0 -- change to equal the upsert queries
  where stn_id = stnid;
$$;


ALTER FUNCTION oe.reset_last_reading_status(stnid integer) OWNER TO cloud;

--
-- Name: run_upsert_queries(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION run_upsert_queries(stnid integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE 
  cs integer:= -1;
  station text;
  mytime timestamp without time zone;
  AirT numeric;
  RH1 numeric;
  WS numeric;
  WD numeric;
  ST1 numeric;
  SS1 numeric;
  SS1_S numeric;
  SS1_OUT numeric;
  SpST numeric;
  SpSS numeric;
  SpGR numeric;
  SpSS_OUT numeric;
  STATUS integer;
  ACCUM integer:= 0;
BEGIN
 select codespace into cs
 from oe.new_last_reading
 where stn_id = stnid;
 
if cs is null then
-- NTCIP values
 --RAISE NOTICE '(Null Detected) codespace(%)', cs;
 
 select xml_target_name into station
 from oe.station_identity
 where stn_id = stnid;
 --RAISE NOTICE 'xml_target_name(%)', station;

 select codespace into cs
 from oe.sensor_identity
 where stn_id = stnid
 limit 1;
 --RAISE NOTICE 'codespace(%)', cs;

 insert into oe.new_last_reading (stn_id,station_name,codespace,last_datetime)
 values (stnid,station,cs,now());
 end if;


 if cs < 2 then
 --M14 / M16 Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;
  
  select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '01'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '02'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '05'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '06'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '30'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '36'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN 
    ACCUM=ACCUM+STATUS; 
    SS1_S = mod(SS1,10);
    CASE Round(SS1_S)
       WHEN 0 THEN SS1_OUT = 2; -- Error
       WHEN 1 THEN SS1_OUT = 3; -- Dry
       WHEN 2 THEN SS1_OUT = 4; -- Moist
       WHEN 3 THEN SS1_OUT = 5; -- Wet
       WHEN 4 THEN SS1_OUT = 6; -- Wet and Chemical
       WHEN 5 THEN SS1_OUT = 13; -- Frosty
       WHEN 6 THEN SS1_OUT = 10; -- Snow Watch
       WHEN 7 THEN SS1_OUT = 8; -- Ice Watch
       WHEN 8 THEN SS1_OUT = 6; -- Wet and Chemical
       WHEN 9 THEN SS1_OUT = 1; -- other
       ELSE SS1_OUT = 1; -- other
    END CASE;
    

  END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime
  --and  si.symbol = '60' 
  and  si.symbol = '61'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '66'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN 
    ACCUM=ACCUM+STATUS;
    CASE Round(SpSS)
       WHEN 4 THEN SpSS_OUT = 0;
       WHEN 5 THEN SpSS_OUT = 301; -- frostWarning
       WHEN 8 THEN SpSS_OUT = 0;
       ELSE SpSS_OUT = SpSS;
    END CASE;

  END IF;

  -- Added by REC, 10-Dec-2013
  select dv.nvalue, dv.status into SpGR, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = '68'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
   
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
--               , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    --ess_surf_status = SS1,
    ess_surf_status = SS1_OUT,
    Spectro_surf_temp = SpST,
    --spectro_surf_status = SpSS,
    spectro_surf_status = SpSS_OUT, 
    spectro_grip = SpGR, 
    status = ACCUM
 WHERE
    stn_id = stnid; 

 -- ntcip handler dropped by accident 
 -- re-enabled 28/11/2013 BJT
 
 elsif cs = 8 then
 --NTCIP Values
 -- RAISE NOTICE 'codespace(%)', cs;

  select last_updated into myTime from oe.station_identity where stn_id = stnid;

    select dv.nvalue, dv.status into AirT, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAirTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into RH1, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essRelativeHumidity.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WS, STATUS 
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAvgWindSpeed.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
  
  select dv.nvalue, dv.status into WD, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essAvgWindDirection.0'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into ST1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essSurfaceTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SS1, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'essSurfaceStatus.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;


  select dv.nvalue, dv.status into SpST, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'spectroSurfaceTemperature.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

  select dv.nvalue, dv.status into SpSS, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'spectroSurfaceStatus.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;

-- Added by REC
  select dv.nvalue, dv.status into SpGR, STATUS
  from oe.data_value dv, oe.sensor_identity si
  where si.stn_id = stnid
  and dv.creationtime = myTime 
  and  si.symbol = 'spectroSurfaceFrictionIndex.1'
  and dv.sensor_id = si.sensor_id;
  if STATUS IS NOT NULL THEN ACCUM=ACCUM+STATUS; END IF;
     
 -- RAISE NOTICE ' date(%) TA(%) RH(%) WS(%) WD(%) ST1(%) SS1(%) SpSt(%) SpSS(%) STATUS(%)'
 --              , myTime, AirT, RH1,   WS,   WD,   ST1,   SS1,   SpST,   SpSS,   ACCUM;

 UPDATE oe.new_last_reading
 SET
    last_datetime = myTime,
    air_temp = AirT,
    rh = RH1,
    avg_wind_speed = WS,
    avg_wind_dir = WD,
    ess_surf_temp = ST1,
    ess_surf_status = SS1,
    Spectro_surf_temp = SpST,
    spectro_surf_status = SpSS,
    spectro_grip = SpGR,
    status = ACCUM
 WHERE
    stn_id = stnid;  

 end if;   
 
end
$$;


ALTER FUNCTION oe.run_upsert_queries(stnid integer) OWNER TO cloud;

--
-- Name: upsert_val1(integer); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION upsert_val1(stnid integer) RETURNS void
    LANGUAGE sql STRICT
    AS $$
WITH upsert as (
  update oe.last_reading lm 
  set 
    last_datetime = st.last_updated, 
    air_temp = dv.nvalue , -- change to reflect column name
    status = lm.status + dv.status
  from 
    oe.data_value dv, 
    oe.station_identity st,
    oe.sensor_identity si 
  where lm.stn_id = stnid
  and st.stn_id  = lm.stn_id
  and si.stn_id = st.stn_id  
  and dv.stn_id = si.stn_id
  and dv.creationtime = st.last_updated
  and si.symbol = 'essAirTemperature.1'
  and dv.sensor_id = si.sensor_id 
 -- and dv.status >= 0
  RETURNING lm.*
)
insert into oe.last_reading (stn_id,station_name,last_datetime)
select st.stn_id, st.xml_target_name, now() 
from oe.station_identity st , oe.sensor_identity si
where st.stn_id = stnid 
and si.stn_id = st.stn_id
and si.symbol = 'essAirTemperature.1'
and st.stn_id not in (select b.stn_id from upsert b);
$$;


ALTER FUNCTION oe.upsert_val1(stnid integer) OWNER TO cloud;

--
-- Name: seq_data_value_id; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE seq_data_value_id
    START WITH 159804781
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 50;


ALTER TABLE oe.seq_data_value_id OWNER TO cloud;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: data_value; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value (
    value_id bigint DEFAULT nextval('seq_data_value_id'::regclass) NOT NULL,
    sensor_id integer NOT NULL,
    creationtime timestamp without time zone NOT NULL,
    nvalue double precision,
    status integer,
    lane_no bigint,
    sensor_no integer,
    stn_id integer NOT NULL,
    created timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    nvalue_str character varying(300)
);


ALTER TABLE oe.data_value OWNER TO cloud;

--
-- Name: TABLE data_value; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON TABLE data_value IS 'Numerical observations.';


--
-- Name: COLUMN data_value.value_id; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.value_id IS 'Surrogate, primary key of the table.';


--
-- Name: COLUMN data_value.sensor_id; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.sensor_id IS 'References to identity table and on into VMDB.';


--
-- Name: COLUMN data_value.creationtime; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.creationtime IS 'Observation time';


--
-- Name: COLUMN data_value.nvalue; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.nvalue IS 'Value of numerical observation.';


--
-- Name: COLUMN data_value.status; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.status IS 'Quality of observation.';


--
-- Name: COLUMN data_value.lane_no; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.lane_no IS 'Reference to the lane number of the observation (unit attribute in the xml).
';


--
-- Name: COLUMN data_value.sensor_no; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.sensor_no IS 'Reference to the sensor number (no attribute in the xml).';


--
-- Name: COLUMN data_value.stn_id; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.stn_id IS 'User set quality for the observation.';


--
-- Name: COLUMN data_value.created; Type: COMMENT; Schema: oe; Owner: cloud
--

COMMENT ON COLUMN data_value.created IS 'Data insertion time in the database';


--
-- Name: data_value_2014_10_19; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value_2014_10_19 (
    CONSTRAINT data_value_2014_10_19_creationtime_check CHECK (((creationtime >= '2014-10-19'::date) AND (creationtime < '2014-10-20'::date)))
)
INHERITS (data_value);


ALTER TABLE oe.data_value_2014_10_19 OWNER TO cloud;

--
-- Name: data_value_2014_10_20; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value_2014_10_20 (
    CONSTRAINT data_value_2014_10_20_creationtime_check CHECK (((creationtime >= '2014-10-20'::date) AND (creationtime < '2014-10-21'::date)))
)
INHERITS (data_value);


ALTER TABLE oe.data_value_2014_10_20 OWNER TO cloud;

--
-- Name: data_value_2014_10_21; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value_2014_10_21 (
    CONSTRAINT data_value_2014_10_21_creationtime_check CHECK (((creationtime >= '2014-10-21'::date) AND (creationtime < '2014-10-22'::date)))
)
INHERITS (data_value);


ALTER TABLE oe.data_value_2014_10_21 OWNER TO cloud;

--
-- Name: data_value_2014_10_22; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value_2014_10_22 (
    CONSTRAINT data_value_2014_10_22_creationtime_check CHECK (((creationtime >= '2014-10-22'::date) AND (creationtime < '2014-10-23'::date)))
)
INHERITS (data_value);


ALTER TABLE oe.data_value_2014_10_22 OWNER TO cloud;

--
-- Name: data_value_2014_10_23; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE data_value_2014_10_23 (
    CONSTRAINT data_value_2014_10_23_creationtime_check CHECK (((creationtime >= '2014-10-23'::date) AND (creationtime < '2014-10-24'::date)))
)
INHERITS (data_value);


ALTER TABLE oe.data_value_2014_10_23 OWNER TO cloud;

--
-- Name: last_reading2_last_reading_id_seq; Type: SEQUENCE; Schema: oe; Owner: postgres
--

CREATE SEQUENCE last_reading2_last_reading_id_seq
    START WITH 340
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.last_reading2_last_reading_id_seq OWNER TO postgres;

--
-- Name: last_reading; Type: TABLE; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE UNLOGGED TABLE last_reading (
    last_reading_id integer DEFAULT nextval('last_reading2_last_reading_id_seq'::regclass) NOT NULL,
    stn_id integer NOT NULL,
    last_datetime timestamp without time zone NOT NULL,
    station_name character varying(100),
    air_temp double precision,
    rh double precision,
    avg_wind_speed double precision,
    avg_wind_dir double precision,
    ess_surf_temp double precision,
    ess_surf_status double precision,
    spectro_surf_temp double precision,
    spectro_surf_status double precision,
    val9 double precision,
    val10 double precision,
    status integer DEFAULT (-999) NOT NULL
);


ALTER TABLE oe.last_reading OWNER TO postgres;

--
-- Name: new_last_reading_last_reading_id_seq; Type: SEQUENCE; Schema: oe; Owner: postgres
--

CREATE SEQUENCE new_last_reading_last_reading_id_seq
    START WITH 397159
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.new_last_reading_last_reading_id_seq OWNER TO postgres;

--
-- Name: new_last_reading; Type: TABLE; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE TABLE new_last_reading (
    last_reading_id integer DEFAULT nextval('new_last_reading_last_reading_id_seq'::regclass) NOT NULL,
    stn_id integer NOT NULL,
    last_datetime timestamp without time zone NOT NULL,
    station_name character varying(100),
    air_temp double precision,
    rh double precision,
    avg_wind_speed double precision,
    avg_wind_dir double precision,
    ess_surf_temp double precision,
    ess_surf_status double precision,
    spectro_surf_temp double precision,
    spectro_surf_status double precision,
    val9 double precision,
    val10 double precision,
    status integer DEFAULT (-999) NOT NULL,
    codespace integer DEFAULT (-1) NOT NULL,
    spectro_grip double precision
);


ALTER TABLE oe.new_last_reading OWNER TO postgres;

--
-- Name: sensor_alias; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE sensor_alias (
    sensor_alias_id integer NOT NULL,
    symbol character varying(100) NOT NULL,
    sensor_no integer DEFAULT 0 NOT NULL,
    alias character varying(100) NOT NULL,
    date_added date DEFAULT now() NOT NULL,
    added_by character varying(20),
    comments character varying(200),
    codespace integer NOT NULL,
    in_use boolean DEFAULT true NOT NULL
);


ALTER TABLE oe.sensor_alias OWNER TO cloud;

--
-- Name: sensor_alias_sensor_alias_id_seq; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE sensor_alias_sensor_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.sensor_alias_sensor_alias_id_seq OWNER TO cloud;

--
-- Name: sensor_alias_sensor_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: oe; Owner: cloud
--

ALTER SEQUENCE sensor_alias_sensor_alias_id_seq OWNED BY sensor_alias.sensor_alias_id;


--
-- Name: sensor_identity; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE sensor_identity (
    sensor_id integer NOT NULL,
    symbol character varying(100) NOT NULL,
    stn_id integer NOT NULL,
    sensor_no integer NOT NULL,
    lane_no integer NOT NULL,
    codespace integer NOT NULL,
    entry_datetime timestamp without time zone,
    blacklisted boolean DEFAULT false NOT NULL
);


ALTER TABLE oe.sensor_identity OWNER TO cloud;

--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE sensor_identity_sensor_id_seq
    START WITH 463
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.sensor_identity_sensor_id_seq OWNER TO cloud;

--
-- Name: sensor_identity_sensor_id_seq1; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE sensor_identity_sensor_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.sensor_identity_sensor_id_seq1 OWNER TO cloud;

--
-- Name: sensor_identity_sensor_id_seq1; Type: SEQUENCE OWNED BY; Schema: oe; Owner: cloud
--

ALTER SEQUENCE sensor_identity_sensor_id_seq1 OWNED BY sensor_identity.sensor_id;


--
-- Name: station_alias; Type: TABLE; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE TABLE station_alias (
    stn_alias_id integer NOT NULL,
    stn_id integer,
    v_region_id integer,
    blacklisted boolean DEFAULT false NOT NULL,
    entry_date date DEFAULT now() NOT NULL,
    added_by character varying(24),
    comments character varying(120)
);


ALTER TABLE oe.station_alias OWNER TO postgres;

--
-- Name: station_alias_identity; Type: TABLE; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE TABLE station_alias_identity (
    v_region_id integer NOT NULL,
    v_region_name character varying(60) NOT NULL,
    blacklisted boolean DEFAULT false NOT NULL,
    entry_date date DEFAULT now(),
    added_by character varying(24)
);


ALTER TABLE oe.station_alias_identity OWNER TO postgres;

--
-- Name: station_alias_identity_vuser_id_seq; Type: SEQUENCE; Schema: oe; Owner: postgres
--

CREATE SEQUENCE station_alias_identity_vuser_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.station_alias_identity_vuser_id_seq OWNER TO postgres;

--
-- Name: station_alias_identity_vuser_id_seq; Type: SEQUENCE OWNED BY; Schema: oe; Owner: postgres
--

ALTER SEQUENCE station_alias_identity_vuser_id_seq OWNED BY station_alias_identity.v_region_id;


--
-- Name: station_alias_stn_alias_id_seq; Type: SEQUENCE; Schema: oe; Owner: postgres
--

CREATE SEQUENCE station_alias_stn_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.station_alias_stn_alias_id_seq OWNER TO postgres;

--
-- Name: station_alias_stn_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: oe; Owner: postgres
--

ALTER SEQUENCE station_alias_stn_alias_id_seq OWNED BY station_alias.stn_alias_id;


--
-- Name: station_identity_stn_id_seq1; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE station_identity_stn_id_seq1
    START WITH 272
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.station_identity_stn_id_seq1 OWNER TO cloud;

--
-- Name: station_identity; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE station_identity (
    stn_id integer DEFAULT nextval('station_identity_stn_id_seq1'::regclass) NOT NULL,
    xml_target_name character varying(100) NOT NULL,
    entry_datetime timestamp without time zone,
    blacklisted boolean DEFAULT false NOT NULL,
    station_name character varying(100),
    last_updated timestamp without time zone,
    lat double precision,
    lon double precision,
    alt double precision,
    region_id character varying(12),
    image1_url character varying(100),
    image2_url character varying(100),
    forecast_url character varying(100),
    country_id character varying(20),
    org_id character varying(50),
    geom public.geometry
);


ALTER TABLE oe.station_identity OWNER TO cloud;

--
-- Name: station_identity_stn_id_seq; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE station_identity_stn_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.station_identity_stn_id_seq OWNER TO cloud;

--
-- Name: user_identity_user_id_seq; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE user_identity_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.user_identity_user_id_seq OWNER TO cloud;

--
-- Name: value_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_19 ALTER COLUMN value_id SET DEFAULT nextval('seq_data_value_id'::regclass);


--
-- Name: created; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_19 ALTER COLUMN created SET DEFAULT timezone('UTC'::text, now());


--
-- Name: value_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_20 ALTER COLUMN value_id SET DEFAULT nextval('seq_data_value_id'::regclass);


--
-- Name: created; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_20 ALTER COLUMN created SET DEFAULT timezone('UTC'::text, now());


--
-- Name: value_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_21 ALTER COLUMN value_id SET DEFAULT nextval('seq_data_value_id'::regclass);


--
-- Name: created; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_21 ALTER COLUMN created SET DEFAULT timezone('UTC'::text, now());


--
-- Name: value_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_22 ALTER COLUMN value_id SET DEFAULT nextval('seq_data_value_id'::regclass);


--
-- Name: created; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_22 ALTER COLUMN created SET DEFAULT timezone('UTC'::text, now());


--
-- Name: value_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_23 ALTER COLUMN value_id SET DEFAULT nextval('seq_data_value_id'::regclass);


--
-- Name: created; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value_2014_10_23 ALTER COLUMN created SET DEFAULT timezone('UTC'::text, now());


--
-- Name: sensor_alias_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY sensor_alias ALTER COLUMN sensor_alias_id SET DEFAULT nextval('sensor_alias_sensor_alias_id_seq'::regclass);


--
-- Name: sensor_id; Type: DEFAULT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY sensor_identity ALTER COLUMN sensor_id SET DEFAULT nextval('sensor_identity_sensor_id_seq1'::regclass);


--
-- Name: stn_alias_id; Type: DEFAULT; Schema: oe; Owner: postgres
--

ALTER TABLE ONLY station_alias ALTER COLUMN stn_alias_id SET DEFAULT nextval('station_alias_stn_alias_id_seq'::regclass);


--
-- Name: v_region_id; Type: DEFAULT; Schema: oe; Owner: postgres
--

ALTER TABLE ONLY station_alias_identity ALTER COLUMN v_region_id SET DEFAULT nextval('station_alias_identity_vuser_id_seq'::regclass);


--
-- Data for Name: data_value; Type: TABLE DATA; Schema: oe; Owner: cloud
--

COPY data_value (value_id, sensor_id, creationtime, nvalue, status, lane_no, sensor_no, stn_id, created, nvalue_str) FROM stdin;
\.


--
-- Name: last_reading2_last_reading_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: postgres
--

SELECT pg_catalog.setval('last_reading2_last_reading_id_seq', 340, false);


--
-- Name: new_last_reading_last_reading_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: postgres
--

SELECT pg_catalog.setval('new_last_reading_last_reading_id_seq', 397159, false);


--
-- Data for Name: sensor_alias; Type: TABLE DATA; Schema: oe; Owner: cloud
--

COPY sensor_alias (sensor_alias_id, symbol, sensor_no, alias, date_added, added_by, comments, codespace, in_use) FROM stdin;
\.


--
-- Name: sensor_alias_sensor_alias_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('sensor_alias_sensor_alias_id_seq', 1, false);


--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('sensor_identity_sensor_id_seq', 463, false);


--
-- Name: sensor_identity_sensor_id_seq1; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('sensor_identity_sensor_id_seq1', 1, false);


--
-- Name: seq_data_value_id; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('seq_data_value_id', 159804781, false);


--
-- Data for Name: station_alias; Type: TABLE DATA; Schema: oe; Owner: postgres
--

COPY station_alias (stn_alias_id, stn_id, v_region_id, blacklisted, entry_date, added_by, comments) FROM stdin;
\.


--
-- Data for Name: station_alias_identity; Type: TABLE DATA; Schema: oe; Owner: postgres
--

COPY station_alias_identity (v_region_id, v_region_name, blacklisted, entry_date, added_by) FROM stdin;
\.


--
-- Name: station_alias_identity_vuser_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: postgres
--

SELECT pg_catalog.setval('station_alias_identity_vuser_id_seq', 1, false);


--
-- Name: station_alias_stn_alias_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: postgres
--

SELECT pg_catalog.setval('station_alias_stn_alias_id_seq', 1, false);


--
-- Data for Name: station_identity; Type: TABLE DATA; Schema: oe; Owner: cloud
--

COPY station_identity (stn_id, xml_target_name, entry_datetime, blacklisted, station_name, last_updated, lat, lon, alt, region_id, image1_url, image2_url, forecast_url, country_id, org_id, geom) FROM stdin;
\.


--
-- Name: station_identity_stn_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('station_identity_stn_id_seq', 1, false);


--
-- Name: station_identity_stn_id_seq1; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('station_identity_stn_id_seq1', 272, false);


--
-- Name: user_identity_user_id_seq; Type: SEQUENCE SET; Schema: oe; Owner: cloud
--

SELECT pg_catalog.setval('user_identity_user_id_seq', 1, false);


SET search_path = public, pg_catalog;

--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


SET search_path = oe, pg_catalog;

--
-- Name: data_value_2014_10_19_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value_2014_10_19
    ADD CONSTRAINT data_value_2014_10_19_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: data_value_2014_10_20_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value_2014_10_20
    ADD CONSTRAINT data_value_2014_10_20_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: data_value_2014_10_21_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value_2014_10_21
    ADD CONSTRAINT data_value_2014_10_21_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: data_value_2014_10_22_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value_2014_10_22
    ADD CONSTRAINT data_value_2014_10_22_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: data_value_2014_10_23_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value_2014_10_23
    ADD CONSTRAINT data_value_2014_10_23_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: data_value_creationtime_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value
    ADD CONSTRAINT data_value_creationtime_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: last_reading2_pk; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT last_reading2_pk PRIMARY KEY (last_reading_id);


--
-- Name: new_last_reading_pk; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY new_last_reading
    ADD CONSTRAINT new_last_reading_pk PRIMARY KEY (last_reading_id);


--
-- Name: new_unique_stn_id; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY new_last_reading
    ADD CONSTRAINT new_unique_stn_id UNIQUE (stn_id);


--
-- Name: sensor_alias_pkey; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY sensor_alias
    ADD CONSTRAINT sensor_alias_pkey PRIMARY KEY (sensor_alias_id);


--
-- Name: sensor_identity_sensor_id_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT sensor_identity_sensor_id_pk PRIMARY KEY (sensor_id);


--
-- Name: station_identity_stn_id.pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY station_identity
    ADD CONSTRAINT "station_identity_stn_id.pk" PRIMARY KEY (stn_id);


--
-- Name: unique_alias_identity; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY sensor_alias
    ADD CONSTRAINT unique_alias_identity UNIQUE (symbol, sensor_no, codespace);


--
-- Name: unique_mapping; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT unique_mapping UNIQUE (stn_id, v_region_id);


--
-- Name: unique_stn_id2; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT unique_stn_id2 UNIQUE (stn_id);


--
-- Name: v_region_id_pk; Type: CONSTRAINT; Schema: oe; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_alias_identity
    ADD CONSTRAINT v_region_id_pk PRIMARY KEY (v_region_id);


--
-- Name: data_value_2014_10_19_created_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_19_created_idx ON data_value_2014_10_19 USING btree (created DESC NULLS LAST);


--
-- Name: data_value_2014_10_19_sensor_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_19_sensor_idx ON data_value_2014_10_19 USING btree (sensor_id);


--
-- Name: data_value_2014_10_19_station_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_19_station_idx ON data_value_2014_10_19 USING btree (stn_id);


--
-- Name: data_value_2014_10_20_created_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_20_created_idx ON data_value_2014_10_20 USING btree (created DESC NULLS LAST);


--
-- Name: data_value_2014_10_20_sensor_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_20_sensor_idx ON data_value_2014_10_20 USING btree (sensor_id);


--
-- Name: data_value_2014_10_20_station_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_20_station_idx ON data_value_2014_10_20 USING btree (stn_id);


--
-- Name: data_value_2014_10_21_created_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_21_created_idx ON data_value_2014_10_21 USING btree (created DESC NULLS LAST);


--
-- Name: data_value_2014_10_21_sensor_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_21_sensor_idx ON data_value_2014_10_21 USING btree (sensor_id);


--
-- Name: data_value_2014_10_21_station_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_21_station_idx ON data_value_2014_10_21 USING btree (stn_id);


--
-- Name: data_value_2014_10_22_created_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_22_created_idx ON data_value_2014_10_22 USING btree (created DESC NULLS LAST);


--
-- Name: data_value_2014_10_22_sensor_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_22_sensor_idx ON data_value_2014_10_22 USING btree (sensor_id);


--
-- Name: data_value_2014_10_22_station_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_22_station_idx ON data_value_2014_10_22 USING btree (stn_id);


--
-- Name: data_value_2014_10_23_created_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_23_created_idx ON data_value_2014_10_23 USING btree (created DESC NULLS LAST);


--
-- Name: data_value_2014_10_23_sensor_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_23_sensor_idx ON data_value_2014_10_23 USING btree (sensor_id);


--
-- Name: data_value_2014_10_23_station_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX data_value_2014_10_23_station_idx ON data_value_2014_10_23 USING btree (stn_id);


--
-- Name: last_reading2_stn_id.idx; Type: INDEX; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE INDEX "last_reading2_stn_id.idx" ON last_reading USING btree (stn_id);


--
-- Name: new_last_reading_stn_id.idx; Type: INDEX; Schema: oe; Owner: postgres; Tablespace: 
--

CREATE INDEX "new_last_reading_stn_id.idx" ON last_reading USING btree (stn_id);


--
-- Name: sensor_identity_stn_id_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX sensor_identity_stn_id_idx ON sensor_identity USING btree (stn_id);


--
-- Name: sensor_identity_symbol_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX sensor_identity_symbol_idx ON sensor_identity USING btree (symbol);


--
-- Name: station_identity_target_name.idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX "station_identity_target_name.idx" ON station_identity USING btree (xml_target_name);


--
-- Name: data_value_insert_trigger; Type: TRIGGER; Schema: oe; Owner: cloud
--

CREATE TRIGGER data_value_insert_trigger BEFORE INSERT ON data_value FOR EACH ROW EXECUTE PROCEDURE data_insert_trigger_func();


--
-- Name: data_value_sensor_id_identity_fk; Type: FK CONSTRAINT; Schema: oe; Owner: cloud
--

ALTER TABLE ONLY data_value
    ADD CONSTRAINT data_value_sensor_id_identity_fk FOREIGN KEY (sensor_id) REFERENCES sensor_identity(sensor_id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: last_reading2_stn_id_fk; Type: FK CONSTRAINT; Schema: oe; Owner: postgres
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT last_reading2_stn_id_fk FOREIGN KEY (stn_id) REFERENCES station_identity(stn_id);


--
-- Name: new_last_reading_stn_id_fk; Type: FK CONSTRAINT; Schema: oe; Owner: postgres
--

ALTER TABLE ONLY new_last_reading
    ADD CONSTRAINT new_last_reading_stn_id_fk FOREIGN KEY (stn_id) REFERENCES station_identity(stn_id);


--
-- Name: station_alias_v_region_id_fkey; Type: FK CONSTRAINT; Schema: oe; Owner: postgres
--

ALTER TABLE ONLY station_alias
    ADD CONSTRAINT station_alias_v_region_id_fkey FOREIGN KEY (v_region_id) REFERENCES station_alias_identity(v_region_id);


--
-- Name: oe; Type: ACL; Schema: -; Owner: cloud
--

REVOKE ALL ON SCHEMA oe FROM PUBLIC;
REVOKE ALL ON SCHEMA oe FROM cloud;
GRANT ALL ON SCHEMA oe TO cloud;
GRANT USAGE ON SCHEMA oe TO pgsqlchkgrp;
GRANT USAGE ON SCHEMA oe TO obsread;
GRANT USAGE ON SCHEMA oe TO madiswrite;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: 131108_run_upsert_queries(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION "131108_run_upsert_queries"(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION "131108_run_upsert_queries"(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION "131108_run_upsert_queries"(stnid integer) TO cloud;
GRANT ALL ON FUNCTION "131108_run_upsert_queries"(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION "131108_run_upsert_queries"(stnid integer) TO madiswrite;


--
-- Name: 131128_run_upsert_queries(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION "131128_run_upsert_queries"(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION "131128_run_upsert_queries"(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION "131128_run_upsert_queries"(stnid integer) TO cloud;
GRANT ALL ON FUNCTION "131128_run_upsert_queries"(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION "131128_run_upsert_queries"(stnid integer) TO madiswrite;


--
-- Name: data_insert_trigger_func(); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION data_insert_trigger_func() FROM PUBLIC;
REVOKE ALL ON FUNCTION data_insert_trigger_func() FROM cloud;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO cloud;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO PUBLIC;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO madiswrite;


--
-- Name: general_dv_func1(text, text, text, timestamp without time zone, timestamp without time zone); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) FROM PUBLIC;
REVOKE ALL ON FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) FROM cloud;
GRANT ALL ON FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) TO cloud;
GRANT ALL ON FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) TO PUBLIC;
GRANT ALL ON FUNCTION general_dv_func1("user" text, pass text, station text, start timestamp without time zone, "end" timestamp without time zone) TO madiswrite;


--
-- Name: get_codespace(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION get_codespace(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_codespace(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION get_codespace(stnid integer) TO cloud;
GRANT ALL ON FUNCTION get_codespace(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION get_codespace(stnid integer) TO madiswrite;


--
-- Name: manage_partitions(); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION manage_partitions() FROM PUBLIC;
REVOKE ALL ON FUNCTION manage_partitions() FROM cloud;
GRANT ALL ON FUNCTION manage_partitions() TO cloud;
GRANT ALL ON FUNCTION manage_partitions() TO PUBLIC;
GRANT ALL ON FUNCTION manage_partitions() TO madiswrite;


--
-- Name: new_creation_day(date, date); Type: ACL; Schema: oe; Owner: madiswrite
--

REVOKE ALL ON FUNCTION new_creation_day(date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION new_creation_day(date, date) FROM madiswrite;
GRANT ALL ON FUNCTION new_creation_day(date, date) TO madiswrite;
GRANT ALL ON FUNCTION new_creation_day(date, date) TO PUBLIC;


--
-- Name: new_creation_week(date, date); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION new_creation_week(date, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION new_creation_week(date, date) FROM cloud;
GRANT ALL ON FUNCTION new_creation_week(date, date) TO cloud;
GRANT ALL ON FUNCTION new_creation_week(date, date) TO PUBLIC;
GRANT ALL ON FUNCTION new_creation_week(date, date) TO madiswrite;


--
-- Name: old_run_upsert_queries(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION old_run_upsert_queries(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION old_run_upsert_queries(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION old_run_upsert_queries(stnid integer) TO cloud;
GRANT ALL ON FUNCTION old_run_upsert_queries(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION old_run_upsert_queries(stnid integer) TO madiswrite;


--
-- Name: reset_last_reading_status(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION reset_last_reading_status(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION reset_last_reading_status(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION reset_last_reading_status(stnid integer) TO cloud;
GRANT ALL ON FUNCTION reset_last_reading_status(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION reset_last_reading_status(stnid integer) TO madiswrite;


--
-- Name: run_upsert_queries(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION run_upsert_queries(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION run_upsert_queries(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION run_upsert_queries(stnid integer) TO cloud;
GRANT ALL ON FUNCTION run_upsert_queries(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION run_upsert_queries(stnid integer) TO madiswrite;


--
-- Name: upsert_val1(integer); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION upsert_val1(stnid integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION upsert_val1(stnid integer) FROM cloud;
GRANT ALL ON FUNCTION upsert_val1(stnid integer) TO cloud;
GRANT ALL ON FUNCTION upsert_val1(stnid integer) TO PUBLIC;
GRANT ALL ON FUNCTION upsert_val1(stnid integer) TO madiswrite;


--
-- Name: seq_data_value_id; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE seq_data_value_id FROM PUBLIC;
REVOKE ALL ON SEQUENCE seq_data_value_id FROM cloud;
GRANT ALL ON SEQUENCE seq_data_value_id TO cloud;
GRANT ALL ON SEQUENCE seq_data_value_id TO madiswrite;


--
-- Name: data_value; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value FROM PUBLIC;
REVOKE ALL ON TABLE data_value FROM cloud;
GRANT ALL ON TABLE data_value TO cloud;
GRANT SELECT ON TABLE data_value TO obsread;
GRANT ALL ON TABLE data_value TO madiswrite;


--
-- Name: data_value_2014_10_19; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value_2014_10_19 FROM PUBLIC;
REVOKE ALL ON TABLE data_value_2014_10_19 FROM cloud;
GRANT ALL ON TABLE data_value_2014_10_19 TO cloud;
GRANT SELECT,INSERT,UPDATE ON TABLE data_value_2014_10_19 TO madiswrite;
GRANT SELECT ON TABLE data_value_2014_10_19 TO obsread;


--
-- Name: data_value_2014_10_20; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value_2014_10_20 FROM PUBLIC;
REVOKE ALL ON TABLE data_value_2014_10_20 FROM cloud;
GRANT ALL ON TABLE data_value_2014_10_20 TO cloud;
GRANT SELECT,INSERT,UPDATE ON TABLE data_value_2014_10_20 TO madiswrite;
GRANT SELECT ON TABLE data_value_2014_10_20 TO obsread;


--
-- Name: data_value_2014_10_21; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value_2014_10_21 FROM PUBLIC;
REVOKE ALL ON TABLE data_value_2014_10_21 FROM cloud;
GRANT ALL ON TABLE data_value_2014_10_21 TO cloud;
GRANT SELECT,INSERT,UPDATE ON TABLE data_value_2014_10_21 TO madiswrite;
GRANT SELECT ON TABLE data_value_2014_10_21 TO obsread;


--
-- Name: data_value_2014_10_22; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value_2014_10_22 FROM PUBLIC;
REVOKE ALL ON TABLE data_value_2014_10_22 FROM cloud;
GRANT ALL ON TABLE data_value_2014_10_22 TO cloud;
GRANT SELECT,INSERT,UPDATE ON TABLE data_value_2014_10_22 TO madiswrite;
GRANT SELECT ON TABLE data_value_2014_10_22 TO obsread;


--
-- Name: data_value_2014_10_23; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value_2014_10_23 FROM PUBLIC;
REVOKE ALL ON TABLE data_value_2014_10_23 FROM cloud;
GRANT ALL ON TABLE data_value_2014_10_23 TO cloud;
GRANT SELECT,INSERT,UPDATE ON TABLE data_value_2014_10_23 TO madiswrite;
GRANT SELECT ON TABLE data_value_2014_10_23 TO obsread;


--
-- Name: last_reading2_last_reading_id_seq; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON SEQUENCE last_reading2_last_reading_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE last_reading2_last_reading_id_seq FROM postgres;
GRANT ALL ON SEQUENCE last_reading2_last_reading_id_seq TO postgres;
GRANT ALL ON SEQUENCE last_reading2_last_reading_id_seq TO madiswrite;


--
-- Name: last_reading; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON TABLE last_reading FROM PUBLIC;
REVOKE ALL ON TABLE last_reading FROM postgres;
GRANT ALL ON TABLE last_reading TO postgres;
GRANT SELECT,INSERT ON TABLE last_reading TO obsread;
GRANT ALL ON TABLE last_reading TO madiswrite;


--
-- Name: new_last_reading_last_reading_id_seq; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON SEQUENCE new_last_reading_last_reading_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE new_last_reading_last_reading_id_seq FROM postgres;
GRANT ALL ON SEQUENCE new_last_reading_last_reading_id_seq TO postgres;
GRANT ALL ON SEQUENCE new_last_reading_last_reading_id_seq TO madiswrite;


--
-- Name: new_last_reading; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON TABLE new_last_reading FROM PUBLIC;
REVOKE ALL ON TABLE new_last_reading FROM postgres;
GRANT ALL ON TABLE new_last_reading TO postgres;
GRANT SELECT ON TABLE new_last_reading TO pgsqlchkgrp;
GRANT SELECT,INSERT ON TABLE new_last_reading TO obsread;
GRANT ALL ON TABLE new_last_reading TO madiswrite;


--
-- Name: sensor_alias; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE sensor_alias FROM PUBLIC;
REVOKE ALL ON TABLE sensor_alias FROM cloud;
GRANT ALL ON TABLE sensor_alias TO cloud;
GRANT SELECT ON TABLE sensor_alias TO obsread;


--
-- Name: sensor_identity; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE sensor_identity FROM PUBLIC;
REVOKE ALL ON TABLE sensor_identity FROM cloud;
GRANT ALL ON TABLE sensor_identity TO cloud;
GRANT SELECT,INSERT ON TABLE sensor_identity TO obsread;
GRANT ALL ON TABLE sensor_identity TO madiswrite;


--
-- Name: sensor_identity_sensor_id_seq; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq FROM cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq TO cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq TO madiswrite;


--
-- Name: sensor_identity_sensor_id_seq1; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq1 FROM cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq1 TO cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq1 TO madiswrite;


--
-- Name: station_alias; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON TABLE station_alias FROM PUBLIC;
REVOKE ALL ON TABLE station_alias FROM postgres;
GRANT ALL ON TABLE station_alias TO postgres;
GRANT SELECT,INSERT ON TABLE station_alias TO obsread;
GRANT ALL ON TABLE station_alias TO madiswrite;


--
-- Name: station_alias_identity; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON TABLE station_alias_identity FROM PUBLIC;
REVOKE ALL ON TABLE station_alias_identity FROM postgres;
GRANT ALL ON TABLE station_alias_identity TO postgres;
GRANT SELECT,INSERT ON TABLE station_alias_identity TO obsread;
GRANT ALL ON TABLE station_alias_identity TO madiswrite;


--
-- Name: station_alias_identity_vuser_id_seq; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON SEQUENCE station_alias_identity_vuser_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_alias_identity_vuser_id_seq FROM postgres;
GRANT ALL ON SEQUENCE station_alias_identity_vuser_id_seq TO postgres;
GRANT ALL ON SEQUENCE station_alias_identity_vuser_id_seq TO madiswrite;


--
-- Name: station_alias_stn_alias_id_seq; Type: ACL; Schema: oe; Owner: postgres
--

REVOKE ALL ON SEQUENCE station_alias_stn_alias_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_alias_stn_alias_id_seq FROM postgres;
GRANT ALL ON SEQUENCE station_alias_stn_alias_id_seq TO postgres;
GRANT ALL ON SEQUENCE station_alias_stn_alias_id_seq TO madiswrite;


--
-- Name: station_identity_stn_id_seq1; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE station_identity_stn_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_identity_stn_id_seq1 FROM cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq1 TO cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq1 TO madiswrite;


--
-- Name: station_identity; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE station_identity FROM PUBLIC;
REVOKE ALL ON TABLE station_identity FROM cloud;
GRANT ALL ON TABLE station_identity TO cloud;
GRANT SELECT,INSERT ON TABLE station_identity TO obsread;
GRANT ALL ON TABLE station_identity TO madiswrite;


--
-- Name: station_identity_stn_id_seq; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE station_identity_stn_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_identity_stn_id_seq FROM cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq TO cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq TO madiswrite;


--
-- Name: user_identity_user_id_seq; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE user_identity_user_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE user_identity_user_id_seq FROM cloud;
GRANT ALL ON SEQUENCE user_identity_user_id_seq TO cloud;
GRANT ALL ON SEQUENCE user_identity_user_id_seq TO madiswrite;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT ON TABLES  TO obsread;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: oe; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA oe REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA oe REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA oe GRANT SELECT,INSERT,UPDATE ON TABLES  TO madiswrite;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA oe GRANT SELECT ON TABLES  TO obsread;


--
-- PostgreSQL database dump complete
--

