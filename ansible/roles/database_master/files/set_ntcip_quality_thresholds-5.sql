-- Function: set_ntcip_quality_thresholds()

-- DROP FUNCTION set_ntcip_quality_thresholds();

CREATE OR REPLACE FUNCTION set_ntcip_quality_thresholds()
  RETURNS void AS
$BODY$

 
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
max_val = 1000000,
error_val = 1000001,
value_multiplier = 0.1,
max_step_val = 1000000,
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
and symbol like 'spectroSurfaceStatus%';$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
ALTER FUNCTION set_ntcip_quality_thresholds()
  OWNER TO cloudwrite;
GRANT EXECUTE ON FUNCTION set_ntcip_quality_thresholds() TO cloudwrite;
GRANT EXECUTE ON FUNCTION set_ntcip_quality_thresholds() TO public;
GRANT EXECUTE ON FUNCTION set_ntcip_quality_thresholds() TO qualwrite;

SELECT set_ntcip_quality_thresholds();
