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
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: qm_cmp_2_values(numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: cloud
--

CREATE FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) RETURNS boolean
    LANGUAGE plpgsql
    AS $$DECLARE
    tmpval numeric:= ABS(this - that);
BEGIN
IF tmpval > threshold THEN
    RETURN TRUE;
ElSE 
    RETURN FALSE;
END IF;
END$$;


ALTER FUNCTION public.qm_cmp_2_values(this numeric, that numeric, threshold numeric) OWNER TO cloud;

--
-- Name: qm_jpctest3(integer, text, text, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$BEGIN
IF test_value = 6 OR test_value = 7 THEN
  INSERT INTO alerts(alert_id, sensor_id, channel_id, message)
  SELECT 'ice/snow', sens_id, channel, 'Ice/Snow detected!'
  WHERE NOT EXISTS(
    select * from alerts
    where channel_id = channel
      and entry_datetime < CURRENT_TIMESTAMP
      and entry_datetime >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
  );
  RETURN -5000;
ELSE
  RETURN 0;
END IF;
END$$;


ALTER FUNCTION public.qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) OWNER TO postgres;

--
-- Name: qm_local_xwind1(numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$DECLARE
    wind_direction2 NUMERIC:= (wind_direction + 180) % 360;  -- define both directions
    xwind_angle NUMERIC:= 30;                                 -- cross wind angle (+/-) MUST BE LESS THAN 90 degrees
    max_wind_speed NUMERIC:= 15;                          -- wind speed threshold
    error_code INT:= -101;
    ang1 NUMERIC:= road_direction + xwind_angle;              -- define XWIND 'window'
    ang2 NUMERIC:= road_direction - xwind_angle;              -- define XWIND 'window'
    hi NUMERIC;
    lo NUMERIC;
BEGIN
IF wind_speed < max_wind_speed THEN 
   RETURN 0;                  -- exit if wind speed too low
END IF;
IF ang1 > 360 THEN 
   ang1 = ang1 - 360;
ELSIF
   ang1 < 0 THEN
   ang1 = ang1 + 360;         
END IF;      

IF ang2 > 360 THEN 
   ang2 = ang2 - 360;
ELSIF
   ang2 < 0 THEN
   ang2 = ang2 + 360;
END IF;    

--RAISE NOTICE 'angle(%) angle(%) WD1(%) WD2(%)',ang1, ang2, wind_direction, wind_direction2; 
 --define 'hi' and 'lo' angles for condion tests below.

IF ang1 - ang2 < 0 THEN
   hi = ang2;
   lo = ang1;
ELSE
   lo = ang2;
   hi = ang1;
END IF;   

-- condion tests (assumes xwind definition is shortest path)
IF (hi - lo) < 180 THEN
  if(wind_direction > lo) AND (wind_direction < hi) THEN 
    RAISE NOTICE 'hit1'; 
    RETURN error_code;
  ELSIF
  ((wind_direction2 > lo) AND (wind_direction2 < hi)) THEN
    RAISE NOTICE 'hit2';
    RETURN error_code; 
  END IF;
ELSE 
  if (wind_direction < lo) OR (wind_direction > hi) THEN 
    RAISE NOTICE 'hit3'; 
    RETURN error_code;
  ELSIF
    (wind_direction2 < lo) OR (wind_direction2 > hi) THEN 
    RAISE NOTICE 'hit4';
    RETURN error_code;
  END IF;                                                                  -- cross wind present
END IF;
RETURN 0;                                                                  
END$$;


ALTER FUNCTION public.qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) OWNER TO postgres;

--
-- Name: qm_surfstate(integer, text, text, numeric); Type: FUNCTION; Schema: public; Owner: cloud
--

CREATE FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$BEGIN
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
END$$;


ALTER FUNCTION public.qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) OWNER TO cloud;

--
-- Name: set_m14_quality_thresholds(); Type: FUNCTION; Schema: public; Owner: cloudwrite
--

CREATE FUNCTION set_m14_quality_thresholds() RETURNS void
    LANGUAGE sql STRICT
    AS $$

-- Air Temperature
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '01'
and codespace < 2
and default_settings = true ;

-- RH
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = 101,
default_settings = false,
max_step_val = 20,
value_multiplier = 1
where symbol = '02'
and codespace < 2
and default_settings = true ;

-- DewPoint
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '03'
and codespace < 2
and default_settings = true ;

--Rain Off/On
update sensor_identity 
set max_val = 1,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 1,
value_multiplier = 1
where symbol = '04'
and codespace < 2
and default_settings = true ;


-- Wind Speed
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 20,
value_multiplier = 1
where symbol = '05'
and codespace < 2
and default_settings = true ;


-- Wind Direction
update sensor_identity 
set max_val = 360,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 360,
value_multiplier = 1
where symbol = '06'
and codespace < 2
and default_settings = true ;


-- Precipitation Sum
update sensor_identity 
set max_val = 300,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 20,
value_multiplier = 1
where symbol = '08'
and codespace < 2
and default_settings = true ;


