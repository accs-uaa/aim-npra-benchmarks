-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query vegetation cover for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query site visits for AIM NPR-A" queries the site visit data from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile vegetation cover
SELECT vegetation_cover.vegetation_cover_id as vegetation_cover_id
     , vegetation_cover.site_visit_code as site_visit_code
	 , site_visit.project_code as project_code
     , cover_type.cover_type as cover_type
     , taxon_accepted.taxon_name as name_accepted
     , vegetation_cover.dead_status as dead_status
     , vegetation_cover.cover_percent as cover_percent
FROM vegetation_cover
	LEFT JOIN site_visit ON vegetation_cover.site_visit_code = site_visit.site_visit_code
    LEFT JOIN cover_type ON vegetation_cover.cover_type_id = cover_type.cover_type_id
    LEFT JOIN taxon_all taxon_adjudicated ON vegetation_cover.code_adjudicated = taxon_adjudicated.taxon_code
    LEFT JOIN taxon_all taxon_accepted ON taxon_adjudicated.taxon_accepted_code = taxon_accepted.taxon_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');