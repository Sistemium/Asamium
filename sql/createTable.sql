create or replace procedure meta.createTable(
    @dom TINY,
    @entity NAME,
    @isTemporary BOOL default 0,
    @forceDrop BOOL default 0,
    @name CODE default null
) begin

    declare @sql text;
    declare @columns text;
    declare @roles text;

    set @name = isnull (@name,@entity);

    if exists(
        select *
        from sys.systable t join sys.sysuserperm u on t.creator = u.user_id
        where t.table_name = @name
            and u.user_name = @dom
            -- and t.table_type in ('BASE', 'GBL TEMP')
    ) and @forceDrop = 0 then
        raiserror 55555 'Table or view %1!.%2! exists', @dom, @name;
        return;
    else

        set @sql = 'drop table if exists ['+@dom+'].['+@name+']';
        message @sql to client;
        execute immediate @sql;

    end if;

    set @columns = (
        select list(
            string(
                '[', p.name, '] ',
                t.dataType,
                if isnull (p.isNullable, t.isNullable) = 0 then
                    ' not null'
                endif,
                if isnull(p.defaultValue,t.defaultValue) is not null then
                    ' default ''' + isnull(p.defaultValue,t.defaultValue) + ''''
                endif
            ), ', ' order by p.id desc
        )
        from meta.Property p
            join meta.Type t
        where p.entity = @entity and p.dom = @dom
    );

    set @roles = (
        select list(
            string(
                '[', r.name, '] ',
                'IDREF',
                if r.isNullable = 0 then
                    ' not null'
                endif
            ), ', ' order by id desc
        )
        from meta.Role r
        where r.entity = @entity
    );

    set @sql =
        'create ' + if @isTemporary = 1 then 'global temporary ' else '' endif
        + 'table ['+@dom+'].['+@name+'] ('
        + 'id ID, '
        + if @roles = '' then '' else @roles + ', ' endif
        + if @columns = '' then '' else @columns + ', ' endif
        + 'author IDREF, xid GUID, ts TS, cts CTS, primary key(id), unique(xid)'
        +') ' + if @isTemporary = 1 then 'not transactional share by all' else '' endif
    ;

    message @sql to client;
    execute immediate @sql;

    set @sql =
        'create index [XK_' + @dom + '_' + @name + '_ts]' +
        ' on [' + @dom + '].[' + @name + '] (ts)'
    ;

    message @sql to client;
    execute immediate @sql;

    -- Foreign keys
    for fks as fk cursor for
        select
            actor,
            name,
            @dom as @owner,
            deleteAction
        from meta.Role r
    where dom = @dom and entity = @entity
        and exists (
            select * from SysTable
            where creator = user_id (@dom) and table_name = r.actor
                and (
                    (@isTemporary = 0 and table_type = 'BASE')
                    or (@isTemporary = 1 and table_type = 'GBL TEMP')
                )
        )
    do

        set @sql = string (
            'alter table [', @owner, '].[', @name, ']',
            ' add foreign key ([', name, ']) references [', @owner, '].[', actor + ']',
            -- ' on update cascade',
            if deleteAction is not null then ' on delete ' + deleteAction endif
        );
        message @sql to client;
        execute immediate @sql;

    end for;

end;
