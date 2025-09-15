function neohtop
    GDK_BACKEND=x11 WEBKIT_DISABLE_DMABUF_RENDERER=1 command neohtop $argv
end
