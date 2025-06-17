module MysqlParser
  class ASTNode
    attr_reader :type, :text, :children, :data
    
    def initialize(type:, text: nil, children: [], data: {})
      @type = type
      @text = text
      @children = children || []
      @data = data || {}
    end
    
    def self.from_hash(hash)
      return nil if hash.nil?
      
      children = hash['children']&.map { |child| from_hash(child) } || []
      
      new(
        type: hash['type'],
        text: hash['text'],
        children: children,
        data: hash['data'] || {}
      )
    end
    
    def statement?
      data['statement_type'] == 'statement'
    end
    
    def expression?
      data['expression_type'] == 'expression'
    end
    
    def ddl?
      data['ddl_type'] == 'ddl'
    end
    
    def dml?
      data['dml_type'] == 'dml'
    end
    
    def select_statement?
      type.include?('SelectStmt')
    end
    
    def insert_statement?
      type.include?('InsertStmt')
    end
    
    def update_statement?
      type.include?('UpdateStmt')
    end
    
    def delete_statement?
      type.include?('DeleteStmt')
    end
    
    def create_table_statement?
      type.include?('CreateTableStmt')
    end
    
    def to_h
      {
        type: type,
        text: text,
        children: children.map(&:to_h),
        data: data
      }
    end
    
    def to_json(*args)
      to_h.to_json(*args)
    end
    
    def table_reference?
      type.include?('TableName') || type.include?('From') || 
      type.include?('Join') || type.include?('Table')
    end
    
    def where_clause?
      type.include?('Where') || type.include?('Condition')
    end
    
    def inspect
      "#<#{self.class.name} type=#{type.inspect} text=#{text.inspect} children=#{children.size}>"
    end
  end
end