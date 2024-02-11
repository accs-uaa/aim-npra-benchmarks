-- -*- coding: utf-8 -*-
-- ---------------------------------------------------------------------------
-- Query site visits for AIM NPR-A
-- Author: Timm Nawrocki, Alaska Center for Conservation Science
-- Last Updated:  2024-02-06
-- Usage: Script should be executed in a PostgreSQL 14+ database.
-- Description: "Query site visits for AIM NPR-A" queries the site visit data from the BLM AIM NPR-A sites.
-- ---------------------------------------------------------------------------

-- Compile site visit data
SELECT site_visit.site_visit_code as site_visit_code
     , site_visit.site_code as site_code
     , site.latitude_dd as latitude_dd
     , site.longitude_dd as longitude_dd
FROM site_visit
    LEFT JOIN site ON site_visit.site_code = site.site_code
WHERE site_visit.project_code IN ('aim_npra_2017', 'aim_gmt2_2021');