create or replace procedure meta.createTable(
    @ref STRING,
    @isTemporary BOOL default 0,
    @forceDrop BOOL default 0,
    @name CODE default null,
    @dom TINY default null,
    @dbspace CODE default null
) begin

    declare @sql STRING;
    declare @columns STRING;
    declare @roles STRING;
    declare @entity NAME;
    declare @commonColumns STRING;

    if @dbspace is null then
        set @dbspace = @dom;
    end if;

    select
        coalesce (
            @dom,
            regexp_substr (@ref,'.*(?=[\.].*)'),
            util.getUserOption('asamium.default.domain'),
            'meta'
        ) as dom,
        if @dom is null then isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) else @ref endif as name
    into @dom, @entity;

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

    set @commonColumns = util.getUserOption('asamium.' + @dom + '.commonColumns');

    set @commonColumns = nullIf(@commonColumns, '');

    set @columns = (
        select list(
            string(
                '[', p.name, '] ',
                t.dataType,
                if isnull (p.isNullable, t.isNullable) = 0 then
                    ' not'
                endif,
                ' null',
                if isnull(p.defaultValue,t.defaultValue) is not null then
                    ' default ''' + isnull(p.defaultValue,t.defaultValue) + ''''
                endif
            ), ', '
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
            and r.dom = @dom
    );

    set @sql = string (
        'create ',
        if @isTemporary = 1 then 'global temporary ' else '' endif,
        ' table ['+@dom+'].['+@name+'] (',
        'id ID, ',
        if @roles = '' then '' else @roles + ', ' endif,
        if @columns = '' then '' else @columns + ', ' endif,
        if @commonColumns is not null then @commonColumns + ', ' endif,
        'author IDREF, xid GUID, ts TS, cts CTS, primary key(id), unique(xid)',
        ') ',
        if @isTemporary = 1 then
            'not transactional share by all'
        else
            (select 'in [' + dbspace_name + ']' from sysfile where dbspace_name = @dbspace)
        endif
    );

    message @sql to client;
    execute immediate @sql;

    set @sql =
        'create index [XK_' + @dom + '_' + @name + '_ts]' +
        ' on [' + @dom + '].[' + @name + '] (ts)'
    ;

    message @sql to client;
    execute immediate @sql;

    set @sql =
        'create index [XK_' + @dom + '_' + @name + '_cts]' +
        ' on [' + @dom + '].[' + @name + '] (cts)'
    ;

    message @sql to client;
    execute immediate @sql;

    -- Foreign keys
    for fks as fk cursor for
        select
            actor,
            name,
            @dom as @owner,
            deleteAction,
            if not exists (
                select * from SysTable
                where creator = user_id (@dom) and table_name = r.actor
                    and (
                        (@isTemporary = 0 and table_type = 'BASE')
                        or (@isTemporary = 1 and table_type = 'GBL TEMP')
                    )
            ) then 'index' else 'fk' endif as @indexOrFk
        from meta.Role r
    where dom = @dom and entity = @entity
    do
        if @indexOrFk = 'fk' then
            set @sql = string (
                'alter table [', @owner, '].[', @name, ']',
                ' add foreign key ([', name, ']) references [', @owner, '].[', actor + ']',
                -- ' on update cascade',
                if deleteAction is not null then ' on delete ' + deleteAction endif
            );
        else
            set @sql = string (
                'create index [XK_', @dom, '_', @name, '_', name, ']',
                ' on [', @dom, '].[', @name, '] ([', name, '])'
            )
        end if;
        message @sql to client;
        execute immediate @sql;

    end for;

end;
