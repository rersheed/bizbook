-- Customer credit book on the hosted BizBook schema.
-- Money columns are unconstrained numeric, matching sales.total_amount.
-- Does not drop or rewrite existing rows. Existing sales are backfilled as paid in full.

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon, authenticated;

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  name text not null,
  phone text,
  email text,
  address text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customers_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.customer_credits (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  customer_id uuid not null references public.customers(id),
  sale_id uuid references public.sales(id),
  recorded_by uuid references auth.users(id),
  recorded_by_name text,
  description text not null,
  original_amount numeric not null,
  outstanding_amount numeric not null,
  credit_date timestamptz not null default now(),
  due_date date,
  status text not null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint customer_credits_original_positive check (original_amount > 0),
  constraint customer_credits_outstanding_range check (
    outstanding_amount >= 0 and outstanding_amount <= original_amount
  ),
  constraint customer_credits_status_chk check (
    status in ('unpaid', 'partial', 'paid')
    and (
      (status = 'paid' and outstanding_amount = 0)
      or (status = 'unpaid' and outstanding_amount = original_amount)
      or (
        status = 'partial'
        and outstanding_amount > 0
        and outstanding_amount < original_amount
      )
    )
  ),
  constraint customer_credits_description_not_blank check (length(trim(description)) > 0)
);

create table if not exists public.credit_repayments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  customer_id uuid not null references public.customers(id),
  credit_id uuid not null references public.customer_credits(id),
  recorded_by uuid references auth.users(id),
  recorded_by_name text,
  amount numeric not null,
  repayment_date timestamptz not null default now(),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint credit_repayments_amount_positive check (amount > 0)
);

alter table public.sales
  add column if not exists customer_id uuid,
  add column if not exists payment_status text,
  add column if not exists amount_paid numeric,
  add column if not exists amount_on_credit numeric;

update public.sales
set payment_status = 'paid',
    amount_on_credit = 0,
    amount_paid = total_amount
where payment_status is null
   or amount_paid is null
   or amount_on_credit is null;

alter table public.sales
  alter column payment_status set default 'paid',
  alter column payment_status set not null,
  alter column amount_paid set default 0,
  alter column amount_paid set not null,
  alter column amount_on_credit set default 0,
  alter column amount_on_credit set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sales_customer_id_fkey'
  ) then
    alter table public.sales
      add constraint sales_customer_id_fkey
      foreign key (customer_id) references public.customers(id);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'sales_payment_balance_chk'
  ) then
    alter table public.sales
      add constraint sales_payment_balance_chk check (
        payment_status in ('paid', 'partial', 'credit')
        and amount_paid >= 0
        and amount_on_credit >= 0
        and total_amount >= 0
        and amount_paid + amount_on_credit = total_amount
        and (
          (payment_status = 'paid' and amount_on_credit = 0)
          or (
            payment_status = 'partial'
            and amount_paid > 0
            and amount_on_credit > 0
            and customer_id is not null
          )
          or (
            payment_status = 'credit'
            and amount_on_credit > 0
            and customer_id is not null
          )
        )
      );
  end if;
end $$;

create unique index if not exists customer_credits_one_live_sale
  on public.customer_credits (sale_id)
  where sale_id is not null and deleted_at is null;

create index if not exists customers_business_idx
  on public.customers (business_id)
  where deleted_at is null;

create index if not exists customer_credits_business_customer_idx
  on public.customer_credits (business_id, customer_id)
  where deleted_at is null;

create index if not exists credit_repayments_credit_idx
  on public.credit_repayments (credit_id)
  where deleted_at is null;

create or replace function private.credit_status(orig numeric, outstanding numeric)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when outstanding = 0 then 'paid'
    when outstanding = orig then 'unpaid'
    else 'partial'
  end;
$$;

create or replace function private.active_repaid(p_credit_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(r.amount), 0)
  from public.credit_repayments r
  where r.credit_id = p_credit_id
    and r.deleted_at is null;
