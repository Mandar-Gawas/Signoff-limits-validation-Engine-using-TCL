## Extraction Engine main Code
set list_minmax {min max}
foreach minmax $list_minmax {
    if { [string match $minmax min] } { set el early } else { set el late }
    set report_directory [file join [pwd] "REPORTS_NEW"]
        file mkdir $report_directory

 ## Variables to create paths for final reports
        set timing_report [file join $report_directory "ipba_${minmax}_new.rpt"]
        set mismatch_report [file join $report_directory "derates_mismatch_${minmax}.rpt"]
        set summary_report [file join $report_directory "ipba_${minmax}_summary.rpt"]
 
 
 
##Read CSV file: Spatial derate xls file : Golden Limits file provided by Signoff Team
        set fileHandle [open "spatial_derate.csv" "r"]
 
###Read CSV file:OCV Deate : Golden Limits file provided by Signoff Team
        set file1Handle [open "ocv_derate.csv" "r"]
 
##Read CSV file:Library Sigma Padding : Golden Limits file provided by Signoff Team
        set file2Handle [open "Library_Sigma_Padding.csv" "r"]
 
## Report timing Format to set the reporting fields in a timing report
        set report_timing_format {timing_point cell load slew slew_mean slew_sigma user_derate socv_derate incr_derate total_derate delay_mean delay_sigma arrival edge}
 
## Proc to remove the secondary voltage element from the corner name:
    set corner_name_raw $CORNER
        set parts [split $corner_name_raw "_"]
        set output [lindex $parts 0]
        for {set i 2} {$i < [llength $parts]} {incr i} {
            append output "_[lindex $parts $i]"
        }
 
    set new_corner $output
     
####################################################################
## Creating hashes to store Spatial Derates for cells and net
###### Data storage into hashes from CSV/LIB DATA ##################

        set cell_late  [dict create]
        set cell_early  [dict create]
        set net_late  [dict create]
        set net_early  [dict create]
 
###################################################################
 
####################################################################
## Creating hashes to store margins
###### Data storage into hashes from CSV/LIB DATA ##################
 
        set setup_margin  [dict create] ;#uncertainity
        set hold_margin [dict create] ;#uncertainity
        set setup_sigma_padding  [dict create]
        set hold_sigma_padding  [dict create]
        set delay_sigma_padding_setup [dict create]
        set delay_sigma_padding_hold [dict create]
###################################################################
##OCV Derates hashes
 
        set setup_launch_clk [dict create]
        set setup_capture_clk [dict create]
        set setup_data [dict create]
        set hold_launch_clk [dict create]
        set hold_capture_clk [dict create]
        set hold_data [dict create]
 
##################################################################
## net Derate percent:
## net derate for all corners +/- 2.5%
        set net_derate_value 0.025
        set late_net_derate [expr {1 + $net_derate_value}] 
        set early_net_derate [expr {1 - $net_derate_value}]
###################################################################
## USER DERATE EXTRACTIOn
 
        proc user_extract {par_value} {
            set user_derates_values_are {} 
            set values_is [split $par_value ":"]
                foreach value $values_is {
                    lappend user_derates_values_are $value
                }
            return $user_derates_values_are
        }
 
 
###################################################################
## Reading spatial derate CSV File
## Spatial Derate
    while {[gets $fileHandle line] != -1} {
        set fields [split $line ","]
############################

            set distance [lindex $fields 0]
            dict set cell_late $distance [lindex $fields 1]
            dict set cell_early $distance [lindex $fields 2]
            dict set net_late $distance [lindex $fields 4]
            dict set net_early $distance [lindex $fields 5]
############################
    }
    close $fileHandle
 
## Reading OCV Derates CSV File
        while {[gets $file1Handle line] != -1} {
            set fields [split $line ","]
## no,corner,setup_launch_clk,setup_capture_clk,setup_data,hold_launch_clk,hold_capture_clk, hold_data
                set corner [lindex $fields 1] ;#key for the hash[lindex $check_list_2 1]
                dict set setup_launch_clk $corner [lindex $fields 2]
                dict set setup_capture_clk $corner [lindex $fields 3]
                dict set setup_data $corner [lindex $fields 4]
                dict set hold_launch_clk $corner [lindex $fields 5]
                dict set hold_capture_clk $corner [lindex $fields 6]
                dict set hold_data $corner [lindex $fields 7]
############################
        }
    close $file1Handle
 
###################################################################
## Reading sigma padding derate CSV File
        while {[gets $file2Handle line] != -1} {
            set fields [split $line ","]
# srno,corner,setup_margin,ignore,setup_sigma_padd,delay_sigma_padding_setup,hold_margin,ignore,hold_sigma_padding,delay_sigma_padding_hold
 
                set corner [lindex $fields 1] ;#key for the hash[lindex $check_list_2 1]
                dict set setup_margin $corner [lindex $fields 2]
                dict set hold_margin $corner [lindex $fields 6]
                dict set setup_sigma_padding $corner [lindex $fields 4]
                dict set hold_sigma_padding $corner [lindex $fields 8]
                dict set delay_sigma_padding_setup $corner [lindex $fields 5]
                dict set delay_sigma_padding_hold $corner [lindex $fields 9]
############################
        }
    close $file2Handle
 
###################################################################
 
## Storing the distance numbers inside the list ###################
        set distance_values {}
## Distance is same for all
    foreach item [dict keys $cell_late] {
        lappend distance_values $item
    }
#################################################################
## Lower and Upper Boundary Defining Proc ##########################
    proc upper_low {input_distance} {
            global distance_values
            set numeric_list {}
 
        foreach elem $distance_values {
            if {[string is integer -strict $elem]} {
                lappend numeric_list $elem
            }
        }
 
        set sorted_numeric_list [lsort -integer $numeric_list]
 
            set lower_boundary ""
            set upper_boundary ""
 
            foreach distance $sorted_numeric_list {
                if {$distance > $input_distance} {
                    set upper_boundary $distance
                        break ;#upper boundary
                }
                set lower_boundary $distance
            }
 
## Changing the Algo
# if {$input_distance < [lindex $sorted_numeric_list 0] || $input_distance > [lindex $sorted_numeric_list end]} {
#          set lower_boundary [lindex $sorted_numeric_list 0]
#               set upper_boundary [lindex $sorted_numeric_list end]
#     }
 
 
## Higher Limit
        if {$input_distance > [lindex $sorted_numeric_list end]} {
            set lower_boundary [lindex $sorted_numeric_list end-1]
                set upper_boundary [lindex $sorted_numeric_list end]
        }
 
 
##Lower limit
        if {$input_distance < [lindex $sorted_numeric_list 0]} {
            set lower_boundary [lindex $sorted_numeric_list 0]
                set upper_boundary [lindex $sorted_numeric_list 1]
        }
 
        return [list $lower_boundary $upper_boundary]
    }
 
###################################################################
    proc percentage_conv {value_is} {
        set factor_value [expr {abs($value_is) / 100.0}]
            if {$value_is < 0} {
                set flag_value 1
            } else {
                set flag_value 0
            }
        if {$flag_value} {
            set number_is [regexp -inline {\d+} $value_is]
                set final_no [format "%.4f" [expr {1 - $factor_value}]]
        } else {
            set number_is $value_is
                set final_no [format "%.4f" [expr {1 + $factor_value}]]
        }
        return $final_no
    }
 
 
######Interpolation Proc #########################################e ################################################
    proc linear_int_ext {x_values y_values x} {
        set n [llength $x_values]
            if {$n != [llength $y_values]} {
                error "Inputs not proper"
            }
 
        set sum_x 0
            set sum_y 0
            set sum_xy 0
            set sum_x_squared 0
 
            for {set i 0} {$i < $n} {incr i} {
                set x_val [lindex $x_values $i]
                    set y_val [lindex $y_values $i]
 
                    set sum_x [expr {$sum_x + $x_val}]
                    set sum_y [expr {$sum_y + $y_val}]
                    set sum_xy [expr {$sum_xy + ($x_val * $y_val)}]
                    set sum_x_squared [expr {$sum_x_squared + ($x_val * $x_val)}]
            }
 
        set slope [expr {($n * $sum_xy - $sum_x * $sum_y) / ($n * $sum_x_squared - $sum_x * $sum_x)}]
            set intercept [expr {($sum_y - $slope * $sum_x) / $n}]
#puts "INT [expr {$intercept + $slope * $x}]"
            return [expr {$intercept + $slope * $x}]
    }
 
 
############################################################
## Proc to extract the values of report_timing_derate command in the form of list
    proc data_extract {timing_point_name} {
        set point_cell_name [get_cells -of_objects $timing_point_name]
          
 
## Replace the command to variable to save major runtime
            eval [report_timing_derate $point_cell_name > verbose.rpt]
 
        set cellDelayData {}
        set cellCheckData {}
        set report_file "verbose.rpt"
 
            set file [open $report_file "r"]
            set inCellDelaySection 0
            set inCellCheckSection 0
 
            while {[gets $file line] >= 0} {
                if {[string match "Cell Delay" $line]} {
                    set cellDelayData $line
                        continue
                } elseif {[string match "Cell Check" $line]} {
                    set cellCheckData $line
                        continue
                }
            }
        close $file
 
 
## Delete the temp file
            file delete $report_file
            set field_1 [split $cellDelayData " "]
            set field_2 [split $cellCheckData " "]
 
 
            set numericValues1 {}
        set numericValues2 {}
 
# To remove the field 1 string
 
        for {set i 1} {$i < [llength $field_1]} {incr i} {
            set field [lindex $field_1 $i]
                if {[regexp {^[0-9:.]+$} $field]} {
                    set values [split $field ":"]
                        foreach value $values {
                            lappend numericValues1 $value
                        }
                }
        }
 
        for {set i 1} {$i < [llength $field_2]} {incr i} {
            set field [lindex $field_2 $i]
 
                if {[regexp {^[0-9:.]+$} $field]} {
                    set values [split $field ":"]
 
                        foreach value $values {
                            lappend numericValues2 $value
                        }
                }
        }
 
        set celldelaydata_new $numericValues1
            set cellcheckdata_new $numericValues2
 
            set numericValues1 {}
        set numericValues2 {}

foreach value $celldelaydata_new {
# puts "Numeric Value delay: $value"
        }
        foreach value $cellcheckdata_new {
#  puts "Numeric Value: $value"
        }
 
        return [list $celldelaydata_new $cellcheckdata_new $point_cell_name]
 
    }

##################################################################
## Testing variables : Check while integration
 
        set nworst "50"
        set pba_mode "exhaustive"
        set max_paths 20
        ## Internal report_timing command in Tempus with all the options to genarate the required timing report: Path Based Mode in ON
        eval [***************************************************************************** > $timing_report]
 
##################################################################
######################OCV SIGMA PROC ###########################
 
        proc print_main {timing_point edge clk_type data user_value_also} {
                global el
                global new_corner ;#check
                global setup_sigma_padding
                global hold_sigma_padding
                global delay_sigma_padding_setup
                global delay_sigma_padding_hold
                global setup_launch_clk 
                global setup_capture_clk 
                global setup_data 
                global hold_launch_clk               
                global hold_capture_clk     
                global hold_data 
                set ana_type $el
                set corner_name_tp $new_corner
 
                proc sigma_padding_with_ocv {timing_pnt edge analysis_type data_clk corner_data clk_type_is user_value_is} {
 
                        global setup_sigma_padding
                        global hold_sigma_padding
                        global delay_sigma_padding_setup
                        global delay_sigma_padding_hold
                        global early_net_derate
                        global late_net_derate
                        global setup_launch_clk 
                        global setup_capture_clk 
                        global setup_data 
                        global hold_launch_clk               
                        global hold_capture_clk     
                        global hold_data
 
 
                        set corner_update $corner_data
 
 
                        if {$data_clk == 1} {
                            set check_list [lrange $timing_pnt 8 end]
                        } elseif {$data_clk == 0} {
                            set check_list [lrange $timing_pnt 0 7]
                        }
 
                    if {$analysis_type == "late"} {
                        set check_list_2 [lindex $check_list 3]
#    set net_derate_is $late_net_derate
                            set check_padding [dict get $setup_sigma_padding $corner_update]
                            set delay_sigma_value_required [dict get $delay_sigma_padding_setup $corner_update]
 
                    } elseif {$analysis_type == "early"} {
                        set check_list_2 [lindex $check_list 1]
#     set net_derate_is $early_net_derate
                            set check_padding [dict get $hold_sigma_padding $corner_update]
                            set delay_sigma_value_required [dict get $delay_sigma_padding_hold $corner_update]
 
                    }
 
 
                    set setup_clock_launch [dict get $setup_launch_clk $corner_update]
                        set setup_clock_capture [dict get $setup_capture_clk $corner_update]
                        set data_setup [dict get $setup_data $corner_update]
                        set hold_clock_launch [dict get $hold_launch_clk $corner_update]
                        set hold_clock_capture [dict get $hold_capture_clk $corner_update] 
                        set data_hold [dict get $hold_data $corner_update]
 
 
### OCV DERATES >> CELL
## Launch clk -SETUP
                        if {!$data_clk && [string match "LAUNCH_CLK" $clk_type_is] && [string match "late" $analysis_type]} {
                                set derate_value_for_net $late_net_derate
                                set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                                set ocv_cell_derate_value_required [percentage_conv $setup_clock_launch]
 
                        }
 
 
## CAPTURE CLK -SETUP
                    if {!$data_clk && [string match "CAPTURE_CLK" $clk_type_is] && [string match "late" $analysis_type]} {
                        set derate_value_for_net $early_net_derate 
                            set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                            set ocv_cell_derate_value_required [percentage_conv $setup_clock_capture]
 
                    }
 
 
## DATA -SETUP
                    if {$data_clk && [string match "DATA" $clk_type_is] && [string match "late" $analysis_type]} {
                        set derate_value_for_net $late_net_derate 
                            set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                            set ocv_cell_derate_value_required [percentage_conv $data_setup]
 
                    }
 
 
################## HOLD ###########################
 
 
                    if {!$data_clk && [string match "LAUNCH_CLK" $clk_type_is] && [string match "early" $analysis_type]} {
                        set derate_value_for_net $early_net_derate 
                            set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                            set ocv_cell_derate_value_required [percentage_conv $hold_clock_launch]
                    }
 
 
## CAPTURE CLK -HOLD
                    if {!$data_clk && [string match "CAPTURE_CLK" $clk_type_is] && [string match "early" $analysis_type]} {
                        set derate_value_for_net $late_net_derate 
                            set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                            set ocv_cell_derate_value_required [percentage_conv $hold_clock_capture]
                    }
 
 
## DATA -HOLD
                    if {$data_clk && [string match "DATA" $clk_type_is] && [string match "early" $analysis_type]} {
                        set derate_value_for_net $early_net_derate 
                            set ocv_cell_derate_value [lindex [user_extract $user_value_is] 0]
                            set ocv_cell_derate_value_required [percentage_conv $data_hold]
                    }
 
 
                    return [list $check_list_2 $check_padding $ocv_cell_derate_value $ocv_cell_derate_value_required $derate_value_for_net $delay_sigma_value_required ] ;#Delay #Check
                }
 
 
            set result_value [sigma_padding_with_ocv $timing_point $edge $ana_type $data $new_corner $clk_type $user_value_also]  
                return $result_value
 
        }
 
## INSTANTIATIONS
        set val1 0
        set val2 0
        set val22 0
        set val3 0
        set val4 0
        set R2O 0
 
        set path_name {}
        set new_pin_name {}
        set endpoint_name {}
        set CHECK_VALUE {}
        set beginpoint_name {}
        set commonpoint_name {}
        set cell_net_derate_list {}     set timin... by Mandar Gawas (Consultant)Mandar Gawas (Consultant) (External)7:35 PM
        set cell_net_derate_list {}
        set timing_point_list {}
        set edge_point_list {}
        set user_point_list {}
        set cell_net_derate_list_1 {}
        set timing_point_list_1 {}
        set edge_point_list_1 {}
        set cell_net_derate_list_11 {}
        set timing_point_list_11 {}
        set edge_point_list_11 {}
        set cell_net_derate_list_2 {}
        set timing_point_list_2 {}
        set edge_point_list_2 {}
        set cell_net_derate_list_3 {}
        set timing_point_list_3 {}
        set edge_point_list_3 {}
        set cell_net_derate_list_new_4 {}
        set timing_point_list_new_4 {}
        set edge_point_list_new_4 {}
        set cell_net_derate_list_new_3 {}
        set timing_point_list_new_3 {}
        set edge_point_list_new_3 {}
        set cell_net_derate_list_new_2 {}
        set timing_point_list_new_2 {}
        set edge_point_list_new_2 {}
        set cell_net_derate_list_new_1 {}
        set timing_point_list_new_1 {}
        set edge_point_list_new_1 {}
        set user_point_list_new_1 {}
     
# Open the report file for reading
    if {[file exists $timing_report]} {
        set fileHandlex [open $timing_report "r"]
    } else {
        puts "Error: Report file does not exist."
#exit
    }
 
################################################################################
## Mismatch Report:
    set mismatch_report [open "$mismatch_report" "w"]
 
######## Setting the headers ##########################
        puts $mismatch_report "######################################################################################################################################################################################################################################"
        puts $mismatch_report "#  ORGINAL REPORT PATH  > $timing_report  "
        puts $mismatch_report "#                                                                   "
        puts $mismatch_report "#                                                                                            "
        puts $mismatch_report "######################################################################################################################################################################################################################################"
        puts $mismatch_report "PATH_NO\t\tTIMING_POINT\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tACTUAL_DERATE\t\tREQUIRED_DERATE"
        puts $mismatch_report "######################################################################################################################################################################################################################################"
 
###### INSTANTIATIONS ################################

## USING STATE MACHINE ALGO TO WRITE THE EXTRACTION ENGINE
        set CODE_STATE 0
#####################################################
 
        while {[gets $fileHandlex line] != -1} {
 
            if {$CODE_STATE == 0} {
                set path_patt {^Path (\d+):}
                if {[regexp $path_patt $line -> path_name]} {
                    
                    puts $mismatch_report "PATH NUMBER: $path_name"
                        set pinPattern {Pin\s+(\S+)*}
                    if {[regexp $pinPattern $line match pin_name]} {
                        set new_pin_name $pin_name
                    }
 
                    set pattern_assertion {External Delay Assertion}
                    if {[regexp $pattern_assertion $line]} {
                        set R2O 1
                    } else {
                        set R2O 0
                    }
                     set CODE_STATE 1
                }
                continue
            }
 
 
                if {$CODE_STATE == 1} {
                    if {[string match "Endpoint:*" $line]} {
                        set endpoint_name $line;
                            set new_end_point [lindex [regexp -all -inline {\S+} $endpoint_name] 1]
                            set CHECK_VALUE [lindex [data_extract $new_end_point] 1]
                            set CODE_STATE 2
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 2} {
                    if {[string match "Beginpoint:*" $line]} {
                        set beginpoint_name $line;
                        set new_begin_point [lindex [regexp -all -inline {\S+} $beginpoint_name] 1]
                            set CODE_STATE 3
                    }
                    continue
 
                }
 
                if {$CODE_STATE == 3} {
                    if {[string match "Common point:*" $line]} {
                        set commonpoint_name $line;
                        set new_common_point [lindex [regexp -all -inline {\S+} $commonpoint_name] 2]
                            set CODE_STATE 4
                    }
                    continue
                }
 
 
##############################
                if {$CODE_STATE == 4} {
                    set distance_pattern {Distance\(um\) : ([0-9.]+)}
 
                    if {[regexp $distance_pattern $line match distance_um]} {
                        set spatial_distance $distance_um
 
                            set upper_bound_after_cppr [lindex [upper_low $spatial_distance] 1]
                            set lower_bound_after_cppr [lindex [upper_low $spatial_distance] 0]
                            set distance_unit "um" ;# based on the customers unit.

                            ## Internal command to get the diagonal distance of the chip
                            set chip_size_var [****************************************]

                            set upper_bound_before_cppr [lindex [upper_low $chip_size_var] 1]
                            set lower_bound_before_cppr [lindex [upper_low $chip_size_var] 0]
 
                            if {$el eq "late"} {
########################
## SETUP
########################
 
                                    set LAUNCH_CLK_PATH_CELL_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $cell_late $lower_bound_before_cppr] [dict get $cell_late $upper_bound_before_cppr]] $chip_size_var]
                                    set LAUNCH_CLK_PATH_NET_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $net_late $lower_bound_before_cppr] [dict get $net_late $upper_bound_before_cppr]] $chip_size_var]
                                    set LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_late $lower_bound_after_cppr] [dict get $cell_late $upper_bound_after_cppr]] $spatial_distance]
                                    set LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_late $lower_bound_after_cppr] [dict get $net_late $upper_bound_after_cppr]] $spatial_distance]
                                    set DATA_PATH_CELL_DERATE [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_late $lower_bound_after_cppr] [dict get $cell_late $upper_bound_after_cppr]] $spatial_distance]
                                    set DATA_PATH_NET_DERATE [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_late $lower_bound_after_cppr] [dict get $net_late $upper_bound_after_cppr]] $spatial_distance]
                                    set CAPTURE_CLK_PATH_CELL_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $cell_early $lower_bound_before_cppr] [dict get $cell_early $upper_bound_before_cppr]] $chip_size_var]
                                    set CAPTURE_CLK_PATH_NET_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $net_early $lower_bound_before_cppr] [dict get $net_early $upper_bound_before_cppr]] $chip_size_var]
                                    set CAPTURE_CLK_PATH_CELL_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_early $lower_bound_after_cppr] [dict get $cell_early $upper_bound_after_cppr]] $spatial_distance]
                                    set CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_early $lower_bound_after_cppr] [dict get $net_early $upper_bound_after_cppr]] $spatial_distance]
 
                            } elseif {$el eq "early"} {
#######################
## HOLD
########################
                                    set LAUNCH_CLK_PATH_CELL_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $cell_early $lower_bound_before_cppr] [dict get $cell_early $upper_bound_before_cppr]] $chip_size_var]
                                    set LAUNCH_CLK_PATH_NET_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $net_early $lower_bound_before_cppr] [dict get $net_early $upper_bound_before_cppr]] $chip_size_var]
                                    set LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_early $lower_bound_after_cppr] [dict get $cell_early $upper_bound_after_cppr]] $spatial_distance]
                                    set LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_early $lower_bound_after_cppr] [dict get $net_early $upper_bound_after_cppr]] $spatial_distance]
                                    set DATA_PATH_CELL_DERATE [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_early $lower_bound_after_cppr] [dict get $cell_early $upper_bound_after_cppr]] $spatial_distance]
                                    set DATA_PATH_NET_DERATE [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_early $lower_bound_after_cppr] [dict get $net_early $upper_bound_after_cppr]] $spatial_distance]
                                    set CAPTURE_CLK_PATH_CELL_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $cell_late $lower_bound_before_cppr] [dict get $cell_late $upper_bound_before_cppr]] $chip_size_var]
                                    set CAPTURE_CLK_PATH_NET_DERATE_BEFORE_CPPR [linear_int_ext [list $lower_bound_before_cppr $upper_bound_before_cppr] [list [dict get $net_late $lower_bound_before_cppr] [dict get $net_late $upper_bound_before_cppr]] $chip_size_var]
                                    set CAPTURE_CLK_PATH_CELL_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $cell_late $lower_bound_after_cppr] [dict get $cell_late $upper_bound_after_cppr]] $spatial_distance]
                                    set CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR [linear_int_ext [list $lower_bound_after_cppr $upper_bound_after_cppr] [list [dict get $net_late $lower_bound_after_cppr] [dict get $net_late $upper_bound_after_cppr]] $spatial_distance]
