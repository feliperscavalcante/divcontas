# Contas da casa

App web instalável (PWA) para dividir as despesas da casa entre as pessoas de um grupo.
Feito em um único `index.html` (JavaScript puro), com banco e login no Supabase e hospedagem no GitHub Pages.

Endereço: https://feliperscavalcante.github.io/divcontas/

## Arquivos do repositório

| Arquivo | Para que serve |
|---|---|
| `index.html` | O app inteiro (telas, estilos e lógica). |
| `config.js` | URL do projeto Supabase e chave pública (anon). Nunca colocar a chave `service_role`. |
| `manifest.webmanifest`, `sw.js`, `icons/` | Instalação como app no celular. |
| `sql/` | Scripts do banco, para rodar no SQL Editor do Supabase, em ordem de data. |
| `.github/workflows/manter-ativo.yml` | Consulta o Supabase duas vezes por semana para ele não ser pausado por falta de uso. |

Scripts do banco, na ordem em que foram criados:
1. `migracao-grupos.sql` (estrutura atual: grupos, pessoas, acessos, despesas e segurança)
2. `migracao-parcelas.sql` (parcelamentos)
3. `migracao-pessoas.sql` (mês de entrada e saída de cada pessoa)
4. `migracao-integridade.sql` (o banco passa a recusar pagamentos ligados a pessoas inexistentes e outros dados incoerentes. Ele confere os dados antes e para com uma mensagem se algo precisar de correção)

O arquivo antigo `supabase.sql` é de antes dos grupos e não deve mais ser usado.

## Como atualizar o app

1. No GitHub, abra o arquivo, clique no lápis ou em Add file, Upload files, e suba a nova versão com o mesmo nome.
2. Commit changes.
3. Aguarde cerca de 1 minuto e abra o app com Ctrl+F5. No celular instalado, feche e abra o app duas vezes.
4. Se a versão trouxer um script `.sql`, rode-o no Supabase antes de subir o `index.html`.

## Rotina de manutenção

**Automático:** a tarefa `Manter Supabase ativo` (aba Actions do GitHub) consulta o banco às segundas e quintas. Se o Supabase não responder, a execução fica vermelha e o GitHub envia um e-mail. O GitHub desativa tarefas agendadas depois de 60 dias sem nenhuma alteração no repositório; ao subir qualquer atualização do app, o relógio reinicia. Se ela for desativada, abra Actions e clique em Enable workflow.

**Todo mês (2 minutos):** em Menu, Exportar backup, e guarde o arquivo `.json` em uma pasta do Drive. O backup traz pessoas, despesas, meses e pagamentos do grupo. O plano gratuito do Supabase não restaura dados apagados, então este arquivo é a sua garantia. O Exportar CSV serve para abrir no Excel, não para restaurar.

**Para restaurar:** Menu, Restaurar backup, escolha o arquivo. Nada é apagado: o que foi excluído volta, o que foi alterado retorna ao valor do backup e o que foi lançado depois continua. Se o arquivo for de outro grupo, o app avisa e importa os dados para o grupo atual.

**A cada 3 meses:** confira em supabase.com/dashboard se o projeto está ativo, sem avisos de e-mail do Supabase, e se `supabase-js` (versão fixada no `index.html`) tem atualização de segurança.

## Se algo der errado

| Sintoma | O que fazer |
|---|---|
| App em branco ou "erro ao conectar" | Veja se o projeto Supabase está pausado e clique em Restore (pausado há mais de 90 dias, o projeto pode não ser recuperável: por isso o backup mensal). Confira o `config.js`. |
| Link de acesso expirado (`otp_expired`) | Peça outro link. Prefira entrar com e-mail e senha. |
| Mudança publicada não aparece | Ctrl+F5. No celular, feche e reabra o app. Se persistir, aumente `VERSAO` no `sw.js`. |
| Valor estranho num mês | Confira o mês anterior: o acerto soma o que ficou em aberto antes. |
| Alguém sem acesso | Menu, Ajustes, Pessoas e acessos (só o administrador). |

## Regras de segurança (não mudar)

- Só a chave `anon` fica no `config.js`. Ela é pública por natureza; quem protege os dados são as regras de acesso (RLS) do banco.
- Todas as tabelas têm RLS ligado. Ao criar tabela nova, ligue o RLS e crie a política antes de usar.
- Nunca publique a chave `service_role` nem a senha do banco.
