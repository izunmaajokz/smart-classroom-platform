;; Attendance System Smart Contract
;; Module for tracking student participation and attendance

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-STUDENT-NOT-FOUND (err u404))
(define-constant ERR-SESSION-NOT-FOUND (err u405))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-ALREADY-CHECKED-IN (err u406))
(define-constant ERR-NOT-CHECKED-IN (err u407))
(define-constant ERR-SESSION-ENDED (err u408))

;; Data Variables
(define-data-var student-id-counter uint u0)
(define-data-var session-id-counter uint u0)
(define-data-var attendance-record-counter uint u0)

;; Student profiles and enrollment
(define-map student-profiles
    { student-id: uint }
    {
        student-wallet: principal,
        student-name: (string-ascii 64),
        student-email: (string-ascii 128),
        institution-id: (string-ascii 32),
        enrollment-date: uint,
        status: (string-ascii 16),
        total-sessions-attended: uint,
        total-sessions-enrolled: uint,
        attendance-percentage: uint
    }
)

;; Class sessions and scheduling
(define-map class-sessions
    { session-id: uint }
    {
        course-code: (string-ascii 32),
        course-title: (string-ascii 128),
        instructor: principal,
        session-date: uint,
        start-time: uint,
        end-time: uint,
        max-students: uint,
        enrolled-count: uint,
        attendance-count: uint,
        session-type: (string-ascii 32),
        location: (string-ascii 128),
        status: (string-ascii 16)
    }
)

;; Student enrollment in courses
(define-map course-enrollments
    { student-id: uint, course-code: (string-ascii 32) }
    {
        enrollment-date: uint,
        enrollment-status: (string-ascii 16),
        grade: (string-ascii 8),
        participation-score: uint,
        attendance-record: (list 50 bool)
    }
)

;; Individual attendance records
(define-map attendance-records
    { record-id: uint }
    {
        student-id: uint,
        session-id: uint,
        check-in-time: uint,
        check-out-time: (optional uint),
        duration-minutes: uint,
        participation-level: uint,
        interaction-count: uint,
        location-verified: bool,
        device-info: (string-ascii 128),
        status: (string-ascii 16)
    }
)

;; Real-time session participation tracking
(define-map session-participation
    { session-id: uint, student-id: uint }
    {
        current-status: (string-ascii 16),
        last-interaction: uint,
        engagement-score: uint,
        questions-asked: uint,
        responses-given: uint,
        chat-messages: uint,
        screen-share-time: uint,
        camera-on-time: uint
    }
)

;; Attendance policies and rules
(define-map attendance-policies
    { course-code: (string-ascii 32) }
    {
        minimum-attendance-percentage: uint,
        late-arrival-grace-period: uint,
        early-departure-penalty: uint,
        participation-weight: uint,
        automatic-drop-threshold: uint,
        makeup-session-allowed: bool,
        excused-absence-limit: uint
    }
)

;; Student notifications and alerts
(define-map attendance-alerts
    { student-id: uint, alert-id: uint }
    {
        alert-type: (string-ascii 32),
        message: (string-ascii 256),
        severity: (string-ascii 16),
        created-at: uint,
        acknowledged: bool,
        action-required: bool
    }
)

;; Instructor dashboard data
(define-map instructor-analytics
    { instructor: principal, course-code: (string-ascii 32) }
    {
        total-sessions: uint,
        average-attendance: uint,
        at-risk-students: uint,
        engagement-trends: (string-ascii 128),
        last-updated: uint
    }
)

