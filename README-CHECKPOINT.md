# PORTALCPT — Checkpoint completo 2026-10-06
Base de código: commit `6bdb8c09bc853bedc399aa13fdb7d9c91cfa24ba`.

Este projeto é HTML/CSS/JS estático. Por isso o código-fonte executável está em `dist/`; não existe uma pasta `src/` separada nem arquivos-fonte ocultos.

## Conteúdo
- `dist/`: frontend completo do checkpoint.
- `supabase/schema.sql`: schema base versionado.
- `supabase/snapshot-current.sql`: recursos adicionais confirmados no Supabase atual.
- `supabase/functions/manage-users/index.ts`: Edge Function administrativa.
- `supabase/config.toml`: configuração Supabase.

O snapshot adicional cobre: Módulo → Tema → Aula; comentários em aulas; vídeo opcional nas dúvidas; anexos múltiplos; Storage `question-images`; RLS/policies; senhas opcionais de módulo/tema; funções de verificação/gestão de senha e guard de perfis atualizado.

## Segurança
Não contém service-role key, secrets, tokens, senha do banco, senhas de usuários nem senhas de conteúdo em texto puro.

## Limite deste pacote
É um checkpoint completo de código + estrutura/configuração reproduzível. Não exporta dados pessoais/Auth nem os arquivos binários já enviados ao Storage. Para isso é necessário um dump/backup de dados autenticado do Supabase.
