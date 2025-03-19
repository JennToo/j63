#!/usr/bin/env python3
import argparse
import concurrent.futures
import dataclasses
import graphlib
import logging
import multiprocessing
import os
import pathlib
import shutil
import subprocess
import sys

import tomli_w


@dataclasses.dataclass
class Tasks:
    dependencies: dict
    builders: dict


PYTHON_SOURCES = [
    "build.py",
]
QUARTUS_PROJECT_FILES = [
    "hw/quartus/j63.qpf",
    "hw/quartus/j63.qsf",
    "hw/quartus/j63.sdc",
    "hw/quartus/j63_toplevel.vhd",
    "hw/quartus/sys_pll.qip",
    "hw/quartus/vga_pll.qip",
    "hw/quartus/vga_fb_fifo.qip",
]
VHDL_SOURCES = [
    "hw/common/math_pkg.vhd",
    "hw/common/test_pkg.vhd",
    "hw/mem/wb_sram.vhd",
    "hw/mem/wb_dma_to_fifo.vhd",
    "hw/gpu/gpu_pkg.vhd",
    "hw/quartus/vga_fb_fifo.vhd",
    "hw/gpu/vga.vhd",
    "hw/gpu/sim_vga.vhd",
    "hw/gpu/sim_sram.vhd",
    "hw/gpu/gpu.vhd",
    "hw/gpu/tb_gpu.vhd",
    "hw/quartus/sys_pll.vhd",
    "hw/quartus/vga_pll.vhd",
    "hw/quartus/j63_toplevel.vhd",
]
VSG_EXCLUDED = [
    "hw/quartus/sys_pll.vhd",
    "hw/quartus/vga_pll.vhd",
    "hw/quartus/vga_fb_fifo.vhd",
]
VSG_SOURCES = [x for x in VHDL_SOURCES if x not in VSG_EXCLUDED]
QUARTUS_EXCLUDED = [
    "hw/gpu/tb_gpu.vhd",
    "hw/gpu/sim_vga.vhd",
    "hw/gpu/sim_sram.vhd",
]
QUARTUS_SOURCES = [x for x in VHDL_SOURCES if x not in QUARTUS_EXCLUDED]
SBY_FILES = ["hw/mem/wb_sram.sby"]


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
    logging.info("Starting build")
    args = parse_args()

    write_vhdl_ls()

    tasks = build_task_graph()
    if args.task:
        requested_tasks = args.task
    else:
        requested_tasks = ["all"]
    tasks = filter_tasks(tasks, requested_tasks)
    task_iter = graphlib.TopologicalSorter(tasks.dependencies)

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=multiprocessing.cpu_count() / 2
    ) as executor:

        def run_task(task):
            if task not in tasks.builders:
                fatal(f"No rule to make {task}")
            dependencies = tasks.dependencies[task]
            if task_up_to_date(task, dependencies):
                logging.info(f"{task} up to date")
                return task
            tasks.builders[task](task=task, dependencies=dependencies)
            return task

        task_iter.prepare()
        open_futures = set()
        while task_iter.is_active():
            for task in task_iter.get_ready():
                open_futures.add(executor.submit(run_task, task))

            futures = concurrent.futures.wait(
                open_futures, return_when=concurrent.futures.FIRST_COMPLETED
            )
            open_futures = futures.not_done
            for completed in futures.done:
                task_iter.done(completed.result())


