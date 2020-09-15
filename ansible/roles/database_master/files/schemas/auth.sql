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
-- Name: user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('user_id_seq', 239, true);


--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY user_roles (id, role, added_by, date_added, role_description, fcast_region_id, metar_data, ltg_data, registered, graph_data, country_code, ticker, bounds) FROM stdin;
105	shetlandislands	MJHS	2015-05-05	Shetland Islands Council	\N	t	t	t	t	GB	f	\N
112	bbisla50	PJHE	2015-05-27	BBISL A50	\N	t	t	t	t	GB	t	\N
121	boise_airport	STW	2015-09-08	Boise Air Terminal	\N	t	t	t	t	US	t	\N
98	aberdeenshirecouncil	RWIL	2015-03-06	Aberdeenshire Council	\N	t	t	t	t	GB	t	\N
73	georgiadot	STW	2015-02-03	Georgia DOT	\N	t	t	t	t	US	t	\N
10	vuser2	BJT	2013-10-23	Virtual Area covering south Britain	\N	f	f	t	t	US	t	\N
82	wakefieldmdc	HEC	2015-02-05	Wakefield MDC	\N	f	t	t	t	GB	t	\N
60	bostonlogan	STW	2015-01-28	Boston Logan Int'L	\N	t	t	t	t	US	t	\N
83	derbycity	HEC	2015-02-05	Derby City Council	\N	f	t	t	t	GB	t	\N
32	massdot	JOSP	2014-10-10	Massachusetts DOT	\N	t	t	t	t	US	t	\N
58	ameyhighwaysse	YBAR	2015-01-25	Amey Highways (SE Region)	\N	t	t	t	t	GB	t	\N
90	cardiffcity	YBAR	2015-02-06	Cardiff City Council	\N	t	t	t	t	GB	t	\N
51	kentcountycouncil	MJHS	2015-01-24	Kent County Council	\N	t	t	t	t	GB	t	\N
59	cornwallcouncil	HEC	2015-01-26	Cornwall Council	co	t	t	t	t	GB	t	\N
18	memphisap	REC	2013-11-21	Memphis Intl Airport	\N	t	t	t	f	US	t	\N
86	doncastermetboro	YBAR	2015-02-06	Doncaster Metropolitan Borough Council	\N	t	t	t	t	GB	t	\N
66	tennrwispilot	STW	2015-01-30	Tennessee RWIS Pilot	\N	t	t	t	t	US	t	\N
76	mayococo	HEC	2015-02-05	Mayo County Council	\N	f	f	t	t	IE	t	\N
40	northayrshirecouncil	PJHE	2015-01-21	North Ayrshire Council	\N	t	t	t	t	GB	t	\N
39	midlothiancouncil	MJHS	2015-01-20	Mid Lothian Council	\N	t	t	t	t	GB	t	\N
99	nephiliairport	STW	2015-03-17	NE Philadelphia Airport	\N	t	t	t	t	US	t	\N
84	cumbriacoco	HEC	2015-02-06	Cumbria County Council	\N	f	t	t	t	GB	t	\N
43	bearscotlandltdnw	MJHS	2015-01-21	BEAR Scotland Ltd (NW)	\N	t	t	t	t	GB	t	\N
24	cardiff	JPC	2014-03-26	Cardiff	sg	t	t	t	t	GB	t	\N
38	inverclydecouncil	MJHS	2015-01-20	Inverclyde Council	\N	t	t	t	t	GB	t	\N
67	bwiairport	STW	2015-01-30	Maryland Aviation	\N	t	t	t	t	US	t	\N
94	westdesmoines	STW	2015-02-11	City of West Des Moines	\N	t	t	t	t	US	t	\N
57	ameym8dbfo	YBAR	2015-01-25	Amey M8 DBFO	\N	t	t	t	t	GB	t	\N
80	buffaloap	JOSP	2015-02-05	Buffalo Niagara International Airport	\N	t	t	t	t	US	t	\N
68	hmmni	HEC	2015-02-02	HMM Northern Ireland	\N	f	f	t	t	GB	t	\N
16	lincolnshire	REC	2013-11-05	Lincolnshire CC	li	t	t	t	t	GB	t	\N
78	bradfordmbc	MJHS	2015-02-05	Bradford MBC	\N	f	t	t	t	GB	t	\N
92	global	JPC	2015-02-09	For use by RDS	\N	t	t	t	t	US	t	\N
75	networkc	HEC	2015-02-05	Egis Lagan Services Ltd (Network C)	\N	f	f	t	t	IE	t	\N
103	orkneyislands	YBAR	2015-04-07	Orkney Islands Council	\N	t	t	t	t	GB	t	\N
23	alabama	REC	2014-03-17	Alabama DoT	\N	t	t	t	t	US	t	\N
45	ameylaganroadsltd	dri	2015-01-22	AMEY Lagan Roads Ltd	\N	t	t	t	t	GB	t	\N
79	ameyliverpool	MJHS	2015-02-05	AMEY Liverpool	\N	f	t	t	t	GB	t	\N
46	bbcelawpr	PJHE	2015-01-23	BBCEL AWPR	\N	t	t	t	t	GB	t	\N
44	bearscotlandltdne	PJHE	2015-01-22	BEAR Scotland Ltd (NE)	\N	t	t	t	t	GB	t	\N
72	belfastintairport	rwil	2015-02-03	Belfast International Airport	\N	f	f	t	t	GB	t	\N
15	blr	REC	2013-11-04	Baltimore Light Rail	\N	f	f	t	t	US	t	\N
48	cityofedinburgh	PJHE	2015-01-23	The City of Edinburgh Council	\N	t	t	t	t	GB	t	\N
25	copenhagenap	REC	2014-05-06	Copenhagen Airport	\N	t	t	t	t	DK	t	\N
21	defkorea	REC	2014-01-28	Korea defense	\N	t	t	t	t	KP	t	\N
100	dulles	STW	2015-03-18	Dulles International Airport	\N	t	t	t	t	US	t	\N
49	eastsussex	YBAR	2015-01-24	East Sussex	\N	t	t	t	t	GB	t	\N
74	finavia	RPK	2015-02-04	Finavia	\N	t	t	t	t	FI	t	\N
37	glasgowcitycouncil	MJHS	2015-01-20	Glasgow City Council	\N	t	t	t	t	GB	t	\N
81	herefordshirecoco	MJHS	2015-02-05	Herefordshire County Council	\N	f	t	t	t	GB	t	\N
8	idaho	BJT	2013-10-23	Idaho DoT	id	t	t	t	t	US	t	\N
17	ireland	REC	2013-11-06	Ireland NRA	ir	t	t	t	t	IE	t	\N
14	admin	BJT	2013-11-01	Admin role for restsql	\N	f	t	t	t	US	t	\N
71	kildarecoco	HEC	2015-02-03	Kildare County Council	\N	f	f	t	t	IE	t	\N
77	knowsleymbc	HEC	2015-02-05	Knowsley Metropolitan Borough Council	\N	f	t	t	t	GB	t	\N
56	m40carillion	YBAR	2015-01-25	M40/Carillion	\N	t	t	t	t	GB	t	\N
55	m6tollmidland	YBAR	2015-01-25	M6 Toll - Midland Expressway Ltd	\N	t	t	t	t	GB	t	\N
64	m77bbcel	rwil	2015-01-30	M77 BBCEL	\N	f	f	t	t	GB	t	\N
65	manchester-boston	STW	2015-01-30	Manchester - Boston Regional Airport	\N	t	t	t	t	US	t	\N
22	maritimedemo	JPC	2014-02-28	Maritime Demo	\N	t	t	t	t	US	t	\N
26	mchenry	JPC	2014-08-06	McHenry County	\N	t	t	t	t	US	t	\N
20	minneapolisap	REC	2014-01-08	Minneapolis Intl Airport	\N	t	t	t	f	US	t	\N
47	networkrail	PJHE	2015-01-23	Network Rail	\N	t	t	t	t	GB	t	\N
33	nhdot	JOSP	2014-10-10	New Hampshire DOT	\N	t	t	t	t	US	t	\N
53	northyorkshirecoco	MJHS	2015-01-24	North Yorkshire County Council	\N	t	t	t	t	GB	t	\N
96	nwarkregap	DRE	2015-02-20	Northwest Arkansas Regional Airport	\N	t	t	t	t	US	t	\N
87	oldhammetboro	YBAR	2015-02-06	Oldham Metropolitan Borough Council	\N	t	t	t	t	GB	t	\N
50	rutlandcountycouncil	MJHS	2015-01-24	Rutland County Council	\N	t	t	t	t	GB	t	\N
97	scotborders	YBAR	2015-03-06	Scottish Borders Council	\N	t	t	t	t	GB	t	\N
85	shropshirecouncil	HEC	2015-02-06	Shropshire Council	\N	f	t	t	t	GB	t	\N
63	southampton	RPK	2015-01-29	Southampton City Council	\N	f	f	t	t	GB	t	\N
41	southayrshirecouncil	MJHS	2015-01-21	South Ayrshire Council	\N	t	t	t	t	GB	t	\N
91	tameside	HEC	2015-02-09	Tameside	\N	f	t	t	t	GB	t	\N
31	tenndot	JOSP	2014-10-10	Tennessee DOT	\N	t	t	t	t	US	t	\N
52	themoraycouncil	MJHS	2015-01-24	The Moray Council	\N	t	t	t	t	GB	t	\N
54	transportforlondon	YBAR	2015-01-24	Transport for London	\N	t	t	t	t	GB	t	\N
9	vuser1	BJT	2013-10-23	Virtual Area covering north Britain	\N	f	f	t	t	US	t	\N
42	westdunbartonshire	MJHS	2015-01-21	West Dunbartonshire	\N	t	t	t	t	GB	t	\N
61	westmids	JPC	2015-01-29	West Midlands	\N	t	t	t	t	GB	t	\N
88	wigan	RPK	2015-02-06	Wigan Council	\N	f	f	t	t	GB	t	\N
62	kerrycountycouncil	RPK	2015-01-29	Kerry County Council	\N	f	f	t	t	IE	t	\N
36	aberdeencitycouncil	MJHS	2015-01-20	Aberdeen City Council	\N	t	t	t	t	GB	t	\N
95	kilkennycoco	YBAR	2015-02-18	Kilkenny County Council	\N	t	t	t	t	IE	t	\N
102	leedscitycouncil	MJHS	2015-03-30	Leeds City Council	\N	t	t	t	t	GB	t	\N
101	mcgheetyson	STW	2015-03-26	McGhee Tyson Airport	\N	t	t	t	t	US	t	\N
89	torfaencbc	HEC	2015-02-06	Torfaen County Borough Council	\N	f	t	t	t	GB	t	\N
104	westernislescouncil	MJHS	2015-04-09	Western Isles Council	\N	t	t	t	t	GB	t	\N
106	nottinghamcity	MJHS	2015-05-11	Nottingham City Council	\N	t	t	t	t	GB	f	\N
107	tubelines	YBAR	2015-05-12	tubelines	\N	t	t	t	t	GB	t	\N
108	londonunderground	YBAR	2015-05-12	London Underground Ltd	\N	t	t	t	t	GB	t	\N
111	transportni	YBAR	2015-05-21	Transport Northern Ireland	\N	t	t	t	t	GB	t	\N
109	floridapike	stw	2015-05-13	Florida Turnpike	\N	t	t	t	t	US	t	\N
110	seatac	stw	2015-05-14	SeaTac International	\N	t	t	t	t	US	t	\N
34	devon	JOSP	2014-10-22	Devon County Council	\N	t	t	t	t	GB	t	\N
113	bbcelm1a1	GPA	2015-05-28	BBCEL M1 A1	\N	t	t	t	t	GB	t	\N
114	m1a1	GPA	2015-05-28	BBCEL M1 A1	\N	t	t	t	t	GB	t	\N
115	reno-tahoe	STW	2015-06-23	Reno-Tahoe International Airport	\N	t	t	t	t	US	f	\N
93	loveland_airport	STW	2015-02-09	Ft. Collins - Loveland Airport	\N	t	t	t	t	US	t	\N
117	stanstedairport	dri	2015-07-30	Stansted Airport	\N	t	t	t	t	GB	t	\N
120	kingstonuponthames	MJHS	2015-08-27	Kingston Upon Thames	\N	t	t	t	t	GB	t	\N
119	southeast	STW	2015-08-24	Southeast Region	\N	t	t	t	t	US	t	\N
118	mississippi_dot	STW	2015-08-24	Mississippi DOT	\N	t	t	t	t	US	t	\N
122	stocktonborough	MJHS	2015-09-18	Stockton Borough Council	\N	t	t	t	t	GB	t	\N
123	calgary_airport	STW	2015-09-21	Calgary International Airport	\N	t	t	t	t	CA	t	\N
125	dia_airport	stw	2015-10-07	Denver International Airport	\N	t	t	t	t	US	t	\N
124	vaisala-stl	jnb	2015-09-21	Vaisala-STL	\N	t	t	t	t	US	t	\N
126	ohare_airport	STW	2015-10-08	O'Hare International Airport	\N	t	t	t	t	US	t	\N
127	westmeathcoco	MJHS	2015-10-10	Westmeath County Council	\N	t	t	t	t	IE	t	\N
128	sligocountycouncil	MJHS	2015-10-10	Sligo County Council	\N	t	t	t	t	IE	t	\N
129	midlink	MJHS	2015-10-10	Egis Project Ireland - Midlink	\N	t	t	t	t	IE	t	\N
130	lancashire	rwil	2015-10-11	Lancashire County Council	\N	t	t	t	t	GB	t	\N
131	lincolnshirecoco	GPA	2015-10-11	Lincolnshire County Council	\N	t	t	t	t	GB	t	\N
136	tulsaroads	STW	2015-10-19	City of Tulsa	\N	t	t	t	t	US	t	\N
132	louth	rpk	2015-10-12	Louth County Council	\N	t	t	t	t	IE	t	\N
133	landratsamt	GPA	2015-10-12	Landratsamt Ravensburg Strassenbauamt	\N	t	t	t	t	DE	t	\N
134	suffolk	GPA	2015-10-12	Suffolk County Council	\N	t	t	t	t	GB	t	\N
135	newzealand	MJHS	2015-10-14	New Zealand	\N	t	t	t	t	GB	t	\N
137	essex	GPA	2015-10-22	Essex County Council	\N	t	t	t	t	GB	t	\N
138	waterstaat	rpk	2015-10-28	Ministerie van Verkeer en Waterstaat	\N	t	t	t	f	NL	f	\N
139	north_van	STW	2015-10-29	North Vancouver	\N	t	t	t	t	CA	t	\N
146	offalycoco	dri	2015-11-10	Offaly County Council	\N	t	t	t	f	IE	f	\N
141	mainedot	JOSP	2015-11-03	Maine DOT	\N	t	t	t	t	US	t	\N
142	pch	MJHS	2015-11-06	PCH - Luxembourg	\N	t	t	t	t	LU	t	\N
143	cg39	RPK	2015-11-06	CG39	\N	t	t	t	f	FR	f	\N
144	cg71	RPK	2015-11-06	CG71	\N	t	t	t	f	FR	f	\N
145	adp	RPK	2015-11-06	Aeroports de Paris	\N	t	t	t	f	FR	f	\N
147	torbaybc	dri	2015-11-10	Torbay Borough Council	\N	t	t	t	f	GB	f	\N
148	leicestershirecoco	dri	2015-11-10	Leicestershire County Council	\N	t	t	t	f	GB	f	\N
19	colorado	REC	2013-12-16	Colorado DoT	\N	t	t	t	t	US	t	\N
\.


