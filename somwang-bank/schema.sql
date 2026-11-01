-- Run once in Supabase SQL Editor. Private app: no anonymous access.
create extension if not exists pgcrypto;
create table if not exists public.funds (
 id text primary key, name text not null, balance numeric(14,2) not null default 0 check(balance>=0),
 protected boolean not null default false, sort_order integer not null default 0
);
insert into public.funds(id,name,protected,sort_order) values
 ('general','เงินเก็บทั่วไป',false,1),('car','เงินเก็บค่ารถ',false,2),
 ('anya','เงินเก็บอันยา',true,3),('atfan','เงินเก็บอัฏฟาน',true,4)
on conflict(id) do nothing;
create table if not exists public.loans (
 id uuid primary key default gen_random_uuid(), kind text not null check(kind in ('personal','school')),
 fund_id text not null references public.funds(id), original numeric(14,2) not null check(original>0),
 outstanding numeric(14,2) not null check(outstanding>=0), note text not null default '',
 created_at timestamptz not null default now()
);
create table if not exists public.transactions (
 id uuid primary key default gen_random_uuid(), kind text not null check(kind in ('deposit','withdraw','family','borrow','repay','transfer')),
 fund_id text references public.funds(id), target_fund_id text references public.funds(id),
 loan_id uuid references public.loans(id), amount numeric(14,2) not null check(amount>0),
 note text not null default '', occurred_on date not null default current_date,
 created_at timestamptz not null default now()
);
create table if not exists public.reconciliations (
 id uuid primary key default gen_random_uuid(), actual numeric(14,2) not null check(actual>=0),
 expected numeric(14,2) not null, note text not null default '', checked_at timestamptz not null default now()
);
-- Block direct access by web users; server calls with service_role only.
alter table public.funds enable row level security;
alter table public.loans enable row level security;
alter table public.transactions enable row level security;
alter table public.reconciliations enable row level security;
revoke all on public.funds,public.loans,public.transactions,public.reconciliations from anon,authenticated;

create or replace function public.record_movement(
 p_kind text,p_amount numeric,p_fund text default null,p_target text default null,
 p_loan uuid default null,p_note text default '',p_date date default current_date,
 p_loan_kind text default null
) returns uuid language plpgsql security invoker set search_path=public as $$
declare v_id uuid; v_balance numeric; v_loan public.loans%rowtype; v_protected boolean;
begin
 if p_amount is null or p_amount<=0 or p_amount>99999999999 then raise exception 'จำนวนเงินไม่ถูกต้อง'; end if;
 if p_date>current_date+1 or p_date<date '2000-01-01' then raise exception 'วันที่ไม่ถูกต้อง'; end if;
 if p_kind not in ('deposit','withdraw','family','borrow','repay','transfer') then raise exception 'ประเภทรายการไม่ถูกต้อง'; end if;
 if p_kind='repay' then
  select * into v_loan from public.loans where id=p_loan for update;
  if not found then raise exception 'ไม่พบเงินยืม'; end if;
  if p_amount>v_loan.outstanding then raise exception 'ยอดส่งคืนเกินยอดค้าง'; end if;
  p_fund:=v_loan.fund_id;
  update public.loans set outstanding=outstanding-p_amount where id=p_loan;
  update public.funds set balance=balance+p_amount where id=p_fund;
 else
  select balance,protected into v_balance,v_protected from public.funds where id=p_fund for update;
  if not found then raise exception 'ไม่พบกองทุน'; end if;
  if p_kind='deposit' then
   update public.funds set balance=balance+p_amount where id=p_fund;
  else
   if p_kind='borrow' and v_protected then raise exception 'ห้ามยืมเงินของอันยาและอัฏฟาน'; end if;
   if p_amount>v_balance then raise exception 'ยอดเงินกองทุนไม่เพียงพอ'; end if;
   if p_kind='borrow' then
    if p_loan_kind not in ('personal','school') then raise exception 'ประเภทเงินยืมไม่ถูกต้อง'; end if;
    insert into public.loans(kind,fund_id,original,outstanding,note)
    values(p_loan_kind,p_fund,p_amount,p_amount,coalesce(p_note,'')) returning id into p_loan;
   elsif p_kind='transfer' then
    if p_target=p_fund or p_target is null then raise exception 'กรุณาเลือกกองทุนปลายทางอื่น'; end if;
    perform 1 from public.funds where id=p_target for update;
    if not found then raise exception 'ไม่พบกองทุนปลายทาง'; end if;
    update public.funds set balance=balance+p_amount where id=p_target;
   end if;
   update public.funds set balance=balance-p_amount where id=p_fund;
  end if;
 end if;
 insert into public.transactions(kind,fund_id,target_fund_id,loan_id,amount,note,occurred_on)
 values(p_kind,p_fund,case when p_kind='transfer' then p_target else null end,
 case when p_kind in ('borrow','repay') then p_loan else null end,p_amount,coalesce(p_note,''),p_date)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.record_movement(text,numeric,text,text,uuid,text,date,text) from public,anon,authenticated;
grant execute on function public.record_movement(text,numeric,text,text,uuid,text,date,text) to service_role;
