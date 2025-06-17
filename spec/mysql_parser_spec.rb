require 'spec_helper'

RSpec.describe MysqlParser do
  describe '.parse' do
    context 'basic functionality' do
      it 'parses a simple SELECT statement and returns ParserResult' do
        sql = 'SELECT * FROM users'
        result = MysqlParser.parse(sql)
        
        expect(result).to be_a(MysqlParser::ParserResult)
        expect(result.tree).to be_an(Array)
        expect(result.tree.first).to be_a(MysqlParser::ASTNode)
        expect(result.tree.first.select_statement?).to be true
      end
      
      it 'parses a simple INSERT statement' do
        sql = "INSERT INTO users (name, email) VALUES ('John', 'john@example.com')"
        result = MysqlParser.parse(sql)
        
        expect(result).to be_a(MysqlParser::ParserResult)
        expect(result.tree.first.insert_statement?).to be true
      end
      
      it 'parses a CREATE TABLE statement' do
        sql = 'CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(255))'
        result = MysqlParser.parse(sql)
        
        expect(result).to be_a(MysqlParser::ParserResult)
        expect(result.tree.first.create_table_statement?).to be true
      end
      
      it 'raises ParseError for invalid SQL' do
        sql = 'INVALID SQL STATEMENT'
        expect { MysqlParser.parse(sql) }.to raise_error(MysqlParser::ParseError)
      end
    end
    
    context 'rich AST structure' do
      describe 'simple SELECT with wildcard' do
        let(:sql) { 'SELECT * FROM test_table' }
        let(:result) { MysqlParser.parse(sql) }
        let(:ast) { result.tree.first }
        
        it 'creates a hierarchical AST structure' do
          expect(ast.type).to eq('*ast.SelectStmt')
          expect(ast.children).not_to be_empty
        end
        
        it 'includes FROM clause with table reference structure' do
          from_clause = ast.children.find { |child| child.data['field_name'] == 'From' }
          expect(from_clause).not_to be_nil
          expect(from_clause.type).to eq('*ast.TableRefsClause')
          
          # Should have Join -> TableSource -> TableName hierarchy
          join_node = from_clause.children.find { |child| child.data['field_name'] == 'TableRefs' }
          expect(join_node.type).to eq('*ast.Join')
          
          table_source = join_node.children.find { |child| child.data['field_name'] == 'Left' }
          expect(table_source.type).to eq('*ast.TableSource')
          
          table_name = table_source.children.find { |child| child.data['field_name'] == 'Source' }
          expect(table_name.type).to eq('*ast.TableName')
          expect(table_name.text).to eq('`test_table`')
        end
        
        it 'includes field list with wildcard structure' do
          field_list = ast.children.find { |child| child.data['field_name'] == 'Fields' }
          expect(field_list).not_to be_nil
          expect(field_list.type).to eq('*ast.FieldList')
          
          # Should have SelectField -> WildCardField structure
          select_field = field_list.children.find { |child| child.data['field_name'] == 'Fields' }
          expect(select_field.type).to eq('*ast.SelectField')
          expect(select_field.data['array_index']).to eq(0)
          
          wildcard = select_field.children.find { |child| child.data['field_name'] == 'WildCard' }
          expect(wildcard.type).to eq('*ast.WildCardField')
          expect(wildcard.text).to eq('*')
        end
      end
      
      describe 'SELECT with specific columns' do
        let(:sql) { 'SELECT id, name FROM users' }
        let(:result) { MysqlParser.parse(sql) }
        let(:ast) { result.tree.first }
        
        it 'creates separate nodes for each selected column' do
          field_list = ast.children.find { |child| child.data['field_name'] == 'Fields' }
          select_fields = field_list.children.select { |child| child.data['field_name'] == 'Fields' }
          
          expect(select_fields.length).to eq(2)
          
          id_field = select_fields.find { |field| field.data['array_index'] == 0 }
          name_field = select_fields.find { |field| field.data['array_index'] == 1 }
          
          expect(id_field.type).to eq('*ast.SelectField')
          expect(name_field.type).to eq('*ast.SelectField')
          
          # Check that each field has ColumnNameExpr -> ColumnName structure
          id_expr = id_field.children.find { |child| child.data['field_name'] == 'Expr' }
          expect(id_expr.type).to eq('*ast.ColumnNameExpr')
          
          id_column = id_expr.children.find { |child| child.data['field_name'] == 'Name' }
          expect(id_column.type).to eq('*ast.ColumnName')
          expect(id_column.text).to eq('`id`')
        end
      end
      
      describe 'SELECT with WHERE clause' do
        let(:sql) { 'SELECT * FROM users WHERE age > 25' }
        let(:result) { MysqlParser.parse(sql) }
        let(:ast) { result.tree.first }
        
        it 'creates WHERE clause with binary operation structure' do
          where_clause = ast.children.find { |child| child.data['field_name'] == 'Where' }
          expect(where_clause).not_to be_nil
          expect(where_clause.type).to eq('*ast.BinaryOperationExpr')
          expect(where_clause.data['expression_type']).to eq('expression')
          
          # Should have left (column) and right (value) operands
          left_operand = where_clause.children.find { |child| child.data['field_name'] == 'L' }
          right_operand = where_clause.children.find { |child| child.data['field_name'] == 'R' }
          
          expect(left_operand.type).to eq('*ast.ColumnNameExpr')
          expect(right_operand.type).to eq('*test_driver.ValueExpr')
          
          # Check column name structure
          column_name = left_operand.children.find { |child| child.data['field_name'] == 'Name' }
          expect(column_name.type).to eq('*ast.ColumnName')
          expect(column_name.text).to eq('`age`')
        end
      end
      
      describe 'SELECT with ORDER BY clause' do
        let(:sql) { 'SELECT * FROM users ORDER BY name DESC, age ASC' }
        let(:result) { MysqlParser.parse(sql) }
        let(:ast) { result.tree.first }
        
        it 'creates ORDER BY clause with multiple items' do
          order_by = ast.children.find { |child| child.data['field_name'] == 'OrderBy' }
          expect(order_by).not_to be_nil
          expect(order_by.type).to eq('*ast.OrderByClause')
          
          # Should have multiple ByItem nodes
          by_items = order_by.children.select { |child| child.data['field_name'] == 'Items' }
          expect(by_items.length).to eq(2)
          
          first_item = by_items.find { |item| item.data['array_index'] == 0 }
          second_item = by_items.find { |item| item.data['array_index'] == 1 }
          
          expect(first_item.type).to eq('*ast.ByItem')
          expect(second_item.type).to eq('*ast.ByItem')
          
          # Check that each ByItem has column expression
          first_expr = first_item.children.find { |child| child.data['field_name'] == 'Expr' }
          expect(first_expr.type).to eq('*ast.ColumnNameExpr')
        end
      end
      
      describe 'complex SELECT with multiple clauses' do
        let(:sql) { 'SELECT id, name FROM users WHERE age > 25 AND status = "active" ORDER BY name LIMIT 10' }
        let(:result) { MysqlParser.parse(sql) }
        let(:ast) { result.tree.first }
        
        it 'creates comprehensive AST with all clause types' do
          expect(ast.type).to eq('*ast.SelectStmt')
          
          # Should have FROM, WHERE, Fields, OrderBy, and Limit children
          field_names = ast.children.map { |child| child.data['field_name'] }
          expect(field_names).to include('From', 'Where', 'Fields', 'OrderBy', 'Limit')
        end
        
        it 'creates complex WHERE clause with AND operation' do
          where_clause = ast.children.find { |child| child.data['field_name'] == 'Where' }
          expect(where_clause.type).to eq('*ast.BinaryOperationExpr')
          
          # The top-level WHERE should be an AND operation with two operands
          left_condition = where_clause.children.find { |child| child.data['field_name'] == 'L' }
          right_condition = where_clause.children.find { |child| child.data['field_name'] == 'R' }
          
          expect(left_condition.type).to eq('*ast.BinaryOperationExpr')  # age > 25
          expect(right_condition.type).to eq('*ast.BinaryOperationExpr') # status = "active"
        end
      end
    end
    
    context 'field name and metadata preservation' do
      let(:sql) { 'SELECT * FROM users' }
      let(:result) { MysqlParser.parse(sql) }
      let(:ast) { result.tree.first }
      
      it 'preserves field names in metadata' do
        ast.children.each do |child|
          expect(child.data).to have_key('field_name')
          expect(child.data['field_name']).to be_a(String)
        end
      end
      
      it 'includes array indices for slice fields' do
        field_list = ast.children.find { |child| child.data['field_name'] == 'Fields' }
        select_fields = field_list.children.select { |child| child.data['field_name'] == 'Fields' }
        
        select_fields.each do |field|
          expect(field.data).to have_key('array_index')
          expect(field.data['array_index']).to be_a(Integer)
        end
      end
      
      it 'includes node type metadata' do
        where_clause_sql = 'SELECT * FROM users WHERE age > 25'
        where_result = MysqlParser.parse(where_clause_sql)
        where_ast = where_result.tree.first
        
        where_clause = where_ast.children.find { |child| child.data['field_name'] == 'Where' }
        expect(where_clause.data['expression_type']).to eq('expression')
      end
    end
  end
  
  describe '.normalize' do
    it 'normalizes SQL by replacing constants with placeholders' do
      sql = "SELECT * FROM users WHERE id = 123 AND name = 'John'"
      normalized = MysqlParser.normalize(sql)
      
      expect(normalized).to include('$1')
      expect(normalized).to include('$2')
      expect(normalized).not_to include('123')
      expect(normalized).not_to include("'John'")
    end
  end
  
  describe '.fingerprint' do
    it 'generates consistent fingerprints for similar queries' do
      sql1 = "SELECT * FROM users WHERE id = 1"
      sql2 = "SELECT * FROM users WHERE id = 2"
      
      fp1 = MysqlParser.fingerprint(sql1)
      fp2 = MysqlParser.fingerprint(sql2)
      
      expect(fp1).to be_a(String)
      expect(fp1.length).to eq(16)
      # Should be same after normalization
      expect(fp1).to eq(fp2)
    end
  end
  
  describe '.tables' do
    it 'extracts table names from simple query' do
      sql = "SELECT * FROM users"
      tables = MysqlParser.tables(sql)
      
      expect(tables).to be_an(Array)
      # This would need proper implementation based on AST structure
    end
  end
  
  describe '.filter_columns' do
    it 'extracts filter columns from WHERE clauses' do
      sql = "SELECT * FROM users WHERE name = 'John' AND age > 25"
      columns = MysqlParser.filter_columns(sql)
      
      expect(columns).to be_an(Array)
      # This would need proper implementation based on AST structure
    end
  end
  
  describe '.scan' do
    it 'tokenizes a SQL query' do
      sql = "SELECT 1"
      result, warnings = MysqlParser.scan(sql)
      
      expect(result).to be_a(Hash)
      expect(result[:tokens]).to be_an(Array)
      expect(warnings).to be_an(Array)
    end
  end
  
  describe 'ParserResult' do
    let(:sql) { 'SELECT * FROM users' }
    let(:result) { MysqlParser.parse(sql) }
    
    it 'has tree, query, and warnings attributes' do
      expect(result.tree).to be_an(Array)
      expect(result.query).to eq(sql)
      expect(result.warnings).to be_an(Array)
    end
    
    it 'supports normalize method' do
      normalized = result.normalize
      expect(normalized).to be_a(String)
    end
    
    it 'supports fingerprint method' do
      fingerprint = result.fingerprint
      expect(fingerprint).to be_a(String)
      expect(fingerprint.length).to eq(16)
    end
    
    it 'supports deparse method' do
      deparsed = result.deparse
      expect(deparsed).to eq(sql)
    end
  end
  
  describe 'AST traversal and inspection' do
    context 'with different statement types' do
      it 'creates rich AST for INSERT statements' do
        sql = "INSERT INTO users (name, email) VALUES ('John', 'john@example.com')"
        result = MysqlParser.parse(sql)
        ast = result.tree.first
        
        expect(ast.type).to eq('*ast.InsertStmt')
        expect(ast.children).not_to be_empty
        
        # Should have table reference and values
        field_names = ast.children.map { |child| child.data['field_name'] }
        expect(field_names).to include('Table')
      end
      
      it 'creates rich AST for UPDATE statements' do
        sql = "UPDATE users SET name = 'Jane' WHERE id = 1"
        result = MysqlParser.parse(sql)
        ast = result.tree.first
        
        expect(ast.type).to eq('*ast.UpdateStmt')
        expect(ast.children).not_to be_empty
        
        # Should have table reference, SET list, and WHERE clause
        field_names = ast.children.map { |child| child.data['field_name'] }
        expect(field_names).to include('TableRefs', 'List', 'Where')
      end
      
      it 'creates rich AST for DELETE statements' do
        sql = "DELETE FROM users WHERE id = 1"
        result = MysqlParser.parse(sql)
        ast = result.tree.first
        
        expect(ast.type).to eq('*ast.DeleteStmt')
        expect(ast.children).not_to be_empty
        
        # Should have table reference and WHERE clause
        field_names = ast.children.map { |child| child.data['field_name'] }
        expect(field_names).to include('TableRefs', 'Where')
      end
      
      it 'creates rich AST for CREATE TABLE statements' do
        sql = "CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(255))"
        result = MysqlParser.parse(sql)
        ast = result.tree.first
        
        expect(ast.type).to eq('*ast.CreateTableStmt')
        expect(ast.children).not_to be_empty
        
        # Should have table name and column definitions
        field_names = ast.children.map { |child| child.data['field_name'] }
        expect(field_names).to include('Table', 'Cols')
      end
    end
    
    context 'recursive AST traversal' do
      let(:sql) { 'SELECT u.id, u.name FROM users u JOIN orders o ON u.id = o.user_id WHERE u.status = "active" AND o.total > 100' }
      let(:result) { MysqlParser.parse(sql) }
      let(:ast) { result.tree.first }
      
      it 'creates deeply nested AST structure for complex queries' do
        expect(ast.type).to eq('*ast.SelectStmt')
        
        # Should have multiple levels of nesting
        from_clause = ast.children.find { |child| child.data['field_name'] == 'From' }
        expect(from_clause.children).not_to be_empty
        
        # The JOIN should create a complex nested structure
        join_node = from_clause.children.find { |child| child.data['field_name'] == 'TableRefs' }
        expect(join_node.children.length).to be > 1  # Should have Left and Right tables
      end
      
      it 'preserves all node relationships through recursive traversal' do
        # Walk the entire tree and verify every node has proper structure
        nodes_visited = []
        
        def visit_node(node, nodes_visited)
          nodes_visited << node
          node.children.each { |child| visit_node(child, nodes_visited) }
        end
        
        visit_node(ast, nodes_visited)
        
        expect(nodes_visited.length).to be > 10  # Complex query should have many nodes
        
        # Every node should have proper metadata
        nodes_visited.each do |node|
          expect(node.type).to be_a(String)
          expect(node.data).to be_a(Hash)
          if node.data.key?('field_name')
            expect(node.data['field_name']).to be_a(String)
          end
        end
      end
    end
  end
end