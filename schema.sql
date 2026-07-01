-- Run this in Supabase SQL Editor (Project -> SQL Editor -> New Query)

create table if not exists students (
  id bigint generated always as identity primary key,
  name text not null,
  email text not null unique,
  created_at timestamptz not null default now()
);
