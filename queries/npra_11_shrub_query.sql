-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query shrub structure for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query shrub structure for AIM NPR-A" queries the shrub structure data with standardized taxonomic concepts for the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile shrub structure data
SELECT shrub_structure.shrub_structure_id as shrub_structure_id
     , shrub_structure.site_visit_code as site_visit_code
	 , site_visit.project_code as project_code
     , taxon_accepted.taxon_name as name_accepted
     , shrub_class.shrub_class as shrub_class
     , height_type.height_type as height_type
     , shrub_structure.height_cm as height_cm
FROM shrub_structure
	LEFT JOIN site_visit ON shrub_structure.site_visit_code = site_visit.site_visit_code
    LEFT JOIN taxon_all taxon_adjudicated ON shrub_structure.code_adjudicated = taxon_adjudicated.taxon_code
    LEFT JOIN taxon_all taxon_accepted ON taxon_adjudicated.taxon_accepted_code = taxon_accepted.taxon_code
    LEFT JOIN cover_type ON shrub_structure.cover_type_id = cover_type.cover_type_id
    LEFT JOIN shrub_class ON shrub_structure.shrub_class_id = shrub_class.shrub_class_id
    LEFT JOIN height_type ON shrub_structure.height_type_id = height_type.height_type_id
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');