#########################
                            }
                        set CODE_STATE 5
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 5} {
                    if {[string match "Uncertainty" $line]} {
                        set pattern {(\d+\.\d+)}
                        if {[regexp $pattern $line match value ]} {
                            set uncer_value $value
                        } else {
                            set uncer_value "NA"
                        }
 
#####Comparision from CSV#################
                        if {$el eq "late"} {
                            set req_value [dict get $setup_margin $new_corner]
                                proc convert_ps_to_ns {input_string} {
                                    if {[regexp {^(\d+)ps$} $input_string match value]} {
                                        set ns_value [expr {$value * 0.001}]
                                            return "$ns_value"
                                    } else {
                                        return $input_string
                                    }
                                }
                            if { [expr [convert_ps_to_ns $req_value] == $uncer_value] } {
                            } else {
                                puts $mismatch_report "Uncertainity mismatched > Required : [convert_ps_to_ns $req_value] | Current_value : $uncer_value"
                            }
 
                            set CODE_STATE 6
                        } elseif {$el eq "early"} {
                            set req_value [dict get $hold_margin $new_corner]
 
 
                                proc convert_ps_to_ns {input_string} {
                                    if {[regexp {^(\d+)ps$} $input_string match value]} {
                                        set ns_value [expr {$value * 0.001}]
                                            return "$ns_value"
                                    } else {
                                        return $input_string
                                    }
                                }
 
                            if { [expr [convert_ps_to_ns $req_value] == $uncer_value] } {
                            } else {
                                puts $mismatch_report "Uncertainity mismatched > Required : [convert_ps_to_ns $req_value] | Current_value : $uncer_value"
                            }
                            set CODE_STATE 6
                        }
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 6} {
                    if {[string match "Timing Point" $line]} {
                            set CODE_STATE 7
                    }
                    continue
                }
 
                if {$CODE_STATE == 7} {
                    if {[string match "-------" $line]} {
                            set CODE_STATE 8
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 8} {
                    set data [regexp -all -inline {\S+} $line]
                        set timing_point [lindex $data 0]
                        set cell_name [lindex $data 1]
                        set derate_value [lindex $data 7]
                        set edge_value_is [lindex $data 13]
                        set user_derate_value [lindex $data 6]
                        if {[regexp {\(net\)} $cell_name]} {
                            set val1 1
                                continue
                        }
                    if {$val1} {
                        set val1 0
                    }
 
                        lappend cell_net_derate_list $derate_value
                        lappend timing_point_list $timing_point
                        lappend edge_point_list $edge_value_is
                        lappend user_point_list $user_derate_value
 
 
                        if {[string equal "NA" $new_common_point]} {
                            if {[string equal "NA" $new_common_point] && $R2O} {
## Reg2out
                                if {[string equal $timing_point $new_begin_point]} {
                                    set CODE_STATE 1000
                                } 
                            } else {
## in2reg : Start with BP and ends at EP  for the data path
                                if {[string equal $timing_point $new_end_point]} {
                                    set CODE_STATE 2000
                                } 
                            }
                        } else {
## R2R operation
                            if {[string equal $timing_point $new_common_point]} {
                                set CODE_STATE 9
                            }
                        }
                    continue
                }
 
 
                if {$CODE_STATE == 9} {
                    set cell_net_derate_list_new_1 [lreplace $cell_net_derate_list 0 0]
                        set timing_point_list_new_1 [lreplace $timing_point_list 0 0]
                        set edge_point_list_new_1 [lreplace $edge_point_list 0 0]
                        set user_point_list_new_1 [lreplace $user_point_list 0 0]
 
 
                        set PATH_STATE "LAUNCH_CLK"
                        for {set i 0} {$i < [llength $cell_net_derate_list_new_1]} {incr i 2} {
                            set element [lindex $cell_net_derate_list_new_1 $i]
 
                                if {[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_BEFORE_CPPR] != $element} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i]\t\t\t$element\t\t[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_BEFORE_CPPR]"
                                        continue
                                }
 
                            set UIPD [print_main $CHECK_VALUE [lindex $edge_point_list_new_1 $i] $PATH_STATE 0 [lindex $user_point_list_new_1 $i]]
## OCV NET DERATE
                                if {[lindex [user_extract [lindex $user_point_list_new_1 $i]] 0] == [lindex $UIPD 4]} {
                                    #puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i] :OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_new_1 $i]] 0] Required [lindex $UIPD 4] "
 
                                }
## Net Sigma Derate
 
                        }
 
 
                    for {set i 1} {$i < [llength $cell_net_derate_list_new_1]} {incr i 2} {
                        set element1 [lindex $cell_net_derate_list_new_1 $i]
                            if {[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_BEFORE_CPPR] != $element1} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i]\t\t\t$element1\t\t[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_BEFORE_CPPR]"
 
                            }
 
