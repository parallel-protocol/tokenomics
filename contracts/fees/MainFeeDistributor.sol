// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IBridgeableToken } from "contracts/interfaces/IBridgeableToken.sol";

import { FeeCollectorCore, ReentrancyGuard, IERC20, SafeERC20 } from "./FeeCollectorCore.sol";

/// @title MainFeeDistributor
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Handles the reception and the distribution of fee tokens.

contract MainFeeDistributor is FeeCollectorCore {
    using SafeERC20 for IERC20;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice token bridgeableToken contract
    IERC20 public bridgeableToken;
    /// @notice Total shares of the fee recipients.
    uint256 public totalShares;
    /// @notice Mapping of the shares of the fee recipients.
    mapping(address => uint256) public shares;
    /// @notice Array of the fee recipients.
    address[] public feeRecipients;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    /// @notice Emitted when a new fee recipient is added to the fee distribution.
    /// @param feeRecipient The address of the fee recipient.
    /// @param shares The number of shares assigned to the fee recipient.
    event FeeRecipientAdded(address feeRecipient, uint256 shares);

    /// @notice Emitted when fees are released.
    /// @param income The amount of income released.
    /// @param releasedAt The timestamp when the fees were released.
    event FeeReleased(uint256 income, uint256 releasedAt);

    /// @notice Emitted when lzToken are swapped.
    /// @param amount The amount of lzToken swapped.
    event LzTokenSwapped(uint256 amount);

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Thrown when the fee recipient address is zero.
    error FeeRecipientZeroAddress();
    /// @notice Thrown when the shares are zero.
    error SharesIsZero();
    /// @notice Thrown when the fee recipient is already added.
    error FeeRecipientAlreadyAdded();
    /// @notice Thrown when there is no fee recipients.
    error NoFeeRecipients();
    /// @notice Thrown when the array length mismatch.
    error ArrayLengthMismatch();
    /// @notice Thrown when the maximum swap amount is zero.
    error MaxSwappableAmountIsZero();
    /// @notice Thrown when the lzToken balance is zero.
    error NothingToSwap();
    /// @notice Thrown when the lzToken balance is not zero
    /// during bridgeableToken contract address update.
    error NeedToSwapAllLzTokenFirst();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    ///@notice MainFeeDistributor constructor.
    ///@param _bridgeableToken address of the bridgeable token.
    ///@param _accessManager address of the AccessManager contract.
    ///@param _feeToken address of the fee token.
    constructor(
        address _accessManager,
        address _bridgeableToken,
        address _feeToken
    )
        FeeCollectorCore(_accessManager, _feeToken)
    {
        bridgeableToken = IERC20(_bridgeableToken);
    }

    //-------------------------------------------
    // External functions
    //-------------------------------------------

    /// @notice Release the fees to the fee recipients according to their shares.
    function release() external nonReentrant {
        uint256 income = feeToken.balanceOf(address(this));
        if (income == 0) revert NothingToRelease();
        if (feeRecipients.length == 0) revert NoFeeRecipients();
        for (uint256 i = 0; i < feeRecipients.length; i++) {
            address feeRecipient = feeRecipients[i];
            _release(income, feeRecipient);
        }
    }

    /// @notice swap Lz-Token to Token if limit not reached.
    /// @dev lzToken doesn't need approval to be transfered.
    function swapLzToken() external nonReentrant {
        uint256 balance = bridgeableToken.balanceOf(address(this));
        if (balance == 0) revert NothingToSwap();

        uint256 maxSwapAmount = IBridgeableToken(address(bridgeableToken)).getMaxMintableAmount();
        if (maxSwapAmount == 0) revert MaxSwappableAmountIsZero();

        uint256 swapAmount = balance > maxSwapAmount ? maxSwapAmount : balance;

        IBridgeableToken(address(bridgeableToken)).swapLzTokenToPrincipalToken(swapAmount);

        emit LzTokenSwapped(swapAmount);
    }

    function getFeeRecipients() external view returns (address[] memory) {
        return feeRecipients;
    }

    //-------------------------------------------
    // AccessManaged functions
    //-------------------------------------------

    /// @notice Allow to update the fees recipients list and shares.
    /// @dev This function can only be called by the accessManager.
    /// @param _feeRecipients The list of the fee recipients.
    /// @param _shares The list of the shares assigned to the fee recipients.
    function updateFeeRecipients(address[] memory _feeRecipients, uint256[] memory _shares) public restricted {
        if (_feeRecipients.length == 0) revert NoFeeRecipients();
        if (_feeRecipients.length != _shares.length) revert ArrayLengthMismatch();
        delete feeRecipients;

        uint256 _totalShares = 0;
        uint256 i = 0;
        for (; i < _feeRecipients.length; ++i) {
            _totalShares += _addFeeRecipient(_feeRecipients[i], _shares[i]);
        }
        totalShares = _totalShares;
    }

    /// @notice Allow to update the bridgeable token.
    /// @dev This function can only be called by the accessManager.
    /// @param _newBridgeableToken The address of the bridgeable token.
    function updateBridgeableToken(address _newBridgeableToken) external restricted {
        if (bridgeableToken.balanceOf(address(this)) > 0) revert NeedToSwapAllLzTokenFirst();
        bridgeableToken = IERC20(_newBridgeableToken);
    }

    //-------------------------------------------
    // Internal/Private functions
    //-------------------------------------------

    /// @notice Release the fees to the fee recipient.
    /// @param _totalIncomeToDistribute The total amount of income received.
    /// @param _feeRecipient The address of the fee recipient.
    function _release(uint256 _totalIncomeToDistribute, address _feeRecipient) internal {
        uint256 amount = _totalIncomeToDistribute * shares[_feeRecipient] / totalShares;
        feeToken.safeTransfer(_feeRecipient, amount);
    }

    /// @notice Add a new fee recipient.
    /// @param _feeRecipient The address of the fee recipient.
    /// @param _shares The number of shares assigned to the fee recipient.
    function _addFeeRecipient(address _feeRecipient, uint256 _shares) internal returns (uint256) {
        if (_feeRecipient == address(0)) revert FeeRecipientZeroAddress();
        if (_shares == 0) revert SharesIsZero();

        feeRecipients.push(_feeRecipient);
        shares[_feeRecipient] = _shares;
        emit FeeRecipientAdded(_feeRecipient, _shares);
        return _shares;
    }
}
