import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

export interface WindowBlueprint {
  name: string;
  dir?: string;
  cmd?: string;
  fallbackCmd?: string;
  focus?: boolean;
}

export interface SessionBlueprint {
  sessionName: string;
  windows: WindowBlueprint[];
}

async function commandExists(cmd: string): Promise<boolean> {
  try {
    const baseCmd = cmd.split(" ")[0];
    await execAsync(`command -v ${baseCmd}`);
    return true;
  } catch {
    return false;
  }
}

async function runTmux(cmd: string, ignoreError = false): Promise<string> {
  try {
    const { stdout } = await execAsync(`tmux ${cmd}`);
    return stdout.trim();
  } catch (error) {
    if (!ignoreError) {
      console.error(`[Error] tmux ${cmd} failed:`, error);
      throw error;
    }
    return "";
  }
}

async function hasSession(sessionName: string): Promise<boolean> {
  try {
    await execAsync(`tmux has-session -t "${sessionName}"`);
    return true;
  } catch {
    return false;
  }
}

async function attachToSession(sessionName: string) {
  if (process.env.TMUX) {
    await runTmux(`switch-client -t "${sessionName}"`);
  } else {
    const { spawn } = require("child_process");
    spawn("tmux", ["attach-session", "-t", sessionName], { stdio: "inherit" });
  }
}

export async function launchSession(blueprint: SessionBlueprint) {
  try {
    await _launchSession(blueprint);
  } catch (err) {
    console.error("\n[TMUX Fatal Error]:", err);
    process.exit(1);
  }
}

async function _launchSession(blueprint: SessionBlueprint) {
  const { sessionName, windows } = blueprint;

  if (windows.length === 0) {
    throw new Error("Blueprint must contain at least one window.");
  }

  // Гарантируем, что сервером владеет Systemd (защита от ghost-серверов)
  console.log(`[TMUX] Ensuring systemd service is active...`);
  await execAsync(`systemctl --user start tmux`).catch(() => {});

  if (await hasSession(sessionName)) {
    console.log(`[TMUX] Session '${sessionName}' already exists. Attaching...`);
    return attachToSession(sessionName);
  }

  console.log(`[TMUX] Building session: ${sessionName}...`);
  await execAsync(`tmux-keeper lock "setup-${sessionName}"`).catch(() => {});

  try {
    let focusTarget = `${sessionName}:1`;

    for (let i = 0; i < windows.length; i++) {
      const win = windows[i];
      const winId = i + 1;
      const target = `${sessionName}:${winId}`;
      const dirFlag = win.dir ? `-c "${win.dir}"` : "";

      if (i === 0) {
        await runTmux(
          `new-session -s "${sessionName}" -n "${win.name}" ${dirFlag} -d`,
        );
      } else {
        await runTmux(`new-window -t "${target}" -n "${win.name}" ${dirFlag}`);
      }

      if (win.cmd) {
        let finalCmd = win.cmd;
        if (win.fallbackCmd) {
          const exists = await commandExists(win.cmd);
          if (!exists) finalCmd = win.fallbackCmd;
        }
        await runTmux(`send-keys -t "${target}" "${finalCmd}" Enter`);
      }

      if (win.focus) focusTarget = target;
      console.log(`  ├── Window ${winId}: ${win.name} [OK]`);
    }

    await runTmux(`select-window -t "${focusTarget}"`);
  } finally {
    await execAsync(`tmux-keeper unlock "setup-${sessionName}"`).catch(
      () => {},
    );
  }

  console.log(`[TMUX] Session built successfully!`);
  await attachToSession(sessionName);
}
