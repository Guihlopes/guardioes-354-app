# Passkeys — Guardiões da 354

Este recurso está sendo preparado para autenticação do aparelho ("Acesso rápido e seguro").

## Banco de dados
Execute `passkeys.sql` no SQL Editor do projeto Supabase do Guardiões da 354.

## Segurança e status
- O banco armazena somente credenciais públicas, nunca biometria nem chave privada.
- As tabelas não são acessíveis diretamente por usuários autenticados; o acesso deve ocorrer por Edge Functions com validação WebAuthn.
- **A interface de login por Passkey não deve ser habilitada até que as Edge Functions de registro/verificação estejam implantadas e testadas.** A sessão Supabase atual continua usando e-mail e senha.
- Passkeys/WebAuthn exigem HTTPS e validação criptográfica de challenge, origem e RP ID no servidor. Não simular autenticação apenas exibindo o prompt do celular.
