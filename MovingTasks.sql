-- ===================================================================================
-- Author:		OK
-- Create date: 13.03.2018
-- Description: Script for moving tasks by changing KK_LM_Task.pos
-- ===================================================================================
--***BeginVersion***
--_V_7.0	13.03.2018	OK	Created
--_V_7.1	16.03.2018	OK	Add normalization of positions, fixed calculating of positions
--***EndVersion***


declare @init_task_id int										--task after which should be inserted tasks from the @tasks_list
declare @init_task_group_id int									--group of task after which should be inserted tasks from the @tasks_list
declare @init_pos int											--position of task after which should be inserted tasks from the @tasks_list
declare @curr_pos int
declare @task_id int
declare @ctask_id int											--task_id, cursor variable 
declare @ctask_group_id int										--group of task, cursor variable 
declare @ctask_prev_group_id int								--group of previous task, cursor variable 
declare @tasks_list varchar(max)								--list of task id's to move
declare @task_ids_table table (nr int identity, task_id int)	--id's of tasks parsed from string
declare @task_groups_table table (gr_id int)					--group id's of tasks from @tasks_list
declare @count int												--amount of tasks in @tasks_list
declare @norm_pos int											--positions starting with 0


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

set @tasks_list = '5612,75'								    --list of task id's to move
set @init_task_id = 4316									--task after which should be inserted tasks from the @tasks_list
				
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

--parsing task id's from the list to table task_ids_table
insert into @task_ids_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select @tasks_list), ',')

insert into @task_groups_table select distinct task_group_id from KK_LM_Task where task_id in (select task_id from @task_ids_table)

--for checking the result after 
select pos pos_before_move, * from KK_LM_Task t
left join KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
left join KK_LM_TaskGroup par on par.gr_id = gr.parent_id
left join wawi_mandant m on m.mand_nr = gr.mandant_nr
where task_group_id in (select gr_id from @task_groups_table)
order by m.mand_bez, par.gr_pos, gr.gr_pos, t.pos

---------------------------------------------------------------------------------------------------
set @init_task_group_id = (select task_group_id from KK_LM_Task where task_id = @init_task_id)
set @init_pos = (select pos from KK_LM_Task where task_id = @init_task_id)
set @curr_pos = @init_pos + 1
set @count =  (select count(*) from @task_ids_table)

UPDATE KK_LM_Task SET pos = pos + @count WHERE task_group_id = @init_task_group_id AND pos > @init_pos

DECLARE task_moving CURSOR FOR
SELECT task_id FROM @task_ids_table

OPEN task_moving 
FETCH NEXT FROM task_moving INTO @task_id
WHILE @@FETCH_STATUS=0 
    BEGIN
    
        
		if (select pos from KK_LM_Task where task_id = @task_id) > @init_pos and (select task_group_id from KK_LM_Task where task_id = @task_id) = @init_task_group_id
			begin
				UPDATE KK_LM_Task SET pos = pos - 1  WHERE task_group_id = @init_task_group_id and  pos > (select pos from KK_LM_Task where task_id = @task_id)
			end
		else if (select pos from KK_LM_Task where task_id = @task_id) < @init_pos and (select task_group_id from KK_LM_Task where task_id = @task_id) = @init_task_group_id
			begin
				UPDATE KK_LM_Task SET pos = pos - 1  WHERE task_group_id = @init_task_group_id and  pos > (select pos from KK_LM_Task where task_id = @task_id)
				set @init_pos = @init_pos - 1
				set @curr_pos = @curr_pos - 1
			end
		else if (select task_group_id from KK_LM_Task where task_id = @task_id) != @init_task_group_id
			begin
				UPDATE KK_LM_Task SET pos = pos - 1  WHERE task_group_id = (select task_group_id from KK_LM_Task where task_id = @task_id) and  pos > (select pos from KK_LM_Task where task_id = @task_id)
			end

		UPDATE KK_LM_Task SET task_group_id = @init_task_group_id, pos = @curr_pos WHERE task_id = @task_id

        set @curr_pos = @curr_pos + 1
		        
        FETCH NEXT FROM task_moving INTO @task_id
    END

CLOSE task_moving
DEALLOCATE task_moving

/*
--for checking the result after 
select pos pos_after_move, * from KK_LM_Task t
left join KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
left join KK_LM_TaskGroup par on par.gr_id = gr.parent_id
left join wawi_mandant m on m.mand_nr = gr.mandant_nr
where task_group_id in (select gr_id from @task_groups_table)
order by m.mand_bez, par.gr_pos, gr.gr_pos, t.pos
*/
-------------------------------------

set @ctask_prev_group_id = null

DECLARE normalization CURSOR FOR
SELECT task_id, task_group_id FROM KK_LM_Task WHERE task_group_id in (select gr_id from @task_groups_table) ORDER BY task_group_id, pos, task_id

OPEN normalization 
FETCH NEXT FROM normalization INTO @ctask_id, @ctask_group_id
WHILE @@FETCH_STATUS=0 
BEGIN
	if @ctask_group_id != @ctask_prev_group_id or @ctask_prev_group_id is null
		set @norm_pos = 0
	
	UPDATE KK_LM_Task SET pos = @norm_pos WHERE task_id = @ctask_id
	set @norm_pos = @norm_pos + 1
	set @ctask_prev_group_id = @ctask_group_id
	
	FETCH NEXT FROM normalization INTO @ctask_id, @ctask_group_id
END
CLOSE normalization
DEALLOCATE normalization

--for checking the result after 
select pos pos_after_norm, * from KK_LM_Task t
left join KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
left join KK_LM_TaskGroup par on par.gr_id = gr.parent_id
left join wawi_mandant m on m.mand_nr = gr.mandant_nr
where task_group_id in (select gr_id from @task_groups_table)
order by m.mand_bez, par.gr_pos, gr.gr_pos, t.pos
