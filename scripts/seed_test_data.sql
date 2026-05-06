-- ============================================================
-- LabTrack — Test Data Seed
-- ============================================================
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor)
--
-- 1. Replace 'YOUR_LAB_ID' with the UUID of your lab.
--    (Find it in: Dashboard → Table Editor → laboratories)
-- 2. Click Run.
--
-- What this creates:
--   • 8 lab products (reagents + consumables)
--   • 6 lots for lot-tracked products
--   • 35 exit movements spread over the last 90 days
--   • 4 count sessions (90, 60, 30, 15 days ago)
--     with quantities showing a clear consumption trend
-- ============================================================

DO $$
DECLARE
  v_lab_id  uuid := 'YOUR_LAB_ID';   -- << REPLACE THIS
  v_user_id uuid;

  -- Product IDs
  p_ethanol  uuid := gen_random_uuid();
  p_ipa      uuid := gen_random_uuid();
  p_acetone  uuid := gen_random_uuid();
  p_nacl     uuid := gen_random_uuid();
  p_hcl      uuid := gen_random_uuid();
  p_water    uuid := gen_random_uuid();
  p_gloves   uuid := gen_random_uuid();
  p_ph       uuid := gen_random_uuid();

  -- Lot IDs
  l_eth1  uuid := gen_random_uuid();
  l_eth2  uuid := gen_random_uuid();
  l_ipa1  uuid := gen_random_uuid();
  l_ace1  uuid := gen_random_uuid();
  l_nacl1 uuid := gen_random_uuid();
  l_hcl1  uuid := gen_random_uuid();

  -- Count session IDs
  s1 uuid := gen_random_uuid();
  s2 uuid := gen_random_uuid();
  s3 uuid := gen_random_uuid();
  s4 uuid := gen_random_uuid();

