// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimeLockPenaltyERC20, ERC20, ERC20Permit } from "./TimeLockPenaltyERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title sPRL1
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice sPRL1 is a staking contract that allows users to deposit PRL assets.
contract sPRL1 is TimeLockPenaltyERC20, ERC20Votes {
    string constant NAME = "Stake PRL";
    string constant SYMBOL = "sPRL1";

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Deploy the sPRL1 contract.
    /// @param _underlying The underlying PRL token.
    /// @param _feeReceiver The address to receive the fees.
    /// @param _accessManager The address of the AccessManager.
    /// @param _startPenaltyPercentage The percentage of the penalty fee.
    /// @param _timeLockDuration The time lock duration.
    constructor(
        address _underlying,
        address _feeReceiver,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration
    )
        TimeLockPenaltyERC20(
            NAME,
            SYMBOL,
            _underlying,
            _feeReceiver,
            _accessManager,
            _startPenaltyPercentage,
            _timeLockDuration
        )
    { }

    //-------------------------------------------
    // Overrides
    //-------------------------------------------

    /// @notice Update the balances of the token.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to transfer.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @notice Get the nonce for an address.
    /// @param owner The address to get the nonce for.
    /// @return The nonce for the address.
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
