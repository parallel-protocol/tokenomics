// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimeLockPenaltyERC20, IERC20, ERC20, IERC20Permit, ERC20Permit } from "./TimeLockPenaltyERC20.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { IBalancerVault } from "contracts/interfaces/IBalancerV3Vault.sol";
import { IAuraBoosterLite, IAuraRewardPool, IAuraStashToken } from "contracts/interfaces/IAura.sol";
import { IWrappedNative } from "contracts/interfaces/IWrappedNative.sol";

contract sPRL2 is TimeLockPenaltyERC20, ERC20Votes {
    using Address for address payable;

    string constant NAME = "Stake 20WETH-80PRL Aura Deposit Vault";
    string constant SYMBOL = "sPRL2";

    uint256 constant AURA_POOL_PID = 19;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The Balancer V3 vault.
    IBalancerVault public immutable BALANCER_VAULT;
    /// @notice The Aura Booster Lite contract.
    IAuraBoosterLite public immutable AURA_BOOSTER_LITE;
    /// @notice The Aura Vault contract.
    IAuraRewardPool public immutable AURA_VAULT;
    /// @notice The PRL token.
    IERC20 public immutable PRL;
    /// @notice The WETH token.
    IWrappedNative public immutable WETH;
    /// @notice The BPT token.
    IERC20 public immutable BPT;
    /// @notice Whether the pair is reversed.
    bool public immutable isReversedBalancerPair;

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Error thrown when the deposit fails.
    error DepositFailed();

    /// @notice Error thrown when the insufficient assets are received.
    error InsufficientAssetsReceived();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Constructor for the sPRL2 contract.
    /// @param _auraBPT The address of the Aura BPT token.
    /// @param _feeReceiver The address of the fee receiver.
    /// @param _accessManager The address of the access manager.
    /// @param _startPenaltyPercentage The start penalty percentage.
    /// @param _timeLockDuration The time lock duration.
    /// @param _balancerVault The address of the Balancer V3 vault.
    /// @param _auraBoosterLite The address of the Aura Booster Lite contract.
    /// @param _auraVault The address of the Aura Vault contract.
    /// @param _balancerBPT The address of the Balancer BPT token.
    /// @param _prl The address of the PRL token.
    /// @param _weth The address of the WETH token.
    constructor(
        address _auraBPT,
        address _feeReceiver,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration,
        IBalancerVault _balancerVault,
        IAuraBoosterLite _auraBoosterLite,
        IAuraRewardPool _auraVault,
        IERC20 _balancerBPT,
        IERC20 _prl,
        IWrappedNative _weth
    )
        TimeLockPenaltyERC20(
            NAME,
            SYMBOL,
            _auraBPT,
            _feeReceiver,
            _accessManager,
            _startPenaltyPercentage,
            _timeLockDuration
        )
    {
        BALANCER_VAULT = _balancerVault;
        AURA_BOOSTER_LITE = _auraBoosterLite;
        AURA_VAULT = _auraVault;
        PRL = _prl;
        WETH = _weth;
        BPT = _balancerBPT;
        isReversedBalancerPair = address(_weth) > address(_prl);
    }

    //-------------------------------------------
    // External Functions
    //-------------------------------------------

    /// @notice Deposit PRL and WETH.
    /// @param _maxPrlAmount The maximum amount of PRL to deposit.
    /// @param _maxWethAmount The maximum amount of WETH to deposit.
    /// @param _exactBptAmount The exact amount of BPT to mint.
    /// @param _deadline The deadline for the permit.
    /// @param _v The v parameter for the permit.
    /// @param _r The r parameter for the permit.
    /// @param _s The s parameter for the permit.
    function depositPRLAndWeth(
        uint256 _maxPrlAmount,
        uint256 _maxWethAmount,
        uint256 _exactBptAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s);

        PRL.transferFrom(msg.sender, address(this), _maxPrlAmount);
        WETH.transferFrom(msg.sender, address(this), _maxWethAmount);

        (amountsIn, bptAmount) = _joinPool(_maxPrlAmount, _maxWethAmount, _exactBptAmount, true);

        _deposit(bptAmount);
    }

    /// @notice Deposit PRL and ETH.
    /// @param _maxPrlAmount The maximum amount of PRL to deposit.
    /// @param _exactBptAmount The exact amount of BPT to mint.
    /// @param _deadline The deadline for the permit.
    /// @param _v The v parameter for the permit.
    /// @param _r The r parameter for the permit.
    /// @param _s The s parameter for the permit.
    function depositPRLAndEth(
        uint256 _maxPrlAmount,
        uint256 _exactBptAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        payable
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s);

        PRL.transferFrom(msg.sender, address(this), _maxPrlAmount);

        (amountsIn, bptAmount) = _joinPool(_maxPrlAmount, msg.value, _exactBptAmount, true);

        _deposit(bptAmount);
    }

    /// @notice Withdraw PRL and WETH for a single request.
    /// @param _requestId The request ID to withdraw from.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minEthAmount The minimum amount of wETH to receive.
    /// @return prlAmount The amount of PRL received.
    /// @return wethAmount The amount of wETH received.
    function withdrawPRLAndWeth(
        uint256 _requestId,
        uint256 _minPrlAmount,
        uint256 _minEthAmount
    )
        external
        returns (uint256 prlAmount, uint256 wethAmount)
    {
        (uint256 bptAmount,) = _withdraw(_requestId);
        (prlAmount, wethAmount) = _exitPool(bptAmount, _minPrlAmount, _minEthAmount);

        PRL.transfer(msg.sender, prlAmount);
        WETH.transfer(msg.sender, wethAmount);
    }

    /// @notice Withdraw PRL and WETH for multiple requests.
    /// @param _requestIds The request IDs to withdraw from.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minEthAmount The minimum amount of ETH to receive.
    /// @return prlAmount The amount of PRL received.
    /// @return wethAmount The amount of wETH received.
    function withdrawPRLAndWethMultiple(
        uint256[] calldata _requestIds,
        uint256 _minPrlAmount,
        uint256 _minEthAmount
    )
        external
        returns (uint256 prlAmount, uint256 wethAmount)
    {
        uint256 totalBptAmount;
        for (uint8 i; i < _requestIds.length; i++) {
            (uint256 bptAmount,) = _withdraw(_requestIds[i]);
            totalBptAmount += bptAmount;
        }

        (prlAmount, wethAmount) = _exitPool(totalBptAmount, _minPrlAmount, _minEthAmount);

        PRL.transfer(msg.sender, prlAmount);
        WETH.transfer(msg.sender, wethAmount);
    }

    /// @notice Withdraw PRL and ETH for a single request.
    /// @param _requestId The request ID to withdraw from.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minEthAmount The minimum amount of ETH to receive.
    /// @return prlAmount The amount of PRL received.
    /// @return ethAmount The amount of ETH received.
    function withdrawPRLAndEth(
        uint256 _requestId,
        uint256 _minPrlAmount,
        uint256 _minEthAmount
    )
        external
        returns (uint256 prlAmount, uint256 ethAmount)
    {
        (uint256 bptAmount,) = _withdraw(_requestId);
        (prlAmount, ethAmount) = _exitPool(bptAmount, _minPrlAmount, _minEthAmount);

        PRL.transfer(msg.sender, prlAmount);

        WETH.withdraw(ethAmount);
        payable(msg.sender).sendValue(ethAmount);
    }

    /// @notice Withdraw PRL and ETH for multiple requests.
    /// @param _requestIds The request IDs to withdraw from.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minEthAmount The minimum amount of ETH to receive.
    /// @return prlAmount The amount of PRL received.
    /// @return ethAmount The amount of ETH received.
    function withdrawPRLAndEthMultiple(
        uint256[] calldata _requestIds,
        uint256 _minPrlAmount,
        uint256 _minEthAmount
    )
        external
        returns (uint256 prlAmount, uint256 ethAmount)
    {
        uint256 totalBptAmount;
        for (uint8 i; i < _requestIds.length; i++) {
            (uint256 bptAmount,) = _withdraw(_requestIds[i]);
            totalBptAmount += bptAmount;
        }

        (prlAmount, ethAmount) = _exitPool(totalBptAmount, _minPrlAmount, _minEthAmount);

        PRL.transfer(msg.sender, prlAmount);

        WETH.withdraw(ethAmount);
        payable(msg.sender).sendValue(ethAmount);
    }

    //-------------------------------------------
    // Internal Functions
    //-------------------------------------------

    /// @notice Join the pool.
    /// @param _maxPrlAmount The maximum amount of PRL to deposit.
    /// @param _maxEthAmount The maximum amount of ETH to deposit.
    /// @param _exactBptAmount The exact amount of BPT to mint.
    /// @param _isEth Whether the ETH is being deposited by the user.
    /// @return amountsIn The amounts of PRL and ETH deposited.
    /// @return bptAmount The amount of BPT received.
    function _joinPool(
        uint256 _maxPrlAmount,
        uint256 _maxEthAmount,
        uint256 _exactBptAmount,
        bool _isEth
    )
        internal
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = _maxEthAmount;
        maxAmountsIn[1] = _maxPrlAmount;

        /// @dev Reverse maxAmountsIn if the pair is reversed
        if (isReversedBalancerPair) {
            (maxAmountsIn[0], maxAmountsIn[1]) = (maxAmountsIn[1], maxAmountsIn[0]);
        }

        /// @dev Set deposit params
        IBalancerVault.AddLiquidityParams memory params = IBalancerVault.AddLiquidityParams({
            pool: address(BPT),
            to: address(this),
            maxAmountsIn: maxAmountsIn,
            minBptAmountOut: _exactBptAmount,
            kind: IBalancerVault.AddLiquidityKind.PROPORTIONAL,
            userData: ""
        });

        /// @dev Approve tokens.
        PRL.approve(address(BALANCER_VAULT), _maxPrlAmount);
        WETH.approve(address(BALANCER_VAULT), _maxEthAmount);

        /// @dev Wrap ETH.
        if (_isEth) {
            WETH.deposit{ value: _maxEthAmount }();
        }

        /// @dev Deposit into Balancer V3
        (amountsIn, bptAmount,) = BALANCER_VAULT.addLiquidity(params);

        /// @dev Deposit into Aura
        if (!AURA_BOOSTER_LITE.deposit(AURA_POOL_PID, bptAmount, true)) revert DepositFailed();

        /// @dev Return any remaining PRL.
        uint256 prlBalanceToReturn = _maxPrlAmount - PRL.balanceOf(address(this));
        if (prlBalanceToReturn > 0) {
            PRL.transfer(msg.sender, prlBalanceToReturn);
        }

        /// @dev Return any remaining WETH.
        uint256 wethBalanceToReturn = _maxEthAmount - WETH.balanceOf(address(this));
        if (wethBalanceToReturn > 0) {
            if (_isEth) {
                WETH.withdraw(wethBalanceToReturn);
                payable(msg.sender).sendValue(wethBalanceToReturn);
            } else {
                WETH.transfer(msg.sender, wethBalanceToReturn);
            }
        }
    }

    /// @notice Exit the pool.
    /// @param _bptAmount The amount of BPT to withdraw.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minEthAmount The minimum amount of ETH to receive.
    /// @return _ethAmount The amount of ETH received.
    /// @return _prlAmount The amount of PRL received.
    function _exitPool(
        uint256 _bptAmount,
        uint256 _minPrlAmount,
        uint256 _minEthAmount
    )
        internal
        returns (uint256 _ethAmount, uint256 _prlAmount)
    {
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = _minEthAmount;
        minAmountsOut[1] = _minPrlAmount;

        if (isReversedBalancerPair) {
            (minAmountsOut[0], minAmountsOut[1]) = (minAmountsOut[1], minAmountsOut[0]);
        }

        IBalancerVault.RemoveLiquidityParams memory params = IBalancerVault.RemoveLiquidityParams({
            pool: address(BPT),
            from: address(this),
            maxBptAmountIn: _bptAmount,
            minAmountsOut: minAmountsOut,
            kind: IBalancerVault.RemoveLiquidityKind.PROPORTIONAL,
            userData: ""
        });

        BPT.approve(address(BALANCER_VAULT), _bptAmount);
        BALANCER_VAULT.removeLiquidity(params);

        _prlAmount = PRL.balanceOf(address(this));
        _ethAmount = WETH.balanceOf(address(this));

        if (_prlAmount < _minPrlAmount || _ethAmount < _minEthAmount) {
            revert InsufficientAssetsReceived();
        }
    }

    /// @notice Claim rewards from Aura Pool and transfer them to the fee receiver.
    function claimRewards() external {
        AURA_VAULT.getReward();
        IERC20 mainRewardToken = IERC20(AURA_VAULT.rewardToken());
        if (mainRewardToken.balanceOf(address(this)) > 0) {
            mainRewardToken.transfer(feeReceiver, mainRewardToken.balanceOf(address(this)));
        }

        uint256 extraRewardsLength = AURA_VAULT.extraRewardsLength();
        if (extraRewardsLength > 0) {
            address[] memory extraRewards = AURA_VAULT.extraRewards();
            uint256 i;
            for (; i < extraRewardsLength; ++i) {
                IERC20 extraRewardToken = IERC20(IAuraStashToken(extraRewards[i]).baseToken());
                if (extraRewardToken.balanceOf(address(this)) > 0) {
                    extraRewardToken.transfer(feeReceiver, extraRewardToken.balanceOf(address(this)));
                }
            }
        }
    }

    /// @notice Allow ETH to be received.
    receive() external payable { }

    //-------------------------------------------
    // Overrides
    //-------------------------------------------

    /// @notice Update the balances of the token.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to transfer.
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @notice Get the nonce for an address.
    /// @param owner The address to get the nonce for.
    /// @return The nonce for the address.
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}