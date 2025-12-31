#!/usr/bin/env python3
"""
生成一个大型 Uya 程序来测试编译器性能
"""

def generate_large_test(output_file, num_functions=1000, num_structs=100):
    """生成大型测试程序"""
    
    print(f"开始生成测试程序: {output_file}")
    print(f"  - 函数数量: {num_functions}")
    print(f"  - 结构体数量: {num_structs}")
    print("  生成中...")
    
    with open(output_file, 'w') as f:
        # 文件头部注释
        f.write("// 大型 Uya 程序 - 编译器性能测试\n")
        f.write(f"// 包含 {num_functions} 个函数和 {num_structs} 个结构体\n\n")
        
        # 生成结构体定义
        f.write("// ========== 结构体定义 ==========\n\n")
        for i in range(num_structs):
            if i % 1000 == 0 and i > 0:
                print(f"  已生成 {i}/{num_structs} 个结构体...")
            f.write(f"struct Struct{i} {{\n")
            f.write(f"    field1: i32,\n")
            f.write(f"    field2: f32,\n")
            f.write(f"    field3: i64,\n")
            f.write(f"    field4: i32,\n")
            f.write(f"    field5: f32,\n")
            f.write(f"}}\n\n")
        
        # 生成辅助函数
        f.write("// ========== 辅助函数 ==========\n\n")
        f.write("fn add(x: i32, y: i32) i32 {\n")
        f.write("    return x + y;\n")
        f.write("}\n\n")
        
        f.write("fn multiply(x: i32, y: i32) i32 {\n")
        f.write("    return x * y;\n")
        f.write("}\n\n")
        
        f.write("fn subtract(x: i32, y: i32) i32 {\n")
        f.write("    return x - y;\n")
        f.write("}\n\n")
        
        # 生成大量函数
        f.write("// ========== 主要函数 ==========\n\n")
        for i in range(num_functions):
            # 每1000个函数显示进度
            if i % 1000 == 0 and i > 0:
                print(f"  已生成 {i}/{num_functions} 个函数...")
            
            # 每100个函数添加一个注释
            if i % 100 == 0:
                f.write(f"// 函数组 {i//100 + 1}\n\n")
            
            f.write(f"fn test_function_{i}(x: i32, y: i32) i32 {{\n")
            f.write(f"    var result: i32 = 0;\n")
            f.write(f"    var counter: i32 = 0;\n")
            f.write(f"    var acc: i32 = 0;\n")
            f.write(f"    var sum: i32 = 0;\n")
            
            # 添加一些计算逻辑（增加代码量）
            if i % 3 == 0:
                f.write(f"    result = add(x, y);\n")
                f.write(f"    result = multiply(result, {i % 100});\n")
                f.write(f"    const temp1: i32 = result * 2;\n")
                f.write(f"    const temp2: i32 = result + temp1;\n")
                f.write(f"    result = temp2 - result;\n")
            elif i % 3 == 1:
                f.write(f"    result = subtract(x, y);\n")
                f.write(f"    result = multiply(result, {i % 50 + 1});\n")
                f.write(f"    const temp: i32 = result / 2;\n")
                f.write(f"    result = result + temp;\n")
            else:
                f.write(f"    result = multiply(x, y);\n")
                f.write(f"    result = add(result, {i % 200});\n")
                f.write(f"    const val1: i32 = result;\n")
                f.write(f"    const val2: i32 = val1 * 3;\n")
                f.write(f"    result = val2 - val1;\n")
            
            # 添加循环和控制流
            if i % 5 == 0:
                f.write(f"    while counter < {i % 20 + 1} {{\n")
                f.write(f"        result = result + counter;\n")
                f.write(f"        counter = counter + 1;\n")
                f.write(f"    }}\n")
            
            # 添加条件语句
            if i % 7 == 0:
                f.write(f"    if result > {i % 1000} {{\n")
                f.write(f"        result = result * 2;\n")
                f.write(f"    }} else {{\n")
                f.write(f"        result = result + 10;\n")
                f.write(f"    }}\n")
            
            # 使用结构体（每20个函数使用一个结构体）
            if i % 20 == 0 and i // 20 < num_structs:
                struct_idx = i // 20
                f.write(f"    const s: Struct{struct_idx} = Struct{struct_idx}{{ field1: result, field2: result as f32, field3: result as i64, field4: result, field5: result as f32 }};\n")
                f.write(f"    result = result + s.field1;\n")
                f.write(f"    result = result + s.field4;\n")
            
            # 添加更多计算以增加代码量
            f.write(f"    acc = result * 3;\n")
            f.write(f"    sum = acc + result;\n")
            f.write(f"    result = sum - acc;\n")
            f.write(f"    const final_val: i32 = result + {i % 1000};\n")
            f.write(f"    result = final_val;\n")
            
            f.write(f"    return result;\n")
            f.write(f"}}\n\n")
        
        # 生成主函数
        f.write("// ========== 主函数 ==========\n\n")
        f.write("fn main() i32 {\n")
        f.write("    var total: i32 = 0;\n")
        f.write("    var i: i32 = 0;\n\n")
        
        # 调用部分函数
        calls_count = min(100, num_functions)
        f.write(f"    // 调用前 {calls_count} 个函数\n")
        for i in range(calls_count):
            f.write(f"    total = total + test_function_{i}({i % 100}, {(i * 2) % 100});\n")
        
        f.write("\n    // 批量调用更多函数\n")
        batch_size = min(500, num_functions - calls_count)
        for i in range(calls_count, calls_count + batch_size, 10):
            f.write(f"    total = total + test_function_{i}({i % 100}, {(i * 3) % 100});\n")
        
        f.write("\n    return total;\n")
        f.write("}\n")
    
    import os
    file_size = os.path.getsize(output_file)
    file_size_mb = file_size / (1024 * 1024)
    
    print(f"\n成功生成大型测试程序: {output_file}")
    print(f"  - 函数数量: {num_functions}")
    print(f"  - 结构体数量: {num_structs}")
    print(f"  - 文件大小: {file_size_mb:.2f} MB ({file_size:,} 字节)")

if __name__ == "__main__":
    import sys
    
    # 默认参数
    num_functions = 1000
    num_structs = 100
    output_file = "large_performance_test.uya"
    
    # 解析命令行参数
    if len(sys.argv) > 1:
        num_functions = int(sys.argv[1])
    if len(sys.argv) > 2:
        num_structs = int(sys.argv[2])
    if len(sys.argv) > 3:
        output_file = sys.argv[3]
    
    generate_large_test(output_file, num_functions, num_structs)

