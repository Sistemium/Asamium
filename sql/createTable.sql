create or replace procedure meta.createTable(
    @dom TINY,
    @entity NAME,
    @isTemporary BOOL default 1,
    @forceDrop BOOL default 0,
    @tableName CODE default null
) begin

    declare @sql text;
    declare @columns text;
    declare @roles text;
    declare @computes text;

    set @tableName = isnull (@tableName,@entity)

    if exists(select *
                from sys.systable t join sys.sysuserperm u on t.creator = u.user_id
               where t.table_name = @tableName
                 and u.user_name = @owner
                 and t.table_type in ('BASE', 'GBL TEMP')) and @forseDrop = 0 then

        raiserror 55555 'Table %1!.%2! exists! use forseDrop option to regenerate', @owner, @name;
        return;
    else

        set @sql = 'drop table if exists ['+@owner+'].['+@name+']';
        execute immediate @sql;

    end if;

    set @columns = (
        select list('['+ch.remoteColumnName(p.name) + '] '+p.type, ', ')
        from
            ch.entityProperty ep
            join ch.property p
        where ep.entity = @name
    );

    set @roles = (
        select list('['+er.name+'] IDREF', ', ')
        from
            ch.entityRole er
        where er.entity = @name
    );

    set @computes = (
        select list(ec.name + ' ' + ec.type + ' compute (' + ec.expression + ')', ', ')
        from
            ch.entityCompute ec
        where ec.entity = @name
    );

    set @sql =
        'create ' + if @isTemporary = 1 then 'global temporary ' else '' endif
        + 'table ['+@owner+'].['+@name+'] ('
        + 'id ID, '
        + if @roles = '' then '' else @roles + ', ' endif
        + if @columns = '' then '' else @columns + ', ' endif
        + if @computes = '' then '' else @computes + ', ' endif
        + 'version int, author IDREF, xid GUID, ts TS, cts CTS, primary key(id), unique(xid)'
        +') ' + if @isTemporary = 1 then 'not transactional share by all' else '' endif
    ;

    message 'ch.createTable @sql = ', @sql to client;
    execute immediate @sql;

    if @isTemporary = 0 then
        set @sql = 'create index [xk_' + @owner + '_' + @name + '_ts]' +
                    ' on [' + @owner + '].[' + @name + '](ts)';

        message 'ch.createTable @sql = ', @sql to client;
        execute immediate @sql;

        if exists (select *
                     from ch.entityProperty
                    where entity = @name
                      and property = 'ts') then

            set @sql = 'create index [xk_' + @owner + '_' + @name + '_remoteTs]' +
                        ' on [' + @owner + '].[' + @name + '](remoteTs)';

            message 'ch.createTable @sql = ', @sql to client;
            execute immediate @sql;

        end if;
    end if;

    -- Foreign keys
    if @isTemporary = 0 then
        for lloop2 as ccur2 cursor for
        select distinct
                entity as c_entity,
                regexp_substr(actor,'[^.]*$') as c_actor,
                regexp_substr(actor,'^[^.]*') as c_actor_owner,
                name as c_name
            from ch.entityRole er
        where (entity = @entity
            or @entity is null
        ) and exists (
            select * from systable
            where creator=user_id(c_actor_owner) and table_name = c_actor
                and table_type = 'base'
        )
        do

            set @sql = 'alter table [' + @owner + '].[' + c_entity + ']'
                + ' add foreign key([' + c_name + ']) references [' + c_actor_owner + '].[' + c_actor + ']'
            ;
            message 'ch.createTable @sql = ', @sql to client;
            execute immediate @sql;

        end for;
    end if;

end;
