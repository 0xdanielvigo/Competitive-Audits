// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./IMarket.sol";
import "./IMarketController.sol";
import "./IMarketResolver.sol";
import "../Token/IPositionTokens.sol";
import "../Vault/IVault.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title MarketController
 * @notice Upgradeable orderbook-based prediction market controller with EIP-712 order matching
 * @dev Coordinates between position tokens, vault, and market resolver contracts with UUPS upgradeability
 */
contract MarketController is
    IMarketController,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable
{
    using ECDSA for bytes32;

    // EIP-712 Type Hash
    bytes32 private constant ORDER_TYPEHASH = keccak256(
        "Order(address user,bytes32 questionId,uint256 outcome,uint256 amount,uint256 price,uint256 nonce,uint256 expiration,bool isBuyOrder)"
    );

    /// @notice Maximum fee rate in basis points (10% = 1000 bp)
    uint256 public constant MAX_FEE_RATE = 1000;

    /// @notice Position tokens contract for minting/burning
    IPositionTokens public positionTokens;

    /// @notice Market resolver for proof verification
    IMarketResolver public marketResolver;

    /// @notice Vault contract for collateral management
    IVault public vault;

    /// @notice Market contract for metadata
    IMarket public market;

    /// @notice Oracle address for condition ID generation
    address public oracle;

    /// @notice Global trading pause state (emergency stop)
    bool public globalTradingPaused;

    /// @notice Per-market trading pause state (for trading hours control)
    mapping(bytes32 => bool) public marketTradingPaused;

    /// @notice Authorized matchers for order matching
    mapping(address => bool) public authorizedMatchers;

    /// @notice Order management for EIP-712
    mapping(bytes32 => uint256) public filledAmounts; // orderHash => filled amount

    /// @notice Fee rate in basis points (e.g., 400 = 4%)
    uint256 public feeRate;

    /// @notice Trade fee rate in basis points (e.g., 100 = 1%)
    uint256 public tradeFeeRate;

    /// @notice Treasury address where fees are sent
    address public treasury;

    /// @notice Custom fee rates for specific users (0 = use default rate)
    mapping(address => uint256) public userFeeRate;

    /// @notice Custom trade fee rates for specific users (0 = use default rate)
    mapping(address => uint256) public userTradeFeeRate;

    /// @dev Gap for future storage variables
    uint256[31] private __gap;

    modifier onlyAuthorizedMatcher() {
        require(authorizedMatchers[msg.sender], "Not authorized matcher");
        _;
    }

    /// @dev Restricts betting to markets that are still open
    modifier onlyOpenMarket(bytes32 questionId) {
        require(market.isMarketOpen(questionId), "Market is closed for betting");
        _;
    }

    /// @dev Restricts trading when paused (global or market-specific)
    modifier whenTradingActive(bytes32 questionId) {
        require(!globalTradingPaused, "Global trading paused");
        require(!marketTradingPaused[questionId], "Market trading paused");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract
     * @param _initialOwner Initial owner of the contract
     * @param _positionTokens Address of position tokens contract
     * @param _marketResolver Address of market resolver contract
     * @param _vault Address of vault contract
     * @param _marketContract Address of market contract
     * @param _oracle Address of oracle for condition generation
     */
    function initialize(
        address _initialOwner,
        address _positionTokens,
        address _marketResolver,
        address _vault,
        address _marketContract,
        address _oracle
    ) public initializer {
        require(_positionTokens != address(0), "Invalid position tokens");
        require(_marketResolver != address(0), "Invalid market resolver");
        require(_vault != address(0), "Invalid vault");
        require(_marketContract != address(0), "Invalid market contract");
        require(_oracle != address(0), "Invalid oracle");

        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __EIP712_init("PredictionMarketOrders", "1");

        positionTokens = IPositionTokens(_positionTokens);
        marketResolver = IMarketResolver(_marketResolver);
        vault = IVault(_vault);
        market = IMarket(_marketContract);
        oracle = _oracle;

        // Initialize with no fee and no treasury
        feeRate = 0;
        treasury = address(0);
    }

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation Address of the new implementation
     * @dev Only callable by contract owner
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ============ Contract Management Functions ============

    /**
     * @notice Updates the position tokens contract address
     * @param _positionTokens New position tokens contract address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updatePositionTokens(address _positionTokens) external onlyOwner {
        require(_positionTokens != address(0), "Invalid position tokens");
        positionTokens = IPositionTokens(_positionTokens);
    }

    /**
     * @notice Updates the market resolver contract address
     * @param _marketResolver New market resolver contract address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateMarketResolver(address _marketResolver) external onlyOwner {
        require(_marketResolver != address(0), "Invalid market resolver");
        marketResolver = IMarketResolver(_marketResolver);
    }

    /**
     * @notice Updates the vault contract address
     * @param _vault New vault contract address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Invalid vault");
        vault = IVault(_vault);
    }

    /**
     * @notice Updates the market contract address
     * @param _market New market contract address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateMarket(address _market) external onlyOwner {
        require(_market != address(0), "Invalid market");
        market = IMarket(_market);
    }

    /**
     * @notice Updates the oracle address
     * @param _oracle New oracle address
     * @dev Only callable by contract owner, for emergency situations
     */
    function updateOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        oracle = _oracle;
    }

    // ============ Fee Management Functions ============

    /**
     * @notice Sets the default fee rate for winnings claims
     * @param _feeRate Fee rate in basis points (e.g., 400 = 4%)
     * @dev Only callable by contract owner, maximum 10% to prevent abuse
     */
    function setFeeRate(uint256 _feeRate) external onlyAuthorizedMatcher {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");

        uint256 oldRate = feeRate;
        feeRate = _feeRate;

        emit FeeRateUpdated(oldRate, _feeRate);
    }

    /**
     * @notice Sets the treasury address where fees are sent
     * @param _treasury Address of the treasury
     * @dev Only callable by contract owner
     */
    function setTreasury(address _treasury) external onlyAuthorizedMatcher {
        require(_treasury != address(0), "Invalid treasury address");

        address oldTreasury = treasury;
        treasury = _treasury;

        emit TreasuryUpdated(oldTreasury, _treasury);
    }

    /**
     * @notice Sets a custom fee rate for specific user (fee tier system)
     * @param user Address of the user
     * @param _feeRate Custom fee rate in basis points (0 = use default rate)
     * @dev Only callable by contract owner, allows preferential rates for MMs/whales
     */
    function setUserFeeRate(address user, uint256 _feeRate) external onlyAuthorizedMatcher {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");

        userFeeRate[user] = _feeRate;

        emit UserFeeRateSet(user, _feeRate);
    }

    /**
     * @notice Gets the effective fee rate for a user
     * @param user Address of the user
     * @return Fee rate in basis points that will be applied to this user
     */
    function getEffectiveFeeRate(address user) external view returns (uint256) {
        return _getEffectiveFeeRate(user);
    }

    /**
    * @notice Sets the default trade fee rate
    * @param _tradeFeeRate Fee rate in basis points (e.g., 100 = 1%)
    * @dev Only callable by authorized matcher, maximum 10%
    */
    function setTradeFeeRate(uint256 _tradeFeeRate) external onlyAuthorizedMatcher {
        require(_tradeFeeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");

        uint256 oldRate = tradeFeeRate;
        tradeFeeRate = _tradeFeeRate;

        emit TradeFeeRateUpdated(oldRate, _tradeFeeRate);
    }

    /**
    * @notice Sets a custom trade fee rate for specific user
    * @param user Address of the user
    * @param _tradeFeeRate Custom fee rate in basis points (0 = use default rate)
    * @dev Only callable by authorized matcher
    */
    function setUserTradeFeeRate(address user, uint256 _tradeFeeRate) external onlyAuthorizedMatcher {
        require(_tradeFeeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");

        userTradeFeeRate[user] = _tradeFeeRate;

        emit UserTradeFeeRateSet(user, _tradeFeeRate);
    }

    /**
    * @notice Gets the effective trade fee rate for a user
    * @param user Address of the user
    * @return Fee rate in basis points that will be applied to this user's trades
    */
    function getEffectiveTradeFeeRate(address user) external view returns (uint256) {
        return _getEffectiveTradeFeeRate(user);
    }

    // ============ Trading Hours Control Functions ============

    /**
     * @notice Sets global trading pause state (emergency stop)
     * @param paused True to pause all trading, false to resume
     * @dev Only callable by contract owner, affects all markets
     */
    function setGlobalTradingPaused(bool paused) external onlyAuthorizedMatcher {
        globalTradingPaused = paused;
        emit GlobalTradingPauseChanged(paused);
    }

    /**
     * @notice Sets trading pause state for specific market
     * @param questionId Market question identifier
     * @param paused True to pause trading, false to resume
     * @dev Only callable by contract owner, for trading hours control
     */
    function setMarketTradingPaused(bytes32 questionId, bool paused) external onlyAuthorizedMatcher {
        marketTradingPaused[questionId] = paused;
        emit MarketTradingPauseChanged(questionId, paused);
    }

    /**
     * @notice Sets trading pause state for multiple markets (batch operation)
     * @param questionIds Array of market question identifiers
     * @param paused True to pause trading, false to resume
     * @dev Only callable by contract owner, gas-efficient for bulk updates
     */
    function batchSetMarketTradingPaused(bytes32[] calldata questionIds, bool paused) external onlyAuthorizedMatcher {
        for (uint256 i = 0; i < questionIds.length; i++) {
            marketTradingPaused[questionIds[i]] = paused;
        }
        emit BatchMarketTradingPauseChanged(questionIds, paused);
    }

    /**
     * @notice Checks if trading is active for a specific market
     * @param questionId Market question identifier
     * @return True if trading is active (not paused globally or for this market)
     */
    function isTradingActive(bytes32 questionId) external view returns (bool) {
        return !globalTradingPaused && !marketTradingPaused[questionId];
    }

    // ============ Market Management Functions ============

    /**
    * @notice Creates a new market with optional time-based resolution and epoch rolling
    * @param questionId Unique market question identifier
    * @param outcomeCount Number of possible outcomes
    * @param resolutionTime Timestamp when market should resolve (0 for manual resolution)
    * @param epochDuration Duration of each epoch in seconds (0 for manual epoch advancement)
    * @dev Only callable by authorized matchers
    * @dev For continuous markets: set resolutionTime=0, epochDuration=86400 (daily rolling)
    * @dev For legacy markets: set epochDuration=0 (requires manual advanceEpoch calls)
    *
    * Examples:
    * - Daily continuous market: resolutionTime=0, epochDuration=86400
    * - Weekly continuous market: resolutionTime=0, epochDuration=604800
    * - One-time event: resolutionTime=futureTimestamp, epochDuration=0
    */
    function createMarket(
        bytes32 questionId,
        uint256 outcomeCount,
        uint256 resolutionTime,
        uint256 epochDuration
    ) external onlyAuthorizedMatcher {
        market.createMarket(questionId, outcomeCount, resolutionTime, epochDuration);
    }

    /**
    * @notice Updates resolution time for existing market
    * @param questionId Market question identifier
    * @param resolutionTime New resolution timestamp (0 for manual resolution)
    * @dev Only callable by authorized matchers, only before current resolution time
    */
    function updateMarketResolutionTime(bytes32 questionId, uint256 resolutionTime) external onlyAuthorizedMatcher {
        market.updateResolutionTime(questionId, resolutionTime);
    }

    /**
    * @notice Advances market to next epoch (manual mode only)
    * @param questionId Market question identifier
    * @dev Only callable by authorized matchers
    * @dev Only works for manual epoch markets (epochDuration = 0)
    * @dev Time-based markets advance automatically, calling this will revert
    */
    function advanceMarketEpoch(bytes32 questionId) external onlyAuthorizedMatcher {
        market.advanceEpoch(questionId);
    }

    // ============ Order Matching Functions ============

    /**
     * @notice Executes a trade using EIP-712 signed orders
     * @param buyOrder The buy order details
     * @param sellOrder The sell order details
     * @param buySignature The buyer's signature
     * @param sellSignature The seller's signature
     * @param fillAmount Amount to fill (must not exceed either order)
     */
    function executeOrderMatch(
        IMarketController.Order calldata buyOrder,
        IMarketController.Order calldata sellOrder,
        bytes calldata buySignature,
        bytes calldata sellSignature,
        uint256 fillAmount
    )
        external
        onlyAuthorizedMatcher
        nonReentrant
        onlyOpenMarket(buyOrder.questionId)
        whenTradingActive(buyOrder.questionId)
    {
        require(buyOrder.questionId == sellOrder.questionId, "Question ID mismatch");
        require(buyOrder.outcome == sellOrder.outcome, "Outcome mismatch");
        require(buyOrder.isBuyOrder && !sellOrder.isBuyOrder, "Order type mismatch");
        require(buyOrder.price >= sellOrder.price, "Price mismatch");
        require(fillAmount > 0, "Invalid fill amount");

        // Verify both signatures
        bytes32 buyOrderHash = _verifyOrder(buyOrder, buySignature);
        bytes32 sellOrderHash = _verifyOrder(sellOrder, sellSignature);

        // Check fill amounts don't exceed remaining
        require(filledAmounts[buyOrderHash] + fillAmount <= buyOrder.amount, "Buy order overfilled");
        require(filledAmounts[sellOrderHash] + fillAmount <= sellOrder.amount, "Sell order overfilled");

        // Update filled amounts
        filledAmounts[buyOrderHash] += fillAmount;
        filledAmounts[sellOrderHash] += fillAmount;

        // Execute the trade with settlement mode detection
        _executeTrade(buyOrder, sellOrder, fillAmount);

        uint256 currentEpoch = market.getCurrentEpoch(buyOrder.questionId);

        emit OrderFilled(
            buyOrderHash,
            buyOrder.user,
            buyOrder.questionId,
            buyOrder.outcome,
            fillAmount,
            sellOrder.price, // Execution price
            true, // isBuyOrder
            currentEpoch,
            sellOrder.user // taker
        );

        emit OrderFilled(
            sellOrderHash,
            sellOrder.user,
            sellOrder.questionId,
            sellOrder.outcome,
            fillAmount,
            sellOrder.price, // Execution price
            false, // isBuyOrder
            currentEpoch,
            buyOrder.user // taker
        );
    }

    /**
     * @notice Executes a single signed order against matcher's liquidity
     * @param order The order to execute
     * @param signature The user's signature
     * @param fillAmount Amount to fill
     * @param counterparty Address providing liquidity (authorized matcher)
     */
    function executeSingleOrder(
        IMarketController.Order calldata order,
        bytes calldata signature,
        uint256 fillAmount,
        address counterparty
    )
        external
        onlyAuthorizedMatcher
        nonReentrant
        onlyOpenMarket(order.questionId)
        whenTradingActive(order.questionId)
    {
        require(fillAmount > 0, "Invalid fill amount");
        bytes32 orderHash = _verifyOrder(order, signature);

        // Check fill amount doesn't exceed remaining
        require(filledAmounts[orderHash] + fillAmount <= order.amount, "Order overfilled");

        // Update filled amount
        filledAmounts[orderHash] += fillAmount;

        // Execute against matcher's liquidity
        _executeAgainstMatcher(order, fillAmount, counterparty);

        uint256 currentEpoch = market.getCurrentEpoch(order.questionId);

        emit OrderFilled(
            orderHash,
            order.user,
            order.questionId,
            order.outcome,
            fillAmount,
            order.price, // Execution price
            order.isBuyOrder,
            currentEpoch,
            counterparty // taker
        );
    }

    /**
     * @notice Allows users to cancel their own orders
     * @param order The order to cancel
     * @param signature The user's signature (for verification)
     */
     //@audit-low, users can cancel non existing orders
    function cancelOrder(IMarketController.Order calldata order, bytes calldata signature) external {
        require(order.user == _msgSender(), "Not order owner");

        bytes32 orderHash = _verifyOrder(order, signature);

        // Mark as fully filled to prevent execution
        filledAmounts[orderHash] = order.amount;

        emit OrderCancelled(orderHash, order.user);
    }

    /**
     * @notice Get the EIP-712 hash for an order
     */
    function getOrderHash(IMarketController.Order calldata order) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        )));
    }

    /**
     * @notice Check how much of an order has been filled
     */
    function getOrderFillAmount(bytes32 orderHash) external view returns (uint256) {
        return filledAmounts[orderHash];
    }

    /**
     * @notice Check remaining amount for an order
     */
    function getOrderRemainingAmount(IMarketController.Order calldata order) external view returns (uint256) {
        bytes32 orderHash = _hashTypedDataV4(keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        )));

        uint256 filled = filledAmounts[orderHash];
        return filled >= order.amount ? 0 : order.amount - filled;
    }

    // ============ Claims and Resolution Functions ============

    /**
     * @notice Claims winnings from resolved market with fee collection
     * @param questionId Market question identifier
     * @param epoch Specific epoch for the claim
     * @param outcome Winning outcome being claimed
     * @param merkleProof Proof of winning outcome
     * @return Payout amount transferred to user (after fees)
     * @dev Claims are always allowed regardless of trading hours
     */
    function claimWinnings(bytes32 questionId, uint256 epoch, uint256 outcome, bytes32[] calldata merkleProof)
        external
        nonReentrant
        returns (uint256)
    {
        require(epoch > 0, "Invalid epoch");
        require(market.getCurrentEpoch(questionId) >= epoch, "Epoch not reached");

        uint256 numberOfOutcomes = market.getOutcomeCount(questionId);
        bytes32 conditionId = market.getConditionId(oracle, questionId, numberOfOutcomes, epoch);

        require(marketResolver.getResolutionStatus(conditionId), "Market not resolved");

        uint256 tokenId = positionTokens.getTokenId(conditionId, outcome);
        uint256 userBalance = positionTokens.balanceOf(_msgSender(), tokenId);
        require(userBalance > 0, "No tokens to claim");

        // Verify the outcome won using proof verification
        require(marketResolver.verifyProof(conditionId, outcome, merkleProof), "Invalid proof");

        // Calculate fees and net payout
        (uint256 netPayout, uint256 feeAmount) = _calculatePayoutAndFee(_msgSender(), userBalance);

        // Burn tokens
        positionTokens.burn(_msgSender(), tokenId, userBalance);

        // Handle fee collection and payout
        _processPayout(conditionId, _msgSender(), questionId, netPayout, feeAmount);

        emit WinningsClaimed(_msgSender(), questionId, epoch, outcome, netPayout);
        return netPayout;
    }

    /**
     * @notice Claims winnings from multiple resolved markets in a single transaction with fee collection
     * @param claims Array of claim requests for different markets/epochs
     * @return totalPayout Total payout amount transferred to user across all claims (after fees)
     * @dev Processes all valid claims and skips invalid ones, enabling users to claim all winnings efficiently
     */
    function batchClaimWinnings(ClaimRequest[] calldata claims)
        external
        nonReentrant
        returns (uint256 totalPayout)
    {
        require(claims.length > 0, "No claims provided");
        require(claims.length <= 50, "Too many claims"); // Gas limit protection

        address user = _msgSender();
        uint256 validClaims = 0;

        // Arrays for batch operations
        bytes32[] memory conditionIds = new bytes32[](claims.length);
        address[] memory users = new address[](claims.length);
        uint256[] memory netAmounts = new uint256[](claims.length);
        uint256[] memory feeAmounts = new uint256[](claims.length);
        uint256[] memory tokenIds = new uint256[](claims.length);
        uint256[] memory grossAmounts = new uint256[](claims.length);

        // Process each claim
        for (uint256 i = 0; i < claims.length; i++) {
            ClaimRequest memory claim = claims[i];

            // Validate basic parameters
            if (claim.epoch == 0) continue;
            if (market.getCurrentEpoch(claim.questionId) < claim.epoch) continue;

            uint256 numberOfOutcomes = market.getOutcomeCount(claim.questionId);
            if (numberOfOutcomes == 0) continue; // Market doesn't exist

            bytes32 conditionId = market.getConditionId(oracle, claim.questionId, numberOfOutcomes, claim.epoch);

            // Check if market is resolved
            if (!marketResolver.getResolutionStatus(conditionId)) continue;

            uint256 tokenId = positionTokens.getTokenId(conditionId, claim.outcome);
            uint256 userBalance = positionTokens.balanceOf(user, tokenId);

            // Skip if user has no tokens for this claim
            if (userBalance == 0) continue;

            // Verify the outcome won using proof verification
            if (!marketResolver.verifyProof(conditionId, claim.outcome, claim.merkleProof)) continue;

            // Calculate fees for this claim
            (uint256 netPayout, uint256 feeAmount) = _calculatePayoutAndFee(user, userBalance);

            // Add to batch arrays
            conditionIds[validClaims] = conditionId;
            users[validClaims] = user;
            netAmounts[validClaims] = netPayout;
            feeAmounts[validClaims] = feeAmount;
            tokenIds[validClaims] = tokenId;
            grossAmounts[validClaims] = userBalance; // Store original amount for burning

            totalPayout += netPayout;
            validClaims++;

            // Emit individual claim event for tracking
            emit WinningsClaimed(user, claim.questionId, claim.epoch, claim.outcome, netPayout);
        }

        require(validClaims > 0, "No valid claims found");

        // Perform batch token burns (burn the original gross amounts)
        for (uint256 i = 0; i < validClaims; i++) {
            positionTokens.burn(user, tokenIds[i], grossAmounts[i]);
        }

        // Prepare arrays for batch vault operations (resize to valid claims only)
        bytes32[] memory finalConditionIds = new bytes32[](validClaims);
        address[] memory finalUsers = new address[](validClaims);
        uint256[] memory finalNetAmounts = new uint256[](validClaims);

        for (uint256 i = 0; i < validClaims; i++) {
            finalConditionIds[i] = conditionIds[i];
            finalUsers[i] = users[i];
            finalNetAmounts[i] = netAmounts[i];
        }

        // Unlock collateral for user (net amounts)
        vault.batchUnlockCollateral(finalConditionIds, finalUsers, finalNetAmounts);

        // Handle fee collection in batch if there are fees and treasury is set
        if (treasury != address(0)) {
            // Prepare arrays for fee collection
            address[] memory treasuryUsers = new address[](validClaims);
            uint256[] memory finalFeeAmounts = new uint256[](validClaims);

            uint256 feeClaims = 0;
            for (uint256 i = 0; i < validClaims; i++) {
                if (feeAmounts[i] > 0) {
                    treasuryUsers[feeClaims] = treasury;
                    finalFeeAmounts[feeClaims] = feeAmounts[i];
                    feeClaims++;
                }
            }

            // Only process fee collection if there are actual fees
            if (feeClaims > 0) {
                // Resize arrays for fee collection
                bytes32[] memory feeConditionIds = new bytes32[](feeClaims);
                address[] memory feeUsers = new address[](feeClaims);
                uint256[] memory feeAmountsArray = new uint256[](feeClaims);

                uint256 feeIndex = 0;
                for (uint256 i = 0; i < validClaims; i++) {
                    if (feeAmounts[i] > 0) {
                        feeConditionIds[feeIndex] = finalConditionIds[i];
                        feeUsers[feeIndex] = treasury;
                        feeAmountsArray[feeIndex] = feeAmounts[i];
                        feeIndex++;
                    }
                }

                vault.batchUnlockCollateral(feeConditionIds, feeUsers, feeAmountsArray);
            }
        }

        emit BatchWinningsClaimed(user, totalPayout, validClaims);
        return totalPayout;
    }

    /**
     * @notice Emergency function to resolve markets that have passed their resolution time
     * @param questionId Market question identifier
     * @param numberOfOutcomes Number of possible outcomes for validation
     * @param merkleRoot Root hash of merkle tree containing valid outcomes
     * @dev Can only be called after resolution time has passed, provides fallback resolution
     */
    function emergencyResolveMarket(bytes32 questionId, uint256 numberOfOutcomes, bytes32 merkleRoot)
        external
        onlyAuthorizedMatcher
    {
        require(market.isMarketReadyForResolution(questionId), "Market not ready for resolution");

        // Validate numberOfOutcomes parameter matches the actual market
        uint256 actualOutcomes = market.getOutcomeCount(questionId);
        require(actualOutcomes > 0, "Market not found");
        require(numberOfOutcomes == actualOutcomes, "Outcome count mismatch");
        require(numberOfOutcomes <= 256, "Maximum 256 outcomes supported");
        uint256 currentEpoch = market.getCurrentEpoch(questionId);
        marketResolver.resolveMarketEpoch(questionId, currentEpoch, numberOfOutcomes, merkleRoot);

        emit EmergencyResolution(questionId, currentEpoch, merkleRoot);
    }

    /**
     * @notice Sets authorization status for off-chain matching systems
     * @param matcher Address of the matching system
     * @param authorized Whether the matcher is authorized
     * @dev Only callable by contract owner
     */
    function setAuthorizedMatcher(address matcher, bool authorized) external onlyOwner {
        authorizedMatchers[matcher] = authorized;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculates net payout and fee amount for a user
     * @param user Address of the user claiming
     * @param grossPayout Gross payout amount before fees
     * @return netPayout Amount to be paid to user after fees
     * @return feeAmount Amount to be paid to treasury as fee
     */
    function _calculatePayoutAndFee(address user, uint256 grossPayout) internal view returns (uint256 netPayout, uint256 feeAmount) {
        if (grossPayout == 0) {
            return (0, 0);
        }

        uint256 applicableFeeRate = _getEffectiveFeeRate(user);

        if (applicableFeeRate == 0 || treasury == address(0)) {
            return (grossPayout, 0);
        }

        feeAmount = (grossPayout * applicableFeeRate) / 10000;
        netPayout = grossPayout - feeAmount;

        return (netPayout, feeAmount);
    }

    /**
     * @notice Processes payout by unlocking collateral for user and collecting fees
     * @param conditionId Condition identifier for the market
     * @param user User receiving the payout
     * @param questionId Market question identifier for event emission
     * @param netPayout Amount to unlock for user
     * @param feeAmount Amount to unlock for treasury
     */
    function _processPayout(
        bytes32 conditionId,
        address user,
        bytes32 questionId,
        uint256 netPayout,
        uint256 feeAmount
    ) internal {
        // Unlock collateral for user
        vault.unlockCollateral(conditionId, user, netPayout);

        // Collect fee to treasury if applicable
        if (feeAmount > 0 && treasury != address(0)) {
            vault.unlockCollateral(conditionId, treasury, feeAmount);
            emit FeeCollected(user, questionId, feeAmount, netPayout);
        }
    }

    /**
     * @notice Gets the effective fee rate for a user (internal version)
     * @param user Address of the user
     * @return Fee rate in basis points
     */
    function _getEffectiveFeeRate(address user) internal view returns (uint256) {
        return userFeeRate[user] > 0 ? userFeeRate[user] : feeRate;
    }

    /**
    * @notice Gets the effective trade fee rate for a user (internal version)
    * @param user Address of the user
    * @return Fee rate in basis points
    */
    function _getEffectiveTradeFeeRate(address user) internal view returns (uint256) {
        return userTradeFeeRate[user] > 0 ? userTradeFeeRate[user] : tradeFeeRate;
    }

    /**
     * @notice Verifies an order signature and basic validity
     */
    function _verifyOrder(IMarketController.Order calldata order, bytes calldata signature) internal view returns (bytes32) {
        // Check expiration
        require(block.timestamp <= order.expiration, "Order expired");

        // Generate order hash
        bytes32 orderHash = _hashTypedDataV4(keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.user,
            order.questionId,
            order.outcome,
            order.amount,
            order.price,
            order.nonce,
            order.expiration,
            order.isBuyOrder
        )));

        // Verify signature
        address signer = orderHash.recover(signature);
        require(signer == order.user, "Invalid signature");

        // Check if order is already fully filled
        require(filledAmounts[orderHash] < order.amount, "Order fully filled");

        return orderHash;
    }

    /**
     * @notice Executes a trade between two orders with intelligent settlement mode detection
     * @dev Determines whether to use token swap (if seller has tokens) or JIT minting (if not)
     */
    function _executeTrade(IMarketController.Order calldata buyOrder, IMarketController.Order calldata sellOrder, uint256 fillAmount) internal {
        uint256 numberOfOutcomes = market.getOutcomeCount(buyOrder.questionId);
        bytes32 conditionId = market.getConditionId(oracle, buyOrder.questionId, numberOfOutcomes, 0);
        uint256 tokenId = positionTokens.getTokenId(conditionId, buyOrder.outcome);

        // Check if seller has existing tokens (SWAP mode vs JIT MINTING mode)
        uint256 sellerBalance = positionTokens.balanceOf(sellOrder.user, tokenId);

        if (sellerBalance >= fillAmount) {
            // SWAP MODE: Seller has tokens, execute direct token-for-USDC swap
            _executeTokenSwap(conditionId, buyOrder, sellOrder, fillAmount, tokenId);
        } else {
            // JIT MINTING MODE: Neither has tokens, mint complete set with proportional contributions
            _executeJITMinting(conditionId, buyOrder, sellOrder, fillAmount, numberOfOutcomes);
        }
    }

    /**
    * @notice Executes token swap when seller has existing tokens
    * @param conditionId Condition identifier
    * @param buyOrder Buyer's order
    * @param sellOrder Seller's order
    * @param fillAmount Amount being traded
    * @param tokenId Token ID being traded
    */
    function _executeTokenSwap(
        bytes32 conditionId,
        IMarketController.Order calldata buyOrder,
        IMarketController.Order calldata sellOrder,
        uint256 fillAmount,
        uint256 tokenId
    ) internal {
        // Calculate payment based on execution price (seller's price in a match)
        //@audit-high ✅ (duplicated), paymentAmount should be required to be greather than 0
        uint256 paymentAmount = (fillAmount * sellOrder.price) / 10000;

        // Calculate trade fee from buyer
        uint256 buyerFeeRate = _getEffectiveTradeFeeRate(buyOrder.user);
        uint256 tradeFee = (paymentAmount * buyerFeeRate) / 10000;
        uint256 netPayment = paymentAmount - tradeFee;

        // Burn tokens from seller and mint to buyer
        positionTokens.burn(sellOrder.user, tokenId, fillAmount);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = tokenId;
        amounts[0] = fillAmount;
        positionTokens.mintBatch(buyOrder.user, tokenIds, amounts);

        // Transfer fee to treasury if applicable
        if (tradeFee > 0 && treasury != address(0)) {
            vault.transferBetweenUsers(conditionId, buyOrder.user, treasury, tradeFee);
            emit TradeFeeCollected(buyOrder.user, buyOrder.questionId, tradeFee, netPayment);
        }
        else {
            netPayment = paymentAmount;
        }

        // Transfer net payment to seller
        vault.transferBetweenUsers(conditionId, buyOrder.user, sellOrder.user, netPayment);
    }

    /**
    * @notice Executes JIT minting when neither party has tokens
    * @param conditionId Condition identifier
    * @param buyOrder Buyer's order
    * @param sellOrder Seller's order
    * @param fillAmount Amount being traded
    * @param numberOfOutcomes Total outcomes in market
    */
    function _executeJITMinting(
        bytes32 conditionId,
        IMarketController.Order calldata buyOrder,
        IMarketController.Order calldata sellOrder,
        uint256 fillAmount,
        uint256 numberOfOutcomes
    ) internal {
        // Calculate proportional contributions based on execution price
        // Buyer pays: fillAmount * price (e.g., $0.60 per token)
        // Seller pays: fillAmount * (1 - price) (e.g., $0.40 per token)
        uint256 buyerPayment = (fillAmount * sellOrder.price) / 10000;
        uint256 sellerPayment = fillAmount - buyerPayment;

        // Calculate trade fees for both parties
        uint256 buyerFeeRate = _getEffectiveTradeFeeRate(buyOrder.user);
        uint256 sellerFeeRate = _getEffectiveTradeFeeRate(sellOrder.user);
        uint256 buyerFee = (buyerPayment * buyerFeeRate) / 10000;
        uint256 sellerFee = (sellerPayment * sellerFeeRate) / 10000;

        // Both parties lock their proportional collateral
        vault.lockCollateral(conditionId, buyOrder.user, buyerPayment);
        vault.lockCollateral(conditionId, sellOrder.user, sellerPayment);

        // Transfer fees to treasury (from available balance, after locking position collateral)
        if (treasury != address(0)) {
            if (buyerFee > 0) {
                vault.transferBetweenUsers(conditionId, buyOrder.user, treasury, buyerFee);
                emit TradeFeeCollected(buyOrder.user, buyOrder.questionId, buyerFee, buyerPayment);
            }
            if (sellerFee > 0) {
                vault.transferBetweenUsers(conditionId, sellOrder.user, treasury, sellerFee);
                emit TradeFeeCollected(sellOrder.user, sellOrder.questionId, sellerFee, sellerPayment);
            }
        }

        // Mint complete sets - buyer gets their outcome, seller gets the rest
        uint256[] memory buyerTokenIds = new uint256[](1);
        uint256[] memory buyerAmounts = new uint256[](1);
        uint256[] memory sellerTokenIds = new uint256[](numberOfOutcomes - 1);
        uint256[] memory sellerAmounts = new uint256[](numberOfOutcomes - 1);

        uint256 sellerIndex = 0;
        for (uint256 i = 0; i < numberOfOutcomes; i++) {
            uint256 outcomeIndex = 1 << i;
            uint256 tokenId = positionTokens.getTokenId(conditionId, outcomeIndex);

            if (outcomeIndex == buyOrder.outcome) {
                // This is the outcome the buyer wants
                buyerTokenIds[0] = tokenId;
                buyerAmounts[0] = fillAmount;
            } else {
                // These go to the seller
                sellerTokenIds[sellerIndex] = tokenId;
                sellerAmounts[sellerIndex] = fillAmount;
                sellerIndex++;
            }
        }

        // Mint tokens directly to recipients
        positionTokens.mintBatch(buyOrder.user, buyerTokenIds, buyerAmounts);
        if (sellerTokenIds.length > 0) {
            positionTokens.mintBatch(sellOrder.user, sellerTokenIds, sellerAmounts);
        }
    }

    /**
    * @notice Executes order against matcher's liquidity (inventory-based only)
    * @dev Matchers are expected to pre-mint and hold inventory. Does not support JIT minting.
    */
    function _executeAgainstMatcher(IMarketController.Order calldata order, uint256 fillAmount, address matcher) internal {
        uint256 numberOfOutcomes = market.getOutcomeCount(order.questionId);
        bytes32 conditionId = market.getConditionId(oracle, order.questionId, numberOfOutcomes, 0);
        uint256 tokenId = positionTokens.getTokenId(conditionId, order.outcome);
        //@audit-high ✅, paymentAmount should be required to be greather than 0
        //it could be 0 if (fillAmount * order.price) < 10000 and simultaneously fillAmount can be any number. 
        //this will allow the order.user to mint tokens an infinite number of times, and this will also lead to the matcher to incorrectly burn his positions token.
        //this would be a griefing attack, where the user is able to mint and / burn a small amount of tokens, but if the payment token is usdc (6 DECIMALS)
        //this could easily lead to accrue matcher's losses to hypotetically more than 10$

        uint256 paymentAmount = (fillAmount * order.price) / 10000;

        if (order.isBuyOrder) {
            // User wants to buy - matcher must have tokens in inventory
            require(positionTokens.balanceOf(matcher, tokenId) >= fillAmount, "Matcher insufficient inventory");

            // Calculate trade fee from user (buyer)
            uint256 buyerFeeRate = _getEffectiveTradeFeeRate(order.user);
            uint256 tradeFee = (paymentAmount * buyerFeeRate) / 10000;
            uint256 netPayment = paymentAmount - tradeFee;

            // Burn tokens from matcher and mint to user
            positionTokens.burn(matcher, tokenId, fillAmount);
            uint256[] memory tokenIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            tokenIds[0] = tokenId;
            amounts[0] = fillAmount;
            positionTokens.mintBatch(order.user, tokenIds, amounts);

            // Transfer fee to treasury if applicable
            if (tradeFee > 0 && treasury != address(0)) {
                vault.transferBetweenUsers(conditionId, order.user, treasury, tradeFee);
                emit TradeFeeCollected(order.user, order.questionId, tradeFee, netPayment);
            }
            else {
                netPayment = paymentAmount;
            }

            // Transfer net payment from user to matcher
            //@audit-high ✅, fees are not applied to the taker, instead they are applied to the maker
            vault.transferBetweenUsers(conditionId, order.user, matcher, netPayment);
        } else {
            // User wants to sell - they must have the tokens
            require(positionTokens.balanceOf(order.user, tokenId) >= fillAmount, "Insufficient tokens");

            // Calculate trade fee from matcher (buyer in this case)
            uint256 matcherFeeRate = _getEffectiveTradeFeeRate(matcher);
            uint256 tradeFee = (paymentAmount * matcherFeeRate) / 10000;
            uint256 netPayment = paymentAmount - tradeFee;

            // Burn tokens from user and mint to matcher
            positionTokens.burn(order.user, tokenId, fillAmount);
            uint256[] memory tokenIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            tokenIds[0] = tokenId;
            amounts[0] = fillAmount;
            positionTokens.mintBatch(matcher, tokenIds, amounts);

            // Transfer fee to treasury if applicable
            if (tradeFee > 0 && treasury != address(0)) {
                vault.transferBetweenUsers(conditionId, matcher, treasury, tradeFee);
                emit TradeFeeCollected(matcher, order.questionId, tradeFee, netPayment);
            }
            else {
                netPayment = paymentAmount;
            }

            // Transfer net payment from matcher to user
            vault.transferBetweenUsers(conditionId, matcher, order.user, netPayment);
        }
    }
}
