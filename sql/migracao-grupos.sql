-- =============================================================
-- Contas da casa: migração para GRUPOS + administrador
--
-- Antes de rodar: troque SEU_EMAIL@exemplo.com (1 lugar, na PARTE 6)
-- pelo e-mail que será o administrador. Rode UMA vez, tudo junto,
-- no SQL Editor do Supabase.
--
-- Seus dados atuais (contas, pagamentos, rendas) são preservados e
-- viram o primeiro grupo. Se algo falhar, nada é alterado.
-- Depois de rodar, suba o index.html novo no GitHub sem demora:
-- o app antigo deixa de funcionar com o banco novo.
-- =============================================================

begin;

-- PARTE 1: guardar as tabelas antigas
alter table membros rename to membros_old;
alter table moradores rename to moradores_old;
alter table contas_recorrentes rename to contas_recorrentes_old;
alter table meses rename to meses_old;
alter table contas_mes rename to contas_mes_old;
alter table pagamentos rename to pagamentos_old;

-- PARTE 2: tabelas novas
create table grupos (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(trim(nome)) > 0),
  criado_em timestamptz not null default now()
);

create table admins (
  email text primary key check (email = lower(email))
);

create table grupo_membros (
  grupo_id uuid not null references grupos(id) on delete cascade,
  email text not null check (email = lower(email)),
  morador_id text,
  primary key (grupo_id, email)
);

create table moradores (
  grupo_id uuid not null references grupos(id) on delete cascade,
  id text not null,
  nome text not null,
  ordem int not null default 0,
  primary key (grupo_id, id)
);

create table contas_recorrentes (
  grupo_id uuid not null references grupos(id) on delete cascade,
  id text not null,
  nome text not null,
  dia int not null check (dia between 1 and 31),
  regra text not null check (regra in ('igual','proporcional','custom')),
  pct jsonb,
  valor_padrao int not null default 0,
  primary key (grupo_id, id)
);

create table meses (
  grupo_id uuid not null references grupos(id) on delete cascade,
  id text not null check (id ~ '^[0-9]{4}-[0-9]{2}$'),
  rendas jsonb not null default '{}',
  criado_em timestamptz not null default now(),
  primary key (grupo_id, id)
);

create table contas_mes (
  grupo_id uuid not null,
  mes_id text not null,
  conta_id text not null,
  nome text not null,
  dia int not null check (dia between 1 and 31),
  regra text not null check (regra in ('igual','proporcional','custom')),
  pct jsonb,
  valor int not null default 0,
  estimado boolean not null default false,
  primary key (grupo_id, mes_id, conta_id),
  foreign key (grupo_id, mes_id) references meses(grupo_id, id) on delete cascade
);

create table pagamentos (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null,
  mes_id text not null,
  tipo text not null check (tipo in ('conta','transferencia')),
  conta_id text,
  quem text,
  de text,
  para text,
  valor int not null check (valor > 0),
  data date not null,
  obs text default '',
  criado_em timestamptz not null default now(),
  foreign key (grupo_id, mes_id) references meses(grupo_id, id) on delete cascade
);

-- PARTE 3: copiar os dados atuais para o primeiro grupo
insert into grupos (id, nome)
values ('11111111-1111-1111-1111-111111111111', 'Casa');

insert into grupo_membros (grupo_id, email)
select '11111111-1111-1111-1111-111111111111', lower(email) from membros_old;

insert into moradores (grupo_id, id, nome, ordem)
select '11111111-1111-1111-1111-111111111111', id, nome, ordem from moradores_old;

insert into contas_recorrentes (grupo_id, id, nome, dia, regra, pct, valor_padrao)
select '11111111-1111-1111-1111-111111111111', id, nome, dia, regra, pct, valor_padrao
from contas_recorrentes_old;

insert into meses (grupo_id, id, rendas, criado_em)
select '11111111-1111-1111-1111-111111111111', id, rendas, criado_em from meses_old;

insert into contas_mes (grupo_id, mes_id, conta_id, nome, dia, regra, pct, valor, estimado)
select '11111111-1111-1111-1111-111111111111', mes_id, conta_id, nome, dia, regra, pct, valor, estimado
from contas_mes_old;

