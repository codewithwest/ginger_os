#!/bin/bash
source "$SCRIPT_DIR/../lib/ui.sh"

# Note: We don't call ui_draw_dashboard here anymore. 
# We just print clean status lines that the Main Orchestrator will "catch".

for i in "${!SCRIPTS[@]}"; do
    PKG_NAME="${PKG_NAMES[$i]}"
    
    # The Main Orchestrator "sees" this echo and puts it in the table
    echo "Building: $PKG_NAME"

    if [ -f "$LFS/var/lib/ginger/$PKG_NAME.built" ]; then
        continue
    fi

    bash "${SCRIPTS[$i]}" > /dev/null 2>&1 # Internal logs handled by main runner
    
    if [ $? -eq 0 ]; then
        touch "$LFS/var/lib/ginger/$PKG_NAME.built"
    else
        echo "Error: $PKG_NAME failed"
        exit 1
    fi
done