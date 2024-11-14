// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/MainChainIntegrations.t.sol";

contract Auctioneer_RecoverToken_Integrations_Test is MainChainIntegrations_Test {
    function setUp() public override {
        super.setUp();
        par.mint(address(auctioneer), INITIAL_BALANCE);
    }

    function test_Auctioneer_RecoverToken() public {
        vm.startPrank(users.admin);

        auctioneer.recoverToken(address(par), INITIAL_BALANCE, users.admin);

        assertEq(par.balanceOf(address(auctioneer)), 0);
        assertEq(par.balanceOf(users.admin), INITIAL_BALANCE * 2);
    }

    function test_Auctioneer_RecoverToken_RevertWhen_CallerNotAuthorized() public {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        auctioneer.recoverToken(address(par), INITIAL_BALANCE, users.hacker);
    }
}
