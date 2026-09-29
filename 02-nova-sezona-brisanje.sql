-- ═══════════════════════════════════════════════════════════════════
-- FC27 Liga — BRISANJE PODATAKA ZA NOVU SEZONU
-- PAŽNJA: briše SVE igrače, mečeve (i playoff), istoriju izmena i mejlove.
-- Pravila ostaju. Ne može da se vrati!
-- ═══════════════════════════════════════════════════════════════════
truncate igraci_kontakt, mecevi, igraci, log restart identity cascade;
