-- =======================================================================================================
-- Author:		OK
-- Create date: 27.03.2018
-- Description: Script for copying tasks and their task groups between linked servers
-- =======================================================================================================
--***BeginVersion***
--_V_7.0	27.03.2018	OK	Created
--_V_7.1	04.04.2018	OK	Added parameter @save_mode to backup, data from tables KK_LM_Task and KK_LM_TaskGroup is copied to KK_LM_Task_<current_date> and KK_LM_TaskGroup_<current_date>
--***EndVersion***

declare @source_task_group_id int
declare @destin_task_group_id int
declare @destin_server_name nvarchar (100) = null
declare @source_server_name nvarchar (100) = null
declare @destin_database nvarchar (100) = null
declare @source_database nvarchar (100) = null
declare @table_name varchar (100) = null
declare @table_name_db varchar (100) = null
declare @sql nvarchar (max) 
declare @save_mode bit = 0 
declare @group_pairs_table table (pos int, source_id int, destin_id int) 
declare @gr_pos int
declare @destin_gr_id int
declare @source_gr_id int
declare @task_group_name nvarchar (60)

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------
set @destin_server_name = 'srv-devter001\sql2017'
set @destin_database = 'am_kieferngarten_ORIGINAL'

set @source_server_name = 'srv-devter001'
set @source_database = 'ok_Freiburg_30062016'

set @source_task_group_id = 8

set @save_mode = 1 
------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

--current server and database are set if it wasn't set earlier
if @source_server_name is null or len(rtrim(ltrim((@source_server_name)))) = 0
	set @source_server_name = (select @@servername)
if @destin_server_name is null or len(rtrim(ltrim((@destin_server_name)))) = 0
	set @destin_server_name = (select @@servername)
if @source_database is null or len(rtrim(ltrim((@source_database)))) = 0
	set @source_database = (select db_name())
if @destin_database is null or len(rtrim(ltrim((@destin_database)))) = 0
	set @destin_database = (select db_name())

--return, nothing to copy
--if @destin_database = @source_database and @destin_server_name = @source_server_name goto end_label

--add link between servers if it is absent
if not exists (select name from sys.servers where name = @destin_server_name)
  exec sp_addlinkedserver @destin_server_name
if not exists (select name from sys.servers where name = @source_server_name)
  exec sp_addlinkedserver @source_server_name

--------------backup block----------------------------------------------------------
set @table_name = ('KK_LM_Task_' + (select convert(varchar(10), getdate(),112)))
set @table_name_db = null
set @sql =
'set @table_name_db = (select table_name from [' + @destin_server_name + '].[' + @destin_database + '].information_schema.tables where table_type = ''base table''' +' and  table_name = ''' + @table_name +''')'

EXEC sp_executesql @sql, N'@table_name_db varchar (max) output', @table_name_db = @table_name_db output
	
if @save_mode = 1  and @table_name_db is null
	begin
		set @sql = '[' + @destin_server_name + '].[' + @destin_database + '].[dbo].[sp_executesql] N'' SELECT * INTO [dbo].' + @table_name +' from [' + @destin_server_name + '].[' + @destin_database + '].dbo.KK_LM_Task''' 
		EXEC (@sql)
		select 'Data from table KK_LM_Task is backuped to table KK_LM_Task_'+ (select convert(varchar(10), getdate(),112)) as ' '
	end

set @table_name = ('KK_LM_TaskGroup_' + (select convert(varchar(10), getdate(),112)))
set @table_name_db = null
set @sql ='set @table_name_db = (select table_name from [' + @destin_server_name + '].[' + @destin_database + '].information_schema.tables where table_type = ''base table''' +' and  table_name = ''' + @table_name +''')'

EXEC sp_executesql @sql, N'@table_name_db varchar (max) output', @table_name_db = @table_name_db output

if @save_mode = 1  and @table_name_db is null
	begin
		set @sql = '[' + @destin_server_name + '].[' + @destin_database + '].[dbo].[sp_executesql] N'' SELECT * INTO [dbo].' + @table_name +' from [' + @destin_server_name + '].[' + @destin_database + '].dbo.KK_LM_TaskGroup''' 
		exec (@sql)
		select 'Data from table KK_LM_TaskGroup is backuped to table KK_LM_TaskGroup_'+ (select convert(varchar(10), getdate(),112)) as ' '
	end
