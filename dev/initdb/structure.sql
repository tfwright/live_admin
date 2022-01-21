create table users (
  id serial,
  name varchar(100),
  birth_date date,
  inserted_at timestamp without time zone,
  active boolean,
  stars_count integer,
  settings jsonb,
  private_data jsonb,
  password text,
  status varchar(100)
);

create table posts (
  id serial,
  user_id int,
  body text
);

create schema alt;

create table alt.posts (
  id serial,
  user_id int,
  body text
);
