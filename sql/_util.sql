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
