; ModuleID = 'tests/programs/test_break_continue.uya'
source_filename = "tests/programs/test_break_continue.uya"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

define i32 @main() {
entry:
  %sum = alloca i32, align 4
  store i32 0, ptr %sum, align 4
  %count = alloca i32, align 4
  store i32 0, ptr %count, align 4
  br label %while.cond.0

while.cond.0:                                     ; preds = %if.end.1, %entry
  %count1 = load i32, ptr %count, align 4
  %0 = icmp slt i32 %count1, 10
  br i1 %0, label %while.body.0, label %while.end.0

while.body.0:                                     ; preds = %while.cond.0
  %count2 = load i32, ptr %count, align 4
  %1 = add i32 %count2, 1
  store i32 %1, ptr %count, align 4
  %sum3 = load i32, ptr %sum, align 4
  %count4 = load i32, ptr %count, align 4
  %2 = add i32 %sum3, %count4
  store i32 %2, ptr %sum, align 4
  %count5 = load i32, ptr %count, align 4
  %3 = icmp eq i32 %count5, 5
  br i1 %3, label %if.then.1, label %if.end.1

while.end.0:                                      ; preds = %if.then.1, %while.cond.0
  %sum6 = load i32, ptr %sum, align 4
  %4 = icmp ne i32 %sum6, 15
  br i1 %4, label %if.then.2, label %if.end.2

if.then.1:                                        ; preds = %while.body.0
  br label %while.end.0

if.end.1:                                         ; preds = %while.body.0
  br label %while.cond.0

if.then.2:                                        ; preds = %while.end.0
  ret i32 1

if.end.2:                                         ; preds = %while.end.0
  %sum2 = alloca i32, align 4
  store i32 0, ptr %sum2, align 4
  %count27 = alloca i32, align 4
  store i32 0, ptr %count27, align 4
  br label %while.cond.3

while.cond.3:                                     ; preds = %if.end.4, %if.then.4, %if.end.2
  %count28 = load i32, ptr %count27, align 4
  %5 = icmp slt i32 %count28, 10
  br i1 %5, label %while.body.3, label %while.end.3

while.body.3:                                     ; preds = %while.cond.3
  %count29 = load i32, ptr %count27, align 4
  %6 = add i32 %count29, 1
  store i32 %6, ptr %count27, align 4
  %count210 = load i32, ptr %count27, align 4
  %7 = icmp eq i32 %count210, 5
  br i1 %7, label %if.then.4, label %if.end.4

while.end.3:                                      ; preds = %while.cond.3
  %sum213 = load i32, ptr %sum2, align 4
  %8 = icmp ne i32 %sum213, 50
  br i1 %8, label %if.then.5, label %if.end.5

if.then.4:                                        ; preds = %while.body.3
  br label %while.cond.3

if.end.4:                                         ; preds = %while.body.3
  %sum211 = load i32, ptr %sum2, align 4
  %count212 = load i32, ptr %count27, align 4
  %9 = add i32 %sum211, %count212
  store i32 %9, ptr %sum2, align 4
  br label %while.cond.3

if.then.5:                                        ; preds = %while.end.3
  ret i32 2

if.end.5:                                         ; preds = %while.end.3
  %outer_count = alloca i32, align 4
  store i32 0, ptr %outer_count, align 4
  %inner_count = alloca i32, align 4
  store i32 0, ptr %inner_count, align 4
  br label %while.cond.6

while.cond.6:                                     ; preds = %if.end.9, %if.end.5
  %outer_count14 = load i32, ptr %outer_count, align 4
  %10 = icmp slt i32 %outer_count14, 5
  br i1 %10, label %while.body.6, label %while.end.6

while.body.6:                                     ; preds = %while.cond.6
  %outer_count15 = load i32, ptr %outer_count, align 4
  %11 = add i32 %outer_count15, 1
  store i32 %11, ptr %outer_count, align 4
  store i32 0, ptr %inner_count, align 4
  br label %while.cond.7

while.end.6:                                      ; preds = %while.cond.6
  %sum320 = alloca i32, align 4
  store i32 0, ptr %sum320, align 4
  %i = alloca i32, align 4
  store i32 0, ptr %i, align 4
  br label %while.cond.10

while.cond.7:                                     ; preds = %if.end.8, %while.body.6
  %inner_count16 = load i32, ptr %inner_count, align 4
  %12 = icmp slt i32 %inner_count16, 10
  br i1 %12, label %while.body.7, label %while.end.7

while.body.7:                                     ; preds = %while.cond.7
  %inner_count17 = load i32, ptr %inner_count, align 4
  %13 = add i32 %inner_count17, 1
  store i32 %13, ptr %inner_count, align 4
  %inner_count18 = load i32, ptr %inner_count, align 4
  %14 = icmp eq i32 %inner_count18, 3
  br i1 %14, label %if.then.8, label %if.end.8

while.end.7:                                      ; preds = %if.then.8, %while.cond.7
  %inner_count19 = load i32, ptr %inner_count, align 4
  %15 = icmp ne i32 %inner_count19, 3
  br i1 %15, label %if.then.9, label %if.end.9

if.then.8:                                        ; preds = %while.body.7
  br label %while.end.7

if.end.8:                                         ; preds = %while.body.7
  br label %while.cond.7

if.then.9:                                        ; preds = %while.end.7
  ret i32 3

if.end.9:                                         ; preds = %while.end.7
  br label %while.cond.6

while.cond.10:                                    ; preds = %while.end.12, %if.then.11, %while.end.6
  %i21 = load i32, ptr %i, align 4
  %16 = icmp slt i32 %i21, 5
  br i1 %16, label %while.body.10, label %while.end.10

while.body.10:                                    ; preds = %while.cond.10
  %i22 = load i32, ptr %i, align 4
  %17 = add i32 %i22, 1
  store i32 %17, ptr %i, align 4
  %i23 = load i32, ptr %i, align 4
  %18 = icmp eq i32 %i23, 3
  br i1 %18, label %if.then.11, label %if.end.11

while.end.10:                                     ; preds = %while.cond.10
  %sum328 = load i32, ptr %sum320, align 4
  %19 = icmp ne i32 %sum328, 36
  br i1 %19, label %if.then.13, label %if.end.13

if.then.11:                                       ; preds = %while.body.10
  br label %while.cond.10

if.end.11:                                        ; preds = %while.body.10
  %j = alloca i32, align 4
  store i32 0, ptr %j, align 4
  br label %while.cond.12

while.cond.12:                                    ; preds = %while.body.12, %if.end.11
  %j24 = load i32, ptr %j, align 4
  %20 = icmp slt i32 %j24, 3
  br i1 %20, label %while.body.12, label %while.end.12

while.body.12:                                    ; preds = %while.cond.12
  %j25 = load i32, ptr %j, align 4
  %21 = add i32 %j25, 1
  store i32 %21, ptr %j, align 4
  %sum326 = load i32, ptr %sum320, align 4
  %i27 = load i32, ptr %i, align 4
  %22 = add i32 %sum326, %i27
  store i32 %22, ptr %sum320, align 4
  br label %while.cond.12

while.end.12:                                     ; preds = %while.cond.12
  br label %while.cond.10

if.then.13:                                       ; preds = %while.end.10
  ret i32 4

if.end.13:                                        ; preds = %while.end.10
  ret i32 0
}
