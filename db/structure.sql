--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: authorizations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE authorizations (
    id integer NOT NULL,
    oauth_provider_id integer NOT NULL,
    user_id integer NOT NULL,
    uid text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE authorizations_id_seq OWNED BY authorizations.id;


--
-- Name: backers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE backers (
    id integer NOT NULL,
    project_id integer NOT NULL,
    user_id integer NOT NULL,
    reward_id integer,
    value numeric NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    confirmed_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    anonymous boolean DEFAULT false,
    key text,
    requested_refund boolean DEFAULT false,
    refunded boolean DEFAULT false,
    credits boolean DEFAULT false,
    notified_finish boolean DEFAULT false,
    payment_method text,
    payment_token text,
    payment_id character varying(255),
    payer_name text,
    payer_email text,
    payer_document text,
    address_street text,
    address_number text,
    address_complement text,
    address_neighbourhood text,
    address_zip_code text,
    address_city text,
    address_state text,
    address_phone_number text,
    payment_choice text,
    payment_service_fee numeric,
    CONSTRAINT backers_value_positive CHECK ((value >= (0)::numeric))
);


--
-- Name: rewards; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE rewards (
    id integer NOT NULL,
    project_id integer NOT NULL,
    minimum_value numeric NOT NULL,
    maximum_backers integer,
    description text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    reindex_versions timestamp without time zone,
    CONSTRAINT rewards_maximum_backers_positive CHECK ((maximum_backers >= 0)),
    CONSTRAINT rewards_minimum_value_positive CHECK ((minimum_value >= (0)::numeric))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    primary_user_id integer,
    provider text,
    uid text,
    email text,
    name text,
    nickname text,
    bio text,
    image_url text,
    newsletter boolean DEFAULT false,
    project_updates boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    admin boolean DEFAULT false,
    full_name text,
    address_street text,
    address_number text,
    address_complement text,
    address_neighbourhood text,
    address_city text,
    address_state text,
    address_zip_code text,
    phone_number text,
    locale text DEFAULT 'pt'::text NOT NULL,
    cpf text,
    encrypted_password character varying(128) DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    twitter character varying(255),
    facebook_link character varying(255),
    other_link character varying(255),
    uploaded_image text,
    moip_login character varying(255),
    state_inscription character varying(255),
    CONSTRAINT users_bio_length_within CHECK (((length(bio) >= 0) AND (length(bio) <= 140)))
);


--
-- Name: backer_reports; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backer_reports AS
    SELECT b.project_id, u.name, b.value, r.minimum_value, r.description, b.payment_method, b.payment_choice, b.payment_service_fee, b.key, (b.created_at)::date AS created_at, (b.confirmed_at)::date AS confirmed_at, u.email, b.payer_email, b.payer_name, COALESCE(b.payer_document, u.cpf) AS cpf, u.address_street, u.address_complement, u.address_number, u.address_neighbourhood, u.address_city, u.address_state, u.address_zip_code, b.requested_refund, b.refunded FROM ((backers b JOIN users u ON ((u.id = b.user_id))) LEFT JOIN rewards r ON ((r.id = b.reward_id))) WHERE b.confirmed;


--
-- Name: configurations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE configurations (
    id integer NOT NULL,
    name text NOT NULL,
    value text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT configurations_name_not_blank CHECK ((length(btrim(name)) > 0))
);


--
-- Name: backer_reports_for_project_owners; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backer_reports_for_project_owners AS
    SELECT b.project_id, COALESCE(r.id, 0) AS reward_id, r.description AS reward_description, (b.confirmed_at)::date AS confirmed_at, b.value AS back_value, (b.value * (SELECT (configurations.value)::numeric AS value FROM configurations WHERE (configurations.name = 'catarse_fee'::text))) AS service_fee, u.email AS user_email, u.name AS user_name, b.payer_email, b.payment_method, COALESCE(b.address_street, u.address_street) AS street, COALESCE(b.address_complement, u.address_complement) AS complement, COALESCE(b.address_number, u.address_number) AS address_number, COALESCE(b.address_neighbourhood, u.address_neighbourhood) AS neighbourhood, COALESCE(b.address_city, u.address_city) AS city, COALESCE(b.address_state, u.address_state) AS state, COALESCE(b.address_zip_code, u.address_zip_code) AS zip_code, b.anonymous FROM ((backers b JOIN users u ON ((u.id = b.user_id))) LEFT JOIN rewards r ON ((r.id = b.reward_id))) WHERE b.confirmed;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE categories (
    id integer NOT NULL,
    name_pt text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    name_en character varying(255),
    CONSTRAINT categories_name_not_blank CHECK ((length(btrim(name_pt)) > 0))
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE projects (
    id integer NOT NULL,
    name text NOT NULL,
    user_id integer NOT NULL,
    category_id integer NOT NULL,
    goal numeric NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    about text NOT NULL,
    headline text NOT NULL,
    video_url text,
    image_url text,
    short_url text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    can_finish boolean DEFAULT false,
    finished boolean DEFAULT false,
    about_html text,
    visible boolean DEFAULT false,
    rejected boolean DEFAULT false,
    recommended boolean DEFAULT false,
    home_page_comment text,
    successful boolean DEFAULT false,
    permalink text NOT NULL,
    video_thumbnail text,
    state character varying(255),
    online_days integer DEFAULT 0,
    online_date timestamp without time zone,
    how_know text,
    more_links text,
    first_backers text,
    uploaded_image character varying(255),
    CONSTRAINT projects_about_not_blank CHECK ((length(btrim(about)) > 0)),
    CONSTRAINT projects_headline_length_within CHECK (((length(headline) >= 1) AND (length(headline) <= 140))),
    CONSTRAINT projects_headline_not_blank CHECK ((length(btrim(headline)) > 0))
);


--
-- Name: backers_by_category; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backers_by_category AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, c.name_pt AS category, sum(b.value) AS total_backed, count(DISTINCT b.user_id) AS total_backers FROM ((backers b JOIN projects p ON ((p.id = b.project_id))) JOIN categories c ON ((c.id = p.category_id))) WHERE b.confirmed GROUP BY to_char(p.expires_at, 'yyyy'::text), c.name_pt ORDER BY to_char(p.expires_at, 'yyyy'::text), c.name_pt;


--
-- Name: backers_by_payment_choice; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backers_by_payment_choice AS
    SELECT to_char(p.expires_at, 'yyyy-mm'::text) AS month, backers.payment_method, backers.payment_choice, sum(backers.value) AS total_backed, (sum(backers.value) / bbm.total_month_backed) AS payment_choice_ratio, sum(CASE WHEN backers.refunded THEN backers.value ELSE NULL::numeric END) AS total_refunded, (sum(CASE WHEN backers.refunded THEN backers.value ELSE NULL::numeric END) / bbm.total_month_backed) AS refunded_ratio FROM ((projects p JOIN backers ON ((backers.project_id = p.id))) JOIN (SELECT to_char(b2.created_at, 'yyyy-mm'::text) AS b2month, sum(b2.value) AS total_month_backed FROM backers b2 WHERE b2.confirmed GROUP BY to_char(b2.created_at, 'yyyy-mm'::text)) bbm ON ((bbm.b2month = to_char(backers.created_at, 'yyyy-mm'::text)))) WHERE backers.confirmed GROUP BY to_char(p.expires_at, 'yyyy-mm'::text), bbm.total_month_backed, backers.payment_method, backers.payment_choice ORDER BY to_char(p.expires_at, 'yyyy-mm'::text), backers.payment_method, backers.payment_choice;


--
-- Name: backers_by_project; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backers_by_project AS
    SELECT backers.project_id, sum(backers.value) AS total_backed, max(backers.value) AS max_backed, count(DISTINCT backers.user_id) AS total_backers FROM backers WHERE backers.confirmed GROUP BY backers.project_id;


--
-- Name: backers_by_state; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backers_by_state AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, NULLIF(u.address_state, ''::text) AS state, sum(b.value) AS total_backed, count(DISTINCT b.user_id) AS total_backers FROM ((backers b JOIN projects p ON ((b.project_id = p.id))) JOIN users u ON ((u.id = b.user_id))) WHERE b.confirmed GROUP BY to_char(p.expires_at, 'yyyy'::text), NULLIF(u.address_state, ''::text) ORDER BY to_char(p.expires_at, 'yyyy'::text), NULLIF(u.address_state, ''::text);


--
-- Name: backers_by_year; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW backers_by_year AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, sum(backers.value) AS total_backed, count(DISTINCT backers.user_id) AS total_backers, count(DISTINCT CASE WHEN (backers.reward_id IS NULL) THEN backers.user_id ELSE NULL::integer END) AS total_backers_without_reward, ((count(DISTINCT CASE WHEN (backers.reward_id IS NULL) THEN backers.user_id ELSE NULL::integer END))::numeric / (count(DISTINCT backers.user_id))::numeric) AS backers_without_reward_ratio, max(backers.value) AS maximum_back FROM (backers JOIN projects p ON ((backers.project_id = p.id))) WHERE backers.confirmed GROUP BY to_char(p.expires_at, 'yyyy'::text);


--
-- Name: backers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE backers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE backers_id_seq OWNED BY backers.id;


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE channels (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    permalink character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    twitter character varying(255),
    facebook character varying(255),
    email character varying(255),
    image character varying(255),
    website character varying(255)
);


--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE channels_id_seq OWNED BY channels.id;


--
-- Name: channels_projects; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE channels_projects (
    id integer NOT NULL,
    channel_id integer,
    project_id integer
);


--
-- Name: channels_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE channels_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE channels_projects_id_seq OWNED BY channels_projects.id;


--
-- Name: channels_subscribers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE channels_subscribers (
    id integer NOT NULL,
    user_id integer NOT NULL,
    channel_id integer NOT NULL
);


--
-- Name: channels_subscribers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE channels_subscribers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_subscribers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE channels_subscribers_id_seq OWNED BY channels_subscribers.id;


--
-- Name: channels_trustees; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE channels_trustees (
    id integer NOT NULL,
    user_id integer,
    channel_id integer
);


--
-- Name: channels_trustees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE channels_trustees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_trustees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE channels_trustees_id_seq OWNED BY channels_trustees.id;


--
-- Name: configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE configurations_id_seq OWNED BY configurations.id;


--
-- Name: notification_types; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notification_types (
    id integer NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    layout text DEFAULT 'email'::text NOT NULL
);


--
-- Name: notification_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notification_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notification_types_id_seq OWNED BY notification_types.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer,
    dismissed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    notification_type_id integer NOT NULL,
    backer_id integer,
    update_id integer
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: oauth_providers; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE oauth_providers (
    id integer NOT NULL,
    name text NOT NULL,
    key text NOT NULL,
    secret text NOT NULL,
    scope text,
    "order" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    strategy text,
    path text,
    CONSTRAINT oauth_providers_key_not_blank CHECK ((length(btrim(key)) > 0)),
    CONSTRAINT oauth_providers_name_not_blank CHECK ((length(btrim(name)) > 0)),
    CONSTRAINT oauth_providers_secret_not_blank CHECK ((length(btrim(secret)) > 0))
);


--
-- Name: oauth_providers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE oauth_providers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_providers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE oauth_providers_id_seq OWNED BY oauth_providers.id;


--
-- Name: payment_logs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE payment_logs (
    id integer NOT NULL,
    backer_id integer,
    status integer,
    amount double precision,
    payment_status integer,
    moip_id integer,
    payment_method integer,
    payment_type character varying(255),
    consumer_email character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: payment_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE payment_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE payment_logs_id_seq OWNED BY payment_logs.id;


--
-- Name: payment_notifications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE payment_notifications (
    id integer NOT NULL,
    backer_id integer NOT NULL,
    extra_data text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: payment_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE payment_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE payment_notifications_id_seq OWNED BY payment_notifications.id;


--
-- Name: paypal_payments; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE paypal_payments (
    data text,
    hora text,
    fusohorario text,
    nome text,
    tipo text,
    status text,
    moeda text,
    valorbruto text,
    tarifa text,
    liquido text,
    doe_mail text,
    parae_mail text,
    iddatransacao text,
    statusdoequivalente text,
    statusdoendereco text,
    titulodoitem text,
    iddoitem text,
    valordoenvioemanuseio text,
    valordoseguro text,
    impostosobrevendas text,
    opcao1nome text,
    opcao1valor text,
    opcao2nome text,
    opcao2valor text,
    sitedoleilao text,
    iddocomprador text,
    urldoitem text,
    datadetermino text,
    iddaescritura text,
    iddafatura text,
    "idtxn_dereferência" text,
    numerodafatura text,
    numeropersonalizado text,
    iddorecibo text,
    saldo text,
    enderecolinha1 text,
    enderecolinha2_distrito_bairro text,
    cidade text,
    "estado_regiao_território_prefeitura_republica" text,
    cep text,
    pais text,
    numerodotelefoneparacontato text,
    extra text
);


--
-- Name: paypal_pending; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW paypal_pending AS
    SELECT string_agg((b.id)::text, ','::text) AS string_agg FROM (backers b JOIN paypal_payments p ON ((lower(p.doe_mail) = b.payer_email))) WHERE ((((b.payment_method = 'PayPal'::text) AND (p.status = 'Concluído'::text)) AND (NOT b.confirmed)) AND (to_number(p.valorbruto, '9,99'::text) = b.value));


--
-- Name: project_totals; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW project_totals AS
    SELECT backers.project_id, sum(backers.value) AS pledged, count(*) AS total_backers FROM backers WHERE (backers.confirmed = true) GROUP BY backers.project_id;


--
-- Name: projects_by_category; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW projects_by_category AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, c.name_pt AS category, count(*) AS total_projects, count(NULLIF(p.successful, false)) AS successful_projects FROM (projects p JOIN categories c ON ((c.id = p.category_id))) WHERE p.finished GROUP BY to_char(p.expires_at, 'yyyy'::text), c.name_pt ORDER BY to_char(p.expires_at, 'yyyy'::text), c.name_pt;


--
-- Name: projects_by_state; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW projects_by_state AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, NULLIF(btrim(u.address_state), ''::text) AS uf, count(*) AS total_projects, count(NULLIF(p.successful, false)) AS successful_projects FROM (projects p JOIN users u ON ((u.id = p.user_id))) WHERE p.finished GROUP BY to_char(p.expires_at, 'yyyy'::text), NULLIF(btrim(u.address_state), ''::text) ORDER BY to_char(p.expires_at, 'yyyy'::text), NULLIF(btrim(u.address_state), ''::text);


--
-- Name: total_backed_ranges; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE total_backed_ranges (
    name text NOT NULL,
    lower numeric,
    upper numeric
);


--
-- Name: projects_by_total_backed_ranges; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW projects_by_total_backed_ranges AS
    SELECT tbr.lower, tbr.upper, count(*) AS count, ((count(*))::numeric / ((SELECT count(*) AS count FROM backers_by_project))::numeric) AS ratio FROM (backers_by_project bp JOIN total_backed_ranges tbr ON (((bp.total_backed >= tbr.lower) AND (bp.total_backed <= tbr.upper)))) GROUP BY tbr.lower, tbr.upper ORDER BY tbr.lower;


--
-- Name: projects_by_year; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW projects_by_year AS
    SELECT to_char(p.expires_at, 'yyyy'::text) AS year, count(*) AS total_projects, count(NULLIF(p.successful, false)) AS successful_projects, sum(CASE WHEN p.successful THEN b.total_backed ELSE NULL::numeric END) AS successful_total_backed, max(b.total_backed) AS max_total_backed, max(b.max_backed) AS max_backed, max(b.total_backers) AS max_total_backers FROM (projects p LEFT JOIN backers_by_project b ON ((b.project_id = p.id))) WHERE p.finished GROUP BY to_char(p.expires_at, 'yyyy'::text) ORDER BY to_char(p.expires_at, 'yyyy'::text);


--
-- Name: projects_curated_pages; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE projects_curated_pages (
    id integer NOT NULL,
    project_id integer,
    curated_page_id integer,
    description text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    description_html text
);


--
-- Name: projects_curated_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projects_curated_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_curated_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projects_curated_pages_id_seq OWNED BY projects_curated_pages.id;


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE projects_id_seq OWNED BY projects.id;


--
-- Name: recurring_backers_by_year; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW recurring_backers_by_year AS
    SELECT bby.year, trb.total_recurring_backed, bby.total_backed, (trb.total_recurring_backed / bby.total_backed) AS recurring_backed_ratio, trb.total_recurring_backers, bby.total_backers, (trb.total_recurring_backers / (bby.total_backers)::numeric) AS recurring_backers_ratio FROM ((SELECT rb.year, sum(rb.total_recurring_backed) AS total_recurring_backed, sum(rb.total_recurring_backers) AS total_recurring_backers FROM (SELECT to_char(backers.created_at, 'yyyy'::text) AS year, sum(backers.value) AS total_recurring_backed, count(DISTINCT backers.user_id) AS total_recurring_backers FROM backers WHERE backers.confirmed GROUP BY to_char(backers.created_at, 'yyyy'::text), backers.user_id HAVING (count(*) > 1)) rb GROUP BY rb.year) trb JOIN backers_by_year bby USING (year));


--
-- Name: reward_ranges; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE reward_ranges (
    name text NOT NULL,
    lower numeric,
    upper numeric
);


--
-- Name: rewards_by_range; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW rewards_by_range AS
    SELECT rr.name AS range, count(*) AS count, ((count(*))::numeric / ((SELECT count(*) AS count FROM backers WHERE (backers.confirmed AND (backers.reward_id IS NOT NULL))))::numeric) AS ratio FROM ((reward_ranges rr JOIN rewards r ON (((r.minimum_value >= rr.lower) AND (r.minimum_value <= rr.upper)))) JOIN backers b ON ((b.reward_id = r.id))) WHERE b.confirmed GROUP BY rr.name, rr.lower ORDER BY rr.lower;


--
-- Name: rewards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE rewards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rewards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE rewards_id_seq OWNED BY rewards.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: states; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE states (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    acronym character varying(255) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT states_acronym_not_blank CHECK ((length(btrim((acronym)::text)) > 0)),
    CONSTRAINT states_name_not_blank CHECK ((length(btrim((name)::text)) > 0))
);


--
-- Name: states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE states_id_seq OWNED BY states.id;


--
-- Name: statistics; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW statistics AS
    SELECT (SELECT count(*) AS count FROM users) AS total_users, backers_totals.total_backs, backers_totals.total_backers, backers_totals.total_backed, projects_totals.total_projects, projects_totals.total_projects_success, projects_totals.total_projects_online FROM (SELECT count(*) AS total_backs, count(DISTINCT backers.user_id) AS total_backers, sum(backers.value) AS total_backed FROM backers WHERE backers.confirmed) backers_totals, (SELECT count(*) AS total_projects, count(CASE WHEN ((projects.state)::text = 'successful'::text) THEN 1 ELSE NULL::integer END) AS total_projects_success, count(CASE WHEN ((projects.state)::text = 'online'::text) THEN 1 ELSE NULL::integer END) AS total_projects_online FROM projects WHERE ((projects.state)::text <> ALL (ARRAY[('draft'::character varying)::text, ('rejected'::character varying)::text]))) projects_totals;


--
-- Name: unsubscribes; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE unsubscribes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    notification_type_id integer NOT NULL,
    project_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: unsubscribes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE unsubscribes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: unsubscribes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE unsubscribes_id_seq OWNED BY unsubscribes.id;


--
-- Name: updates; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE updates (
    id integer NOT NULL,
    user_id integer NOT NULL,
    project_id integer NOT NULL,
    title text,
    comment text NOT NULL,
    comment_html text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE updates_id_seq OWNED BY updates.id;


--
-- Name: user_totals; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW user_totals AS
    SELECT b.user_id AS id, b.user_id, sum(b.value) AS sum, count(*) AS count, sum(CASE WHEN (((p.state)::text <> 'failed'::text) AND (NOT b.credits)) THEN (0)::numeric WHEN (((p.state)::text = 'failed'::text) AND ((b.requested_refund AND (NOT b.credits)) OR (b.credits AND (NOT b.requested_refund)))) THEN (0)::numeric WHEN ((((p.state)::text = 'failed'::text) AND (NOT b.credits)) AND (NOT b.requested_refund)) THEN b.value ELSE (b.value * ((-1))::numeric) END) AS credits FROM (backers b JOIN projects p ON ((b.project_id = p.id))) WHERE (b.confirmed = true) GROUP BY b.user_id;


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE versions (
    id integer NOT NULL,
    item_type character varying(255) NOT NULL,
    item_id integer NOT NULL,
    event character varying(255) NOT NULL,
    whodunnit character varying(255),
    object text,
    created_at timestamp without time zone
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY authorizations ALTER COLUMN id SET DEFAULT nextval('authorizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY backers ALTER COLUMN id SET DEFAULT nextval('backers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels ALTER COLUMN id SET DEFAULT nextval('channels_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_projects ALTER COLUMN id SET DEFAULT nextval('channels_projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_subscribers ALTER COLUMN id SET DEFAULT nextval('channels_subscribers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_trustees ALTER COLUMN id SET DEFAULT nextval('channels_trustees_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY configurations ALTER COLUMN id SET DEFAULT nextval('configurations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notification_types ALTER COLUMN id SET DEFAULT nextval('notification_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY oauth_providers ALTER COLUMN id SET DEFAULT nextval('oauth_providers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY payment_logs ALTER COLUMN id SET DEFAULT nextval('payment_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY payment_notifications ALTER COLUMN id SET DEFAULT nextval('payment_notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects ALTER COLUMN id SET DEFAULT nextval('projects_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects_curated_pages ALTER COLUMN id SET DEFAULT nextval('projects_curated_pages_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY rewards ALTER COLUMN id SET DEFAULT nextval('rewards_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY states ALTER COLUMN id SET DEFAULT nextval('states_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY unsubscribes ALTER COLUMN id SET DEFAULT nextval('unsubscribes_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY updates ALTER COLUMN id SET DEFAULT nextval('updates_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


--
-- Name: authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT authorizations_pkey PRIMARY KEY (id);


--
-- Name: backers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY backers
    ADD CONSTRAINT backers_pkey PRIMARY KEY (id);


--
-- Name: categories_name_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_name_unique UNIQUE (name_pt);


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: channel_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY channels
    ADD CONSTRAINT channel_profiles_pkey PRIMARY KEY (id);


--
-- Name: channels_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY channels_projects
    ADD CONSTRAINT channels_projects_pkey PRIMARY KEY (id);


--
-- Name: channels_subscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY channels_subscribers
    ADD CONSTRAINT channels_subscribers_pkey PRIMARY KEY (id);


--
-- Name: channels_trustees_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY channels_trustees
    ADD CONSTRAINT channels_trustees_pkey PRIMARY KEY (id);


--
-- Name: configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY configurations
    ADD CONSTRAINT configurations_pkey PRIMARY KEY (id);


--
-- Name: notification_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notification_types
    ADD CONSTRAINT notification_types_pkey PRIMARY KEY (id);


--
-- Name: notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: oauth_providers_name_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_providers
    ADD CONSTRAINT oauth_providers_name_unique UNIQUE (name);


--
-- Name: oauth_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY oauth_providers
    ADD CONSTRAINT oauth_providers_pkey PRIMARY KEY (id);


--
-- Name: payment_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY payment_logs
    ADD CONSTRAINT payment_logs_pkey PRIMARY KEY (id);


--
-- Name: payment_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY payment_notifications
    ADD CONSTRAINT payment_notifications_pkey PRIMARY KEY (id);


--
-- Name: projects_curated_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projects_curated_pages
    ADD CONSTRAINT projects_curated_pages_pkey PRIMARY KEY (id);


--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: reward_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY reward_ranges
    ADD CONSTRAINT reward_ranges_pkey PRIMARY KEY (name);


--
-- Name: rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY rewards
    ADD CONSTRAINT rewards_pkey PRIMARY KEY (id);


--
-- Name: states_acronym_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_acronym_unique UNIQUE (acronym);


--
-- Name: states_name_unique; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_name_unique UNIQUE (name);


--
-- Name: states_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: total_backed_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY total_backed_ranges
    ADD CONSTRAINT total_backed_ranges_pkey PRIMARY KEY (name);


--
-- Name: unsubscribes_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY unsubscribes
    ADD CONSTRAINT unsubscribes_pkey PRIMARY KEY (id);


--
-- Name: updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY updates
    ADD CONSTRAINT updates_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: fk__authorizations_oauth_provider_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk__authorizations_oauth_provider_id ON authorizations USING btree (oauth_provider_id);


--
-- Name: fk__authorizations_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk__authorizations_user_id ON authorizations USING btree (user_id);


--
-- Name: fk__channels_subscribers_channel_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk__channels_subscribers_channel_id ON channels_subscribers USING btree (channel_id);


--
-- Name: fk__channels_subscribers_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX fk__channels_subscribers_user_id ON channels_subscribers USING btree (user_id);


--
-- Name: index_authorizations_on_uid_and_oauth_provider_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_authorizations_on_uid_and_oauth_provider_id ON authorizations USING btree (uid, oauth_provider_id);


--
-- Name: index_backers_on_confirmed; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_backers_on_confirmed ON backers USING btree (confirmed);


--
-- Name: index_backers_on_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_backers_on_key ON backers USING btree (key);


--
-- Name: index_backers_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_backers_on_project_id ON backers USING btree (project_id);


--
-- Name: index_backers_on_reward_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_backers_on_reward_id ON backers USING btree (reward_id);


--
-- Name: index_backers_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_backers_on_user_id ON backers USING btree (user_id);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_categories_on_name ON categories USING btree (name_pt);


--
-- Name: index_channels_on_permalink; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_channels_on_permalink ON channels USING btree (permalink);


--
-- Name: index_channels_projects_on_channel_id_and_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_channels_projects_on_channel_id_and_project_id ON channels_projects USING btree (channel_id, project_id);


--
-- Name: index_channels_projects_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_channels_projects_on_project_id ON channels_projects USING btree (project_id);


--
-- Name: index_channels_subscribers_on_user_id_and_channel_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_channels_subscribers_on_user_id_and_channel_id ON channels_subscribers USING btree (user_id, channel_id);


--
-- Name: index_channels_trustees_on_channel_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_channels_trustees_on_channel_id ON channels_trustees USING btree (channel_id);


--
-- Name: index_channels_trustees_on_user_id_and_channel_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_channels_trustees_on_user_id_and_channel_id ON channels_trustees USING btree (user_id, channel_id);


--
-- Name: index_configurations_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_configurations_on_name ON configurations USING btree (name);


--
-- Name: index_confirmed_backers_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_confirmed_backers_on_project_id ON backers USING btree (project_id) WHERE confirmed;


--
-- Name: index_notification_types_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_notification_types_on_name ON notification_types USING btree (name);


--
-- Name: index_notifications_on_update_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notifications_on_update_id ON notifications USING btree (update_id);


--
-- Name: index_projects_on_category_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_projects_on_category_id ON projects USING btree (category_id);


--
-- Name: index_projects_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_projects_on_name ON projects USING btree (name);


--
-- Name: index_projects_on_permalink; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_projects_on_permalink ON projects USING btree (permalink);


--
-- Name: index_projects_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_projects_on_user_id ON projects USING btree (user_id);


--
-- Name: index_rewards_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_rewards_on_project_id ON rewards USING btree (project_id);


--
-- Name: index_unsubscribes_on_notification_type_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_unsubscribes_on_notification_type_id ON unsubscribes USING btree (notification_type_id);


--
-- Name: index_unsubscribes_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_unsubscribes_on_project_id ON unsubscribes USING btree (project_id);


--
-- Name: index_unsubscribes_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_unsubscribes_on_user_id ON unsubscribes USING btree (user_id);


--
-- Name: index_updates_on_project_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_updates_on_project_id ON updates USING btree (project_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_name ON users USING btree (name);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON users USING btree (reset_password_token);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_item_type_and_item_id ON versions USING btree (item_type, item_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- Name: backers_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY backers
    ADD CONSTRAINT backers_project_id_reference FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: backers_reward_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY backers
    ADD CONSTRAINT backers_reward_id_reference FOREIGN KEY (reward_id) REFERENCES rewards(id);


--
-- Name: backers_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY backers
    ADD CONSTRAINT backers_user_id_reference FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: fk_authorizations_oauth_provider_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT fk_authorizations_oauth_provider_id FOREIGN KEY (oauth_provider_id) REFERENCES oauth_providers(id);


--
-- Name: fk_authorizations_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY authorizations
    ADD CONSTRAINT fk_authorizations_user_id FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: fk_channels_projects_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_projects
    ADD CONSTRAINT fk_channels_projects_channel_id FOREIGN KEY (channel_id) REFERENCES channels(id);


--
-- Name: fk_channels_projects_project_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_projects
    ADD CONSTRAINT fk_channels_projects_project_id FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: fk_channels_subscribers_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_subscribers
    ADD CONSTRAINT fk_channels_subscribers_channel_id FOREIGN KEY (channel_id) REFERENCES channels(id);


--
-- Name: fk_channels_subscribers_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_subscribers
    ADD CONSTRAINT fk_channels_subscribers_user_id FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: fk_channels_trustees_channel_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_trustees
    ADD CONSTRAINT fk_channels_trustees_channel_id FOREIGN KEY (channel_id) REFERENCES channels(id);


--
-- Name: fk_channels_trustees_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY channels_trustees
    ADD CONSTRAINT fk_channels_trustees_user_id FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: notifications_backer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_backer_id_fk FOREIGN KEY (backer_id) REFERENCES backers(id);


--
-- Name: notifications_notification_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_notification_type_id_fk FOREIGN KEY (notification_type_id) REFERENCES notification_types(id);


--
-- Name: notifications_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_project_id_reference FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: notifications_update_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_update_id_fk FOREIGN KEY (update_id) REFERENCES updates(id);


--
-- Name: notifications_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_user_id_reference FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: payment_notifications_backer_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY payment_notifications
    ADD CONSTRAINT payment_notifications_backer_id_fk FOREIGN KEY (backer_id) REFERENCES backers(id);


--
-- Name: projects_category_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_category_id_reference FOREIGN KEY (category_id) REFERENCES categories(id);


--
-- Name: projects_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_user_id_reference FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: rewards_project_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rewards
    ADD CONSTRAINT rewards_project_id_reference FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: unsubscribes_notification_type_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY unsubscribes
    ADD CONSTRAINT unsubscribes_notification_type_id_fk FOREIGN KEY (notification_type_id) REFERENCES notification_types(id);


--
-- Name: unsubscribes_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY unsubscribes
    ADD CONSTRAINT unsubscribes_project_id_fk FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: unsubscribes_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY unsubscribes
    ADD CONSTRAINT unsubscribes_user_id_fk FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: updates_project_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY updates
    ADD CONSTRAINT updates_project_id_fk FOREIGN KEY (project_id) REFERENCES projects(id);


--
-- Name: updates_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY updates
    ADD CONSTRAINT updates_user_id_fk FOREIGN KEY (user_id) REFERENCES users(id);


--
-- Name: users_primary_user_id_reference; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_primary_user_id_reference FOREIGN KEY (primary_user_id) REFERENCES users(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO schema_migrations (version) VALUES ('20121226120921');

INSERT INTO schema_migrations (version) VALUES ('20121227012003');

INSERT INTO schema_migrations (version) VALUES ('20121227012324');

INSERT INTO schema_migrations (version) VALUES ('20121230111351');

INSERT INTO schema_migrations (version) VALUES ('20130102180139');

INSERT INTO schema_migrations (version) VALUES ('20130104005632');

INSERT INTO schema_migrations (version) VALUES ('20130104104501');

INSERT INTO schema_migrations (version) VALUES ('20130105123546');

INSERT INTO schema_migrations (version) VALUES ('20130110191750');

INSERT INTO schema_migrations (version) VALUES ('20130117205659');

INSERT INTO schema_migrations (version) VALUES ('20130118193907');

INSERT INTO schema_migrations (version) VALUES ('20130121162447');

INSERT INTO schema_migrations (version) VALUES ('20130121204224');

INSERT INTO schema_migrations (version) VALUES ('20130121212325');

INSERT INTO schema_migrations (version) VALUES ('20130131121553');

INSERT INTO schema_migrations (version) VALUES ('20130201200604');

INSERT INTO schema_migrations (version) VALUES ('20130201202648');

INSERT INTO schema_migrations (version) VALUES ('20130201202829');

INSERT INTO schema_migrations (version) VALUES ('20130201205659');

INSERT INTO schema_migrations (version) VALUES ('20130204192704');

INSERT INTO schema_migrations (version) VALUES ('20130205143533');

INSERT INTO schema_migrations (version) VALUES ('20130206121758');

INSERT INTO schema_migrations (version) VALUES ('20130211174609');

INSERT INTO schema_migrations (version) VALUES ('20130212145115');

INSERT INTO schema_migrations (version) VALUES ('20130213184141');

INSERT INTO schema_migrations (version) VALUES ('20130218201312');

INSERT INTO schema_migrations (version) VALUES ('20130218201751');

INSERT INTO schema_migrations (version) VALUES ('20130221171018');

INSERT INTO schema_migrations (version) VALUES ('20130221172840');

INSERT INTO schema_migrations (version) VALUES ('20130221175717');

INSERT INTO schema_migrations (version) VALUES ('20130221184144');

INSERT INTO schema_migrations (version) VALUES ('20130221185532');

INSERT INTO schema_migrations (version) VALUES ('20130221201732');

INSERT INTO schema_migrations (version) VALUES ('20130222163633');

INSERT INTO schema_migrations (version) VALUES ('20130225135512');

INSERT INTO schema_migrations (version) VALUES ('20130225141802');

INSERT INTO schema_migrations (version) VALUES ('20130228141234');

INSERT INTO schema_migrations (version) VALUES ('20130304193806');

INSERT INTO schema_migrations (version) VALUES ('20130307074614');

INSERT INTO schema_migrations (version) VALUES ('20130307090153');

INSERT INTO schema_migrations (version) VALUES ('20130308200907');

INSERT INTO schema_migrations (version) VALUES ('20130311191444');

INSERT INTO schema_migrations (version) VALUES ('20130311192846');

INSERT INTO schema_migrations (version) VALUES ('20130312001021');

INSERT INTO schema_migrations (version) VALUES ('20130313032607');

INSERT INTO schema_migrations (version) VALUES ('20130313034356');

INSERT INTO schema_migrations (version) VALUES ('20130319131919');

INSERT INTO schema_migrations (version) VALUES ('20130410181958');

INSERT INTO schema_migrations (version) VALUES ('20130410190247');

INSERT INTO schema_migrations (version) VALUES ('20130410191240');

INSERT INTO schema_migrations (version) VALUES ('20130411193016');

INSERT INTO schema_migrations (version) VALUES ('20130422071805');

INSERT INTO schema_migrations (version) VALUES ('20130422072051');

INSERT INTO schema_migrations (version) VALUES ('20130429142823');

INSERT INTO schema_migrations (version) VALUES ('20130429144749');

INSERT INTO schema_migrations (version) VALUES ('20130429153115');

INSERT INTO schema_migrations (version) VALUES ('20130430203333');

INSERT INTO schema_migrations (version) VALUES ('20130502175814');