## LVF Simga padding
                            set UIP [print_main $CHECK_VALUE [lindex $edge_point_list_new_1 $i] $PATH_STATE 0 [lindex $user_point_list_new_1 $i]]
                            if {[lindex $UIP 0] == [lindex $UIP 1]} {
                                #puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP 0] Required [lindex $UIP 1]"
                            }
 
 
## OCV CELL DERATE
                        if {[lindex $UIP 2] == [lindex $UIP 3]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i] : OCV Cell Derate > Actual [lindex $UIP 2] Required [lindex $UIP 3]"
                        }
 
 
## Cell Sigma Padding
                        if {[lindex [user_extract [lindex $user_point_list_new_1 $i]] 1] == [lindex $UIP 5]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_1 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP 0] Required [lindex $UIP 1]"
                        }
                    }
 
                    set cell_net_derate_list_new_1 {}
                    set timing_point_list_new_1 {}
                    set edge_point_list_new_1 {}
                    set user_point_list_new_1 {}
                    set cell_net_derate_list {}
                    set timing_point_list {}
                    set edge_point_list {}
                    set user_point_list {}
                    set CODE_STATE 99
                        continue
                }
 
#### STATE 1000 > check for the scope for it once eveything is ran together:
 
            if {$CODE_STATE == 1000} {
 
                    set cell_net_derate_list_new_2 [lreplace $cell_net_derate_list 0 0]
                    set timing_point_list_new_2 [lreplace $timing_point_list 0 0]
                    set edge_point_list_new_2 [lreplace $edge_point_list 0 0]
                    set user_point_list_new_2 [lreplace $user_point_list 0 0 ]
                    
##FINAL CHANGE: LAUNCH

                    set PATH_STATE "LAUNCH_CLK" ;#Capture clk path in reg2out
                    for {set i 0} {$i < [llength $cell_net_derate_list_new_2]} {incr i 2} {
                        set element66 [lindex $cell_net_derate_list_new_2 $i]
 
### FINAL CHANGE  CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR
                            if {[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR] != $element66} {
## FINAL CHANGE
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i]\t\t\t$element66\t\t[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR]"
                            }
 
##    set UIP66 [print_main [lindex $timing_point_list_new_2 $i] [lindex $edge_point_list_new_2 $i] $PATH_STATE 0]
                            set UIP66D [print_main $CHECK_VALUE [lindex $edge_point_list_new_2 $i] $PATH_STATE 0 [lindex $user_point_list_new_2 $i]]
 
                            if {[lindex [user_extract [lindex $user_point_list_new_2 $i]] 0] == [lindex $UIP66D 4]} {
                                #puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_new_2 $i]] 0] Required [lindex $UIP66D 4] "
 
 
                            }
                    }
                for {set i 1} {$i < [llength $cell_net_derate_list_new_2]} {incr i 2} {
                    set element166 [lindex $cell_net_derate_list_new_2 $i]
# FINAL CHNAGE  CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR
                        if {[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR] != $element166} {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i]\t\t\t$element166\t\t[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR]"
                        }
 
                        set UIP66 [print_main $CHECK_VALUE [lindex $edge_point_list_new_2 $i] $PATH_STATE 0 [lindex $user_point_list_new_2 $i]]
 
