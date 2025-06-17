package main

import (
	"C"
	"encoding/json"
	"fmt"
	"reflect"
	"strings"

	"github.com/pingcap/parser"
	"github.com/pingcap/parser/ast"
	"github.com/pingcap/parser/format"
	_ "github.com/pingcap/parser/test_driver"
)

// Result represents the parsing result
type Result struct {
	Success bool        `json:"success"`
	Error   string      `json:"error,omitempty"`
	AST     interface{} `json:"ast,omitempty"`
}

// ASTNode represents a simplified AST node for JSON serialization
type ASTNode struct {
	Type     string                 `json:"type"`
	Text     string                 `json:"text,omitempty"`
	Children []ASTNode              `json:"children,omitempty"`
	Data     map[string]interface{} `json:"data,omitempty"`
}

func convertToSimpleAST(node ast.Node) ASTNode {
	if node == nil {
		return ASTNode{}
	}

	nodeType := fmt.Sprintf("%T", node)
	
	// Get the text representation
	var text string
	var buf strings.Builder
	if err := node.Restore(format.NewRestoreCtx(format.DefaultRestoreFlags, &buf)); err == nil {
		text = buf.String()
	}

	result := ASTNode{
		Type: nodeType,
		Text: text,
		Data: make(map[string]interface{}),
		Children: []ASTNode{},
	}

	// Add specific data based on node type
	switch node.(type) {
	case ast.StmtNode:
		result.Data["statement_type"] = "statement"
	case ast.ExprNode:
		result.Data["expression_type"] = "expression"
	case ast.DDLNode:
		result.Data["ddl_type"] = "ddl"
	case ast.DMLNode:
		result.Data["dml_type"] = "dml"
	}

	// Use reflection to find child AST nodes
	result.Children = extractChildNodes(node)

	return result
}

// extractChildNodes uses reflection to find all child ast.Node fields in a node
func extractChildNodes(node ast.Node) []ASTNode {
	var children []ASTNode
	
	if node == nil {
		return children
	}

	val := reflect.ValueOf(node)
	if val.Kind() == reflect.Ptr {
		val = val.Elem()
	}
	
	if val.Kind() != reflect.Struct {
		return children
	}

	typ := val.Type()
	
	for i := 0; i < val.NumField(); i++ {
		field := val.Field(i)
		fieldType := typ.Field(i)
		
		// Skip unexported fields
		if !field.CanInterface() {
			continue
		}
		
		// Handle pointer to ast.Node
		if field.Kind() == reflect.Ptr && !field.IsNil() {
			if astNode, ok := field.Interface().(ast.Node); ok {
				child := convertToSimpleAST(astNode)
				child.Data["field_name"] = fieldType.Name
				children = append(children, child)
			}
		}
		
		// Handle slices of ast.Node pointers
		if field.Kind() == reflect.Slice {
			for j := 0; j < field.Len(); j++ {
				elem := field.Index(j)
				if elem.Kind() == reflect.Ptr && !elem.IsNil() {
					if astNode, ok := elem.Interface().(ast.Node); ok {
						child := convertToSimpleAST(astNode)
						child.Data["field_name"] = fieldType.Name
						child.Data["array_index"] = j
						children = append(children, child)
					}
				}
			}
		}
		
		// Handle interfaces that might be ast.Node
		if field.Kind() == reflect.Interface && !field.IsNil() {
			if astNode, ok := field.Interface().(ast.Node); ok {
				child := convertToSimpleAST(astNode)
				child.Data["field_name"] = fieldType.Name
				children = append(children, child)
			}
		}
	}

	return children
}

//export parse_sql
func parse_sql(sql *C.char) *C.char {
	sqlStr := C.GoString(sql)
	
	p := parser.New()
	stmts, _, err := p.Parse(sqlStr, "", "")
	
	var result Result
	
	if err != nil {
		result = Result{
			Success: false,
			Error:   err.Error(),
		}
	} else {
		var astNodes []ASTNode
		for _, stmt := range stmts {
			astNodes = append(astNodes, convertToSimpleAST(stmt))
		}
		
		result = Result{
			Success: true,
			AST:     astNodes,
		}
	}
	
	jsonData, _ := json.Marshal(result)
	return C.CString(string(jsonData))
}

//export free_string
func free_string(str *C.char) {
	// Memory will be managed by Go's garbage collector
	// No need to explicitly free C.CString allocated memory
}

func main() {}