-- Rain Intensity
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 20,
value_multiplier = 1
where symbol = '09'
and codespace < 2
and default_settings = true ;


-- Snow Height
update sensor_identity 
set max_val = 300,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 50,
value_multiplier = 1
where symbol = '10'
and codespace < 2
and default_settings = true ;

-- Visibility
update sensor_identity 
set max_val = 20000,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 2001,
value_multiplier = 1
where symbol = '11'
and codespace < 2 ;

-- Pressure
update sensor_identity 
set max_val = 1650,
min_val = 500 ,
error_val = -1,
default_settings = false,
max_step_val = 100,
value_multiplier = 1
where symbol = '12'
and codespace < 2
and default_settings = true ;

-- Battery Voltage
update sensor_identity 
set max_val = 40,
min_val = 10 ,
error_val = -1,
default_settings = false,
max_step_val = 2,
value_multiplier = 1
where symbol = '14'
and codespace < 2
and default_settings = true ;

-- General Status
update sensor_identity 
set max_val = 1,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 1,
value_multiplier = 1
where symbol = '16'
and codespace < 2
and default_settings = true ;


-- Relay On/Off
update sensor_identity 
set max_val = 1,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 1,
value_multiplier = 1
where symbol = '17'
and codespace < 2
and default_settings = true ;

-- Air Temperature Trend
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '21'
and codespace < 2
and default_settings = true ;


-- Rain Class
update sensor_identity 
set max_val = 6,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 6,
value_multiplier = 1
where symbol = '23'
and codespace < 2
and default_settings = true ;


-- Solar Radiation
update sensor_identity 
set max_val = 150000,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 150000,
value_multiplier = 1
where symbol = '24'
and codespace < 2
and default_settings = true ;


-- Solar Radiation
update sensor_identity 
set max_val = 150000,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 150000,
value_multiplier = 1
where symbol = '25'
and codespace < 2
and default_settings = true ;


-- Wind Speed
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 20,
value_multiplier = 1
where symbol = '26'
and codespace < 2
and default_settings = true ;


-- Wind Direction
update sensor_identity 
set max_val = 360,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 360,
value_multiplier = 1
where symbol = '27'
and codespace < 2
and default_settings = true ;

-- Road Sensor 1 -----------------------

-- Surface Temperature 1
update sensor_identity 
set max_val = 60,
min_val = -40,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '30'
and codespace < 2 ;


-- Ground Temperature 1
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '31'
and codespace < 2
and default_settings = true ;


-- Conductivity Signal 1
update sensor_identity 
set max_val = 10,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '32'
and codespace < 2
and default_settings = true ;


-- Surface Signal 1
update sensor_identity 
set max_val = 10,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '33'
and codespace < 2
and default_settings = true ;



-- Black Ice Signal 1
update sensor_identity 
set max_val = 1000,
min_val = 60 ,
error_val = -1,
default_settings = false,
max_step_val = 500,
value_multiplier = 1
where symbol = '34'
and codespace < 2
and default_settings = true ;



-- Freezing Point 1 (Solidus)
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '35'
and codespace < 2
and default_settings = true ;


-- Surface Status 1
update sensor_identity 
set max_val = 438,
min_val = -0 ,
error_val = 0,
default_settings = false,
max_step_val = 438,
value_multiplier = 1
where symbol = '36'
and codespace < 2
and default_settings = true ;


-- Base Temperature 1
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '37'
and codespace < 2
and default_settings = true ;



-- Concentration 1
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 200,
value_multiplier = 1
where symbol = '39'
and codespace < 2
and default_settings = true ;


-- Amount of Chemical
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 200,
value_multiplier = 1
where symbol = '40'
and codespace < 2
and default_settings = true ;


-- Freezing Point 1 (Liquidus)
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '41'
and codespace < 2
and default_settings = true ;


-- Water Thickness 1
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '42'
and codespace < 2
and default_settings = true ;


-- Low Water Thickness 1
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '43'
and codespace < 2
and default_settings = true ;



-- High Water Thickness 1
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '44'
and codespace < 2
and default_settings = true ;



-- Road Sensor 2 -------------------------

-- Surface Temperature 2
update sensor_identity 
set max_val = 60,
min_val = -40,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '45'
and codespace < 2 ;


-- Ground Temperature 2
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '46'
and codespace < 2
and default_settings = true ;


-- Conductivity Signal 2
update sensor_identity 
set max_val = 10,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '47'
and codespace < 2
and default_settings = true ;


-- Surface Signal 2
update sensor_identity 
set max_val = 10,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '48'
and codespace < 2
and default_settings = true ;



-- Black Ice Signal 2
update sensor_identity 
set max_val = 1000,
min_val = 60 ,
error_val = -1,
default_settings = false,
max_step_val = 500,
value_multiplier = 1
where symbol = '49'
and codespace < 2
and default_settings = true ;


-- Freezing Point 2 (Solidus)
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '50'
and codespace < 2
and default_settings = true ;