## LVF Sigma padding
                        if {[lindex $UIP66 0] == [lindex $UIP66 1]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP66 0] Required [lindex $UIP66 1]"
                        }
 
 
## OCV CELL DERATE
if {[lindex $UIP66 2] == [lindex $UIP66 3]} {
                        #puts "passed"
                    } else {
                        puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i] : OCV Cell Derate > Actual [lindex $UIP66 2] Required [lindex $UIP66 3]"
                    }
 
 
## Cell Sigma Padding
                    if {[lindex [user_extract [lindex $user_point_list_new_2 $i]] 1] == [lindex $UIP66 5]} {
                        #puts "passed"
                    } else {
                        puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_2 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP66 0] Required [lindex $UIP66 1]"
                    }
 
 
                }
 
 
                set cell_net_derate_list_new_2 {}
                set timing_point_list_new_2 {}
                set edge_point_list_new_2 {}
                set cell_net_derate_list {}
                set timing_point_list {}
                set edge_point_list {}
                set user_point_list {}
                set user_point_list_new_2 {}
                set CODE_STATE 69 
                    continue
            }
 
 
                if {$CODE_STATE == 2000} {
 
                    set cell_net_derate_list_new_4 [lreplace $cell_net_derate_list 0 0]
                        set timing_point_list_new_4 [lreplace $timing_point_list 0 0]
                        set edge_point_list_new_4 [lreplace $edge_point_list 0 0]
                        set user_point_list_new_4 [lreplace $user_point_list 0 0]
 
                        set PATH_STATE "DATA"
 
                        for {set i 0} {$i < [llength $cell_net_derate_list_new_4]} {incr i 2} {
                            set element29 [lindex $cell_net_derate_list_new_4 $i]
 
                                if {[format "%.4f" $DATA_PATH_NET_DERATE] != $element2} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i]\t\t\t$element2\t\t[format "%.4f" $DATA_PATH_NET_DERATE]"
                                }
 
                            set UIP29D [print_main $CHECK_VALUE [lindex $edge_point_list_new_4 $i] $PATH_STATE 1 [lindex $user_point_list_new_4 $i]]
 
                                if {[lindex [user_extract [lindex $user_point_list_new_4 $i]] 0] == [lindex $UIP29D 4]} {
                                    #puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_new_4 $i]] 0] Required [lindex $UIP29D 4] "
                                }
 
                        }
 
 
                    for {set i 1} {$i < [llength $cell_net_derate_list_new_4]} {incr i 2} {
                        set element39 [lindex $cell_net_derate_list_new_4 $i]
                            if {[format "%.4f" $DATA_PATH_CELL_DERATE] != $element39} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i]\t\t\t$element39\t\t[format "%.4f" $DATA_PATH_CELL_DERATE]"
                            }
 
 
                            set UIP29 [print_main $CHECK_VALUE [lindex $edge_point_list_new_4 $i] $PATH_STATE 1 [lindex $user_point_list_new_4 $i]]
 
