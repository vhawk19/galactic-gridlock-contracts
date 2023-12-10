// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Leaderboard Contract
/// @notice Manages arbitrary distributions and their merkle roots for leaderboard tracking.
contract Leaderboard is Ownable {
    
    struct ArbitraryDistribution {
        string distname;
        string metadata;
        address owner;
        uint256 epoch;
        uint256 lastUpdated;
        uint256 firstPublished;
    }

    uint256 public immutable epoch;
    uint256 public firstPublished;
    uint256 public lastUpdated;
    bytes32[] public merkleRoots;
    uint256 distCounter;

    mapping(uint256 => ArbitraryDistribution) public distIds;
    mapping(uint256 => bytes32[]) public merkleRootsArbitrary;

    event MerkleRootPublished(bytes32 indexed merkleRoot, uint256 indexed endTimestamp);
    event MerkleRootArbitraryPublished(bytes32 indexed merkleRoot, uint256 indexed endTimestamp, uint256 indexed distId);
    event ArbitraryDistributionCreated(uint256 indexed distId, ArbitraryDistribution indexed dist, address indexed creator);

    /// @param _epoch Duration of each epoch in seconds.
    constructor(uint256 _epoch) Ownable(msg.sender) {
        epoch = _epoch;
    }

    /// @notice Creates a new arbitrary distribution.
    /// @param dist The distribution struct containing distribution details.
    /// @return success Boolean indicating the success of the function call.
    function createArbitraryDistribution(ArbitraryDistribution memory dist) public returns (bool success) {
        distIds[distCounter] = dist;
        emit ArbitraryDistributionCreated(distCounter, dist, msg.sender);
        distCounter++;
        success = true;
    }

    /// @notice Publishes a new merkle root for the standard leaderboard.
    /// @param currentMerkleRoot The merkle root to be published.
    /// @param endTimestamp The end timestamp of the current epoch.
    /// @return success Boolean indicating the success of the function call.
    function publish(bytes32 currentMerkleRoot, uint256 endTimestamp) public onlyOwner returns(bool success) {
        require(block.timestamp > endTimestamp, "Time not passed");
        require(endTimestamp - lastUpdated == epoch, "The Data has to be published every epoch, in case of no activity during an epoch publish no activity");
        if (firstPublished == 0) {
            firstPublished = endTimestamp;
        }
        merkleRoots.push(currentMerkleRoot);
        lastUpdated += epoch;
        emit MerkleRootPublished(currentMerkleRoot, endTimestamp);

        success = true;
    }

    /// @notice Publishes a new merkle root for an arbitrary distribution.
    /// @param currentMerkleRoot The merkle root to be published.
    /// @param endTimestamp The end timestamp of the current epoch.
    /// @param distId The identifier of the distribution.
    /// @return success Boolean indicating the success of the function call.
    function publishArbitrary(bytes32 currentMerkleRoot, uint256 endTimestamp, uint256 distId) public returns(bool success) {
        ArbitraryDistribution memory dist = distIds[distId];
        require(dist.owner == msg.sender, "Can only be published by the creator of the distribution");
        require(block.timestamp > endTimestamp, "Time not passed");
        require(endTimestamp - dist.lastUpdated == dist.epoch, "The Data has to be published every epoch, in case of no activity during an epoch publish no activity");
        if (dist.firstPublished == 0) {
            dist.firstPublished = endTimestamp;
        }
        merkleRootsArbitrary[distId].push(currentMerkleRoot);
        dist.lastUpdated += dist.epoch;
        emit MerkleRootArbitraryPublished(currentMerkleRoot, endTimestamp, distId);

        success = true;
    }

    /// @notice Retrieves the latest merkle root from the standard leaderboard.
    /// @return lastMerkleRoot The most recent merkle root.
    function getCurrentMerkleRoot() public view returns(bytes32 lastMerkleRoot) {
        lastMerkleRoot = merkleRoots[merkleRoots.length - 1];
    }

    /// @notice Retrieves the latest merkle root for a given arbitrary distribution.
    /// @param distId The identifier of the distribution.
    /// @return lastMerkleRoot The most recent merkle root of the specified distribution.
    function getCurrentMerkleRootArbitrary(uint256 distId) public view returns(bytes32 lastMerkleRoot) {
        lastMerkleRoot = merkleRootsArbitrary[distId][merkleRootsArbitrary[distId].length - 1];
    }

    /// @notice Retrieves the merkle root corresponding to a given timestamp from the standard leaderboard.
    /// @param timestamp The timestamp for which the merkle root is requested.
    /// @return merkleRootGivenTimestamp The merkle root corresponding to the given timestamp.
    function getMerkleRootByTimestamp(uint256 timestamp) public view returns(bytes32 merkleRootGivenTimestamp) {
        if (timestamp <= firstPublished) {
            merkleRootGivenTimestamp = merkleRoots[0];
        } else {
            uint256 index = (timestamp - firstPublished) / epoch;
            require(index < merkleRoots.length, "Timestamp is out of range");
            merkleRootGivenTimestamp = merkleRoots[index];
        }
    }

    /// @notice Retrieves the merkle root corresponding to a given timestamp from an arbitrary distribution.
    /// @param timestamp The timestamp for which the merkle root is requested.
    /// @param distId The identifier of the distribution.
    /// @return merkleRootGivenTimestamp The merkle root corresponding to the given timestamp in the specified distribution.
    function getMerkleRootArbitraryByTimestamp(uint256 timestamp, uint256 distId) public view returns(bytes32 merkleRootGivenTimestamp) {
        ArbitraryDistribution memory dist = distIds[distId];
        if (timestamp <= dist.firstPublished) {
            merkleRootGivenTimestamp = merkleRootsArbitrary[distId][0];
        } else {
            uint256 index = (timestamp - dist.firstPublished) / dist.epoch;
            require(index < merkleRootsArbitrary[distId].length, "Timestamp is out of range");
            merkleRootGivenTimestamp = merkleRootsArbitrary[distId][index];
        }
    }
}
