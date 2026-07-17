-- AHBot listing tuning: more profession-levelling materials on the AH.
--
-- The mod-ah-bot quality/class mix lives in acore_world.mod_auctionhousebot,
-- not in mod_ahbot.conf (the conf only holds filters). Stock weights put white
-- trade goods (ore/herbs/cloth/leather — the levelling mats) at 27% while
-- green equipment got 30%; observed live result was ~7 cloth / ~9 herb
-- listings per faction house. Shift weight from green items to white trade
-- goods and raise the faction-house depth 1000 → 4000.
--
-- The 14 percent columns must keep summing to 100 (module normalizes against
-- the total): 40+12+10+1 TGs + 10+17+8+2 items = 100.
--
-- NOT applied by Flux/dbimport. Apply manually against acore_world:
--   kubectl exec -i -n games azerothcore-db-0 -c azerothcore-db -- \
--     sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world' < ahbot-tuning.sql
-- Then restart the worldserver (the module reads this table at boot). The AH
-- fills toward the new maxitems over the following cycles.
--
-- Idempotent: safe to re-run, and must be re-applied after any from-scratch
-- dbimport rebuild (volsync restore already covers it).

-- All houses (2 = Alliance, 6 = Horde, 7 = Neutral): white trade goods
-- 27 → 40, funded by green items 30 → 17.
UPDATE mod_auctionhousebot
SET percentwhitetradegoods = 40,
    percentgreenitems      = 17;

-- Faction houses only: 4x listing depth. Neutral stays at its stock 800.
UPDATE mod_auctionhousebot
SET maxitems = 4000
WHERE auctionhouse IN (2, 6);
