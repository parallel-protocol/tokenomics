// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { TimeLockPenaltyERC20, IERC20, ERC20, IERC20Permit, ERC20Permit } from "./TimeLockPenaltyERC20.sol";
import { Nonces } from "@openzeppelin/contracts/utils/Nonces.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import { IBalancerV3Router } from "contracts/interfaces/IBalancerV3Router.sol";
import {
    IAuraBoosterLite,
    IVirtualBalanceRewardPool,
    IAuraRewardPool,
    IAuraStashToken
} from "contracts/interfaces/IAura.sol";
import { IWrappedNative } from "contracts/interfaces/IWrappedNative.sol";

contract sPRL2 is TimeLockPenaltyERC20, ERC20Votes {
    using Address for address payable;
    using SafeERC20 for IERC20;

    string constant NAME = "Stake 20WETH-80PRL Aura Deposit Vault";
    string constant SYMBOL = "sPRL2";

    /// @dev Aura Pool PID is hardcoded and must be updated before deploying
    uint256 public constant AURA_POOL_PID = 19;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The Balancer V3 router.
    IBalancerV3Router public immutable BALANCER_ROUTER;
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

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Error thrown when the deposit fails.
    error DepositFailed();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Constructor for the sPRL2 contract.
    /// @param _stakedAuraBPT The address of the Staked Aura BPT token.
    /// @param _feeReceiver The address of the fee receiver.
    /// @param _accessManager The address of the access manager.
    /// @param _startPenaltyPercentage The start penalty percentage.
    /// @param _timeLockDuration The time lock duration.
    /// @param _balancerRouter The address of the Balancer V3 router.
    /// @param _auraBoosterLite The address of the Aura Booster Lite contract.
    /// @param _auraVault The address of the Aura Vault contract.
    /// @param _balancerBPT The address of the Balancer BPT token.
    /// @param _prl The address of the PRL token.
    /// @param _weth The address of the WETH token.
    constructor(
        address _stakedAuraBPT,
        address _feeReceiver,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration,
        IBalancerV3Router _balancerRouter,
        IAuraBoosterLite _auraBoosterLite,
        IAuraRewardPool _auraVault,
        IERC20 _balancerBPT,
        IERC20 _prl,
        IWrappedNative _weth
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
        BALANCER_ROUTER = _balancerRouter;
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
        whenNotPaused
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        // @dev using try catch to avoid reverting the transaction in case of front-running
        try IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s) { }
            catch { }

        PRL.transferFrom(msg.sender, address(this), _maxPrlAmount);
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
        returns (uint256[] memory amountsIn, uint256 bptAmount)
    {
        // @dev using try catch to avoid reverting the transaction in case of front-running
        try IERC20Permit(address(PRL)).permit(msg.sender, address(this), _maxPrlAmount, _deadline, _v, _r, _s) { }
            catch { }

        PRL.transferFrom(msg.sender, address(this), _maxPrlAmount);

        (amountsIn, bptAmount) = _joinPool(_maxPrlAmount, msg.value, _exactBptAmount, true);

        _deposit(bptAmount);
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
        uint256 _minWethAmount
    )
        external
        returns (uint256 prlAmount, uint256 wethAmount)
    {
        uint256 totalBptAmount;
        uint256 totalBptAmountSlashed;
        for (uint8 i; i < _requestIds.length; i++) {
            (uint256 bptAmount, uint256 slashBptAmount) = _withdraw(_requestIds[i]);
            totalBptAmount += bptAmount;
            totalBptAmountSlashed += slashBptAmount;
        }

        (prlAmount, wethAmount) = _exitPool(totalBptAmount, totalBptAmountSlashed, _minPrlAmount, _minWethAmount);

        emit WithdrawlPRLAndWeth(_requestIds, msg.sender, prlAmount, wethAmount, totalBptAmountSlashed);
        PRL.transfer(msg.sender, prlAmount);
        WETH.transfer(msg.sender, wethAmount);
    }

    /// @notice Claim rewards from Aura Pool and transfer them to the fee receiver.
    function claimRewards() external {
        AURA_VAULT.getReward();
        IERC20 mainRewardToken = IERC20(AURA_VAULT.rewardToken());
        uint256 mainRewardBalance = mainRewardToken.balanceOf(address(this));
        if (mainRewardBalance > 0) {
            mainRewardToken.transfer(feeReceiver, mainRewardBalance);
        }

        address[] memory extraRewards = AURA_VAULT.extraRewards();
        uint256 extraRewardsLength = extraRewards.length;
        if (extraRewardsLength > 0) {
            uint256 i;
            for (; i < extraRewardsLength; ++i) {
                IAuraStashToken auraStashToken =
                    IAuraStashToken(IVirtualBalanceRewardPool(extraRewards[i]).rewardToken());
                IERC20 extraRewardToken = IERC20(auraStashToken.baseToken());
                uint256 rewardBalance = extraRewardToken.balanceOf(address(this));
                if (rewardBalance > 0) {
                    extraRewardToken.transfer(feeReceiver, rewardBalance);
                }
            }
        }
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
        maxAmountsIn[0] = _maxEthAmount;
        maxAmountsIn[1] = _maxPrlAmount;

        /// @dev Reverse maxAmountsIn if the pair is reversed
        if (isReversedBalancerPair) {
            (maxAmountsIn[0], maxAmountsIn[1]) = (maxAmountsIn[1], maxAmountsIn[0]);
        }

        /// @dev Approve tokens.
        PRL.approve(address(BALANCER_ROUTER), _maxPrlAmount);
        WETH.approve(address(BALANCER_ROUTER), _maxEthAmount);

        /// @dev Wrap ETH.
        if (_isEth) {
            WETH.deposit{ value: _maxEthAmount }();
        }
        /// @dev Deposit into Balancer V3
        uint256[] memory _amountsIn =
            BALANCER_ROUTER.addLiquidityProportional(address(BPT), maxAmountsIn, _exactBptAmount, false, "");

        /// @dev Reset approvals in case not all tokens were used
        PRL.approve(address(BALANCER_ROUTER), 0);
        WETH.approve(address(BALANCER_ROUTER), 0);

        /// @dev Deposit into Aura
        BPT.approve(address(AURA_BOOSTER_LITE), _exactBptAmount);
        if (!AURA_BOOSTER_LITE.deposit(AURA_POOL_PID, _exactBptAmount, true)) revert DepositFailed();

        /// @dev Return any remaining PRL.
        uint256 prlBalanceToReturn = PRL.balanceOf(address(this));
        if (prlBalanceToReturn > 0) {
            PRL.transfer(msg.sender, prlBalanceToReturn);
        }

        /// @dev Return any remaining WETH.
        uint256 wethBalanceToReturn = WETH.balanceOf(address(this));
        if (wethBalanceToReturn > 0) {
            if (_isEth) {
                WETH.withdraw(wethBalanceToReturn);
                payable(msg.sender).sendValue(wethBalanceToReturn);
            } else {
                WETH.transfer(msg.sender, wethBalanceToReturn);
            }
        }

        return (_amountsIn, _exactBptAmount);
    }

    /// @notice Exit the pool.
    /// @dev Unstake
    /// @dev Balancer V3 will revert if the amount of tokens received is less than the minimum expected.
    /// @param _bptAmount The amount of BPT to withdraw.
    /// @param _minPrlAmount The minimum amount of PRL to receive.
    /// @param _minWethAmount The minimum amount of WETH to receive.
    /// @return _wethAmount The amount of WETH received.
    /// @return _prlAmount The amount of PRL received.
    function _exitPool(
        uint256 _bptAmount,
        uint256 _bptAmountSlashed,
        uint256 _minPrlAmount,
        uint256 _minWethAmount
    )
        internal
        returns (uint256 _wethAmount, uint256 _prlAmount)
    {
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = _minWethAmount;
        minAmountsOut[1] = _minPrlAmount;

        if (isReversedBalancerPair) {
            (minAmountsOut[0], minAmountsOut[1]) = (minAmountsOut[1], minAmountsOut[0]);
        }

        /// @dev withdraw from aura
        AURA_VAULT.withdrawAndUnwrap(_bptAmount + _bptAmountSlashed, false);

        // Transfer the slash amount of BPT to the fee receiver
        if (_bptAmountSlashed > 0) {
            BPT.safeTransfer(feeReceiver, _bptAmountSlashed);
        }

        BPT.approve(address(BALANCER_ROUTER), _bptAmount);

        BALANCER_ROUTER.removeLiquidityProportional(address(BPT), _bptAmount, minAmountsOut, false, "");

        _prlAmount = PRL.balanceOf(address(this));
        _wethAmount = WETH.balanceOf(address(this));
    }

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
