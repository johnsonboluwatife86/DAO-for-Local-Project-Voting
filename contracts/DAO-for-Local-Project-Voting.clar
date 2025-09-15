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

(define-map member-participation-score principal uint)
(define-map member-last-vote-block principal uint)
(define-map member-total-contributions principal uint)
(define-data-var participation-bonus-multiplier uint u2)
(define-data-var contribution-power-ratio uint u100000)
(define-data-var decay-blocks uint u1000)

(define-data-var next-proposal-id uint u1)
(define-data-var total-members uint u0)
(define-data-var quorum-percentage uint u51)

(define-map members principal bool)
(define-map member-voting-power principal uint)

(define-constant ERR_CANNOT_DELEGATE_TO_SELF (err u113))
(define-constant ERR_DELEGATE_NOT_MEMBER (err u114))
(define-constant ERR_NOT_DELEGATED (err u115))

(define-constant ERR_DAO_FROZEN (err u116))
(define-constant ERR_ALREADY_VOTED_EMERGENCY (err u117))
(define-constant ERR_INSUFFICIENT_EMERGENCY_VOTES (err u118))

(define-data-var is-emergency-frozen bool false)
(define-data-var emergency-freeze-threshold uint u3)
(define-data-var freeze-proposal-id uint u0)
(define-data-var current-freeze-votes uint u0)
(define-data-var current-unfreeze-votes uint u0)

(define-map member-delegates principal principal)
(define-map delegated-power principal uint)

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
        
        (let ((result (update-voting-power-on-vote tx-sender)))
            (ok true))
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


(define-public (update-voting-power-on-vote (member principal))
    (let
        (
            (current-score (default-to u0 (map-get? member-participation-score member)))
            (last-vote-block (default-to u0 (map-get? member-last-vote-block member)))
            (blocks-since-last-vote (- stacks-block-height last-vote-block))
            (decay-factor (if (> blocks-since-last-vote (var-get decay-blocks)) u1 u0))
            (new-score (+ current-score u1))
            (participation-bonus (/ new-score (var-get participation-bonus-multiplier)))
            (contribution-power (/ (get-member-contributions member) (var-get contribution-power-ratio)))
            (decayed-power (if (> decay-factor u0) u1 (get-voting-power member)))
            (new-power (+ u1 participation-bonus contribution-power))
        )
        (map-set member-participation-score member new-score)
        (map-set member-last-vote-block member stacks-block-height)
        (map-set member-voting-power member (if (> decayed-power new-power) decayed-power new-power))
        (ok true)
    )
)

(define-public (contribute-to-dao (amount uint))
    (let
        (
            (current-contributions (get-member-contributions tx-sender))
        )
        (asserts! (is-member tx-sender) ERR_INVALID_MEMBER)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set member-total-contributions tx-sender (+ current-contributions amount))
        (let ((result (update-voting-power-on-contribution tx-sender)))
            true)
        (ok true)
    )
)

(define-private (update-voting-power-on-contribution (member principal))
    (let
        (
            (current-power (get-voting-power member))
            (contribution-power (/ (get-member-contributions member) (var-get contribution-power-ratio)))
            (participation-bonus (/ (get-member-participation member) (var-get participation-bonus-multiplier)))
            (new-power (+ u1 participation-bonus contribution-power))
        )
        (map-set member-voting-power member new-power)
        (ok true)
    )
)

(define-public (set-participation-multiplier (new-multiplier uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-multiplier u0) ERR_INVALID_AMOUNT)
        (var-set participation-bonus-multiplier new-multiplier)
        (ok true)
    )
)

(define-public (set-contribution-ratio (new-ratio uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-ratio u0) ERR_INVALID_AMOUNT)
        (var-set contribution-power-ratio new-ratio)
        (ok true)
    )
)

(define-read-only (get-member-participation (member principal))
    (default-to u0 (map-get? member-participation-score member))
)

(define-read-only (get-member-contributions (member principal))
    (default-to u0 (map-get? member-total-contributions member))
)

(define-read-only (get-member-voting-metrics (member principal))
    (ok {
        voting-power: (get-voting-power member),
        participation-score: (get-member-participation member),
        total-contributions: (get-member-contributions member),
        last-vote-block: (default-to u0 (map-get? member-last-vote-block member))
    })
)


(define-public (delegate-vote (delegate principal))
    (let
        (
            (delegator-power (get-voting-power tx-sender))
        )
        (asserts! (is-member tx-sender) ERR_INVALID_MEMBER)
        (asserts! (is-member delegate) ERR_DELEGATE_NOT_MEMBER)
        (asserts! (not (is-eq tx-sender delegate)) ERR_CANNOT_DELEGATE_TO_SELF)
        
        (match (map-get? member-delegates tx-sender)
            old-delegate
                (map-set delegated-power old-delegate 
                    (- (default-to u0 (map-get? delegated-power old-delegate)) delegator-power))
            true
        )
        
        (map-set member-delegates tx-sender delegate)
        (map-set delegated-power delegate 
            (+ (default-to u0 (map-get? delegated-power delegate)) delegator-power))
        (ok true)
    )
)

