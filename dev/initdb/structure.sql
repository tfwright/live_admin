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
  other_resource_id int,
  roles character varying[] DEFAULT '{}'::character varying[],
  rating real
);

CREATE UNIQUE INDEX users_email_index ON users USING btree (email);

create table posts (
  id serial,
  user_id uuid,
  disabled_user_id uuid,
  title text NOT NULL,
  body text,
  inserted_at timestamp without time zone,
  tags jsonb,
  previous_version jsonb DEFAULT '{}'::jsonb NOT NULL
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
  other_resource_id int,
  roles character varying[] DEFAULT '{}'::character varying[],
  rating real
);

CREATE UNIQUE INDEX users_email_index ON alt.users USING btree (email);

create table alt.posts (
  id serial,
  user_id uuid,
  disabled_user_id uuid,
  title text NOT NULL,
  body text,
  inserted_at timestamp without time zone,
  tags jsonb,
  previous_version jsonb DEFAULT '{}'::jsonb NOT NULL
);