## LVF Sigma padding
                            if {[lindex $UIP29 0] == [lindex $UIP29 1]} {
                                #puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP29 0] Required [lindex $UIP29 1]"
                            }
 
 
## OCV CELL DERATE
 
                        if {[lindex $UIP66 2] == [lindex $UIP66 3]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i] : OCV Cell Derate > Actual [lindex $UIP29 2] Required [lindex $UIP29 3]"
                        }     ##Cell Sigma ... by Mandar Gawas (Consultant)Mandar Gawas (Consultant) (External)7:35 PM
                        }
 
 
## Cell Sigma PAdding
                        if {[lindex [user_extract [lindex $user_point_list_new_4 $i]] 1] == [lindex $UIP29 5]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_4 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP29 0] Required [lindex $UIP29 1]"
                        }
 
                    }
 
 
                    set cell_net_derate_list_new_4 {}
                    set timing_point_list_new_4 {}
                    set edge_point_list_new_4 {}
                    set cell_net_derate_list {}
                    set timing_point_list {}
                    set edge_point_list {}
                    set user_point_list {}
                    set user_point_list_new_4 {}
                    set CODE_STATE 12
 
                        continue
                }
 
 
            if {$CODE_STATE == 99} {
                set datam [regexp -all -inline {\S+} $line]
                    set timing_point_m [lindex $datam 0]
                    set cell_name_m [lindex $datam 1]
                    set derate_value_m [lindex $datam 7]
                    set edge_value_is_m [lindex $datam 13]
                    set user_value_is_m [lindex $datam 6]
 
                    if {[regexp {\(net\)} $cell_name_m]} {
                        set val22 1
                            continue
                    }
                if {$val22} {
                    set val22 0
                }
 
 
                    lappend cell_net_derate_list_11 $derate_value_m
                    lappend timing_point_list_11 $timing_point_m
                    lappend edge_point_list_11 $edge_value_is_m
                    lappend user_point_list_11 $user_value_is_m
                    if {[string equal $timing_point_m $new_begin_point]} {
                            set CODE_STATE 100
                    }
                continue
            }
 
 
                if {$CODE_STATE == 100} {
                        set PATH_STATE "LAUNCH_CLK"
                        set cell_net_derate_list_11dd $cell_net_derate_list_11
                        set timing_point_list_11dd  $timing_point_list_11
                        set edge_point_list_11dd $edge_point_list_11
                        set user_point_list_11dd $user_point_list_11
 
 
                        for {set i 0} {$i < [llength $cell_net_derate_list_11dd]} {incr i 2} {
                            set element22 [lindex $cell_net_derate_list_11dd $i]
 
                                if {[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR] != $element22} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i]\t\t\t$element22\t\t[format "%.4f" $LAUNCH_CLK_PATH_NET_DERATE_AFTER_CPPR]"
                                }
 
 
 
                            set UIP1D [print_main $CHECK_VALUE [lindex $edge_point_list_11dd $i] $PATH_STATE 0 [lindex $user_point_list_11dd $i]]
                                if {[lindex [user_extract [lindex $user_point_list_11dd $i]] 0] == [lindex $UIP1D 4]} {
                                    #puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_11dd $i]] 0] Required [lindex $UIP1D 4] "
                                }
                        }
 
                    for {set i 1} {$i < [llength $cell_net_derate_list_11dd]} {incr i 2} {
                        set element33 [lindex $cell_net_derate_list_11dd $i]
                            if {[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR] != $element33} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i]\t\t\t$element33\t\t[format "%.4f" $LAUNCH_CLK_PATH_CELL_DERATE_AFTER_CPPR]"
                            }
 
 
                            set UIP1 [print_main $CHECK_VALUE [lindex $edge_point_list_11dd $i] $PATH_STATE 0 [lindex $user_point_list_11dd $i]]
 
 
