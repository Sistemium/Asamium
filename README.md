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