$$;

create or replace function private.apply_credit_balance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cust_business uuid;
  sale_business uuid;
  sale_customer uuid;
  sale_status text;
  sale_credit numeric;
  sale_deleted timestamptz;
  repaid numeric;
begin
  if tg_op = 'UPDATE' and new.business_id is distinct from old.business_id then
    raise exception 'Cannot move a credit to another business';
  end if;

  select c.business_id into cust_business
  from public.customers c
  where c.id = new.customer_id
    and c.deleted_at is null;

  if cust_business is null or cust_business is distinct from new.business_id then
    raise exception 'Customer does not belong to this business';
  end if;

  if new.sale_id is not null then
    select s.business_id, s.customer_id, s.payment_status, s.amount_on_credit, s.deleted_at
      into sale_business, sale_customer, sale_status, sale_credit, sale_deleted
    from public.sales s
    where s.id = new.sale_id;

    if sale_business is null or sale_deleted is not null then
      raise exception 'Linked sale was not found';
    end if;
    if sale_business is distinct from new.business_id
       or sale_customer is distinct from new.customer_id then
      raise exception 'Linked sale does not belong to this customer';
    end if;
    if sale_status not in ('partial', 'credit') then
      raise exception 'Only partial or credit sales can be linked';
    end if;
    if sale_credit is distinct from new.original_amount then
      raise exception 'Credit amount must match the sale amount on credit';
    end if;
  end if;

  repaid := private.active_repaid(new.id);
  if repaid > new.original_amount then
    raise exception 'Repayment exceeds outstanding';
  end if;

  new.outstanding_amount := new.original_amount - repaid;
  new.status := private.credit_status(new.original_amount, new.outstanding_amount);
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.guard_repayment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cred public.customer_credits%rowtype;
  repaid numeric;
begin
  if tg_op = 'UPDATE' and (
    new.business_id is distinct from old.business_id
    or new.credit_id is distinct from old.credit_id
    or new.customer_id is distinct from old.customer_id
  ) then
    raise exception 'Cannot move a repayment to another credit';
  end if;

  select * into cred
  from public.customer_credits
  where id = new.credit_id
  for update;

  if not found or cred.deleted_at is not null then
    raise exception 'Credit was not found';
  end if;
  if cred.business_id is distinct from new.business_id
     or cred.customer_id is distinct from new.customer_id then
    raise exception 'Repayment customer does not match the credit';
  end if;

  if new.deleted_at is not null then
    new.updated_at := now();
    return new;
  end if;

  select coalesce(sum(r.amount), 0) into repaid
  from public.credit_repayments r
  where r.credit_id = new.credit_id
    and r.deleted_at is null
    and r.id is distinct from new.id;

  if repaid + new.amount > cred.original_amount then
    raise exception 'Repayment exceeds outstanding';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.refresh_credit_from_repayment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.credit_id, old.credit_id);
  update public.customer_credits
  set original_amount = original_amount
  where id = target;
  return null;
end;
$$;

create or replace function private.guard_sale_customer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  cust_business uuid;
begin
  -- Legacy clients omit the new payment columns. Defaults would be paid/0/0,
  -- which cannot balance a non-zero total. Treat that as paid in full.
  if new.payment_status = 'paid'
     and new.amount_on_credit = 0
     and new.amount_paid = 0
     and coalesce(new.total_amount, 0) <> 0 then
    new.amount_paid := new.total_amount;
  end if;

  if new.customer_id is not null then
    select c.business_id into cust_business
    from public.customers c
    where c.id = new.customer_id
      and c.deleted_at is null;
    if cust_business is null or cust_business is distinct from new.business_id then
      raise exception 'Customer does not belong to this business';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists customer_credits_balance on public.customer_credits;
create trigger customer_credits_balance
  before insert or update on public.customer_credits
  for each row execute function private.apply_credit_balance();

