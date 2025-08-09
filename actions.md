# MySQL Parser Ruby Bindings - Action Plan

This document provides a structured action plan for improving the MySQL Parser Ruby bindings based on the analysis in `future_work.md`. Each task includes context and implementation guidance for AI agents.

## Phase 1: Critical Foundation Issues (Immediate Priority)

### Task 1: Fix Memory Management in parser.go
**Priority:** Critical  
**Dependencies:** None  
**Context:** The `free_string` function doesn't properly free C strings allocated with `C.CString`, causing memory leaks.

**Implementation Notes:**
- File: `parser.go` (or similar Go source file)
- Problem: `C.CString` allocates memory that must be freed with `C.free(unsafe.Pointer(cstr))`
- Current `free_string` function is incomplete
- Need to import `unsafe` package
- Test with memory profiling tools

**Expected Changes:**
```go
//export free_string
func free_string(str *C.char) {
    C.free(unsafe.Pointer(str))
}
```

### Task 2: Update Gemspec Metadata
**Priority:** High  
**Dependencies:** None  
**Context:** Gemspec contains placeholder values that prevent proper package distribution.

**Implementation Notes:**
- File: `*.gemspec` file in project root
- Update author, email, homepage fields
- Ensure version, description, and summary are accurate
- Verify all required gemspec fields are populated
- Check for any other placeholder text

### Task 3: Set up CI/CD Pipeline
**Priority:** High  
**Dependencies:** None  
**Context:** No automated testing or multi-platform builds exist.

**Implementation Notes:**
- Create `.github/workflows/` directory
- Implement workflows for: testing, building, releasing
- Support platforms: Linux (AMD64, ARM64), macOS (Intel, Apple Silicon), Windows
- Include Ruby matrix testing (multiple Ruby versions)
- Build and test Go components
- Consider using actions like `ruby/setup-ruby`, `actions/setup-go`

## Phase 2: Core API Fixes (High Priority)

### Task 4: Add Line/Column Information to Parse Errors
**Priority:** High  
**Dependencies:** Task 1 (memory management)  
**Context:** Parse errors lack position information, making debugging difficult.

**Implementation Notes:**
- Modify Go parser to capture and return position data
- Update Ruby error handling to include line/column info
- TiDB parser likely provides position information in AST nodes
- Error format should be user-friendly: "Parse error at line 5, column 12: ..."
- Test with various malformed queries

### Task 5: Improve tables() Method
**Priority:** High  
**Dependencies:** Task 1 (memory management)  
**Context:** Current implementation doesn't properly walk AST to find all table references.

**Implementation Notes:**
- File: Ruby class with `tables()` method
- Current logic is incomplete for complex queries
- Need to handle: JOINs, subqueries, CTEs, table aliases
- Should return unique table names (use Set)
- Must handle schema.table format
- Reference implementation provided in future_work.md

**Example AST Node Types to Handle:**
- TableName nodes
- Join nodes  
- SubSelect nodes
- Update/Delete/Insert statements

### Task 6: Fix filter_columns() Method
**Priority:** High  
**Dependencies:** Task 5 (improved AST walking patterns)  
**Context:** Simplified implementation doesn't extract table names or handle complex WHERE clauses.

**Implementation Notes:**
- File: Same Ruby class as tables() method
- Should extract column references with table context
- Handle complex WHERE clauses with subqueries
- Return structured data (column -> table mapping)
- Reuse AST walking patterns from tables() improvement

## Phase 3: Parser Enhancement (Medium Priority)

### Task 7: Replace scan() Regex with Proper Lexical Analysis
**Priority:** Medium  
**Dependencies:** Tasks 1-4 (stable foundation)  
**Context:** Current scan() uses basic regex instead of TiDB parser's lexical capabilities.

**Implementation Notes:**
- File: Ruby class with `scan()` method
- TiDB parser provides proper tokenization
- Should return structured tokens with types and positions
- Replace regex-based approach with parser API calls
- Maintain backward compatibility with existing return format

### Task 8: Implement Proper deparse() Functionality
**Priority:** Medium  
**Dependencies:** Tasks 5-6 (AST walking improvements)  
**Context:** Current deparse() returns original query instead of reconstructing from AST.

**Implementation Notes:**
- Complex feature requiring AST-to-SQL generation
- Should handle formatting and normalization
- Must preserve semantic meaning while potentially improving readability
- Consider using TiDB's AST restoration capabilities
- Test round-trip parsing (parse -> deparse -> parse)

### Task 9: Expand Test Coverage for Complex SQL Constructs
**Priority:** Medium  
**Dependencies:** Tasks 1-6 (stable core functionality)  
**Context:** Missing tests for complex queries that real applications use.

**Implementation Notes:**
- File: Test files (likely in `spec/` or `test/` directory)
- Add tests for: multi-table JOINs, nested subqueries, UNION operations
- Include transaction statements, index operations, view management
- Test parser accuracy and method correctness
- Use real-world query examples

