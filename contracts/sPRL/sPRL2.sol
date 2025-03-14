// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimeLockPenaltyERC20, IERC20, IERC20Permit } from "./TimeLockPenaltyERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IBalancerV3Router } from "contracts/interfaces/IBalancerV3Router.sol";
import { IAuraBoosterLite, IAuraRewardPool } from "contracts/interfaces/IAura.sol";
import { IPermit2 } from "contracts/interfaces/IPermit2.sol";
import { IWrappedNative } from "contracts/interfaces/IWrappedNative.sol";

/// @title sPRL2
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @dev Staked into Aura doesn't credit any erc20 tokens to the contract.
/// @notice sPRL2 is a staking contract that allows users to deposit PRL and WETH into a Balancer V3 pool that is
/// staked into the Aura Pool.
contract sPRL2 is TimeLockPenaltyERC20 {
    using Address for address payable;
    using SafeERC20 for IERC20;

    string constant NAME = "Stake 20WETH-80PRL Aura Deposit Vault";
    string constant SYMBOL = "sPRL2";

    /// @dev Aura Pool PID is hardcoded and must be updated before deploying
    uint256 public constant AURA_POOL_PID = 244;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The configuration parameters for the contract.
    struct BPTConfigParams {
        IBalancerV3Router balancerRouter;
        IAuraBoosterLite auraBoosterLite;
        IAuraRewardPool auraRewardsPool;
        IERC20 balancerBPT;
        IERC20 prl;
        IWrappedNative weth;
        address[] rewardTokens;
        IPermit2 permit2;
    }

    /// @notice The Permit2 contract.
    IPermit2 public immutable PERMIT2;
    /// @notice The Balancer V3 router.
    IBalancerV3Router public immutable BALANCER_ROUTER;
    /// @notice The Aura Booster Lite contract.
    IAuraBoosterLite public immutable AURA_BOOSTER_LITE;
    /// @notice The Aura Rewards Pool contract.
    IAuraRewardPool public immutable AURA_REWARDS_POOL;
    /// @notice The PRL token.
    IERC20 public immutable PRL;
    /// @notice The WETH token.
    IWrappedNative public immutable WETH;
    /// @notice The BPT token.
    IERC20 public immutable BPT;
    /// @notice Whether the pair is reversed.
    bool public immutable isReversedBalancerPair;
    /// @notice The tokens that can be claimed as rewards from the Aura Pool.
    /// @dev This is used to avoid complex logic to know which tokens to forward from the Aura Pool.
    address[] public rewardTokens;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    /// @notice Event emitted when a user withdraws PRL and WETH for multiple requests.
    /// @param requestIds The IDs of the withdrawal requests.
    /// @param user The address of the user.
    /// @param prlAmount The amount of PRL received.
    /// @param wethAmount The amount of WETH received.
    /// @param slashBptAmount The amount of BPT sent to the fee receiver.
    event WithdrawlPRLAndWeth(
        uint256[] requestIds, address user, uint256 prlAmount, uint256 wethAmount, uint256 slashBptAmount
    );

    /// @notice Event emitted when a user withdraws BPT for multiple requests.
    /// @param requestIds The IDs of the withdrawal requests.
    /// @param user The address of the user.
    /// @param bptAmount The amount of BPT received.
    /// @param slashBptAmount The amount of BPT sent to the fee receiver.
    event WithdrawlBPT(uint256[] requestIds, address user, uint256 bptAmount, uint256 slashBptAmount);

    /// @notice Event emitted when the reward tokens are updated.
    /// @param rewardTokens The new reward tokens.
    event RewardTokensUpdated(address[] rewardTokens);

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Error thrown when the deposit fails.
    error AuraDepositFailed();

    /// @notice Error thrown when the reward tokens array is empty.
    error EmptyRewardTokens();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Constructor for the sPRL2 contract.
    /// @param _stakedAuraBPT The address of the Staked Aura BPT token.
    /// @param _feeReceiver The address of the fee receiver.
    /// @param _accessManager The address of the access manager.
    /// @param _startPenaltyPercentage The start penalty percentage.
    /// @param _timeLockDuration The time lock duration.
    /// @param _configParams The configuration parameters for the contract.
    constructor(
        address _stakedAuraBPT,
        address _feeReceiver,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration,
        BPTConfigParams memory _configParams
    )
        TimeLockPenaltyERC20(
            NAME,
            SYMBOL,
            _stakedAuraBPT,
            _feeReceiver,
            _accessManager,
            _startPenaltyPercentage,
            _timeLockDuration
        )
    {
        if (_configParams.rewardTokens.length == 0) {
            revert EmptyRewardTokens();
        }
        BALANCER_ROUTER = _configParams.balancerRouter;
        AURA_BOOSTER_LITE = _configParams.auraBoosterLite;
        AURA_REWARDS_POOL = _configParams.auraRewardsPool;
        PRL = _configParams.prl;
        WETH = _configParams.weth;
        BPT = _configParams.balancerBPT;
        PERMIT2 = _configParams.permit2;
        isReversedBalancerPair = address(_configParams.weth) > address(_configParams.prl);
        rewardTokens = _configParams.rewardTokens;

        /// @dev Approve PERMIT2 to spend PRL and WETH
        PRL.approve(address(PERMIT2), type(uint256).max);
        WETH.approve(address(PERMIT2), type(uint256).max);
    }

    //-------------------------------------------
    // External Functions
    //-------------------------------------------

    /// @notice Deposit BPT into the Aura Pool and mint the equivalent amount of sPRL2.
    /// @param _amount The amount of BPT to deposit.
    function depositBPT(uint256 _amount) external whenNotPaused nonReentrant {
        BPT.safeTransferFrom(msg.sender, address(this), _amount);
        _depositIntoAuraAndStake(_amount);
        _deposit(_amount);
    }

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
        whenNotPaused
        nonReentrant
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        // @dev using try catch to avoid reverting the transaction in case of front-running
        try IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s) { }
            catch { }

        PRL.safeTransferFrom(msg.sender, address(this), _maxPrlAmount);
        WETH.transferFrom(msg.sender, address(this), _maxWethAmount);

        (amountsIn, bptAmount) = _joinPool(_maxPrlAmount, _maxWethAmount, _exactBptAmount, false);

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
        whenNotPaused
        nonReentrant
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        // @dev using try catch to avoid reverting the transaction in case of front-running
        try IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s) { }
            catch { }

        PRL.safeTransferFrom(msg.sender, address(this), _maxPrlAmount);

        (amountsIn, bptAmount) = _joinPool(_maxPrlAmount, msg.value, _exactBptAmount, true);

        _deposit(bptAmount);
    }

    /// @notice Withdraw BPT for multiple requests.
    /// @param _requestIds The request IDs to withdraw from.
    /// @param _maxAcceptablePenalty The maximum penalty percentage to apply.
    function withdrawBPT(uint256[] calldata _requestIds, uint256 _maxAcceptablePenalty) external nonReentrant {
        (uint256 totalBptAmount, uint256 totalBptAmountSlashed) = _withdrawMultiple(_requestIds, _maxAcceptablePenalty);
        _exitAuraVaultAndUnstake(totalBptAmount, totalBptAmountSlashed);
        emit WithdrawlBPT(_requestIds, msg.sender, totalBptAmount, totalBptAmountSlashed);
        BPT.safeTransfer(msg.sender, totalBptAmount);
    }

    /// @notice Withdraw PRL and WETH for multiple requests.
    /// @param _requestIds The request IDs to withdraw from.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minWethAmount The minimum amount of WETH to receive.
    /// @return prlAmount The amount of PRL received.
    /// @return wethAmount The amount of WETH received.
    function withdrawPRLAndWeth(
        uint256[] calldata _requestIds,
        uint256 _minPrlAmount,
        uint256 _minWethAmount,
        uint256 _maxPenaltyPercentage
    )
        external
        nonReentrant
        returns (uint256 prlAmount, uint256 wethAmount)
    {
        (uint256 totalBptAmount, uint256 totalBptAmountSlashed) = _withdrawMultiple(_requestIds, _maxPenaltyPercentage);

        (prlAmount, wethAmount) = _exitPool(totalBptAmount, totalBptAmountSlashed, _minPrlAmount, _minWethAmount);

        emit WithdrawlPRLAndWeth(_requestIds, msg.sender, prlAmount, wethAmount, totalBptAmountSlashed);
        PRL.safeTransfer(msg.sender, prlAmount);
        WETH.transfer(msg.sender, wethAmount);
    }

    /// @notice Claim rewards from Aura Pool
    function claimRewards() public {
        AURA_REWARDS_POOL.getReward();
        forwardRewards();
    }

    /// @notice Forward rewards owned by the contract to the fee receiver.
    function forwardRewards() public {
        for (uint256 i; i < rewardTokens.length; i++) {
            IERC20 token = IERC20(rewardTokens[i]);
            uint256 balance = token.balanceOf(address(this));
            if (balance > 0) {
                token.safeTransfer(feeReceiver, balance);
            }
        }
    }

    /// @notice Allow users to emergency withdraw assets without penalties.
    /// @dev This function can only be called when the contract is paused.
    /// @param _amount The amount of assets to unlock.
    function emergencyWithdraw(uint256 _amount) external whenPaused nonReentrant {
        _burn(msg.sender, _amount);
        _exitAuraVaultAndUnstake(_amount, 0);
        emit EmergencyWithdraw(msg.sender, _amount);
        BPT.safeTransfer(msg.sender, _amount);
    }

    //-------------------------------------------
    // Restricted Functions
    //-------------------------------------------

    /// @notice Allow the AccessManager to update the fee receiver.
    /// @dev Override the parent contract function to claim rewards before updating the fee receiver.
    /// @param _newFeeReceiver The new fee receiver.
    function updateFeeReceiver(address _newFeeReceiver) public override restricted {
        claimRewards();
        super.updateFeeReceiver(_newFeeReceiver);
    }

    /// @notice Allow the AccessManager to update the reward tokens.
    /// @dev This function can only be called by the AccessManager.
    /// @param _rewardTokens The new reward tokens.
    function updateRewardTokens(address[] calldata _rewardTokens) public restricted {
        if (_rewardTokens.length == 0) {
            revert EmptyRewardTokens();
        }
        delete rewardTokens;
        for (uint256 i; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
        }
        emit RewardTokensUpdated(_rewardTokens);
    }

    /// @notice Allow ETH to be received.
    receive() external payable { }

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
        (maxAmountsIn[0], maxAmountsIn[1]) =
            isReversedBalancerPair ? (_maxPrlAmount, _maxEthAmount) : (_maxEthAmount, _maxPrlAmount);

        /// @dev Approve tokens.
        PERMIT2.approve(address(PRL), address(BALANCER_ROUTER), uint160(_maxPrlAmount), 0);
        PERMIT2.approve(address(WETH), address(BALANCER_ROUTER), uint160(_maxEthAmount), 0);

        /// @dev Wrap ETH.
        if (_isEth) {
            WETH.deposit{ value: _maxEthAmount }();
        }
        /// @dev Deposit into Balancer V3
        uint256[] memory _amountsIn =
            BALANCER_ROUTER.addLiquidityProportional(address(BPT), maxAmountsIn, _exactBptAmount, false, "");

        /// @dev Deposit into Aura
        _depositIntoAuraAndStake(_exactBptAmount);

        /// @dev Return any remaining PRL.
        (uint256 prlAmountToReturn, uint256 ethAmountToReturn) = isReversedBalancerPair
            ? (_maxPrlAmount - _amountsIn[0], _maxEthAmount - _amountsIn[1])
            : (_maxPrlAmount - _amountsIn[1], _maxEthAmount - _amountsIn[0]);

        if (prlAmountToReturn > 0) {
            PRL.transfer(msg.sender, prlAmountToReturn);
        }

        /// @dev Return any remaining WETH.
        if (ethAmountToReturn > 0) {
            if (_isEth) {
                WETH.withdraw(ethAmountToReturn);
                payable(msg.sender).sendValue(ethAmountToReturn);
            } else {
                WETH.transfer(msg.sender, ethAmountToReturn);
            }
        }

        return (_amountsIn, _exactBptAmount);
    }

    /// @notice Deposit BPT into the Aura Pool and stake it.
    /// @param _bptAmount The amount of BPT to deposit.
    function _depositIntoAuraAndStake(uint256 _bptAmount) internal {
        BPT.approve(address(AURA_BOOSTER_LITE), _bptAmount);
        if (!AURA_BOOSTER_LITE.deposit(AURA_POOL_PID, _bptAmount, true)) revert AuraDepositFailed();
    }

    /// @notice Exit the pool.
    /// @dev Unstake
    /// @dev Balancer V3 will revert if the amount of tokens received is less than the minimum expected.
    /// @param _bptAmount The amount of BPT to withdraw.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minWethAmount The minimum amount of WETH to receive.
    /// @return _prlAmount The amount of PRL received.
    /// @return _wethAmount The amount of WETH received.
    function _exitPool(
        uint256 _bptAmount,
        uint256 _bptAmountSlashed,
        uint256 _minPrlAmount,
        uint256 _minWethAmount
    )
        internal
        returns (uint256 _prlAmount, uint256 _wethAmount)
    {
        /// @dev Exit the Aura Vault and unstake the BPT.
        _exitAuraVaultAndUnstake(_bptAmount, _bptAmountSlashed);

        uint256[] memory minAmountsOut = new uint256[](2);
        (minAmountsOut[0], minAmountsOut[1]) =
            isReversedBalancerPair ? (_minPrlAmount, _minWethAmount) : (_minWethAmount, _minPrlAmount);

        BPT.approve(address(BALANCER_ROUTER), _bptAmount);

        (uint256[] memory amountsOut) =
            BALANCER_ROUTER.removeLiquidityProportional(address(BPT), _bptAmount, minAmountsOut, false, "");

        (_prlAmount, _wethAmount) =
            isReversedBalancerPair ? (amountsOut[0], amountsOut[1]) : (amountsOut[1], amountsOut[0]);
    }

    /// @notice Exit the Aura Vault and unstake the BPT.
    /// @param _amount The amount of Aura BPT to unstake.
    /// @param _amountSlashed The amount of Aura BPT to slash.
    function _exitAuraVaultAndUnstake(uint256 _amount, uint256 _amountSlashed) internal {
        AURA_REWARDS_POOL.withdrawAndUnwrap(_amount + _amountSlashed, false);
        // Transfer the slash amount of BPT to the fee receiver
        if (_amountSlashed > 0) {
            BPT.safeTransfer(feeReceiver, _amountSlashed);
        }
    }
}
