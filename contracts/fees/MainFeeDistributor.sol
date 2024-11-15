// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./FeeCollectorCore.sol";

import { IBridgeableToken } from "contracts/interfaces/IBridgeableToken.sol";

/// @title MainFeeDistributor
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Handles the reception and the distribution of fee tokens.
contract MainFeeDistributor is FeeCollectorCore {
    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice token bridgeableToken contract
    IERC20 public bridgeableToken;
    /// @notice Total shares of the payees.
    uint256 public totalShares;
    /// @notice Mapping of the shares of the payees.
    mapping(address => uint256) public shares;
    /// @notice Array of the payees.
    address[] public payees;

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    ///@notice MainFeeDistributor constructor.
    ///@param _bridgeableToken address of the bridgeable token.
    ///@param _accessManager address of the AccessManager contract.
    ///@param _feeToken address of the fee token.
    constructor(
        address _bridgeableToken,
        address _accessManager,
        address _feeToken
    )
        FeeCollectorCore(_accessManager, _feeToken)
    {
        bridgeableToken = IERC20(_bridgeableToken);
    }

    //-------------------------------------------
    // External functions
    //-------------------------------------------

    /// @notice swap Lz-Token to Token if limit not reached.
    /// @dev lzToken doesn't need approval to be transfered.
    function swapLzTokenToToken() external {
        IBridgeableToken(address(bridgeableToken)).swapLzTokenToPrincipalToken(
            bridgeableToken.balanceOf(address(this))
        );
    }

    function release() external { }

    //-------------------------------------------
    // AccessManaged functions
    //-------------------------------------------

    /// @notice Allow to update the bridgeable token.
    /// @dev This function can only be called by the accessManager.
    /// @param _newBridgeableToken The address of the bridgeable token.
    function updateBridgeableToken(address _newBridgeableToken) external restricted {
        bridgeableToken = IERC20(_newBridgeableToken);
    }
}
