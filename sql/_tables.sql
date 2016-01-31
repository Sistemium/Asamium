revoke connect from meta;

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
