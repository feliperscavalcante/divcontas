-- =============================================================
-- Contas da casa: suporte a contas parceladas
--
-- Só acrescenta colunas. Nenhum dado é alterado ou apagado, e o app
-- que está no ar continua funcionando depois de rodar este arquivo.
-- Pode rodar mais de uma vez sem problema.
--
-- Ordem: 1) rode este SQL   2) depois suba o novo index.html
-- =============================================================

begin;

-- Conta recorrente que é parcelada: quantas parcelas e em que mês começa
alter table contas_recorrentes add column if not exists parcelas int;
alter table contas_recorrentes add column if not exists inicio text;

alter table contas_recorrentes drop constraint if exists contas_recorrentes_parcelas_chk;
alter table contas_recorrentes add constraint contas_recorrentes_parcelas_chk
  check (
    (parcelas is null and inicio is null)
    or (parcelas is not null and inicio is not null
        and parcelas between 2 and 120
        and inicio ~ '^[0-9]{4}-[0-9]{2}$')
  );

-- Conta de um mês que veio de um parcelamento: qual parcela é e o total
alter table contas_mes add column if not exists parcela int;
alter table contas_mes add column if not exists parcelas int;

alter table contas_mes drop constraint if exists contas_mes_parcela_chk;
alter table contas_mes add constraint contas_mes_parcela_chk
  check (
    (parcela is null and parcelas is null)
    or (parcela is not null and parcelas is not null
        and parcelas >= 2
        and parcela between 1 and parcelas)
  );

commit;
