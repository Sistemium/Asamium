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
        coalesce (@dom, regexp_substr (@ref,'.*(?=[\.].*)'), 'meta') as dom,
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
