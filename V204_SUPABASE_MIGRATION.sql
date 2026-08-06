-- KeySuite V2.04 migration / ES access hotfix
BEGIN;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON TABLE public.ks_products_es TO authenticated;
ALTER TABLE public.ks_products_es ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ks_products_es_select ON public.ks_products_es;
CREATE POLICY ks_products_es_select ON public.ks_products_es FOR SELECT TO authenticated USING (public.keysuite_has_access());
COMMIT;
