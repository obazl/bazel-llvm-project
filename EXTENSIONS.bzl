load(":libs.bzl", "genlibsmap")

# llvm_targets extension
# for each TARGET, uses rctx.template to generate

# info on targets: llvm-project/docs/GettingStarted.rst

################################################################
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

#### repo rule ####
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

    # rctx.workspace_root is the ws from which
    # the extension (& the repo rule) was called.
    # we symlink directories, which means
    # the build files we write will be written
    # to the original dirs. the will not be
    # removed by bazel clean.
    wsroot = rctx.workspace_root
    bld = ".build.15.0.0"

    ## bin dir same for all sdks
    rctx.symlink("{root}/{bld}/bin".format(root=wsroot,bld=bld),
                 "sdk/bin")

    rctx.symlink("{root}/{bld}/include/llvm".format(root=wsroot,bld=bld),
                 "sdk/c/include/llvm")

    # rctx.symlink("{root}/llvm/include/llvm".format(root=wsroot,bld=bld),
    #              "sdk/c/include/llvm")

    rctx.symlink("{root}/llvm/include/llvm-c".format(root=wsroot,bld=bld),
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
    rctx.symlink("{root}/libcxx/include".format(root=wsroot,bld=bld),
                 "sdk/c++/include")

    rctx.symlink("{root}/{bld}/lib".format(root=wsroot,bld=bld),
                 "sdk/c/lib")
    rctx.symlink("{root}/{bld}/libexec".format(root=wsroot,bld=bld),
                 "sdk/c/libexec")

    libsmap = genlibsmap(rctx)
    rctx.template(
        "sdk/c/lib/BUILD.bazel",
        Label(":BUILD.lib_pkg"),
        substitutions = libsmap,
        executable = False,
    )

    # rctx.symlink("libexec", "sdk/c/libexec")

    # rctx.file(
    #     "lib/BUILD.bazel",
    #     content = "#"
    # )

    rctx.file(
        "version/BUILD.bazel",
        content = """
load("@bazel_skylib//rules:common_settings.bzl",
      "string_setting")

string_setting(
    name = "version", build_setting_default = "15.0.0",
    visibility = ["//visibility:public"],
    )
"""
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

    supported = [
        "AArch64", "AMDGPU", "ARM", "AVR", "BPF",
        "Hexagon", "Lanai", "Mips", "MSP430", "NVPTX",
        "PowerPC", "RISCV", "Sparc", "SystemZ",
        "WebAssembly", "X86", "XCore",
    ]

#     content = """
# load(\"@rules_ocaml//build:rules.bzl\", \"ocaml_module\")

# """
#     selectors = ""
#     for target in supported:
#         selector = """
#         "//target:{}": "llvm_{}.ml",
#         "//host:{}": "llvm_{}.ml",
#         """.format(target, target, target, target)
#         selectors = selectors + selector

#     m = "\n".join([
#          "ocaml_module(",
#          "    name   = \"Backend\",",
#          "    struct = select({",
#          selectors,
#          "    }),",
#          "    deps   = [",
#          "        # \"//src/llvm:Llvm\"",
#          "        \"//src/backends:backend_c\"",
#          "    ]",
#          ")\n"
#     ])

#     # content = content + m

#     for target in supported:
#         module = "\n".join([
#             "ocaml_module(",
#             "    name   = \"{T}\",",
#             "    struct = \"llvm_{T}.ml\",",
#             "    deps   = [",
#             "        # \"//src/llvm:Llvm\"",
#             "        \"//src/backends:backend_c\"",
#             "    ]",
#             ")\n"
#         ]).format(T=target)
#         content = content + module

#     rctx.file(
#         "backends/BUILD.bazel",
#         content = content
#     )

        # rctx.template(
        #     "backends/llvm_{}.ml".format(target), # output
        #     Label("//src/backends:BUILD.template"),
        #     substitutions = {"@TARGET@": target},
        #     executable = False,
        # )

    # if "ALL" in rctx.attr.targets:
    #     print("EMITTING ALL TARGETS")
    #     for target in supported:
    #         rctx.template(
    #             "backends/llvm_{}.ml".format(target), # output
    #             Label("//src/backends:llvm_backend.ml.in"),
    #             substitutions = {"@TARGET@": target},
    #             executable = False,
    #         )

    # elif "host" in  rctx.attr.targets:
    #     print("EMITTING HOST TARGET")
    # else:
    #     print("EMITTING TARGETS")
    #     for target in rctx.attr.targets:
    #         if target not in supported:
    #             if target not in ["ALL", "host"]:
    #                 supported.extend(["ALL", "host"])
    #                 print("Supported targets: %s" % supported)
    #                 fail("Bad target: %s" % target)
    #         rctx.template(
    #             "backends/llvm_{}.ml".format(target), # output
    #             Label("//src/backends:llvm_backend.ml.in"),
    #             substitutions = {"@TARGET@": target},
    #             executable = False,
    #         )
## end _llvm_sdk_impl

############
_llvm_sdk = repository_rule(
    implementation = _llvm_sdk_impl,
    local = True,
    attrs = {
        "llvm": attr.label(),
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
## TAG CLASSES
_config = tag_class(
    attrs = {
        "targets": attr.string_list(
            doc = """Supported targets:
            AArch64, AMDGPU, ARM, AVR, BPF, Hexagon, Lanai, Mips,
            MSP430, NVPTX, PowerPC, RISCV, Sparc, SystemZ,
            WebAssembly, X86, XCore.
            Special targets: ALL, host
            """
        ),
    }
)

#### EXTENSION IMPL ####
def _llvm_sdk_extension_impl(module_ctx):

  print("LLVM_SDK EXTENSION")

  # collect artifacts from across the dependency graph
  targets = []
  for mod in module_ctx.modules:
      for config in mod.tags.config:
          for target in config.targets:
              print("TARGET: %s" % target)
              targets.append(target)

  _llvm_sdk(name = "llvm_sdk",
            llvm = "@llvm",
            targets = targets)

##############################
llvm_sdk = module_extension(
  implementation = _llvm_sdk_extension_impl,
  tag_classes = {"config": _config},
)
