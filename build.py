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
    "tools/uart_debug.py",
]
VHDL_FILE_TREE = {
    "hw/common/math_pkg.vhd": [],
    "hw/common/sync_bit.vhd": [],
    "hw/common/test_pkg.vhd": [],
    "hw/mem/wb_pkg.vhd": [],
    "hw/debug/tb_wb_debug.vhd": [
        "hw/gpu/sim_sram.vhd",
        "hw/debug/wb_debug.vhd",
        "hw/mem/wb_pkg.vhd",
        "hw/mem/wb_sram.vhd",
    ],
    "hw/debug/wb_debug.vhd": ["hw/common/math_pkg.vhd"],
    "hw/debug/wb_debug_uart.vhd": [
        "hw/debug/wb_debug.vhd",
        "hw/serial/uart_rx.vhd",
        "hw/serial/uart_tx.vhd",
    ],
    "hw/gpu/gpu.vhd": [
        "hw/gpu/gpu_pkg.vhd",
        "hw/mem/wb_arbiter.vhd",
        "hw/mem/wb_dma_to_fifo.vhd",
        "hw/gpu/vga.vhd",
    ],
    "hw/gpu/gpu_pkg.vhd": ["hw/common/math_pkg.vhd"],
    "hw/gpu/sim_sram.vhd": [],
    "hw/gpu/sim_vga.vhd": ["hw/common/test_pkg.vhd"],
    "hw/gpu/tb_gpu.vhd": [
        "hw/gpu/gpu.vhd",
        "hw/mem/wb_sram.vhd",
        "hw/gpu/sim_vga.vhd",
        "hw/gpu/sim_sram.vhd",
    ],
    "hw/gpu/vga.vhd": ["hw/gpu/gpu_pkg.vhd", "hw/common/math_pkg.vhd"],
    "hw/mem/wb_arbiter.vhd": [],
    "hw/mem/wb_dma_to_fifo.vhd": [],
    "hw/mem/wb_sram.vhd": [
        "hw/mem/wb_pkg.vhd",
    ],
    "hw/quartus/j63_toplevel.vhd": [
        "hw/quartus/sys_pll.vhd",
        "hw/quartus/vga_pll.vhd",
        "hw/gpu/gpu.vhd",
        "hw/mem/wb_pkg.vhd",
        "hw/mem/wb_sram.vhd",
        "hw/mem/wb_arbiter.vhd",
        "hw/sys/reset_gen.vhd",
        "hw/debug/wb_debug_uart.vhd",
        "hw/common/sync_bit.vhd",
    ],
    "hw/quartus/sys_pll.vhd": [],
    "hw/quartus/vga_fb_fifo.vhd": [],
    "hw/quartus/vga_pll.vhd": [],
    "hw/serial/tb_uart_rx.vhd": ["hw/serial/uart_rx.vhd"],
    "hw/serial/tb_uart_tx.vhd": ["hw/serial/uart_tx.vhd"],
    "hw/serial/uart_rx.vhd": ["hw/common/math_pkg.vhd"],
    "hw/serial/uart_tx.vhd": ["hw/common/math_pkg.vhd"],
    "hw/sys/reset_gen.vhd": [],
}
QUARTUS_PROJECT_FILES = [
    "hw/quartus/j63.qpf",
    "hw/quartus/j63.qsf",
    "hw/quartus/j63.sdc",
    "hw/quartus/j63_toplevel.vhd",
    "hw/quartus/sys_pll.qip",
    "hw/quartus/vga_pll.qip",
    "hw/quartus/vga_fb_fifo.qip",
]
VSG_EXCLUDED = [
    "hw/quartus/sys_pll.vhd",
    "hw/quartus/vga_pll.vhd",
    "hw/quartus/vga_fb_fifo.vhd",
]
GHDL_EXCLUDED = VSG_EXCLUDED
VSG_SOURCES = [x for x in VHDL_FILE_TREE.keys() if x not in VSG_EXCLUDED]
QUARTUS_EXCLUDED = [
    "hw/serial/tb_uart_rx.vhd",
    "hw/debug/tb_wb_debug.vhd",
    "hw/gpu/tb_gpu.vhd",
    "hw/gpu/sim_vga.vhd",
    "hw/gpu/sim_sram.vhd",
]
QUARTUS_SOURCES = [x for x in VHDL_FILE_TREE.keys() if x not in QUARTUS_EXCLUDED]
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

    for sby_file in SBY_FILES:
        define_sby(rule, dependencies, sby_file)

    rule("build/j63_nvc", mkdir, [])

    rule("build/j63_nvc/meta-run", nop, [])
    rule("build/j63_nvc/meta-elab", nop, [])

    gpu_cosim_meta = define_crate(rule, dependencies, "gpu-cosim", "hw/gpu/gpu-cosim/")
    gpu_sim_run_meta = define_simulation(
        rule,
        dependencies,
        name="tb_gpu",
        tb_file="hw/gpu/tb_gpu.vhd",
        run_args=["--load", "hw/gpu/gpu-cosim/target/release/libgpucosim.so"],
        need_quartus=True,
    )
    dependencies[gpu_sim_run_meta].append(gpu_cosim_meta)
    define_simulation(
        rule,
        dependencies,
        name="tb_uart_rx",
        tb_file="hw/serial/tb_uart_rx.vhd",
        run_args=[],
    )
    define_simulation(
        rule,
        dependencies,
        name="tb_uart_tx",
        tb_file="hw/serial/tb_uart_tx.vhd",
        run_args=[],
    )
    define_simulation(
        rule,
        dependencies,
        name="tb_wb_debug",
        tb_file="hw/debug/tb_wb_debug.vhd",
        run_args=[],
    )

    for source in (
        PYTHON_SOURCES + QUARTUS_PROJECT_FILES + list(VHDL_FILE_TREE.keys()) + SBY_FILES
    ):
        rule(source, file_exists, [])

    return Tasks(dependencies=dependencies, builders=builders)


