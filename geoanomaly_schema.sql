--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.5

-- Started on 2025-07-17 11:30:22

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2 (class 3079 OID 17349)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 4990 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 247 (class 1255 OID 17616)
-- Name: create_test_zones(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_test_zones(zone_count integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INTEGER;
    batch_size INTEGER := 1000;
    current_batch INTEGER := 0;
BEGIN
    -- Enable progress reporting
    RAISE NOTICE 'Starting creation of % test zones...', zone_count;
    
    WHILE current_batch < zone_count LOOP
        INSERT INTO zones (
            id, name, description,
            location_latitude, location_longitude,
            radius_meters, tier_required, zone_type,
            expires_at, last_activity, auto_cleanup,
            biome, danger_level, properties, is_active
        )
        SELECT 
            uuid_generate_v4(),
            'LoadTest Zone ' || generate_series,
            'Performance testing zone #' || generate_series,
            -- Random GPS coordinates around Bratislava
            48.1486 + (random() - 0.5) * 0.1,
            17.1077 + (random() - 0.5) * 0.1,
            -- Random radius 100-500m
            (random() * 400 + 100)::integer,
            -- Random tier 1-4
            (random() * 3 + 1)::integer,
            'dynamic',
            -- Random expiry 1-60 minutes from now
            CURRENT_TIMESTAMP + (random() * 60 || ' minutes')::interval,
            CURRENT_TIMESTAMP,
            true,
            (ARRAY['urban', 'forest', 'mountain', 'desert', 'coastal'])[floor(random() * 5 + 1)],
            (ARRAY['low', 'medium', 'high'])[floor(random() * 3 + 1)],
            '{"test": true, "batch": "load_test", "created_at": "2025-07-14T13:43:32Z"}'::jsonb,
            true
        FROM generate_series(current_batch + 1, LEAST(current_batch + batch_size, zone_count));
        
        current_batch := current_batch + batch_size;
        
        -- Progress indicator
        RAISE NOTICE 'Created batch: % zones (% / %)', batch_size, current_batch, zone_count;
    END LOOP;
    
    RAISE NOTICE 'Successfully created % test zones', zone_count;
END;
$$;


ALTER FUNCTION public.create_test_zones(zone_count integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 17432)
-- Name: artifacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.artifacts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone,
    zone_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(50) NOT NULL,
    rarity character varying(20) NOT NULL,
    location_latitude numeric(10,8) NOT NULL,
    location_longitude numeric(11,8) NOT NULL,
    location_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    properties jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    biome character varying(50) DEFAULT 'forest'::character varying,
    exclusive_to_biome boolean DEFAULT false,
    CONSTRAINT check_latitude CHECK (((location_latitude >= ('-90'::integer)::numeric) AND (location_latitude <= (90)::numeric))),
    CONSTRAINT check_longitude CHECK (((location_longitude >= ('-180'::integer)::numeric) AND (location_longitude <= (180)::numeric))),
    CONSTRAINT check_rarity CHECK (((rarity)::text = ANY ((ARRAY['common'::character varying, 'rare'::character varying, 'epic'::character varying, 'legendary'::character varying])::text[]))),
    CONSTRAINT check_type CHECK (((type)::text = ANY ((ARRAY['ancient_coin'::character varying, 'crystal'::character varying, 'rune'::character varying, 'scroll'::character varying, 'gem'::character varying, 'tablet'::character varying, 'orb'::character varying, 'urban_artifact'::character varying, 'medical_supplies'::character varying, 'cash_register'::character varying, 'mushroom_sample'::character varying, 'tree_resin'::character varying, 'animal_bones'::character varying, 'herbal_extract'::character varying, 'steel_ingot'::character varying, 'machinery_parts'::character varying, 'electronic_component'::character varying, 'chemical_sample'::character varying, 'aquatic_plant'::character varying, 'contaminated_water'::character varying, 'uranium_ore'::character varying, 'radiation_detector'::character varying, 'contaminated_soil'::character varying, 'atomic_battery'::character varying, 'mountain_crystal'::character varying, 'rare_mineral'::character varying, 'toxic_waste'::character varying, 'chemical_compound'::character varying])::text[])))
);


ALTER TABLE public.artifacts OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17454)
-- Name: gear; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gear (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone,
    zone_id uuid NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(50) NOT NULL,
    level integer NOT NULL,
    location_latitude numeric(10,8) NOT NULL,
    location_longitude numeric(11,8) NOT NULL,
    location_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    properties jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    biome character varying(50) DEFAULT 'forest'::character varying,
    exclusive_to_biome boolean DEFAULT false,
    CONSTRAINT check_gear_type CHECK (((type)::text = ANY ((ARRAY['sword'::character varying, 'shield'::character varying, 'armor'::character varying, 'boots'::character varying, 'helmet'::character varying, 'ring'::character varying, 'amulet'::character varying, 'flashlight'::character varying, 'crowbar'::character varying, 'first_aid_kit'::character varying, 'hunting_knife'::character varying, 'leather_boots'::character varying, 'wooden_bow'::character varying, 'hard_hat'::character varying, 'safety_gloves'::character varying, 'welding_mask'::character varying, 'water_purifier'::character varying, 'waders'::character varying, 'fishing_gear'::character varying, 'radiation_pills'::character varying, 'hazmat_suit'::character varying, 'dosimeter'::character varying, 'climbing_gear'::character varying, 'mountain_boots'::character varying, 'gas_mask'::character varying, 'chemical_suit'::character varying])::text[]))),
    CONSTRAINT check_latitude CHECK (((location_latitude >= ('-90'::integer)::numeric) AND (location_latitude <= (90)::numeric))),
    CONSTRAINT check_level CHECK (((level >= 1) AND (level <= 10))),
    CONSTRAINT check_longitude CHECK (((location_longitude >= ('-180'::integer)::numeric) AND (location_longitude <= (180)::numeric)))
);


