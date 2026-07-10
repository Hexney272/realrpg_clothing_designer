CREATE TABLE IF NOT EXISTS `realrpg_clothing_designs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(80) NOT NULL,
  `name` varchar(80) NOT NULL DEFAULT 'RealRPG Design',
  `gender` varchar(20) NOT NULL DEFAULT 'unknown',
  `preview_type` varchar(40) NOT NULL DEFAULT 'hoodie',
  `skin` longtext DEFAULT NULL,
  `components` longtext DEFAULT NULL,
  `props` longtext DEFAULT NULL,
  `canvas` longtext DEFAULT NULL,
  `image` mediumtext DEFAULT NULL,
  `is_public` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_orders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(80) NOT NULL,
  `design_id` int(11) DEFAULT NULL,
  `name` varchar(80) NOT NULL DEFAULT 'RealRPG Outfit',
  `type` varchar(30) NOT NULL DEFAULT 'outfit',
  `metadata` longtext DEFAULT NULL,
  `status` varchar(30) NOT NULL DEFAULT 'pending',
  `price` int(11) NOT NULL DEFAULT 0,
  `reviewed_by` varchar(80) DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `note` varchar(255) DEFAULT NULL,
  `item_delivered` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`),
  KEY `design_id` (`design_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_captures` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(80) NOT NULL,
  `name` varchar(80) NOT NULL DEFAULT 'capture',
  `category` varchar(50) DEFAULT NULL,
  `drawable` int(11) DEFAULT NULL,
  `texture` int(11) DEFAULT NULL,
  `result` mediumtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_templates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(120) NOT NULL DEFAULT 'template',
  `file_name` varchar(180) NOT NULL,
  `file_type` varchar(10) NOT NULL DEFAULT 'ydd',
  `category` varchar(50) NOT NULL DEFAULT 'other',
  `gender` varchar(20) NOT NULL DEFAULT 'unisex',
  `preview_type` varchar(40) NOT NULL DEFAULT 'hoodie',
  `component_key` varchar(60) DEFAULT NULL,
  `model_name` varchar(120) DEFAULT NULL,
  `texture_name` varchar(120) DEFAULT NULL,
  `drawable` int(11) NOT NULL DEFAULT 0,
  `texture` int(11) NOT NULL DEFAULT 0,
  `image` mediumtext DEFAULT NULL,
  `meta` longtext DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `template_key` varchar(180) DEFAULT NULL,
  `template_path` varchar(255) DEFAULT NULL,
  `preview_path` varchar(255) DEFAULT NULL,
  `slot_path` varchar(255) DEFAULT NULL,
  `managed_preview` tinyint(1) NOT NULL DEFAULT 0,
  `skipped_reason` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `template_identity` (`gender`,`category`,`file_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `realrpg_clothing_access` (
  `identifier` varchar(80) NOT NULL,
  `expires_at` int(11) NOT NULL DEFAULT 0,
  `granted_by` varchar(80) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
