create extension if not exists "pgcrypto";

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  supports_lunch boolean not null default true,
  supports_dinner boolean not null default true,
  ingredients text not null default '',
  ingredient_sources text not null default '',
  instructions text not null default '',
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.menu_items
  add column if not exists ingredient_sources text not null default '';

create table if not exists public.daily_menu_assignments (
  id uuid primary key default gen_random_uuid(),
  service_date date not null unique,
  lunch_menu_item_id uuid references public.menu_items(id) on delete set null,
  dinner_menu_item_id uuid references public.menu_items(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists menu_items_touch_updated_at on public.menu_items;
create trigger menu_items_touch_updated_at
before update on public.menu_items
for each row execute function public.touch_updated_at();

drop trigger if exists daily_menu_assignments_touch_updated_at on public.daily_menu_assignments;
create trigger daily_menu_assignments_touch_updated_at
before update on public.daily_menu_assignments
for each row execute function public.touch_updated_at();

alter table public.menu_items enable row level security;
alter table public.daily_menu_assignments enable row level security;

drop policy if exists "Public can read menu items" on public.menu_items;
create policy "Public can read menu items"
on public.menu_items
for select
using (not is_archived);

drop policy if exists "Public can manage menu items" on public.menu_items;
create policy "Public can manage menu items"
on public.menu_items
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists "Public can read daily assignments" on public.daily_menu_assignments;
create policy "Public can read daily assignments"
on public.daily_menu_assignments
for select
using (true);

drop policy if exists "Public can manage assignments" on public.daily_menu_assignments;
create policy "Public can manage assignments"
on public.daily_menu_assignments
for all
to anon, authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users manage menu items" on public.menu_items;
drop policy if exists "Authenticated users manage assignments" on public.daily_menu_assignments;
