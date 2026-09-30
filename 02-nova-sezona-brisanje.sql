-- ═══════════════════════════════════════════════════════════════════
-- FC27 Liga — BRISANJE PODATAKA ZA NOVU SEZONU
-- PAŽNJA: briše SVE igrače, mečeve (i playoff), istoriju izmena, mejlove i fer-plej glasove.
-- Pravila ostaju. Ne može da se vrati!
-- ═══════════════════════════════════════════════════════════════════
truncate igraci_kontakt, mecevi, igraci, log restart identity cascade;
-- fer-plej glasovi se brišu automatski zajedno sa igračima (cascade)
