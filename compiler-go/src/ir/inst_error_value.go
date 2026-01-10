package ir

// ErrorValueInst 表示错误值指令（error.ErrorName）
type ErrorValueInst struct {
	BaseInst
	Dest      string // 目标变量名
	ErrorName string // 错误名称
}

// Type 返回指令类型
func (e *ErrorValueInst) Type() InstType {
	return InstErrorValue
}

// NewErrorValueInst 创建一个错误值指令
func NewErrorValueInst(dest string, errorName string) *ErrorValueInst {
	return &ErrorValueInst{
		BaseInst:  BaseInst{id: -1},
		Dest:      dest,
		ErrorName: errorName,
	}
}

