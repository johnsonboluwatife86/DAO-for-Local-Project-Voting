(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_MILESTONE_NOT_FOUND (err u201))
(define-constant ERR_VOTING_ACTIVE (err u202))
(define-constant ERR_ALREADY_VOTED (err u203))
(define-constant ERR_INVALID_MEMBER (err u204))
(define-constant ERR_MILESTONE_RELEASED (err u205))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u206))
(define-constant ERR_INVALID_PERCENTAGE (err u207))

(define-data-var next-milestone-id uint u1)
(define-data-var milestone-approval-threshold uint u60)

(define-map milestones uint {
    proposal-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    fund-percentage: uint,
    amount: uint,
    approvals: uint,
    rejections: uint,
    released: bool,
    created-block: uint
})

(define-map milestone-votes {milestone-id: uint, voter: principal} bool)
(define-map proposal-milestones uint (list 10 uint))

(define-public (create-milestone 
    (proposal-id uint)
    (title (string-ascii 100))
    (description (string-ascii 300))
    (fund-percentage uint)
    (total-amount uint))
    (let
        (
            (milestone-id (var-get next-milestone-id))
            (milestone-amount (/ (* total-amount fund-percentage) u100))
            (current-milestones (default-to (list) (map-get? proposal-milestones proposal-id)))
        )
        (asserts! (and (> fund-percentage u0) (<= fund-percentage u100)) ERR_INVALID_PERCENTAGE)
        (map-set milestones milestone-id {
            proposal-id: proposal-id,
            proposer: tx-sender,
            title: title,
            description: description,
            fund-percentage: fund-percentage,
            amount: milestone-amount,
            approvals: u0,
            rejections: u0,
            released: false,
            created-block: stacks-block-height
        })
        (map-set proposal-milestones proposal-id (unwrap-panic (as-max-len? (append current-milestones milestone-id) u10)))
        (var-set next-milestone-id (+ milestone-id u1))
        (ok milestone-id)
    )
)

(define-public (vote-milestone (milestone-id uint) (approve bool))
    (let
        (
            (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
            (vote-key {milestone-id: milestone-id, voter: tx-sender})
        )
        (asserts! (is-none (map-get? milestone-votes vote-key)) ERR_ALREADY_VOTED)
        (asserts! (not (get released milestone)) ERR_MILESTONE_RELEASED)
        (map-set milestone-votes vote-key approve)
        (if approve
            (map-set milestones milestone-id (merge milestone {approvals: (+ (get approvals milestone) u1)}))
            (map-set milestones milestone-id (merge milestone {rejections: (+ (get rejections milestone) u1)}))
        )
        (ok true)
    )
)

(define-public (release-milestone-funds (milestone-id uint) (total-votes uint))
    (let
        (
            (milestone (unwrap! (map-get? milestones milestone-id) ERR_MILESTONE_NOT_FOUND))
            (approval-rate (/ (* (get approvals milestone) u100) total-votes))
        )
        (asserts! (not (get released milestone)) ERR_MILESTONE_RELEASED)
        (asserts! (>= approval-rate (var-get milestone-approval-threshold)) ERR_INSUFFICIENT_APPROVALS)
        (map-set milestones milestone-id (merge milestone {released: true}))
        (ok (get amount milestone))
    )
)

(define-read-only (get-milestone (milestone-id uint))
    (map-get? milestones milestone-id)
)

(define-read-only (get-proposal-milestones (proposal-id uint))
    (map-get? proposal-milestones proposal-id)
)

(define-read-only (get-milestone-vote (milestone-id uint) (voter principal))
    (map-get? milestone-votes {milestone-id: milestone-id, voter: voter})
)