;; Private helper functions
(define-private (increment-student-counter)
    (let ((current-id (var-get student-id-counter)))
        (var-set student-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-session-counter)
    (let ((current-id (var-get session-id-counter)))
        (var-set session-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-record-counter)
    (let ((current-id (var-get attendance-record-counter)))
        (var-set attendance-record-counter (+ current-id u1))
        current-id
    )
)

(define-private (is-session-active (session-id uint))
    (match (map-get? class-sessions { session-id: session-id })
        session (let ((current-time stacks-block-height)
                      (start-time (get start-time session))
                      (end-time (get end-time session)))
                  (and (>= current-time start-time) (<= current-time end-time)))
        false
    )
)

(define-private (calculate-attendance-percentage (attended uint) (total uint))
    (if (> total u0)
        (/ (* attended u100) total)
        u0
    )
)

(define-private (is-student-enrolled (student-id uint) (course-code (string-ascii 32)))
    (is-some (map-get? course-enrollments { student-id: student-id, course-code: course-code }))
)

(define-private (update-student-attendance-stats (student-id uint))
    (match (map-get? student-profiles { student-id: student-id })
        student (let ((new-percentage (calculate-attendance-percentage 
                                        (get total-sessions-attended student) 
                                        (get total-sessions-enrolled student))))
                  (map-set student-profiles
                      { student-id: student-id }
                      (merge student { attendance-percentage: new-percentage })
                  )
                  true)
        false
    )
)

;; Public Functions

;; Register new student
(define-public (register-student
    (student-name (string-ascii 64))
    (student-email (string-ascii 128))
    (institution-id (string-ascii 32))
)
    (let ((student-id (increment-student-counter)))
        (begin
            (map-set student-profiles
                { student-id: student-id }
                {
                    student-wallet: tx-sender,
                    student-name: student-name,
                    student-email: student-email,
                    institution-id: institution-id,
                    enrollment-date: stacks-block-height,
                    status: "active",
                    total-sessions-attended: u0,
                    total-sessions-enrolled: u0,
                    attendance-percentage: u0
                }
            )
            (ok student-id)
        )
    )
)

;; Create class session
(define-public (create-class-session
    (course-code (string-ascii 32))
    (course-title (string-ascii 128))
    (session-date uint)
    (start-time uint)
    (end-time uint)
    (max-students uint)
    (session-type (string-ascii 32))
    (location (string-ascii 128))
)
    (let ((session-id (increment-session-counter)))
        (begin
            (map-set class-sessions
                { session-id: session-id }
                {
                    course-code: course-code,
                    course-title: course-title,
                    instructor: tx-sender,
                    session-date: session-date,
                    start-time: start-time,
                    end-time: end-time,
                    max-students: max-students,
                    enrolled-count: u0,
                    attendance-count: u0,
                    session-type: session-type,
                    location: location,
                    status: "scheduled"
                }
            )
            (ok session-id)
        )
    )
)

;; Enroll student in course
(define-public (enroll-student
    (student-id uint)
    (course-code (string-ascii 32))
)
    (if (is-some (map-get? student-profiles { student-id: student-id }))
        (if (not (is-student-enrolled student-id course-code))
            (begin
                (map-set course-enrollments
                    { student-id: student-id, course-code: course-code }
                    {
                        enrollment-date: stacks-block-height,
                        enrollment-status: "active",
                        grade: "",
                        participation-score: u0,
                        attendance-record: (list)
                    }
                )
                ;; Update student's total enrolled sessions
                (match (map-get? student-profiles { student-id: student-id })
                    student (begin
                              (map-set student-profiles
                                  { student-id: student-id }
                                  (merge student { total-sessions-enrolled: (+ (get total-sessions-enrolled student) u1) })
                              )
                              (ok true))
                    ERR-STUDENT-NOT-FOUND
                )
            )
            (err u409) ;; Already enrolled
        )
        ERR-STUDENT-NOT-FOUND
    )
)

;; Student check-in to session
(define-public (check-in-session
    (student-id uint)
    (session-id uint)
    (location-verified bool)
    (device-info (string-ascii 128))
)
    (let ((record-id (increment-record-counter)))
        (if (and 
              (is-some (map-get? student-profiles { student-id: student-id }))
              (is-some (map-get? class-sessions { session-id: session-id }))
              (is-session-active session-id)
            )
            (match (map-get? class-sessions { session-id: session-id })
                session (if (is-student-enrolled student-id (get course-code session))
                          (begin
                              ;; Create attendance record
                              (map-set attendance-records
                                  { record-id: record-id }
                                  {
                                      student-id: student-id,
                                      session-id: session-id,
                                      check-in-time: stacks-block-height,
                                      check-out-time: none,
                                      duration-minutes: u0,
                                      participation-level: u1,
                                      interaction-count: u0,
                                      location-verified: location-verified,
                                      device-info: device-info,
                                      status: "checked-in"
                                  }
                              )
                              ;; Initialize session participation
                              (map-set session-participation
                                  { session-id: session-id, student-id: student-id }
                                  {
                                      current-status: "active",
                                      last-interaction: stacks-block-height,
                                      engagement-score: u1,
                                      questions-asked: u0,
                                      responses-given: u0,
                                      chat-messages: u0,
                                      screen-share-time: u0,
                                      camera-on-time: u0
                                  }
                              )
                              ;; Update session attendance count
                              (map-set class-sessions
                                  { session-id: session-id }
                                  (merge session { attendance-count: (+ (get attendance-count session) u1) })
                              )
                              (ok record-id)
                          )
                          ERR-NOT-AUTHORIZED
                        )
                ERR-SESSION-NOT-FOUND
            )
            ERR-SESSION-NOT-FOUND
        )
    )
)

;; Student check-out from session
(define-public (check-out-session (record-id uint))
    (match (map-get? attendance-records { record-id: record-id })
        record (if (is-eq (get status record) "checked-in")
                  (let ((duration (- stacks-block-height (get check-in-time record))))
                      (begin
                          (map-set attendance-records
                              { record-id: record-id }
                              (merge record {
                                  check-out-time: (some stacks-block-height),
                                  duration-minutes: duration,
                                  status: "completed"
                              })
                          )
                          ;; Update student total attended sessions
                          (match (map-get? student-profiles { student-id: (get student-id record) })
                              student (begin
                                        (map-set student-profiles
                                            { student-id: (get student-id record) }
                                            (merge student { total-sessions-attended: (+ (get total-sessions-attended student) u1) })
                                        )
                                        (update-student-attendance-stats (get student-id record))
                                        (ok true))
                              ERR-STUDENT-NOT-FOUND
                          )
                      )
                  )
                  ERR-NOT-CHECKED-IN
                )
        ERR-STUDENT-NOT-FOUND
    )
)

;; Record student interaction during session
(define-public (record-interaction
    (session-id uint)
    (student-id uint)
    (interaction-type (string-ascii 32))
)
    (match (map-get? session-participation { session-id: session-id, student-id: student-id })
        participation (let ((updated-participation 
                              (merge participation {
                                  last-interaction: stacks-block-height,
                                  engagement-score: (+ (get engagement-score participation) u1),
                                  questions-asked: (if (is-eq interaction-type "question") 
                                                     (+ (get questions-asked participation) u1) 
                                                     (get questions-asked participation)),
                                  responses-given: (if (is-eq interaction-type "response") 
                                                     (+ (get responses-given participation) u1) 
                                                     (get responses-given participation)),
                                  chat-messages: (if (is-eq interaction-type "chat") 
                                                   (+ (get chat-messages participation) u1) 
                                                   (get chat-messages participation))
                              })))
                        (begin
                            (map-set session-participation
                                { session-id: session-id, student-id: student-id }
                                updated-participation
                            )
                            (ok true)
                        )
                      )
        ERR-STUDENT-NOT-FOUND
    )
)

;; Set attendance policy for course
(define-public (set-attendance-policy
    (course-code (string-ascii 32))
    (minimum-attendance-percentage uint)
    (late-arrival-grace-period uint)
    (early-departure-penalty uint)
    (participation-weight uint)
    (automatic-drop-threshold uint)
    (makeup-session-allowed bool)
    (excused-absence-limit uint)
)
    (begin
        (map-set attendance-policies
            { course-code: course-code }
            {
                minimum-attendance-percentage: minimum-attendance-percentage,
                late-arrival-grace-period: late-arrival-grace-period,
                early-departure-penalty: early-departure-penalty,
                participation-weight: participation-weight,
                automatic-drop-threshold: automatic-drop-threshold,
                makeup-session-allowed: makeup-session-allowed,
                excused-absence-limit: excused-absence-limit
            }
        )
        (ok true)
    )
)

;; Generate attendance report for student
(define-public (generate-attendance-report (student-id uint) (course-code (string-ascii 32)))
    (if (and 
          (is-some (map-get? student-profiles { student-id: student-id }))
          (is-student-enrolled student-id course-code)
        )
        (match (map-get? course-enrollments { student-id: student-id, course-code: course-code })
            enrollment (ok {
                          student-id: student-id,
                          course-code: course-code,
                          enrollment-status: (get enrollment-status enrollment),
                          participation-score: (get participation-score enrollment),
                          attendance-record: (get attendance-record enrollment)
                        })
            ERR-STUDENT-NOT-FOUND
        )
        ERR-NOT-AUTHORIZED
    )
)

;; Read-only functions

;; Get student profile
(define-read-only (get-student-profile (student-id uint))
    (map-get? student-profiles { student-id: student-id })
)

;; Get class session details
(define-read-only (get-class-session (session-id uint))
    (map-get? class-sessions { session-id: session-id })
)

;; Get attendance record
(define-read-only (get-attendance-record (record-id uint))
    (map-get? attendance-records { record-id: record-id })
)

;; Get session participation
(define-read-only (get-session-participation (session-id uint) (student-id uint))
    (map-get? session-participation { session-id: session-id, student-id: student-id })
)

;; Get course enrollment
(define-read-only (get-course-enrollment (student-id uint) (course-code (string-ascii 32)))
    (map-get? course-enrollments { student-id: student-id, course-code: course-code })
)

;; Get attendance policy
(define-read-only (get-attendance-policy (course-code (string-ascii 32)))
    (map-get? attendance-policies { course-code: course-code })
)

;; Get instructor analytics
(define-read-only (get-instructor-analytics (instructor principal) (course-code (string-ascii 32)))
    (map-get? instructor-analytics { instructor: instructor, course-code: course-code })
)

;; Get current counters
(define-read-only (get-student-counter)
    (var-get student-id-counter)
)

(define-read-only (get-session-counter)
    (var-get session-id-counter)
)

(define-read-only (get-record-counter)
    (var-get attendance-record-counter)
)