ALTER TABLE public.gear OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17476)
-- Name: inventory_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone,
    user_id uuid NOT NULL,
    item_type character varying(20) NOT NULL,
    item_id uuid NOT NULL,
    quantity integer DEFAULT 1,
    properties jsonb DEFAULT '{}'::jsonb,
    acquired_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_item_type CHECK (((item_type)::text = ANY ((ARRAY['artifact'::character varying, 'gear'::character varying])::text[]))),
    CONSTRAINT check_quantity CHECK ((quantity >= 0))
);


ALTER TABLE public.inventory_items OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17372)
-- Name: level_definitions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.level_definitions (
    level integer NOT NULL,
    xp_required integer NOT NULL,
    level_name character varying(50),
    features_unlocked jsonb DEFAULT '{}'::jsonb,
    cosmetic_unlocks jsonb DEFAULT '{}'::jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_level CHECK (((level >= 1) AND (level <= 200))),
    CONSTRAINT check_xp CHECK ((xp_required >= 0))
);


ALTER TABLE public.level_definitions OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17498)
-- Name: player_sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.player_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id uuid NOT NULL,
    last_seen timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_online boolean DEFAULT true,
    current_zone uuid,
    last_location_latitude numeric(10,8),
    last_location_longitude numeric(11,8),
    last_location_accuracy numeric(10,2),
    last_location_timestamp timestamp without time zone,
    CONSTRAINT check_latitude CHECK (((last_location_latitude IS NULL) OR ((last_location_latitude >= ('-90'::integer)::numeric) AND (last_location_latitude <= (90)::numeric)))),
    CONSTRAINT check_longitude CHECK (((last_location_longitude IS NULL) OR ((last_location_longitude >= ('-180'::integer)::numeric) AND (last_location_longitude <= (180)::numeric))))
);


ALTER TABLE public.player_sessions OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 17360)
-- Name: tier_definitions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tier_definitions (
    tier_level integer NOT NULL,
    tier_name character varying(50) NOT NULL,
    price_monthly numeric(10,2),
    max_zones_per_scan integer NOT NULL,
    collect_cooldown_seconds integer NOT NULL,
    scan_cooldown_minutes integer NOT NULL,
    inventory_slots integer NOT NULL,
    features jsonb DEFAULT '{}'::jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT check_price CHECK ((price_monthly >= (0)::numeric)),
    CONSTRAINT check_tier_level CHECK (((tier_level >= 0) AND (tier_level <= 5)))
);


ALTER TABLE public.tier_definitions OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17384)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    tier integer DEFAULT 0,
    tier_expires timestamp without time zone,
    tier_auto_renew boolean DEFAULT false,
    xp integer DEFAULT 0,
    level integer DEFAULT 1,
    total_artifacts integer DEFAULT 0,
    total_gear integer DEFAULT 0,
    zones_discovered integer DEFAULT 0,
    is_active boolean DEFAULT true,
    is_banned boolean DEFAULT false,
    last_login timestamp without time zone,
    profile_data jsonb DEFAULT '{}'::jsonb,
    CONSTRAINT check_email_format CHECK (((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)),
    CONSTRAINT check_level CHECK (((level >= 1) AND (level <= 200))),
    CONSTRAINT check_tier CHECK (((tier >= 0) AND (tier <= 5))),
    CONSTRAINT check_username_length CHECK ((length((username)::text) >= 3)),
    CONSTRAINT check_xp CHECK ((xp >= 0))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17413)
