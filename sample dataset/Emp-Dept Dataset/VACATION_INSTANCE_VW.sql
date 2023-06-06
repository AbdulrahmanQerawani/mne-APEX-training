CREATE OR REPLACE FORCE EDITIONABLE VIEW "VACATION_INSTANCE_VW" ("VACATION_ID", "EMP_NO", "START_DATE", "END_DATE", "DESTINATION", "COMMENTS", "PRCS_ID", "LINK_TEXT") AS 
  select vac.VACATION_ID
     , VAC.EMP_NO
     , VAC.START_DATE
     , VAC.END_DATE
     , VAC.DESTINATION
     , vac.COMMENTS
     , inbx.sbfl_prcs_id as prcs_id
     , inbx.link_text
  from VACATIONS vac
  join flow_task_inbox_vw inbx on vac.VACATION_ID = to_number(inbx.sbfl_business_ref default -1 on conversion error)
 where inbx.sbfl_dgrm_name = 'Diagram name'
 and inbx.sbfl_current in ('sub-process1','sub-process2')
 and inbx.sbfl_current_lane = 'EMPLOYEE'
 WITH READ ONLY
/
