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
-- Name: dynamic; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA dynamic;


ALTER SCHEMA dynamic OWNER TO postgres;

--
-- Name: static; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA static;


ALTER SCHEMA static OWNER TO postgres;

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


SET search_path = dynamic, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: custom; Type: TABLE; Schema: dynamic; Owner: writer; Tablespace: 
--

CREATE TABLE custom (
    cname character varying(80),
    cid character varying(8),
    poly character varying(512)
);


ALTER TABLE dynamic.custom OWNER TO writer;

--
-- Name: nwsalerts; Type: TABLE; Schema: dynamic; Owner: writer; Tablespace: 
--

CREATE TABLE nwsalerts (
    gid integer NOT NULL,
    geom public.geometry(MultiPolygon),
    exptime integer,
    ugcstring character varying(1024),
    alerttype character varying(2),
    alertseverity character varying(1),
    alertstate character varying(3),
    text character varying(16000),
    fid double precision,
    alertcategory character varying(3)
);


ALTER TABLE dynamic.nwsalerts OWNER TO writer;

--
-- Name: nwsalerts_gid_seq; Type: SEQUENCE; Schema: dynamic; Owner: writer
--

CREATE SEQUENCE nwsalerts_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dynamic.nwsalerts_gid_seq OWNER TO writer;

--
-- Name: nwsalerts_gid_seq; Type: SEQUENCE OWNED BY; Schema: dynamic; Owner: writer
--

ALTER SEQUENCE nwsalerts_gid_seq OWNED BY nwsalerts.gid;


SET search_path = static, pg_catalog;

--
-- Name: irelandzones; Type: TABLE; Schema: static; Owner: postgres; Tablespace: 
--

CREATE TABLE irelandzones (
    gid integer NOT NULL,
    objectid integer,
    county character varying(100),
    shape_leng numeric,
    shape_area numeric,
    geom public.geometry(MultiPolygon,4269),
    zoneid character varying(3),
    zonename character varying(64)
);


ALTER TABLE static.irelandzones OWNER TO postgres;

--
-- Name: irelandzones_gid_seq; Type: SEQUENCE; Schema: static; Owner: postgres
--

CREATE SEQUENCE irelandzones_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE static.irelandzones_gid_seq OWNER TO postgres;

--
-- Name: irelandzones_gid_seq; Type: SEQUENCE OWNED BY; Schema: static; Owner: postgres
--

ALTER SEQUENCE irelandzones_gid_seq OWNED BY irelandzones.gid;


--
-- Name: nwspubliczones; Type: TABLE; Schema: static; Owner: postgres; Tablespace: 
--

CREATE TABLE nwspubliczones (
    gid integer NOT NULL,
    state character varying(2),
    cwa character varying(9),
    time_zone character varying(2),
    fe_area character varying(2),
    zone character varying(3),
    name character varying(254),
    state_zone character varying(5),
    lon numeric,
    lat numeric,
    shortname character varying(32),
    geom public.geometry(MultiPolygon)
);


ALTER TABLE static.nwspubliczones OWNER TO postgres;

--
-- Name: nwspubliczones_gid_seq; Type: SEQUENCE; Schema: static; Owner: postgres
--

CREATE SEQUENCE nwspubliczones_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE static.nwspubliczones_gid_seq OWNER TO postgres;

--
-- Name: nwspubliczones_gid_seq; Type: SEQUENCE OWNED BY; Schema: static; Owner: postgres
--

ALTER SEQUENCE nwspubliczones_gid_seq OWNED BY nwspubliczones.gid;


--
-- Name: ukzones; Type: TABLE; Schema: static; Owner: postgres; Tablespace: 
--

CREATE TABLE ukzones (
    gid integer NOT NULL,
    name character varying(60),
    area_code character varying(3),
    descriptio character varying(50),
    file_name character varying(50),
    number double precision,
    number0 double precision,
    polygon_id double precision,
    unit_id double precision,
    code character varying(9),
    hectares double precision,
    area double precision,
    type_code character varying(2),
    descript0 character varying(25),
    type_cod0 character varying(3),
    descript1 character varying(36),
    geom public.geometry(MultiPolygon,4269),
    zoneid character varying(3),
    zonename character varying(64)
);


ALTER TABLE static.ukzones OWNER TO postgres;

--
-- Name: ukzones_gid_seq; Type: SEQUENCE; Schema: static; Owner: postgres
--

CREATE SEQUENCE ukzones_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE static.ukzones_gid_seq OWNER TO postgres;

--
-- Name: ukzones_gid_seq; Type: SEQUENCE OWNED BY; Schema: static; Owner: postgres
--