BEGIN
  -- Get a user from this lab
  SELECT user_id INTO v_user_id
  FROM lab_members
  WHERE lab_id = v_lab_id
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found for lab_id: %. Check the UUID.', v_lab_id;
  END IF;

  -- ── Products ──────────────────────────────────────────────
  -- lot-tracked: stock = sum of lot quantities
  -- direct:      stock = direct_quantity column

  INSERT INTO products
    (id, lab_id, name, unit, tracks_lots, reorder_point, minimum_stock, direct_quantity, is_active)
  VALUES
    (p_ethanol, v_lab_id, 'Ethanol 96%',           'mL',     true,  2000, 500, 0,   true),
    (p_ipa,     v_lab_id, 'Isopropanol 70%',        'mL',     true,  1000, 200, 0,   true),
    (p_acetone, v_lab_id, 'Acetone',                'mL',     true,  500,  100, 0,   true),
    (p_nacl,    v_lab_id, 'Sodium Chloride',        'g',      true,  200,  50,  0,   true),
    (p_hcl,     v_lab_id, 'Hydrochloric Acid 37%', 'mL',     true,  300,  100, 0,   true),
    (p_water,   v_lab_id, 'Distilled Water',        'L',      false, 5,    2,   12,  true),
    (p_gloves,  v_lab_id, 'Nitrile Gloves (M)',     'units',  false, 50,   10,  105, true),
    (p_ph,      v_lab_id, 'pH Paper',               'strips', false, 20,   5,   52,  true);

  -- ── Lots (quantities = current state after all movements) ─

  INSERT INTO lots (id, product_id, lot_number, quantity, expiration_date)
  VALUES
    (l_eth1,  p_ethanol, 'ETH-2024-001', 1200, now() + interval '8 months'),
    (l_eth2,  p_ethanol, 'ETH-2025-001', 900,  now() + interval '14 months'),
    (l_ipa1,  p_ipa,     'IPA-2024-001', 1800, now() + interval '10 months'),
    (l_ace1,  p_acetone, 'ACE-2024-001', 950,  now() + interval '6 months'),
    (l_nacl1, p_nacl,    'NACL-2024-01', 580,  now() + interval '24 months'),
    (l_hcl1,  p_hcl,     'HCL-2024-001', 1000, now() + interval '12 months');

  -- ── Exit movements (35 total, for Consumption report) ─────
  -- Spread over last 90 days. Ethanol = most consumed product.

  -- Ethanol — 15 movements
  INSERT INTO movements
    (id, lab_id, product_id, lot_id, type, quantity, reason, user_id, created_at, is_synced)
  VALUES
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 150, 'Experiment A1',  v_user_id, now() - interval '87 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 200, 'Experiment A2',  v_user_id, now() - interval '80 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 180, 'Cleaning',       v_user_id, now() - interval '72 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 150, 'Experiment B1',  v_user_id, now() - interval '65 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 220, 'Experiment B2',  v_user_id, now() - interval '58 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth1, 'exit', 160, 'Experiment C1',  v_user_id, now() - interval '50 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 200, 'Experiment C2',  v_user_id, now() - interval '42 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 180, 'Experiment D1',  v_user_id, now() - interval '35 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 220, 'Cleaning',       v_user_id, now() - interval '28 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 150, 'Experiment D2',  v_user_id, now() - interval '20 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 200, 'Experiment E1',  v_user_id, now() - interval '14 days', true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 160, 'Experiment E2',  v_user_id, now() - interval '8 days',  true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 180, 'Experiment F1',  v_user_id, now() - interval '4 days',  true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 150, 'Experiment F2',  v_user_id, now() - interval '2 days',  true),
    (gen_random_uuid(), v_lab_id, p_ethanol, l_eth2, 'exit', 200, 'Experiment G1',  v_user_id, now() - interval '1 day',   true);

  -- Isopropanol — 8 movements
  INSERT INTO movements
    (id, lab_id, product_id, lot_id, type, quantity, reason, user_id, created_at, is_synced)
  VALUES
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 150, 'Disinfection',    v_user_id, now() - interval '85 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 200, 'Disinfection',    v_user_id, now() - interval '70 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 150, 'Surface clean',   v_user_id, now() - interval '55 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 200, 'Disinfection',    v_user_id, now() - interval '40 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 150, 'Experiment A3',   v_user_id, now() - interval '28 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 200, 'Disinfection',    v_user_id, now() - interval '18 days', true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 150, 'Surface clean',   v_user_id, now() - interval '8 days',  true),
    (gen_random_uuid(), v_lab_id, p_ipa, l_ipa1, 'exit', 200, 'Disinfection',    v_user_id, now() - interval '3 days',  true);

  -- Acetone — 5 movements
  INSERT INTO movements
    (id, lab_id, product_id, lot_id, type, quantity, reason, user_id, created_at, is_synced)
  VALUES
    (gen_random_uuid(), v_lab_id, p_acetone, l_ace1, 'exit', 200, 'Extraction',    v_user_id, now() - interval '75 days', true),
    (gen_random_uuid(), v_lab_id, p_acetone, l_ace1, 'exit', 150, 'Glassware wash',v_user_id, now() - interval '55 days', true),
    (gen_random_uuid(), v_lab_id, p_acetone, l_ace1, 'exit', 200, 'Extraction',    v_user_id, now() - interval '35 days', true),
    (gen_random_uuid(), v_lab_id, p_acetone, l_ace1, 'exit', 150, 'Experiment C3', v_user_id, now() - interval '18 days', true),
    (gen_random_uuid(), v_lab_id, p_acetone, l_ace1, 'exit', 200, 'Extraction',    v_user_id, now() - interval '5 days',  true);

  -- Sodium Chloride — 4 movements
  INSERT INTO movements
    (id, lab_id, product_id, lot_id, type, quantity, reason, user_id, created_at, is_synced)
  VALUES
    (gen_random_uuid(), v_lab_id, p_nacl, l_nacl1, 'exit', 100, 'Buffer prep',    v_user_id, now() - interval '80 days', true),
    (gen_random_uuid(), v_lab_id, p_nacl, l_nacl1, 'exit', 80,  'Buffer prep',    v_user_id, now() - interval '55 days', true),
    (gen_random_uuid(), v_lab_id, p_nacl, l_nacl1, 'exit', 100, 'Experiment H1',  v_user_id, now() - interval '30 days', true),
    (gen_random_uuid(), v_lab_id, p_nacl, l_nacl1, 'exit', 80,  'Buffer prep',    v_user_id, now() - interval '10 days', true);

  -- Hydrochloric Acid — 3 movements
  INSERT INTO movements
    (id, lab_id, product_id, lot_id, type, quantity, reason, user_id, created_at, is_synced)
  VALUES
    (gen_random_uuid(), v_lab_id, p_hcl, l_hcl1, 'exit', 150, 'pH adjustment',   v_user_id, now() - interval '78 days', true),
    (gen_random_uuid(), v_lab_id, p_hcl, l_hcl1, 'exit', 150, 'Titration',       v_user_id, now() - interval '50 days', true),
    (gen_random_uuid(), v_lab_id, p_hcl, l_hcl1, 'exit', 150, 'pH adjustment',   v_user_id, now() - interval '22 days', true);

  -- ── Count sessions ────────────────────────────────────────
  -- 4 sessions showing consumption trend across 90 days.
  -- Quantities decrease over time as products are consumed.
  -- A few intentional discrepancies (counted ≠ expected).

  -- Session 1 — 90 days ago
  INSERT INTO count_sessions (id, lab_id, counted_at, total_counted, discrepancy_count)
  VALUES (s1, v_lab_id, now() - interval '90 days', 8, 1);

  INSERT INTO count_session_items
    (id, session_id, product_id, product_name, unit, expected, counted)
  VALUES
    (gen_random_uuid(), s1, p_ethanol, 'Ethanol 96%',          'mL',     8000, 8000),
    (gen_random_uuid(), s1, p_ipa,     'Isopropanol 70%',       'mL',     4000, 4000),
    (gen_random_uuid(), s1, p_acetone, 'Acetone',               'mL',     2000, 2000),
    (gen_random_uuid(), s1, p_nacl,    'Sodium Chloride',       'g',      1000, 1000),
    (gen_random_uuid(), s1, p_hcl,     'Hydrochloric Acid 37%', 'mL',     1500, 1450),  -- discrepancy: −50
    (gen_random_uuid(), s1, p_water,   'Distilled Water',       'L',      20,   20),
    (gen_random_uuid(), s1, p_gloves,  'Nitrile Gloves (M)',    'units',  200,  200),
    (gen_random_uuid(), s1, p_ph,      'pH Paper',              'strips', 100,  100);

  -- Session 2 — 60 days ago
  INSERT INTO count_sessions (id, lab_id, counted_at, total_counted, discrepancy_count)
  VALUES (s2, v_lab_id, now() - interval '60 days', 8, 1);

  INSERT INTO count_session_items
    (id, session_id, product_id, product_name, unit, expected, counted)
  VALUES
    (gen_random_uuid(), s2, p_ethanol, 'Ethanol 96%',          'mL',     5500, 5600),  -- discrepancy: +100
    (gen_random_uuid(), s2, p_ipa,     'Isopropanol 70%',       'mL',     3500, 3500),
    (gen_random_uuid(), s2, p_acetone, 'Acetone',               'mL',     1650, 1650),
    (gen_random_uuid(), s2, p_nacl,    'Sodium Chloride',       'g',      900,  900),
    (gen_random_uuid(), s2, p_hcl,     'Hydrochloric Acid 37%', 'mL',     1350, 1350),
    (gen_random_uuid(), s2, p_water,   'Distilled Water',       'L',      18,   18),
    (gen_random_uuid(), s2, p_gloves,  'Nitrile Gloves (M)',    'units',  170,  170),
    (gen_random_uuid(), s2, p_ph,      'pH Paper',              'strips', 85,   85);

  -- Session 3 — 30 days ago
  INSERT INTO count_sessions (id, lab_id, counted_at, total_counted, discrepancy_count)
  VALUES (s3, v_lab_id, now() - interval '30 days', 8, 2);

  INSERT INTO count_session_items
    (id, session_id, product_id, product_name, unit, expected, counted)
  VALUES
    (gen_random_uuid(), s3, p_ethanol, 'Ethanol 96%',          'mL',     3200, 3200),
    (gen_random_uuid(), s3, p_ipa,     'Isopropanol 70%',       'mL',     2600, 2600),
    (gen_random_uuid(), s3, p_acetone, 'Acetone',               'mL',     1300, 1300),
    (gen_random_uuid(), s3, p_nacl,    'Sodium Chloride',       'g',      720,  700),   -- discrepancy: −20
    (gen_random_uuid(), s3, p_hcl,     'Hydrochloric Acid 37%', 'mL',     1200, 1150),  -- discrepancy: −50
    (gen_random_uuid(), s3, p_water,   'Distilled Water',       'L',      15,   15),
    (gen_random_uuid(), s3, p_gloves,  'Nitrile Gloves (M)',    'units',  140,  140),
    (gen_random_uuid(), s3, p_ph,      'pH Paper',              'strips', 68,   68);

  -- Session 4 — 15 days ago (most recent)
  INSERT INTO count_sessions (id, lab_id, counted_at, total_counted, discrepancy_count)
  VALUES (s4, v_lab_id, now() - interval '15 days', 8, 0);

  INSERT INTO count_session_items
    (id, session_id, product_id, product_name, unit, expected, counted)
  VALUES
    (gen_random_uuid(), s4, p_ethanol, 'Ethanol 96%',          'mL',     2100, 2100),
    (gen_random_uuid(), s4, p_ipa,     'Isopropanol 70%',       'mL',     1800, 1800),
    (gen_random_uuid(), s4, p_acetone, 'Acetone',               'mL',     950,  950),
    (gen_random_uuid(), s4, p_nacl,    'Sodium Chloride',       'g',      580,  580),
    (gen_random_uuid(), s4, p_hcl,     'Hydrochloric Acid 37%', 'mL',     1000, 1000),
    (gen_random_uuid(), s4, p_water,   'Distilled Water',       'L',      12,   12),
    (gen_random_uuid(), s4, p_gloves,  'Nitrile Gloves (M)',    'units',  105,  105),
    (gen_random_uuid(), s4, p_ph,      'pH Paper',              'strips', 52,   52);

  RAISE NOTICE 'Seed complete for lab %. Products: 8, Movements: 35, Sessions: 4.', v_lab_id;
END $$;
