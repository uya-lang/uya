package ir

// WhileInst 表示 while 循环指令
type WhileInst struct {
	BaseInst
	Condition Inst   // 条件表达式
	Body      []Inst // 循环体的指令列表
}

// Type 返回指令类型
func (w *WhileInst) Type() InstType {
	return InstWhile
}

// NewWhileInst 创建一个 while 循环指令
func NewWhileInst(condition Inst, body []Inst) *WhileInst {
	return &WhileInst{
		BaseInst:  BaseInst{id: -1},
		Condition: condition,
		Body:      body,
	}
}

