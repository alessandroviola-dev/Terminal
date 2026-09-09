#!/usr/bin/env python3
"""Real menu-only installed-app regression; start CLOSED: python3 Scripts/audit-ui-test.py PID.
Requires Accessibility/Screen Recording. Uses fresh project-local markers and native edge resize.
"""
import json, pathlib, re, subprocess, sys, time, uuid
root = pathlib.Path(__file__).resolve().parents[1]
pid = int(sys.argv[1])
driver = root / '.build/audit-ui'
evidence = root / '.build' / ('menu-ui-' + str(uuid.uuid4()))
evidence.mkdir()

def run(*args):
    return subprocess.check_output([str(driver), *map(str, args)], text=True)

def windows():
    return [w['kCGWindowBounds'] for w in json.loads(run('windows', pid)) if w['kCGWindowLayer'] == 101]

def window():
    ws = windows()
    assert len(ws) == 1, ws
    assert ws[0]['Height'] >= 240 and ws[0]['Width'] >= 420, ws
    return ws[0]

def status():
    line = next(l for l in run('ax', pid).splitlines() if 'AXRole=AXMenuBarItem AXTitle= AXDescription=Terminal ' in l)
    x, y = map(float, re.search(r'value = x:([\d.-]+) y:([\d.-]+)', line).groups())
    w, h = map(float, re.search(r'value = w:([\d.-]+) h:([\d.-]+)', line).groups())
    assert x >= 0 and y >= 0 and 0 < w <= 32
    return x + w/2, y + h/2

def click(x, y):
    run('click', x, y); time.sleep(.2)

def send(command):
    window()
    run('type', command); run('return'); time.sleep(.4)

def text(name):
    return (evidence / name).read_text().strip()

def capture(name, w):
    bounds = ','.join(str(int(w[k])) for k in ['X', 'Y', 'Width', 'Height'])
    subprocess.check_call(['screencapture', '-x', '-R'+bounds, str(evidence / (name+'.png'))])

assert not windows()
s = status()
capture('icon', dict(X=s[0]-20, Y=0, Width=40, Height=32))
run('drag', *s, s[0]-160, s[1]+180)
time.sleep(.3)
assert not windows(), 'Icon drag must never open a desktop panel'
assert status() == s
print('PASS closed launch, icon only, drag ignored', flush=True)
click(*status()); w = window()
send(f"pwd > '{evidence}/pwd'; printf '%s' $$ > '{evidence}/shell'")
assert text('pwd').startswith('/')
# A header drag must not move the panel.
run('drag', w['X']+w['Width']/2, w['Y']+19, w['X']+w['Width']/2-70, w['Y']+100)
time.sleep(.2)
assert window() == w, 'Panel became movable'
send(f"stty size > '{evidence}/grid-before'")
# Native right-edge and bottom-edge resize, not AX-setSize or controller method calls.
run('drag', w['X']+w['Width']-1, w['Y']+w['Height']/2,
    w['X']+w['Width']+89, w['Y']+w['Height']/2)
time.sleep(.3)
w2 = window(); assert w2['Width'] > w['Width'] and w2['Y'] == w['Y']
run('drag', w2['X']+w2['Width']/2, w2['Y']+w2['Height']-1,
    w2['X']+w2['Width']/2, w2['Y']+w2['Height']+79)
time.sleep(.3)
w3 = window(); assert w3['Height'] > w2['Height'] and w3['Y'] == w2['Y']
send(f"stty size > '{evidence}/grid-after'; printf '%0200d\\n' 0")
rows0, cols0 = map(int, text('grid-before').split())
rows1, cols1 = map(int, text('grid-after').split())
assert rows1 > rows0 and cols1 > cols0, (rows0,cols0,rows1,cols1)
capture('padding-after-resize', w3)
send("for n in {1..80}; do printf 'scroll line %s\\n' $n; done")
run('scroll', w3['X']+100, w3['Y']+150, 12); time.sleep(.2)
run('scroll', w3['X']+100, w3['Y']+150, -12); time.sleep(.2)
send(f"printf input-ok > '{evidence}/after-scroll'")
assert text('after-scroll') == 'input-ok'
print('PASS pwd/focus, native horizontal+vertical resize, PTY grid growth, wrapping, scroll/input', flush=True)
# Foreground job must still be executing immediately after hide and reopen.
send(f"sleep 12; printf done > '{evidence}/long'")
click(*status()); assert not windows()
time.sleep(.4)
click(*status()); assert window() == w3
assert not (evidence / 'long').exists()
subprocess.check_call(['kill', '-0', text('shell')])
w = window(); click(w['X']+w['Width']-57, w['Y']+19)
send(f"cd /; pwd > '{evidence}/second-tab'")
assert text('second-tab') == '/'
for i in range(10):
    click(*status()); assert not windows()
    click(*status()); window()
print('PASS independent tabs, 10 close/reopen cycles, foreground process preserved', flush=True)
for _ in range(100):
    if (evidence / 'long').exists(): break
    time.sleep(.1)
assert text('long') == 'done'
w = window(); click(w['X']+30, w['Y']+19)
send(f"printf '%s' $$ > '{evidence}/selected-shell'")
assert text('selected-shell') == text('shell'), 'Tab switching must restore the original PTY'
print('PASS click tab restores original shell/PID', flush=True)
# An icon drag while open cannot change the presentation into a desktop notch.
w = window(); s = status()
run('drag', *s, s[0]-100, s[1]+200); time.sleep(.3)
assert window() == w
click(*status()); assert not windows()
assert 'true' in run('quit', pid)
time.sleep(.5)
subprocess.check_call(['open', '/Applications/Terminal.app']); time.sleep(1.5)
lines = subprocess.check_output(['ps','-axo','pid,command'],text=True).splitlines()
pid = int(next(l.split()[0] for l in lines if l.strip().endswith('/Applications/Terminal.app/Contents/MacOS/Terminal')))
assert not windows(); status()
click(*status()); window()
send(f"pwd > '{evidence}/restart-pwd'")
assert text('restart-pwd').startswith('/')
click(*status()); assert not windows()
print('PASS icon drag while open ignored; restart closed with icon and working input', flush=True)
print('PASS installed menu-only UI suite; PID', pid, 'evidence', evidence, flush=True)