-- Surface Status 2
update sensor_identity 
set max_val = 438,
min_val = -0 ,
error_val = 0,
default_settings = false,
max_step_val = 438,
value_multiplier = 1
where symbol = '51'
and codespace < 2
and default_settings = true ;


-- Concentration 2
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 200,
value_multiplier = 1
where symbol = '54'
and codespace < 2
and default_settings = true ;


-- Amount of Chemical 2
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 200,
value_multiplier = 1
where symbol = '55'
and codespace < 2
and default_settings = true ;


-- Freezing Point 2 (Liquidus)
update sensor_identity 
set max_val = 60,
min_val = -40 ,
error_val = 61,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '56'
and codespace < 2
and default_settings = true ;

-- Water Thickness 2
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '57'
and codespace < 2
and default_settings = true ;


-- Low Water Thickness 1
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '58'
and codespace < 2
and default_settings = true ;



-- High Water Thickness 1
update sensor_identity 
set max_val = 20,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 10,
value_multiplier = 1
where symbol = '59'
and codespace < 2
and default_settings = true ;


-- Present Weather Detector ------------------------

-- NWS Codes
update sensor_identity 
set max_val = 12,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 12,
value_multiplier = 1
where symbol = '90'
and codespace < 2
and default_settings = true ;


-- Housekeeping Status
update sensor_identity 
set max_val = 22,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 22,
value_multiplier = 1
where symbol = '91'
and codespace < 2
and default_settings = true ;


$$;


ALTER FUNCTION public.set_m14_quality_thresholds() OWNER TO cloudwrite;

--
-- Name: set_ntcip_quality_thresholds(); Type: FUNCTION; Schema: public; Owner: cloudwrite
--

CREATE FUNCTION set_ntcip_quality_thresholds() RETURNS void
    LANGUAGE sql STRICT
    AS $$

 
update sensor_identity 
set max_val =  3000,
min_val = 0 ,
error_val = 3001,
default_settings = false,
max_step_val = 100,
value_multiplier = 1
where symbol like 'essRoadwaySnowD%'
and default_settings = true ;
  

 
update sensor_identity 
set max_val =  3000,
min_val = 0 ,
error_val = 3001,
default_settings = false,
max_step_val = 100,
value_multiplier = 1
where symbol like 'essRoadwaySnowP%'
and default_settings = true ;
  

 
update sensor_identity 
set max_val =  15,
min_val = 1 ,
error_val = 65535,
default_settings = false,
max_step_val = 15,
value_multiplier = 1
where symbol like 'essPrecipSit%'
and default_settings = true ;
  

 
update sensor_identity 
set max_val =  1000,
min_val = 0 ,
error_val = 65535,
default_settings = false,
max_step_val = 100,
value_multiplier = 0.1
where symbol like 'essIce%'
and default_settings = true ;
  

 
update sensor_identity 
set max_val =  4294967295,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 4294967295,
value_multiplier = 1
where symbol like 'essPrecipitationEnd%'
and default_settings = true ;
  

 
update sensor_identity 
set max_val =  4294967295,
min_val = 0 ,
error_val = -1,
default_settings = false,
max_step_val = 4294967295,
value_multiplier = 1
where symbol like 'essPrecipitationStart%'
and default_settings = true ;
  
 
update sensor_identity 
set max_val =  360,
min_val = 0 ,
error_val = 361,
max_step_val = 362,
value_multiplier = 1,
default_settings = false
where default_settings = true 
and symbol like 'essAvgWindD%';
  

 
update sensor_identity 
set max_val = 1500,
min_val = 0 ,
error_val = 65535,
value_multiplier = 0.1,
max_step_val = 300,
default_settings = false
where default_settings = true 
and symbol like 'essAvgWindS%';
  

 
update sensor_identity 
set max_val = 360,
min_val = 0 ,
error_val = 361,
value_multiplier = 1,
max_step_val = 362,
default_settings = false
where default_settings = true 
and symbol like 'essSpotWindD%';
  

 
update sensor_identity 
set max_val = 1500,
min_val = 0 ,
error_val = 65535,
value_multiplier = 0.1,
max_step_val = 300,
default_settings = false
where default_settings = true 
and symbol like 'essSpotWindS%';
  

 
update sensor_identity 
set max_val = 12,
min_val = 1 ,
error_val = -1,
value_multiplier = 1,
max_step_val = 12,
default_settings = false
where default_settings = true 
and symbol like 'essWindSit%';
  

 
update sensor_identity 
set max_val = 1500,
min_val = 0 ,
error_val = 65535,
value_multiplier = 0.1,
max_step_val = 500,
default_settings = false
where default_settings = true 
and symbol like 'essMaxWindGustS%';
  

 
update sensor_identity 
set max_val = 360,
min_val = 0 ,
error_val = 361,
max_step_val = 362,
value_multiplier = 1,
default_settings = false
where default_settings = true 
and symbol like 'essMaxWindGustD%';
  

 
update sensor_identity 
set max_val = 1000,
min_val = -1000 ,
error_val = 1001,
max_step_val = 100,
value_multiplier = 0.1,
default_settings = false
where default_settings = true 
and symbol like 'essAirT%';
  

 
update sensor_identity 
set max_val = 1000,
min_val = -1000 ,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essWetbulbT%';
  

 
update sensor_identity 
set max_val = 1000,
min_val = -1000 ,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essDewpointT%';
  

 
update sensor_identity 
set max_val = 1000,
min_val = -1000 ,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essMaxT%';
  

 
update sensor_identity 
set max_val = 1000,
min_val = -1000 ,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essMinT%';
  

 
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = 101,
value_multiplier = 1,
max_step_val = 20,
default_settings = false
where default_settings = true 
and symbol like 'essRelativeHumidity%';
  

 
update sensor_identity 
set max_val = 100,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 10,
default_settings = false
where default_settings = true 
and symbol like 'essWater%';
  

 
update sensor_identity 
set max_val = 3000,
min_val = 0 ,
error_val = 3001,
value_multiplier = 1,
default_settings = false
where default_settings = true 
and symbol like 'essAdj%';
  

 
update sensor_identity 
set max_val = 3000,
min_val = 0 ,
error_val = 3001,
value_multiplier = 1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essRoadwayS%';
  

 
update sensor_identity 
set max_val = 2,
min_val = 1 ,
error_val = 3,
value_multiplier = 1,
max_step_val = 3,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipY%';
  

 
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipR%';
  

 
update sensor_identity 
set max_val = 200,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essSnowfallAccum%';
  

 
update sensor_identity 
set max_val = 15,
min_val = 1 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 15,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipSit%';
  

 
update sensor_identity 
set max_val = 150,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 150,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipitationOne%';
  

 
update sensor_identity 
set max_val = 150,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 150,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipitationThree%';
  

 
update sensor_identity 
set max_val = 150,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 150,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipitationSix%';
  

 
update sensor_identity 
set max_val = 150,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 150,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipitation24%';
  

 
update sensor_identity 
set max_val = 150,
min_val = 0 ,
error_val = 65535,
value_multiplier = 1,
max_step_val = 150,
default_settings = false
where default_settings = true 
and symbol like 'essPrecipitationTwel%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceTemp%';
  

 
update sensor_identity
set min_val = 0,
max_val = 10,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 10,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceWaterLa%';
  

 
update sensor_identity
set min_val = 0,
max_val = 100,
error_val = 101,
value_multiplier = 1,
max_step_val = 20,
default_settings = false
where default_settings = true 
and symbol like 'spectroRelativeH%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceTemp%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceFreeze%';


