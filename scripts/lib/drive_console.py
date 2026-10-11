# scripts/check-console から呼ぶ。対話式のコマンド（bin/rails c など）を擬似端末で起動し、入力を 1 つずつ送る。
# reline は起動時にカーソル位置を問い合わせ（ESC[6n）、返事を待つので、問い合わせが来たら ESC[1;1R を返す
# （入力をパイプで流すだけでは止まったままになる。docs/upgrade/TIPS.md の「rails c を確かめる」）。
# Python 3 の標準ライブラリだけを使う。
#
# 使い方: python3 -I drive_console.py <出力のファイル> <コマンド...>
#   送る入力は環境変数 CONSOLE_STEPS（JSON の文字列の配列）。なければ下の DEFAULT_STEPS
#   標準出力に、子プロセスの終了の状態（child_status <数>）を出す
import json
import os
import pty
import select
import sys
import time

DEFAULT_STEPS = [
    'puts "CHECK reline=#{Reline::VERSION} irb=#{IRB::VERSION} '
    'io-console-gem=#{Gem.loaded_specs["io-console"]&.version} '
    'reline-gem=#{Gem.loaded_specs["reline"]&.version} '
    'input=#{IRB.CurrentContext.io.class}"\r',
    "Rails.versi\t",
    "\r",
    "if true\r",
    "42\r",
    "end\r",
    "exit\r",
]

out_path = sys.argv[1]
command = sys.argv[2:]
steps = json.loads(os.environ["CONSOLE_STEPS"]) if os.environ.get("CONSOLE_STEPS") else DEFAULT_STEPS

pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)

buffer = b""
with open(out_path, "wb") as out:

    def pump(seconds):
        global buffer
        deadline = time.time() + seconds
        while time.time() < deadline:
            ready, _, _ = select.select([fd], [], [], 0.1)
            if fd not in ready:
                continue
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            out.write(data)
            out.flush()
            buffer += data
            for _ in range(data.count(b"\x1b[6n")):
                os.write(fd, b"\x1b[1;1R")
        return True

    # プロンプトを待つ（起動に時間がかかるので、最長 60 秒）
    deadline = time.time() + 60
    while time.time() < deadline and b">" not in buffer[-200:] and b"(byebug)" not in buffer:
        if not pump(0.5):
            break
    pump(2)
    for step in steps:
        try:
            os.write(fd, step.encode())
        except OSError:
            # 子プロセスが終わっていて送れない（起動に失敗したなど）
            break
        pump(2)
    pump(5)

status = 0
for _ in range(50):
    finished, status = os.waitpid(pid, os.WNOHANG)
    if finished:
        break
    time.sleep(0.1)
else:
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    status = -1
print("child_status", status)
