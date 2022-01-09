create table users (
  id serial,
  name varchar(100),
  birth_date date,
  inserted_at timestamp without time zone,
  active boolean,
  stars_count integer,
  settings jsonb
);