## Phase 4: Advanced Features (Medium Priority)

### Task 10: Add Support for Common Table Expressions (CTEs)
**Priority:** Medium  
**Dependencies:** Tasks 5-6 (AST handling), Task 9 (expanded tests)  
**Context:** CTEs are widely used but not properly handled.

**Implementation Notes:**
- Update AST walking to recognize CTE nodes
- Modify tables() method to include CTE table names
- Handle recursive CTEs
- Test with complex CTE queries
- Ensure proper scoping of CTE names

### Task 11: Add Support for Window Functions
**Priority:** Medium  
**Dependencies:** Similar to Task 10  
**Context:** Window functions are common in analytics queries.

**Implementation Notes:**
- Recognize window function syntax in AST
- Handle OVER clauses and partitioning
- Update column extraction to include window function columns
- Test with various window function types (ROW_NUMBER, LAG, etc.)

### Task 12: Add Edge Case Testing
**Priority:** Medium  
**Dependencies:** Task 9 (expanded test coverage)  
**Context:** Need to test parser robustness with unusual inputs.

**Implementation Notes:**
- Test large queries (>10KB)
- Unicode and special characters in identifiers
- Reserved word handling
- MySQL-specific vs standard SQL syntax
- Deeply nested expressions
- Malformed queries (should fail gracefully)

## Phase 5: Documentation & Performance (Lower Priority)

### Task 13: Add YARD Documentation
**Priority:** Lower  
**Dependencies:** Tasks 5-8 (stable API)  
**Context:** No API documentation exists for Ruby methods.

**Implementation Notes:**
- Add YARD comments to all public methods
- Include examples for complex use cases
- Document parameter types and return values
- Generate HTML documentation
- Add usage examples

### Task 14: Create Comprehensive Benchmark Suite
**Priority:** Lower  
**Dependencies:** Tasks 1-12 (stable, feature-complete codebase)  
**Context:** No performance metrics or comparisons exist.

**Implementation Notes:**
- Benchmark against other MySQL parsers
- Test various query sizes and complexities
- Memory usage profiling
- Include CI integration for performance regression detection
- Document baseline performance metrics

### Task 15: Implement AST Traversal Optimization
**Priority:** Lower  
**Dependencies:** Task 14 (benchmarking to identify bottlenecks)  
**Context:** Current recursive traversal could be optimized.

**Implementation Notes:**
- Replace recursive with iterative traversal where beneficial
- Optimize string operations and regex usage
- Consider caching frequently accessed AST patterns
- Maintain API compatibility while improving performance

## Phase 6: Advanced Security & Performance (Lowest Priority)

### Task 16: Add Query Caching Mechanism
**Priority:** Lowest  
**Dependencies:** Tasks 14-15 (performance baseline and optimizations)  
**Context:** Parsed results could be cached for repeated queries.

**Implementation Notes:**
- LRU cache for parsed ASTs
- Configurable cache size
- Thread-safety considerations
- Cache invalidation strategy
- Memory usage monitoring

### Task 17: Implement SQL Injection Detection
**Priority:** Lowest  
**Dependencies:** Stable parser (Tasks 1-12)  
**Context:** Security feature to detect potential injection patterns.

**Implementation Notes:**
- Analyze query patterns for injection indicators
- Detect dynamic SQL construction patterns
- Provide security recommendations
- False positive minimization
- Integration with security scanning tools

### Task 18: Add Resource Limits and Timeouts
**Priority:** Lowest  
**Dependencies:** All core functionality complete  
**Context:** Protection against malicious or resource-intensive queries.

**Implementation Notes:**
- Configurable parsing timeouts
- Memory usage limits
- Query complexity limits (nesting depth, etc.)
- Graceful degradation when limits exceeded
- Monitoring and alerting capabilities

## Implementation Guidelines for AI Agents

### Before Starting Any Task:
1. Read the current codebase to understand structure and conventions
2. Check existing tests to understand expected behavior
3. Identify the main entry points and key files
4. Look for existing patterns to follow

### During Implementation:
1. Follow existing code style and conventions
2. Add or update tests for any changes
3. Update documentation if APIs change
4. Consider backward compatibility
5. Test with realistic query examples

### After Implementation:
1. Run existing test suite to ensure no regressions
2. Add specific tests for the new functionality
3. Update any relevant documentation
4. Consider integration with other components

### Key Files to Examine:
- `*.gemspec` - Gem configuration
- `lib/` - Ruby implementation files  
- `*.go` - Go parser implementation
- `spec/` or `test/` - Test files
- `Makefile` - Build configuration
- `README.md` - Usage examples

### Testing Strategy:
- Unit tests for individual methods
- Integration tests for complete parsing workflows
- Performance tests for optimization tasks
- Edge case tests for robustness
- Regression tests to prevent breaking changes