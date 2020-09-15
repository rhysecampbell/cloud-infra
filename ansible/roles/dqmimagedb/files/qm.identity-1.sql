drop table if exists qm.identity_backup;
create table qm.identity_backup as select * from qm.identity;
 
drop table if exists qm.temp_identity;
create table qm.temp_identity as
(
select dqm_stn_id, cam_no, image_target_name, max(indentity_id) as indentity_id
from qm.identity
where dqm_stn_id > 0
group by dqm_stn_id, cam_no, image_target_name
order by dqm_stn_id, cam_no
);
 
delete from qm.identity where indentity_id not in (select indentity_id from qm.temp_identity);
drop table qm.temp_identity;