--------------end of backup block----------------------------------------------------------


--copy of parent task group
--set @sql = 
--'INSERT INTO [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_TaskGroup] ([mandant_nr], [name], [parent_id], [font], [img_name], [text_color], [gr_pos])
--SELECT [mandant_nr], [name], [parent_id], [font], [img_name], [text_color], [gr_pos]
--FROM [' + @source_server_name + '].[' + @source_database + '].[dbo].KK_LM_TaskGroup where gr_id =' + convert(varchar (10), @source_task_group_id)

declare @mandant_nr int
declare @destin_gr_pos int

set @sql =
'set @mandant_nr = (select mandant_nr from [' + @source_server_name + '].[' + @source_database + '].[dbo].[KK_LM_TaskGroup]  where gr_id = ' + convert(varchar(10), @source_task_group_id) + ')'

EXEC sp_executesql @sql, N'@mandant_nr int output', @mandant_nr = @mandant_nr output
select @sql,  @mandant_nr

set @sql =
'set @destin_gr_pos =
(select max (gr_pos) from [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_TaskGroup]  where mandant_nr = ' + convert(varchar(10), @mandant_nr) + ' and parent_id is null)+1'

EXEC sp_executesql @sql, N'@destin_gr_pos int output', @destin_gr_pos = @destin_gr_pos output
select @sql,  @destin_gr_pos

set @sql = 
'INSERT INTO [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_TaskGroup] ([mandant_nr], [name], [parent_id], [font], [img_name], [text_color], [gr_pos])
SELECT [mandant_nr], [name], [parent_id], [font], [img_name], [text_color],' + convert(varchar (10), @destin_gr_pos) + '
FROM [' + @source_server_name + '].[' + @source_database + '].[dbo].KK_LM_TaskGroup where gr_id =' + convert(varchar (10), @source_task_group_id)

EXEC (@sql)
select @sql

set @sql=
'set @task_group_name = (select name from [' + @source_server_name + '].[' + @source_database + '].[dbo].[KK_LM_TaskGroup]  where gr_id = ' + convert(varchar (10), @source_task_group_id) +')'
EXEC sp_executesql @sql, N'@task_group_name nvarchar (60) output', @task_group_name = @task_group_name output
select @sql,  @task_group_name
--defining of id of inserted group
--set @sql = 
--'SET @destin_task_group_id = (select top 1 gr_id from [' + @destin_server_name + '].[' + @destin_database + '].[dbo].KK_LM_TaskGroup order by gr_id desc)'
--EXEC sp_executesql @sql, N'@destin_task_group_id int output', @destin_task_group_id = @destin_task_group_id output

set @sql = 
'SET @destin_task_group_id = (select top 1 gr_id from [' + @destin_server_name + '].[' + @destin_database + '].[dbo].KK_LM_TaskGroup 
where gr_pos = ' + convert(varchar (10), @destin_gr_pos) + ' and mandant_nr = ' + convert(varchar (10), @mandant_nr) + ' and name = ''' + @task_group_name + '''
order by gr_id desc)'
select @sql
EXEC sp_executesql @sql, N'@destin_task_group_id int output', @destin_task_group_id = @destin_task_group_id output
	
--copy of child task groups
set @sql = 
'INSERT INTO [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_TaskGroup] ([mandant_nr], [name], [parent_id], [font], [img_name], [text_color], [gr_pos])
SELECT [mandant_nr], [name],'+ convert(varchar (10), @destin_task_group_id) + ', [font], [img_name], [text_color], [gr_pos]
FROM [' + @source_server_name + '].[' + @source_database + '].[dbo].KK_LM_TaskGroup where parent_id =' + convert(varchar (10), @source_task_group_id)

EXEC (@sql)