## LVF Sigma padding
                            if {[lindex $UIP1 0] == [lindex $UIP1 1]} {
                                #puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP1 0] Required [lindex $UIP1 1]"
                            }
 
 
## OCV CELL DERATE
 
                        if {[lindex $UIP1 2] == [lindex $UIP1 3]} {
                           # puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i] : OCV Cell Derate > Actual [lindex $UIP1 2] Required [lindex $UIP1 3]"
                        }
 
 
## Cell Sigma PAdding
                        if {[lindex [user_extract [lindex $user_point_list_11dd $i]] 1] == [lindex $UIP1 5]} {
                           # puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_11dd $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP1 0] Required [lindex $UIP1 1]"
                        }

                    }
 
                    set cell_net_derate_list_11 {}
                    set timing_point_list_11 {}
                    set edge_point_list_11 {}
                    set user_point_list_11 {}
                    set cell_net_derate_list_11dd {}
                    set timing_point_list_11dd {}
                    set edge_point_list_11dd {}
                    set user_point_list_11dd {}
 
                    set CODE_STATE 10
                        continue
                }
 
            if {$CODE_STATE == 10} {
                    set datax [regexp -all -inline {\S+} $line]
                    set timing_point_x [lindex $datax 0]
                    set cell_name_x [lindex $datax 1]
                    set derate_value_x [lindex $datax 7]
                    set edge_value_is_x [lindex $datax 13]
                    set user_point_value_is_x [lindex $datax 6]
                    if {[regexp {\(net\)} $cell_name_x]} {
                        set val2 1
                            continue
                    }
                if {$val2} {
                    set val2 0
                }
 
 
                    lappend cell_net_derate_list_1 $derate_value_x
                    lappend timing_point_list_1 $timing_point_x
                    lappend edge_point_list_1 $edge_value_is_x
                    lappend user_point_list_1 $user_point_value_is_x
 
                    if {$R2O} {
# R2O
                        if {[string equal $timing_point_x $new_end_point]} {
                            set CODE_STATE 69
                        }
 
                    } else {
                        if {[string equal $timing_point_x $new_end_point]} {
                            set CODE_STATE 11
                        }
                    }
                continue
            }
 
#### ADDITIONAL STEP
 
                if {$CODE_STATE == 69} {
 
                        set cell_net_derate_list_new_3 $cell_net_derate_list_1
                        set timing_point_list_new_3 $timing_point_list_1                    
                        set edge_point_list_new_3 $edge_point_list_1
                        set user_point_list_new_3 $user_point_list_1
 
                        set PATH_STATE "DATA"
                        for {set i 0} {$i < [llength $cell_net_derate_list_new_3]} {incr i 2} {
                            set element26 [lindex $cell_net_derate_list_new_3 $i]
 
                                if {[format "%.4f" $DATA_PATH_NET_DERATE] != $element26} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_3 $i]\t\t\t$element26\t\t[format "%.4f" $DATA_PATH_NET_DERATE]"
                                }
 
