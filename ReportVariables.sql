-- =======================================================================================================
-- Author:		OK
-- Create date: 23.03.2018
-- Description: Script for restoring values of report sql variables after it's renaming in LMGRT
-- =======================================================================================================
--***BeginVersion***
--_V_7.0	23.03.2018	OK	Created
--***EndVersion***

declare @orig_tmpl_id int										--id of original template
declare @emerg_tmpl_id int										--id of emergency template
declare @sv_bez varchar (200)									--field sql_variables.sv_bez
declare @sv_type int											--field sql_variables.sv_type
declare @sv_sort int											--field sql_variables.sv_sort
declare @sv_sql varchar (3000)									--field sql_variables.sv_sql
declare @sv_def_value varchar (1000)							--field sql_variables.sv_def_value
declare @sv_config_mode int										--field sql_variables.sv_config_mode
declare @orig_sv_name varchar (50)								--sv_name in original template, parsed out of @variables_list
declare @emerg_sv_name varchar (50)								--sv_name in emergency template, parsed out of @variables_list
declare @sv_pairs_table table (sv_pair nvarchar(4000))			--list of sql variables, parsed by pairs out of @variables_list
declare @sv_table table (sv nvarchar(4000), id int identity)	--sql variables parsed out of pair
declare @sv_pair nvarchar(4000)									--current pair of sql variables 
declare @variables_list nvarchar(4000) = NULL					--sql variables to copy it's parameters

---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
set @orig_tmpl_id  = 163													--set here id of original template
set @emerg_tmpl_id = 1421													--set here id of emergency template
set @variables_list = 'mz | mealtime ; datum | date ; datum_from | date'	--sql variables to copy it's parameters (sv_name in original template | sv_name in emergency template)
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------		
select 'orig_tmpl', tmpl_id, tmpl_name,tmpl_bez from templates where tmpl_id = @orig_tmpl_id
union all
select 'emerg_tmpl', tmpl_id, tmpl_name,tmpl_bez from templates where tmpl_id = @emerg_tmpl_id
order by tmpl_id

--parsing sv_names by pairs out of @variables_list
insert into @sv_pairs_table select REPLACE(REPLACE(RTRIM(LTRIM(item)), CHAR(13), ''), CHAR(10), '') from SplitStrings_CTE((select @variables_list), ';')

DECLARE sql_variables CURSOR FOR
SELECT sv_pair
FROM @sv_pairs_table

OPEN sql_variables
FETCH NEXT FROM sql_variables INTO @sv_pair
WHILE @@FETCH_STATUS=0
BEGIN
	--parsing sv_pairs one by one into @sv_table 
	delete from @sv_table 
	insert into @sv_table select RTRIM(LTRIM(item)) from SplitStrings_CTE((select top 1 * from @sv_pairs_table), '|')
	
	delete top (1) from @sv_pairs_table
		
	set @orig_sv_name  = (select top 1 sv from @sv_table order by id)
	set @emerg_sv_name  = (select top 1 sv from @sv_table where sv in (select top 2 sv from @sv_table order by id asc) order by id desc)
	
	if exists ( select * from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
		begin
			set @sv_bez = (select sv_bez from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
			set @sv_type =  (select sv_type from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
			set @sv_def_value =  (select sv_def_value from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
			set @sv_sql =  (select sv_sql from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
			set @sv_sort =   (select sv_sort from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
			set @sv_config_mode =  (select sv_config_mode from sql_variables where sv_name = @orig_sv_name and tmpl_id = @orig_tmpl_id)
 
			UPDATE sql_variables SET sv_bez=@sv_bez, sv_sql=@sv_sql, sv_type=@sv_type, sv_def_value=@sv_def_value, sv_sort=@sv_sort, sv_config_mode = @sv_config_mode WHERE sv_name= @emerg_sv_name and tmpl_id = @emerg_tmpl_id
			
		end

	FETCH NEXT FROM sql_variables INTO @sv_pair

END 
CLOSE sql_variables
DEALLOCATE sql_variables	

UPDATE sql_variables SET sv_def_value=0 WHERE sv_name in ('daily_mode', 'future_mode', 'lastAnfoRun', 'newMealStatus') and tmpl_id = @emerg_tmpl_id

select 'orig_tmpl', * from sql_variables WHERE  tmpl_id = @orig_tmpl_id 
union all
select 'emerg_tmpl', * from sql_variables WHERE  tmpl_id = @emerg_tmpl_id order by sv_sort, sv_id

/*
UPDATE sql_variables SET sv_def_value=0 WHERE sv_name in ('daily_mode', 'future_mode', 'lastAnfoRun', 'newMealStatus') and tmpl_id = @tmpl_id
UPDATE sql_variables SET sv_bez='Meal', sv_sql='select meal_id,meal_name from meals', sv_type=5, sv_def_value=1, sv_sort=3 WHERE sv_name= 'mealtime' and tmpl_id = @tmpl_id
UPDATE sql_variables SET sv_bez='Date', sv_type=4, sv_sort=2 WHERE sv_name= 'date' and tmpl_id = @tmpl_id
*/