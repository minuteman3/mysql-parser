#!/usr/bin/env ruby

require_relative '../lib/mysql_parser'

# Example 1: Parse a simple SELECT statement (pg_query style interface)
puts "=== Example 1: Parse Method ==="
sql = "SELECT id, name FROM users WHERE age > 25"
begin
  result = MysqlParser.parse(sql)
  puts "Parsed successfully!"
  puts "Result type: #{result.class}"
  puts "Number of statements: #{result.tree.length}"
  puts "First statement type: #{result.tree.first.type}"
  puts "First statement text: #{result.tree.first.text}"
  puts "Is SELECT statement: #{result.tree.first.select_statement?}"
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end

# Example 1b: Direct class methods (pg_query style)
puts "\n=== Example 1b: Direct Class Methods ==="
sql = "SELECT * FROM products WHERE price > 100"
begin
  # Parse and get ParserResult
  result = MysqlParser.parse(sql)
  puts "Parse result: #{result.class}"
  
  # Normalize query
  normalized = MysqlParser.normalize(sql)
  puts "Normalized: #{normalized}"
  
  # Generate fingerprint  
  fingerprint = MysqlParser.fingerprint(sql)
  puts "Fingerprint: #{fingerprint}"
  
  # Extract tables
  tables = MysqlParser.tables(sql)
  puts "Tables: #{tables.inspect}"
  
  # Scan tokens
  tokens, warnings = MysqlParser.scan(sql)
  puts "Tokens: #{tokens[:tokens].inspect}"
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end

# Example 2: Parse a CREATE TABLE statement
puts "\n=== Example 2: CREATE TABLE Statement ==="
sql = <<~SQL
  CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
SQL

begin
  result = MysqlParser.parse(sql)
  puts "Parsed successfully!"
  puts "Statement type: #{result.tree.first.type}"
  puts "Is CREATE TABLE: #{result.tree.first.create_table_statement?}"
  puts "Is DDL: #{result.tree.first.ddl?}"
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end

# Example 3: Parse multiple statements
puts "\n=== Example 3: Multiple Statements ==="
sql = <<~SQL
  INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');
  UPDATE users SET email = 'john.doe@example.com' WHERE name = 'John Doe';
  DELETE FROM users WHERE id = 1;
SQL

begin
  result = MysqlParser.parse(sql)
  puts "Parsed successfully!"
  puts "Number of statements: #{result.tree.length}"
  result.tree.each_with_index do |stmt, i|
    puts "Statement #{i + 1}: #{stmt.type}"
    puts "  Is INSERT: #{stmt.insert_statement?}"
    puts "  Is UPDATE: #{stmt.update_statement?}"
    puts "  Is DELETE: #{stmt.delete_statement?}"
    puts "  Is DML: #{stmt.dml?}"
  end
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end

# Example 4: Handle parse errors
puts "\n=== Example 4: Parse Error Handling ==="
sql = "INVALID SQL STATEMENT"
begin
  result = MysqlParser.parse(sql)
  puts "This shouldn't print"
rescue MysqlParser::ParseError => e
  puts "Parse error caught: #{e.message}"
end

# Example 5: ParserResult methods (pg_query style)
puts "\n=== Example 5: ParserResult Methods ==="
sql = "SELECT COUNT(*) FROM products WHERE category = 'electronics'"
begin
  result = MysqlParser.parse(sql)
  
  # Use ParserResult methods
  puts "Original query: #{result.query}"
  puts "Normalized: #{result.normalize}"
  puts "Fingerprint: #{result.fingerprint}"
  puts "Deparse: #{result.deparse}"
  puts "Tables: #{result.tables.inspect}"
  puts "Filter columns: #{result.filter_columns.inspect}"
  
  # Walk the AST
  puts "\nWalking AST:"
  result.walk do |node|
    puts "  Node: #{node.type}"
  end
  
  # Convert first AST node to JSON
  json = result.tree.first.to_json
  puts "\nFirst AST node as JSON:"
  puts JSON.pretty_generate(JSON.parse(json))
rescue MysqlParser::ParseError => e
  puts "Parse error: #{e.message}"
end