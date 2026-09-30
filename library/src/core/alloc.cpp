// ============================================================
// alloc.cpp — memory management (M3)
// ============================================================

#include "voss/voss.h"
#include <cstdlib>

extern "C" void voss_free(void* ptr) {
    free(ptr);
}
