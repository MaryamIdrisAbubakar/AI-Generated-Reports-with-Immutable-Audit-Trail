(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_HASH (err u400))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u402))

(define-constant REPUTATION_BOOST_VERIFY u10)
(define-constant REPUTATION_PENALTY_CHALLENGE u5)
(define-constant REPUTATION_BONUS_VERIFIED u5)
(define-constant MIN_AUDITOR_REPUTATION u50)
(define-constant REPUTATION_BOOST_ENDORSE u2)
(define-constant FLAG_THRESHOLD u5)

(define-data-var report-counter uint u0)

(define-map reports
  { report-id: uint }
  {
    hash: (buff 32),
    timestamp: uint,
    creator: principal,
    ai-model: (string-ascii 50),
    report-type: (string-ascii 30),
    metadata: (string-ascii 200),
    verified: bool,
    auditor: (optional principal),
    archived: bool
  }
)

(define-map report-versions
  { report-id: uint, version: uint }
  {
    hash: (buff 32),
    timestamp: uint,
    previous-hash: (optional (buff 32)),
    change-reason: (string-ascii 100)
  }
)

(define-map version-counter
  { report-id: uint }
  { count: uint }
)

(define-map authorized-auditors
  { auditor: principal }
  { active: bool, authorized-by: principal, timestamp: uint }
)

(define-map creator-stats
  { creator: principal }
  { total-reports: uint, verified-reports: uint }
)

(define-map reputation-scores
  { user: principal }
  { 
    score: uint, 
    total-verifications: uint, 
    successful-audits: uint, 
    failed-audits: uint,
    last-updated: uint 
  }
)

(define-map reputation-history
  { user: principal, timestamp: uint }
  { 
    action: (string-ascii 20), 
    score-change: int, 
    new-score: uint, 
    report-id: (optional uint) 
  }
)
(define-map report-endorsements
  { report-id: uint, endorser: principal }
  { timestamp: uint }
)

(define-map endorsement-count
  { report-id: uint }
  { count: uint }
)

(define-map auditor-feedback
  { report-id: uint, auditor: principal }
  { feedback: (string-ascii 200), timestamp: uint, action: (string-ascii 10) }
)

(define-map report-comments
  { report-id: uint, comment-id: uint }
  { commenter: principal, comment: (string-ascii 500), timestamp: uint }
)

(define-map comment-counter
  { report-id: uint }
  { count: uint }
)

(define-map report-flags
  { report-id: uint, flagger: principal }
  { timestamp: uint }
)

(define-map flag-counter
  { report-id: uint }
  { count: uint }
)

(define-read-only (get-report (report-id uint))
  (map-get? reports { report-id: report-id })
)

(define-read-only (get-report-version (report-id uint) (version uint))
  (map-get? report-versions { report-id: report-id, version: version })
)

(define-read-only (get-version-count (report-id uint))
  (default-to 
    { count: u0 } 
    (map-get? version-counter { report-id: report-id })
  )
)

(define-read-only (is-authorized-auditor (auditor principal))
  (match (map-get? authorized-auditors { auditor: auditor })
    entry (get active entry)
    false
  )
)

(define-read-only (get-creator-stats (creator principal))
  (default-to 
    { total-reports: u0, verified-reports: u0 }
    (map-get? creator-stats { creator: creator })
  )
)

(define-read-only (verify-report-hash (report-id uint) (provided-hash (buff 32)))
  (match (get-report report-id)
    report (is-eq (get hash report) provided-hash)
    false
  )
)

(define-read-only (get-reports-by-creator (creator principal) (limit uint))
  (let ((stats (get-creator-stats creator)))
    (if (> (get total-reports stats) u0)
      (ok (get total-reports stats))
      (ok u0)
    )
  )
)

(define-read-only (get-reputation-score (user principal))
  (default-to 
    { score: u100, total-verifications: u0, successful-audits: u0, failed-audits: u0, last-updated: u0 }
    (map-get? reputation-scores { user: user })
  )
)

(define-read-only (get-reputation-rank (user principal))
  (let ((rep (get-reputation-score user)))
    (let ((score (get score rep)))
      (if (>= score u200)
        "Expert"
        (if (>= score u150)
          "Advanced"
          (if (>= score u100)
            "Intermediate"
            (if (>= score u50)
              "Novice"
              "Unranked"
            )
          )
        )
      )
    )
  )
)

(define-read-only (calculate-audit-weight (auditor principal))
  (let ((rep (get-reputation-score auditor)))
    (let ((score (get score rep)))
      (if (>= score u200)
        u3
        (if (>= score u150)
          u2
          u1
        )
      )
    )
  )
)

(define-read-only (is-qualified-auditor (auditor principal))
  (and 
    (is-authorized-auditor auditor)
    (>= (get score (get-reputation-score auditor)) MIN_AUDITOR_REPUTATION)
  )
)

