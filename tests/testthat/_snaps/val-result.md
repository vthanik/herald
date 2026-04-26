# print.herald_result snapshot with 0 findings

    Code
      print(r)
    Message
      -- herald validation -- Submission Ready ---------------------------------------
      Rules: 10/10 applied
      Datasets checked: 1
      Findings: 0
      Duration: 1.2 secs

# print.herald_result snapshot with fired findings and severity counts

    Code
      print(r)
    Message
      -- herald validation -- Issues Found -------------------------------------------
      Rules: 10/10 applied
      Datasets checked: 1
      Findings: 2 fired, 1 advisory
      High: 1
      Reject: 1
      Duration: 1.2 secs

# print.herald_result snapshot for Incomplete state

    Code
      print(r)
    Message
      -- herald validation -- Incomplete ---------------------------------------------
      Rules: 2/10 applied
      Datasets checked: 1
      Findings: 0
      Duration: 1.2 secs

# print.herald_result shows profile when set

    Code
      print(r)
    Message
      -- herald validation -- Submission Ready ---------------------------------------
      Rules: 10/10 applied
      Datasets checked: 1
      Findings: 0
      Duration: 1.2 secs
      Profile: sdtm-2.0

# print.herald_result shows op_errors warning

    Code
      print(r)
    Message
      -- herald validation -- Submission Ready ---------------------------------------
      Rules: 10/10 applied
      Datasets checked: 1
      Findings: 0
      Duration: 1.2 secs
      ! 1 operator error during run

# summary.herald_result snapshot with severity breakdown

    Code
      str(stable)
    Output
      List of 8
       $ state              : chr "Issues Found"
       $ rules_applied      : int 10
       $ rules_total        : int 10
       $ datasets_checked   : chr "DM"
       $ n_findings_fired   : int 3
       $ n_findings_advisory: int 1
       $ severity_counts    : 'table' int [1:2(1d)] 1 2
        ..- attr(*, "dimnames")=List of 1
        .. ..$ : chr [1:2] "High" "Reject"
       $ duration           : 'difftime' num 1.2
        ..- attr(*, "units")= chr "secs"

