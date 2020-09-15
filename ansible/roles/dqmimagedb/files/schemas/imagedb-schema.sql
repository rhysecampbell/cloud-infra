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
-- Name: qm; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA qm;


ALTER SCHEMA qm OWNER TO postgres;

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


--
-- Name: postgres_fdw; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA qm;


--
-- Name: EXTENSION postgres_fdw; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';


SET search_path = qm, pg_catalog;

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
command_str = concat('select qm.new_creation_week(''',start_date, ''',''',end_date,''');');

-- run command
execute command_str;

RAISE NOTICE 'add data command %', command_str;

--*********************************************************************************************


-- Now drop old partitions ----
-- MUST be run on a Monday and be multiples of 7 days to match the partition date.

drop_date = TO_CHAR(localtimestamp - '14 days'::interval, 'YYYY_MM_DD');


execute 'truncate table qm.roadimage_' || drop_date || '';
execute 'drop table qm.roadimage_' || drop_date || ''; 

analyse;

RAISE NOTICE 'Dropped old roadimage partitions [%]', drop_date;

RETURN TRUE;

END$$;


ALTER FUNCTION qm.manage_partition() OWNER TO postgres;

--
-- Name: new_creation_week(date, date); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION new_creation_week(date, date) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
	create_query text;
	index_query text;
	index_query2 text;
	index_query3 text;
BEGIN
	FOR create_query, index_query, index_query2, index_query3 IN SELECT
			'create table qm.roadimage_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( CONSTRAINT no_duplicates_' || TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' UNIQUE (mes_datetime, stn_id,cam_no),
			
			      CONSTRAINT roadimage_'
			|| TO_CHAR( d, 'YYYY_MM_DD' ) || '_pkey'
			|| ' PRIMARY KEY (image_id),'
			|| '  check( mes_datetime >= date '''
			
			|| TO_CHAR( d, 'YYYY-MM-DD' )
			|| ''' and mes_datetime < date '''
			|| TO_CHAR( d + INTERVAL '1 week', 'YYYY-MM-DD' )
			|| ''' ) ) inherits ( qm.roadimage );',
			'create index roadimage_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_time_idx on qm.roadimage_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( mes_datetime);',
			'create index roadimage_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_entry_idx on qm.roadimage_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' ( entry_datetime);',			
			'create index roadimage_'
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| '_stn_id_idx on qm.roadimage_' 
			|| TO_CHAR( d, 'YYYY_MM_DD' )
			|| ' (stn_id) ;'

			
   		FROM generate_series( $1, $2, '1 week' ) AS d
        loop
		EXECUTE create_query;
		EXECUTE index_query;
		EXECUTE index_query2;
		EXECUTE index_query3;
	END LOOP;
END;
$_$;


ALTER FUNCTION qm.new_creation_week(date, date) OWNER TO postgres;

--
-- Name: roadimage_insert_trigger_week(); Type: FUNCTION; Schema: qm; Owner: postgres
--

CREATE FUNCTION roadimage_insert_trigger_week() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
declare

    last_w date 		:= date_trunc('week', now() - '1 week'::interval);
    cur_w date 			:= date_trunc('week', now());      
    plus1_w date 		:= date_trunc('week', now() + '1 week'::interval);
    plus2_w date 		:= date_trunc('week', now() + '2 week'::interval);
    
    cur_file text;

BEGIN
        IF ( NEW.mes_datetime >= cur_w AND NEW.mes_datetime < plus1_w ) THEN 
	        cur_file:= 'qm.roadimage_' || to_char(cur_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW; 
	ELSIF ( NEW.mes_datetime >= plus1_w AND NEW.mes_datetime < plus2_w ) THEN 
	        cur_file:= 'qm.roadimage_' || to_char(plus1_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;		
	ELSIF ( NEW.mes_datetime >= last_w AND NEW.mes_datetime < cur_w ) THEN 
	        cur_file:= 'qm.roadimage_' || to_char(last_w, 'YYYY_MM_DD');
		EXECUTE 'INSERT INTO ' || cur_file || ' SELECT ($1.*)'
		using NEW;				
	ELSE
		RAISE EXCEPTION 'Date out of range.  Something wrong with the roadimage_insert_trigger_week() function!';
	END IF;
	RETURN NULL;
END;
$_$;


ALTER FUNCTION qm.roadimage_insert_trigger_week() OWNER TO postgres;

--
-- Name: qual_service; Type: SERVER; Schema: -; Owner: postgres
--

CREATE SERVER qual_service FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'qualmon2',
    host '192.168.13.6',
    port '5432'
);


ALTER SERVER qual_service OWNER TO postgres;

--
-- Name: USER MAPPING postgres SERVER qual_service; Type: USER MAPPING; Schema: -; Owner: postgres
--

CREATE USER MAPPING FOR postgres SERVER qual_service OPTIONS (
    password 'va15a1a',
    "user" 'postgres'
);


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: identity; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE identity (
    entry_datetime timestamp without time zone DEFAULT now() NOT NULL,
    cat_id integer NOT NULL,
    indentity_id integer NOT NULL,
    station_name character varying(100) NOT NULL,
    cam_no integer NOT NULL,
    image_target_name character varying(100),
    stn_id integer DEFAULT (-1) NOT NULL,
    cam_enabled boolean DEFAULT true NOT NULL,
    last_image_size integer DEFAULT 0 NOT NULL,
    image_update_period integer DEFAULT 20 NOT NULL,
    missing_image_count integer DEFAULT 0 NOT NULL,
    dqm_stn_id integer DEFAULT 0 NOT NULL,
    dqm_lat double precision,
    dqm_lon double precision,
    dqm_alt real,
    dqm_region_id character varying(2),
    dqm_country_id character varying(2),
    dqm_org_id character varying(100),
    dqm_owning_region_id integer,
    dqm_xml_target_name character varying(100),
    last_image_time timestamp without time zone,
    image_status integer,
    last_image_detail double precision DEFAULT (-1) NOT NULL,
    last_image_variance double precision DEFAULT (-1) NOT NULL,
    last_image_mean double precision DEFAULT (-1) NOT NULL,
    last_image_trace double precision DEFAULT (-1) NOT NULL
);


ALTER TABLE qm.identity OWNER TO postgres;

--
-- Name: identity_indentity_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE identity_indentity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.identity_indentity_id_seq OWNER TO postgres;

--
-- Name: identity_indentity_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE identity_indentity_id_seq OWNED BY identity.indentity_id;


--
-- Name: roadimage; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE roadimage (
    image_id bigint NOT NULL,
    image bytea NOT NULL,
    thumb bytea,
    icon bytea,
    stn_id integer NOT NULL,
    entry_datetime timestamp with time zone NOT NULL,
    mes_datetime timestamp without time zone NOT NULL,
    raw_image_size integer DEFAULT (-100) NOT NULL,
    cam_no integer,
    thumb_vsize smallint,
    thumb_hsize smallint,
    image_vsize smallint NOT NULL,
    image_hsize smallint NOT NULL,
    icon_vsize smallint,
    icon_hsize smallint,
    image_detail real DEFAULT 0 NOT NULL,
    image_mean real DEFAULT 0 NOT NULL,
    image_variance real DEFAULT 0 NOT NULL,
    image_trace real DEFAULT 0 NOT NULL,
    image_status smallint DEFAULT 0 NOT NULL
);


ALTER TABLE qm.roadimage OWNER TO postgres;

--
-- Name: roadimage_2015_04_20; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE roadimage_2015_04_20 (
    CONSTRAINT roadimage_2015_04_20_mes_datetime_check CHECK (((mes_datetime >= '2015-04-20'::date) AND (mes_datetime < '2015-04-27'::date)))
)
INHERITS (roadimage);


ALTER TABLE qm.roadimage_2015_04_20 OWNER TO postgres;

--
-- Name: roadimage_2015_04_27; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE roadimage_2015_04_27 (
    CONSTRAINT roadimage_2015_04_27_mes_datetime_check CHECK (((mes_datetime >= '2015-04-27'::date) AND (mes_datetime < '2015-05-04'::date)))
)
INHERITS (roadimage);


ALTER TABLE qm.roadimage_2015_04_27 OWNER TO postgres;

--
-- Name: roadimage_2015_05_04; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE roadimage_2015_05_04 (
    CONSTRAINT roadimage_2015_05_04_mes_datetime_check CHECK (((mes_datetime >= '2015-05-04'::date) AND (mes_datetime < '2015-05-11'::date)))
)
INHERITS (roadimage);


ALTER TABLE qm.roadimage_2015_05_04 OWNER TO postgres;

--
-- Name: roadimage_image_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE roadimage_image_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.roadimage_image_id_seq OWNER TO postgres;

--
-- Name: roadimage_image_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE roadimage_image_id_seq OWNED BY roadimage.image_id;


--
-- Name: station_alias; Type: FOREIGN TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE station_alias (
    stn_alias_id integer NOT NULL,
    v_region_id integer NOT NULL,
    stn_id integer NOT NULL,
    comments character varying(300),
    creation_date date DEFAULT now() NOT NULL,
    fault_detection_minutes smallint
)
SERVER qual_service;


ALTER FOREIGN TABLE qm.station_alias OWNER TO postgres;

--
-- Name: station_alias_identity; Type: FOREIGN TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE station_alias_identity (
    v_region_id integer NOT NULL,
    v_region_name character varying(200) NOT NULL,
    creation_date date DEFAULT now() NOT NULL,
    display_name character varying(200),
    ebs_party_id integer,
    ebs_acct_nbr integer,
    fault_detection_minutes smallint,
    monitored boolean DEFAULT true,
    v_region_code character varying(2)
)
SERVER qual_service;


ALTER FOREIGN TABLE qm.station_alias_identity OWNER TO postgres;

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
-- Name: station_blacklist; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE station_blacklist (
    entry_datetime timestamp without time zone DEFAULT now() NOT NULL,
    image_target_name character varying(100) NOT NULL,
    blacklist_id integer NOT NULL,
    blacklist_type smallint NOT NULL
);


ALTER TABLE qm.station_blacklist OWNER TO postgres;

--
-- Name: station_blacklist_blacklist_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE station_blacklist_blacklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.station_blacklist_blacklist_id_seq OWNER TO postgres;

--
-- Name: station_blacklist_blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE station_blacklist_blacklist_id_seq OWNED BY station_blacklist.blacklist_id;


--
-- Name: station_identity; Type: FOREIGN TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE FOREIGN TABLE station_identity (
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
    geom public.geometry(Point,4326)
)
SERVER qual_service;


ALTER FOREIGN TABLE qm.station_identity OWNER TO postgres;

--
-- Name: status_codes; Type: TABLE; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE TABLE status_codes (
    status_code_id integer NOT NULL,
    code integer NOT NULL,
    code_description character varying(200) NOT NULL
);


ALTER TABLE qm.status_codes OWNER TO postgres;

--
-- Name: status_codes_status_code_id_seq; Type: SEQUENCE; Schema: qm; Owner: postgres
--

CREATE SEQUENCE status_codes_status_code_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE qm.status_codes_status_code_id_seq OWNER TO postgres;

--
-- Name: status_codes_status_code_id_seq; Type: SEQUENCE OWNED BY; Schema: qm; Owner: postgres
--

ALTER SEQUENCE status_codes_status_code_id_seq OWNED BY status_codes.status_code_id;


--
-- Name: indentity_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY identity ALTER COLUMN indentity_id SET DEFAULT nextval('identity_indentity_id_seq'::regclass);


--
-- Name: image_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage ALTER COLUMN image_id SET DEFAULT nextval('roadimage_image_id_seq'::regclass);


--
-- Name: image_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_id SET DEFAULT nextval('roadimage_image_id_seq'::regclass);


--
-- Name: raw_image_size; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN raw_image_size SET DEFAULT (-100);


--
-- Name: image_detail; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_detail SET DEFAULT 0;


--
-- Name: image_mean; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_mean SET DEFAULT 0;


--
-- Name: image_variance; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_variance SET DEFAULT 0;


--
-- Name: image_trace; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_trace SET DEFAULT 0;


--
-- Name: image_status; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_20 ALTER COLUMN image_status SET DEFAULT 0;


--
-- Name: image_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_id SET DEFAULT nextval('roadimage_image_id_seq'::regclass);


--
-- Name: raw_image_size; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN raw_image_size SET DEFAULT (-100);


--
-- Name: image_detail; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_detail SET DEFAULT 0;


--
-- Name: image_mean; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_mean SET DEFAULT 0;


--
-- Name: image_variance; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_variance SET DEFAULT 0;


--
-- Name: image_trace; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_trace SET DEFAULT 0;


--
-- Name: image_status; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_04_27 ALTER COLUMN image_status SET DEFAULT 0;


--
-- Name: image_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_id SET DEFAULT nextval('roadimage_image_id_seq'::regclass);


--
-- Name: raw_image_size; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN raw_image_size SET DEFAULT (-100);


--
-- Name: image_detail; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_detail SET DEFAULT 0;


--
-- Name: image_mean; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_mean SET DEFAULT 0;


--
-- Name: image_variance; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_variance SET DEFAULT 0;


--
-- Name: image_trace; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_trace SET DEFAULT 0;


--
-- Name: image_status; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY roadimage_2015_05_04 ALTER COLUMN image_status SET DEFAULT 0;


--
-- Name: stn_alias_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias ALTER COLUMN stn_alias_id SET DEFAULT nextval('station_alias_stn_alias_id_seq'::regclass);


--
-- Name: v_region_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_alias_identity ALTER COLUMN v_region_id SET DEFAULT nextval('station_alias_identity_v_region_id_seq'::regclass);


--
-- Name: blacklist_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY station_blacklist ALTER COLUMN blacklist_id SET DEFAULT nextval('station_blacklist_blacklist_id_seq'::regclass);


--
-- Name: status_code_id; Type: DEFAULT; Schema: qm; Owner: postgres
--

ALTER TABLE ONLY status_codes ALTER COLUMN status_code_id SET DEFAULT nextval('status_codes_status_code_id_seq'::regclass);


--
-- Name: blacklist_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_blacklist
    ADD CONSTRAINT blacklist_pk PRIMARY KEY (blacklist_id);


--
-- Name: identity_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY identity
    ADD CONSTRAINT identity_pkey PRIMARY KEY (indentity_id);


--
-- Name: no_duplicates_2015_04_20; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_04_20
    ADD CONSTRAINT no_duplicates_2015_04_20 UNIQUE (mes_datetime, stn_id, cam_no);


--
-- Name: no_duplicates_2015_04_27; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_04_27
    ADD CONSTRAINT no_duplicates_2015_04_27 UNIQUE (mes_datetime, stn_id, cam_no);


--
-- Name: no_duplicates_2015_05_04; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_05_04
    ADD CONSTRAINT no_duplicates_2015_05_04 UNIQUE (mes_datetime, stn_id, cam_no);


--
-- Name: roadimage_2015_04_20_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_04_20
    ADD CONSTRAINT roadimage_2015_04_20_pkey PRIMARY KEY (image_id);


--
-- Name: roadimage_2015_04_27_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_04_27
    ADD CONSTRAINT roadimage_2015_04_27_pkey PRIMARY KEY (image_id);


--
-- Name: roadimage_2015_05_04_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage_2015_05_04
    ADD CONSTRAINT roadimage_2015_05_04_pkey PRIMARY KEY (image_id);


--
-- Name: roadimage_pkey; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY roadimage
    ADD CONSTRAINT roadimage_pkey PRIMARY KEY (image_id);


--
-- Name: station_blacklist_image_target_name_key; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY station_blacklist
    ADD CONSTRAINT station_blacklist_image_target_name_key UNIQUE (image_target_name);


--
-- Name: status_code_pk; Type: CONSTRAINT; Schema: qm; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY status_codes
    ADD CONSTRAINT status_code_pk PRIMARY KEY (status_code_id);


--
-- Name: blacklist_image_name_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX blacklist_image_name_idx ON station_blacklist USING btree (image_target_name);


--
-- Name: dmq_stn_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX dmq_stn_id_idx ON identity USING btree (dqm_stn_id);


--
-- Name: dqm_xml_target_name_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX dqm_xml_target_name_idx ON identity USING btree (dqm_xml_target_name);


--
-- Name: image_target_name.idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX "image_target_name.idx" ON identity USING btree (image_target_name);


--
-- Name: roadimage_2015_04_20_entry_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_20_entry_idx ON roadimage_2015_04_20 USING btree (entry_datetime);


--
-- Name: roadimage_2015_04_20_stn_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_20_stn_id_idx ON roadimage_2015_04_20 USING btree (stn_id);


--
-- Name: roadimage_2015_04_20_time_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_20_time_idx ON roadimage_2015_04_20 USING btree (mes_datetime);


--
-- Name: roadimage_2015_04_27_entry_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_27_entry_idx ON roadimage_2015_04_27 USING btree (entry_datetime);


--
-- Name: roadimage_2015_04_27_stn_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_27_stn_id_idx ON roadimage_2015_04_27 USING btree (stn_id);


--
-- Name: roadimage_2015_04_27_time_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_04_27_time_idx ON roadimage_2015_04_27 USING btree (mes_datetime);


--
-- Name: roadimage_2015_05_04_entry_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_05_04_entry_idx ON roadimage_2015_05_04 USING btree (entry_datetime);


--
-- Name: roadimage_2015_05_04_stn_id_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_05_04_stn_id_idx ON roadimage_2015_05_04 USING btree (stn_id);


--
-- Name: roadimage_2015_05_04_time_idx; Type: INDEX; Schema: qm; Owner: postgres; Tablespace: 
--

CREATE INDEX roadimage_2015_05_04_time_idx ON roadimage_2015_05_04 USING btree (mes_datetime);


--
-- Name: roadimage_partition_trigger; Type: TRIGGER; Schema: qm; Owner: postgres
--

CREATE TRIGGER roadimage_partition_trigger BEFORE INSERT ON roadimage FOR EACH ROW EXECUTE PROCEDURE roadimage_insert_trigger_week();


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: identity; Type: ACL; Schema: qm; Owner: postgres
--

REVOKE ALL ON TABLE identity FROM PUBLIC;
REVOKE ALL ON TABLE identity FROM postgres;
GRANT ALL ON TABLE identity TO postgres;


--
-- Name: roadimage; Type: ACL; Schema: qm; Owner: postgres
--

REVOKE ALL ON TABLE roadimage FROM PUBLIC;
REVOKE ALL ON TABLE roadimage FROM postgres;
GRANT ALL ON TABLE roadimage TO postgres;


--
-- Name: station_blacklist; Type: ACL; Schema: qm; Owner: postgres
--

REVOKE ALL ON TABLE station_blacklist FROM PUBLIC;
REVOKE ALL ON TABLE station_blacklist FROM postgres;
GRANT ALL ON TABLE station_blacklist TO postgres;


--
-- PostgreSQL database dump complete
--

