# Implantação de Acesso rápido e seguro (Passkeys)

## O que já está no código
- Botão de login "Acesso rápido e seguro".
- Ação para cadastrar o aparelho dentro do perfil depois de entrar com e-mail e senha.
- Edge Functions para iniciar e validar registro e autenticação WebAuthn.
- Cache PWA atualizado para v28.

## O que ainda precisa ser feito antes de usar em produção
1. Executar `supabase/passkeys.sql` no SQL Editor (já enviado).
2. Implantar as quatro Edge Functions deste diretório no projeto Supabase `nlaywsguzsiwvexwnakp`.
3. Configurar as regras `verify_jwt` conforme `supabase/config.toml` (ou equivalente no dashboard).
4. Testar cadastro e login em aparelho real, no domínio publicado.
5. Confirmar que o redirect e o domínio real do app são `https://guardioes-354-app.guardioesda354.workers.dev`. Se mudar domínio, atualizar a validação de origem/RP ID no servidor.

## Segurança
As funções de autenticação por Passkey usam WebAuthn com verificação de challenge, origem, RP ID e user verification. A chave privada fica no autenticador do aparelho. O login tradicional continua disponível.
