create or replace procedure meta.defineEntity (
    @ref STRING,
    @properties STRING default '',
    @roles STRING default '',
    @dom TINY default null
) begin

    declare @entity NAME;

    if @dom is null then
        select
            isnull (regexp_substr (@ref,'[^\.]*'), 'meta') as dom,
            isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) as name
        into @dom, @entity
    end if;

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
            isnull (p.isNullable,0) as isNullable
        from OpenString (value @properties) with (
                name STRING,
                type STRING,
                defaultValue STRING,
                isNullable BOOL
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
            isnull (p.isNullable,0) as isNullable
        from OpenString (value @roles) with (
                actor STRING,
                name STRING,
                isNullable BOOL
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
                if actor <> name or isNullable = 1 then ',' + name endif,
                if isNullable = 1 then ',1' endif
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
