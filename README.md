# CPT — Careca Poker Team

Videoteca de poker em português: login, dashboard, módulos e aulas, progresso individual, revisões por módulo, dúvidas com vídeos, comentários, perfil e gestão de alunos. Interface responsiva, sem etapa de build.

## Demonstração
Abra a publicação e escolha **Como aluno** ou **Como administrador**. Os dados de exemplo e alterações ficam somente no navegador, compartilhados entre esses dois perfis demo. As aulas de exemplo não contêm vídeos reais. Uma conta criada no modo demo é apenas um registro de exemplo e não possui login real.

## Ativar o Supabase
1. Crie um projeto Supabase dedicado. Execute `supabase/schema.sql` uma única vez no SQL Editor. O script é uma instalação inicial, não uma migração incremental de outro sistema.
2. Em Authentication → Providers, desative o cadastro público por e-mail (`Allow new users to sign up`). Não há cadastro público na interface.
3. Em Authentication → Users, crie a primeira conta com seu e-mail e senha. Promova **somente essa conta** pelo SQL Editor, substituindo o e-mail:
   ```sql
   update public.profiles set role = 'admin' where email = 'SEU_EMAIL';
   ```
4. Instale a Supabase CLI e, na raiz deste projeto, execute:
   ```bash
   supabase login
   supabase link --project-ref SEU_PROJECT_REF
   supabase functions deploy manage-users
   ```
   O arquivo `supabase/config.toml` configura a função para validar o token dentro do código. A função usa `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY`, variáveis padrão do ambiente das Edge Functions. A chave service_role permanece exclusivamente no backend.
5. O frontend deste repositório já vem conectado ao projeto Supabase PORTALCPT usando somente a URL e a chave pública `publishable`. A `service_role` permanece exclusivamente no backend.
6. Crie alunos em **Usuários** e compartilhe as credenciais por seu meio habitual. Os alunos podem alterar a senha em **Meu perfil**. O envio de credenciais não é automático; o aplicativo não envia e-mails. Recuperação de senha por e-mail e troca obrigatória no primeiro acesso ainda não foram implementadas.

## Vídeos do Google Drive
Use links `https://drive.google.com/file/d/ID/view` ou links com `?id=ID`. A aplicação converte o ID para o player `/preview`, sem armazenar os arquivos de vídeo no Supabase. O proprietário precisa conceder aos alunos permissão de acesso no Drive. Arquivos restritos podem exigir login Google; restrições de cookies podem afetar o player.

O login da plataforma não substitui as permissões do Drive. Se você usar “qualquer pessoa com o link”, o vídeo poderá ser acessado fora da plataforma por quem obtiver o link. Bloquear um aluno na plataforma não remove permissões Google já concedidas; o administrador precisa revogá-las também no Drive. Para conteúdo realmente restrito, compartilhe com as contas Google dos alunos e teste o player antes de adotar essa configuração.

Conclusão e revisão são marcações manuais. O aplicativo não mede o tempo assistido do iframe do Drive nem retoma o vídeo automaticamente. A porcentagem de revisão é: aulas distintas marcadas como revisadas / total de aulas do módulo. Revisar uma aula também requer tê-la concluído. Remover a conclusão remove sua revisão. Adicionar aulas muda o denominador dos indicadores.

## Segurança e validação
- RLS no banco nega leitura anônima e limita escritas por papel e autoria.
- Alunos não podem mudar role, active ou email pelo próprio perfil.
- Função administrativa valida sessão, papel e acesso ativo antes de criar ou bloquear contas.
- Ao bloquear, o banco impede acesso aos dados mesmo se um token antigo ainda for válido.
- O Supabase Auth e as políticas devem ser validados em seu projeto antes de convidar alunos; não foram executados contra uma conta real nesta entrega.
- A demonstração não é um mecanismo de autorização; todas as regras de acesso reais estão no Supabase.

## Publicação própria
A pasta `dist/` pode ser publicada na Vercel ou em qualquer hospedagem estática. `.openai/hosting.json` pertence à publicação Sites, não ao Supabase. Não há dependências de frontend: Auth e banco usam a API REST do Supabase. Fontes usam Google Fonts, com fallback para fontes do sistema.

## Excluir alunos
Na tela **Usuários**, o administrador pode escolher **Excluir** e confirmar a exclusão permanente. A conta Auth, o perfil, o progresso, as dúvidas e os comentários do aluno são removidos. Comentários de outros usuários nas dúvidas excluídas também são removidos, conforme as chaves estrangeiras do banco. Aulas, módulos e arquivos no Google Drive permanecem. A própria conta e outros administradores não podem ser excluídos.

Em um Supabase já conectado, publique a versão atualizada da função com `supabase functions deploy manage-users` para ativar esta ação. Não é necessário alterar o schema.