def define_sby(rule, dependencies, sby_file):
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


def define_simulation(rule, dependencies, name, tb_file, run_args, need_quartus=False):
    vhdl_sources = transitive_closure(tb_file, VHDL_FILE_TREE)
    if need_quartus:
        rule(f"build/j63_nvc/{name}/meta-quartus", nvc_quartus_install, [])
        vhdl_sources += [f"build/j63_nvc/{name}/meta-quartus"]

    rule(
        f"build/j63_nvc/{name}/meta-analyzed",
        nvc_analyze,
        vhdl_sources,
    )
    rule(
        f"build/j63_nvc/{name}/meta-elab",
        lambda **kwargs: nvc_elaborate(toplevel=name, **kwargs),
        [f"build/j63_nvc/{name}/meta-analyzed"],
    )
    run_meta = f"build/j63_nvc/{name}/meta-run"
    rule(
        run_meta,
        lambda **kwargs: nvc_run(toplevel=name, run_args=run_args, **kwargs),
        [f"build/j63_nvc/{name}/meta-elab"],
    )
    dependencies["build/j63_nvc/meta-run"].append(run_meta)
    dependencies["build/j63_nvc/meta-elab"].append(f"build/j63_nvc/{name}/meta-elab")
    rule(f"sim-{name}", nop, [run_meta])
    rule(
        f"waves-{name}",
        lambda **kwargs: run(["gtkwave", f"build/j63_nvc/{name}/{name}.fst"]),
        [],
    )
    return run_meta


def define_crate(rule, dependencies, name, path):
    path = pathlib.Path(path)
    sources = list((path / "src").rglob("*.rs")) + [
        path / "Cargo.toml",
        path / "Cargo.lock",
    ]
    meta_file = pathlib.Path(f"build/crates/meta-{name}")
    meta_file.parent.mkdir(parents=True, exist_ok=True)

    def build_crate(**kwargs):
        run(["cargo", "build", "--release"], cwd=path)
        touch(meta_file)

    for src in sources:
        rule(src, file_exists, [])

    rule(meta_file, build_crate, sources)

    rule(f"format-{name}", lambda **kwargs: run(["cargo", "fmt"], cwd=path), [])
    dependencies["format"].append(f"format-{name}")

    return meta_file


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
    config = {"libraries": {"j63": {"files": list(VHDL_FILE_TREE.keys())}}}
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

    vhdl_files = [x for x in src_files if x.suffix == ".vhd"]
    vhdl_files = [x for x in vhdl_files if str(x) not in GHDL_EXCLUDED]
    src_files = [x for x in src_files if x not in vhdl_files]
    vhdl_to_verilog(
        top_level="j63_toplevel",
        output_file=f"{build_dir}/j63_toplevel.v",
        input_files=[str(x) for x in vhdl_files],
        **kwargs,
    )
    src_files.append(build_dir / "j63_toplevel.v")

    qsf_contents = qsf_file.read_text()
    for src_file in src_files:
        if src_file.suffix == ".vhd":
            type_ = "VHDL_FILE"
        elif src_file.suffix == ".v":
            type_ = "VERILOG_FILE"
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


def vhdl_to_verilog(top_level, output_file, input_files, **kwargs):
    oss_cad_run(
        [
            "yosys",
            "-m",
            "ghdl",
            "-p",
            f"ghdl --std=08 {' '.join(input_files)} -e {top_level}; check; opt; write_verilog {output_file}",
        ]
    )


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
    build_dir.mkdir(exist_ok=True, parents=True)
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
    run_args = kwargs.get("run_args", [])
    run(
        [
            "nvc",
            f"--work=j63:{build_dir}/j63",
            "-L",
            str(build_dir),
            "--std=2008",
            "-r",
        ]
        + run_args
        + [
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


def transitive_closure(root, nodes):
    all_deps = []
    new_deps = [root]
    while new_deps:
        all_deps.extend(new_deps)
        next_deps = []
        for new_dep in new_deps:
            next_deps.extend(nodes[new_dep])
        new_deps = next_deps
    all_deps.reverse()
    result = []
    for dep in all_deps:
        if dep not in result:
            result.append(dep)
    return result


if __name__ == "__main__":
    main()
