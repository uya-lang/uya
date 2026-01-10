package ir

import (
	"github.com/uya/compiler-go/src/parser"
)

// GenerateFunction 从函数声明生成 IR
func (g *Generator) GenerateFunction(fnDecl *parser.FuncDecl) Inst {
	if fnDecl == nil {
		return nil
	}

	// 设置函数名
	name := fnDecl.Name

	// 设置返回类型
	var returnType Type
	if fnDecl.ReturnType != nil {
		if typeNode, ok := fnDecl.ReturnType.(parser.Type); ok {
			returnType = GetIRType(typeNode)
		} else {
			returnType = TypeVoid
		}
	} else {
		returnType = TypeVoid
	}
	
	// 检查返回类型是否为错误联合类型
	returnTypeIsErrorUnion := false
	if fnDecl.ReturnType != nil {
		if _, ok := fnDecl.ReturnType.(*parser.ErrorUnionType); ok {
			returnTypeIsErrorUnion = true
		}
	}

	// 提取返回类型的原始名称（用于结构体类型）
	returnTypeOriginalName := ""
	if fnDecl.ReturnType != nil {
		if namedType, ok := fnDecl.ReturnType.(*parser.NamedType); ok {
			if returnType == TypeStruct {
				returnTypeOriginalName = namedType.Name
			}
		}
	}

	// 处理参数：将参数转换为VarDeclInst
	params := make([]Inst, 0, len(fnDecl.Params))
	for _, param := range fnDecl.Params {
		// 获取参数类型
		var paramType Type
		if param.Type != nil {
			if typeNode, ok := param.Type.(parser.Type); ok {
				paramType = GetIRType(typeNode)
			} else {
				paramType = TypeI32
			}
		} else {
			paramType = TypeI32
		}
		
		// 获取原始类型名称
		originalTypeName := ""
		if param.Type != nil {
			if namedType, ok := param.Type.(*parser.NamedType); ok {
				// 检查是否是内置类型
				builtinTypes := map[string]bool{
					"i8": true, "i16": true, "i32": true, "i64": true,
					"u8": true, "u16": true, "u32": true, "u64": true,
					"f32": true, "f64": true,
					"bool": true, "void": true, "byte": true,
				}
				if !builtinTypes[namedType.Name] {
					originalTypeName = namedType.Name
				}
			} else if ptrType, ok := param.Type.(*parser.PointerType); ok {
				// 对于指针类型，提取被指向的类型名称
				if ptrType.PointeeType != nil {
					if namedType, ok := ptrType.PointeeType.(*parser.NamedType); ok {
						builtinTypes := map[string]bool{
							"i8": true, "i16": true, "i32": true, "i64": true,
							"u8": true, "u16": true, "u32": true, "u64": true,
							"f32": true, "f64": true,
							"bool": true, "void": true, "byte": true,
						}
						if !builtinTypes[namedType.Name] {
							originalTypeName = namedType.Name
						}
					}
				}
			}
		}

		// 创建参数作为变量声明指令
		paramInst := NewVarDeclInst(param.Name, paramType, originalTypeName, nil, false, false)
		params = append(params, paramInst)
	}

	// 处理函数体：将AST语句转换为IR指令
	var body []Inst
	if fnDecl.Body != nil {
		body = make([]Inst, 0, len(fnDecl.Body.Stmts))
		for _, stmt := range fnDecl.Body.Stmts {
			inst := g.GenerateStmt(stmt)
			if inst != nil {
				body = append(body, inst)
			}
		}
	}

	// 创建函数定义指令
	funcInst := NewFuncDefInst(name, params, returnType, returnTypeOriginalName, body, fnDecl.IsExtern, returnTypeIsErrorUnion)
	
	// 将函数添加到指令列表
	g.AddInstruction(funcInst)
	
	return funcInst
}

