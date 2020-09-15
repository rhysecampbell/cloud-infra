---------------------------------------------------------------------------------------------------------------------
-- Sequence: user_id_seq

-- DROP SEQUENCE user_id_seq;

CREATE SEQUENCE user_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE user_id_seq
  OWNER TO postgres;



-- Table: "users"

-- DROP TABLE "users";

CREATE TABLE "users"
(
  id integer NOT NULL DEFAULT nextval('user_id_seq'::regclass), -- users ID
  username character varying(24) NOT NULL, -- users login name
  password character(32), -- salted MD5
  comments character varying(120),
  added_by character varying(24),
  date_added date NOT NULL DEFAULT now(),
  CONSTRAINT user_pkey PRIMARY KEY (id),
  CONSTRAINT user_username_key UNIQUE (username)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE "users"
  OWNER TO postgres;
COMMENT ON COLUMN "users".id IS 'users ID';
COMMENT ON COLUMN "users".username IS 'username';
COMMENT ON COLUMN "users".password IS 'salted MD5';
---------------------------------------------------------------------------------------------------------------------
-- Sequence: user_roles_id_seq

-- DROP SEQUENCE user_roles_id_seq;

CREATE SEQUENCE user_roles_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE user_roles_id_seq
  OWNER TO postgres;


-- Table: user_roles

-- DROP TABLE user_roles;

CREATE TABLE user_roles
(
  id integer NOT NULL DEFAULT nextval('user_roles_id_seq'::regclass),
  role character varying(24),
  role_description character varying(120),
  added_by character varying(24),
  date_added date NOT NULL DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (id),
  CONSTRAINT roles_role_key UNIQUE (role)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE user_roles
  OWNER TO postgres;
COMMENT ON TABLE user_roles
  IS 'List of different user_roles available';
---------------------------------------------------------------------------------------------------------------------
-- Sequence: user_roles_ref_id_seq

-- DROP SEQUENCE user_roles_ref_id_seq;

CREATE SEQUENCE user_roles_ref_id_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE user_roles_ref_id_seq
  OWNER TO postgres;


-- Table: user_roles_ref

-- DROP TABLE user_roles_ref;

CREATE TABLE user_roles_ref
(
  id integer NOT NULL DEFAULT nextval('user_roles_ref_id_seq'::regclass), -- Reference ID
  uid integer, -- User ID
  rid integer, -- Role ID
  CONSTRAINT user_role_ref_pkey PRIMARY KEY (id)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE user_roles_ref
  OWNER TO postgres;
COMMENT ON COLUMN user_roles_ref.id IS 'Reference ID';
COMMENT ON COLUMN user_roles_ref.uid IS 'User ID';
COMMENT ON COLUMN user_roles_ref.rid IS 'Role ID';
---------------------------------------------------------------------------------------------------------------------
CREATE VIEW tomcat_roles AS 
SELECT
	u.username,
	r.role,
	u.comments,
	u.added_by,
	u.date_added
FROM users AS u
INNER JOIN user_roles_ref AS f ON u.id = f.uid
INNER JOIN user_roles AS r ON r.id = f.rid