ALTER SEQUENCE ukzones_gid_seq OWNED BY ukzones.gid;


--
-- Name: uscounties; Type: TABLE; Schema: static; Owner: postgres; Tablespace: 
--

CREATE TABLE uscounties (
    gid integer NOT NULL,
    state character varying(2),
    cwa character varying(9),
    countyname character varying(24),
    fips character varying(5),
    time_zone character varying(2),
    fe_area character varying(2),
    lon numeric,
    lat numeric,
    geom public.geometry(MultiPolygon,4269)
);


ALTER TABLE static.uscounties OWNER TO postgres;

--
-- Name: uscounties_gid_seq; Type: SEQUENCE; Schema: static; Owner: postgres
--

CREATE SEQUENCE uscounties_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE static.uscounties_gid_seq OWNER TO postgres;

--
-- Name: uscounties_gid_seq; Type: SEQUENCE OWNED BY; Schema: static; Owner: postgres
--

ALTER SEQUENCE uscounties_gid_seq OWNED BY uscounties.gid;


--
-- Name: usstates; Type: TABLE; Schema: static; Owner: postgres; Tablespace: 
--

CREATE TABLE usstates (
    gid integer NOT NULL,
    state character varying(2),
    name character varying(24),
    fips character varying(2),
    lon numeric,
    lat numeric,
    geom public.geometry(MultiPolygon)
);


ALTER TABLE static.usstates OWNER TO postgres;

--
-- Name: usstates_gid_seq; Type: SEQUENCE; Schema: static; Owner: postgres
--

CREATE SEQUENCE usstates_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE static.usstates_gid_seq OWNER TO postgres;

--
-- Name: usstates_gid_seq; Type: SEQUENCE OWNED BY; Schema: static; Owner: postgres
--

ALTER SEQUENCE usstates_gid_seq OWNED BY usstates.gid;


SET search_path = dynamic, pg_catalog;

--
-- Name: gid; Type: DEFAULT; Schema: dynamic; Owner: writer
--

ALTER TABLE ONLY nwsalerts ALTER COLUMN gid SET DEFAULT nextval('nwsalerts_gid_seq'::regclass);


SET search_path = static, pg_catalog;

--
-- Name: gid; Type: DEFAULT; Schema: static; Owner: postgres
--

