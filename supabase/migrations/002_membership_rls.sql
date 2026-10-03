-- Membership-scoped RLS for the hosted BizBook schema.
-- Live columns (do not rename): businesses.business_name/owner_user_id/currency_code,
-- products.selling_price, sales.sale_date/total_amount, sale_items.description/total_amount,
-- expenses.expense_date, business_members.name.
-- Global expense_categories (business_id is null) stay. No anon access.

alter table public.products
  add column if not exists sku text,
  add column if not exists unit text default 'pcs',
  add column if not exists cost_price numeric(14,2);

alter table public.business_members
  add constraint business_members_business_id_user_id_key unique (business_id, user_id);

create or replace function public.is_business_member(bid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members m
    where m.business_id = bid
      and m.user_id = auth.uid()
      and m.is_active = true
  );
$$;

create or replace function public.is_business_owner(bid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members m
    where m.business_id = bid
      and m.user_id = auth.uid()
      and m.role = 'owner'
      and m.is_active = true
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'phone'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(nullif(excluded.full_name, ''), public.profiles.full_name),
    phone = coalesce(excluded.phone, public.profiles.phone),
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.attach_staff(p_business_id uuid, p_email text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid;
  mid uuid;
begin
  if auth.uid() is null or not public.is_business_owner(p_business_id) then
    raise exception 'Only the business owner can add staff';
  end if;

  select u.id into uid
  from auth.users u
  where lower(u.email) = lower(trim(p_email))
  limit 1;

  if uid is null then
    raise exception 'No account for that email yet';
  end if;

  insert into public.business_members (business_id, user_id, role, name, email, is_active)
  values (p_business_id, uid, 'staff', trim(p_name), lower(trim(p_email)), true)
  on conflict (business_id, user_id) do update
    set is_active = true,
        name = excluded.name,
        email = excluded.email,
        role = 'staff',
        updated_at = now()
  returning id into mid;

  return mid;
end;
$$;

revoke all on function public.is_business_member(uuid) from public, anon;
revoke all on function public.is_business_owner(uuid) from public, anon;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.attach_staff(uuid, text, text) from public, anon;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.is_business_owner(uuid) to authenticated;
grant execute on function public.attach_staff(uuid, text, text) to authenticated;

do $$
declare r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

revoke all privileges on all tables in schema public from anon;
revoke all privileges on all tables in schema public from public;
grant select, insert, update, delete on all tables in schema public to authenticated;

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_categories enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (id = auth.uid());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy businesses_select on public.businesses
  for select to authenticated
  using (owner_user_id = auth.uid() or public.is_business_member(id));
create policy businesses_insert on public.businesses
  for insert to authenticated
  with check (owner_user_id = auth.uid());
create policy businesses_update on public.businesses
  for update to authenticated
  using (public.is_business_owner(id) or owner_user_id = auth.uid())
  with check (public.is_business_owner(id) or owner_user_id = auth.uid());
create policy businesses_delete on public.businesses
  for delete to authenticated
  using (owner_user_id = auth.uid());

create policy members_select on public.business_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_business_member(business_id));
create policy members_insert on public.business_members
  for insert to authenticated
  with check (
    (
      user_id = auth.uid()
      and role = 'owner'
      and exists (
        select 1 from public.businesses b
        where b.id = business_id and b.owner_user_id = auth.uid()
      )
    )
    or public.is_business_owner(business_id)
  );
create policy members_update on public.business_members
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy members_delete on public.business_members
  for delete to authenticated
  using (public.is_business_owner(business_id) and role <> 'owner');

create policy products_select on public.products
  for select to authenticated
  using (public.is_business_member(business_id));
create policy products_write on public.products
  for all to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));

create policy sales_select on public.sales
  for select to authenticated
  using (public.is_business_member(business_id));
create policy sales_insert on public.sales
  for insert to authenticated
  with check (
    public.is_business_member(business_id)
    and recorded_by = auth.uid()
  );
create policy sales_update on public.sales
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy sales_delete on public.sales
  for delete to authenticated
  using (public.is_business_owner(business_id));

create policy sale_items_select on public.sale_items
  for select to authenticated
  using (public.is_business_member(business_id));
create policy sale_items_insert on public.sale_items
  for insert to authenticated
  with check (
    public.is_business_member(business_id)
    and exists (
      select 1 from public.sales s
      where s.id = sale_id and s.business_id = sale_items.business_id
    )
  );
create policy sale_items_update on public.sale_items
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy sale_items_delete on public.sale_items
  for delete to authenticated
  using (public.is_business_owner(business_id));

create policy expenses_select on public.expenses
  for select to authenticated
  using (public.is_business_member(business_id));
create policy expenses_insert on public.expenses
  for insert to authenticated
  with check (
    public.is_business_member(business_id)
    and recorded_by = auth.uid()
  );
create policy expenses_update on public.expenses
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy expenses_delete on public.expenses
  for delete to authenticated
  using (public.is_business_owner(business_id));

create policy expense_categories_select on public.expense_categories
  for select to authenticated
  using (business_id is null or public.is_business_member(business_id));
create policy expense_categories_write on public.expense_categories
  for all to authenticated
  using (business_id is not null and public.is_business_owner(business_id))
  with check (business_id is not null and public.is_business_owner(business_id));

create policy audit_select on public.audit_logs
  for select to authenticated
  using (business_id is not null and public.is_business_member(business_id));
create policy audit_insert on public.audit_logs
  for insert to authenticated
  with check (
    business_id is not null
    and public.is_business_member(business_id)
    and (actor_id is null or actor_id = auth.uid())
  );
