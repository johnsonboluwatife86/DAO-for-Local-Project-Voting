(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_VOTING_PERIOD_ENDED (err u102))
(define-constant ERR_VOTING_PERIOD_ACTIVE (err u103))
(define-constant ERR_ALREADY_VOTED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_PROPOSAL_NOT_APPROVED (err u106))
(define-constant ERR_ALREADY_EXECUTED (err u107))
(define-constant ERR_INVALID_MEMBER (err u108))
(define-constant ERR_MEMBER_EXISTS (err u109))
(define-constant ERR_INVALID_DURATION (err u110))
(define-constant ERR_INVALID_AMOUNT (err u111))

(define-data-var next-proposal-id uint u1)
(define-data-var total-members uint u0)
(define-data-var quorum-percentage uint u51)

(define-map members principal bool)
(define-map member-voting-power principal uint)

(define-map proposals uint {
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-amount: uint,
    start-block: uint,
    end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    executed: bool,
    approved: bool
})

(define-map votes {proposal-id: uint, voter: principal} bool)

(define-read-only (is-member (address principal))
    (default-to false (map-get? members address))
)

(define-public (add-member (member principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (not (is-member member)) ERR_MEMBER_EXISTS)
        (map-set members member true)
        (map-set member-voting-power member u1)
        (var-set total-members (+ (var-get total-members) u1))
        (ok true)
    )
)

(define-public (remove-member (member principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (is-member member) ERR_INVALID_MEMBER)
        (map-delete members member)
        (map-delete member-voting-power member)
        (var-set total-members (- (var-get total-members) u1))
        (ok true)
    )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (funding-amount uint) (duration uint))
    (let
        (
            (proposal-id (var-get next-proposal-id))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration))
        )
        (asserts! (is-member tx-sender) ERR_INVALID_MEMBER)
        (asserts! (> duration u0) ERR_INVALID_DURATION)
        (asserts! (> funding-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (<= funding-amount (stx-get-balance (as-contract tx-sender))) ERR_INSUFFICIENT_FUNDS)
        
        (map-set proposals proposal-id {
            proposer: tx-sender,
            title: title,
            description: description,
            funding-amount: funding-amount,
            start-block: start-block,
            end-block: end-block,
            yes-votes: u0,
            no-votes: u0,
            executed: false,
            approved: false
        })
        
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (voting-power (get-voting-power tx-sender))
            (vote-key {proposal-id: proposal-id, voter: tx-sender})
        )
        (asserts! (is-member tx-sender) ERR_INVALID_MEMBER)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR_VOTING_PERIOD_ENDED)
        (asserts! (is-none (map-get? votes vote-key)) ERR_ALREADY_VOTED)
        
        (map-set votes vote-key support)
        
        (if support
            (map-set proposals proposal-id 
                (merge proposal {yes-votes: (+ (get yes-votes proposal) voting-power)}))
            (map-set proposals proposal-id 
                (merge proposal {no-votes: (+ (get no-votes proposal) voting-power)}))
        )
        
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
            (required-quorum (/ (* (var-get total-members) (var-get quorum-percentage)) u100))
        )
        (asserts! (> stacks-block-height (get end-block proposal)) ERR_VOTING_PERIOD_ACTIVE)
        (asserts! (not (get executed proposal)) ERR_ALREADY_EXECUTED)
        (asserts! (>= total-votes required-quorum) ERR_PROPOSAL_NOT_APPROVED)
        (asserts! (> (get yes-votes proposal) (get no-votes proposal)) ERR_PROPOSAL_NOT_APPROVED)
        
        (map-set proposals proposal-id (merge proposal {executed: true, approved: true}))
        
        (as-contract (stx-transfer? (get funding-amount proposal) tx-sender (get proposer proposal)))
    )
)

(define-public (fund-dao)
    (stx-transfer? u1000000 tx-sender (as-contract tx-sender))
)

(define-public (set-quorum-percentage (new-percentage uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (> new-percentage u0) (<= new-percentage u100)) (err u112))
        (var-set quorum-percentage new-percentage)
        (ok true)
    )
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-voting-power (address principal))
    (default-to u0 (map-get? member-voting-power address))
)

(define-read-only (get-total-members)
    (var-get total-members)
)

(define-read-only (get-quorum-percentage)
    (var-get quorum-percentage)
)

(define-read-only (get-next-proposal-id)
    (var-get next-proposal-id)
)

(define-read-only (get-dao-balance)
    (stx-get-balance (as-contract tx-sender))
)

(define-read-only (proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
            (let
                (
                    (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
                    (required-quorum (/ (* (var-get total-members) (var-get quorum-percentage)) u100))
                    (is-active (<= stacks-block-height (get end-block proposal)))
                    (has-quorum (>= total-votes required-quorum))
                    (is-approved (> (get yes-votes proposal) (get no-votes proposal)))
                )
                (ok {
                    active: is-active,
                    executed: (get executed proposal),
                    approved: (get approved proposal),
                    has-quorum: has-quorum,
                    can-execute: (and (not is-active) (not (get executed proposal)) has-quorum is-approved),
                    total-votes: total-votes,
                    required-quorum: required-quorum
                })
            )
        ERR_PROPOSAL_NOT_FOUND
    )
)

(define-read-only (get-proposal-results (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal
            (ok {
                yes-votes: (get yes-votes proposal),
                no-votes: (get no-votes proposal),
                total-votes: (+ (get yes-votes proposal) (get no-votes proposal)),
                yes-percentage: (if (> (+ (get yes-votes proposal) (get no-votes proposal)) u0)
                    (/ (* (get yes-votes proposal) u100) (+ (get yes-votes proposal) (get no-votes proposal)))
                    u0)
            })
        ERR_PROPOSAL_NOT_FOUND
    )
)

(define-read-only (get-highest-proposal-id)
    (- (var-get next-proposal-id) u1)
)

(begin
    (map-set members CONTRACT_OWNER true)
    (map-set member-voting-power CONTRACT_OWNER u1)
    (var-set total-members u1)
)