(define-private (update-reputation-score (user principal) (change uint) (action (string-ascii 20)) (report-id (optional uint)))
  (let (
    (current-rep (get-reputation-score user))
    (current-score (get score current-rep))
    (new-score (+ current-score change))
  )
    (map-set reputation-scores
      { user: user }
      (merge current-rep { score: new-score, last-updated: stacks-block-height })
    )
    (map-set reputation-history
      { user: user, timestamp: stacks-block-height }
      { action: action, score-change: (to-int change), new-score: new-score, report-id: report-id }
    )
    new-score
  )
)

(define-private (decrease-reputation-score (user principal) (penalty uint) (action (string-ascii 20)) (report-id (optional uint)))
  (let (
    (current-rep (get-reputation-score user))
    (current-score (get score current-rep))
    (new-score (if (>= current-score penalty)
                  (- current-score penalty)
                  u0))
  )
    (map-set reputation-scores
      { user: user }
      (merge current-rep { score: new-score, last-updated: stacks-block-height })
    )
    (map-set reputation-history
      { user: user, timestamp: stacks-block-height }
      { action: action, score-change: (- 0 (to-int penalty)), new-score: new-score, report-id: report-id }
    )
    new-score
   )
)

(define-public (authorize-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-auditors 
      { auditor: auditor }
      { active: true, authorized-by: tx-sender, timestamp: stacks-block-height }
    )
    (update-reputation-score auditor u50 "auditor-authorized" none)
    (ok true)
  )
)

(define-public (revoke-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-auditors 
      { auditor: auditor }
      { active: false, authorized-by: tx-sender, timestamp: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (submit-report 
  (hash (buff 32)) 
  (ai-model (string-ascii 50)) 
  (report-type (string-ascii 30))
  (metadata (string-ascii 200))
)
  (let (
    (new-id (+ (var-get report-counter) u1))
    (current-stats (get-creator-stats tx-sender))
  )
    (asserts! (> (len hash) u0) ERR_INVALID_HASH)
    (map-set reports
      { report-id: new-id }
      {
        hash: hash,
        timestamp: stacks-block-height,
        creator: tx-sender,
        ai-model: ai-model,
        report-type: report-type,
        metadata: metadata,
        verified: false,
        auditor: none,
        archived: false
      }
    )
    (map-set version-counter
      { report-id: new-id }
      { count: u1 }
    )
    (map-set report-versions
      { report-id: new-id, version: u1 }
      {
        hash: hash,
        timestamp: stacks-block-height,
        previous-hash: none,
        change-reason: "Initial submission"
      }
    )
    (map-set creator-stats
      { creator: tx-sender }
      { 
        total-reports: (+ (get total-reports current-stats) u1),
        verified-reports: (get verified-reports current-stats)
      }
    )
    (var-set report-counter new-id)
    (ok new-id)
  )
)

(define-public (update-report 
  (report-id uint) 
  (new-hash (buff 32)) 
  (change-reason (string-ascii 100))
)
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (version-info (get-version-count report-id))
    (new-version (+ (get count version-info) u1))
  )
    (asserts! (is-eq tx-sender (get creator report)) ERR_UNAUTHORIZED)
    (asserts! (not (get archived report)) ERR_UNAUTHORIZED)
    (asserts! (> (len new-hash) u0) ERR_INVALID_HASH)
    (map-set reports
      { report-id: report-id }
      (merge report { hash: new-hash, timestamp: stacks-block-height, verified: false, auditor: none })
    )
    (map-set version-counter
      { report-id: report-id }
      { count: new-version }
    )
    (map-set report-versions
      { report-id: report-id, version: new-version }
      {
        hash: new-hash,
        timestamp: stacks-block-height,
        previous-hash: (some (get hash report)),
        change-reason: change-reason
      }
    )
    (ok new-version)
  )
)

(define-public (verify-report (report-id uint))
  (let ((report (unwrap! (get-report report-id) ERR_NOT_FOUND)))
    (asserts! (is-qualified-auditor tx-sender) ERR_INSUFFICIENT_REPUTATION)
    (map-set reports
      { report-id: report-id }
      (merge report { verified: true, auditor: (some tx-sender) })
    )
    (let (
      (creator (get creator report))
      (current-stats (get-creator-stats creator))
      (auditor-rep (get-reputation-score tx-sender))
    )
      (map-set creator-stats
        { creator: creator }
        { 
          total-reports: (get total-reports current-stats),
          verified-reports: (+ (get verified-reports current-stats) u1)
        }
      )
      (update-reputation-score creator REPUTATION_BONUS_VERIFIED "report-verified" (some report-id))
      (update-reputation-score tx-sender REPUTATION_BOOST_VERIFY "audit-verify" (some report-id))
      (map-set reputation-scores
        { user: tx-sender }
        (merge auditor-rep { successful-audits: (+ (get successful-audits auditor-rep) u1) })
      )
    )
    (ok true)
  )
)

