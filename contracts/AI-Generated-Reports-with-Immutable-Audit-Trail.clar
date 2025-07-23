(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_HASH (err u400))

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
    auditor: (optional principal)
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

(define-public (authorize-auditor (auditor principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-auditors 
      { auditor: auditor }
      { active: true, authorized-by: tx-sender, timestamp: stacks-block-height }
    )
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
        auditor: none
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
    (asserts! (is-authorized-auditor tx-sender) ERR_UNAUTHORIZED)
    (map-set reports
      { report-id: report-id }
      (merge report { verified: true, auditor: (some tx-sender) })
    )
    (let (
      (creator (get creator report))
      (current-stats (get-creator-stats creator))
    )
      (map-set creator-stats
        { creator: creator }
        { 
          total-reports: (get total-reports current-stats),
          verified-reports: (+ (get verified-reports current-stats) u1)
        }
      )
    )
    (ok true)
  )
)

(define-public (challenge-report (report-id uint) (reason (string-ascii 100)))
  (let ((report (unwrap! (get-report report-id) ERR_NOT_FOUND)))
    (asserts! (is-authorized-auditor tx-sender) ERR_UNAUTHORIZED)
    (map-set reports
      { report-id: report-id }
      (merge report { verified: false, auditor: (some tx-sender) })
    )
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
