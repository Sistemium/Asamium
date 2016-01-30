create or replace procedure meta.defineType (
    @ref STRING,
    @properties STRING default '',
    @dom TINY default null
) begin

    declare @name MEDIUM;

    if @dom is null then
        select
            isnull (regexp_substr (@ref,'[^\.]*'), 'meta') as dom,
            isnull (regexp_substr (@ref,'(?<=^.*\.).*'), @ref) as name
        into @dom, @name
    end if;

    merge into meta.Type t using with auto name (
        select
            @dom as dom,
            @name as name,
            isnull (p.datatype,'STRING') as datatype,
            p.defaultValue,
            isnull (p.isNullable,0) as isNullable
        from dummy outer apply (
            select * from OpenString (value @properties) with (
                datatype MEDIUM,
                defaultValue STRING,
                isNullable BOOL
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
