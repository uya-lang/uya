package ir

// Generator 表示 IR 生成器
type Generator struct {
	instructions []Inst // 指令列表
	currentID    int    // 当前指令 ID（用于 SSA 形式）
}

// NewGenerator 创建一个新的 IR 生成器
func NewGenerator() *Generator {
	return &Generator{
		instructions: make([]Inst, 0, 16),
		currentID:    0,
	}
}

// AddInstruction 添加一条指令到生成器
func (g *Generator) AddInstruction(inst Inst) {
	if inst == nil {
		return
	}

	// 为指令分配 ID
	inst.SetID(g.currentID)
	g.currentID++

	// 添加到指令列表
	g.instructions = append(g.instructions, inst)
}

// Instructions 返回所有指令
func (g *Generator) Instructions() []Inst {
	return g.instructions
}

// CurrentID 返回当前指令 ID
func (g *Generator) CurrentID() int {
	return g.currentID
}

// NextID 返回下一个可用的指令 ID（不增加计数器）
func (g *Generator) NextID() int {
	return g.currentID
}

// Reset 重置生成器（清空所有指令，重置 ID）
func (g *Generator) Reset() {
	g.instructions = g.instructions[:0]
	g.currentID = 0
}

// Generate 从 AST 生成 IR（主入口函数）
func (g *Generator) Generate(ast interface{}) interface{} {
	// 重置计数器
	g.Reset()

	// 根据 AST 类型进行转换
	if program, ok := ast.(*parser.Program); ok {
		g.GenerateProgram(program)
	}

	return g
}

// Free 释放生成器及其所有指令
// 在 Go 中，通常不需要显式释放，但提供此方法以匹配 C API
func (g *Generator) Free() {
	// Go 的垃圾回收器会自动处理
	// 但我们可以清空引用以帮助 GC
	g.instructions = nil
	g.currentID = 0
}

