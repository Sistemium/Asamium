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

