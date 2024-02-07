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
FROM soil_horizons
    LEFT JOIN site_visit ON soil_horizons.site_visit_code = site_visit.site_visit_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');