(define-public (revoke-delegation)
    (let
        (
            (current-delegate (unwrap! (map-get? member-delegates tx-sender) ERR_NOT_DELEGATED))
            (delegator-power (get-voting-power tx-sender))
        )
        (map-set delegated-power current-delegate 
            (- (default-to u0 (map-get? delegated-power current-delegate)) delegator-power))
        (map-delete member-delegates tx-sender)
        (ok true)
    )
)

(define-public (vote-as-delegate (proposal-id uint) (support bool) (delegator principal))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (delegate (unwrap! (map-get? member-delegates delegator) ERR_NOT_DELEGATED))
            (vote-key {proposal-id: proposal-id, voter: delegator})
            (delegator-power (get-voting-power delegator))
        )
        (asserts! (is-eq tx-sender delegate) ERR_UNAUTHORIZED)
        (asserts! (is-member delegator) ERR_INVALID_MEMBER)
        (asserts! (<= stacks-block-height (get end-block proposal)) ERR_VOTING_PERIOD_ENDED)
        (asserts! (is-none (map-get? votes vote-key)) ERR_ALREADY_VOTED)
        
        (map-set votes vote-key support)
        
        (if support
            (map-set proposals proposal-id 
                (merge proposal {yes-votes: (+ (get yes-votes proposal) delegator-power)}))
            (map-set proposals proposal-id 
                (merge proposal {no-votes: (+ (get no-votes proposal) delegator-power)}))
        )
        (ok true)
    )
)

(define-read-only (get-delegate (member principal))
    (map-get? member-delegates member)
)

(define-read-only (get-total-delegated-power (delegate principal))
    (default-to u0 (map-get? delegated-power delegate))
)

(define-read-only (get-effective-voting-power (member principal))
    (+ (get-voting-power member) (get-total-delegated-power member))
)


(define-map emergency-freeze-votes {proposal-type: (string-ascii 10), voter: principal} bool)

(define-public (emergency-freeze-vote (support bool))
    (let
        (
            (vote-key {proposal-type: "freeze", voter: tx-sender})
            (current-freeze (var-get current-freeze-votes))
            (current-unfreeze (var-get current-unfreeze-votes))
        )
        (asserts! (is-member tx-sender) ERR_INVALID_MEMBER)
        (asserts! (is-none (map-get? emergency-freeze-votes vote-key)) ERR_ALREADY_VOTED_EMERGENCY)
        
        (map-set emergency-freeze-votes vote-key support)
        
        (if support
            (var-set current-freeze-votes (+ current-freeze u1))
            (var-set current-unfreeze-votes (+ current-unfreeze u1))
        )
        
        (let
            (
                (freeze-threshold (var-get emergency-freeze-threshold))
                (new-freeze-count (var-get current-freeze-votes))
                (new-unfreeze-count (var-get current-unfreeze-votes))
            )
            (if (and support (>= new-freeze-count freeze-threshold) (not (var-get is-emergency-frozen)))
                (begin
                    (var-set is-emergency-frozen true)
                    (var-set freeze-proposal-id (+ (var-get freeze-proposal-id) u1))
                    (clear-emergency-votes)
                    (ok "DAO_FROZEN"))
                (if (and (not support) (>= new-unfreeze-count freeze-threshold) (var-get is-emergency-frozen))
                    (begin
                        (var-set is-emergency-frozen false)
                        (clear-emergency-votes)
                        (ok "DAO_UNFROZEN"))
                    (ok "VOTE_RECORDED")))
        )
    )
)

(define-private (clear-emergency-votes)
    (begin
        (var-set current-freeze-votes u0)
        (var-set current-unfreeze-votes u0)
        true
    )
)

(define-read-only (is-dao-frozen)
    (var-get is-emergency-frozen)
)

(define-read-only (get-emergency-status)
    (ok {
        frozen: (var-get is-emergency-frozen),
        freeze-votes: (var-get current-freeze-votes),
        unfreeze-votes: (var-get current-unfreeze-votes),
        threshold: (var-get emergency-freeze-threshold),
        freeze-id: (var-get freeze-proposal-id)
    })
)

(define-public (set-emergency-threshold (new-threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (> new-threshold u0) (<= new-threshold (var-get total-members))) ERR_INVALID_AMOUNT)
        (var-set emergency-freeze-threshold new-threshold)
        (ok true)
    )
)