// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract SideChainFeeCollector_Pause_Integrations_Test is Integrations_Test {
    function test_SideChainFeeCollector_Pause() external {
        vm.startPrank(users.admin);
        vm.expectEmit(address(sideChainFeeCollector));
        emit Pausable.Paused(users.admin);
        sideChainFeeCollector.pause();
        assertTrue(sideChainFeeCollector.paused());
    }

    function test_SideChainFeeCollector_Pause_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        sideChainFeeCollector.pause();
    }
}
