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


--
-- Name: adminpack; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS adminpack WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION adminpack; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION adminpack IS 'administrative functions for PostgreSQL';


--
-- Name: tablefunc; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;


--
-- Name: EXTENSION tablefunc; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION tablefunc IS 'functions that manipulate whole tables, including crosstab';


SET search_path = public, pg_catalog;

--
-- Name: add_role_restsql(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_role_restsql() RETURNS SETOF character varying
    LANGUAGE plpgsql
    AS $$DECLARE
  myRec record;
  outRec record; 
  myRole TEXT;
BEGIN
  --function to return any user roles that have been added and
  -- do not already have a true <registered> parameter
   
  FOR myRec in select * from user_roles 
  where registered = false
  loop
    select role into myRole from user_roles 
    where role = myRec.role
    and registered = true
    limit 1 ;
    if myRole is null then
      RAISE NOTICE ' NULL %',myRec.role;
    else
     RAISE NOTICE ' NOT NULL %',myRec.role;
     update user_roles set registered = true where role = myRole;
    end if;
  end loop;
RETURN query select role from user_roles where registered = false;
END;$$;


ALTER FUNCTION public.add_role_restsql() OWNER TO postgres;

--
-- Name: user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_id_seq OWNER TO postgres;

--
-- Name: user_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE user_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_roles_id_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE user_roles (
    id integer DEFAULT nextval('user_roles_id_seq'::regclass) NOT NULL,
    role character varying(24),
    added_by character varying(24),
    date_added date DEFAULT now() NOT NULL,
    role_description character varying(100),
    fcast_region_id character varying(2),
    metar_data boolean,
    ltg_data boolean,
    registered boolean DEFAULT false NOT NULL,
    graph_data boolean,
    country_code character varying(2),
    ticker boolean DEFAULT false,
    bounds double precision[]
);


ALTER TABLE public.user_roles OWNER TO postgres;

--
-- Name: TABLE user_roles; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE user_roles IS 'List of different user_roles available';


--
-- Name: user_roles_ref_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE user_roles_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_roles_ref_id_seq OWNER TO postgres;

--
-- Name: user_roles_ref; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE user_roles_ref (
    id integer DEFAULT nextval('user_roles_ref_id_seq'::regclass) NOT NULL,
    uid integer,
    rid integer
);


ALTER TABLE public.user_roles_ref OWNER TO postgres;

--
-- Name: COLUMN user_roles_ref.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN user_roles_ref.id IS 'Reference ID';


--
-- Name: COLUMN user_roles_ref.uid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN user_roles_ref.uid IS 'User ID';


--
-- Name: COLUMN user_roles_ref.rid; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN user_roles_ref.rid IS 'Role ID';


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE users (
    id integer DEFAULT nextval('user_id_seq'::regclass) NOT NULL,
    username character varying(24),
    password character(32),
    comments character varying(120),
    added_by character varying(24),
    date_added date DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: COLUMN users.id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.id IS 'users ID';


--
-- Name: COLUMN users.username; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.username IS 'username';


--
-- Name: COLUMN users.password; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN users.password IS 'salted MD5';


--
-- Name: new_tomcat_roles; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW new_tomcat_roles AS
 SELECT u.username,
    r.role,
    u.comments,
    u.added_by,
    u.date_added,
    r.fcast_region_id
   FROM ((users u
     JOIN user_roles_ref f ON ((u.id = f.uid)))
     JOIN user_roles r ON ((r.id = f.rid)));


ALTER TABLE public.new_tomcat_roles OWNER TO postgres;

--
-- Name: newer_tomcat_roles; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW newer_tomcat_roles AS
 SELECT u.username,
    r.role,
    r.role_description,
    u.comments,
    u.added_by,
    u.date_added,
    r.fcast_region_id,
    r.metar_data,
    r.ltg_data,
    r.graph_data,
    r.country_code,
    r.ticker,
    r.bounds
   FROM ((users u
     JOIN user_roles_ref f ON ((u.id = f.uid)))
     JOIN user_roles r ON ((r.id = f.rid)));


ALTER TABLE public.newer_tomcat_roles OWNER TO postgres;

--
-- Name: tomcat_roles; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW tomcat_roles AS
 SELECT u.username,
    r.role,
    u.comments,
    u.added_by,
    u.date_added
   FROM ((users u
     JOIN user_roles_ref f ON ((u.id = f.uid)))
     JOIN user_roles r ON ((r.id = f.rid)));


ALTER TABLE public.tomcat_roles OWNER TO postgres;

--
-- Name: roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: roles_role_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY user_roles
    ADD CONSTRAINT roles_role_key UNIQUE (role);


--
-- Name: user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: user_role_ref_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY user_roles_ref
    ADD CONSTRAINT user_role_ref_pkey PRIMARY KEY (id);


--
-- Name: user_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT user_username_key UNIQUE (username);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;
GRANT USAGE ON SCHEMA public TO authwrite;


--
-- Name: user_roles; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE user_roles FROM PUBLIC;
REVOKE ALL ON TABLE user_roles FROM postgres;
GRANT ALL ON TABLE user_roles TO postgres;
GRANT SELECT ON TABLE user_roles TO obsread;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE user_roles TO authwrite;


--
-- Name: user_roles_ref; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE user_roles_ref FROM PUBLIC;
REVOKE ALL ON TABLE user_roles_ref FROM postgres;
GRANT ALL ON TABLE user_roles_ref TO postgres;
GRANT SELECT ON TABLE user_roles_ref TO obsread;


--
-- Name: users; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE users FROM PUBLIC;
REVOKE ALL ON TABLE users FROM postgres;
GRANT ALL ON TABLE users TO postgres;
GRANT SELECT ON TABLE users TO obsread;


--
-- Name: new_tomcat_roles; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE new_tomcat_roles FROM PUBLIC;
REVOKE ALL ON TABLE new_tomcat_roles FROM postgres;
GRANT ALL ON TABLE new_tomcat_roles TO postgres;
GRANT SELECT ON TABLE new_tomcat_roles TO obsread;


--
-- Name: newer_tomcat_roles; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE newer_tomcat_roles FROM PUBLIC;
REVOKE ALL ON TABLE newer_tomcat_roles FROM postgres;
GRANT ALL ON TABLE newer_tomcat_roles TO postgres;
GRANT SELECT ON TABLE newer_tomcat_roles TO obsread;


--
-- Name: tomcat_roles; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE tomcat_roles FROM PUBLIC;
REVOKE ALL ON TABLE tomcat_roles FROM postgres;
GRANT ALL ON TABLE tomcat_roles TO postgres;
GRANT SELECT ON TABLE tomcat_roles TO obsread;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE ALL ON TABLES  FROM postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT SELECT ON TABLES  TO obsread;


--
-- PostgreSQL database dump complete
--

