// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    IAuraBoosterLite,
    IAuraRewardPool,
    IVirtualBalanceRewardPool,
    IAuraStashToken
} from "contracts/interfaces/IAura.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "./ERC20Mock.sol";

import { console2 } from "@forge-std/console2.sol";

contract AuraBoosterLiteMock is IAuraBoosterLite {
    IERC20 public bpt;
    ERC20Mock public auraBpt;

    constructor(address _bpt, address _auraBpt) {
        bpt = IERC20(_bpt);
        auraBpt = ERC20Mock(_auraBpt);
    }

    function deposit(uint256, uint256 _amount, bool) external returns (bool) {
        bpt.transferFrom(msg.sender, address(this), _amount);
        auraBpt.mint(msg.sender, _amount);
        return true;
    }

    function withdraw(uint256, uint256 _amount) external returns (bool) {
        auraBpt.burn(msg.sender, _amount);
        bpt.transfer(msg.sender, _amount);
        return true;
    }
}

contract AuraRewardPoolMock is IAuraRewardPool {
    address[] public extraRewardsTokens;
    address public rewardToken;

    constructor(address _rewardToken, address[] memory _extraRewards) {
        extraRewardsTokens = _extraRewards;
        rewardToken = _rewardToken;
    }

    function setExtraRewards(address[] memory _extraRewards) external {
        extraRewardsTokens = _extraRewards;
    }

    function getReward() external returns (bool) {
        return true;
    }

    function extraRewardsLength() external view returns (uint256) {
        return extraRewardsTokens.length;
    }

    function extraRewards() external view returns (address[] memory) {
        return extraRewardsTokens;
    }
}

contract VirtualBalanceRewardPoolMock is IVirtualBalanceRewardPool {
    address public stash;

    constructor(address _stash) {
        stash = _stash;
    }

    function rewardToken() external view returns (address) {
        return stash;
    }
}

contract AuraStashTokenMock is IAuraStashToken {
    address public rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function baseToken() external view returns (address) {
        return rewardToken;
    }
}