#                            set UIP26 [print_main [lindex $timing_point_list_new_3 $i] [lindex $edge_point_list_new_3 $i] $PATH_STATE 1]
                            set UIP26D [print_main $CHECK_VALUE [lindex $edge_point_list_new_3 $i] $PATH_STATE 1 [lindex $user_point_list_new_3 $i]]
 
 
                                if {[lindex [user_extract [lindex $user_point_list_new_3 $i]] 0] == [lindex $UIP26D 4]} {
                                    #puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\\t\t[lindex $timing_point_list_new_3 $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_new_3 $i]] 0] Required [lindex $UIP26D 4] "
 
                                }
 
 
                        }
 
 
                    for {set i 1} {$i < [llength $cell_net_derate_list_new_3]} {incr i 2} {
                        set element36 [lindex $cell_net_derate_list_new_3 $i]
                            if {[format "%.4f" $DATA_PATH_CELL_DERATE] != $element36} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_3 $i]\t\t\t$element36\t\t[format "%.4f" $DATA_PATH_CELL_DERATE]"
                            }

                            set UIP26 [print_main $CHECK_VALUE [lindex $edge_point_list_new_3 $i] $PATH_STATE 1 [lindex $user_point_list_new_3 $i]]
 
##LVF Simga padding
                            if {[lindex $UIP26 0] == [lindex $UIP26 1]} {
                               # puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_3 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP26 0] Required [lindex $UIP26 1]"
                            }
 
 
##OCV CELL DERATE
 
                        if {[lindex $UIP26 2] == [lindex $UIP26 3]} {
                           # puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_3 $i] : OCV Cell Derate > Actual [lindex $UIP26 2] Required [lindex $UIP26 3]"
                        }
 
 
##Cell Sigma PAdding
                        if {[lindex [user_extract [lindex $user_point_list_new_3 $i]] 1] == [lindex $UIP26 5]} {
                          #  puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_3 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP26 0] Required [lindex $UIP26 1]"
                        }
 
                    }
 
 
                    set cell_net_derate_list_new_3 {}
                    set timing_point_list_new_3 {}
                    set edge_point_list_new_3 {}
                    set cell_net_derate_list_1 {}
                    set timing_point_list_1 {}
                    set edge_point_list_1 {}
                    set user_point_list_1 {}
                    set user_point_list_new_3 {}
 
 
 
                    if {[string match "-------" $line]} {
                            set CODE_STATE 0
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 11} {
 
                        set cell_net_derate_list_new_333 $cell_net_derate_list_1
                        set timing_point_list_new_333 $timing_point_list_1                    
                        set edge_point_list_new_333 $edge_point_list_1
                        set user_point_list_new_333 $user_point_list_1
 
                        set PATH_STATE "DATA"
 
                        for {set i 0} {$i < [llength $cell_net_derate_list_new_333]} {incr i 2} {
                            set element2 [lindex $cell_net_derate_list_new_333 $i]
 
                                if {[format "%.4f" $DATA_PATH_NET_DERATE] != $element2} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i]\t\t\t$element2\t\t[format "%.4f" $DATA_PATH_NET_DERATE]"
                                }
 
                            set UIP2D [print_main $CHECK_VALUE [lindex $edge_point_list_new_333 $i] $PATH_STATE 1 [lindex $user_point_list_new_333 $i]]
 
                                if {[lindex [user_extract [lindex $user_point_list_new_333 $i]] 0] == [lindex $UIP2D 4]} {
                                  #  puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_new_333 $i]] 0] Required [lindex $UIP2D 4] "
 
 
                                }
 
                        }
 
 
                    for {set i 1} {$i < [llength $cell_net_derate_list_new_333]} {incr i 2} {
                        set element3 [lindex $cell_net_derate_list_new_333 $i]
                            if {[format "%.4f" $DATA_PATH_CELL_DERATE] != $element3} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i]\t\t\t$element3\t\t[format "%.4f" $DATA_PATH_CELL_DERATE]"
                            }
 
                            set UIP2 [print_main $CHECK_VALUE [lindex $edge_point_list_new_333 $i] $PATH_STATE 1 [lindex $user_point_list_new_333 $i]]
 
##LVF Simga padding
                            if {[lindex $UIP2 0] == [lindex $UIP2 1]} {
                              #  puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP2 0] Required [lindex $UIP2 1]"
                            }
 
 
## OCV CELL DERATE
 
                        if {[lindex $UIP2 2] == [lindex $UIP2 3]} {
                          #  puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i] : OCV Cell Derate > Actual [lindex $UIP2 2] Required [lindex $UIP2 3]"
                        }
 
 
## Cell Sigma PAdding
                        if {[lindex [user_extract [lindex $user_point_list_new_333 $i]] 1] == [lindex $UIP2 5]} {
                          #  puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_new_333 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP2 0] Required [lindex $UIP2 1]"
                        }
 
 
                    }
 
 
                    set cell_net_derate_list_1 {}
                    set timing_point_list_1 {}
                    set edge_point_list_1 {}
                    set cell_net_derate_list_1 {}
                    set timing_point_list_1 {}
                    set edge_point_list_1 {}
                    set user_point_list_1 {}
                    set timing_point_list_new_333 {}
                    set edge_point_list_new_333 {}                    
                    set user_point_list_new_333 {}
                    set CODE_STATE 12
 
                        continue
                }
 
 
                if {$CODE_STATE == 12} {
                    if {[string match "Other End Path" $line]} {
                            set CODE_STATE 13
                    }
                    continue
                }
 
 
                if {$CODE_STATE == 13} {
                    if {[string match "-------" $line]} {
                            set CODE_STATE 14
                    }
                    continue
 
                }
 
 
                if {$CODE_STATE == 14} {
                    if {[string match "-------" $line]} {
                            set CODE_STATE 15
                    }
                    continue
 
                }
 
                if {$CODE_STATE == 15} {
 
                    set data1 [regexp -all -inline {\S+} $line]
                        set timing_point1 [lindex $data1 0]
                        set cell_name1 [lindex $data1 1]
                        set derate_value1 [lindex $data1 7]
                        set edge_value_is_1 [lindex $data1 13]
                        set user_value_is_1 [lindex $data1 6]
                        if {[regexp {\(net\)} $cell_name1]} {
                            set val3 1
                                continue
                        }
                    if {$val3} {
                        set val3 0
                    }
 
                        lappend cell_net_derate_list_2 $derate_value1
                        lappend timing_point_list_2 $timing_point1
                        lappend edge_point_list_2 $edge_value_is_1
                        lappend user_point_list_2 $user_value_is_1
 
 
###INNNN
 
                        if {[string equal "NA" $new_common_point]} {
                            set CODE_STATE 17
 
                        } else {
                            if {[string equal $timing_point1 $new_common_point]} {
                                set CODE_STATE 16
                            }
 
 
                        }
                    continue
                }
 
 
                if {$CODE_STATE == 16} {
                        set cell_net_derate_list_2 [lreplace $cell_net_derate_list_2 0 0]
                        set timing_point_list_2 [lreplace $timing_point_list_2 0 0]
                        set user_point_list_2 [lreplace $user_point_list_2 0 0]
                        set PATH_STATE "CAPTURE_CLK"
 
 
                        for {set i 0} {$i < [llength $cell_net_derate_list_2]} {incr i 2} {
                            set element [lindex $cell_net_derate_list_2 $i]
                                if {[format "%.4f" $CAPTURE_CLK_PATH_NET_DERATE_BEFORE_CPPR] != $element} {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i]\t\t\t$element\t\t[format "%.4f" $CAPTURE_CLK_PATH_NET_DERATE_BEFORE_CPPR]"
                                }
 
 
                            set UIP3D [print_main $CHECK_VALUE [lindex $edge_point_list_2 $i] $PATH_STATE 0 [lindex $user_point_list_2 $i]]
 
                                if {[lindex [user_extract [lindex $user_point_list_2 $i]] 0] == [lindex $UIP3D 4]} {
                                   # puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i] : OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_2 $i]] 0] Required [lindex $UIP3D 4] "
 
                                }
 
 
                        }
                    for {set i 1} {$i < [llength $cell_net_derate_list_2]} {incr i 2} {
                        set element1 [lindex $cell_net_derate_list_2 $i]
                            if {[format "%.4f" $CAPTURE_CLK_PATH_CELL_DERATE_BEFORE_CPPR] != $element1} {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i]\t\t\t$element1\t\t[format "%.4f" $CAPTURE_CLK_PATH_CELL_DERATE_BEFORE_CPPR]"
                            }
 
                            set UIP3 [print_main $CHECK_VALUE [lindex $edge_point_list_2 $i] $PATH_STATE 0 [lindex $user_point_list_2 $i]]
