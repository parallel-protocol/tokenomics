// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title FeeCollectorCore
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Abstract contract that handle the commun logic between SideChainFeeCollector and MainFeeDistributor
/// contracts.
abstract contract FeeCollectorCore is AccessManaged, Pausable {
    using SafeERC20 for IERC20;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The fee token contract.
    IERC20 public immutable feeToken;

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Thrown when the amount to release is zero.
    error NothingToRelease();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    ///@notice FeeCollectorCore constructor.
    ///@param _accessManager address of the AccessManager contract.
    ///@param _feeToken address of the fee token.
    constructor(address _accessManager, address _feeToken) AccessManaged(_accessManager) {
        feeToken = IERC20(_feeToken);
    }

    //-------------------------------------------
    // AccessManaged functions
    //-------------------------------------------

    /// @notice Allow to withdraw token own by the contract.
    /// @dev This function can only be called by the accessManager.
    /// @param _token The address of the ERC20 token to rescue.
    /// @param _to The address of the recipient.
    /// @param _amount The amount of tokens to rescue.
    function recoverToken(address _token, uint256 _amount, address _to) external restricted {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /// @notice Allow AccessManager to pause the contract.
    /// @dev This function can only be called by an authorized() address.
    function pause() external restricted {
        _pause();
    }

    /// @notice Allow AccessManager to unpause the contract.
    /// @dev This function can only be called by an authorized() address.
    function unpause() external restricted {
        _unpause();
    }
}
