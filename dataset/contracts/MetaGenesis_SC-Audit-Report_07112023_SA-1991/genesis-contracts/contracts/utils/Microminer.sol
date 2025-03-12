// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../libs/MinerTypes.sol";

import "../interfaces/IMinerHealthCheck.sol";
import "../interfaces/IMetaPoints.sol";
import "../interfaces/IMinerList.sol";
import "../helpers/RolesHandler.sol";

/**
 * @title Microminer
 * @dev A smart contract for managing Microminers.
 */
contract Microminer is Initializable, RolesHandler {
    /// @notice The amount required for staking as a Microminer
    uint256 public constant STAKE_AMOUNT = 100 ether;

    /// @notice Address of the MinerHealthCheck contract
    IMinerHealthCheck public minerHealthCheck;
    /// @notice Address of the MetaPoints contract
    IMetaPoints public metapoints;
    /// @notice Address of the MinerList contract
    IMinerList public minerList;

    /**
     * @dev Modifier to check if an address is a Microminer.
     * @param miner The address to check.
     */
    modifier isMiner(address miner) {
        require(
            minerList.isMiner(miner, MinerTypes.NodeType.Micro),
            "Microminer: Address is not microminer"
        );
        _;
    }

    /**
     * @dev Modifier to check if an address is not a Microminer.
     * @param miner The address to check.
     */
    modifier notMiner(address miner) {
        require(
            !minerList.isMiner(miner, MinerTypes.NodeType.Micro),
            "Microminer: Address is already microminer"
        );
        _;
    }

    /**
     * @dev The receive function is a special function that allows the contract to accept MTC transactions.
     */
    receive() external payable {}

    /**
     * @dev Initializes the Microminer contract with required addresses.
     * @param minerHealthCheckAddress The address of the MinerHealthCheck contract.
     * @param metapointsAddress The address of the MetaPoints contract.
     * @param minerListAddress The address of the MinerList contract.
     */
    function initialize(
        address minerHealthCheckAddress,
        address metapointsAddress,
        address minerListAddress
    ) external initializer {
        require(
            minerHealthCheckAddress != address(0) &&
                metapointsAddress != address(0) &&
                minerListAddress != address(0),
            "Microminer: cannot set zero address"
        );
        minerHealthCheck = IMinerHealthCheck(minerHealthCheckAddress);
        metapoints = IMetaPoints(metapointsAddress);
        minerList = IMinerList(minerListAddress);
    }

    /**
     * @dev Sets an address as a Microminer.
     * @return A boolean indicating whether the operation was successful.
     */
    function setMiner() external payable notMiner(msg.sender) returns (bool) {
        require(
            msg.value == STAKE_AMOUNT,
            "Microminer: You have to stake as required STAKE_AMOUNT"
        );
        minerList.addMiner(msg.sender, MinerTypes.NodeType.Micro);
        return (true);
    }

    /**
     * @dev Allows a manager to kick a Microminer and refund the staked amount.
     * @param minerAddress The address of the Microminer to kick.
     * @return A boolean indicating whether the operation was successful.
     */
    function kickMiner(
        address minerAddress
    )
        external
        isMiner(minerAddress)
        onlyManagerRole(msg.sender)
        returns (bool)
    {
        _kickMiner(minerAddress);
        return (true);
    }

    /**
     * @dev Internal function to kick a Microminer and refund the staked amount.
     * @param minerAddress The address of the Microminer to kick.
     * @return A boolean indicating whether the operation was successful.
     */
    function _kickMiner(address minerAddress) internal returns (bool) {
        minerList.deleteMiner(minerAddress, MinerTypes.NodeType.Micro);
        (bool sent, ) = payable(minerAddress).call{value: STAKE_AMOUNT}("");

        require(sent, "Microminer: Unstake failed");
        return (true);
    }
}
