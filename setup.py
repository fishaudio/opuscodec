import os
import platform
import re
import subprocess
from pathlib import Path

from pybind11.setup_helpers import Pybind11Extension, build_ext
from setuptools import setup

ROOT = Path(__file__).resolve().parent


def read_project_version() -> str:
    pyproject = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"\s*$', pyproject, re.MULTILINE)
    if not match:
        raise RuntimeError("Could not determine package version from pyproject.toml")
    return match.group(1)


__version__ = read_project_version()


class OpusCodecBuildExt(build_ext):
    def build_extensions(self):
        use_system_deps = os.environ.get("OPUSCODEC_USE_SYSTEM_DEPS", "0") == "1"
        qext_requested = os.environ.get("OPUSCODEC_ENABLE_QEXT", "1") != "0"

        include_dirs = []
        library_dirs = []
        qext_enabled = qext_requested

        if not use_system_deps:
            platform_tag = f"{platform.system().lower()}-{platform.machine().lower()}"
            deps_prefix = Path(
                os.environ.get("OPUSCODEC_DEPS_PREFIX", ROOT / "build" / "deps" / platform_tag)
            ).resolve()
            build_script = ROOT / "scripts" / "build_deps.sh"
            env = os.environ.copy()
            env.setdefault("OPUSCODEC_ENABLE_QEXT", "1" if qext_requested else "0")
            env.setdefault("OPUSCODEC_WITH_OPUS_TOOLS", "0")
            subprocess.check_call(["bash", str(build_script), str(deps_prefix)], cwd=ROOT, env=env)
            include_dirs.append(str(deps_prefix / "include"))
            include_dirs.append(str(deps_prefix / "include" / "opus"))
            library_dirs.append(str(deps_prefix / "lib"))
            qext_enabled = (deps_prefix / ".qext-enabled").exists()

        libraries = ["opusenc", "opusfile", "opus", "ogg"]
        if platform.system() == "Linux":
            libraries.append("m")

        for ext in self.extensions:
            ext.include_dirs.extend(include_dirs)
            ext.library_dirs.extend(library_dirs)
            ext.libraries.extend(libraries)
            ext.define_macros.append(("OPUSCODEC_QEXT_ENABLED", "1" if qext_enabled else "0"))

        super().build_extensions()


ext_modules = [
    Pybind11Extension(
        "opuscodec",
        ["src/opuscodec_bindings.cpp"],
        define_macros=[("VERSION_INFO", __version__)],
        cxx_std=17,
    ),
]

setup(
    ext_modules=ext_modules,
    cmdclass={"build_ext": OpusCodecBuildExt},
    zip_safe=False,
)
