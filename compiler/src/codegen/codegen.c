#include "codegen.h"
#include "codegen_error.h"
#include "codegen_type.h"
#include "codegen_value.h"
#include "codegen_inst.h"
#include "../ir/ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// This file now serves as the main entry point that includes all modular components
// All functionality has been moved to separate modules:
// - codegen_error.c: Error handling functions
// - codegen_type.c: Type handling functions  
// - codegen_value.c: Value writing functions
// - codegen_inst.c: Instruction generation functions
// - codegen_main.c: Main generation functions and initialization