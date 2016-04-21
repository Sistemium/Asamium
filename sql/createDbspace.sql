create or replace procedure meta.createDbspace (
    @dom TINY default null
) begin

    declare @sql text;

    if not exists (select * from sysdbspace where dbspace_name = @dom) then
        set @sql = string (
            'create dbspace ', @dom,
            ' as @dom', '.dbs'
        );
        execute immediate with result set off @sql;
    end if

end;
