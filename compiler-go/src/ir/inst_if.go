package ir

// IfInst 表示 if 语句指令
type IfInst struct {
	BaseInst
	Condition Inst   // 条件表达式
	ThenBody  []Inst // then 分支的指令列表
	ElseBody  []Inst // else 分支的指令列表（可选）
}

// Type 返回指令类型
func (i *IfInst) Type() InstType {
	return InstIf
}

// NewIfInst 创建一个 if 语句指令
func NewIfInst(condition Inst, thenBody, elseBody []Inst) *IfInst {
	return &IfInst{
		BaseInst:  BaseInst{id: -1},
		Condition: condition,
		ThenBody:  thenBody,
		ElseBody:  elseBody,
	}
}

