select * from KK_LM_TaskGroup where name like '%-6%' --3241

select * from KK_LM_Task where task_group_id = 3243

declare @count int
declare @task_id int = 4316
declare @task_after int = 4311
declare @task_group_id int
declare @task_after_pos int

set @task_group_id = (select task_group_id from KK_LM_Task where task_id = @task_after)
select @task_group_id

set @task_after_pos = (select pos from KK_LM_Task where task_id = @task_after)
select @task_after_pos

update KK_LM_Task set pos = pos + 1000 where task_group_id = @task_group_id and pos > @task_after_pos
update KK_LM_Task set pos = @task_after_pos + 1 where task_id = @task_id
update KK_LM_Task set pos = pos - 1000 + 1 where task_group_id = @task_group_id and pos > (@task_after_pos + 1)

select * from KK_LM_Task where task_group_id = 3243
select * from KK_LM_Task where task_group_id = 3243 order by pos



