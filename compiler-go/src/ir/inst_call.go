package ir

// CallInst 表示函数调用指令
type CallInst struct {
	BaseInst
	Dest     string // 目标变量名（可能为空，void函数）
	FuncName string // 函数名
	Args     []Inst // 参数列表
}

// Type 返回指令类型
func (c *CallInst) Type() InstType {
	return InstCall
}

// NewCallInst 创建一个函数调用指令
func NewCallInst(dest, funcName string, args []Inst) *CallInst {
	return &CallInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		FuncName: funcName,
		Args:     args,
	}
}