-- Name: zones; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.zones (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp without time zone,
    name character varying(100) NOT NULL,
    description text,
    location_latitude numeric(10,8) NOT NULL,
    location_longitude numeric(11,8) NOT NULL,
    location_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    radius_meters integer NOT NULL,
    tier_required integer NOT NULL,
    zone_type character varying(20) DEFAULT 'static'::character varying NOT NULL,
    properties jsonb DEFAULT '{}'::jsonb,
    is_active boolean DEFAULT true,
    biome character varying(50) DEFAULT 'forest'::character varying,
    danger_level character varying(20) DEFAULT 'low'::character varying,
    environmental_effects jsonb DEFAULT '{}'::jsonb,
    expires_at timestamp without time zone,
    last_activity timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    auto_cleanup boolean DEFAULT true,
    CONSTRAINT check_latitude CHECK (((location_latitude >= ('-90'::integer)::numeric) AND (location_latitude <= (90)::numeric))),
    CONSTRAINT check_longitude CHECK (((location_longitude >= ('-180'::integer)::numeric) AND (location_longitude <= (180)::numeric))),
    CONSTRAINT check_radius CHECK (((radius_meters >= 50) AND (radius_meters <= 1000))),
    CONSTRAINT check_tier_required CHECK (((tier_required >= 0) AND (tier_required <= 4))),
    CONSTRAINT check_zone_type CHECK (((zone_type)::text = ANY ((ARRAY['static'::character varying, 'dynamic'::character varying, 'event'::character varying])::text[])))
);


ALTER TABLE public.zones OWNER TO postgres;

--
-- TOC entry 4981 (class 0 OID 17432)
-- Dependencies: 222
-- Data for Name: artifacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.artifacts (id, created_at, updated_at, deleted_at, zone_id, name, type, rarity, location_latitude, location_longitude, location_timestamp, properties, is_active, biome, exclusive_to_biome) FROM stdin;
c73b1bd8-0443-4c6c-ae2d-91976d6629e3	2025-07-15 19:39:16.760745	2025-07-16 16:47:11.638963	\N	64933d75-38ae-494d-b1fa-1f87609d5feb	Corrupted Ancient gem	gem	rare	49.12343955	18.32670469	2025-07-16 16:47:11.638963	{"biome": "wasteland", "spawned_at": 1752601156}	f	wasteland	f
7253045e-e820-49fa-b3a8-0037486bf245	2025-07-15 19:39:16.761852	2025-07-16 16:47:11.638963	\N	64933d75-38ae-494d-b1fa-1f87609d5feb	Corrupted Legendary scroll	scroll	epic	49.12360003	18.32712551	2025-07-16 16:47:11.638963	{"biome": "wasteland", "spawned_at": 1752601156}	f	wasteland	f
2d0a8a8c-1539-4705-a5b3-77b0a8b517f6	2025-07-15 19:39:16.762529	2025-07-16 16:47:11.638963	\N	64933d75-38ae-494d-b1fa-1f87609d5feb	Corrupted Legendary orb	orb	epic	49.12517001	18.32767530	2025-07-16 16:47:11.638963	{"biome": "wasteland", "spawned_at": 1752601156}	f	wasteland	f
c3fbaacf-518e-4a63-9ac9-1fe5f7700d44	2025-07-15 19:39:16.764835	2025-07-16 16:47:11.646865	\N	cb8fa6bb-ec76-49fa-b4dd-66cb782268c2	Murky Legendary crystal	crystal	epic	49.13377697	18.32280548	2025-07-16 16:47:11.646865	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
afc89c09-5555-4919-9d98-1d4398b6dc24	2025-07-15 19:39:16.766521	2025-07-16 16:47:11.64899	\N	a6e7ebe9-8586-4055-b70e-effdf43ab0d5	Scorched Ancient rune	rune	rare	49.12827067	18.33146132	2025-07-16 16:47:11.64899	{"biome": "desert", "spawned_at": 1752601156}	f	desert	f
2296811b-370e-4187-af8c-7b498869ddc7	2025-07-15 19:39:16.766521	2025-07-16 16:47:11.64899	\N	a6e7ebe9-8586-4055-b70e-effdf43ab0d5	Scorched Ancient crystal	crystal	rare	49.12835218	18.32794162	2025-07-16 16:47:11.64899	{"biome": "desert", "spawned_at": 1752601156}	f	desert	f
944dd1bf-6d3d-4259-a3b4-c151252594cb	2025-07-15 19:39:16.767167	2025-07-16 16:47:11.64899	\N	a6e7ebe9-8586-4055-b70e-effdf43ab0d5	Scorched Legendary tablet	tablet	epic	49.12741717	18.32993538	2025-07-16 16:47:11.64899	{"biome": "desert", "spawned_at": 1752601156}	f	desert	f
99b68973-f9b2-4670-914d-b9d9a6167b12	2025-07-15 19:39:16.770361	2025-07-16 16:47:11.650576	\N	621af158-7dd2-4bf0-8f23-064dfd07eee7	Murky Ancient tablet	tablet	rare	49.12716742	18.32807979	2025-07-16 16:47:11.650576	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
7c38f120-0fb9-48bb-89b1-d9ae3df907a5	2025-07-15 19:39:16.768189	2025-07-16 19:10:49.359326	\N	8082089d-5c9c-418d-bbb9-994b7ca139b5	Stone Ancient tablet	tablet	rare	49.13076257	18.32950078	2025-07-16 19:10:49.359326	{"biome": "rocky", "spawned_at": 1752601156}	f	rocky	f
8d6381b9-618d-4654-bd1d-750b156a7fde	2025-07-15 19:39:16.768807	2025-07-16 19:10:49.359326	\N	8082089d-5c9c-418d-bbb9-994b7ca139b5	Stone Legendary rune	rune	epic	49.13200988	18.33006106	2025-07-16 19:10:49.359326	{"biome": "rocky", "spawned_at": 1752601156}	f	rocky	f
\.


