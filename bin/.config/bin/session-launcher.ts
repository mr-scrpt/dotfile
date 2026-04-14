import { exec } from "child_process";
import { promisify } from "util";
import { acquireLock } from "/home/mr/Hellkitchen/solution/tmux/src/infrastructure/file-lock";
import { SaveUseCase } from "/home/mr/Hellkitchen/solution/tmux/src/application/save-usecase";
import { createLogger } from "/home/mr/Hellkitchen/solution/tmux/src/infrastructure/logger";

const execAsync = promisify(exec);
const logger = createLogger("session-launcher");

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
            logger.error(`tmux command failed`, { cmd, error: String(error) });
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
        logger.error("Fatal Error during session launch", { error: String(err) });
        process.exit(1);
    }
}

async function _launchSession(blueprint: SessionBlueprint) {
    const { sessionName, windows } = blueprint;

    if (windows.length === 0) {
        throw new Error("Blueprint must contain at least one window.");
    }

    // Guarantee server is owned by Systemd
    logger.info(`Ensuring systemd service is active...`);
    await execAsync(`systemctl --user start tmux`).catch(() => { });

    if (await hasSession(sessionName)) {
        logger.info(`Session already exists. Attaching...`, { sessionName });
        return attachToSession(sessionName);
    }

    logger.info(`Building session`, { sessionName });

    // 1. Acquire the exclusive save lock. This stops the background worker
    // from saving incomplete states while we bash out `new-window` commands.
    // Wait up to 30 seconds for any current saves to finish.
    const saveLock = await acquireLock("save-exclusive", {
        timeoutSeconds: 30,
        logger
    });

    if (!saveLock) {
        logger.warn("Failed to acquire save-exclusive lock. Building session but intermediate states may be saved during hook storm.");
    } else {
        logger.debug("save-exclusive lock acquired. Background saves paused.");
    }

    try {
        let focusTarget = `${sessionName}:1`;

        for (let i = 0; i < windows.length; i++) {
            const win = windows[i];
            if (!win) continue;

            const winId = i + 1; // Assuming tmux base-index is 1, otherwise this might mismatch
            const target = `${sessionName}:${winId}`;

            if (i === 0) {
                await runTmux(
                    `new-session -d -s "${sessionName}" -n "${win.name}"`,
                );
            } else {
                await runTmux(`new-window -t "${target}" -n "${win.name}"`);
            }

            // Prevent tmux from overwriting the user-defined window name
            // with the running process name (e.g. "fish")
            const renameTarget = i === 0 ? `${sessionName}:1` : target;
            await runTmux(`set-option -t "${renameTarget}" automatic-rename off`);

            // Fallback for unreliable `-c` tmux flag: explicitly send 'cd' if a dir is specified.
            const baseCommands: string[] = [];
            if (win.dir) {
                // Expand tilde because `cd "~/path"` prevents bash from expanding it natively
                const expandedDir = win.dir.replace(/^~/, process.env["HOME"] || "");
                baseCommands.push(`cd "${expandedDir}"`);
                if (!win.cmd && !win.fallbackCmd) {
                    baseCommands.push("clear"); // Clean up the cd output if it's just a raw terminal
                }
            }

            if (win.cmd) {
                let finalCmd = win.cmd;
                if (win.fallbackCmd) {
                    const exists = await commandExists(win.cmd);
                    if (!exists) finalCmd = win.fallbackCmd;
                }
                baseCommands.push(finalCmd);
            }

            if (baseCommands.length > 0) {
                const joinedCmd = baseCommands.join(" && ");
                // Use the session name and window name as target to avoid base-index mismatching on window 1
                const safeTarget = i === 0 ? sessionName : target;
                await runTmux(`send-keys -t "${safeTarget}" '${joinedCmd}' Enter`);
            }

            if (win.focus) focusTarget = target;
            console.log(`  ├── Window ${winId}: ${win.name} [OK]`);
        }

        await runTmux(`select-window -t "${focusTarget}"`);

    } finally {
        // 2. Release the lock to allow saves again
        if (saveLock) {
            await saveLock.release();
            logger.debug("save-exclusive lock released.");
        }
    }

    logger.info(`Session built successfully!`);

    // 3. Explicitly trigger a save now that the session is fully built and lock released
    logger.info(`Triggering final save for newly built session...`);
    const useCase = new SaveUseCase({ logger });
    await useCase.triggerSave(`session-build-complete-${sessionName}`);

    // 4. Attach
    await attachToSession(sessionName);
}
