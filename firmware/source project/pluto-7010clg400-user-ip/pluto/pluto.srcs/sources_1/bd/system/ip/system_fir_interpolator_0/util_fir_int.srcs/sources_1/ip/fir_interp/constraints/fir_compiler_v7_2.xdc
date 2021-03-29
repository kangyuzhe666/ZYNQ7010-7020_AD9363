# Constraint to suppress expected memory collision errors/warning during post-synthesis simulation
# o Using GENERATE_X_ONLY to ensure any real errors are caught.
set_property -quiet SIM_COLLISION_CHECK GENERATE_X_ONLY [get_cells -quiet -hierarchical  -filter {IS_PRIMITIVE && (TYPE=="Block Memory" || TYPE=="Block Ram")}]