ALTER TABLE ONLY irelandzones ALTER COLUMN gid SET DEFAULT nextval('irelandzones_gid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: static; Owner: postgres
--

ALTER TABLE ONLY nwspubliczones ALTER COLUMN gid SET DEFAULT nextval('nwspubliczones_gid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: static; Owner: postgres
--

ALTER TABLE ONLY ukzones ALTER COLUMN gid SET DEFAULT nextval('ukzones_gid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: static; Owner: postgres
--

ALTER TABLE ONLY uscounties ALTER COLUMN gid SET DEFAULT nextval('uscounties_gid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: static; Owner: postgres
--

ALTER TABLE ONLY usstates ALTER COLUMN gid SET DEFAULT nextval('usstates_gid_seq'::regclass);


SET search_path = dynamic, pg_catalog;

--
-- Name: nwsalerts_pkey; Type: CONSTRAINT; Schema: dynamic; Owner: writer; Tablespace: 
--

ALTER TABLE ONLY nwsalerts
    ADD CONSTRAINT nwsalerts_pkey PRIMARY KEY (gid);


SET search_path = static, pg_catalog;

--
-- Name: irelandzones_pkey; Type: CONSTRAINT; Schema: static; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY irelandzones
    ADD CONSTRAINT irelandzones_pkey PRIMARY KEY (gid);


--
-- Name: nwspubliczones_pkey; Type: CONSTRAINT; Schema: static; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY nwspubliczones
    ADD CONSTRAINT nwspubliczones_pkey PRIMARY KEY (gid);


--
-- Name: ukzones_pkey; Type: CONSTRAINT; Schema: static; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ukzones
    ADD CONSTRAINT ukzones_pkey PRIMARY KEY (gid);


--
-- Name: uscounties_pkey; Type: CONSTRAINT; Schema: static; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY uscounties
    ADD CONSTRAINT uscounties_pkey PRIMARY KEY (gid);


--
-- Name: usstates_pkey; Type: CONSTRAINT; Schema: static; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY usstates
    ADD CONSTRAINT usstates_pkey PRIMARY KEY (gid);


SET search_path = dynamic, pg_catalog;

--
-- Name: nwsalerts_geom_gist; Type: INDEX; Schema: dynamic; Owner: writer; Tablespace: 
--

CREATE INDEX nwsalerts_geom_gist ON nwsalerts USING gist (geom);


SET search_path = static, pg_catalog;

--
-- Name: irelandzones_geom_gist; Type: INDEX; Schema: static; Owner: postgres; Tablespace: 
--

CREATE INDEX irelandzones_geom_gist ON irelandzones USING gist (geom);


--
-- Name: nwspubliczones_geom_idx; Type: INDEX; Schema: static; Owner: postgres; Tablespace: 
--

CREATE INDEX nwspubliczones_geom_idx ON nwspubliczones USING gist (geom);


--
-- Name: ukzones_geom_gist; Type: INDEX; Schema: static; Owner: postgres; Tablespace: 
--

CREATE INDEX ukzones_geom_gist ON ukzones USING gist (geom);


--
-- Name: uscounties_geom_gist; Type: INDEX; Schema: static; Owner: postgres; Tablespace: 
--

CREATE INDEX uscounties_geom_gist ON uscounties USING gist (geom);


--
-- Name: usstates_geom_idx; Type: INDEX; Schema: static; Owner: postgres; Tablespace: 
--

CREATE INDEX usstates_geom_idx ON usstates USING gist (geom);


--
-- Name: dynamic; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA dynamic FROM PUBLIC;
REVOKE ALL ON SCHEMA dynamic FROM postgres;
GRANT ALL ON SCHEMA dynamic TO postgres;
GRANT USAGE ON SCHEMA dynamic TO reader;
GRANT USAGE ON SCHEMA dynamic TO writer;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: static; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA static FROM PUBLIC;
REVOKE ALL ON SCHEMA static FROM postgres;
GRANT ALL ON SCHEMA static TO postgres;
GRANT USAGE ON SCHEMA static TO reader;


SET search_path = dynamic, pg_catalog;

--
-- Name: custom; Type: ACL; Schema: dynamic; Owner: writer
--

REVOKE ALL ON TABLE custom FROM PUBLIC;
REVOKE ALL ON TABLE custom FROM writer;
GRANT ALL ON TABLE custom TO writer;
GRANT SELECT ON TABLE custom TO reader;


--
-- Name: nwsalerts; Type: ACL; Schema: dynamic; Owner: writer
--

REVOKE ALL ON TABLE nwsalerts FROM PUBLIC;
REVOKE ALL ON TABLE nwsalerts FROM writer;
GRANT ALL ON TABLE nwsalerts TO writer;
GRANT SELECT ON TABLE nwsalerts TO reader;


SET search_path = static, pg_catalog;

--
-- Name: irelandzones; Type: ACL; Schema: static; Owner: postgres
--

REVOKE ALL ON TABLE irelandzones FROM PUBLIC;
REVOKE ALL ON TABLE irelandzones FROM postgres;
GRANT ALL ON TABLE irelandzones TO postgres;
GRANT SELECT ON TABLE irelandzones TO reader;
GRANT SELECT ON TABLE irelandzones TO writer;


--
-- Name: nwspubliczones; Type: ACL; Schema: static; Owner: postgres
--

REVOKE ALL ON TABLE nwspubliczones FROM PUBLIC;
REVOKE ALL ON TABLE nwspubliczones FROM postgres;
GRANT ALL ON TABLE nwspubliczones TO postgres;
GRANT SELECT ON TABLE nwspubliczones TO reader;
GRANT SELECT ON TABLE nwspubliczones TO writer;


--
-- Name: ukzones; Type: ACL; Schema: static; Owner: postgres
--

REVOKE ALL ON TABLE ukzones FROM PUBLIC;
REVOKE ALL ON TABLE ukzones FROM postgres;
GRANT ALL ON TABLE ukzones TO postgres;
GRANT SELECT ON TABLE ukzones TO reader;
GRANT SELECT ON TABLE ukzones TO writer;


--
-- Name: uscounties; Type: ACL; Schema: static; Owner: postgres
--

REVOKE ALL ON TABLE uscounties FROM PUBLIC;
REVOKE ALL ON TABLE uscounties FROM postgres;
GRANT ALL ON TABLE uscounties TO postgres;
GRANT SELECT ON TABLE uscounties TO reader;
GRANT SELECT ON TABLE uscounties TO writer;


--
-- Name: usstates; Type: ACL; Schema: static; Owner: postgres
--

REVOKE ALL ON TABLE usstates FROM PUBLIC;
REVOKE ALL ON TABLE usstates FROM postgres;
GRANT ALL ON TABLE usstates TO postgres;
GRANT SELECT ON TABLE usstates TO reader;
GRANT SELECT ON TABLE usstates TO writer;


--
-- PostgreSQL database dump complete
--

