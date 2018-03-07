create Domain BOOL as int
    not null
    default 0
    check (@this between 0 and 1)
;

create Domain ID as int
    not null
    default autoincrement
    check (@this > 0)
;

create Domain IDREF as int
    check (@this > 0)
;

create Domain STRONGREF as int
    not null
    check (@this > 0)
;

create Domain GUID as UniqueIdentifier
    default newid()
;

create Domain TS as timestamp
    default timestamp
;

create Domain CTS as timestamp
    default current timestamp
;

create Domain TINY as varchar (8)
;

create Domain SHORT as varchar (16)
;

create Domain MEDIUM as varchar (32)
;

create Domain CODE as varchar (64)
;

create Domain NAME as varchar (128)
    not null
;

create Domain STRING as text;

create Domain PRICE as decimal (12,2);
-- revoke connect from meta;

grant connect to meta;
grant dba to meta;

comment on user meta is 'Asamium metadata owner';


create table if not exists meta.Entity (

    dom TINY,
    name NAME,
    parent NAME null,

    unique (dom,name),
    foreign key (dom,parent) references meta.Entity (dom,name),

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id),

);

create table if not exists meta.Type (

    dom TINY,
    name MEDIUM,
    parent MEDIUM,

    unique (dom,name),
    foreign key (dom,parent) references meta.Type (dom,name),

    isNullable BOOL,
    defaultValue STRING,
    datatype MEDIUM not null,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)

);


create table if not exists meta.Property (

    dom TINY,
    entity NAME,
    name MEDIUM,
    type MEDIUM,

    unique (dom,entity,name),

    isNullable BOOL null,
    defaultValue STRING,

    foreign key (dom,entity) references meta.Entity (dom,name),
    foreign key (dom,type) references meta.Type (dom,name),

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)

);

create table if not exists meta.Role (

    dom TINY,
    entity NAME,
    name MEDIUM,
    actor NAME,

    unique (dom,entity,name),

    isNullable BOOL,
    deleteAction TINY,

    foreign key (dom,entity) references meta.Entity (dom,name),
    foreign key (dom,actor) references meta.Entity (dom,name),

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)

);
grant connect to util;
grant dba to util;

create table util.userOption(

    code varchar(128) not null,
    value long varchar not null,

    xid GUID, ts TS, cts CTS,
    unique (xid), primary key (code)
);


create or replace function util.getUserOption(
    @code CODE
) returns STRING
begin

    declare @result STRING;

    set @result = (
        select [value]
        from util.[userOption]
        where [code] = @code
    );

    return @result;

end;

create or replace procedure util.setUserOption(
    @code CODE,
    @value long varchar
)
begin

    insert into util.userOption on existing update with auto name
    select
        @code as [code],
        @value as [value]
    ;

end;

create or replace function util.firstLower (
    @string STRING
) returns STRING
begin

    declare @f char(1);

    set @f = lower(left(@string, 1));

    return @f + substring(@string, 2);

end;
create or replace procedure meta.createDbspace (
    @dom TINY default null
) begin

    declare @sql text;

    if not exists (select * from sysdbspace where dbspace_name = @dom) then
        set @sql = string (
            'create dbspace ', @dom,
            ' as ''', @dom, '.dbs'''
        );
        execute immediate with result set off @sql;
    end if

