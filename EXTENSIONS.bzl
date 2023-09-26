load(":libs.bzl", "genlibsmap")

# info on targets: llvm-project/docs/GettingStarted.rst

################################################################
supported = [
    "AArch64", "AMDGPU", "ARM", "AVR", "BPF",
    "Hexagon", "Lanai", "Mips", "MSP430", "NVPTX",
    "PowerPC", "RISCV", "Sparc", "SystemZ",
    "WebAssembly", "X86", "XCore",
]

archmap = {
    "aarch64": "AArch64",
    "amdgpu": "AMDGPU",
    "arm": "ARM",
    "avr": "AVR",
    "bpf": "BPF",
    "hexagon": "Hexagon",
    "lanai": "Lanai",
    "mips": "Mips",
    "msp430": "MSP430",
    "nvptx": "NVPTX",
    "powerpc": "PowerPC",
    "riscv": "RISCV",
    "sparc": "Sparc",
    "systemz": "SystemZ",
    "webassembly": "WebAssembly",
    "x86": "X86",
    "xcore": "XCore"
}

################################################################
#### C SDK repo rule ####
def _llvm_sdk_impl(rctx):
    print("LLVM_SDK REPO RULE")

    rctx.file(
        "MODULE.bazel",
        content = """
module(
    name = "llvm_sdk",
    version = "17.0.1",
    compatibility_level = 17,
)
"""
    )

    rctx.file(
        "BUILD.bazel",
        content = "#"
    )

    rctx.file(
        "CONFIG.bzl",
        content = """
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
"""
    )

    rctx.symlink(rctx.attr.version_file,
                 "version/BUILD.bazel")
#     rctx.file(
#         "version/BUILD.bazel",
#         content = """
# load("@bazel_skylib//rules:common_settings.bzl",
#       "string_setting")

