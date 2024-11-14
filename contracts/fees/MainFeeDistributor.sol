// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./FeeCollectorCore.sol";

import { IBridgeableToken } from "contracts/interfaces/IBridgeableToken.sol";

contract MainFeeDistributor is FeeCollectorCore {
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    address[] public payees;

    IERC20 public bridgeableToken;

    constructor(
        address _bridgeableToken,
        address _accessManager,
        address _feeToken
    )
        FeeCollectorCore(_accessManager, _feeToken)
    {
        bridgeableToken = IERC20(_bridgeableToken);
    }

    /// @notice swap Lz-PAR to PAR if limit not reached.
    /// @dev LzPar doesn't need approval to be transfered.
    function swapLzParToPar() external {
        IBridgeableToken(address(bridgeableToken)).swapLzTokenToPrincipalToken(
            bridgeableToken.balanceOf(address(this))
        );
    }

    function release() external { }
}
