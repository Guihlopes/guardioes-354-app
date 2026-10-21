-- Keepalive para o projeto Guardioes da 354.
-- A função não consulta dados de membros nem altera dados do aplicativo.
CREATE OR REPLACE FUNCTION public.guardioes_keepalive()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
  SELECT jsonb_build_object(
    'ok', true,
    'timestamp', now()
  );
$$;

GRANT EXECUTE ON FUNCTION public.guardioes_keepalive() TO anon, authenticated;
