-- ============================================
-- Hydra Framework - Database Schema
-- ============================================
-- Run this SQL file to set up all required tables.
-- Hydra also auto-creates tables on first boot if
-- auto_migrate is enabled (default: true).
-- ============================================

-- Players table
CREATE TABLE IF NOT EXISTS `hydra_players` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `last_name` VARCHAR(64) DEFAULT NULL,
  `permission_group` VARCHAR(32) DEFAULT 'user',
  `accounts` LONGTEXT DEFAULT '{}',
  `job` TEXT DEFAULT '{}',
  `position` TEXT DEFAULT '{}',
  `metadata` LONGTEXT DEFAULT '{}',
  `charinfo` TEXT DEFAULT '{}',
  `inventory` LONGTEXT DEFAULT '{}',
  `last_login` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idx_identifier` (`identifier`),
  INDEX `idx_permission_group` (`permission_group`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Characters table
CREATE TABLE IF NOT EXISTS `hydra_characters` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(64) NOT NULL,
  `char_slot` TINYINT UNSIGNED DEFAULT 1,
  `firstname` VARCHAR(32) NOT NULL,
  `lastname` VARCHAR(32) NOT NULL,
  `sex` VARCHAR(10) DEFAULT 'male',
  `dob` VARCHAR(10) DEFAULT '1990-01-01',
  `nationality` VARCHAR(32) DEFAULT 'American',
  `appearance` LONGTEXT DEFAULT '{}',
  `clothing` LONGTEXT DEFAULT '{}',
  `accounts` LONGTEXT DEFAULT '{}',
  `job` TEXT DEFAULT '{}',
  `position` TEXT DEFAULT '{}',
  `metadata` LONGTEXT DEFAULT '{}',
  `inventory` LONGTEXT DEFAULT '{}',
  `permission_group` VARCHAR(32) DEFAULT 'user',
  `last_played` DATETIME DEFAULT NULL,
  `playtime` INT UNSIGNED DEFAULT 0,
  `is_deleted` TINYINT DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idx_char_identifier` (`identifier`, `char_slot`),
  INDEX `idx_char_deleted` (`is_deleted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Doorlocks table
CREATE TABLE IF NOT EXISTS `hydra_doorlocks` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `door_id` VARCHAR(64) NOT NULL,
  `label` VARCHAR(128) DEFAULT NULL,
  `coords_x` FLOAT NOT NULL,
  `coords_y` FLOAT NOT NULL,
  `coords_z` FLOAT NOT NULL,
  `model` BIGINT DEFAULT 0,
  `heading` FLOAT DEFAULT 0,
  `locked` TINYINT(1) DEFAULT 1,
  `lock_type` VARCHAR(32) DEFAULT 'public',
  `lock_data` TEXT DEFAULT '{}',
  `auto_lock` INT DEFAULT 0,
  `double_model` BIGINT DEFAULT 0,
  `created_by` VARCHAR(64) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `idx_door_id` (`door_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Inventories table
CREATE TABLE IF NOT EXISTS `hydra_inventories` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(128) NOT NULL,
  `items` LONGTEXT DEFAULT NULL,
  `money` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Vehicle inventories table
CREATE TABLE IF NOT EXISTS `hydra_vehicle_inventories` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(32) NOT NULL,
  `type` VARCHAR(16) DEFAULT 'trunk',
  `items` LONGTEXT DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stash inventories table
CREATE TABLE IF NOT EXISTS `hydra_stash_inventories` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `stash_id` VARCHAR(128) NOT NULL,
  `items` LONGTEXT DEFAULT NULL,
  `owner` VARCHAR(128) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_stash_id` (`stash_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Anti-cheat bans table
CREATE TABLE IF NOT EXISTS `hydra_anticheat_bans` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(128) NOT NULL,
  `all_identifiers` LONGTEXT DEFAULT NULL,
  `reason` VARCHAR(255) DEFAULT NULL,
  `module` VARCHAR(64) DEFAULT NULL,
  `expires` BIGINT DEFAULT 0,
  `timestamp` BIGINT DEFAULT NULL,
  `playerName` VARCHAR(64) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================
-- Optional: Migration from ESX
-- ============================================
-- Uncomment the following to migrate existing ESX users:
--
-- INSERT INTO hydra_players (identifier, last_name, permission_group, accounts, job, position, metadata)
-- SELECT
--   u.identifier,
--   u.lastname,
--   COALESCE(u.group, 'user'),
--   CONCAT('{"cash":', COALESCE(u.money, 0), ',"bank":', COALESCE(u.bank, 0), ',"black_money":', COALESCE(u.black_money, 0), '}'),
--   CONCAT('{"name":"', COALESCE(u.job, 'unemployed'), '","grade":', COALESCE(u.job_grade, 0), '}'),
--   COALESCE(u.position, '{}'),
--   '{}'
-- FROM users u
-- ON DUPLICATE KEY UPDATE last_name = VALUES(last_name);

-- ============================================
-- Optional: Migration from QBCore
-- ============================================
-- Uncomment the following to migrate existing QBCore players:
--
-- INSERT INTO hydra_players (identifier, last_name, permission_group, accounts, job, position, charinfo, metadata)
-- SELECT
--   p.citizenid,
--   JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')),
--   'user',
--   p.money,
--   p.job,
--   p.position,
--   p.charinfo,
--   p.metadata
-- FROM players p
-- ON DUPLICATE KEY UPDATE last_name = VALUES(last_name);
