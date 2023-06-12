create or replace procedure
GET_SBFL_DATA(
       P_PRCS_ID IN NUMBER
      ,P_SBFL_ID OUT NUMBER
      ,P_SBFL_STEP_KEY OUT VARCHAR2
)
as
begin
    begin
            -- we expect only one subflow
    select sbfl.sbfl_id
         , sbfl.sbfl_step_key
    into p_sbfl_id
        , p_sbfl_step_key
    from flow_subflows_vw sbfl
    where sbfl.sbfl_prcs_id = p_prcs_id;
    exception
          when TOO_MANY_ROWS
          then
            raise;
    end;
end GET_SBFL_DATA;