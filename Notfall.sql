-- =============================================
-- Author:		OK
-- Create date: 01.10.2017
-- Description: Script for copying tasks to Notfall block
-- =============================================
--***BeginVersion***
--_V_7.0	02.10.2017	OK	Created
--_V_7.1	15.11.2017	OK	Added some checks on correctness of input data, used scope_identity and coalesce after code review with AO
--_V_7.2	24.11.2017	OK	Added insert of emergency path to LMPara
--_V_7.3	18.12.2017	OK	Added possibility to copy not all blocks and tasks
--_V_7.4	05.01.2018	OK	Possibility to update parameters of tasks moved from separate script to this one
--_V_7.5	20.01.2018	OK	Added possibility to create PDFKiller block and task
--_V_7.6	23.02.2018	OK	Fixed absent '/' in the beginning of kk_lm_task.parameter1, changed update block for @parameter_to_change without sign '=', logic with @days_in_advance starts with 0 value
--***EndVersion***
 
declare @mandant_nr int = 3             -- tasks are copied inside one mandant
declare @source_gr_name nvarchar(60)    -- name of group from which tasks should be copied
declare @source_gr_id int				-- id is determinated by source group name
declare @source_task_ids varchar(max)   -- list of source task id's to copy
declare @source_task_ids_table table (id int) --id's of tasks for copiyng parsed from sting if @source_task_ids is not null
declare @source_block_table table (block_id int) --unique id's of source blocks calculated if @source_task_ids is not null
declare @source_block_id int  -- current block in the loop
declare @emergency_gr_font nvarchar(4000)
declare @emergency_gr_color int
declare @emergency_gr_name nvarchar(60) = 'Notfall'
declare @emergency_gr_id int
declare @emergency_gr_pos int
declare @emergency_block_name nvarchar(60)
declare @emergency_block_id int
declare @emergency_block_font nvarchar(4000)
declare @emergency_block_color int
declare @emergency_block_pos int
declare @emergency_pc_id nvarchar(400)  = 'notfall'
declare @emergency_file_template varchar(250) = '<@date@><@mealtime@><@planname@><@taskname@>' -- how emergency PDFs should be named
declare @emergency_path nvarchar(4000)  = NULL  -- path to store emergency PDFs
declare @emergency_path2 nvarchar(4000) = NULL  -- additional path to store emergency PDFs
declare @emergency_path3 nvarchar(4000) = NULL  -- additional path to store emergency PDFs
declare @block_amount int = NULL --amount of blocks in one group
declare @block_number int --counter
declare @done_source_blocks table (id int)						-- table for store source blocks which are already copied to emergency group
declare @done_emergency_tasks table (id int)					-- table for store emergency tasks which have been already created 
declare @done_emergency_groups table (id int, action_type int)  -- table for store emergency group and blocks which have been already created or will be used for inserting emergency tasks
declare @done_source_tasks table (id int)						-- table for store source tasks which are copied
declare @skipped_source_tasks table (id int)					-- table for store source tasks which are skipped because they are inactive or not REP or not automatical or are in the list of tasks which shouldn't be copied
declare @task_ids_to_skip nvarchar(4000) = NULL
declare @task_ids_to_skip_table table (id int)
declare @days_in_advance int = 0    --amount of days, tasks will be created with '#date+1', '#date+2' etc
declare @not_create_for_today int = 0    --if 1 then not create task for today (<@date@>), only for @days_in_advance
declare @day_number  int            --counter
declare @add_parameters bit = 0     --if 1 then check and add @parameters_to_add to emergency tasks if it is absent
declare @parameters_to_add nvarchar(4000) = '/daily_mode=0 /future_mode=1 /lastAnfoRun=<@Standardwerte@> /newMealStatus=<@Standardwerte@>'
declare @update_parameters bit = 0  --if 1 then update parameters of task kk_lm_task.parameter1
declare @change_time bit = 0		--if 1 then time for all tasks will be set with @tasks_interval from or to @initial_time
declare @initial_time time(0)		--time from which all tasks should be started or time of last start of tasks
declare @tasks_interval int = 5		--interval between emergency tasks
declare @reverse_time_direction bit = 0 -- if 0 then @initial_time is time of start first task else @initial_time is time of start last task
declare @time_to_set time(0) = NULL
declare @task_id   int
declare @error int = 0					--type of error
declare @create_PDFKiller bit = 0		--if 1 then insert PDF Killer task in separate block
declare @debug_mode bit = 0				--if 1 then all inserted tasks and groups will be deleted
		
