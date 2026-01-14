// 测试程序：验证 LLVM C API 中指针类型数组访问的 GEP 生成
// 模拟 buffer_ptr[0] 场景

#include <stdio.h>
#include <stdlib.h>
#include <llvm-c/Core.h>
#include <llvm-c/ExecutionEngine.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

int main() {
    // 初始化 LLVM
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    
    // 创建上下文和模块
    LLVMContextRef context = LLVMContextCreate();
    LLVMModuleRef module = LLVMModuleCreateWithNameInContext("test_module", context);
    
    // 设置目标三元组
    LLVMSetTarget(module, "x86_64-pc-linux-gnu");
    
    // 创建构建器
    LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);
    
    // 创建函数类型：char test() { ... }
    LLVMTypeRef i8_type = LLVMInt8Type();
    LLVMTypeRef i32_type = LLVMInt32Type();
    LLVMTypeRef func_type = LLVMFunctionType(i8_type, NULL, 0, 0);
    
    // 创建函数
    LLVMValueRef func = LLVMAddFunction(module, "test_buffer_ptr_access", func_type);
    
    // 创建基本块
    LLVMBasicBlockRef entry_bb = LLVMAppendBasicBlock(func, "entry");
    LLVMPositionBuilderAtEnd(builder, entry_bb);
    
    // 创建缓冲区：[100 x i8]
    LLVMTypeRef array_type = LLVMArrayType(i8_type, 100);
    LLVMValueRef buffer = LLVMBuildAlloca(builder, array_type, "buffer");
    
    // 获取 buffer[0] 的地址：getelementptr [100 x i8], ptr %buffer, i32 0, i32 0
    LLVMValueRef indices1[2];
    indices1[0] = LLVMConstInt(i32_type, 0, 0);
    indices1[1] = LLVMConstInt(i32_type, 0, 0);
    LLVMValueRef buffer_ptr = LLVMBuildGEP2(builder, array_type, buffer, indices1, 2, "buffer_ptr");
    
    // 将 buffer_ptr 转换为 i8* 类型（bitcast）
    LLVMTypeRef i8_ptr_type = LLVMPointerType(i8_type, 0);
    LLVMValueRef buffer_ptr_i8 = LLVMBuildBitCast(builder, buffer_ptr, i8_ptr_type, "buffer_ptr_i8");
    
    // 测试：buffer_ptr_i8[0] - 使用 getelementptr i8, ptr %buffer_ptr_i8, i32 0
    printf("测试：生成 getelementptr i8, ptr %%buffer_ptr_i8, i32 0\n");
    LLVMValueRef indices2[1];
    indices2[0] = LLVMConstInt(i32_type, 0, 0);
    
    printf("调用 LLVMBuildGEP2(builder, i8_type=%p, buffer_ptr_i8=%p, indices, 1)\n", 
           (void*)i8_type, (void*)buffer_ptr_i8);
    
    LLVMValueRef element_ptr = LLVMBuildGEP2(builder, i8_type, buffer_ptr_i8, indices2, 1, "element_ptr");
    
    if (!element_ptr) {
        printf("错误: LLVMBuildGEP2 返回 NULL\n");
        return 1;
    }
    
    printf("成功: LLVMBuildGEP2 返回 %p\n", (void*)element_ptr);
    
    // 加载元素值
    LLVMValueRef element_val = LLVMBuildLoad2(builder, i8_type, element_ptr, "temp");
    
    if (!element_val) {
        printf("错误: LLVMBuildLoad2 返回 NULL\n");
        return 1;
    }
    
    printf("成功: LLVMBuildLoad2 返回 %p\n", (void*)element_val);
    
    // 返回元素值
    LLVMBuildRet(builder, element_val);
    
    // 打印 IR
    printf("\n生成的 IR:\n");
    LLVMDumpModule(module);
    
    // 清理
    LLVMDisposeBuilder(builder);
    LLVMDisposeModule(module);
    LLVMContextDispose(context);
    
    printf("\n测试完成: 所有 LLVM C API 调用成功\n");
    return 0;
}

