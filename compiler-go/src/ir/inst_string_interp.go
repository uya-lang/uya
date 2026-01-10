package ir

// StringInterpolationInst 表示字符串插值指令
type StringInterpolationInst struct {
	BaseInst
	Dest         string   // 目标变量名
	TextSegments []string // 文本段
	InterpExprs  []Inst   // 插值表达式列表
}

// Type 返回指令类型
func (s *StringInterpolationInst) Type() InstType {
	return InstStringInterpolation
}

// NewStringInterpolationInst 创建一个字符串插值指令
func NewStringInterpolationInst(dest string, textSegments []string, interpExprs []Inst) *StringInterpolationInst {
	return &StringInterpolationInst{
		BaseInst:    BaseInst{id: -1},
		Dest:        dest,
		TextSegments: textSegments,
		InterpExprs: interpExprs,
	}
}

