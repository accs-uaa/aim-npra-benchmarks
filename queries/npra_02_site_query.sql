SELECT site.site_code as site_code
     , site.establishing_project_code as establishing_project_code
     , site.latitude_dd as latitude_dd
     , site.longitude_dd as longitude_dd
FROM site
WHERE establishing_project_code IN ('aim_npra_2017', 'aim_gmt2_2021');
