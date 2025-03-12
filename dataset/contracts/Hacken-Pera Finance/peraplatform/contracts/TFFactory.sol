//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./trade-farming/TradeFarming.sol";

/// @author Ulaş Erdoğan
/// @title Trade Farming Factory Contract 
/// @dev Deploys new trade farming contracts and store their addresses by transferring its ownership to msg.sender
contract TradeFarmingFactory is Ownable {
    // The addresses of deployed trade farming contracts
    address[] public createdContracts;

    /** 
    * @notice The event will be emitted when new contracts are created
    * @param _addressOfTF address - address of the TF contract
    * @param _tokenAddress address - address of the pairs token
    * @param _totalDays uint256 - total days of the competition
    */
    event TFCreated(address _addressOfTF, address _tokenAddress, uint256 _totalDays);

    /**
     * @notice Factory function - takes the parameters of the competition of Token - Avax pairs
     * @param _routerAddress address of the DEX router contract
     * @param _tokenAddress IERC20 - address of the token of the pair
     * @param _rewardAddress IERC20 - address of the reward token
     * @param _previousVolume uint256 - average of previous days
     * @param _previousDay uint256 - previous considered days
     * @param _totalDays uint256 - total days of the competition
     * @param _owner address - the address which will be the owner
     * @param _upLimit uint256 - setter to up volume change limit
     * @param _downLimit uint256 - setter to down volume change limit
     */
    function createTnAPair(
        address _routerAddress,
        address _tokenAddress,
        address _rewardAddress,
        uint256 _previousVolume,
        uint256 _previousDay,
        uint256 _totalDays,
        uint256 _upLimit,
        uint256 _downLimit,
        address _owner
    ) external onlyOwner {
        TradeFarming TFcontract;
        // Deploying the contract
        TFcontract = new TradeFarming(
            _routerAddress,
            _tokenAddress,
            _rewardAddress,
            _previousVolume,
            _previousDay,
            _totalDays,
            _upLimit,
            _downLimit
        );
        // Transferring the ownership of the contract to the msg.sender
        TFcontract.transferOwnership(_owner);
        // Storing the address of the contract
        createdContracts.push(address(TFcontract));
        // Emitting the new contract event
        emit TFCreated(address(TFcontract), _tokenAddress, _totalDays);
    }

    /**
    * @notice Easily access the last created contracts address
    * @return address - the address of the last deployed contract
    */
    function getLastContract() external view returns (address) {
        return createdContracts[createdContracts.length - 1];
    }
}
