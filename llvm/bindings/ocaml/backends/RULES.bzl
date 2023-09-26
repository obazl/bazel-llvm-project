def _llvm_gensrc_impl(ctx):

    print("VAR: %s" % ctx.var["LLVM_TARGET_ARCH"])

    ctx.actions.expand_template(
        template = ctx.file.template,
        output = ctx.outputs.out,
        substitutions = {"@TARGET@": ctx.var["LLVM_TARGET_ARCH"]},
        is_executable = False
    )

################
llvm_gensrc = rule(
    implementation = _llvm_gensrc_impl,
    attrs = {
        "template": attr.label(
            allow_single_file = True,
            mandatory=True
        ),
        # "target": attr.string(),
        "out": attr.output(mandatory=True),
    }
)
