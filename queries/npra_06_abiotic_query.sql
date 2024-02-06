-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query abiotic top cover for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query abiotic top cover for AIM NPR-A" queries the abiotic top cover data from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile abiotic top cover data
SELECT abiotic_top_cover.abiotic_cover_id as abiotic_cover_id
     , abiotic_top_cover.site_visit_code as site_visit_code
	 , site_visit.project_code as project_code
     , ground_element.ground_element as abiotic_element
     , abiotic_top_cover.abiotic_top_cover_percent as abiotic_top_cover_percent
FROM abiotic_top_cover
	LEFT JOIN site_visit ON abiotic_top_cover.site_visit_code = site_visit.site_visit_code
    LEFT JOIN ground_element ON abiotic_top_cover.abiotic_element_code = ground_element.ground_element_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');