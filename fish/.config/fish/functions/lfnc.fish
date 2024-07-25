# function lfnc
#     if test "$TERM" = "screen" -a -n "$TMUX"
#         tmux source-file ~/.tmux-nc.conf \; \
#             split -h lf -config ~/.config/lf/lfnc.conf \; lf -config ~/.config/lf/lfnc.conf
#     else
#         tmux -f ~/.tmux-nc.conf \
#             new-session lf -config ~/.config/lf/lfnc.conf \; \
#             split -h lf -config ~/.config/lf/lfnc.conf \; \
#             selectp -L \; \
#             attach
#     end
# end
function lfnc
    # Установите имя сессии, которое вы хотите проверить или создать
    set -l session_name "filemanager"

    # Проверяем, существует ли сессия с заданным именем
    if tmux has-session -t $session_name 2>/dev/null
        # Если сессия существует, подключаемся к ней
        tmux attach-session -t $session_name
    else
        # Если сессия не существует, создаем новую сессию с именем и конфигурацией
        # tmux -f ~/.tmux-nc.conf new-session -s $session_name -d
        tmux new-session -s $session_name -d
        tmux send-keys -t $session_name "lf -config ~/.config/lf/lfnc.conf" Enter
        tmux split-window -h -t $session_name "lf -config ~/.config/lf/lfnc.conf"
        tmux select-pane -L -t $session_name
        tmux attach-session -t $session_name
    end
end
