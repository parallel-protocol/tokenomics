// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Users } from "./Types.sol";

/// @notice Contract with default values used throughout the tests.
contract Defaults {
    //----------------------------------------
    // Constants
    //----------------------------------------

    uint256 public constant INITIAL_BALANCE = 100_000e18;
    uint256 public constant DEFAULT_MINT_AMOUNT = 100e18;
    uint256 public constant INIT_PRICE = 1000e18;
    uint256 public constant MIN_INIT_PRICE = 1e18;
    uint256 public constant EPOCH_DURATION = 14 days;
    uint256 public constant PRICE_MULTIPLIER = 2e18;

    uint32 public constant mainEid = 1;

    //----------------------------------------
    // State variables
    //----------------------------------------

    Users internal users;
}
