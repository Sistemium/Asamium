# Asamium
SQL Anywhere domain metadata repository management

## Define Types

```sql
meta.defineType 'inv.name';
```

## Define Entities

```sql
meta.defineEntity 'inv.Article',
  'name;code,name,,1',
  'Article,,nullable:cascade'
;
```

## Create Tables

```sql
meta.createTable 'inv', 'Article';
```
