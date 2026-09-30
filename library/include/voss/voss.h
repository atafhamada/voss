#ifndef VOSS_H
#define VOSS_H

#ifdef __cplusplus
extern "C" {
#endif

// === Error codes (DESIGN.md 3.6) ===
#define VOSS_OK                     0
#define VOSS_ERR_INVALID_N          1
#define VOSS_ERR_OUT_OF_RANGE       2
#define VOSS_ERR_NO_CUDA            3
#define VOSS_ERR_OUT_OF_MEMORY      4
#define VOSS_ERR_CUDA               5
#define VOSS_ERR_INVALID_ARG        6
#define VOSS_ERR_INTERNAL           7

// === Error messages ===
const char* voss_strerror(int code);
const char* voss_get_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // VOSS_H
