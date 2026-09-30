// ============================================================
// error.cpp — thread-local error message + error codes
// ============================================================

#include "voss/voss.h"
#include "core/internal.hpp"

#include <string>

static thread_local std::string g_last_error;

void voss_set_last_error(const std::string& msg) {
    g_last_error = msg;
}

extern "C" const char* voss_get_last_error(void) {
    return g_last_error.c_str();
}

extern "C" const char* voss_strerror(int code) {
    switch (code) {
        case VOSS_OK:                return "OK";
        case VOSS_ERR_INVALID_N:     return "Invalid N";
        case VOSS_ERR_OUT_OF_RANGE:  return "Out of range";
        case VOSS_ERR_NO_CUDA:       return "No CUDA device";
        case VOSS_ERR_OUT_OF_MEMORY: return "Out of memory";
        case VOSS_ERR_CUDA:          return "CUDA error";
        case VOSS_ERR_INVALID_ARG:   return "Invalid argument";
        case VOSS_ERR_INTERNAL:      return "Internal error";
        default:                     return "Unknown error";
    }
}
