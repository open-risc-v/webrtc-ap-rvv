# 上游接入：webrtc-audio-processing（meson）→ <build>/pkg/prefix。
# 探针是 C++（APM 只有 C++ 接口），骨架顶层是 C，这里补开 CXX。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
    COMMENT "构建上游 webrtc-audio-processing（${SRC_DIR}）"
    VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

enable_language(CXX)
add_executable(apm_harness test/pkg_apm.cpp)
if(HAVE_PKG_TARGET)
  add_dependencies(apm_harness pkg)
endif()
target_include_directories(apm_harness PRIVATE "${PKG_PREFIX}/include" "${PKG_PREFIX}/include/webrtc-audio-processing-2")
target_link_directories(apm_harness PRIVATE "${PKG_PREFIX}/lib")
# 上游 webrtc 与全部 absl 由 pkg-build 合并成一个归档，避免跨归档顺序问题
target_link_libraries(apm_harness PRIVATE webrtc-ap-full pthread dl)
target_compile_options(apm_harness PRIVATE ${RVV_FLAGS})
set_target_properties(apm_harness PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

add_test(NAME apm_harness COMMAND apm_harness)
