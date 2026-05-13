: "${DOTFILES_REPO:?DOTFILES_REPO is not set. This should be set by the dotfiles dev shell.}"
install_script="$DOTFILES_REPO/install.sh"

test -x "$install_script"
bash -n "$install_script"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-validate.XXXXXX")"
cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

test_home="$test_root/home"
mkdir -p "$test_home"

safe_path=""
append_path_dir() {
  local dir="$1"
  case ":$safe_path:" in
    *":$dir:"*) ;;
    *) safe_path="${safe_path:+$safe_path:}$dir" ;;
  esac
}

for command_name in bash cat dirname grep id mktemp mv nix python3 pwd rm sed; do
  append_path_dir "$(dirname "$(command -v "$command_name")")"
done

PATH="$safe_path" command -v nix >/dev/null 2>&1
if PATH="$safe_path" command -v git >/dev/null 2>&1; then
  exit 1
fi
if PATH="$safe_path" command -v home-manager >/dev/null 2>&1; then
  exit 1
fi

export INSTALL_SCRIPT="$install_script"
install_script_bash="$(command -v bash)"
export INSTALL_SCRIPT_BASH="$install_script_bash"
export INSTALL_TEST_HOME="$test_home"
export INSTALL_TEST_PATH="$safe_path"
export INSTALL_TRANSCRIPT="$test_root/install-transcript.txt"
export INSTALL_DEFAULT_USERNAME="testuser"
export INSTALL_DEFAULT_HOME="$test_home"
export INSTALL_DEFAULT_STATE_VERSION="25.11"
export INSTALL_DEFAULT_SYSTEM="x86_64-linux"

python3 <<'PY'
import os
import pty
import select
import sys
import time

SELECT_TIMEOUT_SECONDS = 1.0
TIMEOUT_SECONDS = 600

install_script = os.environ["INSTALL_SCRIPT"]
bash_path = os.environ["INSTALL_SCRIPT_BASH"]
transcript_path = os.environ["INSTALL_TRANSCRIPT"]

env = {
    "HOME": os.environ["INSTALL_TEST_HOME"],
    "PATH": os.environ["INSTALL_TEST_PATH"],
    "TMPDIR": os.environ["INSTALL_TEST_HOME"],
    "USER": os.environ["INSTALL_DEFAULT_USERNAME"],
}

prompt_answers = [
    (f"Username [{os.environ['INSTALL_DEFAULT_USERNAME']}]: ", "\n"),
    (f"Home directory [{os.environ['INSTALL_DEFAULT_HOME']}]: ", "\n"),
    (f"Home Manager state version [{os.environ['INSTALL_DEFAULT_STATE_VERSION']}]: ", "\n"),
    (f"System [{os.environ['INSTALL_DEFAULT_SYSTEM']}]: ", "\n"),
    ("Enable mutable mode [y/N]: ", "n\n"),
    ("Activate this Home Manager configuration now [y/N]: ", "n\n"),
]

pid, fd = pty.fork()
if pid == 0:
    os.chdir(os.environ["DOTFILES_REPO"])
    os.environ.clear()
    os.environ.update(env)
    os.execv(bash_path, [bash_path, install_script])

deadline = time.monotonic() + TIMEOUT_SECONDS
transcript = bytearray()
answer_index = 0
exit_status = None

with open(transcript_path, "wb") as transcript_file:
    while True:
        if time.monotonic() > deadline:
            raise SystemExit("Timed out while waiting for install.sh to finish")

        ready, _, _ = select.select([fd], [], [], SELECT_TIMEOUT_SECONDS)
        if ready:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                chunk = b""

            if chunk:
                transcript.extend(chunk)
                transcript_file.write(chunk)
                transcript_file.flush()

                while answer_index < len(prompt_answers):
                    prompt, answer = prompt_answers[answer_index]
                    if prompt.encode() not in transcript:
                        break
                    os.write(fd, answer.encode())
                    answer_index += 1
            else:
                _, status = os.waitpid(pid, 0)
                exit_status = status
                break

if exit_status is None:
    raise SystemExit("install.sh exited without a status")
if os.waitstatus_to_exitcode(exit_status) != 0:
    sys.exit(os.waitstatus_to_exitcode(exit_status))
if answer_index != len(prompt_answers):
    missing_prompt = prompt_answers[answer_index][0]
    raise SystemExit(f"Missing expected prompt: {missing_prompt}")
PY

transcript="$INSTALL_TRANSCRIPT"

grep -Fq "Installing standalone Home Manager config from:" "$transcript"
grep -Fq "Username [$INSTALL_DEFAULT_USERNAME]:" "$transcript"
grep -Fq "Home directory [$INSTALL_DEFAULT_HOME]:" "$transcript"
grep -Fq "Home Manager state version [$INSTALL_DEFAULT_STATE_VERSION]:" "$transcript"
grep -Fq "System [$INSTALL_DEFAULT_SYSTEM]:" "$transcript"
grep -Fq "Enable mutable mode [y/N]:" "$transcript"
grep -Fq "Configuration summary:" "$transcript"
grep -Fq "username:       $INSTALL_DEFAULT_USERNAME" "$transcript"
grep -Fq "home directory: $INSTALL_DEFAULT_HOME" "$transcript"
grep -Fq "state version:  $INSTALL_DEFAULT_STATE_VERSION" "$transcript"
grep -Fq "system:         $INSTALL_DEFAULT_SYSTEM" "$transcript"
grep -Fq "mutable:        false" "$transcript"
grep -Fq "Running nix flake check for: path:$DOTFILES_REPO" "$transcript"
grep -Fq "Building the generated Home Manager activation package..." "$transcript"
grep -Fq "Activate this Home Manager configuration now [y/N]:" "$transcript"
grep -Fq "Skipping activation." "$transcript"
