-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query ground cover for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query ground cover for AIM NPR-A" queries the ground cover data from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile ground cover data
SELECT ground_cover.ground_cover_id as ground_cover_id
     , ground_cover.site_visit_code as site_visit_code
	 , site_visit.project_code as project_code
     , ground_element.ground_element as ground_element
     , ground_cover.ground_cover_percent as ground_cover_percent
FROM ground_cover
	LEFT JOIN site_visit ON ground_cover.site_visit_code = site_visit.site_visit_code
    LEFT JOIN ground_element ON ground_cover.ground_element_code = ground_element.ground_element_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');