# string_setting(
#     name = "version", build_setting_default = "15.0.0",
#     visibility = ["//visibility:public"],
#     )
# """
#     )

    # rctx.workspace_root is the ws from which
    # the extension (& the repo rule) was called.
    # we symlink directories, which means
    # the build files we write will be written
    # to the original dirs. the will not be
    # removed by bazel clean.
    wsroot = rctx.workspace_root

    ## bin dir same for all sdks
    rctx.symlink("{root}/{bld}/bin".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/bin")
    rctx.file(
        "sdk/bin/BUILD.bazel",
        content = """
exports_files(glob(["**"]))
"""
    )

    rctx.symlink("{root}/{bld}/include/llvm".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/c/include/llvm")

    # rctx.symlink("{root}/llvm/include/llvm".format(root=wsroot,bld=bld),
    #              "sdk/c/include/llvm")

    rctx.symlink("{root}/llvm/include/llvm-c".format(root=wsroot),
                 "sdk/c/include/llvm-c")
    rctx.file(
        "sdk/c/include/BUILD.bazel",
        content = """
cc_library(
    name = "llvm-c",
    hdrs = glob(["llvm-c/**"]) + glob([
        "llvm/Config/llvm-config.h", # C hdr among c++ hdrs
        "llvm/Config/*.def"
    ], exclude = ["llvm/Config/abi-breaking.h"]),
    visibility = ["//visibility:public"]
)
"""
        )


    ## c++ sdk
    rctx.symlink("{root}/libcxx/include".format(root=wsroot),
                 "sdk/c++/include")

    rctx.symlink("{root}/{bld}/lib".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/c/lib")
    rctx.symlink("{root}/{bld}/libexec".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/c/libexec")

    libsmap = genlibsmap(rctx)
    rctx.template(
        "sdk/c/lib/BUILD.bazel",
        Label(":BUILD.lib_pkg"),
        substitutions = libsmap,
        executable = False,
    )

    xarch = rctx.os.arch.lower()
    arch = archmap[xarch]
    # print("ARCH: %s" % arch)

    rctx.file(
        "makevars/RULES.bzl",
        content = """
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _makevars_impl(ctx):
    t = ctx.attr._target[BuildSettingInfo].value
    if t == "host":
        arch = "{host_arch}"
    else:
        arch = t
    items = {{"LLVM_TARGET_ARCH": arch}}

    return [platform_common.TemplateVariableInfo(items)]
makevars = rule(
    implementation = _makevars_impl,
    attrs = {{ "_target": attr.label(
        default = "//target"
        ) }}
)
""".format(host_arch = arch)
    )

    rctx.file(
        "makevars/BUILD.bazel",
        content = """
load(":RULES.bzl", "makevars")
makevars(name = "makevars",
         visibility = ["//visibility:public"])
"""
    )

    rctx.file(
        "host/BUILD.bazel",
        content = """
package(default_visibility = ["//visibility:public"])
config_setting(name = "aarch64",
               flag_values = {"//target": "host"},
               constraint_values = ["@platforms//cpu:aarch64"])
config_setting(name = "x86",
               flag_values = {"//target": "host"},
               constraint_values = ["@platforms//cpu:x86_64"])
"""
        )
    rctx.file(
        "target/BUILD.bazel",
        content = """
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
string_flag(
    name = "target", build_setting_default = "host",
    visibility = ["//visibility:public"],
    values = [
        "AArch64", "AMDGPU", "ARM", "AVR", "BPF",
        "Hexagon", "Lanai", "Mips", "MSP430",
        "NVPTX", "PowerPC", "RISCV", "Sparc",
        "SystemZ", "WebAssembly", "X86", "XCore",
        "host"
    ]
)
config_setting(name = "host",
               flag_values = {":target": "host"})

config_setting(name = "aarch64",
               flag_values = {":target": "aarch64"})

config_setting(name = "x86",
               flag_values = {":target": "x86"})
"""
    )

    ## end of _llvm_sdk repo rule

############
_llvm_sdk = repository_rule(
    implementation = _llvm_sdk_impl,
    local = True,
    attrs = {
        "version_file": attr.string(),
        "llvm": attr.label(),
        "build_dir": attr.string(mandatory = True),

        # "_ml_template": attr.label(
        #     default = "//src/backends/llvm_backend.ml.in"
        # ),
        # "_mli_template": attr.label(
        #     default = "//src/backends/llvm_backend.mli.in"
        # ),
        "targets": attr.string_list(
            doc = """Supported targets:
            AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, Lanai, Mips,
            MSP430, NVPTX, PowerPC, RISCV, Sparc, SystemZ,
            WebAssembly, X86, XCore.
            Special targets: ALL, host
            """
        ),
    },
)

################################################################
#### LLVM TOOL repo rule ####
def _llvm_tools_impl(rctx):
    print("LLVM_TOOLS REPO RULE")

    rctx.file(
        "MODULE.bazel",
        content = """
module(
    name = "llvm_tools",
    version = "17.0.1",
    compatibility_level = 17,
)
"""
    )

    rctx.file(
        "BUILD.bazel",
        content = "#"
    )

    wsroot = rctx.workspace_root

    rctx.symlink(
        "{}/utils/bazel/RULES.bzl".format(wsroot),
        "RULES.bzl")

    rctx.file(
        "CONFIG.bzl",
        content = """
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
"""
    )

    rctx.symlink(rctx.attr.version_file,
                 "version/BUILD.bazel")
    # rctx.workspace_root is the ws from which
    # the extension (& the repo rule) was called.
    # we symlink directories, which means
    # the build files we write will be written
    # to the original dirs. the will not be
    # removed by bazel clean.
    wsroot = rctx.workspace_root

    ## bin dir same for all sdks
    rctx.symlink("{root}/{bld}/bin".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/bin")
    rctx.file(
        "sdk/bin/BUILD.bazel",
        content = """
exports_files(glob(["**"]))
"""
    )

    rctx.symlink("{root}/{bld}/lib".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/c/lib")
    rctx.symlink("{root}/{bld}/libexec".format(
        root=wsroot,
        bld=rctx.attr.build_dir),
                 "sdk/c/libexec")

    # libsmap = genlibsmap(rctx)
    # rctx.template(
    #     "sdk/c/lib/BUILD.bazel",
    #     Label(":BUILD.lib_pkg"),
    #     substitutions = libsmap,
    #     executable = False,
    # )

    xarch = rctx.os.arch.lower()
    arch = archmap[xarch]
    # print("ARCH: %s" % arch)

#     rctx.file(
#         "makevars/RULES.bzl",
#         content = """
# load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

# def _makevars_impl(ctx):
#     t = ctx.attr._target[BuildSettingInfo].value
#     if t == "host":
#         arch = "{host_arch}"
#     else:
#         arch = t
#     items = {{"LLVM_TARGET_ARCH": arch}}

#     return [platform_common.TemplateVariableInfo(items)]
# makevars = rule(
#     implementation = _makevars_impl,
#     attrs = {{ "_target": attr.label(
#         default = "//target"
#         ) }}
# )
# """.format(host_arch = arch)
#     )

#     rctx.file(
#         "makevars/BUILD.bazel",
#         content = """
# load(":RULES.bzl", "makevars")
# makevars(name = "makevars",
#          visibility = ["//visibility:public"])
# """
#     )

#     rctx.file(
#         "host/BUILD.bazel",
#         content = """
# package(default_visibility = ["//visibility:public"])
# config_setting(name = "aarch64",
#                flag_values = {"//target": "host"},
#                constraint_values = ["@platforms//cpu:aarch64"])
# config_setting(name = "x86",
#                flag_values = {"//target": "host"},
#                constraint_values = ["@platforms//cpu:x86_64"])
# """
#         )

#     rctx.file(
#         "target/BUILD.bazel",
#         content = """
# load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
# string_flag(
#     name = "target", build_setting_default = "host",
#     visibility = ["//visibility:public"],
#     values = [
#         "AArch64", "AMDGPU", "ARM", "AVR", "BPF",
#         "Hexagon", "Lanai", "Mips", "MSP430",
#         "NVPTX", "PowerPC", "RISCV", "Sparc",
#         "SystemZ", "WebAssembly", "X86", "XCore",
#         "host"
#     ]
# )
# config_setting(name = "host",
#                flag_values = {":target": "host"})

# config_setting(name = "aarch64",
#                flag_values = {":target": "aarch64"})

# config_setting(name = "x86",
#                flag_values = {":target": "x86"})
# """
#     )

    ## end of _llvm_tools repo rule

############
_llvm_tools = repository_rule(
    implementation = _llvm_tools_impl,
    local = True,
    attrs = {
        "version_file": attr.string(),
        "llvm": attr.label(),
        "build_dir": attr.string(mandatory = True),

        # "_ml_template": attr.label(
        #     default = "//src/backends/llvm_backend.ml.in"
        # ),
        # "_mli_template": attr.label(
        #     default = "//src/backends/llvm_backend.mli.in"
        # ),
        "targets": attr.string_list(
            doc = """Supported targets:
            AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, Lanai, Mips,
            MSP430, NVPTX, PowerPC, RISCV, Sparc, SystemZ,
            WebAssembly, X86, XCore.
            Special targets: ALL, host
            """
        ),
    },
)

################################################################
#### OCAML SDK repo rule ####
def _ocaml_sdk_impl(rctx):
    print("OCAML_SDK REPO RULE")

    rctx.file(
        "MODULE.bazel",
        content = """
module(
    name = "ocaml_llvm",
    version = "15.0.0",
    compatibility_level = 15,
)
"""
    )

    rctx.file(
        "BUILD.bazel",
        content = """
load("@cc_config//:MACROS.bzl", "repo_paths")

load("@bazel_skylib//rules:common_settings.bzl", "string_setting")

PROD_REPOS = [
    "@llvm_sdk//version",
    "@ocaml//version"
]

repo_paths(
    name = "repo_paths",
    repos = PROD_REPOS
)

repo_paths(
    name = "test_repo_paths",
    repos = PROD_REPOS + [
    ]
)
"""

    )

    rctx.symlink(rctx.attr.version_file,
                 "version/BUILD.bazel")
#     rctx.file(
#         "version/BUILD.bazel",
#         content = """
# load("@bazel_skylib//rules:common_settings.bzl",
#       "string_setting")

# string_setting(
#     name = "version", build_setting_default = "15.0.0",
#     visibility = ["//visibility:public"],
#     )
# """
#     )

    # rctx.workspace_root is the ws from which
    # the extension (& the repo rule) was called.
    # we symlink directories, which means
    # the build files we write will be written
    # to the original dirs. the will not be
    # removed by bazel clean.
    wsroot = rctx.workspace_root

    ## ocaml_sdk contains:
    ##  llvm-project/llvm/bindings/ocaml
    ##  llvm-project/llvm/test/Bindings/OCaml

    rctx.symlink("{root}/llvm/bindings/ocaml".format(
        root=wsroot), "src")

    rctx.symlink("{root}/llvm/test/Bindings/OCaml".format(
        root=wsroot), "test")

    ## end of _ocaml_sdk repo rule

############
_ocaml_sdk = repository_rule(
    implementation = _ocaml_sdk_impl,
    local = True,
    attrs = {
        "version_file": attr.string(),
        "llvm": attr.label(),
        "c_sdk": attr.label(),
        "build_dir": attr.string(mandatory = True),
        # "_ml_template": attr.label(
        #     default = "//src/backends/llvm_backend.ml.in"
        # ),
        # "_mli_template": attr.label(
        #     default = "//src/backends/llvm_backend.mli.in"
        # ),
        "targets": attr.string_list(
            doc = """Supported targets:
            AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, Lanai, Mips,
            MSP430, NVPTX, PowerPC, RISCV, Sparc, SystemZ,
            WebAssembly, X86, XCore.
            Special targets: ALL, host
            """
        ),
    },
)

##############
_sdk_attrs = {
    "version": attr.string(),
    "build_dir": attr.string(
        mandatory = True
    ),
    "targets": attr.string_list(
        doc = """Supported targets:
            AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, Lanai, Mips,
            MSP430, NVPTX, PowerPC, RISCV, Sparc, SystemZ,
            WebAssembly, X86, XCore.
            Special targets: ALL, host
            """
    )
}

#### TAG CLASSES ####
_c_sdk_tag = tag_class(attrs = _sdk_attrs)
_ocaml_sdk_tag = tag_class(attrs = _sdk_attrs)


#### EXTENSION IMPL ####
def _llvm_sdks_impl(mctx):
    print("LLVM_SDKS EXTENSION")

    # result = mctx.execute(["pwd"])
    # print("PWD: %s" % result.stdout)

    # result = mctx.execute(["env"])
    # print("PATH: %s" % result.stdout)

    # result = mctx.which("llvm-config")
    # print("which llvm-config: %s" % result)

    c_sdk = False
    c_sdk_version = None
    c_sdk_build_dir = None

    ocaml_sdk = False
    ocaml_sdk_version = None
    ocaml_sdk_build_dir = None

    # collect artifacts from across the dependency graph
    targets = []
    for mod in mctx.modules:
        print("XMOD name: %s" % mod.name)
        print("XMOD version: %s" % mod.version)
        print("XMOD is_root: %s" % mod.is_root)
        print("XMOD tags: %s" % mod.tags)
        # for d in dir(mod.tags):
        #     print("XMOD tag: %s" % d)
        #     a = getattr(mod.tags, d)
        #     for k in a:
        #         print("  attr: {}".format(k))

        for config in mod.tags.c:
            c_sdk = True
            print("C SDK config")
            c_sdk_build_dir = config.build_dir
            c_sdk_version = config.version
            for target in config.targets:
                print("TARGET: %s" % target)
                targets.append(target)

        for config in mod.tags.ocaml:
            print("OCAML SDK config")
            ocaml_sdk = True
            ocaml_sdk_build_dir = config.build_dir
            ocaml_sdk_version = config.version
            for target in config.targets:
                print("TARGET: %s" % target)
                targets.append(target)

    if c_sdk_version != ocaml_sdk_version:
        fail("Must use same version for all sdks")

    if c_sdk_build_dir != ocaml_sdk_build_dir:
        fail("Must use same build dir for all sdks")

    # mctx.file("WORKSPACE.bazel", content = "#test")
    # mctx.file("XXXXXXXXXXXXXXXXTEST", content = "#test")

    # share one version/BUILD.bazel across all sdks
    mctx.file(
        "VERSION.build",
        content = """
load("@bazel_skylib//rules:common_settings.bzl",
      "string_setting")

string_setting(
    name = "version", build_setting_default = "{}",
    visibility = ["//visibility:public"],
    )
""".format(c_sdk_version)
    )
    vfile = mctx.path("VERSION.build")
    print("VFILE: %s" % vfile)

    if c_sdk:
        _llvm_sdk(name = "llvm_sdk",
                  version_file = str(vfile),
                  build_dir = c_sdk_build_dir,
                  llvm = "@llvm",
                  targets = targets)
        _llvm_tools(name = "llvm_tools",
                    version_file = str(vfile),
                    build_dir = c_sdk_build_dir,
                    llvm = "@llvm",
                    targets = targets)

    if ocaml_sdk:
        _ocaml_sdk(name = "ocaml_llvm",
                  version_file = str(vfile),
                   build_dir = ocaml_sdk_build_dir,
                   llvm = "@llvm",
                   c_sdk = "@llvm_sdk",
                   targets = targets)

##############################
llvm_sdks = module_extension(
  implementation = _llvm_sdks_impl,
  tag_classes = {"c": _c_sdk_tag,
                 "ocaml": _ocaml_sdk_tag},
)
