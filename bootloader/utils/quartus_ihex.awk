BEGIN {
    byte_count = 0x04;
    record_type = 0x00;
    address_raw = 0;
}
{
    # Change data endianness
    data_raw = strtonum("0x" $1);
    d0 = and(data_raw, 0xFF);
    d1 = rshift(and(data_raw, 0xFF00), 8);
    d2 = rshift(and(data_raw, 0xFF0000), 16);
    d3 = rshift(and(data_raw, 0xFF000000), 24);
    # data = sprintf("%02X%02X%02X%02X", d0, d1, d2, d3);
    data = sprintf("%02X%02X%02X%02X", d3, d2, d1, d0);

    # Convert address to bytes
    a0 = and(address_raw, 0xFF);
    a1 = rshift(and(address_raw, 0xFF00), 8);
    address = sprintf("%02X%02X", a1, a0);
    ++address_raw;

    # Calculate checksum
    digest = byte_count + a0 + a1 + record_type + d0 + d1 + d2 + d3;
    # digest = 0xE2
    checksum = and(and(compl(and(digest, 0xFF)), 0xFF) + 1, 0xFF);

    # Print IHEX
    printf ":%02X%4s%02X%8s%02X\n", byte_count, address, record_type, data, checksum;
}
END {
    printf ":00000001FF\n";
}
