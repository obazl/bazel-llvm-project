def genlibsmap(rctx):

    libsmap = {}

    stanzas = ""

    ## every component
    components = rctx.execute(["./sdk/bin/llvm-config",
                               "--link-static",
                               "--components"])

    for component in components.stdout.strip().split(" "):
        libs = rctx.execute(["./sdk/bin/llvm-config",
                             "--link-static",
                             "--libs",
                             component])
        # print("COMP: %s" % component)

        liblist = ["\"lib" + lib[2:] + ".a\"" for lib in libs.stdout.strip().split(" ")]

        stanza = """
cc_library(name = "{c}-libs",
           srcs = [{libs}])
""".format(c=component,
           libs= ", ".join(liblist))

        stanzas = stanzas + stanza

    libsmap["{{COMPONENTS}}"] = stanzas

    stanzas = ""
    ## every lib
    libs = rctx.execute(["./sdk/bin/llvm-config", "--link-static",
                         "--libs"])
    if libs.return_code != 0:
        print("ERROR llvm-config --link-static --libs: %s" % libs.stderr)

    for lib in libs.stdout.strip().split(" "):
        libname = "lib" + lib[2:]
        filename = libname + ".a"
        stanza = """
cc_import(name = "{libname}",
          static_library = "{fname}")
""".format(libname=libname, fname = filename)
        stanzas = stanzas + stanza

    libsmap["{{EVERY_LIB}}"] = stanzas

    return libsmap
