# https://www.dmtf.org/sites/default/files/standards/documents/DSP0134_3.8.0.pdf
# Used for Memory Type and Form Factor reference

Get-CimInstance -ClassName Win32_PhysicalMemory | ForEach-Object {
    [PSCustomObject]@{
        'Manufacturer'  = $_.Manufacturer
        'Tag'           = $_.Tag
        'Part Number'   = $_.PartNumber
        'Serial Number' = $_.SerialNumber
        'Capacity GB'   = [math]::Round($_.Capacity / 1GB, 2) # Convert bytes to GB and round to 2 decimal places
        'Memory Type'   = switch ($_.SMBIOSMemoryType) {
                            1  { 'Other' }
                            2  { 'Unknown' }
                            3  { 'DRAM' }
                            4  { 'EDRAM' }
                            5  { 'VRAM' }
                            6  { 'SRAM' }
                            7  { 'RAM' }
                            8  { 'ROM' }
                            9  { 'FLASH' }
                            10 { 'EEPROM' }
                            11 { 'FEPROM' }
                            12 { 'EPROM' }
                            13 { 'CDRAM' }
                            14 { '3DRAM' }
                            15 { 'SDRAM' }
                            16 { 'SGRAM' }
                            17 { 'RDRAM' }
                            18 { 'DDR' }
                            19 { 'DDR2' }
                            20 { 'DDR2 FB-DIMM' }
                            21 { 'Reserved' }
                            22 { 'Reserved' }
                            23 { 'Reserved' }
                            24 { 'DDR3' }
                            25 { 'FBD2' }
                            26 { 'DDR4' }
                            27 { 'LPDDR' }
                            28 { 'LPDDR2' }
                            29 { 'LPDDR3' }
                            30 { 'LPDDR4' }
                            31 { 'Logical non-volatile device' }
                            32 { 'HBM (High Bandwidth Memory)' }
                            33 { 'HBM2' }
                            34 { 'DDR5' }
                            35 { 'LPDDR5' }
                            36 { 'HDM3' }
                            Default { 'Undefined' }
                        }
        'Speed'         = $_.Speed
        'Form Factor'   = switch ($_.FormFactor) {
                            0  { 'Other' }
                            1  { 'Unknown' }
                            2  { 'SIMM' }
                            3  { 'SIP' }
                            4  { 'Chip' }
                            5  { 'DIP' }
                            6  { 'ZIP' }
                            7  { 'Proprietary Card' }
                            8  { 'DIMM' }
                            9  { 'TSOP' }
                            10 { 'Row of chips' }
                            11 { 'RIMM' }
                            12 { 'SODIMM' }
                            13 { 'SRIMM' }
                            14 { 'FB-DIMM' }
                            15 { 'Die' }
                            16 { 'CAMM' }
                            Default { 'Undefined' }
                        }
        'Width'              = $_.TotalWidth
        'Configured Voltage' = $_.ConfiguredVoltage
        'Bank Label'         = $_.BankLabel
        'Device Locator'     = $_.DeviceLocator
    }
}
