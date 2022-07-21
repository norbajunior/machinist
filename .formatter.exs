# Used by "mix format"
functions = [event: 1, event: 2, from: 2, from: 3, to: 1, to: 2]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: functions,
  export: [
    locals_without_parens: functions
  ]
]
