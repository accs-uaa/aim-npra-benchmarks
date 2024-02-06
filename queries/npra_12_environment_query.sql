-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query environment for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated: 2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query environment for AIM NPR-A" queries the environment data from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile environment data
SELECT environment.environment_id as environment_id
     , environment.site_visit_code as site_visit_code
	 , site_visit.project_code as project_code
     , environment.depth_water_cm as depth_water_cm
     , environment.depth_moss_duff_cm as depth_moss_duff_cm
     , environment.depth_restrictive_layer_cm as depth_restrictive_layer_cm
     , restrictive_type.restrictive_type as restrictive_type
     , environment.microrelief_cm as microrelief_cm
     , environment.surface_water as surface_water
     , soil_class.soil_class as soil_class
     , environment.cryoturbation as cryoturbation
     , soil_texture.soil_texture as dominant_texture_40_cm
     , environment.depth_15_percent_coarse_fragments_cm as depth_15_percent_coarse_fragments_cm
FROM environment
	LEFT JOIN site_visit ON environment.site_visit_code = site_visit.site_visit_code
    LEFT JOIN restrictive_type ON environment.restrictive_type_id = restrictive_type.restrictive_type_id
    LEFT JOIN soil_class ON environment.soil_class_id = soil_class.soil_class_id
    LEFT JOIN soil_texture ON environment.dominant_texture_40_cm_code = soil_texture.soil_texture_code
WHERE project_code IN ('aim_npra_2017', 'aim_gmt2_2021');
