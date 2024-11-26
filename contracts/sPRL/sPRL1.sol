// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimeLockPenaltyERC20, ERC20, ERC20Permit } from "./TimeLockPenaltyERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";

contract sPRL1 is TimeLockPenaltyERC20, ERC20Votes {
    string constant NAME = "Social Escrowed PRL";
    string constant SYMBOL = "sPRL1";

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

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
