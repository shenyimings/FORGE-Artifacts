// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "../core/Distributor.sol";
import "../core/TokenDistributor.sol";
import "../interfaces/IDistributor.sol";
import "../interfaces/ITokenDistributor.sol";

/**
 * @title PoolFactory
 * @dev A contract for creating Distributor and TokenDistributor contracts.
 */
contract PoolFactory is Initializable, Ownable {
    uint256 public distributorCount; // Counter for the number of created Distributor contracts.
    uint256 public tokenDistributorCount; // Counter for the number of created TokenDistributor contracts.

    mapping(uint256 => address) public distributors; // Mapping to store Distributor contract addresses by their IDs.
    mapping(uint256 => address) public tokenDistributors; // Mapping to store TokenDistributor contract addresses by their IDs.

    address public distributorImplementation; // Address of the implementation contract for Distributor contracts.
    address public tokenDistributorImplementation; // Address of the implementation contract for TokenDistributor contracts.

    event DistributorCreated(
        address creatorAddress,
        address distributorAddress,
        uint256 distributorId
    ); // Event emitted when a Distributor contract is created.
    event TokenDistributorCreated(
        address creatorAddress,
        address tokenDistributorAddress,
        uint256 tokenDistributorId
    ); // Event emitted when a TokenDistributor contract is created.

    /**
     * @dev Initializes the contract with new implementation addresses.
     */
    function initialize(address distributorImplementation_, address tokenDistributorImplementation_) external initializer {
        _transferOwnership(_msgSender());
        distributorImplementation = distributorImplementation_;
        tokenDistributorImplementation = tokenDistributorImplementation_;
    }

    /**
     * @dev Creates a new Distributor contract.
     * @param poolName The name of the pool.
     * @param startTime The start time of the distribution.
     * @param endTime The end time of the distribution.
     * @param distributionRate The distribution rate.
     * @param periodLength The length of each distribution period.
     * @param claimableAmount The total amount claimable per period.
     * @return The ID of the created Distributor contract.
     */
    function createDistributor(
        string memory poolName,
        uint256 startTime,
        uint256 endTime,
        uint256 distributionRate,
        uint256 periodLength,
        uint256 lastClaimTime,
        uint256 claimableAmount,
        uint256 leftClaimableAmount
    ) external onlyOwner returns (uint256) {
        require(distributorImplementation != address(0), "PoolFactory: Distributor implementation not found");

        address newDistributorAddress = Clones.clone(distributorImplementation);
        IDistributor(newDistributorAddress).initialize(
            owner(),
            poolName,
            startTime,
            endTime,
            distributionRate,
            periodLength,
            lastClaimTime,
            claimableAmount,
            leftClaimableAmount
        );

        emit DistributorCreated(
            owner(),
            newDistributorAddress,
            distributorCount
        );

        distributors[distributorCount] = newDistributorAddress;
        distributorCount++;

        return distributorCount - 1;
    }

    /**
     * @dev Creates a new TokenDistributor contract.
     * @param poolName The name of the pool.
     * @param startTime The start time of the distribution.
     * @param endTime The end time of the distribution.
     * @param distributionRate The distribution rate.
     * @param periodLength The length of each distribution period.
     * @return The ID of the created TokenDistributor contract.
     */
    function createTokenDistributor(
        string memory poolName,
        uint256 startTime,
        uint256 endTime,
        uint256 distributionRate,
        uint256 periodLength
    ) external onlyOwner returns (uint256) {
        require(tokenDistributorImplementation != address(0), "PoolFactory: TokenDistributor implementation not found");

        address newTokenDistributorAddress = Clones.clone(
            tokenDistributorImplementation
        );
        ITokenDistributor(newTokenDistributorAddress).initialize(
            owner(),
            poolName,
            startTime,
            endTime,
            distributionRate,
            periodLength
        );

        emit TokenDistributorCreated(
            owner(),
            newTokenDistributorAddress,
            tokenDistributorCount
        );

        tokenDistributors[tokenDistributorCount] = newTokenDistributorAddress;
        tokenDistributorCount++;

        return tokenDistributorCount - 1;
    }
}