update sensor_identity
set min_val = 1,
max_val = 14,
error_val = 2,
value_multiplier = 1,
max_step_val = 14,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceStatus%';
  
update sensor_identity
set min_val = 1,
max_val = 4,
error_val = 4,
value_multiplier = 1,
max_step_val = 4,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceBlackIceSignal%';


update sensor_identity
set min_val = 0,
max_val = 65535,
error_val = 65535,
value_multiplier = 1,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceSalinity%';


update sensor_identity
set min_val = 0,
max_val = 65535,
error_val = 65535,
value_multiplier = 1,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceConductivity%';


update sensor_identity
set min_val = 1,
max_val = 5,
error_val = 2,
value_multiplier = 1,
max_step_val = 5,
default_settings = false
where default_settings = true 
and symbol like 'essSubSurfaceSensorError%';


update sensor_identity
set min_val = 1,
max_val = 5,
error_val = 2,
value_multiplier = 1,
max_step_val = 5,
default_settings = false
where default_settings = true 
and symbol like 'essPavementSensorError%';

 
update sensor_identity
set min_val = 0,
max_val = 50000,
error_val = 1000001,
value_multiplier = 0.1,
max_step_val = 20001,
default_settings = false
where symbol like 'essVisibility.%';
  

 
update sensor_identity
set min_val = 1,
max_val = 12,
error_val = 0,
value_multiplier = 1,
max_step_val = 12,
default_settings = false
where default_settings = true 
and symbol like 'essVisibilitySituation.%';
  

 
update sensor_identity
set min_val = 0,
max_val = 100,
error_val = 101,
value_multiplier = 1,
max_step_val = 20,
default_settings = false
where default_settings = true 
and symbol like 'essSubSurfaceMoisture.%';
  

 
update sensor_identity
set min_val = 0,
max_val = 65534,
error_val = 65535,
value_multiplier = 1,
max_step_val = 10000,
default_settings = false
where default_settings = true 
and symbol like 'essSolarRadiation.%';
  

 
update sensor_identity
set min_val = 6000,
max_val = 15000,
error_val = 65535,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essAtmosphericPressure.%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'spectroAirTemp%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essSubSurfaceTemperature%';
  

 
update sensor_identity
set min_val = 0,
max_val = 1440,
error_val = 1441,
value_multiplier = 1,
max_step_val = 200,
default_settings = false
where default_settings = true 
and symbol like 'essTotalSun%';
  

 
update sensor_identity
set min_val = -1000,
max_val = 1000,
error_val = 1001,
value_multiplier = 0.1,
max_step_val = 100,
default_settings = false
where default_settings = true 
and symbol like 'essPavementTemperature%';
  

 
update sensor_identity
set min_val = 0,
max_val = 100,
error_val = 101,
value_multiplier = 0.01, -- Added by REC, 10-Dec-2013
max_step_val = 80,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceFrictionIndex%';
  

 
update sensor_identity
set min_val = 0,
max_val = 254,
error_val = 255,
value_multiplier = 1,
max_step_val = 25,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceWaterDepth%';
  

 
update sensor_identity
set min_val = 0,
max_val = 254,
error_val = 255,
value_multiplier = 1,
max_step_val = 25,
default_settings = false
where default_settings = true 
and symbol like 'essSurfaceWaterDepth%';
  

 
update sensor_identity
set min_val = 0,
max_val = 65534,
error_val = 65535,
value_multiplier = 0.01,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceIceLayer%';
  

 
update sensor_identity
set min_val = 0,
max_val = 65534,
error_val = 65535,
value_multiplier = 0.01,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceWaterLayer%';
  

 
update sensor_identity
set min_val = 0,
max_val = 65534,
error_val = 65535,
value_multiplier = 0.01,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceSnowLayer%';
  


