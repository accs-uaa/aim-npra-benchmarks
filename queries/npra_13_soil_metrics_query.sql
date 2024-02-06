-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query soil metrics for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated: 2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query soil metrics for AIM NPR-A" queries the soil pH from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile soils data
SELECT soil_metrics.soil_metric_id as soil_metric_id
     , soil_metrics.site_visit_code as site_visit_code
     , site_visit.project_code as project_code
     , soil_metrics.water_measurement as water_measurement
     , soil_metrics.measure_depth_cm as measure_depth_cm
     , soil_metrics.ph as ph
FROM soil_metrics
    LEFT JOIN site_visit ON soil_metrics.site_visit_code = site_visit.site_visit_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');