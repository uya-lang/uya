package ir

// StructInitInst 表示结构体初始化指令
type StructInitInst struct {
	BaseInst
	Dest       string   // 目标变量名
	StructName string   // 结构体名称
	FieldInits []Inst   // 字段初始化表达式列表
	FieldNames []string // 字段名称列表（对应FieldInits）
}

// Type 返回指令类型
func (s *StructInitInst) Type() InstType {
	return InstStructInit
}

// NewStructInitInst 创建一个结构体初始化指令
func NewStructInitInst(dest string, structName string, fieldInits []Inst, fieldNames []string) *StructInitInst {
	return &StructInitInst{
		BaseInst:  BaseInst{id: -1},
		Dest:      dest,
		StructName: structName,
		FieldInits: fieldInits,
		FieldNames: fieldNames,
	}
}

