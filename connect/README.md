# connect_sqlite.sh – SQLite Database Query Helper

A command-line Bash script for easily running queries and meta-commands against an SQLite database.  
Supports common queries, direct SQLite meta-commands, and helpful “describe” shortcuts for table structure and more.

## Features

- Run SQL queries directly from the command line
- Automatically adds a semicolon if missing
- Supports native SQLite meta-commands (e.g. `.tables`)
- “Describe” helpers for schema inspection (`describe .table mytable`, etc.)
- Interactive SQLite shell if no arguments are provided
- Usage/help messages

## Usage
```
./connect_sqlite.sh [SQL statement or meta-command]
```
## Examples
### 1. List all tables
```
./connect_sqlite.sh .tables
```
### 2. Run a SQL query
```
./connect_sqlite.sh SELECT * FROM driver_race_denorm WHERE driver_id = 'lewis-hamilton'
./connect_sqlite.sh SELECT COUNT(*) AS cnt FROM driver_race_denorm WHERE driver_id = 'foobar'
```
### 3. Show table columns/structure for a table
```
./connect_sqlite.sh describe .table mytable
```
### 4. Show all indexes for a table
```
./connect_sqlite.sh describe .indexes mytable
```
### 5. Show foreign keys for a table
```
./connect_sqlite.sh describe .fkeys mytable
```
### 6. Show schema version
```
./connect_sqlite.sh describe .schema_version
```
### 7. Run integrity check
```
./connect_sqlite.sh describe .integrity_check
```
### 8. Show usage/help
```
./connect_sqlite.sh -h
./connect_sqlite.sh -help
```
### 9. Enter SQLite interactive mode (no arguments)
```
./connect_sqlite.sh
```

