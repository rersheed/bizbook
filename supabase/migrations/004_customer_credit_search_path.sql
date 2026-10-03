-- Advisor fix: pin search_path on the credit status helper.
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

revoke all on function private.credit_status(numeric, numeric) from public, anon, authenticated;
