package ir

// ConstantInst 表示常量指令
type ConstantInst struct {
	BaseInst
	Value string // 常量值（字符串形式）
	Typ   Type   // 常量类型
}

// Type 返回指令类型
func (c *ConstantInst) Type() InstType {
	return InstConstant
}

// NewConstantInst 创建一个常量指令
func NewConstantInst(value string, typ Type) *ConstantInst {
	return &ConstantInst{
		BaseInst: BaseInst{id: -1},
		Value:    value,
		Typ:      typ,
	}
}

