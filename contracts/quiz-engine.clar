;; Quiz Engine Smart Contract
;; Module to deliver interactive quizzes and instant grading

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-QUIZ-NOT-FOUND (err u404))
(define-constant ERR-QUESTION-NOT-FOUND (err u405))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-QUIZ-EXPIRED (err u406))
(define-constant ERR-ALREADY-SUBMITTED (err u407))
(define-constant ERR-INSUFFICIENT-TIME (err u408))

;; Data Variables
(define-data-var quiz-id-counter uint u0)
(define-data-var question-id-counter uint u0)
(define-data-var submission-id-counter uint u0)

;; Quiz definitions and metadata
(define-map quizzes
    { quiz-id: uint }
    {
        title: (string-ascii 128),
        description: (string-ascii 256),
        instructor: principal,
        course-code: (string-ascii 32),
        created-at: uint,
        start-time: uint,
        end-time: uint,
        duration-minutes: uint,
        max-attempts: uint,
        passing-score: uint,
        total-questions: uint,
        shuffle-questions: bool,
        show-results-immediately: bool,
        allow-review: bool,
        quiz-type: (string-ascii 32),
        status: (string-ascii 16)
    }
)

;; Individual questions within quizzes
(define-map quiz-questions
    { question-id: uint }
    {
        quiz-id: uint,
        question-text: (string-ascii 512),
        question-type: (string-ascii 32),
        points: uint,
        time-limit: uint,
        options: (list 6 (string-ascii 128)),
        correct-answers: (list 6 uint),
        explanation: (string-ascii 256),
        difficulty-level: uint,
        tags: (string-ascii 128),
        media-url: (string-ascii 128)
    }
)

;; Student quiz attempts and submissions
(define-map quiz-submissions
    { submission-id: uint }
    {
        quiz-id: uint,
        student-id: uint,
        attempt-number: uint,
        started-at: uint,
        submitted-at: (optional uint),
        time-spent: uint,
        total-score: uint,
        max-score: uint,
        percentage: uint,
        status: (string-ascii 16),
        ip-address: (string-ascii 32),
        browser-info: (string-ascii 128)
    }
)

;; Individual question responses
(define-map question-responses
    { submission-id: uint, question-id: uint }
    {
        student-answer: (list 6 uint),
        is-correct: bool,
        points-awarded: uint,
        time-spent: uint,
        response-confidence: uint,
        flagged-for-review: bool,
        attempt-sequence: uint
    }
)

;; Question banks and pools
(define-map question-banks
    { bank-id: uint }
    {
        bank-name: (string-ascii 64),
        subject-area: (string-ascii 64),
        difficulty-range: (string-ascii 32),
        total-questions: uint,
        created-by: principal,
        public: bool,
        usage-count: uint,
        last-updated: uint
    }
)

;; Quiz analytics and performance metrics
(define-map quiz-analytics
    { quiz-id: uint }
    {
        total-attempts: uint,
        completion-rate: uint,
        average-score: uint,
        average-time: uint,
        highest-score: uint,
        lowest-score: uint,
        question-difficulty: (list 50 uint),
        common-mistakes: (string-ascii 256),
        last-analyzed: uint
    }
)

;; Student performance tracking
(define-map student-quiz-history
    { student-id: uint, quiz-id: uint }
    {
        attempts-made: uint,
        best-score: uint,
        latest-score: uint,
        total-time-spent: uint,
        improvement-trend: int,
        mastery-level: (string-ascii 16),
        topics-mastered: (list 10 (string-ascii 32)),
        topics-struggling: (list 10 (string-ascii 32))
    }
)

;; Anti-cheating and proctoring data
(define-map proctoring-sessions
    { submission-id: uint }
    {
        webcam-enabled: bool,
        screen-recording: bool,
        tab-switches: uint,
        suspicious-activity: uint,
        proctoring-score: uint,
        flags-raised: (list 10 (string-ascii 64)),
        verified-identity: bool,
        session-integrity: (string-ascii 16)
    }
)

