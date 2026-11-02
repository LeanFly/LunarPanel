import subprocess
from pathlib import Path

bash = r'C:\Program Files\Git\bin\bash.exe'
script = Path('LunarPanel/charge-control.sh').resolve().as_posix()

def decide(percent, online, state, phase):
    return subprocess.run([bash, script, 'decide', str(percent), str(online), str(state), phase],
                          capture_output=True, text=True, check=False)

for percent in range(101):
    for state in (0, 1):
        for phase in ('hold', 'charge'):
            next_phase = 'hold' if percent >= 80 else ('charge' if percent <= 40 else phase)
            action = 'stop' if next_phase == 'hold' and state == 1 else (
                'start' if next_phase == 'charge' and state == 0 else 'hold')
            result = decide(percent, 1, state, phase)
            assert result.returncode == 0 and result.stdout.strip() == f'{action} {next_phase}'
            assert decide(percent, 0, state, phase).stdout.strip() == f'restore {next_phase}'
for args in (('bad', 1, 1, 'hold'), (101, 1, 1, 'hold'), (50, 2, 1, 'hold'),
             (50, 1, 2, 'hold'), (50, 1, 1, 'bad')):
    assert decide(*args).returncode != 0

phase = 'hold'
for percent, online, state, expected in (
    (80, 1, 1, 'stop'), (75, 0, 0, 'restore'), (74, 1, 1, 'stop'),
    (41, 1, 0, 'hold'), (40, 1, 0, 'start'), (60, 1, 1, 'hold'),
    (60, 0, 0, 'restore'), (60, 1, 1, 'hold'), (80, 1, 1, 'stop'),
):
    action, phase = decide(percent, online, state, phase).stdout.strip().split()
    assert action == expected
assert decide(75, 1, 1, 'hold').stdout.strip() == 'stop hold'
print('Charge thresholds, reconnect hysteresis, startup behavior and invalid inputs verified.')
