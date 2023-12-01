#!/usr/bin/env python3
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.

from sys import argv

binfile = argv[1]
nwords = int(argv[2])
hexfile = argv[3]  # New argument for the output .hex file

with open(binfile, "rb") as f:
    bindata = f.read()

with open(hexfile, "w") as f:  # Open the output .hex file in write mode
    for i in range(nwords):
        if i < len(bindata) // 4:
            w = bindata[4*i : 4*i+4]
            hex_str = "%02x%02x%02x%02x" % (w[3], w[2], w[1], w[0])
        else:
            hex_str = "0"
        f.write(hex_str + "\n")  # Write the hex string to the .hex file


