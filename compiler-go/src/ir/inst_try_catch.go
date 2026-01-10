package ir

// TryCatchInst 表示try-catch指令
type TryCatchInst struct {
	BaseInst
	Dest      string // 目标变量名（catch表达式的返回值）
	TryExpr   Inst   // try表达式
	ErrorVar  string // 错误变量名（可能为空）
	CatchBody []Inst // catch块指令列表
}

// Type 返回指令类型
func (t *TryCatchInst) Type() InstType {
	return InstTryCatch
}

// NewTryCatchInst 创建一个try-catch指令
func NewTryCatchInst(dest string, tryExpr Inst, errorVar string, catchBody []Inst) *TryCatchInst {
	return &TryCatchInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		TryExpr:  tryExpr,
		ErrorVar: errorVar,
		CatchBody: catchBody,
	}
}

