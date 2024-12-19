// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IBalancerVault } from "contracts/interfaces/IBalancerV3Vault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "./ERC20Mock.sol";

contract BalancerVaultMock is IBalancerVault {
    address[2] public tokens;
    uint256[2] public balances;
    ERC20Mock public bpt;

    constructor(address[2] memory _tokens, address _bpt) {
        tokens = _tokens;
        bpt = ERC20Mock(_bpt);
    }

    function setBalances(uint256[2] memory _balances) public {
        balances = _balances;
    }

    function addLiquidity(AddLiquidityParams memory params)
        external
        override
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData)
    {
        IERC20(tokens[0]).transferFrom(msg.sender, address(this), params.maxAmountsIn[0]);
        IERC20(tokens[1]).transferFrom(msg.sender, address(this), params.maxAmountsIn[1]);
        bpt.mint(params.to, params.minBptAmountOut);
        return (params.maxAmountsIn, params.minBptAmountOut, params.userData);
    }

    function removeLiquidity(RemoveLiquidityParams memory params)
        external
        override
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData)
    {
        bpt.burn(msg.sender, params.maxBptAmountIn);
        IERC20(tokens[0]).transfer(params.from, params.minAmountsOut[0]);
        IERC20(tokens[1]).transfer(params.from, params.minAmountsOut[1]);
        return (params.maxBptAmountIn, params.minAmountsOut, params.userData);
    }
}
