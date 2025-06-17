# MySQL Parser Ruby Bindings

Ruby bindings for the [TiDB MySQL parser](https://github.com/pingcap/tidb/tree/master/pkg/parser), allowing you to parse MySQL queries and get back a structured AST (Abstract Syntax Tree).

## Features

- Parse MySQL SQL statements into AST
- Support for all MySQL syntax supported by TiDB parser
- Ruby-friendly AST representation
- Error handling with descriptive messages
- Support for multiple statements in a single parse call

## Installation

### Prerequisites

- Go 1.21 or later
- Ruby 2.7 or later
- FFI gem

### Build Steps

1. Clone this repository
2. Build the Go shared library:
   ```bash
   make build
   ```
3. Install Ruby dependencies:
   ```bash
   bundle install
   ```

## Usage

The API follows the same pattern as [pg_query](https://github.com/pganalyze/pg_query) for PostgreSQL.

### Basic Example

```ruby
require 'mysql_parser'

# Parse a query (returns a ParserResult object)
result = MysqlParser.parse("SELECT id, name FROM users WHERE age > 25")

puts result.class               # => MysqlParser::ParserResult
puts result.tree.first.type     # => "*ast.SelectStmt" 
puts result.tree.first.select_statement?  # => true
puts result.query               # => "SELECT id, name FROM users WHERE age > 25"
```

### Class Methods (pg_query compatible)

```ruby
# Parse and return ParserResult
result = MysqlParser.parse("SELECT * FROM users")

# Normalize query (replace constants with placeholders)
MysqlParser.normalize("SELECT * FROM users WHERE id = 123")
# => "SELECT * FROM users WHERE id = $1"

# Generate fingerprint for query similarity
MysqlParser.fingerprint("SELECT * FROM users WHERE id = 1")
# => "a1b2c3d4e5f6789a"

# Extract table names
MysqlParser.tables("SELECT * FROM users JOIN orders ON users.id = orders.user_id")
# => ["users", "orders"]

# Extract filter columns  
MysqlParser.filter_columns("SELECT * FROM users WHERE name = 'John' AND age > 25")
# => [["users", "name"], ["users", "age"]]

# Tokenize query
tokens, warnings = MysqlParser.scan("SELECT 1")
# => [{:tokens => ["SELECT", "1"]}, []]
```

### ParserResult Methods

```ruby
result = MysqlParser.parse("SELECT * FROM users WHERE name = 'John'")

# Access parsed query components
result.tree                    # => Array of AST nodes
result.query                   # => Original SQL string
result.warnings               # => Array of parsing warnings

# Analyze the query
result.normalize              # => "SELECT * FROM users WHERE name = $1"
result.fingerprint            # => "abc123def456789a"  
result.tables                 # => ["users"]
result.filter_columns         # => [["users", "name"]]
result.deparse                # => "SELECT * FROM users WHERE name = 'John'"

# Walk the AST
result.walk do |node|
  puts "Node type: #{node.type}"
end
```

### Handling Multiple Statements

```ruby
sql = "INSERT INTO users (name) VALUES ('John'); UPDATE users SET name = 'Jane' WHERE id = 1;"

result = MysqlParser.parse(sql)
result.tree.each do |stmt|
  puts "Statement type: #{stmt.type}"
  puts "Is INSERT: #{stmt.insert_statement?}"
  puts "Is UPDATE: #{stmt.update_statement?}"
end
```

### Error Handling

```ruby
begin
  result = MysqlParser.parse("INVALID SQL")
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end
```

### AST Node Methods

The `ASTNode` class provides several convenience methods:

- `statement?` - Returns true if this is a statement node
- `expression?` - Returns true if this is an expression node
- `ddl?` - Returns true if this is a DDL statement
- `dml?` - Returns true if this is a DML statement
- `select_statement?` - Returns true if this is a SELECT statement
- `insert_statement?` - Returns true if this is an INSERT statement
- `update_statement?` - Returns true if this is an UPDATE statement
- `delete_statement?` - Returns true if this is a DELETE statement
- `create_table_statement?` - Returns true if this is a CREATE TABLE statement

### Converting to JSON

```ruby
sql = "SELECT * FROM users"
result = MysqlParser.parse(sql)
json = result.first.to_json
puts JSON.pretty_generate(JSON.parse(json))
```

## Development

### Running Tests

```bash
bundle exec rspec
```

### Running Examples

```bash
ruby examples/basic_usage.rb
```

### Building the Library

The Go shared library needs to be built before using the Ruby bindings:

```bash
make build
```

This creates `libmysql_parser.so` and `libmysql_parser.h` files.

## Architecture

This project uses FFI (Foreign Function Interface) to call into a Go shared library that wraps the TiDB MySQL parser. The architecture consists of:

1. **Go Wrapper** (`parser.go`) - Exports C-compatible functions that use the TiDB parser
2. **Ruby FFI Bindings** (`lib/mysql_parser.rb`) - Ruby interface to the Go functions
3. **AST Classes** (`lib/mysql_parser/ast_node.rb`) - Ruby representation of AST nodes

## License

Apache 2.0 License (same as TiDB parser)

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for your changes
4. Make sure all tests pass
5. Submit a pull request