--
-- TOC entry 4982 (class 0 OID 17454)
-- Dependencies: 223
-- Data for Name: gear; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gear (id, created_at, updated_at, deleted_at, zone_id, name, type, level, location_latitude, location_longitude, location_timestamp, properties, is_active, biome, exclusive_to_biome) FROM stdin;
bf49f413-69d8-4cb5-a9d8-3b1da9aaea6f	2025-07-15 19:39:16.763105	2025-07-16 16:47:11.643943	\N	64933d75-38ae-494d-b1fa-1f87609d5feb	Corrupted boots +4	boots	4	49.12331684	18.32646986	2025-07-16 16:47:11.643943	{"biome": "wasteland", "spawned_at": 1752601156}	f	wasteland	f
1436ba2c-fe32-4340-98b4-0abb83939691	2025-07-15 19:39:16.764835	2025-07-16 16:47:11.647421	\N	cb8fa6bb-ec76-49fa-b4dd-66cb782268c2	Rusty helmet +5	helmet	5	49.13172238	18.32699312	2025-07-16 16:47:11.647421	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
7a51993f-1114-4af2-8244-475d8b0cc6c1	2025-07-15 19:39:16.765489	2025-07-16 16:47:11.647421	\N	cb8fa6bb-ec76-49fa-b4dd-66cb782268c2	Rusty amulet +4	amulet	4	49.13092541	18.32599356	2025-07-16 16:47:11.647421	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
79ecf11b-60ce-4bdd-8f7b-bf3b5d12345b	2025-07-15 19:39:16.767678	2025-07-16 16:47:11.649502	\N	a6e7ebe9-8586-4055-b70e-effdf43ab0d5	Bronze armor +5	armor	5	49.12855196	18.32806981	2025-07-16 16:47:11.649502	{"biome": "desert", "spawned_at": 1752601156}	f	desert	f
d6c17ee2-1245-47e6-a564-d80ba5dbb93b	2025-07-15 19:39:16.770952	2025-07-16 16:47:11.651087	\N	621af158-7dd2-4bf0-8f23-064dfd07eee7	Rusty shield +5	shield	5	49.12693368	18.33045443	2025-07-16 16:47:11.651087	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
92bd048a-3133-4399-80b8-f978f5643985	2025-07-15 19:39:16.771465	2025-07-16 16:47:11.651087	\N	621af158-7dd2-4bf0-8f23-064dfd07eee7	Rusty amulet +4	amulet	4	49.12724742	18.33002720	2025-07-16 16:47:11.651087	{"biome": "swamp", "spawned_at": 1752601156}	f	swamp	f
11cd4b8d-f6da-44c2-95a2-d3a09209edbb	2025-07-15 19:39:16.769321	2025-07-16 19:10:49.361826	\N	8082089d-5c9c-418d-bbb9-994b7ca139b5	Iron helmet +5	helmet	5	49.13099303	18.32869331	2025-07-16 19:10:49.361826	{"biome": "rocky", "spawned_at": 1752601156}	f	rocky	f
72f88d4c-afaa-4254-829d-c16f36c054bd	2025-07-15 19:39:16.769849	2025-07-16 19:10:49.361826	\N	8082089d-5c9c-418d-bbb9-994b7ca139b5	Iron shield +4	shield	4	49.13231319	18.32806511	2025-07-16 19:10:49.361826	{"biome": "rocky", "spawned_at": 1752601156}	f	rocky	f
\.