;; Private helper functions
(define-private (increment-quiz-counter)
    (let ((current-id (var-get quiz-id-counter)))
        (var-set quiz-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-question-counter)
    (let ((current-id (var-get question-id-counter)))
        (var-set question-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (increment-submission-counter)
    (let ((current-id (var-get submission-id-counter)))
        (var-set submission-id-counter (+ current-id u1))
        current-id
    )
)

(define-private (is-quiz-active (quiz-id uint))
    (match (map-get? quizzes { quiz-id: quiz-id })
        quiz (let ((current-time stacks-block-height)
                   (start-time (get start-time quiz))
                   (end-time (get end-time quiz)))
               (and (>= current-time start-time) (<= current-time end-time)))
        false
    )
)

(define-private (calculate-percentage (score uint) (max-score uint))
    (if (> max-score u0)
        (/ (* score u100) max-score)
        u0
    )
)

(define-private (is-passing-score (score uint) (total uint) (passing-percentage uint))
    (>= (calculate-percentage score total) passing-percentage)
)

;; Public Functions

;; Create new quiz
(define-public (create-quiz
    (title (string-ascii 128))
    (description (string-ascii 256))
    (course-code (string-ascii 32))
    (start-time uint)
    (end-time uint)
    (duration-minutes uint)
    (max-attempts uint)
    (passing-score uint)
    (shuffle-questions bool)
    (show-results-immediately bool)
    (allow-review bool)
    (quiz-type (string-ascii 32))
)
    (let ((quiz-id (increment-quiz-counter)))
        (begin
            (map-set quizzes
                { quiz-id: quiz-id }
                {
                    title: title,
                    description: description,
                    instructor: tx-sender,
                    course-code: course-code,
                    created-at: stacks-block-height,
                    start-time: start-time,
                    end-time: end-time,
                    duration-minutes: duration-minutes,
                    max-attempts: max-attempts,
                    passing-score: passing-score,
                    total-questions: u0,
                    shuffle-questions: shuffle-questions,
                    show-results-immediately: show-results-immediately,
                    allow-review: allow-review,
                    quiz-type: quiz-type,
                    status: "draft"
                }
            )
            ;; Initialize analytics
            (map-set quiz-analytics
                { quiz-id: quiz-id }
                {
                    total-attempts: u0,
                    completion-rate: u0,
                    average-score: u0,
                    average-time: u0,
                    highest-score: u0,
                    lowest-score: u100,
                    question-difficulty: (list),
                    common-mistakes: "",
                    last-analyzed: stacks-block-height
                }
            )
            (ok quiz-id)
        )
    )
)

;; Add question to quiz
(define-public (add-question
    (quiz-id uint)
    (question-text (string-ascii 512))
    (question-type (string-ascii 32))
    (points uint)
    (time-limit uint)
    (options (list 6 (string-ascii 128)))
    (correct-answers (list 6 uint))
    (explanation (string-ascii 256))
    (difficulty-level uint)
    (tags (string-ascii 128))
    (media-url (string-ascii 128))
)
    (let ((question-id (increment-question-counter)))
        (match (map-get? quizzes { quiz-id: quiz-id })
            quiz (if (is-eq (get instructor quiz) tx-sender)
                    (begin
                        (map-set quiz-questions
                            { question-id: question-id }
                            {
                                quiz-id: quiz-id,
                                question-text: question-text,
                                question-type: question-type,
                                points: points,
                                time-limit: time-limit,
                                options: options,
                                correct-answers: correct-answers,
                                explanation: explanation,
                                difficulty-level: difficulty-level,
                                tags: tags,
                                media-url: media-url
                            }
                        )
                        ;; Update quiz total questions
                        (map-set quizzes
                            { quiz-id: quiz-id }
                            (merge quiz { total-questions: (+ (get total-questions quiz) u1) })
                        )
                        (ok question-id)
                    )
                    ERR-NOT-AUTHORIZED
                )
            ERR-QUIZ-NOT-FOUND
        )
    )
)

;; Start quiz attempt
(define-public (start-quiz-attempt
    (quiz-id uint)
    (student-id uint)
    (ip-address (string-ascii 32))
    (browser-info (string-ascii 128))
)
    (let ((submission-id (increment-submission-counter)))
        (if (is-quiz-active quiz-id)
            (match (map-get? quizzes { quiz-id: quiz-id })
                quiz (begin
                        (map-set quiz-submissions
                            { submission-id: submission-id }
                            {
                                quiz-id: quiz-id,
                                student-id: student-id,
                                attempt-number: u1,
                                started-at: stacks-block-height,
                                submitted-at: none,
                                time-spent: u0,
                                total-score: u0,
                                max-score: (* (get total-questions quiz) u10),
                                percentage: u0,
                                status: "in-progress",
                                ip-address: ip-address,
                                browser-info: browser-info
                            }
                        )
                        ;; Initialize proctoring session
                        (map-set proctoring-sessions
                            { submission-id: submission-id }
                            {
                                webcam-enabled: false,
                                screen-recording: false,
                                tab-switches: u0,
                                suspicious-activity: u0,
                                proctoring-score: u100,
                                flags-raised: (list),
                                verified-identity: false,
                                session-integrity: "normal"
                            }
                        )
                        (ok submission-id)
                    )
                ERR-QUIZ-NOT-FOUND
            )
            ERR-QUIZ-EXPIRED
        )
    )
)

;; Submit answer to question
(define-public (submit-answer
    (submission-id uint)
    (question-id uint)
    (student-answer (list 6 uint))
    (time-spent uint)
    (response-confidence uint)
    (flagged-for-review bool)
)
    (match (map-get? quiz-submissions { submission-id: submission-id })
        submission (if (is-eq (get status submission) "in-progress")
                      (match (map-get? quiz-questions { question-id: question-id })
                          question (if (is-eq (get quiz-id question) (get quiz-id submission))
                                      (let ((is-correct (is-eq student-answer (get correct-answers question)))
                                            (points-awarded (if is-correct (get points question) u0)))
                                          (begin
                                              (map-set question-responses
                                                  { submission-id: submission-id, question-id: question-id }
                                                  {
                                                      student-answer: student-answer,
                                                      is-correct: is-correct,
                                                      points-awarded: points-awarded,
                                                      time-spent: time-spent,
                                                      response-confidence: response-confidence,
                                                      flagged-for-review: flagged-for-review,
                                                      attempt-sequence: u1
                                                  }
                                              )
                                              ;; Update submission score
                                              (map-set quiz-submissions
                                                  { submission-id: submission-id }
                                                  (merge submission { 
                                                      total-score: (+ (get total-score submission) points-awarded),
                                                      time-spent: (+ (get time-spent submission) time-spent)
                                                  })
                                              )
                                              (ok points-awarded)
                                          )
                                      )
                                      ERR-INVALID-INPUT
                                  )
                          ERR-QUESTION-NOT-FOUND
                      )
                      ERR-ALREADY-SUBMITTED
                )
        ERR-QUIZ-NOT-FOUND
    )
)

;; Complete quiz submission
(define-public (complete-quiz (submission-id uint))
    (match (map-get? quiz-submissions { submission-id: submission-id })
        submission (if (is-eq (get status submission) "in-progress")
                      (let ((final-percentage (calculate-percentage (get total-score submission) (get max-score submission))))
                          (begin
                              ;; Update submission as completed
                              (map-set quiz-submissions
                                  { submission-id: submission-id }
                                  (merge submission {
                                      submitted-at: (some stacks-block-height),
                                      percentage: final-percentage,
                                      status: "completed"
                                  })
                              )
                              ;; Update student quiz history
                              (map-set student-quiz-history
                                  { student-id: (get student-id submission), quiz-id: (get quiz-id submission) }
                                  {
                                      attempts-made: u1,
                                      best-score: final-percentage,
                                      latest-score: final-percentage,
                                      total-time-spent: (get time-spent submission),
                                      improvement-trend: 0,
                                      mastery-level: (if (>= final-percentage u90) "expert" (if (>= final-percentage u70) "proficient" "novice")),
                                      topics-mastered: (list),
                                      topics-struggling: (list)
                                  }
                              )
                              (ok final-percentage)
                          )
                      )
                      ERR-ALREADY-SUBMITTED
                )
        ERR-QUIZ-NOT-FOUND
    )
)

;; Publish quiz (make it active)
(define-public (publish-quiz (quiz-id uint))
    (match (map-get? quizzes { quiz-id: quiz-id })
        quiz (if (is-eq (get instructor quiz) tx-sender)
                (begin
                    (map-set quizzes
                        { quiz-id: quiz-id }
                        (merge quiz { status: "active" })
                    )
                    (ok true)
                )
                ERR-NOT-AUTHORIZED
            )
        ERR-QUIZ-NOT-FOUND
    )
)

;; Generate quiz report
(define-public (generate-quiz-report (quiz-id uint))
    (match (map-get? quizzes { quiz-id: quiz-id })
        quiz (if (is-eq (get instructor quiz) tx-sender)
                (match (map-get? quiz-analytics { quiz-id: quiz-id })
                    analytics (ok {
                                quiz-id: quiz-id,
                                title: (get title quiz),
                                total-attempts: (get total-attempts analytics),
                                completion-rate: (get completion-rate analytics),
                                average-score: (get average-score analytics),
                                highest-score: (get highest-score analytics),
                                lowest-score: (get lowest-score analytics)
                              })
                    ERR-QUIZ-NOT-FOUND
                )
                ERR-NOT-AUTHORIZED
            )
        ERR-QUIZ-NOT-FOUND
    )
)

;; Record suspicious activity
(define-public (record-suspicious-activity
    (submission-id uint)
    (activity-type (string-ascii 64))
    (severity uint)
)
    (match (map-get? proctoring-sessions { submission-id: submission-id })
        session (let ((updated-session (merge session {
                                         suspicious-activity: (+ (get suspicious-activity session) u1),
                                         proctoring-score: (if (> (get proctoring-score session) severity) 
                                                             (- (get proctoring-score session) severity) 
                                                             u0),
                                         session-integrity: (if (>= severity u50) "compromised" "suspicious")
                                       })))
                    (begin
                        (map-set proctoring-sessions
                            { submission-id: submission-id }
                            updated-session
                        )
                        (ok true)
                    )
                )
        ERR-QUIZ-NOT-FOUND
    )
)

;; Read-only functions

;; Get quiz details
(define-read-only (get-quiz (quiz-id uint))
    (map-get? quizzes { quiz-id: quiz-id })
)

;; Get question details
(define-read-only (get-question (question-id uint))
    (map-get? quiz-questions { question-id: question-id })
)

;; Get quiz submission
(define-read-only (get-submission (submission-id uint))
    (map-get? quiz-submissions { submission-id: submission-id })
)

;; Get question response
(define-read-only (get-question-response (submission-id uint) (question-id uint))
    (map-get? question-responses { submission-id: submission-id, question-id: question-id })
)

;; Get quiz analytics
(define-read-only (get-quiz-analytics (quiz-id uint))
    (map-get? quiz-analytics { quiz-id: quiz-id })
)

;; Get student quiz history
(define-read-only (get-student-quiz-history (student-id uint) (quiz-id uint))
    (map-get? student-quiz-history { student-id: student-id, quiz-id: quiz-id })
)

;; Get proctoring session
(define-read-only (get-proctoring-session (submission-id uint))
    (map-get? proctoring-sessions { submission-id: submission-id })
)

;; Get current counters
(define-read-only (get-quiz-counter)
    (var-get quiz-id-counter)
)

(define-read-only (get-question-counter)
    (var-get question-id-counter)
)

(define-read-only (get-submission-counter)
    (var-get submission-id-counter)
)

