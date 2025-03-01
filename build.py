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
]
VHDL_SOURCES = [
    "hw/quartus/j63_toplevel.vhd",
]


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
    logging.info("Starting build")
    args = parse_args()

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
            if all(os.path.exists(x) for x in [task] + dependencies):
                task_stat = os.stat(task)
                dep_stats = [os.stat(x) for x in dependencies]
                if all(task_stat.st_mtime >= dep.st_mtime for dep in dep_stats):
                    logging.info(f"{task} up to date")
                    return task
            tasks.builders[task](task=task, dependencies=dependencies)
            return task

        task_iter.prepare()
        open_futures = set()
        while task_iter.is_active():
            for task in task_iter.get_ready():
                open_futures.add(executor.submit(run_task, task))

            futures = concurrent.futures.wait(open_futures)
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
        ["vsg-check", "black-check", "ruff-check", "build/j63_quartus/meta-built"],
    )
    rule("format", nop, ["vsg-fix", "black-fix", "ruff-fix"])
    rule(
        "black-check",
        lambda dependencies, **kwargs: run(["black", "--check"] + dependencies),
        PYTHON_SOURCES,
    )
    rule(
        "ruff-check",
        lambda dependencies, **kwargs: run(["ruff", "check"] + dependencies),
        PYTHON_SOURCES,
    )
    rule(
        "vsg-check",
        lambda dependencies, **kwargs: run(["vsg"] + dependencies),
        VHDL_SOURCES,
    )
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
        lambda dependencies, **kwargs: run(["vsg", "--fix"] + dependencies),
        VHDL_SOURCES,
    )
    rule(
        "build/j63_quartus/meta-built",
        build_quartus_project,
        QUARTUS_PROJECT_FILES + ["build/j63_quartus"],
    )
    rule("build/j63_quartus", mkdir, [])

    for source in PYTHON_SOURCES + QUARTUS_PROJECT_FILES:
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


def build_quartus_project(task, dependencies, **kwargs):
    build_dir = pathlib.Path(task).parent
    qsf_file = None
    qpf_file = None
    src_files = []
    for dep in dependencies:
        if dep.endswith(".vhd") or dep.endswith(".sdc"):
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
        else:
            fatal(f"Unknown src file type {src_file}")
        qsf_contents += f"set_global_assignment -name {type_} {src_file.absolute()}\n"

    build_qsf_file = build_dir / qsf_file.name
    build_qsf_file.write_text(qsf_contents)
    shutil.copy(qpf_file, build_dir / qpf_file.name)

    quartus = os.environ["QUARTUS_ROOTDIR"]
    project = qsf_file.stem
    run([f"{quartus}/quartus_sh", "--prepare", project], cwd=build_dir)
    run(
        [
            f"{quartus}/quartus_map",
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
            f"{quartus}/quartus_fit",
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
            f"{quartus}/quartus_asm",
            "--read_settings_files=on",
            "--write_settings_files=off",
            project,
            "-c",
            project,
        ],
        cwd=build_dir,
    )
    run([f"{quartus}/quartus_sta", project, "-c", project], cwd=build_dir)

    touch(task)


def touch(path):
    pathlib.Path(path).write_text("")


def run(cmd, cwd=None):
    logging.info(" ".join(cmd))
    result = subprocess.run(cmd, check=False, cwd=cwd)
    if result.returncode != 0:
        fatal("Command failed: " + " ".join(cmd), result.returncode)


def fatal(message, code=1):
    logging.error(message)
    sys.exit(code)


if __name__ == "__main__":
    main()