update sensor_identity
set min_val = 0,
max_val = 309,
error_val = 65335,
value_multiplier = 1,
max_step_val = 1000,
default_settings = false
where default_settings = true 
and symbol like 'spectroSurfaceStatus%';$$;


ALTER FUNCTION public.set_ntcip_quality_thresholds() OWNER TO cloudwrite;

--
-- Name: set_quality_thresholds(); Type: FUNCTION; Schema: public; Owner: cloud
--

CREATE FUNCTION set_quality_thresholds() RETURNS void
    LANGUAGE plpgsql
    AS $$BEGIN
    perform set_ntcip_quality_thresholds();
    perform set_m14_quality_thresholds();

end$$;


ALTER FUNCTION public.set_quality_thresholds() OWNER TO cloud;

--
-- Name: test_xcheck_01(integer, integer, numeric, text, numeric); Type: FUNCTION; Schema: public; Owner: cloud
--

CREATE FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
  err_code integer := -12345;
  ttl interval := ''||ttl_minutes||' minutes';	-- convert minute integer to interval
  note_id integer;
  func_name text := 'test_xcheck_01';
  
BEGIN

RAISE NOTICE 'sensor_id = % | time to live = % | threshold = % | symbol = % value = %'
                            , sens_id, ttl, my_threshold, symbol, this_val;

-- comment out following line for testing
--    IF this_val >= my_threshold THEN RETURN 0; END IF;

-- do stuff ----------------------------------------------------------

   select notification_id into note_id from notification_test 
   where sensor_id = sens_id and function_name = func_name;   

RAISE NOTICE ' notification_id = %',note_id; 

   IF note_id IS NOT NULL THEN
      UPDATE notification_test SET last_updated = now() WHERE notification_id = note_id;
   ELSE
      INSERT INTO notification_test
      (sensor_id, nvalue, error_code, threshold, time_to_live, last_updated, function_name)
      VALUES(sens_id, this_val, err_code, my_threshold, ttl, now(), func_name);
   END IF;
   
 RETURN err_code;

END$$;


ALTER FUNCTION public.test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) OWNER TO cloud;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: alerts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE alerts (
    sensor_id integer,
    channel text,
    message text,
    entry_datetime timestamp without time zone DEFAULT now(),
    processed_datetime timestamp without time zone,
    id integer NOT NULL,
    alert_id text,
    target text,
    locbased boolean
);


ALTER TABLE public.alerts OWNER TO postgres;

--
-- Name: alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alerts_id_seq OWNER TO postgres;

--
-- Name: alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE alerts_id_seq OWNED BY alerts.id;


--
-- Name: check_queries; Type: TABLE; Schema: public; Owner: cloud; Tablespace: 
--

CREATE TABLE check_queries (
    entry_datetime timestamp without time zone,
    check_queries_id integer NOT NULL,
    query_name character varying(24),
    query_script character varying(1000)
);


ALTER TABLE public.check_queries OWNER TO cloud;

--
-- Name: check_queries_check_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: cloud
--

CREATE SEQUENCE check_queries_check_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.check_queries_check_queries_id_seq OWNER TO cloud;

--
-- Name: check_queries_check_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cloud
--

ALTER SEQUENCE check_queries_check_queries_id_seq OWNED BY check_queries.check_queries_id;


--
-- Name: error_codes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE error_codes (
    error_number integer NOT NULL,
    error_code character varying(24),
    error_type character varying(24),
    error_description character varying(200),
    entry_date date DEFAULT now() NOT NULL,
    added_by character varying(24)
);


ALTER TABLE public.error_codes OWNER TO postgres;

