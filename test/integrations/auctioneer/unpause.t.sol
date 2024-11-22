// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract Auctioneer_UnPause_Integrations_Test is Integrations_Test {
    function setUp() public virtual override {
        super.setUp();
        vm.startPrank(users.admin.addr);
        auctioneer.pause();
    }

    function test_Auctioneer_UnPause() external {
        vm.expectEmit(address(auctioneer));
        emit Pausable.Unpaused(users.admin.addr);
        auctioneer.unpause();
        assertFalse(auctioneer.paused());
    }

    function test_Auctioneer_UnPause_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        auctioneer.unpause();
    }
}
