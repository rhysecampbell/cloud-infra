-- Function: set_m14_quality_thresholds()

-- DROP FUNCTION set_m14_quality_thresholds();

CREATE OR REPLACE FUNCTION set_m14_quality_thresholds()
  RETURNS void AS
$BODY$

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
max_step_val = 20000,
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


$BODY$
  LANGUAGE sql VOLATILE STRICT
  COST 100;
ALTER FUNCTION set_m14_quality_thresholds()
  OWNER TO cloudwrite;
GRANT EXECUTE ON FUNCTION set_m14_quality_thresholds() TO cloudwrite;
GRANT EXECUTE ON FUNCTION set_m14_quality_thresholds() TO public;
GRANT EXECUTE ON FUNCTION set_m14_quality_thresholds() TO qualwrite;

SELECT set_m14_quality_thresholds();
