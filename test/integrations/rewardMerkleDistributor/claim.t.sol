// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Merkle } from "@murky/Merkle.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "test/Integrations.t.sol";

contract RewardMerkleDistributor_Claim_Integrations_Test is Integrations_Test {
    uint256 internal firstRewardsAmount = 1e18;
    uint256 internal secondRewardsAmount = 2e18;

    uint64 firstEpochId = 0;
    RewardMerkleDistributor.MerkleDrop firstEpochMerkleDrop;
    Merkle internal firstEpochMerkleTree;
    bytes32[] internal firstEpochLeaves;
    bytes32 internal firstEpochRoot;

    uint64 secondEpochId = 1;
    RewardMerkleDistributor.MerkleDrop secondEpochMerkleDrop;
    Merkle internal secondEpochMerkleTree;
    bytes32[] internal secondEpochLeaves;
    bytes32 internal secondEpochRoot;

    function setUp() public override {
        super.setUp();

        firstEpochMerkleTree = new Merkle();
        secondEpochMerkleTree = new Merkle();

        par.mint(address(rewardMerkleDistributor), INITIAL_BALANCE);

        vm.startPrank(users.admin.addr);
        /// @dev Leaves are added in the order of the merkle tree's firstEpochLeaves.
        /// @dev alice reward is at index 0, bob reward is at index 1.
        firstEpochLeaves.push(keccak256(abi.encodePacked(firstEpochId, users.alice.addr, firstRewardsAmount)));
        firstEpochLeaves.push(keccak256(abi.encodePacked(firstEpochId, users.bob.addr, firstRewardsAmount)));
        firstEpochRoot = firstEpochMerkleTree.getRoot(firstEpochLeaves);

        firstEpochMerkleDrop = RewardMerkleDistributor.MerkleDrop({
            root: firstEpochRoot,
            totalAmount: INITIAL_BALANCE,
            startTime: uint64(block.timestamp),
            expiryTime: uint64(block.timestamp) + uint64(rewardMerkleDistributor.EPOCH_LENGTH() * 6)
        });
        rewardMerkleDistributor.updateMerkleDrop(firstEpochId, firstEpochMerkleDrop);

        /// @dev Leaves are added in the order of the merkle tree's secondEpochLeaves.
        /// @dev alice reward is at index 0, bob reward is at index 1.
        secondEpochLeaves.push(keccak256(abi.encodePacked(secondEpochId, users.alice.addr, secondRewardsAmount)));
        secondEpochLeaves.push(keccak256(abi.encodePacked(secondEpochId, users.bob.addr, secondRewardsAmount)));
        secondEpochRoot = secondEpochMerkleTree.getRoot(secondEpochLeaves);
        secondEpochMerkleDrop = RewardMerkleDistributor.MerkleDrop({
            root: secondEpochRoot,
            totalAmount: INITIAL_BALANCE,
            startTime: uint64(block.timestamp) + uint64(rewardMerkleDistributor.EPOCH_LENGTH()),
            expiryTime: uint64(block.timestamp) + uint64(rewardMerkleDistributor.EPOCH_LENGTH() * 7)
        });
        rewardMerkleDistributor.updateMerkleDrop(secondEpochId, secondEpochMerkleDrop);
    }

    function test_RewardMerkleDistributor_Claim_OneEpoch() external {
        vm.startPrank(users.alice.addr);

        uint256 alicePARBalanceBefore = par.balanceOf(users.alice.addr);
        bytes32[] memory proof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount,
            merkleProof: proof
        });

        rewardMerkleDistributor.claims(claimsData);
        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + firstRewardsAmount);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), INITIAL_BALANCE - firstRewardsAmount);
        assertEq(rewardMerkleDistributor.totalClaimedPerUser(users.alice.addr), firstRewardsAmount);
        assertEq(rewardMerkleDistributor.totalClaimedPerEpoch(firstEpochId), firstRewardsAmount);
        assertEq(rewardMerkleDistributor.totalClaimed(), firstRewardsAmount);
    }

    function test_RewardMerkleDistributor_Claim_SeveralEpochs() external {
        vm.startPrank(users.alice.addr);
        uint256 expectedTotalClaimed = firstRewardsAmount + secondRewardsAmount;

        uint256 alicePARBalanceBefore = par.balanceOf(users.alice.addr);
        bytes32[] memory firstEpochProof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);
        bytes32[] memory secondEpochProof = secondEpochMerkleTree.getProof(secondEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](2);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount,
            merkleProof: firstEpochProof
        });
        claimsData[1] = RewardMerkleDistributor.ClaimCallData({
            epochId: secondEpochId,
            account: users.alice.addr,
            amount: secondRewardsAmount,
            merkleProof: secondEpochProof
        });

        vm.warp(secondEpochMerkleDrop.startTime);

        rewardMerkleDistributor.claims(claimsData);
        assertEq(par.balanceOf(users.alice.addr), alicePARBalanceBefore + expectedTotalClaimed);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), INITIAL_BALANCE - expectedTotalClaimed);
        assertEq(rewardMerkleDistributor.totalClaimedPerUser(users.alice.addr), expectedTotalClaimed);
        assertEq(rewardMerkleDistributor.totalClaimedPerEpoch(firstEpochId), firstRewardsAmount);
        assertEq(rewardMerkleDistributor.totalClaimedPerEpoch(secondEpochId), secondRewardsAmount);
        assertEq(rewardMerkleDistributor.totalClaimed(), expectedTotalClaimed);
    }

    function test_RewardMerkleDistributor_Claim_RevertWhen_EpochExpired() external {
        vm.startPrank(users.alice.addr);
        bytes32[] memory proof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount,
            merkleProof: proof
        });
        vm.warp(firstEpochMerkleDrop.expiryTime + 1);
        vm.expectRevert(RewardMerkleDistributor.EpochExpired.selector);
        rewardMerkleDistributor.claims(claimsData);
    }

    function test_RewardMerkleDistributor_Claim_RevertWhen_EpochNotStarted() external {
        vm.startPrank(users.alice.addr);
        bytes32[] memory proof = secondEpochMerkleTree.getProof(secondEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: secondEpochId,
            account: users.alice.addr,
            amount: secondRewardsAmount,
            merkleProof: proof
        });
        vm.expectRevert(RewardMerkleDistributor.NotStarted.selector);
        rewardMerkleDistributor.claims(claimsData);
    }

    function test_RewardMerkleDistributor_Claim_RevertWhen_EpochAlreadyClaimed() external {
        vm.startPrank(users.alice.addr);

        bytes32[] memory proof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount,
            merkleProof: proof
        });

        rewardMerkleDistributor.claims(claimsData);

        vm.expectRevert(RewardMerkleDistributor.AlreadyClaimed.selector);
        rewardMerkleDistributor.claims(claimsData);
    }

    function test_RewardMerkleDistributor_Claim_RevertWhen_ProofInvalid() external {
        vm.startPrank(users.alice.addr);

        bytes32[] memory proof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount * 100,
            merkleProof: proof
        });

        vm.expectRevert(RewardMerkleDistributor.ProofInvalid.selector);
        rewardMerkleDistributor.claims(claimsData);
    }

    modifier SetupTotalEpochRewardAmountClaimedExceedsEpochTotalAmount() {
        vm.startPrank(users.admin.addr);
        firstEpochMerkleDrop = RewardMerkleDistributor.MerkleDrop({
            root: firstEpochRoot,
            totalAmount: firstRewardsAmount - 1,
            startTime: uint64(block.timestamp),
            expiryTime: uint64(block.timestamp) + uint64(rewardMerkleDistributor.EPOCH_LENGTH() * 6)
        });
        rewardMerkleDistributor.updateMerkleDrop(firstEpochId, firstEpochMerkleDrop);

        _;
    }

    function test_RewardMerkleDistributor_Claim_RevertWhen_TotalAmountExceedsEpochTotalAmount()
        external
        SetupTotalEpochRewardAmountClaimedExceedsEpochTotalAmount
    {
        vm.startPrank(users.alice.addr);

        bytes32[] memory proof = firstEpochMerkleTree.getProof(firstEpochLeaves, 0);

        RewardMerkleDistributor.ClaimCallData[] memory claimsData = new RewardMerkleDistributor.ClaimCallData[](1);
        claimsData[0] = RewardMerkleDistributor.ClaimCallData({
            epochId: firstEpochId,
            account: users.alice.addr,
            amount: firstRewardsAmount,
            merkleProof: proof
        });

        vm.expectRevert(RewardMerkleDistributor.TotalEpochRewardsExceeded.selector);
        rewardMerkleDistributor.claims(claimsData);
    }
}
