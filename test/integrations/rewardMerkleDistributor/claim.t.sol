// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Merkle } from "@murky/Merkle.sol";

import "test/Integrations.t.sol";

contract RewardMerkleDistributor_Claim_Integrations_Test is Integrations_Test {
    uint256 internal rewardsAmount = 1e18;

    Merkle internal firstMerkleTree;
    bytes32[] internal firstLeaves;
    bytes32 internal firstRoot;

    Merkle internal secondMerkleTree;
    bytes32[] internal secondLeaves;
    bytes32 internal secondRoot;

    function setUp() public override {
        super.setUp();
        par.mint(address(rewardMerkleDistributor), INITIAL_BALANCE);

        firstMerkleTree = new Merkle();
        secondMerkleTree = new Merkle();

        vm.startPrank(users.admin.addr);
        /// @dev Leaves are added in the order of the merkle tree's firstLeaves.
        /// @dev alice reward is at index 0, bob reward is at index 1, dao treasury reward is at index 2.
        firstLeaves.push(keccak256(abi.encodePacked(users.alice.addr, rewardsAmount)));
        firstLeaves.push(keccak256(abi.encodePacked(users.bob.addr, rewardsAmount)));
        firstLeaves.push(keccak256(abi.encodePacked(users.daoTreasury.addr, rewardsAmount)));
        firstRoot = firstMerkleTree.getRoot(firstLeaves);
        rewardMerkleDistributor.updateRoot(firstRoot);
    }

    function test_RewardMerkleDistributor_Claim_CurrentRoot() external {
        vm.startPrank(users.alice.addr);

        uint256 alicePARBalanceBefore = par.balanceOf(users.alice.addr);
        bytes32[] memory proof = firstMerkleTree.getProof(firstLeaves, 0);
        rewardMerkleDistributor.claim(users.alice.addr, rewardsAmount, proof);
        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + rewardsAmount);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), INITIAL_BALANCE - rewardsAmount);
        assertEq(rewardMerkleDistributor.claimed(users.alice.addr), rewardsAmount);
    }

    function test_RewardMerkleDistributor_Claim_PreviousRoot() external {
        _addNewEpoch(rewardsAmount * 2);
        vm.startPrank(users.alice.addr);
        uint256 alicePARBalanceBefore = par.balanceOf(users.alice.addr);
        bytes32[] memory proof = firstMerkleTree.getProof(firstLeaves, 0);
        rewardMerkleDistributor.claim(users.alice.addr, rewardsAmount, proof);
        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + rewardsAmount);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), INITIAL_BALANCE - rewardsAmount);
        assertEq(rewardMerkleDistributor.claimed(users.alice.addr), rewardsAmount);
    }

    function test_RewardMerkleDistributor_Claim_MultipleEpochs(uint256 _newAliceRewardsAmount) external {
        _newAliceRewardsAmount =
            bound(_newAliceRewardsAmount, rewardsAmount + 1, INITIAL_BALANCE - (rewardsAmount * 3));

        vm.startPrank(users.alice.addr);
        uint256 alicePARBalanceBefore = par.balanceOf(users.alice.addr);

        bytes32[] memory proof = firstMerkleTree.getProof(firstLeaves, 0);
        rewardMerkleDistributor.claim(users.alice.addr, rewardsAmount, proof);

        uint256 rewardMerkleDistributorBalance = par.balanceOf(address(rewardMerkleDistributor));
        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + rewardsAmount);
        assertEq(rewardMerkleDistributorBalance, INITIAL_BALANCE - rewardsAmount);
        assertEq(rewardMerkleDistributor.claimed(users.alice.addr), rewardsAmount);

        _addNewEpoch(_newAliceRewardsAmount);

        vm.startPrank(users.alice.addr);
        alicePARBalanceBefore = par.balanceOf(users.alice.addr);
        bytes32[] memory secondProof = secondMerkleTree.getProof(secondLeaves, 0);

        rewardMerkleDistributor.claim(users.alice.addr, _newAliceRewardsAmount, secondProof);

        uint256 expectedClaimed = _newAliceRewardsAmount - rewardsAmount;

        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + expectedClaimed);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), rewardMerkleDistributorBalance - expectedClaimed);
        assertEq(rewardMerkleDistributor.claimed(users.alice.addr), rewardsAmount + expectedClaimed);
    }

    function _addNewEpoch(uint256 _newAliceRewardsAmount) internal {
        secondMerkleTree = new Merkle();
        secondLeaves.push(keccak256(abi.encodePacked(users.alice.addr, _newAliceRewardsAmount)));
        secondLeaves.push(keccak256(abi.encodePacked(users.bob.addr, rewardsAmount)));
        secondLeaves.push(keccak256(abi.encodePacked(users.daoTreasury.addr, rewardsAmount)));
        secondLeaves.push(keccak256(abi.encodePacked(users.insuranceFundMultisig.addr, rewardsAmount)));
        secondRoot = secondMerkleTree.getRoot(secondLeaves);

        vm.startPrank(users.admin.addr);
        rewardMerkleDistributor.updateRoot(secondRoot);
        vm.stopPrank();
    }
}
