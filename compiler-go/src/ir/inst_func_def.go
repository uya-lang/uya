package ir

// FuncDefInst 表示函数定义指令
type FuncDefInst struct {
	BaseInst
	Name                 string   // 函数名
	Params               []Inst   // 参数列表（作为VarDeclInst）
	ReturnType           Type     // 返回类型
	ReturnTypeOriginalName string // 返回类型的原始名称（用于结构体类型）
	Body                 []Inst   // 函数体指令列表
	IsExtern             bool     // 是否为外部函数
	ReturnTypeIsErrorUnion bool   // 返回类型是否为错误联合类型（!T）
}

// Type 返回指令类型
func (f *FuncDefInst) Type() InstType {
	return InstFuncDef
}

// NewFuncDefInst 创建一个函数定义指令
func NewFuncDefInst(name string, params []Inst, returnType Type, returnTypeOriginalName string, body []Inst, isExtern bool, returnTypeIsErrorUnion bool) *FuncDefInst {
	return &FuncDefInst{
		BaseInst:              BaseInst{id: -1},
		Name:                  name,
		Params:                params,
		ReturnType:            returnType,
		ReturnTypeOriginalName: returnTypeOriginalName,
		Body:                  body,
		IsExtern:              isExtern,
		ReturnTypeIsErrorUnion: returnTypeIsErrorUnion,
	}
}

