LLVM_DEFINES = [
    "__STDC_CONSTANT_MACROS",
    "__STDC_FORMAT_MACROS",
    "__STDC_LIMIT_MACROS"
]

LLVM_LINKOPTS = [
    # llvm linker flags (llvm-config --ldflags):
    "-Wl,-search_paths_first",
    "-Wl,-headerpad_max_install_names"
]
