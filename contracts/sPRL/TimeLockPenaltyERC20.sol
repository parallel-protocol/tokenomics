// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { MathsLib } from "contracts/libraries/MathsLib.sol";

/// @title TimeLockPenaltyERC20
/// @notice An ERC20 wrapper contract that allows users to deposit assets and can only withdraw them after a specified
/// time lock period. If the user withdraws before the time lock period, a penalty fee is applied relative to the time
/// left.
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
contract TimeLockPenaltyERC20 is ERC20Permit, AccessManaged, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using MathsLib for *;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The status of a withdrawal request.
    enum WITHDRAW_STATUS {
        UNUSED,
        UNLOCKING,
        RELEASED,
        CANCELLED
    }

    /// @notice A struct to store the details of a withdrawal request.
    struct WithdrawalRequest {
        /// @notice The amount of assets the user requested to withdraw.
        uint256 amount;
        /// @notice The time the user requested the withdrawal.
        uint64 requestTime;
        /// @notice The time the user can withdraw the assets.
        uint64 releaseTime;
        /// @notice The status of the withdrawal request.
        WITHDRAW_STATUS status;
    }

    /// @notice 1e18 = 100%
    uint256 private constant MAX_PENALTY_PERCENTAGE = 1e18;
    /// @notice The min duration of the time lock
    uint64 constant MIN_TIMELOCK_DURATION = 1 days;
    /// @notice The max duration of the time lock
    uint64 constant MAX_TIMELOCK_DURATION = 365 days;

    /// @notice The address of the underlying token.
    IERC20 public underlying;
    /// @notice The address that will receive the fees.
    address public feeReceiver;
    /// @notice The duration of the time lock.
    uint64 public timeLockDuration;
    /// @notice The amount of assets that are in unlocking state.
    uint256 public unlockingAssets;
    /// @notice The penalties percentage that will be applied at request time.
    uint256 public startPenaltyPercentage;
    /// @notice Mapping of user to their withdrawal requests.
    mapping(address user => mapping(uint256 requestId => WithdrawalRequest request)) public userVsWithdrawals;
    /// @notice Mapping of user to their next withdrawal request ID.
    mapping(address user => uint256 nextRequestId) public userVsNextID;

    //----------------------------------------
    // Events
    //----------------------------------------

    /// @notice Emitted when the time lock duration is changed.
    /// @param oldTimeLock The old time lock duration.
    /// @param newTimeLock The new time lock duration.
    event TimeLockUpdated(uint256 oldTimeLock, uint256 newTimeLock);

    /// @notice Emitted when a user requests to unlock assets.
    /// @param id The ID of the request.
    /// @param user The user that requested the unlock.
    event RequestedUnlocking(uint256 id, address user, uint256 amount);

    /// @notice Emitted when a user withdraws assets
    /// @param id The ID of the request
    /// @param user The user that withdrew the assets
    /// @param amount The amount of underlying assets withdrawn for the user
    /// @param slashAmount The amount of underlying assets slashed for the fee receiver
    event Withdraw(uint256 id, address user, uint256 amount, uint256 slashAmount);

    /// @notice Emitted when a user emergency withdraws assets.
    /// @param user The user that withdrew the assets.
    /// @param amount The amount of assets withdrawn.
    event EmergencyWithdraw(address user, uint256 amount);

    /// @notice Emitted when a user deposits assets
    /// @param user The user that deposited the assets.
    /// @param amount The amount of assets deposited.
    event Deposited(address user, uint256 amount);

    /// @notice Emitted when a user cancels a withdrawal request.
    /// @param id The ID of the request.
    /// @param user The user that cancelled the request.
    /// @param amount The amount of assets cancelled.
    event CancelledWithdrawalRequest(uint256 id, address user, uint256 amount);

    /// @notice Emitted when the fee receiver is updated.
    /// @param newFeeReceiver The new fee receiver.
    event FeeReceiverUpdated(address newFeeReceiver);

    /// @notice Emitted when the start penalty percentage is updated.
    /// @param oldPercentage The old penalty percentage.
    /// @param newPercentage The new penalty percentage.
    event StartPenaltyPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Thrown when the time lock duration is out of range.
    error TimelockOutOfRange(uint256 attemptedTimelockDuration);
    /// @notice Thrown when a user tries to cancel a withdrawal request that is not in the unlocking state.
    error CannotCancelWithdrawalRequest(uint256 reqId);
    /// @notice Thrown when a user tries to withdraw assets that are not in the unlocking state.
    error CannotWithdraw(uint256 reqId);
    /// @notice Thrown when a user tries to withdraw assets that are not yet unlocked.
    error CannotWithdrawYet(uint256 reqId);
    /// @notice Thrown when the percentage is out of range.
    error PercentageOutOfRange(uint256 attemptedPercentage);

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Construct a new TimeLockedERC20 contract
    /// @param _name The name of the token
    /// @param _symbol The symbol of the token.
    /// @param _underlying The underlying that is being locked.
    /// @param _timeLockDuration The duration of the time lock.
    constructor(
        string memory _name,
        string memory _symbol,
        address _underlying,
        address _feeReceiver,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration
    )
        ERC20Permit(_name)
        ERC20(_name, _symbol)
        AccessManaged(_accessManager)
    {
        if (_timeLockDuration < MIN_TIMELOCK_DURATION || _timeLockDuration > MAX_TIMELOCK_DURATION) {
            revert TimelockOutOfRange(_timeLockDuration);
        }
        if (_startPenaltyPercentage > MAX_PENALTY_PERCENTAGE) {
            revert PercentageOutOfRange(_startPenaltyPercentage);
        }

        feeReceiver = _feeReceiver;
        underlying = IERC20(_underlying);
        timeLockDuration = _timeLockDuration;
        startPenaltyPercentage = _startPenaltyPercentage;
    }

    //-------------------------------------------
    // External functions
    //-------------------------------------------

    /// @notice Deposit assets into the contract and mint the equivalent amount of tokens.
    /// @param _assetAmount The amount of assets to deposit.
    function deposit(uint256 _assetAmount) external virtual whenNotPaused nonReentrant {
        underlying.safeTransferFrom(msg.sender, address(this), _assetAmount);
        _deposit(_assetAmount);
    }

    /// @notice Deposit assets into the contract using ERC20Permit and mint the equivalent amount of tokens
    /// @param _assetAmount The amount of assets to deposit
    /// @param _deadline The deadline for the permit.
    /// @param _v The v value of the permit signature.
    /// @param _r The r value of the permit signature.
    /// @param _s The s value of the permit signature.
    function depositWithPermit(
        uint256 _assetAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        whenNotPaused
        nonReentrant
    {
        // @dev using try catch to avoid reverting the transaction in case of front-running
        try IERC20Permit(address(underlying)).permit(msg.sender, address(this), _assetAmount, _deadline, _v, _r, _s) {
        } catch { }
        underlying.safeTransferFrom(msg.sender, address(this), _assetAmount);
        _deposit(_assetAmount);
    }

    /// @notice Withdraw multiple withdrawal requests.
    /// @param _ids The IDs of the withdrawal requests to withdraw.
    function withdraw(uint256[] calldata _ids) external nonReentrant {
        uint256 totalAmountWithdrawn;
        uint256 totalFeeAmount;
        uint256 i = 0;
        for (; i < _ids.length; ++i) {
            (uint256 amountWithdrawn, uint256 feeAmount) = _withdraw(_ids[i]);
            totalAmountWithdrawn += amountWithdrawn;
            totalFeeAmount += feeAmount;
        }
        unlockingAssets = unlockingAssets - totalAmountWithdrawn - totalFeeAmount;
        if (totalFeeAmount > 0) {
            underlying.safeTransfer(feeReceiver, totalFeeAmount);
        }
        underlying.safeTransfer(msg.sender, totalAmountWithdrawn);
    }

    /// @notice Allow users to emergency withdraw assets without penalties.
    /// @dev This function can only be called when the contract is paused.
    /// @param _unlockingAmount The amount of assets to unlock.
    function emergencyWithdraw(uint256 _unlockingAmount) external whenPaused nonReentrant {
        _burn(msg.sender, _unlockingAmount);
        emit EmergencyWithdraw(msg.sender, _unlockingAmount);
        underlying.safeTransfer(msg.sender, _unlockingAmount);
    }

    /// @notice Request to withdraw assets from the contract.
    /// @param _unlockingAmount The amount of assets to unlock.
    function requestWithdraw(uint256 _unlockingAmount) external {
        _burn(msg.sender, _unlockingAmount);

        uint256 id = userVsNextID[msg.sender]++;
        WithdrawalRequest storage request = userVsWithdrawals[msg.sender][id];

        request.amount = _unlockingAmount;
        request.requestTime = uint64(block.timestamp);
        request.releaseTime = uint64(block.timestamp) + timeLockDuration;
        request.status = WITHDRAW_STATUS.UNLOCKING;

        unlockingAssets += _unlockingAmount;

        emit RequestedUnlocking(id, msg.sender, _unlockingAmount);
    }

    /// @notice Cancel multiple withdrawal requests.
    /// @param _ids The IDs of the withdrawal requests to cancel.
    function cancelWithdrawalRequests(uint256[] calldata _ids) external whenNotPaused {
        uint256 i = 0;
        for (; i < _ids.length; ++i) {
            _cancelWithdrawalRequest(_ids[i]);
        }
    }

    /// @notice This is for off-chain use, it finds any locked IDs in the specified range.
    /// @param _user The user to find the unlocking IDs for.
    /// @param _start The ID to start looking from.
    /// @param _startFromEnd Whether to start from the end.
    /// @param _countToCheck The number of IDs to check.
    /// @return ids The IDs of the unlocking requests.
    function findUnlockingIDs(
        address _user,
        uint256 _start,
        bool _startFromEnd,
        uint16 _countToCheck
    )
        external
        view
        returns (uint256[] memory ids)
    {
        uint256 nextId = userVsNextID[_user];

        if (_start >= nextId) return ids;
        if (_startFromEnd) _start = nextId - _start;
        uint256 end = _start + uint256(_countToCheck);
        if (end > nextId) end = nextId;

        mapping(uint256 => WithdrawalRequest) storage withdrawals = userVsWithdrawals[_user];

        ids = new uint256[](end - _start);
        uint256 length = 0;
        uint256 id = _start;
        // Nothing in here can overflow so disable the checks for the loop.
        unchecked {
            for (; id < end; ++id) {
                if (withdrawals[id].status == WITHDRAW_STATUS.UNLOCKING) {
                    ids[length++] = id;
                }
            }
        }

        // Need to force the array length to the correct value using assembly.
        assembly {
            mstore(ids, length)
        }
    }

    //-------------------------------------------
    // AccessManaged functions
    //-------------------------------------------

    /// @notice Allow the AccessManager to update the time lock duration.
    /// @param _newTimeLockDuration The new time lock duration.
    function updateTimeLockDuration(uint64 _newTimeLockDuration) external restricted {
        if (_newTimeLockDuration < MIN_TIMELOCK_DURATION || _newTimeLockDuration > MAX_TIMELOCK_DURATION) {
            revert TimelockOutOfRange(_newTimeLockDuration);
        }
        emit TimeLockUpdated(timeLockDuration, _newTimeLockDuration);
        timeLockDuration = _newTimeLockDuration;
    }

    /// @notice Allow the AccessManager to update the time lock duration.
    /// @param _newStartPenaltyPercentage The new time lock duration.
    function updateStartPenaltyPercentage(uint256 _newStartPenaltyPercentage) external restricted {
        if (_newStartPenaltyPercentage > MAX_PENALTY_PERCENTAGE) {
            revert PercentageOutOfRange(_newStartPenaltyPercentage);
        }
        emit StartPenaltyPercentageUpdated(startPenaltyPercentage, _newStartPenaltyPercentage);
        startPenaltyPercentage = _newStartPenaltyPercentage;
    }

    /// @notice Allow the AccessManager to update the fee receiver address.
    /// @param _newFeeReceiver The new fee receiver.
    function updateFeeReceiver(address _newFeeReceiver) external restricted {
        emit FeeReceiverUpdated(_newFeeReceiver);
        feeReceiver = _newFeeReceiver;
    }

    /// @notice Allow AccessManager to pause the contract.
    /// @dev This function can only be called by the AccessManager.
    function pause() external restricted {
        _pause();
    }

    /// @notice Allow AccessManager to unpause the contract.
    /// @dev This function can only be called by the AccessManager.
    function unpause() external restricted {
        _unpause();
    }

    //-------------------------------------------
    // Private/Internal functions
    //-------------------------------------------

    /// @notice Deposit assets into the contract and mint the equivalent amount of tokens.
    /// @param _assetAmount The amount of assets to deposit.
    function _deposit(uint256 _assetAmount) internal {
        emit Deposited(msg.sender, _assetAmount);
        _mint(msg.sender, _assetAmount);
    }

    /// @notice Withdraw assets from the contract
    /// @param _id The ID of the withdrawal request.
    /// @return withdrawAmount The amount of assets user received.
    /// @return slashAmount The amount of assets that were slashed.
    function _withdraw(uint256 _id) internal returns (uint256 withdrawAmount, uint256 slashAmount) {
        WithdrawalRequest storage request = userVsWithdrawals[msg.sender][_id];

        if (request.status != WITHDRAW_STATUS.UNLOCKING) {
            revert CannotWithdraw(_id);
        }

        slashAmount = _calculateFee(request.amount, request.requestTime, request.releaseTime);
        withdrawAmount = request.amount - slashAmount;
        request.status = WITHDRAW_STATUS.RELEASED;

        emit Withdraw(_id, msg.sender, withdrawAmount, slashAmount);
    }

    /// @notice Cancel a withdrawal request.
    /// @param _id The ID of the withdrawal request.
    function _cancelWithdrawalRequest(uint256 _id) internal {
        WithdrawalRequest storage request = userVsWithdrawals[msg.sender][_id];
        if (request.status != WITHDRAW_STATUS.UNLOCKING) {
            revert CannotCancelWithdrawalRequest(_id);
        }
        request.status = WITHDRAW_STATUS.CANCELLED;

        uint256 _assetAmount = request.amount;
        unlockingAssets -= _assetAmount;

        emit CancelledWithdrawalRequest(_id, msg.sender, _assetAmount);

        _mint(msg.sender, _assetAmount);
    }

    /// @notice Calculate the fee amount that will be slashed from the withdrawal amount.
    /// @dev The fee amount is calculated based on the time left until the release time.
    /// @param _amount The total amount of assets user should withdraw.
    /// @param _requestTime The time the user requested the withdrawal.
    /// @param _releaseTime The time the user can withdraw the assets.
    /// @return feeAmount The amount of assets that will be slashed.
    function _calculateFee(
        uint256 _amount,
        uint256 _requestTime,
        uint256 _releaseTime
    )
        internal
        view
        returns (uint256 feeAmount)
    {
        if (block.timestamp >= _releaseTime) return 0;
        uint256 timeLeft = _releaseTime - block.timestamp;
        uint256 lockDuration = _releaseTime - _requestTime;
        uint256 feePercentage = startPenaltyPercentage.mulDivUp(timeLeft, lockDuration);
        feeAmount = _amount.wadMulUp(feePercentage);
    }
}
