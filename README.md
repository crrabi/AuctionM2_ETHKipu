# AuctionM2_ETHKipu
🔨 Advanced Auction Smart Contract | Kipu Ethereum Developer Pack - Module 2 practical assignment. English auction with time extension, partial refunds during bidding, and secure fund management.
# 🔨 Advanced Auction Smart Contract (AuctionM2)

https://sepolia.etherscan.io/address/0xA7B3015771eEC21a53202cCF9E6AAE23C7fe05b3#code

## 📋 General Description

**AuctionM2** is a smart contract developed in Solidity that implements an advanced English auction system. The contract allows the creation and management of auctions with features such as automatic time extension, partial refunds during the auction, and secure deposit management with commissions.

### 🎯 Main Features

- ✅ **English Auction**: Ascending bid system
- ✅ **Minimum Increment**: Bids must exceed the current bid by at least 5%
- ✅ **Automatic Extension**: If a bid is placed in the last 10 minutes, the auction extends by 10 more minutes
- ✅ **Partial Refund**: Participants can withdraw excess funds during the auction
- ✅ **Commission Management**: 2% commission on withdrawals
- ✅ **Robust Security**: Implements standard security patterns

## 🤖 AI-Assisted Development

This smart contract was developed with assistance from **Copilot 2.5 Flash Gemini Code Assist**, following Ethereum development best practices and design patterns recommended by ETH Kipu.

### 🔄 Development Process

The development followed an iterative approach that included:

1. **Initial Generation**: Request for base code with all required functionalities
2. **Incremental Compilation**: Function-by-function development to detect errors and warnings
3. **Exhaustive Testing**: Testing in multiple scenarios to verify functionality
4. **Issue Resolution**: Identification and correction of critical problems detected during testing

### 🛠️ Challenges Resolved

During the development process, several important issues were identified and resolved:

- **Owner Restriction**: Validation implemented to prevent the owner from bidding in their own auction
- **Fund Management**: Logic corrected to allow differentiated withdrawals between winners and non-winners
- **Commission Equity**: Implementation of 2% commission charges for both partial and final refunds
- **Refund Optimization**: Adopted an approach where any superseded bid can be withdrawn during the auction, maintaining contract simplicity and security

### 🎯 Tools Used

- **Solidity**: ^0.8.0
- **Copilot 2.5 Flash Gemini Code Assist**: Development assistance
- **ETH Kipu**: Reference for design patterns and best practices
- **Solidity Documentation**: Official technical guide

## 🎓 Academic Context

This project was developed as a **Module 2 practical assignment** for the **Kipu Ethereum Developer Pack**, focusing on advanced smart contract development with security patterns and complex auction logic implementation.

---

## 🔧 State Variables

### Main Variables

| Variable | Type | Description |
|----------|------|-------------|
| `owner` | `address immutable` | Contract owner who starts the auction |
| `auctionStartTime` | `uint` | Auction start timestamp |
| `auctionEndTime` | `uint` | Auction end timestamp |
| `highestBidder` | `address` | Address of the bidder with the highest bid |
| `highestBid` | `uint` | Value of the current highest bid |
| `auctionEnded` | `bool` | Indicator of whether the auction has ended |
| `winningBid` | `uint` | Stores the final winning bid for reference |

### Mappings

| Mapping | Description |
|---------|-------------|
| `pendingReturns` | `address => uint` - Ether deposited pending withdrawal by each participant |
| `latestBid` | `address => uint` - Last valid bid placed by each participant |
| `_isBidderActive` | `address => bool` - Controls if an address is already registered as an active bidder |

### Private Variables

| Variable | Description |
|----------|-------------|
| `accumulatedFees` | Total accumulated commissions |
| `_activeBidders` | Array of active bidder addresses |

### Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `FEE_PERCENTAGE` | `200` (2%) | Commission percentage on withdrawals |
| `AUCTION_EXTENSION_TIME` | `10 minutes` | Automatic extension time |
| `MIN_BID_INCREMENT_PERCENTAGE` | `500` (5%) | Minimum required increment for bids |

---

## 🚀 Functions

### 🏗️ Constructor

```solidity
constructor(uint _biddingTime)
```

**Description**: Initializes the auction contract.

**Parameters**:
- `_biddingTime`: Auction duration in seconds from deployment time

**Functionality**:
- Sets the deployer as `owner`
- Calculates `auctionStartTime` and `auctionEndTime`
- Emits `AuctionStarted` event

---

### 💰 Bidding Function

```solidity
function bid() external payable notEnded auctionStarted
```

**Description**: Allows participants to place bids in the auction.

**Validations**:
- Owner cannot bid in their own auction
- Auction must be active by time
- Bid must be greater than 0
- Must exceed current bid by at least 5%

**Functionality**:
- Updates `pendingReturns` for the previous highest bidder
- Registers new bidder in `_activeBidders` (if first bid)
- Handles automatic time extension
- Emits `NewBid` event

**Extension Logic**:
```solidity
if (block.timestamp < auctionEndTime && (auctionEndTime - block.timestamp) < AUCTION_EXTENSION_TIME) {
    auctionEndTime += AUCTION_EXTENSION_TIME;
    emit AuctionExtension(highestBidder, block.timestamp, auctionEndTime);
}
```

---

### 🏆 Show Winner

```solidity
function showWinner() external onlyAfterEnd returns (address, uint)
```

**Description**: Returns the auction winner information.

**Returns**:
- `address`: Winner's address (or `address(0)` if no bids)
- `uint`: Winning bid amount

---

### 📊 Show Bids

```solidity
function showBids() external view returns (address[] memory, uint[] memory)
```

**Description**: Returns the complete list of bidders and their latest valid bids.

**Returns**:
- `address[] memory`: Array of bidder addresses
- `uint[] memory`: Array of latest valid bid amounts

---

### 🔄 Partial Refund

```solidity
function partialRefund() external notEnded auctionStarted
```

**Description**: Allows participants to withdraw excess funds during the active auction.

**Functionality**:
- Calculates and deducts 2% commission
- Transfers net amount to requester
- Accumulates commission for owner
- Emits `FundsWithdrawn` event

**Usage Example**:
```
T0: User1 bids 1 ETH
T1: User2 bids 2 ETH  
T2: User1 bids 3 ETH → Can withdraw 1 ETH (minus 2% commission)
```

**Commission Calculation**:
- Available withdrawal amount: 1 ETH
- Commission (2%): 0.02 ETH  
- Net amount received: 0.98 ETH
- Commission accumulated for owner: 0.02 ETH

---

### 💸 Withdraw Deposits

```solidity
function withdrawDeposits() external onlyAfterEnd
```

**Description**: Allows non-winning participants to withdraw their funds after auction ends.

**Validations**:
- Only after auction end
- Requester must have pending funds

**Functionality**:
- Calculates and deducts 2% commission
- Transfers funds to participant
- Marks auction as ended
- Emits `AuctionEnded` and `FundsWithdrawn` events

---

### 🏁 End Auction

```solidity
function endAuction() external onlyOwner notEnded
```

**Description**: Allows owner to manually end the auction once time has expired.

**Validations**:
- Only owner can call it
- Only if time has expired
- Auction must not have ended previously

**Functionality**:
- Sets `auctionEnded = true`
- Saves `winningBid` for future queries
- Emits `AuctionEnded` or `NoOffers` event

---

### 💰 Owner Withdrawal

```solidity
function ownerWithdraw() external onlyOwner onlyAfterEnd
```

**Description**: Allows owner to withdraw winning bid and accumulated commissions.

**Functionality**:
- Withdraws `highestBid` (winning bid)
- Withdraws `accumulatedFees` (commissions)
- Prevents double withdrawals by setting values to 0
- Emits `OwnerWithdrawn` event

