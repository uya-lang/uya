package ir

// AssignInst 表示赋值指令
type AssignInst struct {
	BaseInst
	Dest     string // 目标变量名（简单变量，向后兼容）
	DestExpr Inst   // 目标表达式（支持 arr[0] 等）
	Src      Inst   // 源表达式
}

// Type 返回指令类型
func (a *AssignInst) Type() InstType {
	return InstAssign
}

// NewAssignInst 创建一个赋值指令
func NewAssignInst(dest string, destExpr Inst, src Inst) *AssignInst {
	return &AssignInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		DestExpr: destExpr,
		Src:      src,
	}
}

