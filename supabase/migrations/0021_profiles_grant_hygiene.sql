-- Registration goes through register_patient() and profile rows are never
-- inserted or deleted by a client. The grants outlived the design; RLS was
-- the only thing making them harmless.
revoke insert, delete on public.profiles from authenticated;
