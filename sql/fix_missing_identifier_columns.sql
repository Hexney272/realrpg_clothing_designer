ALTER TABLE `realrpg_clothing_designs`
  ADD COLUMN IF NOT EXISTS `identifier` varchar(80) NOT NULL DEFAULT '' AFTER `id`;
ALTER TABLE `realrpg_clothing_orders`
  ADD COLUMN IF NOT EXISTS `identifier` varchar(80) NOT NULL DEFAULT '' AFTER `id`;
ALTER TABLE `realrpg_clothing_captures`
  ADD COLUMN IF NOT EXISTS `identifier` varchar(80) NOT NULL DEFAULT '' AFTER `id`;
ALTER TABLE `realrpg_clothing_designs`
  ADD INDEX IF NOT EXISTS `identifier` (`identifier`);
ALTER TABLE `realrpg_clothing_orders`
  ADD INDEX IF NOT EXISTS `identifier` (`identifier`);
ALTER TABLE `realrpg_clothing_captures`
  ADD INDEX IF NOT EXISTS `identifier` (`identifier`);