--
-- Name: last_reading; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE UNLOGGED TABLE last_reading (
    sensor_id integer NOT NULL,
    nvalue double precision DEFAULT 65335,
    last_datetime timestamp without time zone DEFAULT now() NOT NULL,
    status integer DEFAULT (-99999) NOT NULL
);


ALTER TABLE public.last_reading OWNER TO postgres;

--
-- Name: notification_test_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: cloud
--

CREATE SEQUENCE notification_test_notification_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notification_test_notification_id_seq OWNER TO cloud;

--
-- Name: notification_test; Type: TABLE; Schema: public; Owner: cloud; Tablespace: 
--

CREATE UNLOGGED TABLE notification_test (
    notification_id integer DEFAULT nextval('notification_test_notification_id_seq'::regclass) NOT NULL,
    sensor_id integer NOT NULL,
    nvalue double precision NOT NULL,
    error_code integer NOT NULL,
    threshold double precision NOT NULL,
    time_to_live interval NOT NULL,
    last_updated timestamp without time zone DEFAULT now() NOT NULL,
    function_name character varying(100) NOT NULL
);


ALTER TABLE public.notification_test OWNER TO cloud;

--
-- Name: sensor_identity; Type: TABLE; Schema: public; Owner: cloud; Tablespace: 
--

CREATE TABLE sensor_identity (
    entry_datetime time without time zone,
    sensor_id integer NOT NULL,
    station_id integer NOT NULL,
    symbol character varying(100) NOT NULL,
    blacklisted boolean DEFAULT false NOT NULL,
    max_val double precision DEFAULT 100 NOT NULL,
    min_val double precision DEFAULT (-100) NOT NULL,
    active_alm_val double precision DEFAULT 50 NOT NULL,
    cancel_alm_val double precision DEFAULT 40 NOT NULL,
    max_step_val double precision DEFAULT 10 NOT NULL,
    error_val integer DEFAULT 65535,
    min_repeat_val integer DEFAULT 30 NOT NULL,
    sensor_no integer NOT NULL,
    codespace integer NOT NULL,
    local_xcheck character varying(100),
    lane_no integer NOT NULL,
    remote_xcheck character varying(100),
    default_settings boolean DEFAULT true NOT NULL,
    value_multiplier double precision DEFAULT 1.00 NOT NULL
);


ALTER TABLE public.sensor_identity OWNER TO cloud;

--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE; Schema: public; Owner: cloud
--

CREATE SEQUENCE sensor_identity_sensor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sensor_identity_sensor_id_seq OWNER TO cloud;

--
-- Name: sensor_identity_sensor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cloud
--

ALTER SEQUENCE sensor_identity_sensor_id_seq OWNED BY sensor_identity.sensor_id;


--
-- Name: stage1; Type: TABLE; Schema: public; Owner: cloud; Tablespace: 
--

CREATE TABLE stage1 (
    entry_datetime timestamp without time zone,
    msg_datetime timestamp without time zone,
    stage1_id integer NOT NULL,
    station_id integer,
    sensor_id integer,
    nvalue double precision,
    sensor_no integer
);


ALTER TABLE public.stage1 OWNER TO cloud;

--
-- Name: stage1_stage1_id_seq; Type: SEQUENCE; Schema: public; Owner: cloud
--

CREATE SEQUENCE stage1_stage1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stage1_stage1_id_seq OWNER TO cloud;

--
-- Name: stage1_stage1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cloud
--

ALTER SEQUENCE stage1_stage1_id_seq OWNED BY stage1.stage1_id;


--
-- Name: station_identity; Type: TABLE; Schema: public; Owner: cloud; Tablespace: 
--

CREATE TABLE station_identity (
    entry_datetime timestamp without time zone,
    station_id integer NOT NULL,
    target_name character varying(100),
    blacklisted boolean
);


ALTER TABLE public.station_identity OWNER TO cloud;

--
-- Name: station_identity_station_id_seq; Type: SEQUENCE; Schema: public; Owner: cloud
--

CREATE SEQUENCE station_identity_station_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.station_identity_station_id_seq OWNER TO cloud;

--
-- Name: station_identity_station_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: cloud
--

ALTER SEQUENCE station_identity_station_id_seq OWNED BY station_identity.station_id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY alerts ALTER COLUMN id SET DEFAULT nextval('alerts_id_seq'::regclass);


--
-- Name: check_queries_id; Type: DEFAULT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY check_queries ALTER COLUMN check_queries_id SET DEFAULT nextval('check_queries_check_queries_id_seq'::regclass);


--
-- Name: sensor_id; Type: DEFAULT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY sensor_identity ALTER COLUMN sensor_id SET DEFAULT nextval('sensor_identity_sensor_id_seq'::regclass);


--
-- Name: stage1_id; Type: DEFAULT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY stage1 ALTER COLUMN stage1_id SET DEFAULT nextval('stage1_stage1_id_seq'::regclass);


