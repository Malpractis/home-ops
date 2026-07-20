-- Realm item_template QoL tweaks.
--
-- NOT applied by Flux/dbimport. Apply manually against acore_world:
--   kubectl exec -i -n games azerothcore-db-0 -c azerothcore-db -- \
--     sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" acore_world' < item-tweaks.sql
-- item_template is cached at boot with NO live reload command, so changes take
-- effect on the next worldserver restart. Clients also cache item data — wipe
-- Cache\WDB (or Cache\WDB\enUS\Item-*.wdb) so the new values render.
--
-- Idempotent: safe to re-run, and must be re-applied after any from-scratch
-- dbimport rebuild.

-- ---------------------------------------------------------------------------
-- Soul Shard (6265): stack to the existing 32-shard cap so a warlock's shards
-- fit in ONE bag slot instead of up to 32. MaxCount (32) is deliberately left
-- alone — this is a clutter fix, not a cap change. Verified safe: shards are
-- created via spell 43836 (CreateItem) and consumed as reagents, both through
-- the generic stack-/cap-aware item system, so stacking breaks nothing.
-- ---------------------------------------------------------------------------
UPDATE item_template SET stackable = 32 WHERE entry = 6265;
