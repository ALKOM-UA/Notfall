-- =======================================================================================================
-- Author:		OK
-- Create date: 20.12.2017
-- Description: Script for set time for all tasks in group with step in @tasks_interval minutes
-- =======================================================================================================
--***BeginVersion***
--_V_7.0	20.12.2017	OK	Created
--_V_7.1	21.03.2018	OK	Added logs and possibility to update tasks from different mandants, fixed sequence of tasks in cursor
--***EndVersion***

declare @initial_time time(0)					--time from which all tasks should be started or time of last start of tasks
declare @tasks_interval int						--interval between tasks
declare @reverse_time_direction int				-- if 0 then @initial_time is time of start first task else @initial_time is time of start last task
declare @time_to_set time(0)  
declare @task_list table (id int)				-- table for store tasks which should be updated

--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

insert into @task_list 
--select task_id from kk_lm_task where task_group_id in (select gr_id from kk_lm_taskgroup where mandant_nr in (6,9,13,14) and gr_id>17 )
	--or--
--select task_id from kk_lm_task where task_id in (4,26,30,31)
	--or--
select task_id from kk_lm_task where task_group_id in (select gr_id from kk_lm_taskgroup where gr_id in (12, 3864))


--select * from @task_list

set @initial_time = '10:00'				--time from which all tasks should be started or time of last start of tasks
set @tasks_interval  = 5				--interval between emergency tasks
set @reverse_time_direction = 0 		--if 0 then @initial_time is time of start first task else @initial_time is time of start last task
--------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

--select for checking result
select * from kk_lm_task t
left join KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
left join KK_LM_TaskGroup par on par.gr_id = gr.parent_id
left join wawi_mandant m on m.mand_nr = gr.mandant_nr
where task_id in (select * from @task_list) 
order by m.mand_bez, par.gr_pos, gr.gr_pos, t.pos

set @time_to_set = @initial_time

--variables for cursor
DECLARE @task_id		 int,
		@time            nvarchar(60)

if @reverse_time_direction = 0  -- the difference in cursors is only sequence of tasks
	DECLARE task_update CURSOR FOR 
	SELECT task_id, time FROM KK_LM_Task t
	LEFT JOIN KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
	LEFT JOIN KK_LM_TaskGroup par on par.gr_id = gr.parent_id
	LEFT JOIN wawi_mandant m on m.mand_nr = gr.mandant_nr
	WHERE task_id in (select * from @task_list)
	ORDER BY m.mand_bez, par.gr_pos, gr.gr_pos, t.pos
else 
	DECLARE task_update CURSOR FOR
	SELECT task_id, time FROM KK_LM_Task t
	LEFT JOIN KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
	LEFT JOIN KK_LM_TaskGroup par on par.gr_id = gr.parent_id
	LEFT JOIN wawi_mandant m on m.mand_nr = gr.mandant_nr
	WHERE task_id in (select * from @task_list)
	ORDER BY m.mand_bez desc, par.gr_pos desc, gr.gr_pos desc, t.pos desc
		 
		
OPEN task_update
FETCH NEXT FROM task_update INTO @task_id, @time
WHILE @@FETCH_STATUS=0
BEGIN
		
	UPDATE KK_LM_Task SET [time] = convert(VARCHAR(5), @time_to_set) WHERE task_id = @task_id
	set @time_to_set = (case 
							when @reverse_time_direction = 0 then DATEADD(MINUTE, @tasks_interval, @time_to_set)  
							else DATEADD(MINUTE, - @tasks_interval, @time_to_set)
						end) 
				
	FETCH NEXT FROM task_update INTO @task_id, @time 
END 
CLOSE task_update
DEALLOCATE task_update

--select for checking result
select * from kk_lm_task t
left join KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
left join KK_LM_TaskGroup par on par.gr_id = gr.parent_id
left join wawi_mandant m on m.mand_nr = gr.mandant_nr
where task_id in (select * from @task_list) 
order by m.mand_bez, par.gr_pos, gr.gr_pos, t.pos