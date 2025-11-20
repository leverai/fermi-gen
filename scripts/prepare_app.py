"""Prepare a standalone application directory by bundling source code
and packaging all dependencies, including internal workspace packages, as wheels.

Usage:

```
python scripts/prepare_app.py --app-name fermi-api --app-path apps/fermi-api
```
"""

import argparse
import logging
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

# --- Basic Configuration ---
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
)


def run_command(command: list[str], cwd: Path) -> subprocess.CompletedProcess:
    """Run a shell command, logs its execution, and handles errors."""
    logging.info(f'🚀 Running command: {" ".join(command)}')
    try:
        result = subprocess.run(  # noqa: S603
            command,
            check=True,
            capture_output=True,
            text=True,
            cwd=cwd,
        )
        if result.stderr:
            # Use INFO for stderr as some tools write progress to it
            logging.info(f'Stderr from command:\n{result.stderr}')
        return result
    except subprocess.CalledProcessError as e:
        logging.error(f'❌ Command failed: {" ".join(command)}')
        logging.error(f'    Return Code: {e.returncode}')
        logging.error(f'    Stdout:\n{e.stdout}')
        logging.error(f'    Stderr:\n{e.stderr}')
        raise


def get_workspace_members(project_root: Path) -> set[str]:
    """Get a set of all package names in the uv workspace."""
    logging.info('Discovering workspace members from pyproject.toml...')
    root_pyproject_path = project_root / 'pyproject.toml'
    if not root_pyproject_path.exists():
        raise FileNotFoundError(
            f"Could not find root pyproject.toml at '{root_pyproject_path}'",
        )

    with root_pyproject_path.open('rb') as f:
        data = tomllib.load(f)

    workspace_globs = (
        data.get('tool', {}).get('uv', {}).get('workspace', {}).get('members', [])
    )
    if not workspace_globs:
        logging.warning(
            'No "[tool.uv.workspace.members]" found in pyproject.toml. '
            'Assuming no workspace members.',
        )
        return set()

    member_names = set()
    for pattern in workspace_globs:
        for member_path in project_root.glob(pattern):
            if member_path.is_dir():
                member_pyproject = member_path / 'pyproject.toml'
                if member_pyproject.exists():
                    with member_pyproject.open('rb') as f_member:
                        member_data = tomllib.load(f_member)

                    package_name = member_data.get('project', {}).get('name')
                    if package_name:
                        member_names.add(package_name)

    logging.info(f'Found {len(member_names)} workspace members.')
    return member_names


def main(app_name: str, app_path_str: str) -> None:
    """Prepare a standalone application directory by bundling source code
    and packaging all dependencies, including internal workspace packages, as wheels.
    """
    # --- 1. Setup Paths ---
    project_root = Path(__file__).parent.parent.resolve()
    app_path = project_root / app_path_str

    if not app_path.is_dir():
        logging.error(f'App path does not exist: {app_path}')
        return

    dist_dir = project_root / 'dist'
    app_dist_dir = dist_dir / app_name
    lib_dir = app_dist_dir / 'lib'

    logging.info(f"Preparing app '{app_name}' from '{app_path}'")
    logging.info(f'Output directory: {app_dist_dir}')

    # Clean up previous build and create directories
    if app_dist_dir.exists():
        logging.info('Removing existing application directory...')
        shutil.rmtree(app_dist_dir)
    lib_dir.mkdir(parents=True)

    # --- 2. Discover Workspace Members ---
    workspace_members = get_workspace_members(project_root)

    # --- 3. Export Dependencies using `uv export` ---
    logging.info(f"Exporting dependency tree for '{app_name}'...")
    temp_req_file = app_dist_dir / 'temp-requirements.txt'
    export_cmd = [
        'uv',
        'export',
        '--package',
        app_name,
        '--no-editable',
        '--no-hashes',
        '--no-header',
        '--no-annotate',
        '--output-file',
        str(temp_req_file),
    ]
    run_command(export_cmd, cwd=project_root)

    # --- 4. Process Dependencies & Build Internal Wheels ---
    logging.info('Processing dependencies and building internal wheels...')
    final_requirements = []
    # This regex extracts the package name from a requirement line

    with temp_req_file.open('r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            dep_identifier = re.split(r'[ ;@<>=!~]', line, maxsplit=1)[0].strip()

            # The package name is the last component of the path or identifier.
            # This works for names like "numpy" and paths like "./packages/fermi-core".
            dep_name = Path(dep_identifier).name

            # The export will include the app itself, which we don't want as a wheel.
            if dep_name == app_name:
                logging.info(f"Ignoring app's self-dependency: {dep_name}")
                continue

            # Check if it's an internal workspace package
            if dep_name in workspace_members:
                logging.info(f'Found internal dependency: {dep_name}')

                # Build the wheel for the internal package using `uv build`
                build_cmd = [
                    'uv',
                    'build',
                    '--wheel',
                    '--out-dir',
                    str(lib_dir),
                    '--package',
                    dep_name,
                ]
                run_command(build_cmd, cwd=project_root)

                # Find the name of the wheel we just built
                # Convert package name (e.g., "fermi-core") to wheel name format
                # (e.g., "fermi_core")
                wheel_name_prefix = dep_name.replace('-', '_')
                try:
                    wheel_path = next(lib_dir.glob(f'{wheel_name_prefix}-*.whl'))
                    # The path in requirements.txt should be relative to the app root
                    relative_wheel_path = wheel_path.relative_to(app_dist_dir)
                    final_requirements.append(f'./{relative_wheel_path.as_posix()}')
                    logging.info(
                        '  -> Added to requirements: '
                        f'./{relative_wheel_path.as_posix()}',
                    )
                except StopIteration:
                    logging.error(
                        f'Could not find wheel for package {dep_name} in {lib_dir}',
                    )
                    raise
            else:
                # It's an external dependency (e.g., from PyPI)
                final_requirements.append(line)

    # --- 5. Create Final `requirements.txt` ---
    logging.info('Writing final `requirements.txt`...')
    final_req_path = app_dist_dir / 'requirements.txt'
    with final_req_path.open('w') as f:
        # Sort for deterministic output
        f.write('\n'.join(sorted(final_requirements)))
        f.write('\n')

    # --- 6. Copy Application Source Code ---
    logging.info(f'Copying application source from {app_path} to {app_dist_dir}...')
    shutil.copytree(
        src=app_path,
        dst=app_dist_dir,
        dirs_exist_ok=True,
        # Ignore the lib dir we created to avoid recursive copy issues
        ignore=shutil.ignore_patterns('__pycache__', '*.pyc', 'lib'),
    )

    # --- 7. Cleanup ---
    temp_req_file.unlink()

    logging.info(f'✅ Successfully created standalone app: {app_dist_dir}')
    logging.info('To install dependencies, run:')
    logging.info(
        f'  cd {app_dist_dir} && python -m venv .venv && . .venv/bin/activate && uv pip'
        ' install -r requirements.txt',
    )


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Create a standalone distribution for a Python application within a'
        ' uv workspace.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        '--app-name',
        help="The name of the application package (e.g., 'fermi-api').",
    )
    parser.add_argument(
        '--app-path',
        help="The relative path to the application's source code"
        ' (e.g., "apps/fermi-api").',
    )
    args = parser.parse_args()

    main(args.app_name, args.app_path)
