#ifndef VOSS_INTERNAL_HPP
#define VOSS_INTERNAL_HPP

#include <string>

// Internal, non-public: set the thread-local error message.
// Used by all translation units that need to report failures.
void voss_set_last_error(const std::string& msg);

#endif // VOSS_INTERNAL_HPP