(define-public (challenge-report (report-id uint) (reason (string-ascii 100)))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (creator (get creator report))
  )
    (asserts! (is-qualified-auditor tx-sender) ERR_INSUFFICIENT_REPUTATION)
    (map-set reports
      { report-id: report-id }
      (merge report { verified: false, auditor: (some tx-sender) })
    )
    (let (
      (auditor-rep (get-reputation-score tx-sender))
      (creator-rep (get-reputation-score creator))
    )
      (decrease-reputation-score creator REPUTATION_PENALTY_CHALLENGE "report-challenged" (some report-id))
      (update-reputation-score tx-sender REPUTATION_BOOST_VERIFY "audit-challenge" (some report-id))
      (map-set reputation-scores
        { user: tx-sender }
        (merge auditor-rep { failed-audits: (+ (get failed-audits auditor-rep) u1) })
      )
    )
    (ok true)
  )
)
(define-public (endorse-report (report-id uint))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (creator (get creator report))
    (current-count (get count (get-endorsement-count report-id)))
  )
    (asserts! (is-none (map-get? report-endorsements { report-id: report-id, endorser: tx-sender })) ERR_ALREADY_EXISTS)
    (map-set report-endorsements { report-id: report-id, endorser: tx-sender } { timestamp: stacks-block-height })
    (map-set endorsement-count { report-id: report-id } { count: (+ current-count u1) })
    (update-reputation-score creator REPUTATION_BOOST_ENDORSE "report-endorsed" (some report-id))
    (ok true)
  )
)

(define-read-only (get-report-trail (report-id uint))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (version-count (get count (get-version-count report-id)))
  )
    (ok {
      report: report,
      total-versions: version-count,
      latest-version: version-count
    })
  )
)

(define-read-only (audit-report-integrity (report-id uint))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (version-count (get count (get-version-count report-id)))
  )
    (ok {
      report-exists: true,
      creator: (get creator report),
      creation-time: (get timestamp report),
      verified: (get verified report),
      auditor: (get auditor report),
      total-versions: version-count,
      ai-model: (get ai-model report),
      report-type: (get report-type report)
    })
  )
)

(define-read-only (is-report-archived (report-id uint))
  (match (get-report report-id)
    report (get archived report)
    false
  )
)

(define-public (archive-report (report-id uint))
  (let ((report (unwrap! (get-report report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get creator report)) ERR_UNAUTHORIZED)
    (asserts! (not (get archived report)) ERR_ALREADY_EXISTS)
    (map-set reports
      { report-id: report-id }
      (merge report { archived: true })
    )
    (ok true)
  )
)

(define-public (submit-auditor-feedback (report-id uint) (feedback (string-ascii 200)) (action (string-ascii 10)))
 (let ((report (unwrap! (get-report report-id) ERR_NOT_FOUND)))
   (asserts! (is-qualified-auditor tx-sender) ERR_INSUFFICIENT_REPUTATION)
   (asserts! (is-eq (some tx-sender) (get auditor report)) ERR_UNAUTHORIZED)
   (asserts! (or (is-eq action "verify") (is-eq action "challenge")) ERR_INVALID_HASH)
   (map-set auditor-feedback { report-id: report-id, auditor: tx-sender } { feedback: feedback, timestamp: stacks-block-height, action: action })
   (ok true)
 )
)

(define-read-only (get-auditor-feedback (report-id uint) (auditor principal))
  (map-get? auditor-feedback { report-id: report-id, auditor: auditor })
)

(define-public (add-comment (report-id uint) (comment (string-ascii 500)))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (current-count (get count (default-to { count: u0 } (map-get? comment-counter { report-id: report-id }))))
    (new-id (+ current-count u1))
  )
    (map-set report-comments
      { report-id: report-id, comment-id: new-id }
      { commenter: tx-sender, comment: comment, timestamp: stacks-block-height }
    )
    (map-set comment-counter
      { report-id: report-id }
      { count: new-id }
    )
    (ok new-id)
  )
)

(define-read-only (get-comment (report-id uint) (comment-id uint))
  (map-get? report-comments { report-id: report-id, comment-id: comment-id })
)

(define-read-only (get-comment-count (report-id uint))
  (default-to { count: u0 } (map-get? comment-counter { report-id: report-id }))
)

(define-read-only (get-endorsement-count (report-id uint))
  (default-to { count: u0 } (map-get? endorsement-count { report-id: report-id })))

(define-public (flag-report (report-id uint))
  (let (
    (report (unwrap! (get-report report-id) ERR_NOT_FOUND))
    (current-count (get count (default-to { count: u0 } (map-get? flag-counter { report-id: report-id }))))
  )
    (asserts! (is-none (map-get? report-flags { report-id: report-id, flagger: tx-sender })) ERR_ALREADY_EXISTS)
    (map-set report-flags { report-id: report-id, flagger: tx-sender } { timestamp: stacks-block-height })
    (map-set flag-counter { report-id: report-id } { count: (+ current-count u1) })
    (ok true)
  )
)

(define-read-only (get-flag-count (report-id uint))
  (default-to { count: u0 } (map-get? flag-counter { report-id: report-id })))

(define-read-only (is-report-flagged (report-id uint))
  (>= (get count (get-flag-count report-id)) FLAG_THRESHOLD))
