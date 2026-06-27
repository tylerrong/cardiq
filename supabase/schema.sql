-- CardIQ Supabase schema
-- Run this in your Supabase project: Dashboard > SQL Editor > New query > paste > Run.
-- Safe to re-run (uses IF NOT EXISTS / OR REPLACE / idempotent policy drops).

-- =====================================================================
-- profiles: one row per auth user, mirrors the app's AppUser
-- =====================================================================
create table if not exists public.profiles (
    id                              uuid primary key references auth.users (id) on delete cascade,
    name                            text    not null default 'Collector',
    email                           text    not null default '',
    subscription_tier               text    not null default 'free',
    free_scans_remaining            integer not null default 3,
    preferred_grading_company       text    not null default 'PSA',
    default_selling_fee_percentage  double precision not null default 13,
    created_at                      timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by owner"  on public.profiles;
drop policy if exists "Profiles are insertable by owner" on public.profiles;
drop policy if exists "Profiles are updatable by owner"  on public.profiles;
drop policy if exists "Profiles are deletable by owner"  on public.profiles;

create policy "Profiles are viewable by owner"
    on public.profiles for select using (auth.uid() = id);
create policy "Profiles are insertable by owner"
    on public.profiles for insert with check (auth.uid() = id);
create policy "Profiles are updatable by owner"
    on public.profiles for update using (auth.uid() = id);
create policy "Profiles are deletable by owner"
    on public.profiles for delete using (auth.uid() = id);

-- Auto-create a profile row whenever an auth user is created. Runs as
-- SECURITY DEFINER so it bypasses RLS (the client never inserts profiles).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, name, email)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'name', 'Collector'),
        coalesce(new.email, '')
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- =====================================================================
-- collection_items: a user's saved cards
-- =====================================================================
create table if not exists public.collection_items (
    item_id                    text primary key,
    user_id                    uuid not null references auth.users (id) on delete cascade,
    card_identity              jsonb,
    grading_report             jsonb,
    market_snapshot            jsonb,
    front_image_path           text,
    back_image_path            text,
    surface_image_path         text,
    purchase_price             double precision,
    purchase_date              timestamptz,
    quantity                   integer not null default 1,
    notes                      text,
    official_grade             double precision,
    official_grading_company   text,
    official_cert_number       text,
    official_grade_date        timestamptz,
    allow_anonymized_data      boolean not null default false,
    date_added                 timestamptz not null default now(),
    scan_id                    text
);

create index if not exists collection_items_user_id_idx
    on public.collection_items (user_id, date_added desc);

alter table public.collection_items enable row level security;

drop policy if exists "Collection items are viewable by owner"  on public.collection_items;
drop policy if exists "Collection items are insertable by owner" on public.collection_items;
drop policy if exists "Collection items are updatable by owner"  on public.collection_items;
drop policy if exists "Collection items are deletable by owner"  on public.collection_items;

create policy "Collection items are viewable by owner"
    on public.collection_items for select using (auth.uid() = user_id);
create policy "Collection items are insertable by owner"
    on public.collection_items for insert with check (auth.uid() = user_id);
create policy "Collection items are updatable by owner"
    on public.collection_items for update using (auth.uid() = user_id);
create policy "Collection items are deletable by owner"
    on public.collection_items for delete using (auth.uid() = user_id);

-- =====================================================================
-- Storage: private bucket for scanned card images, namespaced by user id
-- Path convention: <auth.uid()>/<identifier>.jpg
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('card-images', 'card-images', false)
on conflict (id) do nothing;

drop policy if exists "Card images are readable by owner"   on storage.objects;
drop policy if exists "Card images are insertable by owner" on storage.objects;
drop policy if exists "Card images are updatable by owner"  on storage.objects;
drop policy if exists "Card images are deletable by owner"  on storage.objects;

create policy "Card images are readable by owner"
    on storage.objects for select
    using (bucket_id = 'card-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Card images are insertable by owner"
    on storage.objects for insert
    with check (bucket_id = 'card-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Card images are updatable by owner"
    on storage.objects for update
    using (bucket_id = 'card-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Card images are deletable by owner"
    on storage.objects for delete
    using (bucket_id = 'card-images' and (storage.foldername(name))[1] = auth.uid()::text);
