// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { console2 } from "@forge-std/console2.sol";
import { Test } from "@forge-std/Test.sol";

import "./helpers/Deploys.sol";
import "./helpers/Defaults.sol";
import "./helpers/Assertions.sol";
import "./helpers/Utils.sol";
import "./helpers/SigUtils.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Deploys, Assertions, Defaults, Utils {
    //----------------------------------------
    // Set-up
    //----------------------------------------
    function setUp() public virtual {
        // Roll the blockchain forward to Monday 1 January 2024 12:00:00 GMT.
        skip(1_704_110_400);

        // Deploy PAR token contract.
        par = _deployERC20Mock("PAR", "PAR", 18);
        // Deploy paUSD token contract.
        paUSD = _deployERC20Mock("paUSD", "paUSD", 18);
        // Deploy bridgeable token mock contract.
        bridgeableTokenMock = _deployBridgeableTokenMock(address(par));

        // Create users for testing.
        users = Users({
            admin: _createUser("Admin", true),
            daoTreasury: _createUser("Dao Treasury", false),
            insuranceFundMultisig: _createUser("Insurance Fund Multisig", false),
            alice: _createUser("Alice", true),
            bob: _createUser("Bob", true),
            hacker: _createUser("Hacker", true)
        });

        accessManager = _deployAccessManager(users.admin);
    }

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function _createUser(string memory name, bool setTokenBalance) internal returns (address payable user) {
        user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: INITIAL_BALANCE });
        if (setTokenBalance) {
            par.mint(user, INITIAL_BALANCE);
            paUSD.mint(user, INITIAL_BALANCE);
        }
    }

    function _signPermitData(
        uint256 privateKey,
        address spender,
        uint256 amount,
        address token
    )
        internal
        view
        returns (uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    {
        address owner = vm.addr(privateKey);
        deadline = block.timestamp + 1 days;
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: owner,
            spender: spender,
            value: amount,
            nonce: IERC20Permit(token).nonces(owner),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (v, r, s) = vm.sign(privateKey, digest);
    }
}