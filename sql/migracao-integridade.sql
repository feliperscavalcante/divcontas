-- Integridade do banco: o banco passa a recusar dados incoerentes, mesmo que o app falhe.
-- Rode uma vez no Supabase: SQL Editor > New query > colar > Run. Seguro para rodar de novo.
-- Antes de aplicar, o script confere se os dados atuais ja estao coerentes. Se algo estiver fora do lugar,
-- ele para com uma mensagem dizendo o que corrigir, sem alterar nada.

do $$
declare n int;
begin
  -- 1) pagamentos que citam uma pessoa que nao existe mais no grupo
  select count(*) into n from pagamentos p
   where (p.quem is not null and not exists (select 1 from moradores m where m.grupo_id=p.grupo_id and m.id=p.quem))
      or (p.de   is not null and not exists (select 1 from moradores m where m.grupo_id=p.grupo_id and m.id=p.de))
      or (p.para is not null and not exists (select 1 from moradores m where m.grupo_id=p.grupo_id and m.id=p.para));
  if n>0 then raise exception 'Ha % pagamento(s) ligados a uma pessoa que nao existe mais. Veja com: select * from pagamentos p where p.quem is not null and not exists (select 1 from moradores m where m.grupo_id=p.grupo_id and m.id=p.quem);', n; end if;

  -- 2) formato dos pagamentos
  select count(*) into n from pagamentos
   where not ((tipo='conta' and quem is not null and conta_id is not null and de is null and para is null)
           or (tipo='transferencia' and de is not null and para is not null and de<>para and quem is null and conta_id is null));
  if n>0 then raise exception 'Ha % pagamento(s) com campos incoerentes (ex.: transferencia sem origem ou destino).', n; end if;

  -- 3) periodo das pessoas
  select count(*) into n from moradores where desde is not null and ate is not null and ate<desde;
  if n>0 then raise exception 'Ha % pessoa(s) com ultimo mes anterior ao primeiro.', n; end if;
end $$;

-- Vinculos de e-mail que apontam para pessoa inexistente passam a "sem vinculo" (o app avisa o administrador).
update grupo_membros gm set morador_id = null
 where morador_id is not null
   and not exists (select 1 from moradores m where m.grupo_id=gm.grupo_id and m.id=gm.morador_id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname='pagamentos_quem_fk') then
    alter table pagamentos add constraint pagamentos_quem_fk foreign key (grupo_id, quem) references moradores(grupo_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='pagamentos_de_fk') then
    alter table pagamentos add constraint pagamentos_de_fk foreign key (grupo_id, de) references moradores(grupo_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='pagamentos_para_fk') then
    alter table pagamentos add constraint pagamentos_para_fk foreign key (grupo_id, para) references moradores(grupo_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='pagamentos_formato_ck') then
    alter table pagamentos add constraint pagamentos_formato_ck check (
      (tipo='conta' and quem is not null and conta_id is not null and de is null and para is null)
      or (tipo='transferencia' and de is not null and para is not null and de<>para and quem is null and conta_id is null));
  end if;
  if not exists (select 1 from pg_constraint where conname='moradores_periodo_ck') then
    alter table moradores add constraint moradores_periodo_ck check (desde is null or ate is null or ate>=desde);
  end if;
  if not exists (select 1 from pg_constraint where conname='grupo_membros_morador_fk') then
    -- ao excluir uma pessoa, o e-mail dela continua com acesso, apenas sem vinculo
    alter table grupo_membros add constraint grupo_membros_morador_fk foreign key (grupo_id, morador_id) references moradores(grupo_id, id) on delete set null (morador_id);
  end if;
end $$;
