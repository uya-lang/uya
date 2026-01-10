package ir

// VarDeclInst 表示变量声明指令
type VarDeclInst struct {
	BaseInst
	Name             string // 变量名
	Typ              Type   // 变量类型
	OriginalTypeName string // 用户定义类型的原始名称（如结构体）
	Init             Inst   // 初始化表达式（可选）
	IsMut            bool   // 是否为可变变量
	IsAtomic         bool   // 是否为原子类型
}

// Type 返回指令类型
func (v *VarDeclInst) Type() InstType {
	return InstVarDecl
}

// NewVarDeclInst 创建一个变量声明指令
func NewVarDeclInst(name string, typ Type, originalTypeName string, init Inst, isMut, isAtomic bool) *VarDeclInst {
	return &VarDeclInst{
		BaseInst:        BaseInst{id: -1},
		Name:            name,
		Typ:             typ,
		OriginalTypeName: originalTypeName,
		Init:            init,
		IsMut:           isMut,
		IsAtomic:        isAtomic,
	}
}

