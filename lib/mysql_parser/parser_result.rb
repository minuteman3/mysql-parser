require 'digest'

module MysqlParser
  class ParserResult
    attr_reader :tree, :query, :warnings
    
    def initialize(tree, query, warnings = [])
      @tree = tree
      @query = query  
      @warnings = warnings
    end
    
    # Parse a query into a ParserResult
    def self.parse(sql)
      result_json = MysqlParser.parse_sql(sql)
      result = JSON.parse(result_json)
      
      unless result['success']
        error_msg = result['error']
        if result['line'] && result['line'] > 0
          error_msg = "#{error_msg} (at line #{result['line']}"
          error_msg += ", column #{result['column']}" if result['column'] && result['column'] > 0
          error_msg += ")"
        end
        raise ParseError, error_msg
      end
      
      # Convert JSON AST to Ruby objects
      ast_nodes = if result['ast'].is_a?(Array)
        result['ast'].map { |node| ASTNode.from_hash(node) }
      else
        [ASTNode.from_hash(result['ast'])]
      end
      
      new(ast_nodes, sql, [])
    end
    
    # Extract table names from parsed query
    # Handles: simple tables, schema.table format, JOINs, subqueries
    # Returns unique table names without aliases
    def tables
      require 'set'
      tables = Set.new
      
      # Walk the entire AST looking for TableName nodes
      walk_tree do |node|
        # Only process TableName nodes - these contain actual table references
        if node.type.include?('TableName')
          table_name = extract_table_name(node)
          tables.add(table_name) if table_name
        end
      end
      
      tables.to_a.sort
    end
    
    # Extract columns used in filtering (WHERE clauses)
    # Returns array of [table/alias, column] pairs
    def filter_columns
      columns = []
      
      # Find all WHERE clause nodes
      walk_tree do |node|
        if node.where_clause?
          # Recursively extract all column references from the WHERE clause
          extract_columns_from_node(node, columns)
        end
      end
      
      # Return unique column references
      columns.uniq
    end
    
    # Generate a fingerprint for the query
    def fingerprint
      normalized = normalize  # Use the same normalization as the normalize method
      Digest::SHA256.hexdigest(normalized)[0, 16]
    end
    
    # Normalize the query by replacing constants with placeholders
    def normalize
      # Simple normalization - replace string literals and numbers with placeholders
      normalized = @query.dup
      param_count = 0
      
      # Replace number literals first (so numbering is consistent)
      normalized.gsub!(/\b\d+\b/) do |match|
        param_count += 1
        "$#{param_count}"
      end
      
      # Replace string literals
      normalized.gsub!(/'[^']*'/) do |match|
        param_count += 1
        "$#{param_count}"
      end
      
      normalized
    end
    
    # Convert back to SQL (if the AST supports it)
    def deparse
      # For now, return the original query
      # This would need to be implemented based on AST structure
      @query
    end
    
    # Walk through the AST
    def walk(&block)
      @tree.each { |node| walk_node(node, &block) }
    end
    
    # Walk and potentially modify the AST
    def walk!(&block)
      @tree.each { |node| walk_node!(node, &block) }
    end
    
    private
    
    def walk_tree(&block)
      @tree.each { |node| walk_node(node, &block) }
    end
    
    def walk_node(node, &block)
      yield node
      node.children.each { |child| walk_node(child, &block) }
    end
    
    def walk_node!(node, &block)
      yield node
      node.children.each { |child| walk_node!(child, &block) }
    end
    
    def extract_table_name(node)
      # Extract table name from TableName nodes
      # TableName nodes contain the actual table identifier
      return nil unless node.text
      
      text = node.text.strip
      
      # Remove backticks
      table_name = text.gsub(/`/, '')
      
      # Skip CTE references (they're not actual tables)
      # In a more complete implementation, we might want to track CTEs separately
      
      # Return the cleaned table name (preserves schema.table format)
      table_name.empty? ? nil : table_name
    end
    
    def extract_filter_columns(node)
      # Legacy method - kept for compatibility
      # Use extract_columns_from_node instead
      columns = []
      extract_columns_from_node(node, columns)
      columns
    end
    
    def extract_columns_from_node(node, columns)
      # Extract column references from any node
      if node.type.include?('ColumnName')
        # Extract table/alias and column from the text
        if node.text
          text = node.text.gsub(/`/, '')
          parts = text.split('.')
          
          if parts.length == 2
            # table.column or alias.column format
            columns << [parts[0], parts[1]]
          elsif parts.length == 1
            # just column name
            columns << [nil, parts[0]]
          end
        end
      end
      
      # Recursively process children
      node.children.each { |child| extract_columns_from_node(child, columns) }
    end
    
    def normalize_for_fingerprint
      # Create a normalized version for fingerprinting
      # Remove extra whitespace, standardize case, etc.
      @query.gsub(/\s+/, ' ').strip.downcase
    end
  end
end