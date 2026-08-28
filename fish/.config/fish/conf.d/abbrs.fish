# ~/.config/fish/conf.d/abbrs.fish

if status is-interactive
    abbr -a ta 'tmux a'
    abbr -a ccx 'claude --dangerously-skip-permissions'
    abbr -a ccxr 'claude --dangerously-skip-permissions --continue'
    abbr -a cxx 'if codex remote-control start >/dev/null 2>&1; codex --remote unix:// --dangerously-bypass-approvals-and-sandbox; else; codex remote-control stop >/dev/null 2>&1; echo "Remote Control недоступен — включи MFA в ChatGPT; запускаю локально" >&2; codex --dangerously-bypass-approvals-and-sandbox; end'
    abbr -a cxxr 'if codex remote-control start >/dev/null 2>&1; codex --remote unix:// --dangerously-bypass-approvals-and-sandbox resume --last; else; codex remote-control stop >/dev/null 2>&1; echo "Remote Control недоступен — включи MFA в ChatGPT; запускаю локально" >&2; codex --dangerously-bypass-approvals-and-sandbox resume --last; end'
    abbr -a cxxs 'if codex remote-control start >/dev/null 2>&1; codex --search --remote unix:// --dangerously-bypass-approvals-and-sandbox; else; codex remote-control stop >/dev/null 2>&1; echo "Remote Control недоступен — включи MFA в ChatGPT; запускаю локально" >&2; codex --search --dangerously-bypass-approvals-and-sandbox; end'
end
