-- Funnel-test: bestaande leads (geïmporteerd vóór de test) expliciet naar de video-funnel.
-- Ze tellen NIET mee in de round-robin (geen funnelAssigned-vlag).
update public.leads
set data = data || '{"funnel":"video"}'::jsonb,
    updated_at = now()
where not (data ? 'funnel');
