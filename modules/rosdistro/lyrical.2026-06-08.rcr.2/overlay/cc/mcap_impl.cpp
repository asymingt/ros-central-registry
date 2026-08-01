// This file compiles the mcap header-only library into a proper object file.
// The mcap library uses MCAP_IMPLEMENTATION to gate inclusion of the .inl
// implementation files from the .hpp headers. Without this, the library is
// purely header-only and produces no symbols.
#define MCAP_IMPLEMENTATION
#include <mcap/mcap.hpp>
