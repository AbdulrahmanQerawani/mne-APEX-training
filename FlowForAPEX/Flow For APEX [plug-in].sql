-- Delete Instance Using Page Process
-- Select flow Using this query
select prcs_id
from flow_instances_vw
where prcs_business_ref = :P3_APP_ID;


-- complete step using page process

