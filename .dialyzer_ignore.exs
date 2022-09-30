should_fix = [
  {"lib/forcex/bulk.ex", :no_return},
  {"lib/mix/tasks/compile.forcex.ex", :callback_info_missing},
]

known_bug = [
]

dependency_issue = [
]

should_fix ++ known_bug ++ dependency_issue
