-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query soil horizons for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2023-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query soil horizons for AIM NPR-A" queries organic mineral ratio and organic soil depth from the BLM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile soils data
SELECT soil_horizons.soil_horizon_id as soil_horizon_id
     , soil_horizons.site_visit_code as site_visit_code
     , site_visit.project_code as project_code
     , soil_horizons.horizon_order as horizon_order
     , soil_horizons.thickness_cm as thickness_cm
     , soil_horizons.depth_upper_cm as depth_upper_cm
     , soil_horizons.depth_lower_cm as depth_lower_cm
     , soil_horizons.horizon_primary_code as horizon_primary_code
     , soil_horizons.horizon_suffix_1_code as horizon_suffix_1
     , soil_horizons.horizon_suffix_2_code as horizon_suffix_2
     , soil_horizons.horizon_secondary_code as horizon_secondary_code
     , soil_horizons.horizon_suffix_3_code as horizon_suffix_3
     , soil_horizons.horizon_suffix_4_code as horizon_suffix_4
     , soil_horizons.clay_percent as clay_percent
     , soil_horizons.total_coarse_fragment_percent as total_coarse_fragment_percent
     , soil_horizons.gravel_percent as gravel_percent
     , soil_horizons.cobble_percent as cobble_percent
     , soil_horizons.stone_percent as stone_percent
     , soil_horizons.boulder_percent as boulder_percent
FROM soil_horizons
    LEFT JOIN soil_texture ON soil_horizons.texture_code = soil_texture.soil_texture_code
    LEFT JOIN site_visit ON soil_horizons.site_visit_code = site_visit.site_visit_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');