--
-- TOC entry 4983 (class 0 OID 17476)
-- Dependencies: 224
-- Data for Name: inventory_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_items (id, created_at, updated_at, deleted_at, user_id, item_type, item_id, quantity, properties, acquired_at) FROM stdin;
634de956-a0ef-4e1c-8072-f24fd6b3aa90	2025-07-13 16:34:28.506993	2025-07-13 16:34:28.506993	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	d9dbe698-1db8-4106-b3d7-73a959fb0a80	1	{"name": "Military Steel Ingot", "type": "steel_ingot", "biome": "industrial", "rarity": "rare", "zone_name": "Scrapyard (T4)", "zone_biome": "industrial", "collected_at": 1752417268, "danger_level": "high", "collected_from": "bf42b90f-6865-4c0d-b172-59c1d7e2cc7f"}	2025-07-13 16:34:28.506993
e5b618c8-50d4-4950-8239-d7ebaef977ae	2025-07-13 16:58:53.817931	2025-07-13 16:58:53.817931	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	b2acfed1-ad78-4496-848c-16b88c0791c1	1	{"name": "Industrial Machinery Parts", "type": "machinery_parts", "biome": "industrial", "rarity": "rare", "zone_name": "Scrapyard (T4)", "zone_biome": "industrial", "collected_at": 1752418733, "danger_level": "high", "collected_from": "bf42b90f-6865-4c0d-b172-59c1d7e2cc7f"}	2025-07-13 16:58:53.817931
b6871d8e-aa1a-44d7-9e0d-6d6764de0c99	2025-07-13 17:06:50.492773	2025-07-13 17:06:50.492773	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	279080fd-c755-412a-bf07-6c3db05ab3ee	1	{"name": "Industrial Machinery Parts", "type": "machinery_parts", "biome": "industrial", "rarity": "rare", "zone_name": "Scrapyard (T4)", "zone_biome": "industrial", "collected_at": 1752419210, "danger_level": "high", "collected_from": "bf42b90f-6865-4c0d-b172-59c1d7e2cc7f"}	2025-07-13 17:06:50.492773
839b88aa-e376-4e73-8002-8b84b3f0186f	2025-07-13 17:16:10.342867	2025-07-13 17:16:10.342867	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	c415113a-e839-4a5d-b95f-65d78ed702d9	1	{"name": "Healing Herb Extract", "type": "herbal_extract", "biome": "forest", "rarity": "common", "zone_name": "Silent Thicket (T0)", "zone_biome": "forest", "collected_at": 1752419770, "danger_level": "low", "collected_from": "c624fb72-4432-4f39-a4c2-219e44c3d8a4"}	2025-07-13 17:16:10.342867
8525fd38-6e39-4166-8d11-b0f42681e343	2025-07-13 17:17:55.674149	2025-07-13 17:17:55.674149	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	b246129a-10c8-4907-9859-266a9c76e359	1	{"name": "Amber Tree Resin", "type": "tree_resin", "biome": "forest", "rarity": "common", "zone_name": "Silent Thicket (T0)", "zone_biome": "forest", "collected_at": 1752419875, "danger_level": "low", "collected_from": "c624fb72-4432-4f39-a4c2-219e44c3d8a4"}	2025-07-13 17:17:55.674149
a1f949a0-5f6d-478c-900f-390387ef810c	2025-07-13 17:26:09.976599	2025-07-13 17:26:09.976599	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	a3a10b3b-eae9-47ec-b2f5-2ee810e7025a	1	{"name": "City Historical Artifact", "type": "urban_artifact", "biome": "urban", "rarity": "common", "zone_name": "School Complex (T1)", "zone_biome": "urban", "collected_at": 1752420369, "danger_level": "medium", "collected_from": "e768a126-d777-425a-a432-65073399c4a6"}	2025-07-13 17:26:09.976599
4679cf43-2281-45bc-b11e-7ae6edcb2ce5	2025-07-13 17:35:23.420865	2025-07-13 17:35:23.420865	\N	e77b1b45-4d6b-405a-8bdd-69c9c966d176	artifact	54e3be63-c83e-46c7-936d-8b403eb64e95	1	{"name": "Medical Emergency Kit", "type": "medical_supplies", "biome": "urban", "rarity": "common", "zone_name": "School Complex (T1)", "zone_biome": "urban", "collected_at": 1752420923, "danger_level": "medium", "collected_from": "e768a126-d777-425a-a432-65073399c4a6"}	2025-07-13 17:35:23.420865
\.


