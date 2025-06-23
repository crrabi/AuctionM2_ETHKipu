// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/// @title Advanced Auction Contract
/// @notice This contract allows the creation and management of an English auction.
///         It includes functionalities such as time extension, partial refunds, and fee management.
contract AuctionM2 {
    // ====================================================================================================
    //                                         STATE VARIABLES
    // ====================================================================================================
    address public immutable owner;            // Owner of the contract and the one who starts the auction.
    uint256 public auctionStartTime;           // Timestamp when the auction should start.
    uint256 public auctionEndTime;             // Timestamp when the auction should end.
    address public highestBidder;              // Address of the bidder with the highest bid.
    uint256 public highestBid;                 // Value of the highest bid.
    bool    public auctionEnded;               // Indicator of whether the auction has ended.
    uint256 private accumulatedFees;           // Total accumulated fees.
    uint256 public winningBid;                 // Stores the final winning bid for lookup.
    // mapping: bidder address => amount of Ether deposited and pending return.
    // Includes the current bid amount and any partially withdrawn excess.
    mapping(address => uint256) public pendingReturns;
    // mapping: bidder address => last valid bid placed by that bidder.
    mapping(address => uint256) public latestBid;
    // To know if an address has already been added to _activeBidders, to avoid duplicates
    mapping(address => bool)    private _isBidderActive;
    // List of active bidder addresses for iteration
    address[]   private _activeBidders;
    // Constant for the gas fee (2% = 200 out of 10000 parts)
    uint8   private constant FEE_PERCENTAGE = 200; // 2% = 200 / 10000
    // Constant for auction time extension (10 minutes in seconds)
    uint16  private constant AUCTION_EXTENSION_TIME = 10 minutes; // 10 minutes * 60 seconds/minute
    // Constant for the minimum bid increment (5% = 500 out of 10000 parts)
    uint16  private constant MIN_BID_INCREMENT_PERCENTAGE = 500; // 5% = 500 / 10000
    // ====================================================================================================
    //                                          EVENTS
    // ====================================================================================================
    ///@dev Emitted when the auction starts.
    ///@param owner owner's address
    //@param _auctionStartTime auction start time
    //@param _auctionEndTime auction end time
    event AuctionStarted(address indexed owner, uint256 _auctionStartTime, uint256 _auctionEndTime);

    /// @dev Emitted when a new valid bid is placed.
    /// @param bidder The bidder's address.
    /// @param amount The bid amount.
    /// @param _currentTime current auction time.
    event NewBid(address indexed bidder, uint256 amount, uint256 _currentTime);
    
    ///@dev Emitted when the auction is extended.
    ///@param _highestBidder highest bidder's address
    ///@param _currentTime current auction time
    ///@param _auctionEndTime auction end time
    event AuctionExtension(address indexed _highestBidder, uint256 _currentTime, uint256 _auctionEndTime);

    /// @dev Emitted when the auction has ended.
    /// @param _winner The winning bidder's address.
    /// @param _winningBid The winning bid amount.
    event AuctionEnded(address indexed _winner, uint256 _winningBid);

    /// @dev Emitted when a participant withdraws funds (partial refund).
    /// @param withdrawer The address withdrawing funds.
    /// @param amount The amount of funds withdrawn.
    event FundsWithdrawn(address indexed withdrawer, uint256 amount);

    /// @dev Emitted when owner withdraws funds and the auction has ended.
    /// @param owner The address withdrawing funds.
    /// @param amount The amount of funds withdrawn.
    event OwnerWithdrawn(address indexed owner, uint256 amount);

    /// @dev Emitted when the auction ended with no bids.
    /// @param _auctionStartTime auction start time.
    /// @param _auctionEndTime auction end time.
    event NoOffers (address indexed _owner, uint256 _auctionStartTime, uint256 _auctionEndTime);

    /// @dev Emitted when funds are distributed after the auction ends.
    /// @param _owner The contract owner.
    /// @param _totalAmountToOwner The amount of the winning bid transferred to the owner.
    /// @param _totalRefundedToBidders Total amount refunded to non-winning bidders.
    /// @param _currentAccumulatedFees Total fees collected during the distribution.
    event FundsDistributed(address indexed _owner, uint256 _totalAmountToOwner, uint256 _totalRefundedToBidders, uint256 _currentAccumulatedFees);

    // ====================================================================================================
    //                                           MODIFIERS
    // ====================================================================================================
    /// @dev Restricts access to the function only to the contract owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call.");
        _;
    }
    /// @dev The contract owner cannot place bids.
    modifier notOwner() {
        require(msg.sender != owner, "Owner cannot call.");
        _;
    }
    /// @dev Restricts function execution if the auction has already ended.
    modifier notEnded() {
        require(!auctionEnded, "Auction ended.");
        _;
    }
    /// @dev Restricts function execution until the auction has ended.
    modifier onlyAfterEnd() {
        require(auctionEndTime < block.timestamp, "Auction not ended.");
        _;
    }
    /// @dev Restricts function execution if the auction has not started.
    modifier auctionStarted() {
        require(auctionEndTime != 0, "Auction not initialized.");
        _;
    }
    /// @dev Ensure the auction is still active by time.
    modifier stillActive() {
        require(block.timestamp < auctionEndTime, "Auction ended.");
        _;
    }
    /// @dev Ensure the amount sent is greater than 0.
    modifier bidMoreThanZero() {
        require(msg.value > 0, "Must be greater than 0.");
        _;
    }
    // ====================================================================================================
    //                                             CONSTRUCTOR
    // ====================================================================================================
    /// @dev The constructor executes only once when the contract is deployed.
    ///      It initializes the contract owner and the auction duration.
    /// @param _biddingTime The duration of the auction in seconds from the deployment time.
    constructor(uint256 _biddingTime) {
        owner = msg.sender;
        // The auction ends at deployment time + bidding time.
        // block.timestamp is used for the current time on the blockchain.
        auctionEndTime = block.timestamp + _biddingTime;
        auctionStartTime = block.timestamp;
        emit AuctionStarted(owner, block.timestamp, auctionEndTime);
    }
    // ====================================================================================================
    //                                            MAIN FUNCTIONS
    // ====================================================================================================
    /// @dev Allows participants to bid on the item.
    ///      For a bid to be valid, it must be greater than the current highest bid by at least 5%
    ///      and must be placed while the auction is active.
    function bid() external payable auctionStarted stillActive notEnded notOwner bidMoreThanZero {     
        //Calculate the minimum required increment (5% of the highest bid).
        uint256 minBidIncrement = (highestBid * MIN_BID_INCREMENT_PERCENTAGE) / 10000;
        // The new bid must be at least 5% higher than the current highest bid.
        require(msg.value > (highestBid + minBidIncrement), "must be greater than 5%.");

        // If there is a previous bidder, their current bid is moved to pendingReturns so it can be claimed.
        // This is crucial for partial/final refund functionality.
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        
        // Update the highest bid and the highest bidder.
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        // Record the latest valid bid of msg.sender.
        latestBid[msg.sender] = msg.value;
        
        // Logic to register the bidder if it's their first time bidding.
        if (!_isBidderActive[msg.sender]) {
            _activeBidders.push(msg.sender);
            _isBidderActive[msg.sender] = true;
        }
        // Handle auction time extension.
        // If current time + 10 minutes is greater than the current auction end time,
        // and the auction has not yet ended by time (it's in the last 10 minutes of its original duration).
        // The second condition is to ensure extension only happens near the end,
        // not at any point during the auction.
        if (block.timestamp < auctionEndTime && (auctionEndTime - block.timestamp) < AUCTION_EXTENSION_TIME) {
            auctionEndTime += AUCTION_EXTENSION_TIME;
            emit AuctionExtension(highestBidder, block.timestamp, auctionEndTime);
        }
        // Emit an event to notify that a new bid has been placed.
        emit NewBid (highestBidder, highestBid, block.timestamp);
    }
    
    ///@dev Shows the winning bidder and the winning bid amount.
    ///     Can only be called once the auction has ended.
    ///@return address The address of the winning bidder.
    ///@return uint The amount of the winning bid.
    function showWinner() external onlyAfterEnd returns (address, uint256) {
        if (highestBidder == address(0)) {
            // Mark the auction as ended.
            auctionEnded = true;
            // Emit the auction ended event.
            emit AuctionEnded(highestBidder, winningBid);
            emit NoOffers(owner, auctionStartTime, auctionEndTime);
            return (address(0), 0);
        }
        winningBid = highestBid;
        return (highestBidder, winningBid);
    }
    ///@dev Allows ending the auction once the time has expired.
    ///     Only the owner can call this function, and only if the time has passed.  
    function endAuction() external onlyOwner notEnded onlyAfterEnd{ 

        if (highestBidder == address(0)) {
            emit NoOffers(owner, auctionStartTime, auctionEndTime); 
            }
        // Mark the auction as ended.
        auctionEnded = true;
        // Stores the final winning bid.
        // To retain the information even after contract funds have been withdrawn.
        winningBid = highestBid; 
        // Emit the auction ended event.
        emit AuctionEnded(highestBidder, winningBid);
    }
    /// @dev Shows a list of bidders who have funds in the contract
    ///      and their respective last valid bids.
    /// @return biddersList An array of bidder addresses.
    /// @return bidsAmounts An array of the amounts of the last valid bids corresponding to each bidder.
    function showBids() external view returns (address[] memory biddersList, uint256[] memory bidsAmounts) {

        uint256 numBidders = _activeBidders.length;
        // Create in-memory arrays for the results.
        biddersList = new address[](numBidders);
        bidsAmounts = new uint256 [](numBidders);

        // Iterate over the array of addresses to get their latest bids.
        for (uint256 i = 0; i < numBidders; i++) {
            address bidderAddress = _activeBidders[i];
            biddersList[i] = bidderAddress;
            bidsAmounts[i] = latestBid[bidderAddress];
        }
        return (biddersList, bidsAmounts);
    }
    /// @dev Allows participants to withdraw the amount from their deposit that exceeds their last bid
    ///      during the auction.
    function partialRefund() external auctionStarted stillActive notEnded notOwner {
        // Ensure the sender has excess funds deposited beyond their last bid.
        require(pendingReturns[msg.sender] > 0 && highestBidder == msg.sender , "No excess funds.");
        uint256 amountToWithdraw = pendingReturns[msg.sender];
        // Reset the pending balance before transfer (Checks-Effects-Interactions).
        pendingReturns[msg.sender] = 0; 
        // Attempt to send Ether to the user.
        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Failed.");
        // Emit when a participant withdraws funds (partial or final refund).
        emit FundsWithdrawn(msg.sender, amountToWithdraw);
    }

    /// @dev Upon auction end, deposits are returned to non-winning bidders,
    ///      minus a 2% fee for gas.
    ///      This function can be called by Owner
    function withdrawDeposits() external onlyAfterEnd onlyOwner{
        // Ensure the auction is marked as ended, or mark it now if not already.
        // This ensures winningBid is set correctly if endAuction wasn't called.
        if (!auctionEnded) {
            auctionEnded = true;
            winningBid = highestBid;
            emit AuctionEnded(highestBidder, winningBid);
        }

        uint256 totalRefundedToBidders = 0;
        uint256 currentAccumulatedFees = 0;
        uint256 _numBidders = _activeBidders.length;
        address bidderAddress;
        address currentHighestBidder = highestBidder;
        // 1. Process refunds for non-winning bidders
        for (uint256 i = 0; i < _numBidders ; i++) {
            bidderAddress = _activeBidders[i];
            // Skip the highest bidder, as their funds go to the owner.
            if (bidderAddress == currentHighestBidder) {
                continue; 
            }

            uint256 amountForRefund = pendingReturns[bidderAddress];
            if (amountForRefund > 0) {
                uint256 fee = (amountForRefund * FEE_PERCENTAGE) / 10000;
                uint256 amountAfterFee = amountForRefund - fee;

                pendingReturns[bidderAddress] = 0; // Reset before transfer
                currentAccumulatedFees += fee; // Accumulate fee for this distribution

                (bool refoundSuccess, ) = payable(bidderAddress).call{value: amountAfterFee}("");
                require(refoundSuccess, "Failed."); 
                totalRefundedToBidders += amountAfterFee;
                emit FundsWithdrawn(bidderAddress, amountAfterFee);
            }
        }
        
        // Add fees from this distribution to the global accumulated fees.
        accumulatedFees += currentAccumulatedFees;

        uint256 totalAmountToOwner = 0;

        // 2. Transfer winning bid to the owner
        if (highestBidder != address(0) && highestBid > 0) {
            totalAmountToOwner += highestBid; 
            highestBid = 0;
        }

        // 3. Transfer total accumulated fees to the owner
        if (accumulatedFees > 0) {
            totalAmountToOwner += accumulatedFees;
            accumulatedFees = 0;
        }

        require(totalAmountToOwner > 0, "No funds.");

        // Attempt to send total funds to the owner
        (bool success, ) = payable(owner).call{value: totalAmountToOwner}("");
        require(success, "Failed.");

        emit OwnerWithdrawn(owner, totalAmountToOwner);
        emit FundsDistributed(owner, totalAmountToOwner, totalRefundedToBidders, currentAccumulatedFees);
    }

    /// @dev Allows the contract owner to withdraw auction funds (winning bid and fees).
    ///      Can only be called by the owner and once the auction has ended.
    ///      Also handles the scenario where there were no valid bids.
    function ownerWithdraw() external onlyOwner onlyAfterEnd {
        // Mark the auction as ended.
        auctionEnded = true;
        // Emit the auction ended event.
        emit AuctionEnded(highestBidder, winningBid);
        uint256 totalAmountToWithdraw = 0;
        // 1. Withdraw the winning bid (if there was a winner and it hasn't been withdrawn yet)
        if (highestBidder != address(0) && highestBid > 0) {
            totalAmountToWithdraw += highestBid;
            highestBid = 0; // Mark the winning bid as withdrawn to prevent double withdrawals.
        }
        // 2. Withdraw accumulated fees
        if (accumulatedFees > 0) {
            totalAmountToWithdraw += accumulatedFees;
            accumulatedFees = 0; // Mark fees as withdrawn.
        }
        require(totalAmountToWithdraw > 0, "No funds.");
        // Attempt to send Ether to the owner.
        (bool success, ) = payable(owner).call{value: totalAmountToWithdraw}("");
        require(success, "Failed.");

        //Emit when owner withdraws funds and the auction has ended.
        emit OwnerWithdrawn(owner, totalAmountToWithdraw);
    }
}