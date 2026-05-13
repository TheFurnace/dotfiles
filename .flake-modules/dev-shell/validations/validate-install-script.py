import os
import pty
import select
import sys
import time

SELECT_TIMEOUT_SECONDS = 1.0
OVERALL_TIMEOUT_SECONDS = 120


def main() -> int:
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

    deadline = time.monotonic() + OVERALL_TIMEOUT_SECONDS
    transcript = bytearray()
    answer_index = 0
    exit_status = 0

    with open(transcript_path, "wb") as transcript_file:
        while True:
            if time.monotonic() > deadline:
                raise SystemExit(
                    f"Timed out after {OVERALL_TIMEOUT_SECONDS} seconds while waiting for install.sh to finish"
                )

            ready, _, _ = select.select([fd], [], [], SELECT_TIMEOUT_SECONDS)
            if not ready:
                continue

            try:
                chunk = os.read(fd, 4096)
            except OSError:
                chunk = b""

            if not chunk:
                _, status = os.waitpid(pid, 0)
                exit_status = status
                break

            transcript.extend(chunk)
            transcript_file.write(chunk)
            transcript_file.flush()

            while answer_index < len(prompt_answers):
                prompt, answer = prompt_answers[answer_index]
                if prompt.encode() not in transcript:
                    break
                os.write(fd, answer.encode())
                answer_index += 1

    exit_code = os.waitstatus_to_exitcode(exit_status)
    if exit_code != 0:
        return exit_code

    if answer_index != len(prompt_answers):
        missing_prompt = prompt_answers[answer_index][0]
        raise SystemExit(f"Missing expected prompt: {missing_prompt}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