def build_task_graph():
    dependencies = {}
    builders = {}

    def rule(name, builder, deps):
        builders[name] = builder
        dependencies[name] = deps

    rule(
        "all",
        nop,
        [
            "build/meta-vsg-check",
            "build/meta-black-check",
            "build/meta-ruff-check",
            "build/j63_quartus/meta-built",
            "build/j63_nvc/meta-run",
        ],
    )
    rule("format", nop, ["vsg-fix", "black-fix", "ruff-fix"])
    rule("sim", nop, ["build/j63_nvc/meta-run"])
    rule("build/meta-black-check", black_check, PYTHON_SOURCES)
    rule("build/meta-ruff-check", ruff_check, PYTHON_SOURCES)
    rule("build/meta-vsg-check", vsg_check, VSG_SOURCES)
    rule(
        "black-fix",
        lambda dependencies, **kwargs: run(["black"] + dependencies),
        PYTHON_SOURCES,
    )
    rule(
        "ruff-fix",
        lambda dependencies, **kwargs: run(["ruff", "check", "--fix"] + dependencies),
        PYTHON_SOURCES,
    )
    rule(
        "vsg-fix",
        lambda dependencies, **kwargs: run(
            ["vsg", "-c", "vsg.yaml", "--fix"] + dependencies
        ),
        VSG_SOURCES,
    )
    rule(
        "build/j63_quartus/meta-built",
        build_quartus_project,
        QUARTUS_PROJECT_FILES + QUARTUS_SOURCES + ["build/j63_quartus"],
    )
    rule("build/j63_quartus", mkdir, [])
    rule(
        "quartus-j63",
        lambda **kwargs: run(
            [f"{os.environ["QUARTUS_ROOTDIR"]}/bin/quartus", "j63"],
            cwd="build/j63_quartus",
        ),
        ["build/j63_quartus/meta-built"],
    )
    rule(
        "program",
        lambda **kwargs: run(
            [
                f"{os.environ["QUARTUS_ROOTDIR"]}/bin/quartus_pgm",
                "--cable=1",
                "--mode=jtag",
                "-o",
                "p;./build/j63_quartus/j63.sof@1",
            ],
        ),
        ["build/j63_quartus/meta-built"],
    )

    rule("formal", nop, [])

    def define_sby(sby_file):
        sby_path = pathlib.Path(sby_file)
        name = pathlib.Path(sby_path).name.split(".")[0]
        target = f"build/formal/meta-run-{name}"
        prefix = f"build/formal/{name}"

        sby_contents = sby_path.read_text(encoding="utf-8").splitlines(keepends=False)
        file_section_start = sby_contents.index("[files]")
        file_deps = sby_contents[file_section_start + 1 :]
        for source in file_deps:
            rule(source, file_exists, [])

        rule(
            target,
            lambda **kwargs: sby_run(sby_file=sby_file, prefix=prefix, **kwargs),
            [sby_file] + file_deps,
        )
        dependencies["formal"].append(target)

    for sby_file in SBY_FILES:
        define_sby(sby_file)

    rule("build/j63_nvc/meta-quartus", nvc_quartus_install, ["build/j63_nvc"])
    rule(
        "build/j63_nvc/meta-analyzed",
        nvc_analyze,
        VHDL_SOURCES + ["build/j63_nvc/meta-quartus"],
    )
    rule("build/j63_nvc", mkdir, [])

    rule("build/j63_nvc/meta-run", nop, [])
    rule("build/j63_nvc/meta-elab", nop, [])

    def define_simulation(name):
        rule(
            f"build/j63_nvc/meta-elab-{name}",
            lambda **kwargs: nvc_elaborate(toplevel=name, **kwargs),
            ["build/j63_nvc/meta-analyzed"],
        )
        rule(
            f"build/j63_nvc/meta-run-{name}",
            lambda **kwargs: nvc_run(toplevel=name, **kwargs),
            [f"build/j63_nvc/meta-elab-{name}"],
        )
        dependencies["build/j63_nvc/meta-run"].append(f"build/j63_nvc/meta-run-{name}")
        dependencies["build/j63_nvc/meta-elab"].append(
            f"build/j63_nvc/meta-elab-{name}"
        )
        rule(
            f"waves-{name}",
            lambda **kwargs: run(["gtkwave", f"build/j63_nvc/{name}.fst"]),
            [],
        )

    define_simulation("tb_gpu")

    for source in PYTHON_SOURCES + QUARTUS_PROJECT_FILES + VHDL_SOURCES + SBY_FILES:
        rule(source, file_exists, [])

    return Tasks(dependencies=dependencies, builders=builders)


def filter_tasks(tasks, requested):
    tasks_to_check = set(requested)
    tasks_to_keep = set()

    while tasks_to_check:
        next_tasks_to_check = set()
        for task in tasks_to_check:
            if task not in tasks.dependencies:
                fatal(f"No rule to make {task}")
            for dep in tasks.dependencies[task]:
                next_tasks_to_check.add(dep)
        tasks_to_keep.update(tasks_to_check)
        tasks_to_check = next_tasks_to_check

    return Tasks(
        dependencies={
            key: value
            for key, value in tasks.dependencies.items()
            if key in tasks_to_keep
        },
        builders=tasks.builders,
    )


def task_up_to_date(task, dependencies):
    if all(os.path.exists(x) for x in [task] + dependencies):
        task_stat = os.stat(task)
        dep_stats = [os.stat(x) for x in dependencies if not os.path.isdir(x)]
        if all(task_stat.st_mtime >= dep.st_mtime for dep in dep_stats):
            return True
    return False


def write_vhdl_ls():
    config = {"libraries": {"j63": {"files": VHDL_SOURCES}}}
    pathlib.Path("vhdl_ls.toml").write_text(tomli_w.dumps(config))


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("task", nargs="*")
    return parser.parse_args()


def file_exists(dependencies, **kwargs):
    for file_ in dependencies:
        if not os.path.exists(file_):
            fatal(f"No rule to make {file_}")


def mkdir(task, **kwargs):
    os.makedirs(task, exist_ok=True)


def nop(**kwargs):
    return


def black_check(task, dependencies, **kwargs):
    run(["black", "--check"] + dependencies)
    touch(task)


def ruff_check(task, dependencies, **kwargs):
    run(["ruff", "check"] + dependencies)
    touch(task)


def vsg_check(task, dependencies, **kwargs):
    run(["vsg", "-c", "vsg.yaml", "--"] + dependencies)
    touch(task)


