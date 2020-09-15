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
-- Name: forecast; Type: COMMENT; Schema: -; Owner: cloud
--

COMMENT ON DATABASE forecast IS 'forecast database currently supports UKMO datapoint';


--
-- Name: oe; Type: SCHEMA; Schema: -; Owner: cloudwrite
--

CREATE SCHEMA oe;


ALTER SCHEMA oe OWNER TO cloudwrite;

--
-- Name: SCHEMA oe; Type: COMMENT; Schema: -; Owner: cloudwrite
--

COMMENT ON SCHEMA oe IS 'Observation Engine schema (modified)';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = oe, pg_catalog;

--
-- Name: data_insert_trigger_func(); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION data_insert_trigger_func() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare

    last_d date 		:= date_trunc('day', now() - '1 day'::interval);
    cur_d date 			:= date_trunc('day', now());      
    plus1_d date 		:= date_trunc('day', now() + '1 day'::interval);
    plus2_d date 		:= date_trunc('day', now() + '2 day'::interval);
    plus3_d date 		:= date_trunc('day', now() + '3 day'::interval);
    plus4_d date 		:= date_trunc('day', now() + '4 day'::interval);
    plus5_d date 		:= date_trunc('day', now() + '6 day'::interval);
    plus6_d date 		:= date_trunc('day', now() + '6 day'::interval);
    
    
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
	ELSIF ( NEW.creationtime >= plus2_d AND NEW.creationtime < plus3_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(plus2_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;	
	ELSIF ( NEW.creationtime >= plus3_d AND NEW.creationtime < plus4_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(plus3_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;	
	ELSIF ( NEW.creationtime >= plus4_d AND NEW.creationtime < plus5_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(plus4_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;
	ELSIF ( NEW.creationtime >= plus5_d AND NEW.creationtime < plus6_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(plus5_d, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;			
	ELSIF ( NEW.creationtime >= last_d AND NEW.creationtime < cur_d ) THEN 
	        cur_file:= 'oe.data_value_' || to_char(last_d, 'YYYY_MM_DD');
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
-- Name: manage_partitions(); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION manage_partitions() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	old_partition text;
	new_partition text;
	old_date date := current_date - '1 day'::interval;
	new_date date := current_date + '6 days'::interval;
BEGIN
  begin
-- simple function to drop yesterday's partition 
-- and create new partition March 2014 BJT

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
-- Name: new_creation_day(date, date); Type: FUNCTION; Schema: oe; Owner: cloud
--

CREATE FUNCTION new_creation_day(date, date) RETURNS void
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
			|| ' PRIMARY KEY (creationtime,sensor_id,forecast_created),'
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

			
   		FROM generate_series( $1, $2, '1 day' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
	END LOOP;
END;
$_$;


ALTER FUNCTION oe.new_creation_day(date, date) OWNER TO cloud;

--
-- Name: seq_data_value_id; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE seq_data_value_id
    START WITH 191907230
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
    nvalue_str character varying(300),
    forecast_created timestamp without time zone NOT NULL
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
-- Name: sensor_identity_sensor_id_seq1; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE sensor_identity_sensor_id_seq1
    START WITH 283212
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.sensor_identity_sensor_id_seq1 OWNER TO cloud;

--
-- Name: sensor_identity; Type: TABLE; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE TABLE sensor_identity (
    sensor_id integer DEFAULT nextval('sensor_identity_sensor_id_seq1'::regclass) NOT NULL,
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
-- Name: station_identity_stn_id_seq1; Type: SEQUENCE; Schema: oe; Owner: cloud
--

CREATE SEQUENCE station_identity_stn_id_seq1
    START WITH 28589
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE oe.station_identity_stn_id_seq1 OWNER TO cloud;

--
-- Name: data_value_creationtime_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY data_value
    ADD CONSTRAINT data_value_creationtime_pk PRIMARY KEY (creationtime, sensor_id);


--
-- Name: sensor_identity_sensor_id_pk; Type: CONSTRAINT; Schema: oe; Owner: cloud; Tablespace: 
--

ALTER TABLE ONLY sensor_identity
    ADD CONSTRAINT sensor_identity_sensor_id_pk PRIMARY KEY (sensor_id);


--
-- Name: sensor_identity_stn_id_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX sensor_identity_stn_id_idx ON sensor_identity USING btree (stn_id);


--
-- Name: sensor_identity_symbol_idx; Type: INDEX; Schema: oe; Owner: cloud; Tablespace: 
--

CREATE INDEX sensor_identity_symbol_idx ON sensor_identity USING btree (symbol);


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
-- Name: oe; Type: ACL; Schema: -; Owner: cloudwrite
--

REVOKE ALL ON SCHEMA oe FROM PUBLIC;
REVOKE ALL ON SCHEMA oe FROM cloudwrite;
GRANT USAGE ON SCHEMA oe TO forecastwrite;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: data_insert_trigger_func(); Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON FUNCTION data_insert_trigger_func() FROM PUBLIC;
REVOKE ALL ON FUNCTION data_insert_trigger_func() FROM cloud;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO cloud;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO PUBLIC;
GRANT ALL ON FUNCTION data_insert_trigger_func() TO forecastwrite;


--
-- Name: seq_data_value_id; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE seq_data_value_id FROM PUBLIC;
REVOKE ALL ON SEQUENCE seq_data_value_id FROM cloud;
GRANT ALL ON SEQUENCE seq_data_value_id TO cloud;
GRANT ALL ON SEQUENCE seq_data_value_id TO forecastwrite;


--
-- Name: data_value; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE data_value FROM PUBLIC;
REVOKE ALL ON TABLE data_value FROM cloud;
GRANT ALL ON TABLE data_value TO cloud;
GRANT SELECT,INSERT,TRIGGER,UPDATE ON TABLE data_value TO forecastwrite;


--
-- Name: sensor_identity_sensor_id_seq1; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE sensor_identity_sensor_id_seq1 FROM cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq1 TO cloud;
GRANT ALL ON SEQUENCE sensor_identity_sensor_id_seq1 TO forecastwrite;


--
-- Name: sensor_identity; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON TABLE sensor_identity FROM PUBLIC;
REVOKE ALL ON TABLE sensor_identity FROM cloud;
GRANT ALL ON TABLE sensor_identity TO cloud;
GRANT SELECT,INSERT,TRIGGER,UPDATE ON TABLE sensor_identity TO forecastwrite;


--
-- Name: station_identity_stn_id_seq1; Type: ACL; Schema: oe; Owner: cloud
--

REVOKE ALL ON SEQUENCE station_identity_stn_id_seq1 FROM PUBLIC;
REVOKE ALL ON SEQUENCE station_identity_stn_id_seq1 FROM cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq1 TO cloud;
GRANT ALL ON SEQUENCE station_identity_stn_id_seq1 TO forecastwrite;


--
-- PostgreSQL database dump complete
--