## LVF Simga padding
                            if {[lindex $UIP3 0] == [lindex $UIP3 1]} {
                                #puts "passed"
                            } else {
                                puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP3 0] Required [lindex $UIP3 1]"
                            }
## OCV CELL DERATE 
                        if {[lindex $UIP3 2] == [lindex $UIP3 3]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i] : OCV Cell Derate > Actual [lindex $UIP3 2] Required [lindex $UIP3 3]"
                        }
## Cell Sigma PAdding
                        if {[lindex [user_extract [lindex $user_point_list_2 $i]] 1] == [lindex $UIP3 5]} {
                            #puts "passed"
                        } else {
                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_2 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP3 0] Required [lindex $UIP3 1]"
                        }
 
                    }
 
                    set cell_net_derate_list_2 {}
                    set timing_point_list_2 {}
                    set edge_point_list_2 {}
                    set user_point_list_2 {}
                    set CODE_STATE 17
                        continue
                }
 
 
                if {$CODE_STATE == 17} {
                        set datay [regexp -all -inline {\S+} $line]
                        set timing_point_y [lindex $datay 0]
                        set cell_name_y [lindex $datay 1]
                        set derate_value_y [lindex $datay 7]
                        set edge_value_is_y [lindex $datay 13]
                        set user_value_is_y [lindex $datay 6]
                        if {[regexp {\(net\)} $cell_name_y]} {
                            set val4 1
                                continue
                        }
                    if {$val4} {
                        set val4 0
                    }
                        lappend cell_net_derate_list_3 $derate_value_y
                        lappend timing_point_list_3 $timing_point_y
                        lappend edge_point_list_3 $edge_value_is_y
                        lappend user_point_list_3 $user_value_is_y
 
 
                        if {[string match "-------" $line]} {
                                set CODE_STATE 0
                                set PATH_STATE "CAPTURE_CLK"
                                for {set i 0} {$i < [llength $cell_net_derate_list_3]} {incr i 2} {
                                    set element2 [lindex $cell_net_derate_list_3 $i]
 
                                        if {[format "%.4f" $CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR] != $element2} {
                                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i]\t\t\t$element2\t\t[format "%.4f" $CAPTURE_CLK_PATH_NET_DERATE_AFTER_CPPR]"
                                        }
                                        set UIP4D [print_main $CHECK_VALUE [lindex $edge_point_list_3 $i] $PATH_STATE 0 [lindex $user_point_list_3 $i]]
 
                                        if {[lindex [user_extract [lindex $user_point_list_3 $i]] 0] == [lindex $UIP4D 4]} {
                                           # puts "passed"
                                        } else {
                                            puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i]:OCV NET DERATE > Actual [lindex [user_extract [lindex $user_point_list_3 $i]] 0] Required [lindex $UIP4D 4] "
                                          }
                                 }
 
                              for {set i 1} {$i < [llength $cell_net_derate_list_3]} {incr i 2} {
                                set element3 [lindex $cell_net_derate_list_3 $i]
                                    if {[format "%.4f" $CAPTURE_CLK_PATH_CELL_DERATE_AFTER_CPPR] != $element3} {
                                        puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i]\t\t\t$element3\t\t[format "%.4f" $CAPTURE_CLK_PATH_CELL_DERATE_AFTER_CPPR]"
                                    }
                                     set UIP4 [print_main $CHECK_VALUE [lindex $edge_point_list_3 $i] $PATH_STATE 0 [lindex $user_point_list_3 $i]]
 
 ## LVF Simga padding
                                    if {[lindex $UIP4 0] == [lindex $UIP4 1]} {
                                      #  puts "passed"
                                    } else {
                                        puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i] : LVF Sigma Padding Mismatch > Actual [lindex $UIP4 0] Required [lindex $UIP4 1]"
                                    }
 
 # OCV CELL DERATE
                                if {[lindex $UIP4 2] == [lindex $UIP4 3]} {
                                   # puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i] : OCV Cell Derate > Actual [lindex $UIP4 2] Required [lindex $UIP4 3]"
                                }
 
 
## Cell Sigma PAdding
                                if {[lindex [user_extract [lindex $user_point_list_3 $i]] 1] == [lindex $UIP4 5]} {
                                 #   puts "passed"
                                } else {
                                    puts $mismatch_report "$path_name\t\t[lindex $timing_point_list_3 $i] : Delay Sigma Padding Mismatch > Actual [lindex $UIP4 0] Required [lindex $UIP4 1]"
                                }
                            }
                            set cell_net_derate_list_3 {}
                            set timing_point_list_3 {}
                            set timing_point_list_3 {}
                            set user_point_list_3 {}
                            #set CODE_STATE 0
                        }
                    continue
                }
        } ;#while loop end
        
############Reports Closing ##################
    close $mismatch_report
 
set outfile [file join $report_directory "derates_margin_mismatch_$minmax.rpt"]
        set in_block 0
 
# Open the report file for reading
        set file_to [open "$report_directory/derates_mismatch_$minmax.rpt" "r"]
        set output_to [open $outfile "w"]
 
        while {[gets $file_to line] != -1} {
            if {[regexp {^PATH NUMBER:\s*(\d+)$} $line - match number]} {
                set in_block 1
                    continue
            } elseif {$in_block && [string match "-----" $line]} {
# Skip lines containing only dashes
                continue
            } elseif {$in_block} {
                puts $output_to "$line "
            } else {
                puts $output_to "$line "
            }
        }
      close $file_to
        close $output_to
  } ;#for loop ending
        
