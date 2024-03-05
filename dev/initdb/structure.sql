create table users (
  id uuid,
  name varchar(100),
  email varchar(100),
  birth_date date,
  inserted_at timestamp without time zone,
  active boolean,
  stars_count integer,
  settings jsonb,
  private_data jsonb,
  encrypted_password text,
  status varchar(100),
  roles character varying[] DEFAULT '{}'::character varying[],
  rating real
);

CREATE UNIQUE INDEX users_email_index ON users USING btree (email);

create table user_profiles (
  id serial,
  user_id uuid
);

create table posts (
  post_id serial,
  user_id uuid,
  disabled_user_id uuid,
  title text NOT NULL,
  body text,
  inserted_at timestamp without time zone,
  tags jsonb,
  categories jsonb,
  status varchar(100),
  previous_versions jsonb DEFAULT '[]'::jsonb,
  metadata jsonb DEFAULT '{}'::jsonb
);

create schema alt;

create table alt.users (
  id uuid,
  name varchar(100),
  email varchar(100),
  birth_date date,
  inserted_at timestamp without time zone,
  active boolean,
  stars_count integer,
  settings jsonb,
  private_data jsonb,
  encrypted_password text,
  status varchar(100),
  roles character varying[] DEFAULT '{}'::character varying[],
  rating real
);

CREATE UNIQUE INDEX users_email_index ON alt.users USING btree (email);

create table alt.user_profiles (
  id serial,
  user_id uuid
);

create table alt.posts (
  post_id serial,
  user_id uuid,
  disabled_user_id uuid,
  title text NOT NULL,
  body text,
  inserted_at timestamp without time zone,
  tags jsonb,
  categories jsonb,
  status varchar(100),
  previous_versions jsonb DEFAULT '[]'::jsonb,
  metadata jsonb DEFAULT '{}'::jsonb
);