---

## 🎭 Modifiers

| Modifier | Description |
|-------------|-------------|
| `onlyOwner()` | Restricts access to contract owner only |
| `notEnded()` | Prevents execution if auction has already ended |
| `onlyAfterEnd()` | Only allows execution after auction end |
| `auctionStarted()` | Verifies that auction has been initialized |

---

## 📢 Events

### `AuctionStarted`
```solidity
event AuctionStarted(address indexed owner, uint _auctionStartTime, uint _auctionEndTime);
```
**When emitted**: Upon contract deployment
**Purpose**: Notify auction start with its timing

### `NewBid`
```solidity
event NewBid(address indexed bidder, uint amount, uint _currentTime);
```
**When emitted**: When a valid bid is placed
**Purpose**: Notify new bid with bidder details

### `AuctionExtension`
```solidity
event AuctionExtension(address indexed _highestBidder, uint _currentTime, uint _auctionEndTime);
```
**When emitted**: When auction time is automatically extended
**Purpose**: Inform about time extension

### `AuctionEnded`
```solidity
event AuctionEnded(address indexed _winner, uint _winningBid);
```
**When emitted**: When auction officially ends (manual or by withdrawals)
**Purpose**: Notify official auction end

### `FundsWithdrawn`
```solidity
event FundsWithdrawn(address indexed withdrawer, uint amount);
```
**When emitted**: When a participant withdraws funds
**Purpose**: Record participant withdrawals

### `OwnerWithdrawn`
```solidity
event OwnerWithdrawn(address indexed owner, uint amount);
```
**When emitted**: When owner withdraws funds
**Purpose**: Record owner withdrawals

### `NoOffers`
```solidity
event NoOffers(address indexed _owner, uint _auctionStartTime, uint _auctionEndTime);
```
**When emitted**: When auction ends without bids
**Purpose**: Register auctions without participation

---

## 🔒 Security Considerations

### Implemented Patterns

1. **Checks-Effects-Interactions**: Validate, then update state, finally transfer
2. **Reentrancy Prevention**: Balances reset before transfers
3. **Safe use of `call()`**: Preferred over `transfer()` for better compatibility
4. **Exhaustive Validations**: Multiple `require()` statements in each critical function

### Specific Protections

- ✅ **Owner cannot bid**: Prevents manipulation
- ✅ **Mandatory minimum increment**: Avoids insignificant bids
- ✅ **Time control**: Strict temporal validations
- ✅ **Double withdrawal prevention**: Variables reset after use

---

## 📈 Typical Usage Flow

### 1. Deployment
```solidity
// Deploy with 1 hour duration
AuctionM2 auction = new AuctionM2(3600);
```

### 2. Participation
```solidity
// Users place bids
auction.bid{value: 1 ether}();
auction.bid{value: 1.1 ether}(); // Must be >5% higher
```

### 3. During Auction
```solidity
// View current bids
(address[] memory bidders, uint[] memory amounts) = auction.showBids();

// Partial refund if applicable
auction.partialRefund();
```

### 4. Finalization
```solidity
// After time limit
auction.endAuction(); // Owner finalizes

// Participants withdraw funds
auction.withdrawDeposits();

// Owner withdraws earnings
auction.ownerWithdraw();
```

---

## ⚠️ Limitations and Considerations

### Gas Limitations
- The `_activeBidders` array can become expensive with many participants
- The `showBids()` function has O(n) cost where n = number of bidders

### Usage Considerations
- 2% commissions apply to all withdrawals
- Time extensions only occur in the last 10 minutes
- Owner must manually end auction after time limit

---

## 📄 License

This contract is licensed under MIT License.

---

## 🤝 Contributions

To report issues, suggest improvements, or contribute to the code, please create an issue or pull request in the repository.

---

*Documentation generated for AuctionM2 v1.0*