declare @Parameter1 nvarchar(4000) = ''									--parameters of task after updating and concatenation
declare @Parameters table (item nvarchar(4000))							--table for parsed parameters from kk_LM_Task.parameter1
declare @parameters_list nvarchar(4000) = NULL							--list of parameters, what to change and parameter after change
declare @parameter_pairs_table table (parameter_pair nvarchar(4000))	--list of parameters, parsed by pairs
declare @parameter_to_change nvarchar(4000) = ''						--parsed out of pair
declare @parameter_after_change nvarchar(4000) = ''						--parsed out of pair
declare @parameters_table table (par nvarchar(4000), id int identity)	--parsed out of pair
declare @par nvarchar(4000) 
--
declare @intelli_date  bit = 0	-- if 1 then parameter 'date' would be updated to 'date=<@date@>' or 'date=<@date+1@>' or 'date=<@date+2@>' etc. accordingly to task name



---------------------------------------------------------------------------------------------------------------------------
---------------------------------Block for setting source and expected name for emergency group----------------------------
---------------------------------------------------------------------------------------------------------------------------

---- please use ONE parameter: set name of source group OR source task id's, @source_task_ids have bigger priority --------

set @source_gr_name = 'notfall_test'       -- 'ATS' --'Produktion'
               --OR--
set @source_task_ids = '54,30,25,31'        --'54,56,78' '54,30,25,31'     

---- general parameters --------------------------------
set @mandant_nr = 3 
set @emergency_gr_name = 'Système d''urgence'           --'Notfall'  --'Système d''urgence' 
set @emergency_pc_id = 'notfall'						--'notfall'  --'secour'
---- additional parameters --------------------------------
set @days_in_advance = 0				 --amount of days, tasks will be created with '#date+1', '#date+2' etc
set @not_create_for_today = 1			 --if 1 then not create task for today (<@date@>), only for @days_in_advance
--set @block_amount = 1					 --set amount of blocks here if you want copy not all blocks (for example, first 3: Breakfast/Lunch/Dinner) 
--set @task_ids_to_skip = '4313, 4309'	 --set here id's of tasks which shouldn't be copied, delimiter is comma sign. Use WHERE in cursor to skip tasks by filter [name like '%%']
set @emergency_file_template = '<@date@>_<@taskname@>_notfall'    --'<@date@>_<@taskname@>_notfall'   --'<@date@>_<@taskname@>_secour'
set @emergency_path = 'D:\Logimen\Emergency'					  --'D:\Logimen\Emergency'
set @emergency_path2 = NULL 
set @emergency_path3 = NULL
set @debug_mode = 1						 --if 1 then all inserted tasks and groups will be deleted
set @create_PDFKiller = 0				 --if 1 then insert PDF Killer task in separate block
			
set @add_parameters = 1                  --if 1 then check and add @parameters_to_add to emergency tasks if it is absent
---- if @add_parameters = 1 --------------------------------
	set @parameters_to_add = '/daily_mode=0 /future_mode=1 /lastAnfoRun=<@Standardwerte@> /newMealStatus=<@Standardwerte@>' 

set @change_time = 0					 --if 1 then time for all tasks will be set with @tasks_interval from or to @initial_time else time = NULL 
---- if @change_time = 1 --------------------------------
	set @initial_time = '03:59'			 --time from which all tasks should be started or time of last start of tasks
	set @tasks_interval  = 4			 --interval between emergency tasks
	set @reverse_time_direction = 0      --if 0 then @initial_time is time of start first task else @initial_time is time of start last task

set @update_parameters = 1 
---- if @@update_parameters = 1 --------------------------------

	--set 'parameter to change | parameter after change', use ; as separator between pairs
	--if parameter to change is like 'mz' and do not have definite value, like 'mz=3' etc., will be changed all items like 'mz%' 
	--if parameter to change has definite value like 'mz=3' etc., will be changed only items with this value mz=3
	--in parameter after change type only name to change parameter name, or name = value to change both
	set @parameters_list = 'datum_from|date; datum|date; mz=|mealtime; show=1|show=0; daily_mode|daily_mode=0; future_mode|future_mode=1'

	set @intelli_date = 1		-- if 1 then parameter 'date' would be updated to 'date=<@date@>' or 'date=<@date+1@>' or 'date=<@date+2@>' etc. accordingly to task name

