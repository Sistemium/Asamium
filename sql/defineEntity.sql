create or replace procedure meta.defineEntity (
    @ref STRING,
    @properties STRING default '',
    @roles STRING default '',
    @dom TINY default null
) begin

    declare @entity NAME;

    select
        coalesce (@dom, regexp_substr (@ref,'.*(?=[\.].*)'), 'meta') as dom,
        if @dom is null then isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) else @ref endif as name
    into @dom, @entity;

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
            p.isNullable
        from OpenString (value @properties) with (
                name STRING,
                type STRING,
                defaultValue STRING,
                isNullable int
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
