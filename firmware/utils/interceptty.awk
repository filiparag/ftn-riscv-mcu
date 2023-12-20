{
    gsub(/^<\s*/, "\033[1;33msend\033[0m ", $0)
    gsub(/^>\s*/, "\033[1;32mrecv\033[0m ", $0)
    printf("%s ", $0)
}
$2 == "0x10" {
    printf("\033[0;35mSTK_OK\033[0m")
}
$2 == "0x11" {
    printf("\033[0;34mSTK_FAILED\033[0m")
}
$2 == "0x12" {
    printf("\033[0;34mSTK_UNKNOWN\033[0m")
}
$2 == "0x13" {
    printf("\033[0;34mSTK_NODEVICE\033[0m")
}
$2 == "0x14" {
    printf("\033[0;35mSTK_INSYNC\033[0m")
}
$2 == "0x15" {
    printf("\033[0;34mSTK_NOSYNC\033[0m")
}
$2 == "0x16" {
    printf("\033[0;34mADC_CHANNEL_ERROR\033[0m")
}
$2 == "0x17" {
    printf("\033[0;34mADC_MEASURE_OK\033[0m")
}
$2 == "0x18" {
    printf("\033[0;34mPWM_CHANNEL_ERROR\033[0m")
}
$2 == "0x19" {
    printf("\033[0;34mPWM_ADJUST_OK\033[0m")
}
$2 == "0x20" {
    printf("\033[0;35mCRC_EOP\033[0m")
}
$2 == "0x30" {
    printf("\033[0;34mSTK_GET_SYNC\033[0m")
}
$2 == "0x31" {
    printf("\033[0;34mSTK_GET_SIGN_ON\033[0m")
}
$2 == "0x40" {
    printf("\033[0;34mSTK_SET_PARAMETER\033[0m")
}
$2 == "0x41" {
    printf("\033[0;36mSTK_GET_PARAMETER\033[0m")
}
$2 == "0x42" {
    printf("\033[0;36mSTK_SET_DEVICE\033[0m")
}
$2 == "0x45" {
    printf("\033[0;36mSTK_SET_DEVICE_EXT\033[0m")
}
$2 == "0x50" {
    printf("\033[0;34mSTK_ENTER_PROGMODE\033[0m")
}
$2 == "0x51" {
    printf("\033[0;36mSTK_LEAVE_PROGMODE\033[0m")
}
$2 == "0x52" {
    printf("\033[0;34mSTK_CHIP_ERASE\033[0m")
}
$2 == "0x53" {
    printf("\033[0;34mSTK_CHECK_AUTOINC\033[0m")
}
$2 == "0x55" {
    printf("\033[0;36mSTK_LOAD_ADDRESS\033[0m")
}
$2 == "0x56" {
    printf("\033[0;36mSTK_UNIVERSAL\033[0m")
}
$2 == "0x60" {
    printf("\033[0;34mSTK_PROG_FLASH\033[0m")
}
$2 == "0x61" {
    printf("\033[0;34mSTK_PROG_DATA\033[0m")
}
$2 == "0x62" {
    printf("\033[0;34mSTK_PROG_FUSE\033[0m")
}
$2 == "0x63" {
    printf("\033[0;34mSTK_PROG_LOCK\033[0m")
}
$2 == "0x64" {
    printf("\033[0;36mSTK_PROG_PAGE\033[0m")
}
$2 == "0x65" {
    printf("\033[0;34mSTK_PROG_FUSE_EXT\033[0m")
}
$2 == "0x70" {
    printf("\033[0;34mSTK_READ_FLASH\033[0m")
}
$2 == "0x71" {
    printf("\033[0;34mSTK_READ_DATA\033[0m")
}
$2 == "0x72" {
    printf("\033[0;34mSTK_READ_FUSE\033[0m")
}
$2 == "0x73" {
    printf("\033[0;34mSTK_READ_LOCK\033[0m")
}
$2 == "0x74" {
    printf("\033[0;36mSTK_READ_PAGE\033[0m")
}
$2 == "0x75" {
    printf("\033[0;36mSTK_READ_SIGN\033[0m")
}
$2 == "0x76" {
    printf("\033[0;34mSTK_READ_OSCCAL\033[0m")
}
$2 == "0x77" {
    printf("\033[0;34mSTK_READ_FUSE_EXT\033[0m")
}
$2 == "0x78" {
    printf("\033[0;34mSTK_READ_OSCCAL_EXT\033[0m")
}
$2 == "0x81" {
    printf("\033[0;35mSTK_SW_MAJOR\033[0m")
}
$2 == "0x82" {
    printf("\033[0;35mSTK_SW_MINOR\033[0m")
}
$2 == "0x1E" {
    printf("\033[0;35mSIGNATURE_0\033[0m")
}
$2 == "0x95" {
    printf("\033[0;35mSIGNATURE_1\033[0m")
}
$2 == "0x0F" {
    printf("\033[0;35mSIGNATURE_2\033[0m")
}
$2 == "0x4d" {
    printf("\033[0;34mAVR_OP_LOAD_EXT_ADDR\033[0m")
}
{
    printf("\n")
}