drop trigger if exists credit_repayments_guard on public.credit_repayments;
create trigger credit_repayments_guard
  before insert or update on public.credit_repayments
  for each row execute function private.guard_repayment();

drop trigger if exists credit_repayments_refresh on public.credit_repayments;
create trigger credit_repayments_refresh
  after insert or update or delete on public.credit_repayments
  for each row execute function private.refresh_credit_from_repayment();

drop trigger if exists sales_customer_guard on public.sales;
create trigger sales_customer_guard
  before insert or update of customer_id, business_id on public.sales
  for each row execute function private.guard_sale_customer();

revoke all on function private.credit_status(numeric, numeric) from public, anon, authenticated;
revoke all on function private.active_repaid(uuid) from public, anon, authenticated;
revoke all on function private.apply_credit_balance() from public, anon, authenticated;
revoke all on function private.guard_repayment() from public, anon, authenticated;
revoke all on function private.refresh_credit_from_repayment() from public, anon, authenticated;
revoke all on function private.guard_sale_customer() from public, anon, authenticated;

revoke all on table public.customers from public, anon;
revoke all on table public.customer_credits from public, anon;
revoke all on table public.credit_repayments from public, anon;
grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.customer_credits to authenticated;
grant select, insert, update, delete on public.credit_repayments to authenticated;

alter table public.customers enable row level security;
alter table public.customer_credits enable row level security;
alter table public.credit_repayments enable row level security;

drop policy if exists customers_select on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
drop policy if exists customers_delete on public.customers;
create policy customers_select on public.customers
  for select to authenticated
  using (public.is_business_member(business_id));
create policy customers_insert on public.customers
  for insert to authenticated
  with check (public.is_business_member(business_id));
create policy customers_update on public.customers
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy customers_delete on public.customers
  for delete to authenticated
  using (public.is_business_owner(business_id));

drop policy if exists customer_credits_select on public.customer_credits;
drop policy if exists customer_credits_insert on public.customer_credits;
drop policy if exists customer_credits_update on public.customer_credits;
drop policy if exists customer_credits_delete on public.customer_credits;
create policy customer_credits_select on public.customer_credits
  for select to authenticated
  using (public.is_business_member(business_id));
create policy customer_credits_insert on public.customer_credits
  for insert to authenticated
  with check (
    public.is_business_member(business_id)
    and recorded_by = auth.uid()
    and exists (
      select 1 from public.customers c
      where c.id = customer_id
        and c.business_id = customer_credits.business_id
        and c.deleted_at is null
    )
    and (
      sale_id is null
      or exists (
        select 1 from public.sales s
        where s.id = sale_id
          and s.business_id = customer_credits.business_id
          and s.customer_id = customer_credits.customer_id
          and s.deleted_at is null
      )
    )
  );
create policy customer_credits_update on public.customer_credits
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy customer_credits_delete on public.customer_credits
  for delete to authenticated
  using (public.is_business_owner(business_id));

drop policy if exists credit_repayments_select on public.credit_repayments;
drop policy if exists credit_repayments_insert on public.credit_repayments;
drop policy if exists credit_repayments_update on public.credit_repayments;
drop policy if exists credit_repayments_delete on public.credit_repayments;
create policy credit_repayments_select on public.credit_repayments
  for select to authenticated
  using (public.is_business_member(business_id));
create policy credit_repayments_insert on public.credit_repayments
  for insert to authenticated
  with check (
    public.is_business_member(business_id)
    and recorded_by = auth.uid()
    and exists (
      select 1 from public.customer_credits cc
      where cc.id = credit_id
        and cc.business_id = credit_repayments.business_id
        and cc.customer_id = credit_repayments.customer_id
        and cc.deleted_at is null
    )
  );
create policy credit_repayments_update on public.credit_repayments
  for update to authenticated
  using (public.is_business_owner(business_id))
  with check (public.is_business_owner(business_id));
create policy credit_repayments_delete on public.credit_repayments
  for delete to authenticated
  using (public.is_business_owner(business_id));