--
-- Name: user_roles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('user_roles_id_seq', 148, true);


--
-- Data for Name: user_roles_ref; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY user_roles_ref (id, uid, rid) FROM stdin;
35	9	9
36	10	10
41	7	8
50	28	15
51	7	15
52	7	16
119	81	14
53	30	16
120	81	15
121	87	21
58	35	17
61	39	8
62	40	17
63	41	18
67	45	8
68	46	8
70	48	8
72	50	17
73	51	14
74	52	17
76	54	16
77	55	8
78	56	19
79	55	17
80	55	18
81	57	17
82	7	17
83	7	18
84	35	16
28	1	8
29	2	8
30	3	8
134	90	22
32	5	8
34	8	8
87	59	8
88	59	15
89	59	18
90	59	17
91	59	16
92	7	20
85	60	20
86	61	20
93	59	20
94	61	18
95	62	20
96	63	17
149	59	23
150	59	24
151	94	14
152	95	23
154	93	20
97	14	79
98	15	79
155	59	25
156	96	23
157	96	8
158	97	25
159	98	8
160	99	25
161	101	8
162	102	26
163	104	23
164	104	31
165	105	32
166	106	33
167	106	32
168	105	33
169	107	34
170	106	34
171	35	34
173	108	25
174	109	8
175	109	17
176	106	26
177	110	36
178	111	37
183	115	40
180	113	38
181	114	39
182	106	37
184	116	41
185	117	42
186	118	43
187	119	44
188	120	45
189	121	46
190	122	47
191	123	48
192	124	49
193	126	50
205	138	61
195	128	51
196	129	52
197	130	53
198	131	54
199	132	55
200	133	56
201	134	57
202	135	58
203	136	59
204	137	60
206	138	36
207	138	23
208	138	58
209	138	45
210	138	57
211	138	46
212	138	44
213	138	15
214	138	60
216	138	24
217	138	19
218	138	48
219	138	59
220	138	25
221	138	21
222	138	34
223	138	49
224	138	37
225	138	8
226	138	55
227	138	38
228	138	16
229	138	17
230	138	51
231	138	56
232	138	22
233	138	26
234	138	32
235	138	18
236	138	39
237	138	20
238	138	31
239	138	53
240	138	50
241	138	40
242	138	47
243	138	43
244	138	33
245	138	41
246	138	52
247	138	54
248	138	9
249	138	10
250	138	42
251	139	62
253	141	63
254	142	64
255	143	65
256	144	66
257	145	23
258	146	67
259	147	68
260	148	60
261	149	65
263	151	66
264	152	67
273	160	75
266	154	71
267	155	72
268	156	73
269	59	68
270	157	74
271	158	8
272	159	73
274	161	76
275	162	77
276	163	78
277	164	79
278	140	80
279	150	80
280	106	80
281	165	81
282	166	82
283	167	83
284	168	84
285	169	85
286	170	86
288	172	88
289	173	89
290	174	90
291	175	91
292	176	92
400	207	118
294	178	33
295	179	32
296	180	94
297	181	95
298	182	87
299	183	96
300	184	93
301	118	44
302	119	43
303	121	64
304	142	46
305	135	57
306	134	58
307	104	73
308	185	97
309	186	98
310	111	40
311	111	41
312	111	42
313	111	38
314	115	37
315	115	41
316	115	42
317	115	38
318	116	40
319	116	42
320	116	37
321	116	38
322	117	37
323	117	40
324	117	41
325	117	38
326	113	37
327	113	41
328	113	40
329	113	42
330	129	36
331	129	98
332	110	98
333	110	52
334	186	36
335	186	52
336	123	39
337	123	97
338	114	97
339	114	48
340	185	39
341	185	48
342	106	73
343	187	99
344	188	100
345	189	101
346	190	102
348	191	23
349	191	60
350	191	80
351	191	19
352	191	100
353	191	67
354	191	73
355	191	8
356	191	26
357	191	93
358	191	32
359	191	33
360	191	74
361	191	98
362	191	34
363	191	18
364	191	20
365	191	42
366	106	19
367	192	103
368	193	104
369	106	23
370	106	60
371	106	67
372	106	100
373	106	24
374	106	25
375	106	74
376	106	8
377	106	18
378	194	105
379	195	106
380	196	107
381	197	108
382	198	109
383	199	23
384	200	110
385	201	111
386	202	74
387	202	8
388	202	32
389	202	73
390	202	20
391	202	60
392	202	25
393	202	34
394	203	112
397	204	115
398	205	117
399	206	93
401	208	119
402	209	120
403	210	121
404	211	122
405	212	123
406	215	125
407	216	126
408	217	16
409	218	127
410	219	128
411	220	129
412	221	130
413	222	131
414	223	36
415	223	98
416	223	58
417	223	45
418	223	79
419	223	57
420	223	46
421	223	113
422	223	112
423	223	44
424	223	43
425	223	72
426	223	78
427	223	24
428	223	88
429	223	127
430	223	104
431	223	42
432	223	82
433	223	107
434	223	111
435	223	54
436	223	89
437	223	52
438	223	91
439	223	122
440	223	90
441	223	48
442	223	59
443	223	84
444	223	83
445	223	34
446	223	86
447	223	49
448	223	37
449	223	81
450	223	38
451	223	17
452	223	51
453	223	62
454	223	71
455	223	95
456	223	120
457	223	77
458	223	130
459	223	102
460	223	16
461	223	131
462	223	108
463	223	93
464	223	114
465	223	56
466	223	55
467	223	64
468	223	76
469	223	129
470	223	39
471	223	75
472	223	47
473	223	40
474	223	53
475	223	106
476	223	8
477	223	103
478	223	50
479	223	97
480	223	105
481	223	85
482	223	128
483	223	63
484	223	41
485	223	117
493	228	136
487	224	132
488	225	133
489	226	134
490	227	135
491	190	78
492	163	102
494	229	137
495	230	138
496	231	139
497	106	141
498	232	141
499	233	142
500	234	143
501	235	144
502	236	145
503	237	146
504	238	147
505	239	148
\.