---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------



------------------------ INSERT -------------------------------------------------------------------------------------------

--parsing task id's to be skipped from the list to table @task_ids_to_skip_table
insert into @task_ids_to_skip_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select @task_ids_to_skip), ',')

IF @source_task_ids = '' set @source_task_ids = null
IF @source_task_ids is not null 
	BEGIN
		--parsing task id's from the list to table source_task_ids_table
		insert into @source_task_ids_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select @source_task_ids), ',')
		
		insert into @source_block_table select distinct task_group_id from kk_lm_task where task_id in (select id from @source_task_ids_table)

		if (select count (distinct parent_id) from KK_LM_TaskGroup where gr_id in (select block_id from @source_block_table)) > 1 
			begin
				select ('Source tasks should be from the same source group, check @source_task_ids = ' + @source_task_ids) as Error
				set @error=1 
				GOTO end_label
			end
		else 
			if (select count (distinct parent_id) from KK_LM_TaskGroup where gr_id in (select block_id from @source_block_table)) = 0 
				begin
					select ('There are no source tasks with such ids, check @source_task_ids = ' + @source_task_ids) as Error
					set @error=1 
					GOTO end_label
				end
			else
				set @source_gr_id = (select top 1 parent_id from KK_LM_TaskGroup where gr_id in (select block_id from @source_block_table))
	END