--
-- Name: station_id; Type: DEFAULT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY station_identity ALTER COLUMN station_id SET DEFAULT nextval('station_identity_station_id_seq'::regclass);


--
-- Name: alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (id);


--
-- Name: check_queries_id_pkey; Type: CONSTRAINT; Schema: public; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY check_queries
    ADD CONSTRAINT check_queries_id_pkey PRIMARY KEY (check_queries_id);


--
-- Name: error_no_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY error_codes
    ADD CONSTRAINT error_no_pk PRIMARY KEY (error_number);


--
-- Name: last_reading_pk; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY last_reading
    ADD CONSTRAINT last_reading_pk PRIMARY KEY (sensor_id);


--
-- Name: notification_id_pk; Type: CONSTRAINT; Schema: public; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY notification_test
    ADD CONSTRAINT notification_id_pk PRIMARY KEY (notification_id);


--
-- Name: sensor_id_pkey; Type: CONSTRAINT; Schema: public; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT sensor_id_pkey PRIMARY KEY (sensor_id);


--
-- Name: stage1_id_pkey; Type: CONSTRAINT; Schema: public; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY stage1
    ADD CONSTRAINT stage1_id_pkey PRIMARY KEY (stage1_id);


--
-- Name: station_id_pkey; Type: CONSTRAINT; Schema: public; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY station_identity
    ADD CONSTRAINT station_id_pkey PRIMARY KEY (station_id);


--
-- Name: station_id_idx; Type: INDEX; Schema: public; Owner: cloud; Tablespace: 
--

CREATE INDEX station_id_idx ON sensor_identity USING btree (station_id);


--
-- Name: symbol_idx; Type: INDEX; Schema: public; Owner: cloud; Tablespace: 
--

CREATE INDEX symbol_idx ON sensor_identity USING btree (symbol);


--
-- Name: target_name_idx; Type: INDEX; Schema: public; Owner: cloud; Tablespace: 
--

CREATE INDEX target_name_idx ON station_identity USING btree (target_name);


--
-- Name: sensor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY stage1
    ADD CONSTRAINT sensor_id_fkey FOREIGN KEY (sensor_id) REFERENCES sensor_identity(sensor_id);


--
-- Name: station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY stage1
    ADD CONSTRAINT station_id_fkey FOREIGN KEY (station_id) REFERENCES station_identity(station_id);


--
-- Name: station_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: cloud
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT station_id_fkey FOREIGN KEY (station_id) REFERENCES station_identity(station_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: qm_cmp_2_values(numeric, numeric, numeric); Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) FROM cloud;
GRANT ALL ON FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) TO cloud;
GRANT ALL ON FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) TO PUBLIC;
GRANT ALL ON FUNCTION qm_cmp_2_values(this numeric, that numeric, threshold numeric) TO qualwrite;


--
-- Name: qm_jpctest3(integer, text, text, numeric); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) FROM postgres;
GRANT ALL ON FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) TO postgres;
GRANT ALL ON FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) TO PUBLIC;
GRANT ALL ON FUNCTION qm_jpctest3(sens_id integer, channel text, symbol text, test_value numeric) TO qualwrite;


--
-- Name: qm_local_xwind1(numeric, numeric, numeric); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) FROM postgres;
GRANT ALL ON FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) TO postgres;
GRANT ALL ON FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) TO PUBLIC;
GRANT ALL ON FUNCTION qm_local_xwind1(wind_speed numeric, wind_direction numeric, road_direction numeric) TO qualwrite;


--
-- Name: qm_surfstate(integer, text, text, numeric); Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) FROM cloud;
GRANT ALL ON FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) TO cloud;
GRANT ALL ON FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) TO PUBLIC;
GRANT ALL ON FUNCTION qm_surfstate(sens_id integer, ch_id text, symbol text, test_value numeric) TO qualwrite;


--
-- Name: set_m14_quality_thresholds(); Type: ACL; Schema: public; Owner: cloudwrite
--

REVOKE ALL ON FUNCTION set_m14_quality_thresholds() FROM PUBLIC;
REVOKE ALL ON FUNCTION set_m14_quality_thresholds() FROM cloudwrite;
GRANT ALL ON FUNCTION set_m14_quality_thresholds() TO cloudwrite;
GRANT ALL ON FUNCTION set_m14_quality_thresholds() TO PUBLIC;
GRANT ALL ON FUNCTION set_m14_quality_thresholds() TO qualwrite;


--
-- Name: set_ntcip_quality_thresholds(); Type: ACL; Schema: public; Owner: cloudwrite
--

REVOKE ALL ON FUNCTION set_ntcip_quality_thresholds() FROM PUBLIC;
REVOKE ALL ON FUNCTION set_ntcip_quality_thresholds() FROM cloudwrite;
GRANT ALL ON FUNCTION set_ntcip_quality_thresholds() TO cloudwrite;
GRANT ALL ON FUNCTION set_ntcip_quality_thresholds() TO PUBLIC;
GRANT ALL ON FUNCTION set_ntcip_quality_thresholds() TO qualwrite;


