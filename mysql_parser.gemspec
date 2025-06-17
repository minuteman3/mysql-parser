Gem::Specification.new do |spec|
  spec.name          = "mysql_parser"
  spec.version       = "0.1.1"
  spec.authors       = ["Your Name"]
  spec.email         = ["your.email@example.com"]
  spec.summary       = "Ruby bindings for TiDB MySQL parser"
  spec.description   = "Parse MySQL queries and get back AST using TiDB's parser"
  spec.homepage      = "https://github.com/yourusername/mysql-parser"
  spec.license       = "Apache-2.0"
  
  spec.metadata = {
    "github_repo" => "ssh://github.com/minuteman3/mysql-parser"
  }
  
  # For platform-specific gems, include the binary for that platform
  if ENV['MYSQL_PARSER_PLATFORM']
    spec.platform = Gem::Platform.new(ENV['MYSQL_PARSER_PLATFORM'])
    spec.files = Dir["lib/**/*"] + ["libmysql_parser.so", "libmysql_parser.h"].select { |f| File.exist?(f) }
  else
    # Source gem - no binaries included
    spec.files = Dir["lib/**/*", "ext/**/*", "Makefile", "parser.go", "go.mod", "go.sum"] - Dir["lib/mysql_parser/binaries/*"]
    spec.extensions = ["ext/mysql_parser/extconf.rb"]
  end
  spec.require_paths = ["lib"]
  
  spec.add_dependency "ffi", "~> 1.15"
  spec.add_development_dependency "rspec", "~> 3.0"
end