end;
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
create or replace procedure meta.defineEntity (
    @ref STRING,
    @properties STRING default '',
    @roles STRING default '',
    @dom TINY default null
) begin

    declare @entity NAME;

    select
        coalesce (
            @dom,
            regexp_substr (@ref,'.*(?=[\.].*)'),
            util.getUserOption('asamium.default.domain'),
            'meta'
        ) as dom,
        if @dom is null then isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) else @ref endif as name
    into @dom, @entity;

    message @dom, '.', @entity to client;

    merge into meta.Entity e using with auto name (
        select
            @dom as dom,
            @entity as name
    ) as m on m.dom = e.dom and m.name = e.name
    when not matched
        then insert
    when matched
        then update
    ;

    delete from meta.Property
    where dom = @dom
        and entity = @entity
    ;

    merge into meta.Property p using with auto name (
        select
            @dom as dom,
            @entity as entity,
            p.name,
            isnull (p.type,p.name) as type,
            p.defaultValue,
            case
                when p.isNullable is null then null
                when p.isNullable = '1' or p.isNullable = 'nullable' then 1
                when p.isNullable = '0' or p.isNullable = 'notnullable' then 0
            end as isNullable
        from OpenString (value @properties) with (
                name STRING,
                type STRING,
                defaultValue STRING,
                isNullable STRING
            ) option (delimited by ',' row delimited by ';') AS p
    ) as m on m.dom = p.dom and m.entity = p.entity and m.name = p.name
    when not matched
        then insert
    when matched
        then update
    ;

    delete from meta.Role
    where dom = @dom
        and entity = @entity
    ;

    merge into meta.Role r using with auto name (
        select
            @dom as dom,
            @entity as entity,
            isnull (p.name,util.firstLower(p.actor)) as name,
            p.actor,
            if isnull (p.[options],'') like '%nullable%' then 1 else 0 endif as isNullable,
            if p.[options] like '%cascade%' then 'cascade' endif as deleteAction
        from OpenString (value @roles) with (
                actor STRING,
                name STRING,
                [options] STRING
            ) option (delimited by ',' row delimited by ';') AS p
    ) as m on m.dom = r.dom and m.entity = r.entity and m.name = r.name
    when not matched
        then insert
    when matched
        then update
    ;

    select
        dom,
        name,
        parent,
        (select list (string(
                name,
                if type <> name or defaultValue is not null or isNullable = 1 then ',' + type endif,
                if defaultValue is not null or isNullable = 1 then ',' + defaultValue endif,
                if isNullable = 1 then ',1' endif
            ),';' order by id)
            from meta.Property
            where dom = e.dom
               and entity = e.name
        ) as properties,
        (select list (string(
                actor,
                if actor <> name or isNullable = 1 or deleteAction is not null then ',' + name endif,
                if isNullable = 1 then ',nullable' endif,
                if deleteAction is not null then
                     if isnull (isNullable,0) = 1 then ':' else ',' endif
                endif,
                deleteAction
            ),';' order by id)
            from meta.Role
            where dom = e.dom
               and entity = e.name
        ) as roles,
        ts, cts, id, xid
    from meta.Entity e
    where dom = @dom
        and name = @entity
    ;

end;
create or replace procedure meta.defineType (
    @ref STRING,
    @options STRING default null,
    @dom TINY default null
) begin

    declare @name MEDIUM;

    if @options is null then
        select
            regexp_substr (@ref,'^[^:]*'),
            isnull (regexp_substr (@ref,'(?<=^.*:).*'), '')
        into @ref, @options;
    end if;

    select
        coalesce (
            @dom,
            regexp_substr (@ref,'.*(?=[\.].*)'),
            util.getUserOption('asamium.default.domain'),
            'meta'
        ) as dom,
        if @dom is null then isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) else @ref endif as name
    into @dom, @name;

    merge into meta.Type t using with auto name (
        select
            @dom as dom,
            @name as name,
            isnull (p.datatype,'STRING') as datatype,
            p.defaultValue,
            if p.isNullable is not null then 1 else 0 endif as isNullable
        from dummy outer apply (
            select * from OpenString (value @options) with (
                datatype MEDIUM,
                defaultValue STRING,
                isNullable STRING
            ) option (delimited by ',' row delimited by ';') AS p
        ) as p
    ) as m on m.dom = t.dom and m.name = t.name
    when not matched
        then insert
    when matched
        then update
    ;

    select
        dom,
        name,
        datatype,
        defaultValue,
        isNullable,
        ts, cts, id, xid
    from meta.Type
    where dom = @dom
        and name = @name
    ;

end;
