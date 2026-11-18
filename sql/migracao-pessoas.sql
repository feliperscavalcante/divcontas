-- Periodo de participacao de cada pessoa na divisao das despesas.
-- Rode uma vez no Supabase: SQL Editor > New query > colar > Run.
-- Seguro para rodar de novo.

alter table moradores add column if not exists desde text;  -- primeiro mes em que divide (AAAA-MM). Vazio = desde o inicio
alter table moradores add column if not exists ate text;    -- ultimo mes em que divide (AAAA-MM). Vazio = sem data final