insert into pagamentos (id, grupo_id, mes_id, tipo, conta_id, quem, de, para, valor, data, obs, criado_em)
select id, '11111111-1111-1111-1111-111111111111', mes_id, tipo, conta_id, quem, de, para, valor, data, obs, criado_em
from pagamentos_old;

-- PARTE 4: remover as tabelas e a função antigas
drop table pagamentos_old, contas_mes_old, meses_old, contas_recorrentes_old, moradores_old, membros_old;
drop function if exists public.is_membro();

-- PARTE 5: segurança
create or replace function public.eh_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where email = lower(auth.jwt() ->> 'email'));
$$;

create or replace function public.eh_membro(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.grupo_membros
    where grupo_id = gid and email = lower(auth.jwt() ->> 'email')
  );
$$;

revoke execute on function public.eh_admin() from public, anon;
revoke execute on function public.eh_membro(uuid) from public, anon;
grant execute on function public.eh_admin() to authenticated;
grant execute on function public.eh_membro(uuid) to authenticated;

revoke all on grupos, admins, grupo_membros, moradores, contas_recorrentes, meses, contas_mes, pagamentos from anon;
grant select, insert, update, delete on grupos, grupo_membros, moradores, contas_recorrentes, meses, contas_mes, pagamentos to authenticated;
grant select on admins to authenticated;

alter table grupos enable row level security;
alter table admins enable row level security;
alter table grupo_membros enable row level security;
alter table moradores enable row level security;
alter table contas_recorrentes enable row level security;
alter table meses enable row level security;
alter table contas_mes enable row level security;
alter table pagamentos enable row level security;

-- Administrador: cria, renomeia e exclui grupos e controla os acessos.
-- Membros: veem o grupo e trabalham nas contas dele.
create policy "admins veem a si mesmos" on admins
  for select to authenticated using (email = lower(auth.jwt() ->> 'email'));

create policy "ver grupo" on grupos
  for select to authenticated using (public.eh_membro(id) or public.eh_admin());
create policy "admin cria grupo" on grupos
  for insert to authenticated with check (public.eh_admin());
create policy "admin altera grupo" on grupos
  for update to authenticated using (public.eh_admin()) with check (public.eh_admin());
create policy "admin exclui grupo" on grupos
  for delete to authenticated using (public.eh_admin());

create policy "ver acessos" on grupo_membros
  for select to authenticated using (public.eh_membro(grupo_id) or public.eh_admin());
create policy "admin cria acesso" on grupo_membros
  for insert to authenticated with check (public.eh_admin());
create policy "admin altera acesso" on grupo_membros
  for update to authenticated using (public.eh_admin()) with check (public.eh_admin());
create policy "admin remove acesso" on grupo_membros
  for delete to authenticated using (public.eh_admin());

-- Nomes das pessoas: o administrador também mexe, mas não vê valores.
create policy "membros e admin" on moradores
  for all to authenticated
  using (public.eh_membro(grupo_id) or public.eh_admin())
  with check (public.eh_membro(grupo_id) or public.eh_admin());

-- Contas, meses e pagamentos: só quem é membro do grupo.
create policy "membros acessam" on contas_recorrentes
  for all to authenticated using (public.eh_membro(grupo_id)) with check (public.eh_membro(grupo_id));
create policy "membros acessam" on meses
  for all to authenticated using (public.eh_membro(grupo_id)) with check (public.eh_membro(grupo_id));
create policy "membros acessam" on contas_mes
  for all to authenticated using (public.eh_membro(grupo_id)) with check (public.eh_membro(grupo_id));
create policy "membros acessam" on pagamentos
  for all to authenticated using (public.eh_membro(grupo_id)) with check (public.eh_membro(grupo_id));

-- PARTE 6: administrador (TROQUE O E-MAIL)
insert into admins (email) values (lower('SEU_EMAIL@exemplo.com'));

do $$
begin
  if exists (select 1 from admins where email like 'seu_email@%') then
    raise exception 'Troque SEU_EMAIL@exemplo.com pelo e-mail do administrador antes de rodar.';
  end if;
end $$;

-- PARTE 7: atualização em tempo real entre os celulares
alter publication supabase_realtime add table grupos, grupo_membros, moradores, contas_recorrentes, meses, contas_mes, pagamentos;

commit;
