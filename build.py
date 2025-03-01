#!/usr/bin/env python3
import argparse
import concurrent.futures
import dataclasses
import graphlib
import logging
import os
import subprocess
import sys
import multiprocessing


@dataclasses.dataclass
class Tasks:
    dependencies: dict
    builders: dict


PYTHON_SOURCES = [
    "build.py",
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
                logging.error(f"No rule to make {task}")
                sys.exit(1)
            tasks.builders[task](tasks.dependencies[task])
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

    rule("all", nop, ["black-check", "ruff-check"])
    rule("format", nop, ["black-fix", "ruff-fix"])
    rule("black-check", lambda deps: run(["black", "--check"] + deps), PYTHON_SOURCES)
    rule("ruff-check", lambda deps: run(["ruff", "check"] + deps), PYTHON_SOURCES)
    rule("black-fix", lambda deps: run(["black"] + deps), PYTHON_SOURCES)
    rule(
        "ruff-fix", lambda deps: run(["ruff", "check", "--fix"] + deps), PYTHON_SOURCES
    )
    for python_source in PYTHON_SOURCES:
        rule(python_source, file_exists, [])

    return Tasks(dependencies=dependencies, builders=builders)


def filter_tasks(tasks, requested):
    tasks_to_check = set(requested)
    tasks_to_keep = set()

    while tasks_to_check:
        next_tasks_to_check = set()
        for task in tasks_to_check:
            if task not in tasks.dependencies:
                logging.error(f"No rule to make {task}")
                sys.exit(1)
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


def file_exists(paths):
    for path in paths:
        if not os.path.exists(path):
            logging.error(f"No rule to make {path}")
            sys.exit(1)


def nop(paths):
    return


def run(cmd):
    logging.info(" ".join(cmd))
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        logging.error("Command failed: " + " ".join(cmd))
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
