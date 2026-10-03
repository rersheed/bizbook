-- NOTE: This file was a draft and does NOT match the hosted project.
-- Hosted columns differ (business_name, owner_user_id, selling_price, sale_date, ...).
-- Do not re-apply. Production RLS lives in 002_membership_rls.sql.

-- BizBook V1 schema
-- Parent applies via Supabase MCP. Demo-open anon policies for prototype — tighten before production.

create extension if not exists "pgcrypto";

-- Profiles (mirrors auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  currency text not null default 'NGN',
  currency_symbol text not null default '₦',
  owner_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create type public.member_role as enum ('owner', 'staff');

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.member_role not null default 'staff',
  display_name text,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  sku text,
  unit_price numeric(14,2) not null default 0,
  cost_price numeric(14,2),
  unit text default 'pcs',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  recorded_by uuid not null references public.profiles(id),
  total numeric(14,2) not null default 0,
  note text,
  sold_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  sync_status text not null default 'synced' -- pending|synced|failed
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  quantity numeric(14,3) not null default 1,
  unit_price numeric(14,2) not null default 0,
  line_total numeric(14,2) not null default 0
);

create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete cascade, -- null = global default
  name text not null,
  is_default boolean not null default false
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  recorded_by uuid not null references public.profiles(id),
  description text not null,
  amount numeric(14,2) not null,
  category_id uuid references public.expense_categories(id) on delete set null,
  category_name text,
  note text,
  spent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  sync_status text not null default 'synced'
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity text,
  entity_id uuid,
  meta jsonb,
  created_at timestamptz not null default now()
);

-- Seed default expense categories (global)
insert into public.expense_categories (id, business_id, name, is_default) values
  (gen_random_uuid(), null, 'Rent', true),
  (gen_random_uuid(), null, 'Utilities', true),
  (gen_random_uuid(), null, 'Transport', true),
  (gen_random_uuid(), null, 'Supplies', true),
  (gen_random_uuid(), null, 'Salaries', true),
  (gen_random_uuid(), null, 'Marketing', true),
  (gen_random_uuid(), null, 'Other', true)
on conflict do nothing;

-- Indexes
create index if not exists idx_members_business on public.business_members(business_id);
create index if not exists idx_products_business on public.products(business_id);
create index if not exists idx_sales_business_sold on public.sales(business_id, sold_at desc);
create index if not exists idx_expenses_business_spent on public.expenses(business_id, spent_at desc);

-- RLS
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_categories enable row level security;
alter table public.audit_logs enable row level security;

-- Helper: membership check
create or replace function public.is_business_member(bid uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.business_members m
    where m.business_id = bid and m.user_id = auth.uid() and m.is_active
  );
$$;

create or replace function public.is_business_owner(bid uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from public.business_members m
    where m.business_id = bid and m.user_id = auth.uid() and m.role = 'owner' and m.is_active
  );
$$;

-- PROTOTYPE: open read/write for anon+authenticated for demo.
-- TODO: replace with is_business_member / is_business_owner policies before production.
create policy "demo_profiles_all" on public.profiles for all using (true) with check (true);
create policy "demo_businesses_all" on public.businesses for all using (true) with check (true);
create policy "demo_members_all" on public.business_members for all using (true) with check (true);
create policy "demo_products_all" on public.products for all using (true) with check (true);
create policy "demo_sales_all" on public.sales for all using (true) with check (true);
create policy "demo_sale_items_all" on public.sale_items for all using (true) with check (true);
create policy "demo_expenses_all" on public.expenses for all using (true) with check (true);
create policy "demo_expense_cats_all" on public.expense_categories for all using (true) with check (true);
create policy "demo_audit_all" on public.audit_logs for all using (true) with check (true);

-- Intended production sketches (commented):
-- create policy "members_read_business" on public.businesses for select using (public.is_business_member(id));
-- create policy "owner_update_business" on public.businesses for update using (public.is_business_owner(id));
-- create policy "staff_insert_sales" on public.sales for insert with check (public.is_business_member(business_id));
-- create policy "members_read_sales" on public.sales for select using (public.is_business_member(business_id));
-- create policy "owner_products_write" on public.products for all using (public.is_business_owner(business_id));
