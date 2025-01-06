// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MathsLib } from "contracts/libraries/MathsLib.sol";

/// @title Auctioneer
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Inspired by FeeFlowController https://github.com/euler-xyz/fee-flow
contract Auctioneer is AccessManaged, Pausable {
    using SafeERC20 for IERC20;
    using MathsLib for *;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    uint256 public constant MIN_EPOCH_DURATION = 1 hours;
    uint256 public constant MAX_EPOCH_DURATION = 365 days;
    /// @notice Should at least be 110% of settlement price.
    uint256 public constant MIN_PRICE_MULTIPLIER = 1.1e18;
    /// @notice Should not exceed 300% of settlement price.
    uint256 public constant MAX_PRICE_MULTIPLIER = 3e18;
    /// @notice Minimum sane value for init price.
    uint256 public constant ABS_MIN_INIT_PRICE = 1e6;
    /// @notice Chosen so that initPrice * priceMultiplier does not exceed uint256.
    uint256 public constant ABS_MAX_INIT_PRICE = type(uint192).max;
    uint256 public constant PRICE_MULTIPLIER_SCALE = 1e18;

    /// @notice The payment token expected to receive.
    IERC20 public paymentToken;
    /// @notice The receiver address of the expected token.
    address public paymentReceiver;
    /// @notice The epoch duration.
    uint256 public epochDuration;
    /// @notice The price multiplier apply to init the start price of new epoch.
    uint256 public priceMultiplier;
    /// @notice The price min start price of new epoch.
    uint256 public minInitPrice;

    /// @notice The Slot0 struct contains the current epoch data.
    struct Slot0 {
        // 1 if locked, 2 if unlocked (save gas/memory space instead of Oz Reentrancy)
        uint8 locked;
        // intentionally overflowable
        uint16 epochId;
        uint192 initPrice;
        uint40 startTime;
    }

    /// @notice The current epoch data.
    Slot0 internal slot0;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    /// @notice Event emitted when token has been bought for the current epoch.
    /// @param buyer the buyer address.
    /// @param assetsReceiver the receiver of payment token.
    /// @param paymentAmount the amount paid by the buyer.
    event Buy(address buyer, address assetsReceiver, uint256 paymentAmount);

    /// @notice Emitted when tokens are rescued.
    /// @param token The address of the token.
    /// @param to The address of the recipient.
    /// @param amount The amount of tokens rescued.
    event EmergencyRescued(address token, address to, uint256 amount);

    /// @notice Event emitted when the payment token has been updated.
    /// @param newPaymentToken the new payment token address.
    event PaymentTokenUpdated(address newPaymentToken);

    /// @notice Event emitted when the payment receiver has been updated.
    /// @param newPaymentReceiver the new payment receiver address.
    event PaymentReceiverUpdated(address newPaymentReceiver);

    /// @notice Event emitted when the epoch settings have been updated.
    /// @param epochDuration the new epoch duration.
    /// @param initPrice the new initial price.
    /// @param priceMultiplier the new price multiplier.
    /// @param minInitPrice the new min initial price for new epoch.
    event EpocSettingsUpdated(uint256 epochDuration, uint256 initPrice, uint256 priceMultiplier, uint256 minInitPrice);

    //-------------------------------------------
    // Error
    //-------------------------------------------

    /// @notice Thrown when the reentrancy appear.
    error Reentrancy();
    /// @notice Thrown when init price below minInitPrice.
    error InitPriceBelowMin();
    /// @notice Thrown when init price exceeds ABS_MAX_INIT_PRICE.
    error InitPriceExceedsMax();
    /// @notice Thrown when epoch duration below MIN_EPOCH_DURATION.
    error EpochDurationBelowMin();
    /// @notice Thrown when epoch duration exceeds MAX_EPOCH_DURATION.
    error EpochDurationExceedsMax();
    /// @notice Thrown when price multiplier below MIN_PRICE_MULTIPLIER.
    error PriceMultiplierBelowMin();
    /// @notice Thrown when price multiplier exceeds MAX_PRICE_MULTIPLIER.
    error PriceMultiplierExceedsMax();
    /// @notice Thrown when min init price below ABS_MIN_INIT_PRICE.
    error MinInitPriceBelowMin();
    /// @notice Thrown when min init price exceeds ABS_MAX_INIT_PRICE.
    error MinInitPriceExceedsAbsMaxInitPrice();
    /// @notice Thrown when start time is passed.
    error InitStartTimePassed();
    /// @notice Thrown when assets array to buy is empty.
    error EmptyAssets();
    /// @notice Thrown when epochId expected to buy is not the current one.
    error EpochIdMismatch();
    /// @notice Thrown when calculated amount to paid exceed to max expected one.
    error MaxPaymentTokenAmountExceeded();
    /// @notice Thrown when new payment receiver is the contract itself.
    error PaymentReceiverIsThis();

    //-------------------------------------------
    // Modifier
    //-------------------------------------------

    modifier nonReentrant() {
        if (slot0.locked == 2) revert Reentrancy();
        slot0.locked = 2;
        _;
        slot0.locked = 1;
    }

    modifier nonReentrantView() {
        if (slot0.locked == 2) revert Reentrancy();
        _;
    }

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice This constructor performs parameter validation and sets the initial values for the contract.
    /// @dev Initializes the FeeFlowController contract with the specified parameters.
    /// @param _accessManager The address of the AccessManager contract.
    /// @param _paymentToken The address of the payment token.
    /// @param _paymentReceiver The address of the payment receiver.
    /// @param _initStartTime The initial start time for the first epoch.
    /// @param _epochDuration The duration of each epoch.
    /// @param _initPrice The initial price for the first epoch.
    /// @param _priceMultiplier The multiplier for adjusting the price from one epoch to the next.
    /// @param _minInitPrice The minimum allowed initial price for an epoch.
    constructor(
        address _accessManager,
        address _paymentToken,
        address _paymentReceiver,
        uint256 _initStartTime,
        uint256 _epochDuration,
        uint256 _initPrice,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    )
        AccessManaged(_accessManager)
    {
        _assertEpochSettings(_epochDuration, _initPrice, _priceMultiplier, _minInitPrice);
        if (block.timestamp > _initStartTime) revert InitStartTimePassed();
        if (_paymentReceiver == address(this)) revert PaymentReceiverIsThis();

        slot0.initPrice = uint192(_initPrice);
        slot0.startTime = uint40(_initStartTime);

        paymentToken = IERC20(_paymentToken);
        paymentReceiver = _paymentReceiver;
        epochDuration = _epochDuration;
        priceMultiplier = _priceMultiplier;
        minInitPrice = _minInitPrice;
    }

    //-------------------------------------------
    // External functions
    //-------------------------------------------

    /// @notice This function performs various checks and transfers the payment tokens to the payment receiver.
    /// It also transfers the assets to the assets receiver and sets up a new auction with an updated initial price.
    /// @dev Allows a user to buy assets by transferring payment tokens and receiving the assets.
    /// @param _assets The addresses of the assets to be bought.
    /// @param _assetsReceiver The address that will receive the bought assets.
    /// @param _epochId Id of the epoch to buy from, will revert if not the current epoch
    /// @param _maxPaymentTokenAmount The maximum amount of payment tokens the user is willing to spend.
    /// @return paymentAmount The amount of payment tokens transferred for the purchase.
    function buy(
        address[] calldata _assets,
        address _assetsReceiver,
        uint256 _epochId,
        uint256 _maxPaymentTokenAmount
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 paymentAmount)
    {
        if (_assets.length == 0) revert EmptyAssets();

        Slot0 memory slot0Cache = slot0;

        if (uint16(_epochId) != slot0Cache.epochId) revert EpochIdMismatch();

        paymentAmount = getPriceFromCache(slot0Cache);

        if (paymentAmount > _maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();

        // Setup new auction
        uint256 newInitPrice = paymentAmount.mulDivUp(priceMultiplier, PRICE_MULTIPLIER_SCALE);

        if (newInitPrice > ABS_MAX_INIT_PRICE) {
            newInitPrice = ABS_MAX_INIT_PRICE;
        } else if (newInitPrice < minInitPrice) {
            newInitPrice = minInitPrice;
        }

        // epochID is allowed to overflow, effectively reusing them
        unchecked {
            slot0Cache.epochId++;
        }
        slot0Cache.initPrice = uint192(newInitPrice);
        slot0Cache.startTime = uint40(block.timestamp);

        // Write cache in single write
        slot0 = slot0Cache;

        emit Buy(msg.sender, _assetsReceiver, paymentAmount);

        if (paymentAmount > 0) {
            paymentToken.safeTransferFrom(msg.sender, paymentReceiver, paymentAmount);
        }

        uint256 i = 0;
        for (; i < _assets.length; ++i) {
            // Transfer full balance to buyer
            uint256 balance = IERC20(_assets[i]).balanceOf(address(this));
            IERC20(_assets[i]).safeTransfer(_assetsReceiver, balance);
        }

        return paymentAmount;
    }

    /// @dev Calculates the current price
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice Uses the internal function `getPriceFromCache` to calculate the current price.
    function getPrice() external view nonReentrantView returns (uint256) {
        return getPriceFromCache(slot0);
    }

    /// @dev Retrieves Slot0 as a memory struct
    /// @return Slot0 The Slot0 value as a Slot0 struct
    function getSlot0() external view nonReentrantView returns (Slot0 memory) {
        return slot0;
    }

    //-------------------------------------------
    // AccessManaged functions
    //-------------------------------------------

    /// @notice Allow to rescue token own by the contract.
    /// @dev This function can only be called by the accessManager.
    /// @param _token The address of the ERC20 token to rescue.
    /// @param _to The address of the receiver.
    /// @param _amount The amount of tokens to rescue.
    function emergencyRescue(address _token, address _to, uint256 _amount) external restricted whenPaused {
        emit EmergencyRescued(_token, _to, _amount);
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /// @notice Allow to update the payment token.
    /// @dev This function can only be called by the accessManager.
    /// @param _newPaymentToken The address of the new payment token.
    function updatePaymentToken(address _newPaymentToken) external restricted {
        paymentToken = IERC20(_newPaymentToken);
        emit PaymentTokenUpdated(_newPaymentToken);
    }

    /// @notice Allow to update the payment receiver.
    /// @dev This function can only be called by the accessManager.
    /// @param _newPaymentReceiver The address of the new payment receiver.
    function updatePaymentReceiver(address _newPaymentReceiver) external restricted {
        if (_newPaymentReceiver == address(this)) revert PaymentReceiverIsThis();
        paymentReceiver = _newPaymentReceiver;
        emit PaymentReceiverUpdated(_newPaymentReceiver);
    }

    /// @notice Allow to update epoch settings
    /// @dev This function can only be called by the accessManager.
    /// @param _epochDuration The new epoch duration.
    /// @param _initPrice The new initial price.
    /// @param _priceMultiplier The new price multiplier.
    /// @param _minInitPrice The new min initial price for new epoch.
    function updateEpochSettings(
        uint256 _epochDuration,
        uint256 _initPrice,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    )
        external
        restricted
    {
        _assertEpochSettings(_epochDuration, _initPrice, _priceMultiplier, _minInitPrice);

        Slot0 memory slot0Cache = slot0;
        unchecked {
            slot0Cache.epochId++;
        }
        slot0Cache.initPrice = uint192(_initPrice);
        slot0Cache.startTime = uint40(block.timestamp);

        slot0 = slot0Cache;
        epochDuration = _epochDuration;
        priceMultiplier = _priceMultiplier;
        minInitPrice = _minInitPrice;
        emit EpocSettingsUpdated(_epochDuration, _initPrice, _priceMultiplier, _minInitPrice);
    }

    /// @notice Allow AccessManager to pause the contract
    /// @dev This function can only be called by the owner
    function pause() external restricted {
        _pause();
    }

    /// @notice Allow AccessManager to unpause the contract
    /// @dev This function can only be called by the owner
    function unpause() external restricted {
        _unpause();
    }

    //-------------------------------------------
    // Private/Internal functions
    //-------------------------------------------

    /// @dev Retrieves the current price from the cache based on the elapsed time since the start of the epoch.
    /// @param _slot0Cache The Slot0 struct containing the initial price and start time of the epoch.
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice This function calculates the current price by subtracting a fraction of the initial price based on the
    /// elapsed time.
    // If the elapsed time exceeds the epoch duration, the price will be 0.
    function getPriceFromCache(Slot0 memory _slot0Cache) internal view returns (uint256) {
        uint256 timePassed = block.timestamp - _slot0Cache.startTime;
        if (timePassed > epochDuration) {
            return 0;
        }
        return _slot0Cache.initPrice - _slot0Cache.initPrice.mulDivUp(timePassed, epochDuration);
    }

    /// @notice Assert new epoch settings data are valid
    /// @param _epochDuration The new epoch duration.
    /// @param _priceMultiplier The new price multiplier.
    /// @param _initPrice The new initial price.
    /// @param _minInitPrice The new min initial price for new epoch.
    function _assertEpochSettings(
        uint256 _epochDuration,
        uint256 _initPrice,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    )
        private
        pure
    {
        if (_initPrice < _minInitPrice) revert InitPriceBelowMin();
        if (_initPrice > ABS_MAX_INIT_PRICE) revert InitPriceExceedsMax();
        if (_epochDuration < MIN_EPOCH_DURATION) revert EpochDurationBelowMin();
        if (_epochDuration > MAX_EPOCH_DURATION) revert EpochDurationExceedsMax();
        if (_priceMultiplier < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
        if (_priceMultiplier > MAX_PRICE_MULTIPLIER) revert PriceMultiplierExceedsMax();
        if (_minInitPrice < ABS_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
        if (_minInitPrice > ABS_MAX_INIT_PRICE) revert MinInitPriceExceedsAbsMaxInitPrice();
    }
}
