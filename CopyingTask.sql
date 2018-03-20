-- =======================================================================================================
-- Author:		OK
-- Create date: 16.03.2018
-- Description: Script for copying task from the list and inserting @count times just after copied task
-- =======================================================================================================
--***BeginVersion***
--_V_7.0	16.03.2018	OK	Created
--***EndVersion***

declare @tasks_list varchar(max)								--list of task id's to copy
declare @task_ids_table table (nr int identity, task_id int)	--id's of tasks parsed from string
declare @count int												--amount of copies of every task
declare @task_group_id int										--group of task for copying
declare @init_pos int											--position of task after which should be inserted tasks from the @tasks_list
declare @task_id int											--task for copying
declare @i int													--counter				



---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------

set @tasks_list = '5623,5618'								--list of task id's to copy
set @count = 2												--amount of copies of every task
				
---------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------


--parsing task id's from the list to table task_ids_table
insert into @task_ids_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select @tasks_list), ',')

--for checking the result after 
select task_group_id gr, pos p, * from KK_LM_Task where task_group_id in (select distinct task_group_id from KK_LM_Task where task_id in (select task_id from @task_ids_table)) order by task_group_id, pos


-------------------------------------------------------------------------------------------------------------------
	
DECLARE task_copying CURSOR FOR
SELECT task_id FROM @task_ids_table

OPEN task_copying
FETCH NEXT FROM task_copying INTO @task_id
WHILE @@FETCH_STATUS=0 
    BEGIN

    set @task_group_id = (select task_group_id from KK_LM_Task where task_id = @task_id)

    set @init_pos = (select pos from KK_LM_Task where task_id = @task_id)

    UPDATE KK_LM_Task SET pos = pos + @count WHERE task_group_id = @task_group_id and pos > @init_pos

    set @i = 1

    WHILE @i <= @count
    BEGIN 

        INSERT INTO KK_LM_Task ([task_group_id],[name],[type],[period],[schedule],[time],[pc_ids],[body],[parameter1],[value1],[active],[exec_day],[exec_max_anfo],
                    [exec_min_state],[exec_mz],[exec_time],[font],[text_color],[wait_for_exit],[workdir],[date_range],[pos],[show_message],[anfo_task],[postrun_task_id])
            SELECT [task_group_id],[name],[type],[period],[schedule],[time],[pc_ids],[body],[parameter1],[value1],[active],[exec_day],[exec_max_anfo],
                    [exec_min_state],[exec_mz],[exec_time],[font],[text_color],[wait_for_exit],[workdir],[date_range], @init_pos + @i,[show_message],[anfo_task],[postrun_task_id]
            FROM KK_LM_Task WHERE task_id = @task_id

        set @i = @i + 1

    END

        FETCH NEXT FROM task_copying INTO @task_id
    END

CLOSE task_copying
DEALLOCATE task_copying
-------------------------------------------------------------------------------------------------------------------

--for checking the result after 
select task_group_id gr, pos p, * from KK_LM_Task where task_group_id in (select distinct task_group_id from KK_LM_Task where task_id in (select task_id from @task_ids_table)) order by task_group_id, pos





