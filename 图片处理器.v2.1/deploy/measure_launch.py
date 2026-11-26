"""Measure fresh Windows GUI launches using the launcher's own UI smoke mode.
Usage: python measure_launch.py <package directory> <new results directory> [runs]
Times include the launcher, MATLAB initialization, first draw and event hooks.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def measure(package, results, n):
    package = package.resolve()
    logs = (package / 'userdata' if (package / 'portable.flag').exists() else Path(os.environ['LOCALAPPDATA']) / 'FilterLab') / 'logs'
    results.mkdir(parents=True, exist_ok=False)
    times = []
    for run in range(1, n + 1):
        output = results.resolve() / str(run)
        previous = set(logs.glob('*'))
        start = time.perf_counter()
        child = subprocess.Popen([str(package / 'FilterLab.exe'), '--ui-test', '--test-output', str(output)])
        while time.perf_counter() - start < 180:
            ready = [p for p in set(logs.glob('*')) - previous if (p / 'ready.flag').exists() and str(package / 'app').casefold() in (p / 'launcher.txt').read_text(encoding='utf-8-sig').casefold()]
            if ready:
                times.append(round(time.perf_counter() - start, 3))
                print('ready', times[-1], 'seconds', flush=True)
                break
            if child.poll() is not None:
                raise RuntimeError(f'GUI exited before ready, code {child.returncode}')
            time.sleep(.05)
        else:
            raise TimeoutError('Startup exceeded 180 seconds. See launcher logs.')
        if child.wait(timeout=180) or not (output / 'PASS.txt').is_file():
            raise RuntimeError('UI smoke check did not complete')
    (results / 'timings.json').write_text(json.dumps(times),encoding='utf-8')


if __name__ == '__main__':
    measure(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]) if len(sys.argv)>3 else 3)