--
-- TOC entry 4978 (class 0 OID 17372)
-- Dependencies: 219
-- Data for Name: level_definitions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.level_definitions (level, xp_required, level_name, features_unlocked, cosmetic_unlocks, created_at) FROM stdin;
1	0	Novice Explorer	{"basic_scanning": true}	{"default_avatar": true}	2025-07-10 15:44:13.56099
2	100	Amateur Seeker	{"improved_detection": true}	{"bronze_badge": true}	2025-07-10 15:44:13.56099
3	250	Dedicated Hunter	{"zone_history": true}	{"silver_badge": true}	2025-07-10 15:44:13.56099
4	500	Skilled Adventurer	{"item_analysis": true}	{"gold_badge": true}	2025-07-10 15:44:13.56099
5	1000	Expert Tracker	{"advanced_scanning": true}	{"platinum_badge": true}	2025-07-10 15:44:13.56099
6	1750	Master Collector	{"rare_item_boost": true}	{"diamond_badge": true}	2025-07-10 15:44:13.56099
7	2750	Elite Explorer	{"legendary_detection": true}	{"elite_avatar": true}	2025-07-10 15:44:13.56099
8	4000	Legendary Seeker	{"zone_prediction": true}	{"legendary_emblem": true}	2025-07-10 15:44:13.56099
9	6000	Mythical Hunter	{"artifact_fusion": true}	{"mythical_aura": true}	2025-07-10 15:44:13.56099
10	9000	Grandmaster	{"unlimited_potential": true}	{"grandmaster_crown": true}	2025-07-10 15:44:13.56099
11	13000	Artifact Scholar	{"enhanced_analysis": true}	{"scholar_robes": true}	2025-07-10 15:44:13.56099
12	18000	Zone Master	{"zone_creation": true}	{"master_insignia": true}	2025-07-10 15:44:13.56099
13	24000	Relic Hunter	{"ancient_detection": true}	{"hunter_cloak": true}	2025-07-10 15:44:13.56099
14	32000	Dimensional Walker	{"cross_zone_travel": true}	{"dimensional_aura": true}	2025-07-10 15:44:13.56099
15	42000	Cosmic Explorer	{"stellar_navigation": true}	{"cosmic_wings": true}	2025-07-10 15:44:13.56099
16	55000	Reality Shaper	{"zone_modification": true}	{"shaper_crown": true}	2025-07-10 15:44:13.56099
17	71000	Ethereal Guardian	{"guardian_powers": true}	{"ethereal_form": true}	2025-07-10 15:44:13.56099
18	90000	Nexus Controller	{"nexus_access": true}	{"controller_interface": true}	2025-07-10 15:44:13.56099
19	113000	Void Walker	{"void_traversal": true}	{"void_essence": true}	2025-07-10 15:44:13.56099
20	140000	Omnipresent	{"omnipresence": true}	{"godlike_presence": true}	2025-07-10 15:44:13.56099
21	172000	Ascended Being	{"ascension_powers": true}	{"ascended_form": true}	2025-07-10 15:44:32.017027
22	209000	Quantum Manipulator	{"quantum_mechanics": true}	{"quantum_field": true}	2025-07-10 15:44:32.017027
23	252000	Time Weaver	{"temporal_control": true}	{"temporal_threads": true}	2025-07-10 15:44:32.017027
24	302000	Space Bender	{"spatial_distortion": true}	{"space_ripples": true}	2025-07-10 15:44:32.017027
25	360000	Universal Constant	{"universal_laws": true}	{"constant_glow": true}	2025-07-10 15:44:32.017027
26	427000	Multiverse Walker	{"multiverse_access": true}	{"multiverse_portal": true}	2025-07-10 15:44:32.017027
27	505000	Reality Architect	{"reality_design": true}	{"architect_tools": true}	2025-07-10 15:44:32.017027
28	595000	Existence Shaper	{"existence_control": true}	{"shaper_mark": true}	2025-07-10 15:44:32.017027
29	698000	Consciousness Stream	{"mind_network": true}	{"stream_flow": true}	2025-07-10 15:44:32.017027
30	816000	Infinite Explorer	{"infinite_reach": true}	{"infinite_symbol": true}	2025-07-10 15:44:32.017027
31	950000	Beyond Comprehension	{"transcendent_abilities": true}	{"incomprehensible_aura": true}	2025-07-10 15:44:32.017027
32	1102000	Paradox Resolver	{"paradox_solving": true}	{"paradox_symbols": true}	2025-07-10 15:44:32.017027
33	1274000	Concept Creator	{"concept_manifestation": true}	{"creator_halo": true}	2025-07-10 15:44:32.017027
34	1468000	Abstract Thinker	{"abstract_reasoning": true}	{"thought_patterns": true}	2025-07-10 15:44:32.017027
35	1686000	Pure Energy	{"energy_transformation": true}	{"pure_radiance": true}	2025-07-10 15:44:32.017027
36	1930000	Timeless Entity	{"time_immunity": true}	{"timeless_presence": true}	2025-07-10 15:44:32.017027
37	2203000	Spaceless Being	{"location_transcendence": true}	{"placeless_form": true}	2025-07-10 15:44:32.017027
38	2508000	Causality Master	{"cause_effect_control": true}	{"causality_chains": true}	2025-07-10 15:44:32.017027
39	2847000	Logic Transcender	{"beyond_logic": true}	{"illogical_patterns": true}	2025-07-10 15:44:32.017027
40	3224000	Truth Keeper	{"absolute_truth": true}	{"truth_crystal": true}	2025-07-10 15:44:32.017027
41	3642000	Wisdom Incarnate	{"infinite_wisdom": true}	{"wisdom_crown": true}	2025-07-10 15:44:32.017027
42	4105000	Knowledge Nexus	{"all_knowledge": true}	{"nexus_matrix": true}	2025-07-10 15:44:32.017027
43	4616000	Understanding Itself	{"pure_understanding": true}	{"understanding_light": true}	2025-07-10 15:44:32.017027
44	5179000	Awareness Eternal	{"eternal_awareness": true}	{"awareness_field": true}	2025-07-10 15:44:32.017027
45	5798000	Consciousness Prime	{"prime_consciousness": true}	{"prime_emanation": true}	2025-07-10 15:44:32.017027
46	6477000	The Observer	{"universal_observation": true}	{"observer_eye": true}	2025-07-10 15:44:32.017027
47	7221000	The Dreamer	{"reality_dreaming": true}	{"dream_weaver": true}	2025-07-10 15:44:32.017027
48	8035000	The Source	{"origin_point": true}	{"source_radiance": true}	2025-07-10 15:44:32.017027
49	8925000	The One	{"unity_consciousness": true}	{"unity_symbol": true}	2025-07-10 15:44:32.017027
50	9896000	Beyond Names	{"nameless_existence": true}	{"no_form": true}	2025-07-10 15:44:32.017027
\.


