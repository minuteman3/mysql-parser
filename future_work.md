# Future Work - MySQL Parser Ruby Bindings

## Overview
This document outlines identified gaps, omissions, and areas for improvement in the MySQL Parser Ruby bindings project based on a comprehensive code review.

## Critical Issues

### 1. Memory Management
- **Issue**: The `free_string` function in `parser.go` doesn't actually free C strings created with `C.CString`
- **Impact**: Potential memory leaks in long-running applications
- **Fix**: Implement proper memory deallocation using `C.free(unsafe.Pointer(cstr))`

### 2. Incomplete pg_query API Compatibility
Several methods claim pg_query compatibility but have incomplete implementations:

- **`tables()` method**: Currently has a complex extraction logic but doesn't properly walk the entire AST to find all table references
- **`filter_columns()` method**: Simplified implementation that doesn't extract table names or handle complex WHERE clauses
- **`scan()` method**: Uses basic regex instead of proper lexical analysis via the TiDB parser
- **`deparse()` method**: Returns original query instead of reconstructing SQL from AST
- **`walk!()` method**: Exists but doesn't support AST modification as the name implies

### 3. Build and Distribution
- **Missing CI/CD**: No GitHub Actions or other CI configuration for automated testing and multi-platform builds
- **Platform Support**: Makefile hardcoded for Linux/AMD64, no automated builds for macOS, Windows, or ARM architectures
- **Gemspec Metadata**: Contains placeholder values for author, email, and homepage

## Feature Gaps

### 1. Parser Capabilities Not Exposed
The TiDB parser supports many features not currently accessible:
- SQL dialect selection
- Parser flags and options
- Charset and collation handling
- Comment preservation in AST
- SQL hint extraction
- Prepared statement support

### 2. Advanced SQL Constructs
Limited or no support for:
- Common Table Expressions (CTEs)
- Window functions
- Stored procedures and functions
- Triggers and events
- Partitioning statements
- Full-text search syntax
- JSON operations

### 3. Error Handling Enhancements
- No line/column information for parse errors
- No error recovery or partial parsing
- No warnings for deprecated syntax
- No SQL validation beyond syntax checking

## Performance and Optimization

### 1. Benchmarking
- No performance benchmarks included
- No comparison with other MySQL parsers
- No memory usage profiling

### 2. Optimization Opportunities
- AST traversal could be optimized with iterative approaches
- String normalization uses multiple regex passes
- No caching of parsed results
- JSON serialization/deserialization overhead could be reduced

## Testing Gaps

### 1. Query Types
Missing test coverage for:
- Complex multi-table JOINs
- Nested subqueries
- UNION/INTERSECT/EXCEPT operations
- Recursive CTEs
- Transactions (BEGIN, COMMIT, ROLLBACK)
- Index operations (CREATE INDEX, DROP INDEX)
- Views and materialized views
- User and permission management statements

### 2. Edge Cases
- Very large queries (>10KB)
- Deeply nested expressions
- Unicode and special characters in identifiers
- Reserved word handling
- MySQL-specific syntax vs standard SQL

## Documentation Needs

### 1. API Documentation
- No YARD documentation for Ruby methods
- No inline code comments explaining complex logic
- No architecture documentation explaining Go-Ruby bridge

### 2. User Documentation
- No troubleshooting guide
- No performance tuning guide
- No migration guide from other parsers
- Limited examples for complex use cases

## Security Considerations

### 1. SQL Injection Detection
- No built-in capability to detect potential SQL injection patterns
- No query sanitization helpers
- No parameter binding validation

### 2. Resource Limits
- No limits on query size or complexity
- No timeout for parsing operations
- No protection against malicious/malformed queries causing excessive resource usage

## Recommended Priorities

### High Priority
1. Fix memory management issues
2. Implement proper `tables()` and `filter_columns()` extraction
3. Add CI/CD for multi-platform builds
4. Improve error messages with position information

### Medium Priority
1. Implement `deparse()` functionality
2. Add support for more SQL constructs (CTEs, window functions)
3. Create comprehensive benchmarks
4. Add YARD documentation

### Low Priority
1. Optimize performance for large queries
2. Add SQL validation features
3. Implement query caching
4. Create migration guides

## Implementation Suggestions

### For `tables()` Method
```ruby
def tables
  tables = Set.new
  walk_tree do |node|
    case node.type
    when /TableName/
      # Extract actual table name, handling schema.table format
    when /Join/
      # Recursively extract from join nodes
    when /SubSelect/
      # Handle subqueries
    end
  end
  tables.to_a
end
```

### For Memory Management
```go
//export parse_sql
func parse_sql(sql *C.char) *C.char {
    // ... existing code ...
    cstr := C.CString(string(jsonData))
    // Store pointer for later cleanup
    return cstr
}

//export free_string
func free_string(str *C.char) {
    C.free(unsafe.Pointer(str))
}
```

## Conclusion

While the MySQL Parser Ruby bindings provide a solid foundation for parsing MySQL queries, there are significant opportunities for improvement in functionality, performance, testing, and documentation. Addressing the high-priority items would greatly enhance the library's reliability and usability for production applications.