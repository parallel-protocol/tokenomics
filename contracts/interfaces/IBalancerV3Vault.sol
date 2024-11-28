// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBalancerVault {
    enum AddLiquidityKind {
        PROPORTIONAL,
        UNBALANCED,
        SINGLE_TOKEN_EXACT_OUT,
        DONATION,
        CUSTOM
    }

    struct AddLiquidityParams {
        address pool;
        address to;
        uint256[] maxAmountsIn;
        uint256 minBptAmountOut;
        AddLiquidityKind kind;
        bytes userData;
    }

    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (uint256[] memory amountsIn, uint256 bptAmountOut, bytes memory returnData);

    enum RemoveLiquidityKind {
        PROPORTIONAL,
        SINGLE_TOKEN_EXACT_IN,
        SINGLE_TOKEN_EXACT_OUT,
        CUSTOM
    }

    struct RemoveLiquidityParams {
        address pool;
        address from;
        uint256 maxBptAmountIn;
        uint256[] minAmountsOut;
        RemoveLiquidityKind kind;
        bytes userData;
    }

    function removeLiquidity(RemoveLiquidityParams memory params)
        external
        returns (uint256 bptAmountIn, uint256[] memory amountsOut, bytes memory returnData);
}