def build_quartus_project(task, dependencies, **kwargs):
    build_dir = pathlib.Path(task).parent
    qsf_file = None
    qpf_file = None
    src_files = []
    for dep in dependencies:
        if dep.endswith(".vhd") or dep.endswith(".sdc") or dep.endswith(".qip"):
            src_files.append(pathlib.Path(dep))
        elif dep.endswith(".qsf"):
            qsf_file = pathlib.Path(dep)
        elif dep.endswith(".qpf"):
            qpf_file = pathlib.Path(dep)

    qsf_contents = qsf_file.read_text()
    for src_file in src_files:
        if src_file.suffix == ".vhd":
            type_ = "VHDL_FILE"
        elif src_file.suffix == ".sdc":
            type_ = "SDC_FILE"
        elif src_file.suffix == ".qip":
            type_ = "QIP_FILE"
        else:
            fatal(f"Unknown src file type {src_file}")
        qsf_contents += f"set_global_assignment -name {type_} {src_file.absolute()}\n"

    build_qsf_file = build_dir / qsf_file.name
    build_qsf_file.write_text(qsf_contents)
    shutil.copy(qpf_file, build_dir / qpf_file.name)

    quartus = os.environ["QUARTUS_ROOTDIR"]
    project = qsf_file.stem
    run([f"{quartus}/bin/quartus_sh", "--prepare", project], cwd=build_dir)
    run(
        [
            f"{quartus}/bin/quartus_map",
            "--read_settings_files=on",
            "--write_settings_files=off",
            project,
            "-c",
            project,
        ],
        cwd=build_dir,
    )
    run(
        [
            f"{quartus}/bin/quartus_fit",
            "--read_settings_files=on",
            "--write_settings_files=off",
            project,
            "-c",
            project,
        ],
        cwd=build_dir,
    )
    run(
        [
            f"{quartus}/bin/quartus_asm",
            "--read_settings_files=on",
            "--write_settings_files=off",
            project,
            "-c",
            project,
        ],
        cwd=build_dir,
    )
    run([f"{quartus}/bin/quartus_sta", project, "-c", project], cwd=build_dir)

    touch(task)


def sby_run(sby_file, prefix, task, **kwargs):
    oss_cad_run(
        [
            "sby",
            "--yosys",
            "yosys -m ghdl",
            "-f",
            "--prefix",
            prefix,
            sby_file,
        ]
    )
    touch(task)


def nvc_quartus_install(task, **kwargs):
    build_dir = pathlib.Path(task).parent

    env = os.environ.copy()
    env["NVC_INSTALL_DEST"] = str(build_dir.absolute())
    run(["nvc", "--install", "quartus"], cwd=build_dir, env=env)

    touch(task)


def nvc_analyze(task, dependencies, **kwargs):
    build_dir = pathlib.Path(task).parent
    mkdir(build_dir)
    run(
        ["nvc", f"--work=j63:{build_dir}/j63", "-L", str(build_dir), "--std=2008", "-a"]
        + [x for x in dependencies if x.endswith(".vhd")]
    )
    touch(task)


def nvc_elaborate(toplevel, task, **kwargs):
    build_dir = pathlib.Path(task).parent
    run(
        [
            "nvc",
            f"--work=j63:{build_dir}/j63",
            "-L",
            str(build_dir),
            "--std=2008",
            "-e",
            toplevel,
        ]
    )
    touch(task)


def nvc_run(toplevel, task, **kwargs):
    build_dir = pathlib.Path(task).parent
    run(
        [
            "nvc",
            f"--work=j63:{build_dir}/j63",
            "-L",
            str(build_dir),
            "--std=2008",
            "-r",
            "--ieee-warnings=off",
            f"--wave={build_dir}/{toplevel}.fst",
            f"--gtkw={build_dir}/{toplevel}.gtkw",
            toplevel,
        ]
    )
    touch(task)


def touch(path):
    mkdir(pathlib.Path(path).parent)
    pathlib.Path(path).write_text("")


def oss_cad_run(cmd, cwd=None):
    cad_root = os.environ["OSS_CAD_ROOTDIR"]

    env = os.environ.copy()
    env["PATH"] = f"{cad_root}/bin:{cad_root}/py3bin:{env['PATH']}"
    env["GHDL_PREFIX"] = f"{cad_root}/lib/ghdl"
    env["VERILATOR_ROOT"] = f"{cad_root}/share/verilator"
    env["VIRTUAL_ENV"] = cad_root

    run(cmd, cwd=cwd, env=env)


def run(cmd, cwd=None, env=None):
    logging.info(" ".join(cmd))
    result = subprocess.run(cmd, check=False, cwd=cwd, env=env)
    if result.returncode != 0:
        fatal("Command failed: " + " ".join(cmd), result.returncode)


def fatal(message, code=1):
    logging.error(message)
    sys.exit(code)


if __name__ == "__main__":
    main()