--defining pairs of groups to copy tasks
set @sql = 
'select  s1.gr_pos, s1.gr_id, s2.gr_id from [' + @source_server_name + '].[' + @source_database + '].[dbo]. kk_lm_taskgroup s1
left join [' + @destin_server_name + '].[' + @destin_database + '].[dbo].kk_lm_taskgroup s2 on s1.gr_pos = s2.gr_pos
where s1.parent_id = ' + convert(varchar (10), @source_task_group_id) + ' and s2.parent_id = ' + convert(varchar (10), @destin_task_group_id)

insert into @group_pairs_table
EXEC sp_executesql @sql

--copying task from child groups, one by one
set @gr_pos = 0
while @gr_pos <= (select max (pos) from @group_pairs_table)
	begin
		--selecting current pair of groups to copy tasks
		set @destin_gr_id = (select destin_id from @group_pairs_table where pos = @gr_pos)
		set @source_gr_id = (select source_id from @group_pairs_table where pos = @gr_pos)

		set @sql = 
		'INSERT INTO [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_Task] ([task_group_id],[name],[type],[period],[schedule],[time],[pc_ids],[body],[parameter1],[value1],[active],[exec_day],[exec_max_anfo],[exec_min_state],[exec_mz],[exec_time],[font],[text_color],[wait_for_exit],[workdir],[date_range],[pos],[show_message],[anfo_task],[postrun_task_id])
		SELECT ' + convert(varchar (10), @destin_gr_id) + ',[name],[type],[period],[schedule],[time],[pc_ids],[body],[parameter1],[value1],[active],[exec_day],[exec_max_anfo],[exec_min_state],[exec_mz],[exec_time],[font],[text_color],[wait_for_exit],[workdir],[date_range],[pos],[show_message],[anfo_task],[postrun_task_id]  
		FROM [' + @source_server_name + '].[' + @source_database + '].[dbo].[KK_LM_Task]
		WHERE task_group_id =' + convert(varchar (10), @source_gr_id)
		
		EXEC (@sql)

		set @gr_pos = @gr_pos + 1
	end



--log
set @sql = 
'Copying tasks from server [' + @source_server_name + '] , database [' + @source_database + '], group ' + convert(varchar (10), @source_gr_id) + ' ''' + @task_group_name + ''' to server [' + @destin_server_name + '] , database [' + @destin_database + '], group '  + convert(varchar (10), @destin_task_group_id) + ' ''' + @task_group_name + ''' is successful'
select (@sql)

--log, inserted task groups
set @sql = 
'SELECT * FROM [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_TaskGroup] 
WHERE gr_id = ' + convert(varchar (10), @destin_task_group_id) +
' OR parent_id = ' + convert(varchar (10), @destin_task_group_id) +
' ORDER BY parent_id, gr_pos'

EXEC (@sql)

--log, inserted tasks
set @sql = 
'SELECT * FROM [' + @destin_server_name + '].[' + @destin_database + '].[dbo].[KK_LM_Task] t
LEFT JOIN [' + @destin_server_name + '].[' + @destin_database + '].[dbo].KK_LM_TaskGroup gr on t.task_group_id = gr.gr_id
LEFT JOIN [' + @destin_server_name + '].[' + @destin_database + '].[dbo].KK_LM_TaskGroup par on par.gr_id = gr.parent_id
WHERE t.task_group_id = ' + convert(varchar (10), @destin_task_group_id) +
' OR gr.parent_id = ' + convert(varchar (10), @destin_task_group_id) +
' ORDER BY par.gr_pos, gr.gr_pos, t.pos'

EXEC (@sql)


end_label:
if @destin_database = @source_database and @destin_server_name = @source_server_name
	select '@destin_database is the same with @source_database, nothing is copied'
	


/*

--select * from [srv-devter001\sql2017].[am_kieferngarten_ORIGINAL].information_schema.tables

--select * from sys.servers

SELECT name FROM sys.databases order by name


---exec sp_dropserver  [srv-devter001\sql2017]


DECLARE @ScopeIdentity (ID int)
INSERT INTO @ScopeIdentity
EXEC server.master..sp_executesql N'
  INSERT INTO database.schema.table (columns) VALUES (values);
  SELECT SCOPE_IDENTITY()'
SELECT * FROM @ScopeIdentity
*/