--
-- TOC entry 4984 (class 0 OID 17498)
-- Dependencies: 225
-- Data for Name: player_sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.player_sessions (id, created_at, updated_at, user_id, last_seen, is_online, current_zone, last_location_latitude, last_location_longitude, last_location_accuracy, last_location_timestamp) FROM stdin;
e459b694-1fb1-49c6-9664-6039d202b582	2025-07-15 18:55:37.397358	2025-07-15 18:55:37.397358	69e2afbf-3da3-4a7b-b5d3-c76df32fedcf	2025-07-15 18:55:37.396818	t	\N	0.00000000	0.00000000	0.00	0001-01-01 00:00:00
40fec578-0473-4303-aaf6-46e1636403c8	2025-07-15 19:15:41.872536	2025-07-15 19:15:41.872536	78e3dbb4-0ced-497d-bdc1-4d3478689fea	2025-07-15 19:15:41.872536	t	\N	0.00000000	0.00000000	0.00	0001-01-01 00:00:00
b2e767f7-3694-4c9e-aaa2-fb5ee1606d0d	2025-07-10 17:33:39.059979	2025-07-16 19:10:49.36353	e77b1b45-4d6b-405a-8bdd-69c9c966d176	2025-07-16 19:10:49.36353	t	\N	48.14860000	17.10770000	10.00	2025-07-13 11:32:11.086158
\.


--
-- TOC entry 4977 (class 0 OID 17360)
-- Dependencies: 218
-- Data for Name: tier_definitions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tier_definitions (tier_level, tier_name, price_monthly, max_zones_per_scan, collect_cooldown_seconds, scan_cooldown_minutes, inventory_slots, features, created_at, updated_at) FROM stdin;
0	Free User	0.00	3	300	15	50	{"ads": true}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
1	Standard User	4.99	5	180	10	100	{"ads": false}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
2	Premium User	9.99	8	120	5	200	{"enhanced": true}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
3	Legendary User	19.99	12	60	3	500	{"legendary": true}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
4	Admin	\N	50	30	1	1000	{"admin": true}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
5	Super Admin	\N	100	0	0	10000	{"super_admin": true}	2025-07-14 16:50:29.842693	2025-07-14 16:50:29.842693
\.


--
-- TOC entry 4979 (class 0 OID 17384)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, created_at, updated_at, deleted_at, username, email, password_hash, tier, tier_expires, tier_auto_renew, xp, level, total_artifacts, total_gear, zones_discovered, is_active, is_banned, last_login, profile_data) FROM stdin;
78e3dbb4-0ced-497d-bdc1-4d3478689fea	2025-07-14 16:52:33.48689	2025-07-15 19:39:11.889109	\N	K4RDAN	k4rdan@geoanomaly.com	$2a$10$YsUKcHuM6UE84zjQTJU.ROVr2IktuUzW/22z.1eGGpeBTRu48PAuO	3	\N	f	0	1	0	0	0	t	f	\N	{}
e77b1b45-4d6b-405a-8bdd-69c9c966d176	2025-07-10 17:27:16.081622	2025-07-16 17:31:26.452295	\N	silverminesro	silverminesro@geoanomaly.com	$2a$10$WUkE.JgMjBMuxT5fN4cdmukYtMazD5eLS1dQZj2PkBHVB3qrBZz0K	5	\N	f	515	3	15	0	0	t	f	\N	{}
27e980ad-f9a1-42ff-98b6-17e42f052003	2025-07-16 18:15:35.815067	2025-07-16 18:15:35.815067	\N	fluttertest	fluttertest@example.com	$2a$10$lDTJPOPngs9a6GmC/UT1HOHnkj5gCgaU4vZnyIBEH3O5D34UgE0gq	1	\N	f	0	1	0	0	0	t	f	\N	{}
a34c9106-c158-4abe-a9fc-dd666af5c539	2025-07-15 18:29:55.057726	2025-07-15 18:30:02.015266	\N	testuser	test@example.com	$2a$10$XN9CMi0W5awZ3KXFbDaOCO3N8m173JD/1fM/Cdvrj6N0dVVjimPUy	1	\N	f	0	1	0	0	0	t	f	\N	{}
69e2afbf-3da3-4a7b-b5d3-c76df32fedcf	2025-07-15 16:45:46.567428	2025-07-15 18:54:07.792031	\N	test	test@test.com	$2a$10$CkOrqgcewbOu1SzCoROr2.sDlhYpCQgI0foxwLfQgc6W6lIguXiqe	1	\N	f	0	1	0	0	0	t	f	\N	{}
1099aad7-feed-4bcb-a0ac-d68b2d8f2930	2025-07-15 18:59:20.709719	2025-07-15 18:59:20.709719	\N	marybell	sjdjdjej@hsjs.com	$2a$10$k1dcB/l9u3et80b.f///Nuy/PzzcHHTURKfSF5mfzuW8.HlyLPNfC	3	\N	f	0	1	0	0	0	t	f	\N	{}
\.


