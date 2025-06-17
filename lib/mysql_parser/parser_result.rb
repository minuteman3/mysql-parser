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
        raise ParseError, result['error']
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
    def tables
      tables = []
      walk_tree { |node| tables << extract_table_name(node) if node.table_reference? }
      tables.compact.uniq
    end
    
    # Extract columns used in filtering (WHERE clauses)
    def filter_columns
      columns = []
      walk_tree { |node| columns.concat(extract_filter_columns(node)) if node.where_clause? }
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
      # Extract table name from table reference nodes
      # Focus on TableName nodes which contain the actual table identifier
      return nil unless node.type.include?('TableName') && node.text
      
      text = node.text.strip
      
      # Remove index hints (FORCE INDEX, USE INDEX, IGNORE INDEX)
      # These appear after the table name and can include FOR JOIN/ORDER BY/GROUP BY
      text = text.sub(/\s+(FORCE|USE|IGNORE)\s+INDEX(\s+FOR\s+(JOIN|ORDER\s+BY|GROUP\s+BY))?\s*\([^)]+\).*$/i, '')
      
      # Remove aliases (both implicit and explicit AS)
      # TableName nodes should contain just the table identifier without aliases
      # but in some cases they might include index hints
      
      # Clean up backticks and return the table name
      # Handle schema.table format
      table_name = text.gsub(/`/, '')
      
      # Return the cleaned table name
      table_name.empty? ? nil : table_name
    end
    
    def extract_filter_columns(node)
      # Extract column references from WHERE clauses
      # This is a simplified implementation  
      columns = []
      if node.type.include?('Column') || node.type.include?('Field')
        table = nil
        column = node.text&.split('.')&.last
        columns << [table, column] if column
      end
      columns
    end
    
    def normalize_for_fingerprint
      # Create a normalized version for fingerprinting
      # Remove extra whitespace, standardize case, etc.
      @query.gsub(/\s+/, ' ').strip.downcase
    end
  end
end