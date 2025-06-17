require 'ffi'
require 'json'
require 'digest'
require 'rbconfig'

module MysqlParser
  extend FFI::Library
  
  # Load the shared library - simplified for platform-specific gems
  def self.load_library
    # For platform-specific gems, the binary is in the root
    root_path = File.expand_path('../libmysql_parser.so', __dir__)
    
    if File.exist?(root_path)
      ffi_lib root_path
    else
      raise "Binary not found. Please install the correct platform-specific gem or build locally with 'make build'"
    end
  end
  
  load_library
  
  # Define C functions
  attach_function :parse_sql, [:string], :string
  attach_function :free_string, [:string], :void
  
  class ParseError < StandardError; end
  
  # Parse a SQL string and return ParserResult (pg_query compatible interface)
  def self.parse(sql)
    ParserResult.parse(sql)
  end
  
  # Normalize a SQL string by replacing constants with placeholders
  def self.normalize(sql)
    parse(sql).normalize
  end
  
  # Generate a fingerprint for a SQL query
  def self.fingerprint(sql)
    parse(sql).fingerprint
  end
  
  # Extract table names from a SQL query
  def self.tables(sql)
    parse(sql).tables
  end
  
  # Extract filter columns from a SQL query
  def self.filter_columns(sql)
    parse(sql).filter_columns
  end
  
  # Scan/tokenize a SQL query (basic implementation)
  def self.scan(sql)
    # For now, return a simple token-like structure
    # This would need a proper lexer implementation
    tokens = sql.scan(/\w+|\d+|'[^']*'|[^\w\s]/)
    [{ tokens: tokens }, []]
  end
end

require_relative 'mysql_parser/ast_node'
require_relative 'mysql_parser/parser_result'