--
-- TOC entry 4980 (class 0 OID 17413)
-- Dependencies: 221
-- Data for Name: zones; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.zones (id, created_at, updated_at, deleted_at, name, description, location_latitude, location_longitude, location_timestamp, radius_meters, tier_required, zone_type, properties, is_active, biome, danger_level, environmental_effects, expires_at, last_activity, auto_cleanup) FROM stdin;
64933d75-38ae-494d-b1fa-1f87609d5feb	2025-07-15 19:39:16.759305	2025-07-16 16:47:11.645845	\N	Cursed Swamp (T3)		49.12335799	18.32729816	2025-07-16 16:47:11.645845	250	3	dynamic	{"biome": "wasteland", "ttl_hours": 10.903906086129723, "spawned_by": "scan_area", "cleanup_time": 1752677231, "danger_level": "high", "cleanup_reason": "expired"}	f	wasteland	high	{}	2025-07-16 06:33:30.820694	2025-07-15 19:39:16.758784	t
cb8fa6bb-ec76-49fa-b4dd-66cb782268c2	2025-07-15 19:39:16.764237	2025-07-16 16:47:11.648449	\N	Cursed Wasteland (T3)		49.13167781	18.32365746	2025-07-16 16:47:11.648449	250	3	dynamic	{"biome": "swamp", "ttl_hours": 10.125612071680278, "spawned_by": "scan_area", "cleanup_time": 1752677231, "danger_level": "high", "cleanup_reason": "expired"}	f	swamp	high	{}	2025-07-16 05:46:48.967695	2025-07-15 19:39:16.764237	t
a6e7ebe9-8586-4055-b70e-effdf43ab0d5	2025-07-15 19:39:16.766001	2025-07-16 16:47:11.650009	\N	Rotten Wasteland (T3)		49.12789232	18.32932962	2025-07-16 16:47:11.650009	250	3	dynamic	{"biome": "desert", "ttl_hours": 7.323082030734167, "spawned_by": "scan_area", "cleanup_time": 1752677231, "danger_level": "high", "cleanup_reason": "expired"}	f	desert	high	{}	2025-07-16 02:58:39.861311	2025-07-15 19:39:16.766001	t
621af158-7dd2-4bf0-8f23-064dfd07eee7	2025-07-15 19:39:16.770354	2025-07-16 16:47:11.651624	\N	Rotten Graveyard (T3)		49.12701048	18.32986245	2025-07-16 16:47:11.651624	250	3	dynamic	{"biome": "swamp", "ttl_hours": 7.5974059150925, "spawned_by": "scan_area", "cleanup_time": 1752677231, "danger_level": "high", "cleanup_reason": "expired"}	f	swamp	high	{}	2025-07-16 03:15:07.431143	2025-07-15 19:39:16.769849	t
8082089d-5c9c-418d-bbb9-994b7ca139b5	2025-07-15 19:39:16.768189	2025-07-16 19:10:49.363826	\N	Rotten Graveyard (T3)		49.13210699	18.32785007	2025-07-16 19:10:49.363826	250	3	dynamic	{"biome": "rocky", "ttl_hours": 23.4628710158175, "spawned_by": "scan_area", "cleanup_time": 1752685849, "danger_level": "high", "cleanup_reason": "expired"}	f	rocky	high	{}	2025-07-16 19:07:03.103846	2025-07-16 16:55:32.719977	t
\.


-- Completed on 2025-07-17 11:30:22

--
-- PostgreSQL database dump complete
--

