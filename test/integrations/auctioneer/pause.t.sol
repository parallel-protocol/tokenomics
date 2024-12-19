// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract Auctioneer_Pause_Integrations_Test is Integrations_Test {
    function test_Auctioneer_Pause() external {
        vm.startPrank(users.admin.addr);
        vm.expectEmit(address(auctioneer));
        emit Pausable.Paused(users.admin.addr);
        auctioneer.pause();
        assertTrue(auctioneer.paused());
    }

    function test_Auctioneer_Pause_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        auctioneer.pause();
    }
}
