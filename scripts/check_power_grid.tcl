if {[info exists ::env(A54_ODB)]} {
    read_db $::env(A54_ODB)
}

check_power_grid -net VDD
check_power_grid -net VSS
