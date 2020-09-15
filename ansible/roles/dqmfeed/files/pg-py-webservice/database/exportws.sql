--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.5
-- Dumped by pg_dump version 9.5.0

-- Started on 2016-02-11 14:15:22 GMT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 7 (class 2615 OID 16409)
-- Name: exportws; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA exportws;


ALTER SCHEMA exportws OWNER TO postgres;

SET search_path = exportws, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 181 (class 1259 OID 16545)
-- Name: groups; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE groups (
    vmdb_id integer NOT NULL,
    group_id integer NOT NULL,
    data_number integer,
    lane_name text,
    xsitype text
);


ALTER TABLE groups OWNER TO postgres;

--
-- TOC entry 182 (class 1259 OID 16551)
-- Name: lanes; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE lanes (
    vmdb_id integer NOT NULL,
    data_number integer NOT NULL,
    reverse boolean,
    lane_direction text
);


ALTER TABLE lanes OWNER TO postgres;

--
-- TOC entry 183 (class 1259 OID 16557)
-- Name: permissions; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE permissions (
    username text NOT NULL,
    region text NOT NULL,
    role text NOT NULL
);


ALTER TABLE permissions OWNER TO postgres;

--
-- TOC entry 184 (class 1259 OID 16563)
-- Name: pwdb; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE pwdb (
    username text NOT NULL,
    salt text,
    password text
);


ALTER TABLE pwdb OWNER TO postgres;

--
-- TOC entry 185 (class 1259 OID 16569)
-- Name: qttids; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE qttids (
    vmdb_id integer NOT NULL,
    qtt_id integer
);


ALTER TABLE qttids OWNER TO postgres;

--
-- TOC entry 186 (class 1259 OID 16572)
-- Name: sensorindex; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE sensorindex (
    datex_id integer NOT NULL,
    sensor_id integer,
    data_symbol text,
    data_number integer
);


ALTER TABLE sensorindex OWNER TO postgres;

--
-- TOC entry 187 (class 1259 OID 16578)
-- Name: sensors; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE sensors (
    vmdb_id integer NOT NULL,
    group_id integer,
    datex_id integer NOT NULL,
    enabled boolean
);


ALTER TABLE sensors OWNER TO postgres;

--
-- TOC entry 188 (class 1259 OID 16581)
-- Name: stations; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE stations (
    vmdb_id integer NOT NULL,
    measurementside text,
    version integer
);


ALTER TABLE stations OWNER TO postgres;

--
-- TOC entry 189 (class 1259 OID 16587)
-- Name: xmltags; Type: TABLE; Schema: exportws; Owner: postgres
--

CREATE TABLE xmltags (
    data_symbol text NOT NULL,
    xmltagname text,
    measurementunit text,
    xsitype text,
    datatype text
);


ALTER TABLE xmltags OWNER TO postgres;

--
-- TOC entry 3145 (class 2606 OID 80329)
-- Name: groups_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (vmdb_id, group_id);


--
-- TOC entry 3147 (class 2606 OID 80331)
-- Name: lanes_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY lanes
    ADD CONSTRAINT lanes_pkey PRIMARY KEY (vmdb_id, data_number);


--
-- TOC entry 3149 (class 2606 OID 80333)
-- Name: permissions_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (username, region, role);


--
-- TOC entry 3151 (class 2606 OID 80335)
-- Name: pwdb_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY pwdb
    ADD CONSTRAINT pwdb_pkey PRIMARY KEY (username);


--
-- TOC entry 3153 (class 2606 OID 80337)
-- Name: qttids_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY qttids
    ADD CONSTRAINT qttids_pkey PRIMARY KEY (vmdb_id);


--
-- TOC entry 3155 (class 2606 OID 80339)
-- Name: qttids_qtt_id_key; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY qttids
    ADD CONSTRAINT qttids_qtt_id_key UNIQUE (qtt_id);


--
-- TOC entry 3157 (class 2606 OID 80341)
-- Name: sensorindex_data_symbol_key; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY sensorindex
    ADD CONSTRAINT sensorindex_data_symbol_key UNIQUE (data_symbol, data_number);


--
-- TOC entry 3159 (class 2606 OID 80343)
-- Name: sensorindex_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY sensorindex
    ADD CONSTRAINT sensorindex_pkey PRIMARY KEY (datex_id);


