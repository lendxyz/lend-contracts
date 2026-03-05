#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Usage: $0 contract1 contract2 struct_name"
  echo "contract1 and contract2 should be in the format accepted by forge inspect, e.g., 'src/ContractV1.sol:ContractV1'"
  exit 1
fi

contract1=$1
contract2=$2
struct_name=$3

# Get storage layouts as JSON
layout1=$(forge inspect "$contract1" storage-layout --json)
layout2=$(forge inspect "$contract2" storage-layout --json)

# Function to extract member map as JSON {label: {type, slot}}
extract_map() {
  local layout=$1
  # Get the type key for the 's' variable
  type_key=$(echo "$layout" | jq -r '.storage[] | select(.label == "s").type')
  # Create map
  echo "$layout" | jq --arg key "$type_key" '.types[$key].members | reduce .[] as $m ({}; .[$m.label] = {"type": $m.type | sub("[0-9]+_(storage)"; ""), "slot": $m.slot})'
}

old_map=$(extract_map "$layout1")
new_map=$(extract_map "$layout2")

# Check for removals: if any old labels not in new, fail
missing=$(echo "$old_map $new_map" | jq -s '. as $maps | $maps[0] | keys_unsorted | map(select($maps[1][.] == null)) | length')

if [ "$missing" -gt 0 ]; then
    echo "MISSING_VALUE"
    exit 0;
fi

# Check for differences in slot for common members
diffs_slots=$(echo "$old_map $new_map" | jq -s '. as $maps | $maps[0] | keys_unsorted | map(if $maps[0][.].slot == $maps[1][.].slot then 0 else 1 end) | add')

if [ "$diffs_slots" -gt 0 ]; then
    echo "SLOT_SHIFT"
    exit 0;
fi

# Check for differences in type for common members
diffs_type=$(echo "$old_map $new_map" | jq -s '. as $maps | $maps[0] | keys_unsorted | map(if $maps[0][.].type == $maps[1][.].type then 0 else 1 end) | add')

if [ "$diffs_type" -gt 0 ]; then
    echo "TYPE_CHANGE"
    exit 0;
fi

echo "OK"
exit 0;
