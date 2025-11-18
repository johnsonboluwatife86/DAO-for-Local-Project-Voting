# 🏛️ DAO for Local Project Voting

A decentralized autonomous organization (DAO) smart contract built on Stacks blockchain that enables community members to propose and vote on local development initiatives. Perfect for funding community projects like boreholes, street lighting, parks, and other local infrastructure! 🌟

## 🚀 Features

- 👥 **Member Management**: Add/remove community members with voting rights
- 📝 **Proposal Creation**: Submit funding proposals for local projects
- 🗳️ **Democratic Voting**: Members vote yes/no on proposals
- 📊 **Quorum System**: Configurable quorum requirements for proposal approval
- 💰 **Automatic Fund Release**: Funds released only after successful approval
- 🔍 **Transparent Tracking**: Real-time proposal status and voting results
- ⏰ **Time-bound Voting**: Proposals have configurable voting periods

## 🏗️ How It Works

1. **Community Setup**: Contract owner adds members to the DAO
2. **Funding**: Community funds the DAO treasury
3. **Proposal Creation**: Members submit project proposals with funding requirements
4. **Voting Period**: Members vote during the specified timeframe
5. **Execution**: Approved proposals automatically release funds to the proposer

## 📋 Contract Functions

### 👨‍💼 Owner Functions
- `add-member(member)` - Add a new voting member
- `remove-member(member)` - Remove a voting member
- `set-quorum-percentage(percentage)` - Update quorum requirements

### 👥 Member Functions
- `create-proposal(title, description, funding-amount, duration)` - Submit a new proposal
- `vote(proposal-id, support)` - Vote on a proposal (true for yes, false for no)
- `execute-proposal(proposal-id)` - Execute an approved proposal after voting ends

### 💰 Funding Functions
- `fund-dao()` - Add STX to the DAO treasury

### 🔍 Read-Only Functions
- `get-proposal(proposal-id)` - Get proposal details
- `get-vote(proposal-id, voter)` - Check individual vote
- `proposal-status(proposal-id)` - Get comprehensive proposal status
- `get-proposal-results(proposal-id)` - Get voting results
- `get-active-proposals()` - List all active proposals
- `get-dao-balance()` - Check DAO treasury balance
- `get-total-members()` - Get total member count
- `is-member(address)` - Check if address is a member

## 🛠️ Usage Examples

### Setting Up the DAO

```clarity
;; Add members (owner only)
(contract-call? .DAO-for-Local-Project-Voting add-member 'SP1234...)
(contract-call? .DAO-for-Local-Project-Voting add-member 'SP5678...)

;; Fund the DAO
(contract-call? .DAO-for-Local-Project-Voting fund-dao)
```

### Creating a Proposal

```clarity
;; Propose a borehole project
(contract-call? .DAO-for-Local-Project-Voting create-proposal 
    "Community Borehole Project"
    "Drill a new borehole to provide clean water access for 500 families"
    u5000000  ;; 5 STX funding request
    u1000     ;; Voting period: 1000 blocks (~1 week)
)
```

### Voting on Proposals

```clarity
;; Vote yes on proposal #1
(contract-call? .DAO-for-Local-Project-Voting vote u1 true)

;; Vote no on proposal #2
(contract-call? .DAO-for-Local-Project-Voting vote u2 false)
```

### Executing Approved Proposals

```clarity
;; Execute proposal after voting period ends
(contract-call? .DAO-for-Local-Project-Voting execute-proposal u1)
```

## 📊 Proposal Lifecycle

```
💡 Created → 🗳️ Active Voting → ⏰ Voting Ended → ✅ Execute (if approved)
```

### Proposal States:
- **Active**: Currently accepting votes
- **Ended**: Voting period finished
- **Approved**: Met quorum and majority voted yes
- **Executed**: Funds released to proposer
- **Rejected**: Failed to meet approval criteria

## ⚙️ Configuration

### Default Settings:
- **Quorum**: 51% of total members must vote
- **Approval**: Simple majority (more yes than no votes)
- **Voting Power**: Each member has 1 vote
- **Minimum Funding**: Must fund DAO before creating proposals

### Customizable:
- Quorum percentage (adjustable by owner)
- Voting duration per proposal
- Member voting power (currently 1 per member)

## 🔐 Security Features

- ✅ Only members can create proposals and vote
- ✅ One vote per member per proposal
- ✅ Proposals can't be executed during voting period
- ✅ Funds only released after proper approval
- ✅ Owner-only administrative functions
- ✅ Prevents double-voting and unauthorized access

## 🚀 Getting Started

1. Deploy the contract to Stacks blockchain
2. Add initial members using `add-member`
3. Fund the DAO treasury with `fund-dao`
4. Start creating and voting on proposals! 🎉

## 📈 Monitoring

Track DAO activity with read-only functions:
- Monitor proposal status and voting progress
- Check treasury balance
- View member participation
- Analyze voting patterns and outcomes

---

**Built with ❤️ for community governance on Stacks blockchain** 🌐

> *Empowering communities to democratically fund local development projects through transparent, trustless voting mechanisms.*