--
-- TOC entry 3161 (class 2606 OID 80345)
-- Name: sensorindex_sensor_id_key; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY sensorindex
    ADD CONSTRAINT sensorindex_sensor_id_key UNIQUE (sensor_id);


--
-- TOC entry 3163 (class 2606 OID 80347)
-- Name: sensors_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY sensors
    ADD CONSTRAINT sensors_pkey PRIMARY KEY (vmdb_id, datex_id);


--
-- TOC entry 3165 (class 2606 OID 80349)
-- Name: stations_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY stations
    ADD CONSTRAINT stations_pkey PRIMARY KEY (vmdb_id);


--
-- TOC entry 3167 (class 2606 OID 80351)
-- Name: xmltags_pkey; Type: CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY xmltags
    ADD CONSTRAINT xmltags_pkey PRIMARY KEY (data_symbol);


--
-- TOC entry 3168 (class 2606 OID 80524)
-- Name: permissions_user_fkey; Type: FK CONSTRAINT; Schema: exportws; Owner: postgres
--

ALTER TABLE ONLY permissions
    ADD CONSTRAINT permissions_user_fkey FOREIGN KEY (username) REFERENCES pwdb(username);


--
-- TOC entry 3283 (class 0 OID 0)
-- Dependencies: 7
-- Name: exportws; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA exportws FROM PUBLIC;
REVOKE ALL ON SCHEMA exportws FROM postgres;
GRANT ALL ON SCHEMA exportws TO postgres;
GRANT USAGE ON SCHEMA exportws TO "exportws-group";


--
-- TOC entry 3284 (class 0 OID 0)
-- Dependencies: 181
-- Name: groups; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE groups FROM PUBLIC;
REVOKE ALL ON TABLE groups FROM postgres;
GRANT ALL ON TABLE groups TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE groups TO "exportws-group";


--
-- TOC entry 3285 (class 0 OID 0)
-- Dependencies: 182
-- Name: lanes; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE lanes FROM PUBLIC;
REVOKE ALL ON TABLE lanes FROM postgres;
GRANT ALL ON TABLE lanes TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE lanes TO "exportws-group";


--
-- TOC entry 3286 (class 0 OID 0)
-- Dependencies: 183
-- Name: permissions; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE permissions FROM PUBLIC;
REVOKE ALL ON TABLE permissions FROM postgres;
GRANT ALL ON TABLE permissions TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE permissions TO "exportws-group";


--
-- TOC entry 3287 (class 0 OID 0)
-- Dependencies: 184
-- Name: pwdb; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE pwdb FROM PUBLIC;
REVOKE ALL ON TABLE pwdb FROM postgres;
GRANT ALL ON TABLE pwdb TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE pwdb TO "exportws-group";


--
-- TOC entry 3288 (class 0 OID 0)
-- Dependencies: 185
-- Name: qttids; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE qttids FROM PUBLIC;
REVOKE ALL ON TABLE qttids FROM postgres;
GRANT ALL ON TABLE qttids TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE qttids TO "exportws-group";


--
-- TOC entry 3289 (class 0 OID 0)
-- Dependencies: 186
-- Name: sensorindex; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE sensorindex FROM PUBLIC;
REVOKE ALL ON TABLE sensorindex FROM postgres;
GRANT ALL ON TABLE sensorindex TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sensorindex TO "exportws-group";


--
-- TOC entry 3290 (class 0 OID 0)
-- Dependencies: 187
-- Name: sensors; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE sensors FROM PUBLIC;
REVOKE ALL ON TABLE sensors FROM postgres;
GRANT ALL ON TABLE sensors TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sensors TO "exportws-group";


--
-- TOC entry 3291 (class 0 OID 0)
-- Dependencies: 188
-- Name: stations; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE stations FROM PUBLIC;
REVOKE ALL ON TABLE stations FROM postgres;
GRANT ALL ON TABLE stations TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE stations TO "exportws-group";


--
-- TOC entry 3292 (class 0 OID 0)
-- Dependencies: 189
-- Name: xmltags; Type: ACL; Schema: exportws; Owner: postgres
--

REVOKE ALL ON TABLE xmltags FROM PUBLIC;
REVOKE ALL ON TABLE xmltags FROM postgres;
GRANT ALL ON TABLE xmltags TO postgres;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE xmltags TO "exportws-group";


-- Completed on 2016-02-11 14:15:22 GMT

--
-- PostgreSQL database dump complete
--

