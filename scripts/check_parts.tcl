# TCL script to find available installed parts in Vivado
set parts [get_parts]
puts "TOTAL_PARTS_FOUND: [llength $parts]"
puts "SAMPLE_PARTS: [lrange $parts 0 10]"
