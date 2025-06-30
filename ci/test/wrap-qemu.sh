#!/usr/bin/env bash
#
# Copyright (c) 2018-2019 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or https://opensource.org/licenses/mit-license.php.

export LC_ALL=C.UTF-8

# Loop through a list of binaries (by name) that need to be wrapped with QEMU.
# This allows binaries compiled for a different architecture (e.g., ARM) to run
# on the x86_64 CI host via QEMU emulation.
# Added 'src/test/test_gridcoin' to wrap the main unit test executable.
for b_name in {"${BASE_OUTDIR}/bin"/*,src/secp256k1/*tests,src/univalue/{no_nul,test_json,unitester,object},src/test/test_gridcoin}; do
    # Use 'find' to locate the actual executable file(s) corresponding to the binary name.
    # shellcheck disable=SC2044
    for b in $(find "${BASE_ROOT_DIR}" -executable -type f -name $(basename $b_name)); do
      echo "Wrap $b ..."
      # Rename the original binary by appending '_orig'.
      mv "$b" "${b}_orig"
      # Create a new wrapper script with the original binary's name.
      echo '#!/usr/bin/env bash' > "$b"
      # The wrapper script executes QEMU with the original binary and passes all arguments.
      echo "$QEMU_USER_CMD \"${b}_orig\" \"\$@\"" >> "$b"
      # Make the wrapper script executable.
      chmod +x "$b"
    done
done