--
-- Name: set_quality_thresholds(); Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON FUNCTION set_quality_thresholds() FROM PUBLIC;
REVOKE ALL ON FUNCTION set_quality_thresholds() FROM cloud;
GRANT ALL ON FUNCTION set_quality_thresholds() TO cloud;
GRANT ALL ON FUNCTION set_quality_thresholds() TO PUBLIC;
GRANT ALL ON FUNCTION set_quality_thresholds() TO qualwrite;


--
-- Name: test_xcheck_01(integer, integer, numeric, text, numeric); Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) FROM cloud;
GRANT ALL ON FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) TO cloud;
GRANT ALL ON FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) TO PUBLIC;
GRANT ALL ON FUNCTION test_xcheck_01(sens_id integer, ttl_minutes integer, my_threshold numeric, symbol text, this_val numeric) TO qualwrite;


--
-- Name: alerts; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE alerts FROM PUBLIC;
REVOKE ALL ON TABLE alerts FROM postgres;
GRANT ALL ON TABLE alerts TO postgres;
GRANT ALL ON TABLE alerts TO qualwrite;
GRANT SELECT ON TABLE alerts TO nagios;


--
-- Name: alerts_id_seq; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON SEQUENCE alerts_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE alerts_id_seq FROM postgres;
GRANT ALL ON SEQUENCE alerts_id_seq TO postgres;
GRANT ALL ON SEQUENCE alerts_id_seq TO qualwrite;


--
-- Name: check_queries; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON TABLE check_queries FROM PUBLIC;
REVOKE ALL ON TABLE check_queries FROM cloud;
GRANT ALL ON TABLE check_queries TO cloud;
GRANT ALL ON TABLE check_queries TO qualwrite;


--
-- Name: check_queries_check_queries_id_seq; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON SEQUENCE check_queries_check_queries_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE check_queries_check_queries_id_seq FROM cloud;
GRANT ALL ON SEQUENCE check_queries_check_queries_id_seq TO cloud;
GRANT ALL ON SEQUENCE check_queries_check_queries_id_seq TO qualwrite;


--
-- Name: error_codes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE error_codes FROM PUBLIC;
REVOKE ALL ON TABLE error_codes FROM postgres;
GRANT ALL ON TABLE error_codes TO postgres;
GRANT ALL ON TABLE error_codes TO qualwrite;


--
-- Name: last_reading; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE last_reading FROM PUBLIC;
REVOKE ALL ON TABLE last_reading FROM postgres;
GRANT ALL ON TABLE last_reading TO postgres;
GRANT ALL ON TABLE last_reading TO qualwrite;


--
-- Name: notification_test_notification_id_seq; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON SEQUENCE notification_test_notification_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE notification_test_notification_id_seq FROM cloud;
GRANT ALL ON SEQUENCE notification_test_notification_id_seq TO cloud;
GRANT ALL ON SEQUENCE notification_test_notification_id_seq TO qualwrite;


--
-- Name: notification_test; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON TABLE notification_test FROM PUBLIC;
REVOKE ALL ON TABLE notification_test FROM cloud;
GRANT ALL ON TABLE notification_test TO cloud;
GRANT ALL ON TABLE notification_test TO qualwrite;


--
-- Name: sensor_identity; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON TABLE sensor_identity FROM PUBLIC;
REVOKE ALL ON TABLE sensor_identity FROM cloud;
GRANT ALL ON TABLE sensor_identity TO cloud;
GRANT ALL ON TABLE sensor_identity TO qualwrite;


--
-- Name: sensor_identity_sensor_id_seq; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq FROM cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq TO cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq TO qualwrite;


--
-- Name: stage1; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON TABLE stage1 FROM PUBLIC;
REVOKE ALL ON TABLE stage1 FROM cloud;
GRANT ALL ON TABLE stage1 TO cloud;
GRANT ALL ON TABLE stage1 TO qualwrite;


--
-- Name: stage1_stage1_id_seq; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON SEQUENCE stage1_stage1_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE stage1_stage1_id_seq FROM cloud;
GRANT ALL ON SEQUENCE stage1_stage1_id_seq TO cloud;
GRANT ALL ON SEQUENCE stage1_stage1_id_seq TO qualwrite;


--
-- Name: station_identity; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON TABLE station_identity FROM PUBLIC;
REVOKE ALL ON TABLE station_identity FROM cloud;
GRANT ALL ON TABLE station_identity TO cloud;
GRANT ALL ON TABLE station_identity TO qualwrite;


--
-- Name: station_identity_station_id_seq; Type: ACL; Schema: public; Owner: cloud
--

REVOKE ALL ON SEQUENCE station_identity_station_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_identity_station_id_seq FROM cloud;
GRANT ALL ON SEQUENCE station_identity_station_id_seq TO cloud;
GRANT ALL ON SEQUENCE station_identity_station_id_seq TO qualwrite;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO qualwrite;


--
-- PostgreSQL database dump complete
--