ELSE
	BEGIN
		if (select count (gr_id) from KK_LM_TaskGroup where name=@source_gr_name and mandant_nr=@mandant_nr) > 1 
			Begin
				select 'There are several source groups with the same name ''' +@source_gr_name+ ''' in mandant ''' + (select RTRIM (mand_bez) from wawi_mandant where mand_nr =@mandant_nr) +'''' as Error
				set @error=1 
				GOTO end_label
			end
		else
			if (select count (gr_id) from KK_LM_TaskGroup where name=@source_gr_name and mandant_nr=@mandant_nr) = 0 
				begin
					select 'There are no source group with such name ''' +@source_gr_name+ ''' in mandant ''' + (select RTRIM (mand_bez) from wawi_mandant where mand_nr =@mandant_nr) +'''' as Error
					set @error=1 
					GOTO end_label
				end
			else
				set @source_gr_id =(select gr_id from KK_LM_TaskGroup where name=@source_gr_name and mandant_nr=@mandant_nr)
	END


set @emergency_gr_font = (select font from KK_LM_TaskGroup where gr_id=@source_gr_id)
set @emergency_gr_color = (select text_color from KK_LM_TaskGroup where gr_id=@source_gr_id)
set @emergency_gr_pos = (select max (gr_pos) from KK_LM_TaskGroup where mandant_nr=@mandant_nr and parent_id is null)+1

--insert emergency group
if not exists (select * from KK_LM_TaskGroup where mandant_nr=@mandant_nr and name = @emergency_gr_name and parent_id is null)
	begin
		INSERT INTO KK_LM_TaskGroup (mandant_nr, name, parent_id, font, img_name, text_color, gr_pos)
		VALUES (@mandant_nr, @emergency_gr_name, NULL, @emergency_gr_font, 'i_5_1' , @emergency_gr_color, @emergency_gr_pos)
		
		set @emergency_gr_id =  SCOPE_IDENTITY()
		insert into @done_emergency_groups (id, action_type) select @emergency_gr_id, 1
	end
else
	begin
		set @emergency_gr_id = (select top 1 gr_id from KK_LM_TaskGroup where mandant_nr=@mandant_nr and name = @emergency_gr_name and parent_id is null order by gr_pos desc)
		select 'Group ''' + @emergency_gr_name + ''' exists already, blocks will be inserted in existing group' as Notice
		insert into @done_emergency_groups (id, action_type) select @emergency_gr_id, 2

	end

--calculating of emergency blocks amount inside this group, in case if amount is not set manually
if @source_task_ids is null
	begin
		if @block_amount is null or @block_amount=''
			set @block_amount = (select count (gr_id) from KK_LM_TaskGroup where parent_id=@source_gr_id) -- all blocks from this group
		else 
			if @block_amount > (select count (gr_id) from KK_LM_TaskGroup where parent_id=@source_gr_id)
				begin
					select 'Amount of blocks in group ''' + @emergency_gr_name + ''' is less then it is set in variable @block_amount' as Notice
					set @block_amount = (select count (gr_id) from KK_LM_TaskGroup where parent_id=@source_gr_id)
				end
	end
else
	set @block_amount = (select count (gr_id) from KK_LM_TaskGroup where parent_id=@source_gr_id and gr_id in (select block_id from @source_block_table)) --***-- only blocks from this group
	

--loop for inserting emergency blocks
set @block_number=1
WHILE @block_number<=@block_amount 
BEGIN 
	if @source_task_ids is null 
		set @source_block_id = (select top 1 gr_id from KK_LM_TaskGroup where parent_id=@source_gr_id and gr_id not in (select id from @done_source_blocks) order by gr_pos) 
	else		
		set @source_block_id = (select top 1 gr_id from KK_LM_TaskGroup where parent_id=@source_gr_id and gr_id not in (select id from @done_source_blocks) and gr_id in (select block_id from @source_block_table) order by gr_pos) 
		
	set @emergency_block_name = (select name from KK_LM_TaskGroup where gr_id=@source_block_id)
	set @emergency_block_font = (select font from KK_LM_TaskGroup where gr_id=@source_block_id)
	set @emergency_block_color = (select text_color from KK_LM_TaskGroup where gr_id=@source_block_id)
	set @emergency_block_pos = (coalesce((select max (gr_pos) from KK_LM_TaskGroup where parent_id=@emergency_gr_id),-1)+1)
		
		
	
	if not exists (select * from KK_LM_TaskGroup where name = @emergency_block_name and parent_id = @emergency_gr_id) --inserting of emergency block if not exists
		begin
			INSERT INTO KK_LM_TaskGroup (mandant_nr, name, parent_id, font, img_name, text_color, gr_pos)
			VALUES (@mandant_nr, @emergency_block_name, @emergency_gr_id, @emergency_block_font, '' , @emergency_block_color, @emergency_block_pos)
			
			set @emergency_block_id = SCOPE_IDENTITY()
			insert into @done_emergency_groups (id, action_type) select @emergency_block_id, 1
		end	
	else --use existing emergency block 
		begin
			set @emergency_block_id = (select gr_id from KK_LM_TaskGroup where name = @emergency_block_name and parent_id = @emergency_gr_id)
			select 'Block ''' + @emergency_block_name + ''' exists already, tasks will be inserted in existing block' as Notice
			insert into @done_emergency_groups (id, action_type) select @emergency_block_id, 2
		end
	
	-- add path to notfall folder and template name	if not exists
	if not exists (select * from LMPara where gruppe = @emergency_block_id and schluessel = 'emergency_file_template')
		begin
			SET  @emergency_path = (select CASE WHEN RIGHT(RTRIM(@emergency_path),1) = '\' THEN  RTRIM(@emergency_path) ELSE RTRIM(@emergency_path) + '\' END)
			SET  @emergency_path2 = (select CASE WHEN RIGHT(RTRIM(@emergency_path2),1) = '\' THEN  RTRIM(@emergency_path2) ELSE RTRIM(@emergency_path2) + '\' END)
			SET  @emergency_path3 = (select CASE WHEN RIGHT(RTRIM(@emergency_path3),1) = '\' THEN  RTRIM(@emergency_path3) ELSE RTRIM(@emergency_path3) + '\' END)

			INSERT INTO LMPara (mandant, gruppe, schluessel, Wert, application) VALUES (0,@emergency_block_id, 'emergency_file_template', @emergency_file_template, 'ATS')
			INSERT INTO LMPara (mandant, gruppe, schluessel, Wert, application) VALUES (0,@emergency_block_id, 'emergency_path', LEFT(@emergency_path, LEN(@emergency_path) - CHARINDEX('\', REVERSE(@emergency_path))) + '\' + CONVERT(nvarchar(2), @block_number) + ' ' + @emergency_block_name, 'ATS')
			IF @emergency_path2 is not null and @emergency_path2 <> '\'
				INSERT INTO LMPara (mandant, gruppe, schluessel, Wert, application) VALUES (0,@emergency_block_id, 'emergency_path2', LEFT(@emergency_path2, LEN(@emergency_path2) - CHARINDEX('\', REVERSE(@emergency_path2))) + '\' + CONVERT(nvarchar(2), @block_number) + ' ' + @emergency_block_name, 'ATS')
			IF @emergency_path3 is not null and @emergency_path3 <> '\'
				INSERT INTO LMPara (mandant, gruppe, schluessel, Wert, application) VALUES (0,@emergency_block_id, 'emergency_path3', LEFT(@emergency_path3, LEN(@emergency_path3) - CHARINDEX('\', REVERSE(@emergency_path3))) + '\' + CONVERT(nvarchar(2), @block_number) + ' ' + @emergency_block_name, 'ATS')
		end
	
	--cursor for inserting tasks in one block
	DECLARE @cTask_id             int,
			@cTask_group_id       int,
			@cName                nvarchar(60),
			@cType                nvarchar(60),
			@cPeriod              nvarchar(60),
			@cSchedule            nvarchar(60),
			@cTime                nvarchar(60),
			@cPc_ids              nvarchar(400),
			@cBody                nvarchar(4000),
			@cParameter1          nvarchar(4000),
			@cValue1              nvarchar(4000),
			@cActive              int,
			@cFont                nvarchar(4000),
			@cText_color          int,
			@cWorkdir             nvarchar(4000),
			@cPos                 int,
			@cShow_message        int
			


	set @cTask_id = null

	if @source_task_ids is null
        DECLARE task_insert CURSOR FOR
        SELECT task_id, task_group_id, name, [type], period, schedule, [time], pc_ids, body, parameter1, value1, active, font, text_color, workdir, pos, show_message
        FROM KK_LM_Task
        WHERE task_group_id=@source_block_id and active=1 and [type]='REP' and (period='D' or period='H') --only active daily or manual tasks, type report
        and task_id not in (select * from @task_ids_to_skip_table)
        --and name not like '%band%'
        ORDER BY pos
	else
		DECLARE task_insert CURSOR FOR
		SELECT task_id, task_group_id, name, [type], period, schedule, [time], pc_ids, body, parameter1, value1, active, font, text_color, workdir, pos, show_message
		FROM KK_LM_Task
		WHERE (task_group_id=@source_block_id and task_id in (select id from @source_task_ids_table))  --only tasks which there are in the list 
		ORDER BY pos
	
	OPEN task_insert
	FETCH NEXT FROM task_insert INTO @cTask_id, @cTask_group_id, @cName, @cType, @cPeriod, @cSchedule, @cTime, @cPc_ids, @cBody, @cParameter1, @cValue1, @cActive, @cFont, @cText_color, @cWorkdir, @cPos, @cShow_message 
	WHILE @@FETCH_STATUS=0
	BEGIN
		if @not_create_for_today = 1 
			set @day_number = 1
		else set @day_number = 0

		WHILE @day_number <= @days_in_advance
		BEGIN 
			INSERT INTO kk_lm_task
            (task_group_id,
             name,
             [type],
             period,
             schedule,
             pc_ids,
             body,
             parameter1,
             value1,
             active,
             font,
             text_color,
             workdir,
             pos,
             show_message)
			VALUES      
			(@emergency_block_id,
            (case
				when @day_number = 0 then @cName  
				else (@cName + ' #date+' + CONVERT(nvarchar(60), @day_number)) 
			 end),
             @cType,
             'D',
             @cSchedule,
             @emergency_pc_id,
             @cBody,
             @cParameter1,
             @cValue1,
             @cActive,
             @cFont,
             @cText_color,
             @cWorkdir,
             coalesce((select max (pos)+1 from KK_LM_Task where task_group_id=@emergency_block_id),0),
             0) 
			 
			insert into @done_emergency_tasks select SCOPE_IDENTITY()
			insert into @done_source_tasks (id) select @cTask_id
						
			set @day_number=@day_number + 1
		END
		FETCH NEXT FROM task_insert INTO @cTask_id, @cTask_group_id, @cName, @cType, @cPeriod, @cSchedule, @cTime, @cPc_ids, @cBody, @cParameter1, @cValue1, @cActive, @cFont, @cText_color, @cWorkdir, @cPos, @cShow_message 
	END -- end loop for inserting tasks in one block
	CLOSE task_insert
	DEALLOCATE task_insert

	if @source_task_ids is null
		insert into @skipped_source_tasks (id) select task_id from KK_LM_Task where task_group_id=@source_block_id and task_id not in (select * from @done_source_tasks) --all tasks which not in cursor

	insert into @done_source_blocks (id) select @source_block_id

	if (select count (*)  from KK_LM_Task where task_group_id = @emergency_block_id and task_id in (select * from @done_emergency_tasks)) = 0
	select 'No tasks were inserted in block ''' + @emergency_block_name + ''''  as 'Warning'

	set @block_number=@block_number+1

END -- end loop for inserting emergency blocks

if @create_PDFKiller = 1
	begin
		if not exists (select * from KK_LM_TaskGroup where name = 'PDF Killer' and parent_id = @emergency_gr_id) --inserting of PDF Killer if not exists
				begin
					INSERT INTO KK_LM_TaskGroup (mandant_nr, name, parent_id, font, img_name, text_color, gr_pos)
					VALUES (@mandant_nr, 'PDF Killer', @emergency_gr_id, 'Arial; 12pt', '' , '-16777216', (coalesce((select max (gr_pos) from KK_LM_TaskGroup where parent_id=@emergency_gr_id),-1)+1))
			
					set @emergency_block_id = SCOPE_IDENTITY()
					insert into @done_emergency_groups (id, action_type) select @emergency_block_id, 1
		
					INSERT INTO kk_lm_task (task_group_id,
								 name,
								 [type],
								 period,
								 schedule,
								 [time],
								 pc_ids,
								 body,
								 parameter1,
								 active,
								 font,
								 text_color,
								 pos,
								 show_message)
								VALUES      
								(@emergency_block_id,
								'PDF Killer',
								 'EXE',
								 'D',
								 '11111111',
								 '12:00',
								 @emergency_pc_id,
								 'set path to PDFKiller.exe here',
								 'date=<@date-7@>' + ' path="' + @emergency_path + '"',
								 1,
								 'Microsoft Sans Serif; 10pt',
								 '1',
								 0,
								 0) 

					insert into @done_emergency_tasks select SCOPE_IDENTITY()
			
				end
	end

if (select count(*) from @done_emergency_tasks) = 0 
	begin
		set @error = 2 
		goto end_label
	end

------------------------ UPDATE --------------------------------------------------------------------------------
IF @update_parameters = 1 or @change_time = 1 or @add_parameters = 1
	BEGIN
		if @change_time = 1 and @reverse_time_direction = 0  -- the difference in cursors is only sequence of tasks
			DECLARE task_update CURSOR FOR 
			SELECT task_id, task_group_id, name, [type], period, schedule, [time], pc_ids, body, parameter1, value1, active, font, text_color, workdir, pos, show_message
			FROM KK_LM_Task
			WHERE task_id in (select * from @done_emergency_tasks) and name != 'PDF Killer'
			ORDER BY task_id 
		else
			DECLARE task_update CURSOR FOR
			SELECT task_id, task_group_id, name, [type], period, schedule, [time], pc_ids, body, parameter1, value1, active, font, text_color, workdir, pos, show_message
			FROM KK_LM_Task
			WHERE task_id in (select * from @done_emergency_tasks) and name != 'PDF Killer'
			ORDER BY task_id desc
	

 

		OPEN task_update
		FETCH NEXT FROM task_update INTO @cTask_id, @cTask_group_id, @cName, @cType, @cPeriod, @cSchedule, @cTime, @cPc_ids, @cBody, @cParameter1, @cValue1, @cActive, @cFont, @cText_color, @cWorkdir, @cPos, @cShow_message
		WHILE @@FETCH_STATUS=0
		BEGIN
			if @change_time = 1
				BEGIN 
					if @time_to_set is null 
						set @time_to_set = @initial_time
					UPDATE KK_LM_Task set time = convert(VARCHAR(5), @time_to_set) where task_id = @cTask_id
					set @time_to_set = (case 
											when @reverse_time_direction = 0 then DATEADD(MINUTE, @tasks_interval, @time_to_set)  
											else DATEADD(MINUTE, -@tasks_interval, @time_to_set)
										end) 
				END

			if @add_parameters = 1
				UPDATE KK_LM_Task set parameter1=parameter1 + ' ' + @parameters_to_add where type='REP' and parameter1 not like '%/daily_mode=%' and task_id = @cTask_id 
			
			
			if @update_parameters = 1
				BEGIN
					--parsing KK_LM_Task.parameter1 to temporary table
					delete from @Parameters 
					insert into @Parameters select RTRIM(LTRIM(item)) from SplitStrings_CTE((select parameter1 from KK_LM_Task where task_id=@cTask_id), '/')

					--parsing @parameters_list by pairs
					insert into @parameter_pairs_table select REPLACE(REPLACE(RTRIM(LTRIM(item)), CHAR(13), ''), CHAR(10), '') from SplitStrings_CTE((select @parameters_list), ';')
					--select * from @parameter_pairs_table

					DECLARE parameter CURSOR FOR
					SELECT parameter_pair
					FROM @parameter_pairs_table
	
					OPEN parameter
					FETCH NEXT FROM parameter INTO @par
					WHILE @@FETCH_STATUS=0
					BEGIN
						--parsing parameter_pairs one by one into @parameters_table 
						delete from @parameters_table 
						insert into @parameters_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select top 1 * from @parameter_pairs_table), '|')
						--select * from @parameters_table 
						delete top (1) from @parameter_pairs_table
		
						set @parameter_to_change  = (select top 1 par from @parameters_table order by id)
						set @parameter_after_change  = (select top 1 par from @parameters_table where par in (select top 2 par from @parameters_table order by id asc) order by id desc)
					
						--searching by temporary table and replacing to new value
						IF LEN(RIGHT(@parameter_to_change, LEN(@parameter_to_change)-CHARINDEX('=', @parameter_to_change)))= 0  
							--@parameter_to_change doesn't have definite value after '=', will be changed all items with value like @parameter_to_change  +'%'
							begin 
								if LEN(RIGHT(@parameter_after_change, LEN(@parameter_after_change)-CHARINDEX('=', @parameter_after_change)))= 0
									--@parameter_after_change has '=' sign but doesn't have definite value after
									update @Parameters set item=LEFT(@parameter_after_change, CHARINDEX('=', @parameter_after_change) - 1)+(RIGHT (item,LEN(item)+2-CHARINDEX('=', item)))  where item  like @parameter_to_change +'%'
								else 
									if (select CHARINDEX('=',@parameter_after_change)) = 0
										--@parameter_after_change doesn't have definite value and '=' sign
										update @Parameters set item=@parameter_after_change+(RIGHT (item,LEN(item)+1-CHARINDEX('=', item)))  where item  like @parameter_to_change +'%'
								else 
									--@parameter_after_change has definite value
									update @Parameters set item=@parameter_after_change  where item like @parameter_to_change +'%'
							end
						ELSE
							IF (select CHARINDEX('=',@parameter_to_change)) = 0
								--@parameter_to_change doesn't have sign '=' at all, will be changed all items with value like @parameter_to_change  +'=%'
								begin 
									if LEN(RIGHT(@parameter_after_change, LEN(@parameter_after_change)-CHARINDEX('=', @parameter_after_change)))= 0
										--@parameter_after_change has '=' sign but doesn't have definite value after
										update @Parameters set item=LEFT(@parameter_after_change, CHARINDEX('=', @parameter_after_change) - 1)+(RIGHT (item,LEN(item)+2-CHARINDEX('=', item)))  where item  like @parameter_to_change +'=%'
									else 
										if (select CHARINDEX('=',@parameter_after_change)) = 0
											--@parameter_after_change doesn't have definite value and '=' sign
											update @Parameters set item=@parameter_after_change+(RIGHT (item,LEN(item)+1-CHARINDEX('=', item)))  where item  like @parameter_to_change +'=%'
									else 
										--@parameter_after_change has definite value
										update @Parameters set item=@parameter_after_change  where item like @parameter_to_change +'=%'
								end
						ELSE  
							-- will be changed only items with this definite value @parameter_to_change
							begin
								if LEN(RIGHT(@parameter_after_change, LEN(@parameter_after_change)-CHARINDEX('=', @parameter_after_change)))= 0
									--@parameter_after_change has '=' sign but doesn't have definite value after
									update @Parameters set item=LEFT(@parameter_after_change, CHARINDEX('=', @parameter_after_change) - 1)+(RIGHT (item,LEN(item)+2-CHARINDEX('=', item)))  where item = @parameter_to_change
								else 
									if (select CHARINDEX('=',@parameter_after_change)) = 0
										--@parameter_after_change doesn't have definite value and '=' sign
										update @Parameters set item=@parameter_after_change+(RIGHT (item,LEN(item)+2-CHARINDEX('=', item)))  where item = @parameter_to_change
								else
									--@parameter_after_change has definite value
									update @Parameters set item=@parameter_after_change where item = @parameter_to_change 
							end

							
					FETCH NEXT FROM parameter INTO @par

					END 
					CLOSE parameter
					DEALLOCATE parameter	
				
					if @intelli_date = 1  and @cName != 'PDF Killer'
						begin
							if @cName not like '%#date+%'
								update @Parameters set item='date=<@date@>' where item like 'date=%' 
							else
								update @Parameters set item='date=<@date+' + CONVERT(char(1), RIGHT(RTRIM(@cName),1)) + '@>' where item like 'date=%' 
						end
		
					--concatenation again from @Parameters table to string and then into KK_LM_Task.Parameter1
					set @Parameter1 = ''
					select @Parameter1 = COALESCE(@Parameter1 + ' /', '') + item FROM @Parameters
					UPDATE KK_LM_Task set parameter1 = @Parameter1 where task_id=@cTask_id
	
				END

			

		FETCH NEXT FROM task_update INTO @cTask_id, @cTask_group_id, @cName, @cType, @cPeriod, @cSchedule, @cTime, @cPc_ids, @cBody, @cParameter1, @cValue1, @cActive, @cFont, @cText_color, @cWorkdir, @cPos, @cShow_message
		END -- end loop for updating tasks 
		CLOSE task_update
		DEALLOCATE task_update

	END


------------------------- END_LABEL ---------------------------------------------------------------------------

end_label:
if @error = 1
	select 'There is an error, no groups and tasks were created'  as Result
else 
	if @error = 2 
	begin 
		if (select count (*) from @skipped_source_tasks) > 0
			select 'There is an error, all tasks were skipped'  as Result
		else (select 'There is an error, no tasks for copying in selected source group ''' + @source_gr_name + '''' as Result)
	end
else	
	select 'Emergency tasks are created successfully'  as Result

 
------------------------- LOG ----------------------------------------------------------------------------------

--select of emergency group and blocks which were created or which contain inserted emergency tasks
if (select count (id) from @done_emergency_groups) > 0
	select 'inserted emergency group'  as ' ', * from KK_LM_TaskGroup where gr_id in (select id from  @done_emergency_groups where action_type=1)  and  parent_id is null
	union all
	select 'inserted emergency block'  as ' ', * from KK_LM_TaskGroup where  gr_id in (select id from  @done_emergency_groups where action_type=1) and parent_id is not null 
	union all
	select 'used emergency group'  as ' ', * from KK_LM_TaskGroup where gr_id in (select id from  @done_emergency_groups where action_type=2) 
	order by gr_id

--select of inserted emergency tasks
if (select count (*) from @done_emergency_tasks) > 0
	select 'inserted emergency task'  as ' ', * from KK_LM_Task where task_id in (select * from @done_emergency_tasks)
else if @error = 2 select 'No inserted emergency tasks' as 'Error'

--select of skipped source tasks
if (select count (*) from @skipped_source_tasks) > 0
	select 'skipped source task'  as ' ', * from KK_LM_Task where task_id in (select * from @skipped_source_tasks) 
else if @error != NULL select 'No skipped source tasks' as ' '



------------------------- DEBUG --------------------------------------------------------------------------------

if @debug_mode = 1 
	begin
		--delete all tasks and groups which were inserted 
		delete from KK_LM_Task where task_id in (select * from @done_emergency_tasks)
		delete from KK_LM_TaskGroup where gr_id in (select id from @done_emergency_groups where action_type=1)

		--delete all records about emergence path and template name for groups which were inserted 
		delete from LMPara where gruppe in (select id from @done_emergency_groups where action_type=1) and application = 'ATS'  

		if @error != 1
		select '@debug_mode = 1, all inserted data is deleted' as Warning  
	end

--delete from KK_LM_Task where task_id >= 
--delete from KK_LM_TaskGroup where gr_id >= 



