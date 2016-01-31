# Asamium
SQL Anywhere domain metadata repository management

## Define Types

```sql
-- default datatype is STRING and not nulllable
meta.defineType 'inv.name';

-- with default value of 0
meta.defineType 'inv.qty', 
    @options = 'INT,0'
;

-- nullable Type with no default value
meta.defineType 'inv.flag', 
    'BOOL,,nullable'
;

-- use : to separate name and options in only one argument
meta.defineType 'inv.price:MONEY';
meta.defineType 'inv.code:,,nullable';
```

## Define Entities

```sql
meta.defineEntity 'inv.Vendor',
  @properties = 'name'
;

meta.defineEntity 'inv.Article',
  @properties = 'name;serialNumber,code;isFluid,flag;price',
  @roles = 'Vendor'
;
```

## Create Tables

```sql
meta.createTable 'inv.Vendor';
meta.createTable 'inv.Article';
```

Console output:
```sql
create table [inv].[Vendor] (
    id ID, 
    
    [name] STRING not null, 
    
    author IDREF, xid GUID, ts TS, cts CTS, 
    primary key(id), unique(xid)
)

create index [XK_inv_Vendor_ts] on [inv].[Vendor] (ts)
create index [XK_inv_Vendor_cts] on [inv].[Vendor] (cts)

create table [inv].[Article] (
    id ID, 
    
    [vendor] IDREF not null,
    [serialNumber] STRING null, 
    [isFluid] BOOL null,
    [price] MONEY not null, 
    [name] STRING not null, 
    
    author IDREF, xid GUID, ts TS, cts CTS, 
    primary key(id), unique(xid)
)

create index [XK_inv_Article_ts] on [inv].[Article] (ts)
create index [XK_inv_Article_cts] on [inv].[Article] (cts)

alter table [inv].[Article] add foreign key ([vendor]) 
    references [inv].[Vendor]
```
