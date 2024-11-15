// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SideChainFeeCollector_Release_Integrations_Test is Integrations_Test {
    using OptionsBuilder for bytes;

    function test_SideChainFeeCollector_release() public {
        par.mint(address(sideChainFeeCollector), INITIAL_BALANCE);
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);
        sideChainFeeCollector.release(options);

        assertEq(par.balanceOf(address(sideChainFeeCollector)), 0);
    }

    function test_SideChainFeeCollector_release_RevertWhen_AmountIsZero() public {
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200_000, 0);

        vm.expectRevert(abi.encodeWithSelector(FeeCollectorCore.NothingToRelease.selector));
        sideChainFeeCollector.release(options);
    }
}