--
-- Name: user_roles_ref_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('user_roles_ref_id_seq', 505, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY users (id, username, password, comments, added_by, date_added) FROM stdin;
1	admin	21232f297a57a5a743894a0e4a801fc3	Login for looking at logs and  reloading restsql queries	BJT	2013-10-23
2	all	a181a603769c1f98ad927e7367c7aa51	test account	BJT	2013-10-23
3	bert	3de0746a7d2762a87add40dac2bc95a0	test account	REC	2013-10-23
5	brent	fddd76411252e465ab9edde8ebed3d0a	test account	BJT	2013-10-23
8	trn	60a6c11c633c86891c3a8c701dcf2640	test account	BJT	2013-10-23
9	vuser1	ba0f62ee7eab93e25c8634a2e3c6c8cc	test account	BJT	2013-10-23
10	vuser2	20beb575c10d0c3f34d769c155f9d8e0	test account	BJT	2013-10-23
7	rec	3f0b8d8580d700154745170d8ff15b76	test account	REC	2013-10-23
61	slha	972b1eceef6746237236f5e5f687b029	Stephanie Haynes in APS segment (slha321)	REC	2014-01-09
87	defkorea	f2fc4d785eb35d8e3ce4bcd6983291fd	Account for DEF guys (defguys)	REC	2014-01-28
28	blr	73e588ba736daa50923d71ddb7539ae8	Baltimore Light Rail	REC	2013-11-04
39	idaho	d32dfaff96f81d614c539285561bd3db	Shared account for Vaisala users	REC	2013-11-20
40	ireland	dc0e098155b47197ead51e3cf93b719a	Shared account for Vaisala users	REC	2013-11-20
41	memphis	a94e7da23cc2e9e978f0376c895fd7d3	Added as a test for SRH (memphisAP)	REC	2013-11-21
45	bobk	cc62d02ec6bf9dd4fac611f2e33ded54	Bob Koberlain, ITD winter maintenance	REC	2013-11-21
46	dennisj	cc62d02ec6bf9dd4fac611f2e33ded54	Dennis Jensen, ITD winter maintenance	REC	2013-11-21
48	garys	cc62d02ec6bf9dd4fac611f2e33ded54	gary Sanderson, ITD winter maintenance	REC	2013-11-21
51	suser	e29f8644c1f89f5d9c4296a741ad0d83	super user login (admin role)	BJT	2013-11-22
229	essex	0a1d7524d3293522357871d3730dfa58	Essex	gpa	2015-10-22
55	bruce	45a87a133daac67353d4cc1d7b6c80a8	Rage Digital Developer (iosdude)	REC	2013-12-13
57	earlyS	0aefa5b8ffe141473f016b941be9bb13	Steve rocks	REC	2013-12-20
62	aaronf	3543d5803d33f37c1e0c4994cee97541	Airport user partner (msp321)	REC	2014-01-13
30	frankie	d30c7f7381508c2fcd7139aaa67ce48e	another test.	REC	2013-11-06
50	damieng	f485c301f5ebfac7f0a67c24857e6084	Damien Grennan, NRA (nraiPad)	REC	2013-11-21
52	charliem	f485c301f5ebfac7f0a67c24857e6084	Charlie McCarthy NRA (nraiPad)	REC	2013-11-26
60	msp	3543d5803d33f37c1e0c4994cee97541	Test account for MSP	REC	2014-01-08
59	demo	a31de580a7d8a59d7f21946964967595	Added for SG group (demovai)	REC	2014-01-06
63	stephens	f485c301f5ebfac7f0a67c24857e6084	Stephen Smyth  NRA (nraiPad)	REC	2014-01-15
56	rockies	0b36753349fbaaa9d8e70bfdb4df5a66	Shared account	REC	2013-12-16
90	mardemo	e428a0fd7bfca241b4157eeded8f17b7	For Tomi / Mikka (mardemovai)	REC	2014-03-03
94	q	4297f44b13955235245b2497399d7a93	test account	rwi	2014-03-30
95	eddie	b67733c3e4ddc0633ddb2531e3a51ec9	delete ASAP	eddie	2014-03-31
93	mspops	c787e257e350d68e6f760e241460457f	MSP airport operations	REC	2014-03-29
96	joespenner	dd93776382419a102c8504828165d6b2	test for Joe. can be removed	REC	2014-06-27
97	jorgenr	9046b395c72eb740290a05b10be95468	Copenhagen greenbox partner (pass jr123)	REC	2014-07-23
98	fred_test	202cb962ac59075b964b07152d234b70	test user	rwi	2014-07-29
99	rwi_test123	202cb962ac59075b964b07152d234b70	test user	rwi	2014-07-29
101	steveg	cc62d02ec6bf9dd4fac611f2e33ded54	Steve Gertonson, ITD winter maintenance	REC	2014-08-01
102	mchenry	0e52725b0860de4597ce6200c5345051	mchendry	JPC	2014-08-06
198	fte	ea9816075b4a2b84d02d168b69683dfc	FTE default user	stw	2015-05-13
104	jwal	224b0fd608405c7891273b59749ae13a	Added Account JWAL Customer WS	JOSP	2014-10-09
105	kuki	49bc9629f574052d96928304718afc99	Kurt's Account	JOSP	2014-10-10
106	josp	41fde95763c68a56d9c74d2897133e6b	John Spence	JOSP	2014-10-15
107	mjw	fa928a3b0e76c656c89cf1d37e645ef4	Account for mjw	JOSP	2014-10-22
35	rla	f3cb404be8e582878fcfdc7aad201bbb	NRA client	REC as a test for Rachel	2013-11-06
108	cphap	2971de992c5ba14455e81db31effe636	Created for CPH	TRN	2014-11-27
109	applereviewer	8145e17bae83caa331f3a2ded1928140	Apple Reviewer Account	JOSP	2014-12-15
123	cityofedinburgh	7c4b6e046a7d2469f4da3ae7155a9305	Added for City of Edinburgh	PJHE	2015-01-23
124	eastsussex	6ea7f6c35be989c0cd8924db94613370	Created for East Sussex	YBAR	2015-01-24
120	ameylagan	fa7b8deedd81179c980f87d1dd7952e8	added user	dri	2015-01-22
138	jpc	2c4738d24c422be5454d6b3f74475f2f	jpc asd	jpc	2015-01-29
110	aberdeencity	bedd1b75312931b2e0aff83fe326ccd0	Adding virtual org	MJHS	2015-01-20
111	glasgowcity	053326b763ea291a1c266d0bc16e62fe	Creating user	MJHS	2015-01-20
113	inverclydecouncil	45ef9a81ff61fbb95436a1b0d43bea7e	Adding user	MJHS	2015-01-20
114	midlothiancouncil	8f522a27bcad56e267450aa2b7799ffc	Adding new user	MJHS	2015-01-20
115	northayrshirecouncil	83e7a9c2d8e14b6a40fc78628394c98c	Created for North Ayrshire	PJHE	2015-01-21
116	southayrshirecouncil	3afa1f3f7f0a8726480b38dbed741933	South Ayrshire Login	MJHS	2015-01-21
117	westdunbartonshire	40638e187eccb660739a2e8abf7990e4	West Dunbartonshire	MJHS	2015-01-21
118	bearnw	4c8e60ff968c191d59a43462661c66dc	Bear nw added	MJHS	2015-01-21
119	bearne	cc4ae016bebfc1122f4aaef707e28221	Created for Bear Scotland NE	PJHE	2015-01-22
121	bbcelawpr	1f311ad773e725f67da5e363beebaa79	Added for BBCEL AWPR	PJHE	2015-01-23
122	networkrail	059a30b14f4483bf37f3db256381cf17	Added for Network Rail	PJHE	2015-01-23
128	kentcoco	50bc0ef017f784afec86e4fa1261c09c	Adding user for Kent	MJHS	2015-01-24
129	moraycouncil	16de909616682ec765ee9c1ba3895040	Adding user for Moray	MJHS	2015-01-24
126	rutlandcoco	e56e088442e46b3388b538114f46d7eb	Adding Rutland user	MJHS	2015-01-24
139	kerry	0e62c056e53ce502bba1ae5b249970cf	Created for Kerry CC	RPK	2015-01-29
130	northyorkshirecoco	20d6952e6f148d35db21e7c812b65c52	Adding North Yorkshire user	MJHS	2015-01-24
131	transportforlondon	ba5148435b63ac8f2429daff87a6b367	Created for TFL	YBAR	2015-01-24
132	m6tollmidland	a5194f933633088a536dd472bb2501c2	Created for M6 Toll - Midland	YBAR	2015-01-25
133	m40carillion	83e1e0976ab1dea3a0d505551c345cd6	Created for M40/Carillion	YBAR	2015-01-25
134	ameym8dbfo	e8c2761deef80eecdce2be28f925aee0	Created for Amey M8 DBFO	YBAR	2015-01-25
135	ameyhighwaysse	d958cec8cb479485da0914061236415a	Created for Amey Highways SE	YBAR	2015-01-25
136	cornwall	fd0a63d46ffc71ba107a01db503defed	Created for Cornwall Council	HEC	2015-01-26
137	BOS	e529f1ffeb63c7d27e84f3d50b465a03	Boston Ligan International	STW	2015-01-28
140	BUF	e529f1ffeb63c7d27e84f3d50b465a03	Generic user	STW	2015-01-29
141	southampton	4a0df4a777107d83e62ec31f2c91a952	Adding southampton	RPK	2015-01-29
142	m77bbcel	891bc6d1fa6eb96ea10a2e58fae4a930	adding m77bbcel	rwil	2015-01-30
143	MHT	e529f1ffeb63c7d27e84f3d50b465a03	Manchester - Boston Regional	STW	2015-01-30
144	RWISPilot	b72a19a47c3aa6017104cde8789b36ef	Tenn RWIS Pilot Sites	STW	2015-01-30
145	ALDOT	b72a19a47c3aa6017104cde8789b36ef	Customer User	STW	2015-01-30
146	BWI	e529f1ffeb63c7d27e84f3d50b465a03	Part of Maryland Aviation (wb)	STW	2015-01-30
160	networkc	601c803b0c16a8de391fc0189ba0aef5	Created for Network C	HEC	2015-02-05
147	hmmni	48730caf613da7a3bd6955330df2790e	Created for HMM NI	HEC	2015-02-02
148	bos	e529f1ffeb63c7d27e84f3d50b465a03	2nd user lower case	STW	2015-02-02
149	mht	e529f1ffeb63c7d27e84f3d50b465a03	2nd lower case user	STW	2015-02-02
150	buf	e529f1ffeb63c7d27e84f3d50b465a03	2nd lower case user	STW	2015-02-02
151	tndot	b72a19a47c3aa6017104cde8789b36ef	2nd lower case user	STW	2015-02-02
152	bwi	e529f1ffeb63c7d27e84f3d50b465a03	2nd lowercase user	STW	2015-02-02
161	mayococo	beeafbea694a5fb79e2acfbb84b4f7d3	Created for Mayo	HEC	2015-02-05
154	kildarecoco	c5ce24cd1d4a67970a755c426619dc97	Created for Kildare	HEC	2015-02-03
155	belfastintairport	5fe328c450733e16f0fd4fe8bba7f0f0	adding belfast	rwil	2015-02-03
156	gdot	d6b904031a80e4c15044733ce3efbf30	Georgia Statewide	STW	2015-02-03
157	finavia	705950c96722e1beb531dc005c4bd301	Adding FINAVIA	RPK	2015-02-04
158	iddot	6e2abf0869dd41e8504fe4178e9bf5a8	My First add	HED	2015-02-04
159	gadot	d6b904031a80e4c15044733ce3efbf30	Georgia default user	STW	2015-02-04
162	knowsleymbc	8221ca2edce2ab44775e600aade18e1b	Created for Knowsley	HEC	2015-02-05
163	bradfordcity	1a1942036888683dac0dc1550a58643d	Adding user for Bradford	MJHS	2015-02-05
164	ameyliverpool	f9f1bf56e3bfd0e5f2a700c88330c67f	Adding new user for AMEY Liv	MJHS	2015-02-05
165	herefordshirecoco	f8d93e5cd84edea87541570d4632f558	Adding user to Herefordshire	MJHS	2015-02-05
166	wakefieldmdc	6fa02573e6875ddb880404d020d399ed	Created for Wakefield	HEC	2015-02-05
167	derbycity	5766deb2206c8b647409eab5a0c8f499	Created for Derby City	HEC	2015-02-05
168	cumbriacoco	6943a7ceb3f8b6946811b11287fb459c	Created for Cumbria	HEC	2015-02-06
169	shropshirecouncil	54a8b4c61b61d12b9ff056ac7f48d201	Created for Shropshire	HEC	2015-02-06
170	doncastermetboro	f7f54e61da41504cae9c9e7de58668c6	Set up for Doncaster	YBAR	2015-02-06
183	xna	e529f1ffeb63c7d27e84f3d50b465a03	new airport added	DRE	2015-02-20
181	kilkennycoco	b7f7ba240099d5402d0e4711ba1bcc66	Added for Kilkenny	YBAR	2015-02-18
172	wigan	641890d307444ad0efdc6dd453124106	Adding Wigan	RPK	2015-02-06
173	torfaencbc	27c6f798d94cd0b551c9b4f9a8a221e9	Created for Torfaen	HEC	2015-02-06
174	cardiffcity	82a1e7ad9733d8c094825a22f23930cc	Set up for Cardiff City	YBAR	2015-02-06
175	tameside	10428dcffe4e4790ea472d78d04c1f20	Created for Tameside	HEC	2015-02-09
176	rds	522a80b7a25f5fedbcee2b2c074ff3bd	rds global	jpc	2015-02-09
207	msdot	d6b904031a80e4c15044733ce3efbf30	Mississippi DOT Statewidw	STW	2015-08-24
178	nhdot	dd4bcb8803597ff2785225409f3049c2	New Hampshire DOT	STW	2015-02-10
179	massdot	d6b904031a80e4c15044733ce3efbf30	setting up new customer	dre	2015-02-11
180	wdsm	d6b904031a80e4c15044733ce3efbf30	City of West Des Moines	STW	2015-02-11
182	OMBC	07c366f28b5c919e023a5434d220b269	Asked for new un & pw	YBAR	2015-02-20
184	systestuser	13b9ce6723f8a54cf2c13947603be98b	Test	josp	2015-02-27
185	scotborders	6c9d689b0f140ae0009c31c31c224111	Added for Scottish Borders	YBAR	2015-03-06
186	aberdeenshirecouncil	e98bb0497ae042a5e89681444f23c71e	Added for Aberdeenshire	RWIL	2015-03-06
187	pne	4a776428d7409fc7091a8e2aaecbff48	NE Philadelphia Airport	STW	2015-03-17
188	iad	4a776428d7409fc7091a8e2aaecbff48	Dulles International Airport	STW	2015-03-18
189	tys	4a776428d7409fc7091a8e2aaecbff48	McGhee Tyson Airport	STW	2015-03-26
190	leedscitycouncil	52742b5032d47d5e4beac31086d0d806	Adding Leeds	MJHS	2015-03-30
191	daat	f43e949e6e206da9b24e8fb4a6747a0d	Dario Account	JOSP	2015-04-02
192	orkneyislands	3e92fd6936f5b86370661ebc80d829ab	Added for Orkney Islands	YBAR	2015-04-07
193	westernisles	6f80da7908b1d7eeb89bdda2c7cb964f	adding user for western isles	MJHS	2015-04-09
194	shetlandislands	d7913ca26da9ea350378533d7996845e	Adding user	MJHS	2015-05-05
195	nottinghamcity	b8d1369d50f2b680c323103512b36665	adding user for nottingham	MJHS	2015-05-11
196	tubelines	01e7b4b0b479b8d5d5ff0c66b4762ad2	Added for Tubelines	YBAR	2015-05-12
197	londonunderground	d7e5a53d4122f02fc05eeb3ade86ef5a	Added for London Underground	YBAR	2015-05-12
199	aldot	b72a19a47c3aa6017104cde8789b36ef	Lowercase user create	JOSP	2015-05-13
200	sea	4a776428d7409fc7091a8e2aaecbff48	SeaTac default user	stw	2015-05-14
201	transportni	dc0989470696d5d83f41a6abeb4e2326	Setup for Transport NI	YBAR	2015-05-21
202	vaisala	459513684e9e1301b1eaf3fef5e59d7e	Active Board of Directors acct	JOSP	2015-05-21
203	bbisla50	07b6e0064fde9818e1dac1087069fbbc	Created for BBISL A50	PJHE	2015-05-27
204	rno	4a776428d7409fc7091a8e2aaecbff48	Reno-Tahoe default user	STW	2015-06-23
205	stanstedairport	e8e232651fe3681bb2a0b4eac753f65f	set up new region	dri	2015-07-30
206	fnl	4a776428d7409fc7091a8e2aaecbff48	Loveland primary user	STW	2015-08-12
208	southeast	42de9cd92164ca7e1c8c6b1c06384acc	Regional map of Southeast	STW	2015-08-24
209	kingstonuponthames	8ea96930e812428ae7737bb294aecd67	MJHS	MJHS	2015-08-27
210	boi	4a776428d7409fc7091a8e2aaecbff48	Boise default user	STW	2015-09-08
211	stocktonborough	0297d4adb692623a8aa7cf5ee5acf83b	Adding new user	MJHS	2015-09-18
212	yyc	4a776428d7409fc7091a8e2aaecbff48	Calgary International default	STW	2015-09-21
54	lincs	3db323406278f8cb1b51b873593f0d6d	Another test account	REC	2013-12-11
214	vaistl	5f4dcc3b5aa765d61d8327deb882cf99	STL stations	jnb	2015-09-21
215	dia	4a776428d7409fc7091a8e2aaecbff48	DIA default user	STW	2015-10-07
216	ord	4a776428d7409fc7091a8e2aaecbff48	O'Hare default user	STW	2015-10-08
217	lincolnshire	0b59c62a3007a2ea81edc17c17e783f4	Lincolnshire County Council	GPA	2015-10-10
218	westmeathcoco	cfcb0f31d23e139cdf133c1384fb9bdb	Adding new user	MJHS	2015-10-10
232	mainedot	d6b904031a80e4c15044733ce3efbf30	Maiine DOt default user	STW	2015-11-03
219	sligococo	8fa9dfbc3c3cb529978152372ac6478f	SLIGO	MJHS	2015-10-10
220	midlink	1ff91603d49168d050c85c03684004f8	MIDLINK	MJHS	2015-10-10
221	lancashirecoco	c3328c66e2e59b9c4520619600745cbd	Created for Lancashire	rwil	2015-10-11
222	lincolnshirecoco	564f6c843364d3b31cb43167d3141985	Lincolnshire CoCO log in	GPA	2015-10-11
230	rijkswaterstaat	435e6393c808fe98cd6a263db4479a16	adding Ministerie van Verkeer	rpk	2015-10-28
224	louthcoco	60f40f2420390163935edc45de7704ee	adding new user	rpk	2015-10-12
225	landratsamt	841add545be57861bfd543896c49994b	Landratsamt user log in	GPA	2015-10-12
226	suffolk	8f1b41437a8d2674f7c04556642a07f5	Suffolk user	GPA	2015-10-12
227	newzealand	b1eaf0fe60816286a67becef737098cf	newzealand	MJHS	2015-10-14
228	tulsaroads	d6b904031a80e4c15044733ce3efbf30	Tulsa default password	STW	2015-10-19
223	BIRFRONTLINE	5eecb5aceea2e8bab3b8a9fc4ad577cd	MJHA	MJHS	2015-10-11
231	northvan	d6b904031a80e4c15044733ce3efbf30	North Vancouver default	STW	2015-10-29
233	pch	cddad90ec66deac557d9f41ee989566c	adding user	MJHS	2015-11-06
234	cg39	d6d1a5ac3f1c6c3e8d342d8128730a76	Adding CG39	RPK	2015-11-06
235	cg71	8c25f524d87615e30bc052c410f538a2	adding cg71	RPK	2015-11-06
236	adp	ce09cf32bd69e303bbdedaf3f93fa7ed	adding adp	RPK	2015-11-06
237	offaly	39ea46c63751d0edede9b05214103ffe	adding	dri	2015-11-10
238	torbaybc	7bfe7bc7a5ad32e5212822ce25c8b6c0	added	dri	2015-11-10
239	leicestershirecoco	e44aed4c863c531ed9faaf6b20b978c0	Added	dri	2015-11-10
\.


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

