"""Custom Bazel rule to register an arbitrary resource in the ament index.

This works by placing the resource file at the exact path expected by
ament_index_cpp/ament_index_python inside the runfiles directory of the test.
"""

def _register_ament_resource_impl(ctx):
    resource_file = ctx.actions.declare_file(ctx.label.name + "_resource")
    ctx.actions.write(
        output = resource_file,
        content = ctx.attr.content,
    )
    symlinks = {}
    path = "share/ament_index/resource_index/{category}/{package}".format(
        category = ctx.attr.category,
        package = ctx.attr.package_name if ctx.attr.package_name else ctx.label.workspace_name.removesuffix("+"),
    )
    symlinks[path] = resource_file
    return [
        DefaultInfo(
            files = depset([resource_file]),
            runfiles = ctx.runfiles(symlinks = symlinks),
        ),
    ]

register_ament_resource = rule(
    implementation = _register_ament_resource_impl,
    attrs = {
        "category": attr.string(mandatory = True),
        "content": attr.string(mandatory = True),
        "package_name": attr.string(),
    },
)

def _register_ament_files_impl(ctx):
    symlinks = {}
    for f in ctx.files.files:
        rel_path = f.short_path
        if rel_path.startswith("../"):
            parts = rel_path.split("/")
            rel_path = "/".join(parts[2:])
        else:
            pkg_prefix = ctx.label.package + "/"
            if pkg_prefix != "/" and rel_path.startswith(pkg_prefix):
                rel_path = rel_path[len(pkg_prefix):]
        if ctx.attr.strip_prefix:
            prefix = ctx.attr.strip_prefix
            if not prefix.endswith("/"):
                prefix += "/"
            if rel_path.startswith(prefix):
                rel_path = rel_path[len(prefix):]
        path = "share/{package}/{rel_path}".format(
            package = ctx.attr.package_name if ctx.attr.package_name else ctx.label.workspace_name.removesuffix("+"),
            rel_path = rel_path,
        )
        symlinks[path] = f
    return [
        DefaultInfo(
            files = depset(ctx.files.files),
            runfiles = ctx.runfiles(symlinks = symlinks),
        ),
    ]

register_ament_files = rule(
    implementation = _register_ament_files_impl,
    attrs = {
        "files": attr.label_list(allow_files = True, mandatory = True),
        "strip_prefix": attr.string(),
        "package_name": attr.string(),
    },
)
