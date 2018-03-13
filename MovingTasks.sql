-- ===================================================================================
-- Author:		OK
-- Create date: 13.03.2018
-- Description: Script for moving tasks by changing KK_LM_Task.pos
-- ===================================================================================
--***BeginVersion***
--_V_7.0	13.03.2018	OK	Created


declare @init_task_id int										--task after which should be inserted tasks from the @tasks_list
declare @task_group_id int										--group of task after which should be inserted tasks from the @tasks_list
declare @init_pos int											--position of task after which should be inserted tasks from the @tasks_list
declare @curr_pos int
declare @task_id int
declare @tasks_list varchar(max)								--list of task id's to move
declare @task_ids_table table (nr int identity, task_id int)	--id's of tasks parsed from string
declare @count int												--amount of tasks in @tasks_list


---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

--select pos p, * from KK_LM_Task where task_group_id = 3243 order by pos

set @tasks_list = '4316,4315,4309'								--list of task id's to move
set @init_task_id = 4311										--task after which should be inserted tasks from the @tasks_list
				
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


--parsing task id's from the list to table task_ids_table
insert into @task_ids_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select @tasks_list), ',')

set @count =  (select count(*) from @task_ids_table)

set @task_group_id = (select task_group_id from KK_LM_Task where task_id = @init_task_id)

set @init_pos = (select pos from KK_LM_Task where task_id = @init_task_id)

set @curr_pos = @init_pos + 1

--for checking the result after 
select pos p, * from KK_LM_Task where task_group_id = @task_group_id order by pos

DECLARE task_moving CURSOR FOR
select task_id from @task_ids_table where 
--task_id is not null
(select count (task_id) from @task_ids_table) > 0


if (select max (pos) from KK_LM_Task where task_group_id = @task_group_id) + @count  < 1000 
	update KK_LM_Task set pos = pos + 1000 where task_group_id = @task_group_id and pos > @init_pos
else
	update KK_LM_Task set pos = pos + 10000 where task_group_id = @task_group_id and pos > @init_pos


OPEN task_moving 
FETCH NEXT FROM task_moving INTO @task_id
WHILE @@FETCH_STATUS=0 and (select count (task_id) from @task_ids_table) > 0
	BEGIN
	
		set @task_id = (select top 1 task_id from @task_ids_table order by nr)
			
		update KK_LM_Task set pos = @curr_pos where task_id = @task_id

		set @curr_pos = @curr_pos + 1

		delete from @task_ids_table where task_id = @task_id
		
	END
FETCH NEXT FROM task_moving INTO @task_id
CLOSE task_moving
DEALLOCATE task_moving

update KK_LM_Task set pos = pos - 1000 + @count where task_group_id = @task_group_id and pos > (@init_pos + @count)

--for checking the result 
select pos p, * from KK_LM_Task where task_group_id = @task_group_id order by pos



